#!/usr/bin/env python3
"""Pull live player session trails (TelemetryService SessionTrail_v1) from the launch universe.

usage:
  tools/trail.py                 # sessions saved in the last 24 h, one block per session
  tools/trail.py --hours 72 --out build/liveops/trails.txt
  tools/trail.py --test          # the test universe instead of launch

Each line in a block: "<seconds since join> <event>". "pos x,y,z" every 30 s, "ERR ..." server errors.
Also prints current players/visits. Read-only; needs the universe's API key (datastores read).
"""
import argparse
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STORE = "SessionTrail_v1"


def target(test):
    with open(os.path.join(ROOT, "deploy", "target.json" if test else "launch-target.json")) as f:
        t = json.load(f)
    key = os.path.expanduser(t.get("apiKey", "~/RobloxProjects/.roblox-api-key"))
    with open(key) as f:
        return t["universeId"], f.read().strip()


def get(url, key):
    req = urllib.request.Request(url, headers={"x-api-key": key} if key else {})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--hours", type=float, default=24)
    ap.add_argument("--test", action="store_true")
    ap.add_argument("--out")
    a = ap.parse_args()
    uni, key = target(a.test)
    g = get(f"https://games.roblox.com/v1/games?universeIds={uni}", None)["data"][0]
    out = [f"universe {uni}: playing {g['playing']}, visits {g['visits']}, updated {g['updated']}"]
    base = f"https://apis.roblox.com/datastores/v1/universes/{uni}/standard-datastores/datastore/entries"
    since = time.time() - a.hours * 3600
    keys, cursor = [], ""
    while True:
        q = urllib.parse.urlencode({"datastoreName": STORE, "limit": 100, "cursor": cursor})
        try:
            page = get(f"{base}?{q}", key)
        except urllib.error.HTTPError as e:
            if e.code != 404:  # 404: no session saved yet, so the store doesn't exist
                raise
            page = {}
        keys += [k["key"] for k in page.get("keys", [])]
        cursor = page.get("nextPageCursor") or ""
        if not cursor:
            break
    recent = sorted((k for k in keys if int(k.rsplit("_", 1)[1]) >= since), key=lambda k: int(k.rsplit("_", 1)[1]))
    out.append(f"{len(recent)} sessions in the last {a.hours:g} h ({len(keys)} total)")
    for k in recent:
        q = urllib.parse.urlencode({"datastoreName": STORE, "entryKey": k})
        v = get(f"{base}/entry?{q}", key)
        user, joined = k.rsplit("_", 1)
        when = time.strftime("%Y-%m-%d %H:%M", time.localtime(int(joined)))
        out.append(f"\n== user {user} joined {when} place v{v.get('place')} job {v.get('job')} ({len(v.get('lines', []))} lines)")
        out += v.get("lines", [])
    text = "\n".join(out)
    if a.out:
        os.makedirs(os.path.dirname(a.out), exist_ok=True)
        with open(a.out, "w") as f:
            f.write(text + "\n")
        print(f"{out[0]}\n{out[1]}\nwrote {a.out}")
    else:
        print(text)


if __name__ == "__main__":
    main()
