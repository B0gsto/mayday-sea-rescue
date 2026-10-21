#!/usr/bin/env python3
"""Lay out the Mayday: Sea Rescue Discord server. Safe to re-run: matches by name.

Discord bots can no longer create servers, so make an empty one first, then:
  DISCORD_BOT_TOKEN=... python3 tools/discord/setup_server.py <guild_id> [--icon path.png]
The bot needs the Administrator permission in that server.
"""
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request

API = "https://discord.com/api/v10"
GAME_URL = "https://www.roblox.com/games/85419402278824"
NAVY, ORANGE = 0x0B2A4A, 0xF26B1D

# Permission bits
VIEW, SEND, CONNECT = 1 << 10, 1 << 11, 1 << 20
SEND_THREADS, ADD_REACT = 1 << 38, 1 << 6

# name -> (colour, hoist, mentionable)
ROLES = {
    "Station Chief": (ORANGE, True, False),
    "Coxswain": (0x2E86C1, True, True),  # moderators
    "Tester": (0x27AE60, True, False),
    "Content Creator": (0x9B59B6, True, False),
    "Storm Alerts": (0, False, True),  # ping role for updates and events
}
STAFF = ("Station Chief", "Coxswain")

# Channel types: 0 text, 2 voice, 4 category, 5 announcement, 15 forum
LAYOUT = [
    ("📻 HARBOUR OFFICE", None, [
        ("welcome", 0, "read", "Start here."),
        ("rules", 0, "read", "Station rules."),
        ("announcements", 5, "read", "News from Port Haven."),
        ("patch-notes", 5, "read", "What changed in each update."),
    ]),
    ("⚓ CREW MESS", None, [
        ("general", 0, None, "Talk about the game."),
        ("find-a-crew", 0, None, "Looking for a crew? Post your server and time."),
        ("screenshots", 0, None, "Best shots from the Gale Isles."),
        ("clips", 0, None, "Rescues, storms and fails."),
        ("bosun-appreciation", 0, None, "The station dog. Good boy."),
        ("off-topic", 0, None, "Anything else."),
    ]),
    ("🛟 SUPPORT", None, [
        ("bug-reports", 15, None, "One bug per post: what happened, where, device, screenshot."),
        ("suggestions", 15, None, "One idea per post."),
        ("help", 0, None, "Stuck? Ask here."),
    ]),
    ("🔊 RADIO", None, [
        ("Crew Channel 16", 2, None, None),
        ("Crew Channel 67", 2, None, None),
        ("Storm Watch", 2, None, None),
    ]),
    ("🧪 TEST STATION", "Tester", [
        ("tester-chat", 0, None, "Playtest feedback and builds."),
    ]),
    ("🔒 STATION ROOM", "staff", [
        ("staff-chat", 0, None, None),
        ("mod-log", 0, None, None),
    ]),
]

WELCOME = {
    "title": "Welcome aboard, crew 🛟",
    "description": (
        "**Mayday: Sea Rescue**: answer the call, brave the storm, bring them home.\n\n"
        f"▶️ **[Play on Roblox]({GAME_URL})**\n\n"
        "📜 Read <#rules>\n"
        "📣 News in <#announcements> and <#patch-notes>\n"
        "⚓ Find a crew in <#find-a-crew>\n"
        "🐛 Report bugs in <#bug-reports>"
    ),
    "color": ORANGE,
}
RULES = {
    "title": "Station rules",
    "description": (
        "**1.** Be kind. No harassment, hate or slurs.\n"
        "**2.** Keep it family friendly: many players are young.\n"
        "**3.** No spam, scams, or self-promo outside the right channel.\n"
        "**4.** Never share personal info, yours or anyone's.\n"
        "**5.** No exploits or cheats. Found one? Report it in <#bug-reports>.\n"
        "**6.** Follow Discord's Terms and Roblox's Community Standards.\n"
        "**7.** Coxswains (mods) have the final say."
    ),
    "color": NAVY,
}


def api(method, path, token, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(API + path, data=data, method=method, headers={
        "Authorization": f"Bot {token}",
        "Content-Type": "application/json",
        "User-Agent": "DiscordBot (mayday-setup, 1.0)",
    })
    while True:
        try:
            with urllib.request.urlopen(req) as r:
                raw = r.read()
                return json.loads(raw) if raw else None
        except urllib.error.HTTPError as e:
            if e.code == 429:
                time.sleep(json.loads(e.read()).get("retry_after", 1) + 0.1)
                continue
            sys.exit(f"{method} {path} -> {e.code}: {e.read().decode()}")


def main():
    token = os.environ.get("DISCORD_BOT_TOKEN") or sys.exit("set DISCORD_BOT_TOKEN")
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    gid = sys.argv[1]
    icon = sys.argv[sys.argv.index("--icon") + 1] if "--icon" in sys.argv else None

    guild = api("GET", f"/guilds/{gid}", token)
    everyone = gid  # @everyone role id == guild id

    roles = {r["name"]: r for r in api("GET", f"/guilds/{gid}/roles", token)}
    for name, (colour, hoist, mention) in ROLES.items():
        if name not in roles:
            perms = str(8) if name == "Station Chief" else None  # Administrator
            body = {"name": name, "color": colour, "hoist": hoist, "mentionable": mention}
            if perms:
                body["permissions"] = perms
            roles[name] = api("POST", f"/guilds/{gid}/roles", token, body)
            print("role +", name)

    def overwrites(kind, private):
        ow = []
        if kind == "read":
            ow.append({"id": everyone, "type": 0, "allow": str(VIEW | ADD_REACT),
                       "deny": str(SEND | SEND_THREADS)})
        if private:
            ow.append({"id": everyone, "type": 0, "allow": "0", "deny": str(VIEW | CONNECT)})
            names = STAFF if private == "staff" else (private, *STAFF)
            ow += [{"id": roles[n]["id"], "type": 0, "allow": str(VIEW | SEND | CONNECT),
                    "deny": "0"} for n in names]
        if kind == "read":  # staff can post in read-only channels
            ow += [{"id": roles[n]["id"], "type": 0, "allow": str(SEND | SEND_THREADS),
                    "deny": "0"} for n in STAFF]
        return ow

    # Announcement channels and forums need a Community server; turn it on first.
    channels = api("GET", f"/guilds/{gid}/channels", token)
    by_name = {c["name"]: c for c in channels}

    def ensure(name, ctype, parent=None, kind=None, private=None, topic=None):
        if name in by_name:
            return by_name[name]
        body = {"name": name, "type": ctype, "permission_overwrites": overwrites(kind, private)}
        if parent:
            body["parent_id"] = parent
        if topic and ctype in (0, 5, 15):
            body["topic"] = topic
        c = api("POST", f"/guilds/{gid}/channels", token, body)
        by_name[name] = c
        print("channel +", name)
        return c

    rules_ch = ensure("rules", 0, kind="read")
    mod_ch = ensure("mod-log", 0, private="staff")
    if "COMMUNITY" not in guild["features"]:
        api("PATCH", f"/guilds/{gid}", token, {
            "features": guild["features"] + ["COMMUNITY"],
            "verification_level": 2,  # registered 5+ minutes
            "explicit_content_filter": 2,  # scan all members
            "rules_channel_id": rules_ch["id"],
            "public_updates_channel_id": mod_ch["id"],
        })
        print("community on")

    for pos, (cat_name, private, chans) in enumerate(LAYOUT):
        cat = ensure(cat_name, 4, private=private)
        api("PATCH", f"/channels/{cat['id']}", token, {"position": pos})
        for i, (name, ctype, kind, topic) in enumerate(chans):
            c = ensure(name, ctype, cat["id"], kind, private, topic)
            api("PATCH", f"/channels/{c['id']}", token, {
                "parent_id": cat["id"], "position": i,
                "permission_overwrites": overwrites(kind, private)})

    # Drop Discord's default "Text Channels"/"Voice Channels" categories once emptied.
    now = api("GET", f"/guilds/{gid}/channels", token)
    for c in now:
        if c["type"] == 4 and c["name"] in ("Text Channels", "Voice Channels") \
                and not any(k.get("parent_id") == c["id"] for k in now):
            api("DELETE", f"/channels/{c['id']}", token)

    # Swap #name placeholders for real channel mentions, then post if the channel is empty.
    ids = {n: c["id"] for n, c in by_name.items()}

    def fill(embed):
        d = embed["description"]
        for n, cid in ids.items():
            d = d.replace(f"<#{n}>", f"<#{cid}>")
        return {**embed, "description": d}

    for chan, embed in (("welcome", WELCOME), ("rules", RULES)):
        cid = ids[chan]
        if not api("GET", f"/channels/{cid}/messages?limit=1", token):
            api("POST", f"/channels/{cid}/messages", token, {"embeds": [fill(embed)]})
            print("posted in", chan)

    patch = {"system_channel_id": ids["general"], "description": "Answer the call. Brave the storm. Bring them home."}
    if icon:
        with open(icon, "rb") as f:
            patch["icon"] = "data:image/png;base64," + base64.b64encode(f.read()).decode()
    api("PATCH", f"/guilds/{gid}", token, patch)
    print("done:", guild["name"])


if __name__ == "__main__":
    main()
