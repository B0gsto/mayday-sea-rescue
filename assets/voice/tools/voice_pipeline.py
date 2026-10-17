#!/usr/bin/env python3
"""Voice pipeline for Mayday: Sea Rescue (docs/11-dispatcher-and-voice.md, section 5).

  python3 -I voice_pipeline.py generate [--only ID[,ID]] [--voice CG_DAY] [--scope MVP] [--takes 2] [--force]
  python3 -I voice_pipeline.py normalise
  python3 -I voice_pipeline.py pack
  python3 -I voice_pipeline.py upload [--bank BANK_ID]

Secrets come from the environment only, never from files in the repo:
  ELEVENLABS_API_KEY   ElevenLabs key (text-to-speech permission only)
  ROBLOX_API_KEY       Open Cloud key with Assets read and write
  ROBLOX_CREATOR_ID    user or group id that owns the assets
  ROBLOX_CREATOR_TYPE  "user" (default) or "group"
Voice ids live in voices.json (voice name -> ElevenLabs voice_id + settings).
Needs ffmpeg on PATH. Uses only the Python standard library.
"""
import argparse
import csv
import json
import os
import re
import subprocess
import sys
import time
import urllib.request
import uuid
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # assets/voice
CSV_PATH = os.path.join(ROOT, "lines.csv")
VOICES = os.path.join(ROOT, "voices.json")
RAW, NORM, BANKS = (os.path.join(ROOT, "build", d) for d in ("raw", "norm", "banks"))
MANIFEST = os.path.join(ROOT, "manifest.json")
EL_URL = "https://api.elevenlabs.io/v1/text-to-speech/{voice_id}?output_format=mp3_44100_192"
RBX_ASSETS = "https://apis.roblox.com/assets/v1/assets"
RBX_OPS = "https://apis.roblox.com/assets/v1/"
GAP_S = 0.35          # silence between clips inside a bank
BANK_MAX_S = 240.0    # 4 min per bank (Roblox limit is 7 min / 20 MB)
LUFS, TP = -18.0, -1.5


def env(name):
    v = os.environ.get(name)
    if not v:
        sys.exit(f"missing environment variable {name}")
    return v


def rows(args=None):
    with open(CSV_PATH, encoding="utf-8") as f:
        for r in csv.DictReader(f):
            if args:
                if args.only and r["id"] not in args.only.split(","):
                    continue
                if args.voice and r["voice"] != args.voice:
                    continue
                if args.scope and not r["notes"].startswith(f"[{args.scope}]"):
                    continue
            yield r


def note(r, key):
    m = re.search(key + r"=(.*?)(?:\s\|\s|$)", r["notes"])
    return m.group(1).strip() if m else None


def generate(args):
    key = env("ELEVENLABS_API_KEY")
    voices = json.load(open(VOICES))
    os.makedirs(RAW, exist_ok=True)
    for r in rows(args):
        v = voices[r["voice"]]
        for take in range(1, args.takes + 1):
            out = os.path.join(RAW, f"{r['id']}__t{take}.mp3")
            if os.path.exists(out) and not args.force:
                continue
            body = {
                "text": note(r, "say") or r["text"],
                "model_id": v.get("model_id", "eleven_multilingual_v2"),
                "voice_settings": v["settings"],
                "seed": (zlib.crc32(r["id"].encode()) + take) % 4294967295,
                "apply_text_normalization": "off",  # numbers are already words
            }
            for k, api in (("ctx_prev", "previous_text"), ("ctx_next", "next_text")):
                if note(r, k):
                    body[api] = note(r, k)
            req = urllib.request.Request(
                EL_URL.format(voice_id=v["voice_id"]), data=json.dumps(body).encode(),
                headers={"xi-api-key": key, "Content-Type": "application/json"})
            for attempt in range(4):
                try:
                    with urllib.request.urlopen(req, timeout=60) as resp:
                        open(out, "wb").write(resp.read())
                    break
                except Exception as e:  # 429 / 5xx: back off and retry
                    print(f"{r['id']} take {take}: {e}; retry", file=sys.stderr)
                    time.sleep(2 ** attempt * 2)
            print("ok", os.path.basename(out))


def normalise(_):
    """Trim edge silence, keep 40 ms pads, loudness-normalise, mono 48 kHz WAV."""
    os.makedirs(NORM, exist_ok=True)
    picks = json.load(open(os.path.join(ROOT, "picks.json"))) if os.path.exists(os.path.join(ROOT, "picks.json")) else {}
    for r in rows():
        src = os.path.join(RAW, f"{r['id']}__t{picks.get(r['id'], 1)}.mp3")
        if not os.path.exists(src):
            continue
        dst = os.path.join(NORM, r["id"] + ".wav")
        short = len(r["text"]) < 25  # integrated LUFS is unreliable on very short clips
        loud = (f"loudnorm=I={LUFS}:TP={TP}:LRA=7" if not short
                else f"dynaudnorm=f=75:g=3,alimiter=limit={10 ** (TP / 20):.3f}")
        af = ("silenceremove=start_periods=1:start_threshold=-50dB,areverse,"
              "silenceremove=start_periods=1:start_threshold=-50dB,areverse,"
              f"adelay=40,apad=pad_dur=0.04,{loud}")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-af", af,
                        "-ac", "1", "-ar", "48000", dst], check=True)


def duration(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                          "-of", "csv=p=0", path], capture_output=True, text=True, check=True)
    return float(out.stdout.strip())


def pack(_):
    """Concatenate clips into banks (voice + scope), record offsets in manifest.json."""
    os.makedirs(BANKS, exist_ok=True)
    manifest = json.load(open(MANIFEST)) if os.path.exists(MANIFEST) else {"banks": {}, "clips": {}}
    groups = {}
    for r in rows():
        p = os.path.join(NORM, r["id"] + ".wav")
        if os.path.exists(p):
            scope = "L" if r["notes"].startswith("[L]") else "MVP"
            groups.setdefault(f"{r['voice']}_{scope}", []).append((r, p))
    for gname, items in groups.items():
        n, t, parts = 1, 0.0, []
        def flush():
            bank = f"{gname}_{n:02d}"
            listfile = os.path.join(BANKS, bank + ".txt")
            with open(listfile, "w") as f:
                for _, path, _ in parts:
                    f.write(f"file '{path}'\nfile '{os.path.join(BANKS, 'gap.wav')}'\n")
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0",
                            "-i", listfile, "-c:a", "libvorbis", "-q:a", "5",
                            os.path.join(BANKS, bank + ".ogg")], check=True)
            old = manifest["banks"].get(bank, {})
            manifest["banks"][bank] = {"file": bank + ".ogg", "assetId": old.get("assetId")}
            for rid, _, (start, end) in parts:
                manifest["clips"][rid] = {"bank": bank, "start": round(start, 3), "end": round(end, 3)}
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "lavfi", "-i",
                        f"anullsrc=r=48000:cl=mono", "-t", str(GAP_S), os.path.join(BANKS, "gap.wav")], check=True)
        for r, p in items:
            d = duration(p)
            if t + d > BANK_MAX_S and parts:
                flush(); n, t, parts = n + 1, 0.0, []
            parts.append((r["id"], p, (t, t + d)))
            t += d + GAP_S
        if parts:
            flush()
    json.dump(manifest, open(MANIFEST, "w"), indent=1, sort_keys=True)
    print(f"{len(manifest['banks'])} banks, {len(manifest['clips'])} clips")


def upload(args):
    key = env("ROBLOX_API_KEY")
    creator = {"userId": env("ROBLOX_CREATOR_ID")} if os.environ.get("ROBLOX_CREATOR_TYPE", "user") == "user" \
        else {"groupId": env("ROBLOX_CREATOR_ID")}
    manifest = json.load(open(MANIFEST))
    for bank, info in manifest["banks"].items():
        if (args.bank and bank != args.bank) or (info.get("assetId") and not args.bank):
            continue
        meta = {"assetType": "Audio", "displayName": f"MSR VO {bank}"[:50],
                "description": "Mayday: Sea Rescue radio voice bank (AI voice, ElevenLabs)",
                "creationContext": {"creator": creator}}
        boundary = uuid.uuid4().hex
        data = open(os.path.join(BANKS, info["file"]), "rb").read()
        body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\n\r\n{json.dumps(meta)}\r\n"
                f"--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{info['file']}\"\r\n"
                f"Content-Type: audio/ogg\r\n\r\n").encode() + data + f"\r\n--{boundary}--\r\n".encode()
        req = urllib.request.Request(RBX_ASSETS, data=body, headers={
            "x-api-key": key, "Content-Type": f"multipart/form-data; boundary={boundary}"})
        op = json.load(urllib.request.urlopen(req, timeout=120))
        for _ in range(60):  # poll the long-running operation
            res = json.load(urllib.request.urlopen(urllib.request.Request(
                RBX_OPS + op["path"], headers={"x-api-key": key}), timeout=30))
            if res.get("done"):
                break
            time.sleep(3)
        asset_id = res.get("response", {}).get("assetId")
        print(bank, asset_id or res)
        if asset_id:
            info["assetId"] = asset_id
            json.dump(manifest, open(MANIFEST, "w"), indent=1, sort_keys=True)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["generate", "normalise", "pack", "upload"])
    ap.add_argument("--only"); ap.add_argument("--voice"); ap.add_argument("--scope")
    ap.add_argument("--takes", type=int, default=2); ap.add_argument("--force", action="store_true")
    ap.add_argument("--bank")
    a = ap.parse_args()
    {"generate": generate, "normalise": normalise, "pack": pack, "upload": upload}[a.cmd](a)
