#!/usr/bin/env python3
"""ElevenLabs line generator for Mayday: Sea Rescue (docs/11, section 5).

Reads assets/voice/lines.csv, maps each speaker (the `voice` column) to a voice id
and settings from assets/voice/cast.json, and writes per line:

    assets/voice/out/<SPEAKER>/<line_id>.mp3        clean master, as returned by the API
    assets/voice/out/<SPEAKER>/<line_id>.ogg        clean, mono 48 kHz Vorbis (needs ffmpeg)
    assets/voice/out/<SPEAKER>/<line_id>.radio.ogg  VHF post-process (--radio, needs ffmpeg)

Resumable: an existing master is never regenerated (unless --force); missing .ogg /
.radio.ogg files are rebuilt from the master without spending credits.

Credit guard: --max-credits caps what this run may spend. /v1/user/subscription is read
before the run and re-read every --recheck lines; the run stops before any line that
would push spend past the cap or past the account's remaining quota.

Examples:
    python3 -I tools/voice/tts.py --dry-run
    python3 -I tools/voice/tts.py --speaker CG_DAY --scope MVP --max-credits 5000 --radio
    python3 -I tools/voice/tts.py --only AGG_ADVICE_CERT_DONE --force --max-credits 100

API key: $ELEVENLABS_API_KEY, else the file ~/RobloxProjects/.elevenlabs-api-key.
The key is only ever sent in the xi-api-key header; it is never printed or written.
"""
import argparse
import csv
import json
import os
import re
import shutil
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
import zlib
from collections import OrderedDict
from concurrent.futures import ThreadPoolExecutor

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
VOICE_DIR = os.path.join(REPO, "assets", "voice")
CSV_PATH = os.path.join(VOICE_DIR, "lines.csv")
CAST_PATH = os.path.join(VOICE_DIR, "cast.json")
OUT_DIR = os.path.join(VOICE_DIR, "out")
KEY_FILE = os.path.expanduser("~/RobloxProjects/.elevenlabs-api-key")
API = "https://api.elevenlabs.io"
DEFAULT_MODEL = "eleven_multilingual_v2"  # docs/11 section 1: one model for every voice

# Credits per billed character, per model (ElevenLabs pricing, docs/11 section 4).
MODEL_COST = {
    "eleven_multilingual_v2": 1.0,
    "eleven_v3": 1.0,
    "eleven_turbo_v2_5": 0.5,
    "eleven_flash_v2_5": 0.5,
}

# VHF marine radio: band-pass 300-3400 Hz (2 x 12 dB/oct), presence bump, light
# compression, then a 180 ms band-passed noise "kssh" squelch tail (docs/11 section 3.3).
RADIO_FILTER = (
    "[0:a]aresample=48000,aformat=channel_layouts=mono,"
    "highpass=f=300,highpass=f=300,lowpass=f=3400,lowpass=f=3400,"
    "equalizer=f=1800:t=q:w=1:g=3,"
    "acompressor=threshold=0.1:ratio=4:attack=5:release=150:makeup=2,"
    "alimiter=limit=0.89[v];"
    "anoisesrc=d=0.18:c=pink:r=48000:a=0.22,highpass=f=300,lowpass=f=3400,"
    "afade=t=in:st=0:d=0.01,afade=t=out:st=0.03:d=0.15[n];"
    "[v][n]concat=n=2:v=0:a=1[out]"
)


# ---------------------------------------------------------------- helpers
def api_key():
    key = os.environ.get("ELEVENLABS_API_KEY")
    if not key and os.path.exists(KEY_FILE):
        with open(KEY_FILE, encoding="utf-8") as f:
            key = f.read().strip()
    if not key:
        sys.exit("no ElevenLabs key: set ELEVENLABS_API_KEY or create " + KEY_FILE)
    return key


def note(row, key):
    m = re.search(r"(?:^|\s)" + key + r"=(.*?)(?:\s\|\s|\s(?:ctx_prev|ctx_next|say|pos)=|$)", row["notes"])
    return m.group(1).strip() if m else None


def scope(row):
    m = re.match(r"\[(\w+)\]", row["notes"])
    return m.group(1) if m else ""


def spoken_text(row):
    """What is billed and spoken: the say= pronunciation override, else the subtitle text."""
    return note(row, "say") or row["text"]


def load_rows(path, args):
    only = set(args.only.split(",")) if args.only else None
    speakers = set(args.speaker.split(",")) if args.speaker else None
    with open(path, encoding="utf-8", newline="") as f:
        for r in csv.DictReader(f):
            if only and r["id"] not in only:
                continue
            if speakers and r["voice"] not in speakers:
                continue
            if args.scope and scope(r) != args.scope:
                continue
            yield r


def load_cast(path):
    with open(path, encoding="utf-8") as f:
        cast = json.load(f)
    return cast.get("roles", cast)


def http(method, url, key, body=None, timeout=120):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "xi-api-key": key, "Content-Type": "application/json", "Accept": "*/*"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read(), resp.headers


def subscription(key):
    raw, _ = http("GET", API + "/v1/user/subscription", key, timeout=30)
    s = json.loads(raw)
    return {"tier": s.get("tier"), "used": s.get("character_count", 0),
            "limit": s.get("character_limit", 0),
            "remaining": s.get("character_limit", 0) - s.get("character_count", 0)}


def ffmpeg():
    return shutil.which("ffmpeg")


def run_ffmpeg(args):
    """Last arg is the output; encode to a temp file and rename, so a failed encode never
    leaves a stub that a resumed run would treat as done."""
    dst = args[-1]
    tmp = dst[:-4] + ".part" + dst[-4:]
    try:
        subprocess.run([ffmpeg(), "-hide_banner", "-loglevel", "error", "-y"] + args[:-1] + [tmp],
                       check=True)
        os.replace(tmp, dst)
    finally:
        if os.path.exists(tmp):
            os.remove(tmp)


def done(path):
    return os.path.exists(path) and os.path.getsize(path) > 0


_VORBIS = None


def vorbis_args():
    """libvorbis (mono) if this ffmpeg has it; else the built-in encoder, which is stereo-only."""
    global _VORBIS
    if _VORBIS is None:
        enc = subprocess.run([ffmpeg(), "-hide_banner", "-encoders"], capture_output=True, text=True).stdout
        _VORBIS = (["-ac", "1", "-c:a", "libvorbis"] if "libvorbis" in enc
                   else ["-ac", "2", "-c:a", "vorbis", "-strict", "-2"])
    return _VORBIS


def encode_clean(src, dst):
    run_ffmpeg(["-i", src, "-ar", "48000"] + vorbis_args() + ["-q:a", "6", dst])


def encode_radio(src, dst):
    run_ffmpeg(["-i", src, "-filter_complex", RADIO_FILTER, "-map", "[out]"]
               + vorbis_args() + ["-q:a", "5", dst])


# ---------------------------------------------------------------- budget guard
class Budget:
    """Reserves credits before each request so parallel workers can never overshoot."""

    def __init__(self, key, max_credits, recheck):
        self.key, self.max, self.recheck = key, max_credits, recheck
        self.lock = threading.Lock()
        self.spent = 0.0       # credits reserved or confirmed by this run
        self.requests = 0
        s = subscription(key)
        self.start_used, self.remaining = s["used"], s["remaining"]
        print(f"subscription: tier={s['tier']} used={s['used']} limit={s['limit']} "
              f"remaining={s['remaining']} | run cap={max_credits}")

    def reserve(self, credits):
        with self.lock:
            if self.requests and self.requests % self.recheck == 0:
                s = subscription(self.key)
                self.remaining = s["remaining"]
                actual = s["used"] - self.start_used
                print(f"  [guard] account used this run={actual}, remaining={self.remaining}")
                self.spent = max(self.spent, actual)
            if self.spent + credits > self.max:
                return False
            if credits > self.remaining:
                return False
            self.spent += credits
            self.remaining -= credits
            self.requests += 1
            return True

    def refund(self, credits):
        with self.lock:
            self.spent -= credits
            self.remaining += credits

    def final(self):
        s = subscription(self.key)
        return s["used"] - self.start_used, s


# ---------------------------------------------------------------- generation
def tts_request(key, voice, row, out_format, take=1):
    body = {
        "text": spoken_text(row),
        "model_id": voice.get("model_id", DEFAULT_MODEL),
        "voice_settings": voice.get("settings", {}),
        "seed": (zlib.crc32(row["id"].encode()) + take) % 4294967295,
    }
    if voice.get("model_id", DEFAULT_MODEL) == "eleven_multilingual_v2":
        body["apply_text_normalization"] = "off"  # numbers are already words in the script
        for k, api in (("ctx_prev", "previous_text"), ("ctx_next", "next_text")):
            if note(row, k):
                body[api] = note(row, k)
    url = f"{API}/v1/text-to-speech/{voice['voice_id']}?output_format={out_format}"
    delay = 2.0
    for attempt in range(7):
        try:
            audio, headers = http("POST", url, key, body)
            return audio, headers
        except urllib.error.HTTPError as e:
            detail = e.read().decode(errors="replace")[:300]
            if e.code == 429 or e.code >= 500:
                wait = float(e.headers.get("retry-after") or delay)
                print(f"  {row['id']}: HTTP {e.code}, retry in {wait:.0f}s", file=sys.stderr)
                time.sleep(wait)
                delay = min(delay * 2, 60)
                continue
            raise RuntimeError(f"HTTP {e.code}: {detail}") from None
        except (urllib.error.URLError, TimeoutError, ConnectionError) as e:
            print(f"  {row['id']}: {e}, retry in {delay:.0f}s", file=sys.stderr)
            time.sleep(delay)
            delay = min(delay * 2, 60)
    raise RuntimeError("gave up after retries")


def post_process(master, row_dir, line_id, radio):
    if not ffmpeg():
        return
    clean = os.path.join(row_dir, line_id + ".ogg")
    if not done(clean):
        encode_clean(master, clean)
    if radio:
        r = os.path.join(row_dir, line_id + ".radio.ogg")
        if not done(r):
            encode_radio(master, r)


def cost_of(row, voice):
    return len(spoken_text(row)) * MODEL_COST.get(voice.get("model_id", DEFAULT_MODEL), 1.0)


def dry_run(rows, cast, out_dir):
    per = OrderedDict()
    for r in rows:
        v = cast.get(r["voice"], {})
        p = per.setdefault(r["voice"], {"lines": 0, "chars": 0, "credits": 0.0, "todo": 0.0,
                                        "ctx": 0, "model": v.get("model_id", DEFAULT_MODEL),
                                        "cast": bool(v.get("voice_id"))})
        c = cost_of(r, v)
        p["lines"] += 1
        p["chars"] += len(spoken_text(r))
        p["credits"] += c
        p["ctx"] += len(note(r, "ctx_prev") or "") + len(note(r, "ctx_next") or "")
        if not done(os.path.join(out_dir, r["voice"], r["id"] + ".mp3")):
            p["todo"] += c
    print(f"{'speaker':<13}{'lines':>6}{'chars':>8}{'credits':>9}{'to do':>9}{'ctx chars':>10}  model / cast")
    tot = {"lines": 0, "chars": 0, "credits": 0.0, "todo": 0.0, "ctx": 0}
    for s, p in per.items():
        print(f"{s:<13}{p['lines']:>6}{p['chars']:>8}{p['credits']:>9.0f}{p['todo']:>9.0f}{p['ctx']:>10}"
              f"  {p['model']}{'' if p['cast'] else '  (NOT CAST)'}")
        for k in tot:
            tot[k] += p[k]
    print(f"{'TOTAL':<13}{tot['lines']:>6}{tot['chars']:>8}{tot['credits']:>9.0f}{tot['todo']:>9.0f}{tot['ctx']:>10}")
    print("ctx chars = previous_text/next_text; not counted as billed (verify on first paid batch).")
    return tot


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--csv", default=CSV_PATH)
    ap.add_argument("--cast", default=CAST_PATH)
    ap.add_argument("--out", default=OUT_DIR)
    ap.add_argument("--speaker", help="comma list of speakers (csv `voice` column)")
    ap.add_argument("--scope", choices=["MVP", "L"])
    ap.add_argument("--only", help="comma list of line ids")
    ap.add_argument("--limit", type=int, help="at most N new lines this run")
    ap.add_argument("--max-credits", type=float, help="hard cap on credits this run (required unless --dry-run)")
    ap.add_argument("--recheck", type=int, default=25, help="re-read /v1/user/subscription every N requests")
    ap.add_argument("--workers", type=int, default=2, help="parallel requests (free tier allows 2, Creator 5)")
    ap.add_argument("--format", default="mp3_44100_128", help="mp3_44100_192 needs Creator or above")
    ap.add_argument("--radio", action="store_true", help="also write <id>.radio.ogg (VHF chain, ffmpeg)")
    ap.add_argument("--force", action="store_true", help="regenerate even if the master exists")
    ap.add_argument("--dry-run", action="store_true", help="print credits needed per speaker and exit")
    args = ap.parse_args()

    cast = load_cast(args.cast) if os.path.exists(args.cast) else {}
    rows = list(load_rows(args.csv, args))
    if args.dry_run:
        dry_run(rows, cast, args.out)
        return
    if args.max_credits is None:
        sys.exit("--max-credits is required for a real run (try --dry-run first)")
    missing = sorted({r["voice"] for r in rows if not cast.get(r["voice"], {}).get("voice_id")})
    if missing:
        print("skipping uncast speakers:", ", ".join(missing))
        rows = [r for r in rows if r["voice"] not in missing]
    if not ffmpeg():
        print("ffmpeg not found: writing mp3 masters only")

    key = api_key()
    budget = Budget(key, args.max_credits, args.recheck)
    todo = []
    for r in rows:
        d = os.path.join(args.out, r["voice"])
        master = os.path.join(d, r["id"] + ".mp3")
        if done(master) and not args.force:
            post_process(master, d, r["id"], args.radio)  # free: rebuild derived files only
            continue
        todo.append(r)
    if args.limit:
        todo = todo[: args.limit]
    print(f"{len(todo)} lines to generate, about {sum(cost_of(r, cast[r['voice']]) for r in todo):.0f} credits")

    stop = threading.Event()
    stats = {"ok": 0, "fail": 0, "skipped_budget": 0}

    def work(r):
        if stop.is_set():
            return
        v = cast[r["voice"]]
        c = cost_of(r, v)
        if not budget.reserve(c):
            stats["skipped_budget"] += 1
            stop.set()
            return
        d = os.path.join(args.out, r["voice"])
        os.makedirs(d, exist_ok=True)
        try:
            audio, _ = tts_request(key, v, r, args.format)
        except Exception as e:
            budget.refund(c)
            stats["fail"] += 1
            print(f"  FAIL {r['id']}: {e}", file=sys.stderr)
            if "quota_exceeded" in str(e) or "HTTP 401" in str(e) or "HTTP 402" in str(e):
                stop.set()
            return
        master = os.path.join(d, r["id"] + ".mp3")
        tmp = master + ".part"
        with open(tmp, "wb") as f:
            f.write(audio)
        os.replace(tmp, master)  # atomic: a crash never leaves a half file that resume would skip
        post_process(master, d, r["id"], args.radio)
        stats["ok"] += 1
        print(f"  ok {r['voice']}/{r['id']} ({c:.0f} cr)")

    with ThreadPoolExecutor(max_workers=max(1, args.workers)) as pool:
        list(pool.map(work, todo))
    used, s = budget.final()
    print(f"done: ok={stats['ok']} fail={stats['fail']} "
          f"{'STOPPED by credit guard' if stats['skipped_budget'] else ''}")
    print(f"credits used this run (account counter) = {used}; remaining = {s['remaining']}")


if __name__ == "__main__":
    main()
