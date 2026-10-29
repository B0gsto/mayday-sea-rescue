#!/usr/bin/env python3
"""List every model in Shared.Config.AssetIds that InsertService:LoadAsset can't load in a published place.
AssetLoader falls back to code-built greyboxes for those, so they ship looking wrong. Runs a Luau Execution
task on the place (default: test place, deploy/target.json; --launch: deploy/launch-target.json + its key).
--grant: instead of checking, grant the place's universe Use permission on every asset id under src/ (AssetIds
models with their meshes, textures, sounds, images). The models are uploaded by the owner's user account, so a group-owned universe (the
launch place) can't LoadAsset them without this grant ("User is not authorized to access Asset"). Uses the
uploader's key (~/RobloxProjects/.roblox-api-key). Grants take ~2-3 minutes to apply; then re-run the check.
usage: tools/asset_load_check.py [--launch] [--version N] [--all-lods] [--grant]
Exit 1 when any model fails. API keys are read from files and never printed.
"""
import argparse
import json
import os
import re
import sys

import persist_check as pc

ROOT = pc.ROOT
SCRIPT = r"""
local InsertService = game:GetService("InsertService")
local ids = require(game:GetService("ReplicatedStorage").Shared.Config.AssetIds)
local allLods = %s
local failed, total, pending, running = {}, 0, 0, 0
for asset, lods in ids.Models do
	for lod, uri in lods do
		if allLods or lod == "LOD0" then
			total += 1
			pending += 1
			while running >= 6 do -- 288 loads at once get HTTP 504s
				task.wait(0.1)
			end
			running += 1
			task.spawn(function()
				local id = tonumber(string.match(uri, "%%d+"))
				local ok, res = pcall(InsertService.LoadAsset, InsertService, id)
				if not ok then
					table.insert(failed, asset .. " " .. lod .. " " .. id .. ": " .. tostring(res))
				elseif typeof(res) == "Instance" then
					res:Destroy()
				end
				pending -= 1
				running -= 1
			end)
		end
	end
end
local t0 = os.clock()
while pending > 0 and os.clock() - t0 < 120 do
	task.wait(0.5)
end
table.sort(failed)
return game:GetService("HttpService"):JSONEncode({ total = total, pending = pending, failed = failed,
	creatorType = tostring(game.CreatorType), creatorId = game.CreatorId })
"""


def grant(universe):
    """Grant `universe` Use on every asset id under src/ (models, meshes, textures, sounds). Returns the failures."""
    ids = set()
    for d, _, files in os.walk(os.path.join(ROOT, "src")):
        for name in files:
            if name.endswith((".luau", ".json")):
                with open(os.path.join(d, name)) as f:
                    ids |= {int(i) for i in re.findall(r"rbxassetid://(\d+)", f.read())}
    ids = sorted(i for i in ids if i > 0)
    failed = []
    for n in range(0, len(ids), 50):
        body = {"subjectType": "Universe", "subjectId": str(universe), "action": "Use",
                "requests": [{"assetId": i, "grantToDependencies": True} for i in ids[n:n + 50]]}
        _, res = pc.http("PATCH", "/asset-permissions-api/v1/assets/permissions", json_body=body)
        failed += res.get("errors") or []
    print(f"granted universe {universe} Use on {len(ids) - len(failed)}/{len(ids)} assets")
    for e in failed:
        print("  GRANT FAILED", json.dumps(e)[:200])
    return failed


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--launch", action="store_true", help="check the launch place (group-owned)")
    ap.add_argument("--version", type=int)
    ap.add_argument("--all-lods", action="store_true")
    ap.add_argument("--grant", action="store_true", help="grant the universe Use on every asset (no check)")
    args = ap.parse_args()
    with open(os.path.join(ROOT, "deploy", "launch-target.json" if args.launch else "target.json")) as f:
        target = json.load(f)
    if args.grant:  # with the uploader's (default) key: only the asset owner can grant
        return 1 if grant(target["universeId"]) else 0
    if target.get("apiKey"):
        pc.KEY_PATH = os.path.expanduser(target["apiKey"])
    out = pc.run_task(target["universeId"], target["placeId"],
                      SCRIPT % ("true" if args.all_lods else "false"), args.version)
    res = json.loads(out)
    print(f"{target['name']}: creator {res['creatorType']} {res['creatorId']}; "
          f"{len(res['failed'])}/{res['total']} models fail to load ({res['pending']} timed out)")
    for line in res["failed"]:
        print("  FALLBACK", line)
    return 1 if res["failed"] or res["pending"] else 0


if __name__ == "__main__":
    sys.exit(main())
