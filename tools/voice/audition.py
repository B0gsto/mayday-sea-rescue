#!/usr/bin/env python3
"""Casting auditions for the docs/11 cast, generated through tts.py (same guard, retries, radio FX).

Premade voices are rendered with two representative lines per role (costs credits).
Accent-matched Voice Library voices cannot be used through the API on the free tier,
so for those only their public preview sample is downloaded (free, not our lines).

    python3 -I tools/voice/audition.py --dry-run
    python3 -I tools/voice/audition.py --max-credits 3000

Writes assets/voice/auditions/<ROLE>--<Voice>/<line_id>.mp3 (+ .radio.ogg for radio roles)
and assets/voice/auditions/library/<ROLE>--<Voice>.mp3.
"""
import csv
import json
import os
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import tts  # noqa: E402

AUD = os.path.join(tts.VOICE_DIR, "auditions")

PREMADE = {
    "Alice": "Xb7hH8MSUJpSbSDYk0k2", "Lily": "pFZP5JQG7iQjIQuC4Bku",
    "Daniel": "onwK4e9ZLuTAKqWW03F9", "George": "JBFqnCBsd6RMkjVDRZzb",
    "Bill": "pqHfZKP75CvOlQylNhV4", "Brian": "nPczCjzI2devNBz1zQrb",
    "Chris": "iP95p4xoKVk53GoZ742B", "Roger": "CwhRBWXzGAHq8TQ4Fs17",
    "Sarah": "EXAVITQu4vr4xnSDxMaL", "Matilda": "XrExE9yKIg1WjnnlVkGX",
    "Jessica": "cgSgspJ2msm6clMCkdW9", "Bella": "hpp4J3VqNfWAUOO0d1Us",
    "Charlie": "IKne3meq5aSn9XLyUdCD", "Callum": "N2lVS1w4EtoT3dr4eOWO",
    "Liam": "TX3LPaxmHKxFdv7VOQHJ", "Will": "bIHbv24MWmeRgasZH58o",
}

# role: (premade candidates in preference order, two line ids). Ordered by priority so the
# credit guard, if it trips, cuts the minor roles.
ROLES = [
    ("CG_DAY", ["Alice", "Lily"], ["CGD_CHATTER_RADIO_CHECK_REPLY", "CGD_FERRY_MANIFEST_MISMATCH"]),
    ("CG_NIGHT", ["Daniel", "George"], ["CGN_CHATTER_RADIO_CHECK_REPLY", "CGN_FERRY_MANIFEST_MISMATCH"]),
    ("AGGIE", ["Lily", "Alice"], ["AGG_ADVICE_IDLE_2", "AGG_ADVICE_RANK_UP"]),
    ("CREW_FINN", ["Charlie", "Liam"], ["FIN_CALLOUT_LOST", "FIN_CHATTER_C2"]),
    ("CREW_DEE", ["Sarah", "Matilda"], ["DEE_CALLOUT_BIG_SET", "DEE_CHATTER_C1"]),
    ("PLAYER_M", ["Will", "Liam"], ["PLM_CALM_NEARLY_THERE", "PLM_FERRY_ALL_ACCOUNTED"]),
    ("PLAYER_F", ["Jessica", "Sarah"], ["PLF_CALM_NEARLY_THERE", "PLF_FERRY_ALL_ACCOUNTED"]),
    ("HELI_PILOT", ["Daniel", "Brian"], ["HEL_HELO_ON_SCENE", "HEL_HELO_FUEL"]),
    ("BARNABY", ["George", "Bill"], ["BAR_CALLER_ANCHOR_OK", "BAR_CALLER_LIFEJACKETS"]),
    ("LOU", ["Bill", "Brian"], ["LOU_CALLER_ARRIVE", "LOU_CALLER_CAPTAIN_THANKS"]),
    ("DR_OSEI", ["Lily", "Alice"], ["OSE_HANDOVER_RECEIVE", "OSE_HANDOVER_THANKS_3"]),
    ("PATROL", ["Chris", "Roger"], ["PAT_CALLER_RADIO_CHECK", "PAT_CALLER_COVER_SECTOR"]),
    ("HAZEL", ["Matilda", "Alice"], ["HAZ_CALLER_STORM", "HAZ_CALLER_GOSSIP_2"]),
    ("CASUALTY_M", ["Callum", "Chris"], ["CSM_CASUALTY_AIR_POCKET_2", "CSM_CASUALTY_COUGH_OK"]),
    ("CASUALTY_F", ["Matilda", "Bella"], ["CSF_CASUALTY_AIR_POCKET_2", "CSF_CASUALTY_COUGH_OK"]),
    ("PARENT_F", ["Bella", "Jessica"], ["PAR_CALLER_ASK", "PAR_CALLER_RELIEF"]),
    ("INFORMANT_M", ["Callum", "Liam"], ["INF_CALLER_STILL_THERE", "INF_CALLER_WAVE_2"]),
    ("TEEN_M", ["Liam", "Will"], ["TEN_CALLER_IN_WATER_2", "TEN_CALLER_THANKS"]),
]

# Accent-matched Voice Library voices (need a paid plan for API use). Preview samples only.
LIBRARY = {
    "CG_DAY": [("Isla Skye", "TVmbglAk3F1GkiCoOq47", "scottish"), ("Lynda", "SB13jgWjPxi4e4JoTT1H", "scottish")],
    "CG_NIGHT": [("Liam Dale", "w2ZdKT3ghAOcMRbpjC3u", "british"), ("Peter Baker", "Ix8C14HEHgIQkJswik2o", "british")],
    "AGGIE": [("Beatrice", "kkPJzQOWz2Oz9cUaEaQd", "british"), ("Eleanor", "2qQJWjw5XdG80GreshqG", "british")],
    "CREW_FINN": [("Bren", "RlSVB64yXMZJjq67jbB1", "irish"), ("Cillian", "B5jEZPqk2OJ2vkPw3wBM", "irish")],
    "PLAYER_M": [("Lewis", "gUbIduqGzBP438teh4ZA", "scottish")],
    "PLAYER_F": [("Sarah", "Lny4bN2CTZWgKZAgIHKa", "scottish")],
    "HELI_PILOT": [("Adam", "U5UjeJMsOvyhYhXfZdvZ", "scottish"), ("David", "1N4VgTBW1ZGBv5IHWRAf", "scottish")],
    "BARNABY": [("Grandfather Joe", "0lp4RIz96WD1RUtvEu3Q", "british")],
    "HAZEL": [("Jane", "RILOU7YmBhvwJGDGjNmP", "british")],
    "CASUALTY_M": [("Darren", "9TYDukkUVpJPDSIuv3ir", "irish")],
    "PARENT_F": [("Laura", "3b8fXc91YHS1i2DYAlBQ", "irish"), ("Michelle", "C92s6vssSLlabgIln1iY", "irish")],
    "INFORMANT_M": [("Patrick", "qwaVDEGNsBllYcZO1ZOJ", "irish"), ("Richie", "73JgZZFYmivaO9TzZpzc", "irish")],
    "TEEN_M": [("Toby", "pYDLV125o4CgqP8i49Lg", "british")],
}

RADIO_ROLES = {"CG_DAY", "CG_NIGHT", "AGGIE", "PLAYER_M", "PLAYER_F", "HELI_PILOT", "BARNABY",
               "LOU", "PATROL", "HAZEL"}

# docs/11 section 1 settings (stability / similarity / style / speed).
DOC_SETTINGS = {
    "CG_DAY": (0.72, 0.80, 0.05, 0.95), "CG_NIGHT": (0.72, 0.80, 0.05, 0.93),
    "AGGIE": (0.55, 0.80, 0.20, 1.0), "CREW_FINN": (0.45, 0.75, 0.25, 1.05),
    "CREW_DEE": (0.50, 0.75, 0.20, 1.0), "PLAYER_M": (0.62, 0.80, 0.10, 1.0),
    "PLAYER_F": (0.62, 0.80, 0.10, 1.0), "BARNABY": (0.40, 0.75, 0.45, 1.0),
    "LOU": (0.40, 0.80, 0.35, 1.05), "HAZEL": (0.45, 0.75, 0.40, 1.0),
    "PATROL": (0.65, 0.80, 0.10, 1.0), "INFORMANT_M": (0.35, 0.75, 0.40, 1.1),
    "PARENT_F": (0.35, 0.75, 0.40, 1.05), "TEEN_M": (0.40, 0.75, 0.35, 1.05),
    "CASUALTY_M": (0.30, 0.75, 0.45, 1.0), "CASUALTY_F": (0.30, 0.75, 0.45, 1.0),
    "DR_OSEI": (0.65, 0.80, 0.15, 1.0), "HELI_PILOT": (0.75, 0.80, 0.05, 1.0),
}


def settings(role):
    st, sim, sty, spd = DOC_SETTINGS[role]
    return {"stability": st, "similarity_boost": sim, "style": sty, "use_speaker_boost": True, "speed": spd}


def fetch_library_previews(key):
    os.makedirs(os.path.join(AUD, "library"), exist_ok=True)
    for role, cands in LIBRARY.items():
        for name, vid, accent in cands:
            dst = os.path.join(AUD, "library", f"{role}--{name.replace(' ', '_')}.mp3")
            if os.path.exists(dst):
                continue
            q = urllib.parse.urlencode({"search": name.split()[0], "accent": accent, "page_size": 100})
            raw, _ = tts.http("GET", f"{tts.API}/v1/shared-voices?{q}", key, timeout=30)
            hit = next((v for v in json.loads(raw).get("voices", []) if v["voice_id"] == vid), None)
            if not hit or not hit.get("preview_url"):
                print("  no preview for", role, name)
                continue
            with urllib.request.urlopen(hit["preview_url"], timeout=60) as r, open(dst, "wb") as f:
                f.write(r.read())
            print("  preview", os.path.basename(dst))


def main():
    rows = {r["id"]: r for r in csv.DictReader(open(tts.CSV_PATH, encoding="utf-8", newline=""))}
    tmp = tempfile.mkdtemp(prefix="mayday_aud_")
    cast, out_rows = {}, []
    for role, voices, ids in ROLES:
        for name in voices:
            spk = f"{role}--{name}"
            cast[spk] = {"voice_id": PREMADE[name], "model_id": tts.DEFAULT_MODEL, "settings": settings(role)}
            for i in ids:
                out_rows.append({**rows[i], "voice": spk})
    csv_path, cast_path = os.path.join(tmp, "aud.csv"), os.path.join(tmp, "cast.json")
    with open(csv_path, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(out_rows[0]))
        w.writeheader()
        w.writerows(out_rows)
    json.dump(cast, open(cast_path, "w"))
    passthru = sys.argv[1:]
    base = [sys.executable, "-I", os.path.join(HERE, "tts.py"), "--csv", csv_path, "--cast", cast_path, "--out", AUD]
    if "--dry-run" in passthru:
        subprocess.run(base + passthru, check=True)
        return
    radio_spk = ",".join(s for s in cast if s.split("--")[0] in RADIO_ROLES)
    # one run for all (priority order), radio variants added in a free second pass
    subprocess.run(base + passthru, check=True)
    subprocess.run(base + ["--speaker", radio_spk, "--radio", "--max-credits", "0"], check=True)
    fetch_library_previews(tts.api_key())


if __name__ == "__main__":
    main()
