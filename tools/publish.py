#!/usr/bin/env python3
"""Check, build and publish Mayday: Sea Rescue to the PRIVATE test experience (deploy/target.json).

usage: python3 tools/publish.py [--skip-check]

Runs ~/RobloxProjects/tools/check.sh and build.sh, then uploads build/MaydaySeaRescue.rbxl as a new Published
version of the test place through Open Cloud, using the shared helpers in ~/RobloxProjects/tools/deploy.py (the API
key is read from ~/RobloxProjects/.roblox-api-key and never printed). It never creates passes or products and never
changes the experience's visibility. The new version number is written to deploy/state.json."""
import json, os, subprocess, sys

GAME = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS = os.path.expanduser("~/RobloxProjects/tools")
sys.path.insert(0, TOOLS)
import deploy  # noqa: E402

target = json.load(open(os.path.join(GAME, "deploy", "target.json")))
universe, place = target["universeId"], target["placeId"]

steps = [] if "--skip-check" in sys.argv else ["check.sh"]
for script in steps + ["build.sh"]:
    r = subprocess.run([os.path.join(TOOLS, script), GAME], capture_output=True, text=True)
    if r.returncode != 0:
        print((r.stdout + r.stderr)[-2000:])
        sys.exit(f"{script} failed: nothing published")

rbxl = os.path.join(GAME, "build", "MaydaySeaRescue.rbxl")
with open(rbxl, "rb") as f:
    _, body = deploy.http("POST", f"/universes/v1/{universe}/places/{place}/versions?versionType=Published",
                          data=f.read(), content_type="application/octet-stream", retry_5xx=False)
version = body.get("versionNumber") if isinstance(body, dict) else None
state_path = os.path.join(GAME, "deploy", "state.json")
state = json.load(open(state_path)) if os.path.exists(state_path) else {}
state["placeVersion"] = version
json.dump(state, open(state_path, "w"), indent=2)
print(f"published place {place} version {version}: https://www.roblox.com/games/{place}")
