#!/usr/bin/env python3
"""Pull live player session trails (TelemetryService SessionTrail_v1) from the launch universe.

usage:
  tools/trail.py                 # sessions saved in the last 24 h, one block per session
  tools/trail.py --hours 72 --out build/liveops/trails.txt
  tools/trail.py --test          # the test universe instead of launch

Each line in a block: "<seconds since join> <event>". "pos x,y,z" every 30 s, "ERR ..." server errors.
Also prints current players/visits, a Robux summary (prompts shown, purchases, R$ by source), a per-device perf summary
(SessionPerf: join-to-world and frame-rate buckets, sessions in each) and the onboarding funnel (unique users per step;
old rows such as 8 WorkshopPlaced keep their own line beside 8 FirstUpgrade).
Read-only; needs the universe's API key (datastores read).
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


def robux_summary(lines):
    """RobuxPrompt trail lines: "<s> custom RobuxPrompt <value> <source> <key> <Shown|Purchased|Cancelled>".
    A Purchased line's value is the item's list price in R$ (older lines carry kind as the source and value 1)."""
    shown, bought, robux, by, waiting = 0, 0, 0, {}, {}
    for line in lines:
        p = line.split()
        if len(p) < 7 or p[1:3] != ["custom", "RobuxPrompt"]:
            continue
        value, source, key, outcome = p[3], p[4], p[5], p[6]
        if outcome == "Shown":
            shown += 1
            waiting[key] = waiting.get(key, 0) + 1
        elif outcome in ("Cancelled", "Purchased"):
            if waiting.get(key):  # closes a prompt already counted by its Shown line
                waiting[key] -= 1
            else:  # older trails log only the outcome, so it is the prompt's only line
                shown += 1
        if outcome == "Purchased":
            bought += 1
            r = int(float(value)) if source not in ("Products", "GamePasses") else 0
            robux += r
            by[source] = by.get(source, 0) + r
            by.setdefault("items", []).append(key)
    items = by.pop("items", [])
    where = ", ".join(f"{s} {r}" for s, r in sorted(by.items())) or "none"
    return f"Robux: {shown} prompts shown, {bought} purchases, {robux} R$ list (by source: {where}){': ' + ' '.join(items) if items else ''}"


def funnel_summary(sessions):
    """Onboarding steps from {user: [lines]}: "<s> onboarding <step> <name>". Rows come from the lines themselves, so
    names from before a funnel change still read. Go back isn't a step (driving home skips it): "<s> custom GoBack
    <value> <vehicle> Started" before that user's first delivery line counts it."""
    reached, pressed = {}, set()
    for user, lines in sessions.items():
        delivered = False
        for line in lines:
            p = line.split()
            if len(p) >= 4 and p[1] == "onboarding":
                reached.setdefault((int(p[2]), p[3]), set()).add(user)
                delivered = delivered or p[3] == "FirstDelivery"
            elif len(p) >= 6 and p[1:3] == ["custom", "GoBack"] and p[5] == "Started" and not delivered:
                pressed.add(user)
    rows = [f"  {step:>2} {name:<15} {len(users)}" for (step, name), users in sorted(reached.items())]
    return "\n".join(["Onboarding funnel (unique users):"] + rows + [f"  Go back before the first delivery: {len(pressed)}"])


def perf_summary(lines):
    """SessionPerf trail lines: "<s> custom SessionPerf <ready seconds> <ready bucket> <fps bucket> <device>"."""
    by = {}
    for line in lines:
        p = line.split()
        if len(p) == 7 and p[1:3] == ["custom", "SessionPerf"]:
            d = by.setdefault(p[6], {"ready": {}, "fps": {}})
            d["ready"][p[4]] = d["ready"].get(p[4], 0) + 1
            d["fps"][p[5]] = d["fps"].get(p[5], 0) + 1
    if not by:
        return "Perf: no SessionPerf lines"

    def counts(c):
        return " ".join(f"{k}:{n}" for k, n in sorted(c.items()))

    return "Perf: " + " | ".join(f"{dev} ready {counts(d['ready'])} fps {counts(d['fps'])}" for dev, d in sorted(by.items()))


def selftest():
    text = funnel_summary({
        "1": ["0 onboarding 7 FirstDelivery", "5 onboarding 8 WorkshopPlaced", "9 custom GoBack 0 JetSki Started"],
        "2": ["3 custom GoBack 1 JetSki Started", "4 onboarding 7 FirstDelivery", "9 onboarding 8 FirstUpgrade"],
        "3": ["0 onboarding 2 AtSea", "6 onboarding 4 FirstDelivery", "99 onboarding 10 BoatL11"],  # boat-first numbering
    })
    assert "7 FirstDelivery   2" in text, text
    assert "8 FirstUpgrade    1" in text and "8 WorkshopPlaced  1" in text, text
    assert "4 FirstDelivery   1" in text and "10 BoatL11         1" in text, text
    assert text.endswith("first delivery: 1"), text
    print("ok")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--hours", type=float, default=24)
    ap.add_argument("--test", action="store_true")
    ap.add_argument("--out")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        return selftest()
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
    allLines, byUser = [], {}
    for k in recent:
        q = urllib.parse.urlencode({"datastoreName": STORE, "entryKey": k})
        v = get(f"{base}/entry?{q}", key)
        allLines += v.get("lines", [])
        user, joined = k.rsplit("_", 1)
        byUser.setdefault(user, []).extend(v.get("lines", []))
        when = time.strftime("%Y-%m-%d %H:%M", time.localtime(int(joined)))
        out.append(f"\n== user {user} joined {when} place v{v.get('place')} job {v.get('job')} ({len(v.get('lines', []))} lines)")
        out += v.get("lines", [])
    out[2:2] = [robux_summary(allLines), perf_summary(allLines), funnel_summary(byUser)]
    text = "\n".join(out)
    if a.out:
        os.makedirs(os.path.dirname(a.out), exist_ok=True)
        with open(a.out, "w") as f:
            f.write(text + "\n")
        print(f"{out[0]}\n{out[1]}\n{out[2]}\n{out[3]}\nwrote {a.out}")
    else:
        print(text)


if __name__ == "__main__":
    main()
