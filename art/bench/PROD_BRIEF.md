# Production brief: build one backlog asset

You build one real game asset for MaydaySeaRescue (photoreal Roblox sea-rescue game, Cornish / Gale Isles coast).
Your asset name `<Asset>` and kind folder `<kind>` are in your task. Stop as soon as the deliverables exist.

## Rules

- Source: `art/source/<kind>/<Asset>/build.py` (+ helper `.py` next to it). Outputs: `--out-root build/prod/<Asset>`.
- Do **not** touch anything else: no edits to `tools/`, `docs/`, `assets/`, `art/status/`, `src/` or other assets'
  folders; no git commits; no Roblox uploads. Reading anything is fine.
- Your spec row: `grep -n '<Asset>' docs/12-asset-list.md` (size, triangle budget, sets, priority). Real dimensions:
  `art/reference/<Asset>/dims.md` if it exists (validate checks your `dims_m` against it; reference photos may sit
  next to it). Art direction: `docs/05-art-direction.md` (skim sections 4 and 5: scale, texel tiers, wear, palette).
- Read `tools/blender/README.md` for the build-file spec, steps, budgets and `validate` rules. Model in studs
  (1 m = 3 studs, `common.metres_to_studs`). Pick the right `budget` class from `tools/blender/budgets.py`.
- Good examples to copy patterns from (read, never edit): `art/source/kit/E1/kitgeo.py`,
  `art/source/harbour/M_Hbr_PropAtlas/props.py`, `art/source/vessels/_C1/c1geo.py`, `tools/blender/rope.py` (ropes).
- Quality bar: photoreal, real-world proportions, bevelled hard edges, believable wear (salt, rust, scuffs, fading),
  CC0 scan textures where they help (the repo already has Poly Haven scans; see `tools/blender/scan_ingest.py`).
  No placeholder art. Add the `ATT_*` attachments gameplay needs (the docs/12 row or docs/09 mention them).
- `build()` returns LOD0 (+ `_COL`) only; the `lod` step makes `_LOD1` / `_LOD2`.

## Commands (every Blender run through the shared 2-slot lock; queueing is normal)

```sh
~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build art/source/<kind>/<Asset>/build.py \
  --out-root build/prod/<Asset> --steps build,lod,validate,export,turntable 2>&1 | tail -40
python3 tools/blender/sheet.py --asset <Asset> --out-root build/prod/<Asset>
```

Iterate until `validate` passes. Check your own turntable once or twice (downscale: `sips -Z 768 in.png --out s.png`)
and fix what looks wrong. Cap yourself at about 8 Blender runs.

## Deliverables (then stop)

1. `art/source/<kind>/<Asset>/build.py` passing validate.
2. `build/prod/<Asset>/` with fbx, textures, turntable, contact sheet.
3. `art/source/<kind>/<Asset>/RESULT.md` (under 200 words): validate result, LOD tris, sets, attachments, open issues.

Final reply: RESULT.md text + contact sheet path. Nothing else.
