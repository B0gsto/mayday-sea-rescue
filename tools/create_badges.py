#!/usr/bin/env python3
"""Create the BadgeConfig badges that still have id = 0 on the LAUNCH universe (deploy/launch-target.json) through
Open Cloud (POST apis.roblox.com/legacy-badges/v1/universes/{id}/badges), icon = marketing/badges/<Key>.png, and
write each new id back into src/shared/Config/BadgeConfig.luau.

usage: python3 tools/create_badges.py [--only Key[,Key]] [--max-cost N]
expectedCost guards spend: a badge is created only if Roblox's price equals the cost we send (0 = free quota);
on a price mismatch the script stops and prints the price instead of paying. --max-cost N allows paying up to N
Robux per badge (group funds). API key: ~/RobloxProjects/.roblox-api-key (never printed)."""
import json, os, re, sys, uuid, urllib.request, urllib.error

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CFG = os.path.join(REPO, "src/shared/Config/BadgeConfig.luau")
KEY = open(os.path.expanduser("~/RobloxProjects/.roblox-api-key")).read().strip()
TARGET = json.load(open(os.path.join(REPO, "deploy/launch-target.json")))
UNI = TARGET["universeId"]
GROUP = TARGET["creator"]["type"] == "Group"
ICON_FALLBACK = {"RankCoxswain": "CertCoxswain"}


def arg(name, default=None):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def badges(src):
    out = []
    for m in re.finditer(r"\n\t(\w+) = \{\n\t\tid = (\d+),\n\t\tname = \"([^\"]*)\",\n\t\tdescription = \"([^\"]*)\",", src):
        out.append({"key": m.group(1), "id": int(m.group(2)), "name": m.group(3), "description": m.group(4)})
    return out


def create(b, cost):
    icon = os.path.join(REPO, "marketing/badges", ICON_FALLBACK.get(b["key"], b["key"]) + ".png")
    boundary = uuid.uuid4().hex
    fields = {"name": b["name"], "description": b["description"], "expectedCost": str(cost),
              "paymentSourceType": "2" if GROUP else "1", "isActive": "true"}
    body = b""
    for k, v in fields.items():
        body += f"--{boundary}\r\nContent-Disposition: form-data; name=\"{k}\"\r\n\r\n{v}\r\n".encode()
    body += (f"--{boundary}\r\nContent-Disposition: form-data; name=\"files\"; filename=\"icon.png\"\r\n"
             "Content-Type: image/png\r\n\r\n").encode() + open(icon, "rb").read() + b"\r\n"
    body += f"--{boundary}--\r\n".encode()
    req = urllib.request.Request(f"https://apis.roblox.com/legacy-badges/v1/universes/{UNI}/badges", data=body,
                                 method="POST", headers={"x-api-key": KEY,
                                                         "Content-Type": f"multipart/form-data; boundary={boundary}"})
    try:
        r = urllib.request.urlopen(req, timeout=60)
        return True, json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        return False, e.code, e.read().decode()[:400]


def main():
    src = open(CFG).read()
    only = set(arg("--only", "").split(",")) - {""}
    max_cost = int(arg("--max-cost", "0"))
    for b in badges(src):
        if b["id"] != 0 or (only and b["key"] not in only):
            continue
        res = create(b, 0)
        if not res[0] and max_cost > 0 and '"code":18' in res[2].replace(" ", ""):
            res = create(b, max_cost)
        if not res[0]:
            print(f"{b['key']}: FAILED {res[1]} {res[2]}")
            return 1
        new_id = res[1].get("id")
        src = src.replace(f"\n\t{b['key']} = {{\n\t\tid = 0,", f"\n\t{b['key']} = {{\n\t\tid = {new_id},", 1)
        open(CFG, "w").write(src)
        print(f"{b['key']}: created {new_id}")
    return 0


sys.exit(main())
