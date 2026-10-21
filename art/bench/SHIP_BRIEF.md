# Ship brief: upload a batch of built assets and put them in the game

You ship one batch of assets that are already built (they pass `validate`, sources in `art/source/<kind>/<Asset>/`,
outputs in `build/prod/<Asset>/`). Your batch id, asset list and integration target are in your task.
Follow the `ponytail` skill (`~/.claude/skills/ponytail/SKILL.md`, level full): smallest complete change.
Stop as soon as the deliverables exist.

## Rules

- Read first: `CLAUDE.md`, `CONTRACT.md` (the I1 entries: Swaps, Street, Harbour, Seamarks, AssetLoader),
  `src/server/World/Swaps.luau`, `src/server/Services/WorldDressingService.luau` (`Start`, `swap`), and each asset's
  `RESULT.md` + `build/prod/<Asset>/fbx/<Asset>/<Asset>.attachments.json`.
- Own only the files your task names, plus your assets' `assets/fbx|textures|models/<Asset>*`, `art/status/<ID>.csv`,
  and the generated `src/shared/Config/AssetIds.luau` / `src/server/Assets/Appearances.model.json` (regenerated, never
  hand-edited). Other agents edit other files at the same time: never revert, reformat or "fix" files you don't own.
- No git commits. No Blender rebuilds (if an asset is broken, skip it and report). Never upload human body meshes.
- Uploads are real Roblox uploads: only your batch's files, named after the asset, through the tools below.
- Keep greybox fallbacks: if an asset fails to load, the old greybox or part-built object stays (as Swaps does).
- No choice UI, no paragraph text (CLAUDE.md). Code-built Parts are fine for anything missing.

## Steps

1. **Copy** `build/prod/<A>/fbx/<A>/*` to `assets/fbx/<A>/` and `build/prod/<A>/textures/<A>/*.png` to
   `assets/textures/<A>/` (ship PNGs only; skip `masters/` or 2048 masters if present).
2. **Upload** with `art/source/<kind>/<batch>/upload.sh` written like `art/source/buildings/H6/upload.sh`
   (same `with-lock.sh assets.MaydaySeaRescue` wrapper, textures as Image, LOD0/1/2 as Model, then
   `python3 tools/gen_asset_ids.py` with retries). HTTP 429: wait and rerun; re-uploads of identical bytes are no-ops.
   Check moderation: `python3 ~/RobloxProjects/tools/assets.py refresh .`.
3. **Status**: `art/status/<ID>.csv`, same columns as `art/status/E1.csv`, one row per asset (status, LOD0 id,
   source `blender:art/source/... (deepseek-v4.1-flash 2026-10-19)`, licence, ai_used, notes with tris + ATT list +
   the integration mapping).
4. **Integrate** as your task says. Patterns: greybox swap = a `Swaps` entry (see the H3 cottages / H6 entries);
   free placement = your own module `src/server/World/<Module>.luau` with `place(base)` (already called from
   `WorldDressingService.Start` when the module exists; copy the Seamarks / Harbour style: Atomic models under
   `Workspace.Dressing`, `AssetLoader` by asset name, pcall per item, a folder attribute with counts). Put pure layout
   maths in a pure module with a small `tests/<Module>.spec.luau`.
5. **Check**: `~/RobloxProjects/tools/check.sh . 2>&1 | tail -15` must pass. Then one Studio check:
   `python3 tools/studio/smoke.py open`, `play start`, a `lua Server -` snippet that prints your folder attributes /
   counts, `shot <batch>` once or twice near your assets (move the camera there in the snippet), `play stop`, `close`.
   The Studio lock queues you behind other agents: that is normal. Cap yourself at about 4 Studio sessions.
6. **CONTRACT.md**: append one bullet for your batch (module, folder, attributes, mapping), like the I1 bullets.

## Final reply (under 250 words, then stop)

Assets shipped (LOD0 ids), assets skipped and why, files changed, check result, Studio result + shot paths, open issues.
