# tools/blender: the photoreal asset pipeline

Rules: docs/12-asset-list.md section 1 (ported from Gulp), budgets from docs/05 section 5.6. **Every Blender run goes through
`~/RobloxProjects/tools/blender-run.sh`** (one of the 2 machine-wide heavy slots). Keep each run short: build + lod + validate + export
is one run, each bake is its own run.

## Commands

```sh
# one asset (art/source/<kind>/<Asset>/build.py), all steps
~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --asset <Asset>
~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --asset <Asset> --steps build,lod,validate,export
# any build file, outputs somewhere else (fbx/, textures/, review/ under --out-root instead of assets/)
~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build path/to/build.py --out-root build/x --no-template

# no heavy slot (system python3 + Pillow + numpy)
python3 tools/blender/check_textures.py assets/textures/<Asset>/ [--cap 4096] [--alpha] [--wet] [--signal-mask T_<Name>_<Set>=mask.png]
python3 -m unittest discover -b -s tools/blender -p 'test_*.py'
tools/blender/selftest/run_selftest.sh        # tests + the bollard end to end (2 short Blender runs) -> build/blender-selftest/
```

## Steps (run.py)

`build, lod, bake, validate, export, turntable` always run in that order. `export` needs `validate` in the same run and
writes nothing when it fails; exit status 1 on any failure. `bake` / `turntable` call `bake.run(spec, report)` /
`turntable.run(spec, report, ok)` when B01 adds those files, and are skipped until then. The scene starts from
`art/blender/_template.blend` when it exists (B01's `template.py`), else an empty factory scene. Report:
`assets/review/<Asset>/<date>_report.json`. The `.blend` is saved next to `build.py`.

| File | Job |
|---|---|
| `common.py` | paths (12 1.3), `EXPORT_CAP` 1024, `MASTER` 4096, 3 studs per metre, `dims.md` parser, image-size reader |
| `names.py` | name rules: `M_<Cat>_<Name>[_NN][_HP\|_LOD0\|_LOD1\|_LOD2\|_COL]`, `T_<Name>_<Set>_<ALB\|NOR\|RGH\|MET>[_Wet]`, `ATT_*`, `RIG_`, `A_`, `FX_`, `SFX_` |
| `budgets.py` | per-class LOD0 / per-MeshPart / LOD1 / LOD2 triangles, texture sets, `_COL` rule, texel tiers, size tolerances |
| `validate.py` | the checks (below); pure rule functions at the top |
| `versions.py` | `lod` step: `_LOD1` / `_LOD2` by bisected collapse decimation, UVs kept, weighted normals |
| `export.py` | one FBX per LOD via `rbxkit.export_fbx` (measured: `-Z` forward, `Y` up, `FBX_SCALE_UNITS`, scale 1; 1 unit = 1 stud; `roblox = (-bx, bz, by)`), read back; `_COL` goes in the LOD0 file; `<Name>.attachments.json` |
| `uvlayout.py` | UV stats, texel density, LOD layout comparison, island count |
| `texgen.py` | atlas shelf packing, bake margin, cap downsizing, texel maths |
| `check_textures.py` | map content: albedo 30 to 240 (metal 180 to 250), saturation 0.45 outside signal masks, OpenGL normals (curl test), single-channel RGH / MET, size, names, wet darker / glossier |

**validate** fails on: names; real size off by more than 5% of `dims_m` x 3 (up to 15% with `size_note`), or spec `dims_m`
disagreeing with `art/reference/<Asset>/dims.md`; LOD0 total, per-MeshPart, LOD1 / LOD2 over budget (or a LOD missing /
present against its class); more than one material; not exactly one UV set `UVMap`, UVs outside 0..1 (unless `tiling`),
a LOD whose UV layout moved; texel density under 90% of the tier; a set's four maps missing, not power of two or over
`EXPORT_CAP`; missing `_COL` where the class needs it; bad `ATT_*` names; transforms not applied; origin; scene units.

## Build file and spec

`build()` makes the objects (1 Blender unit = 1 stud: use `common.metres_to_studs`) and returns:

```python
{"name": "M_Hbr_Bollard_01",          # mesh base name; meshes are <name>_LOD0 / _COL / _HP
 "budget": "small_prop",              # a budgets.BUDGETS class
 "tris": 800,                         # optional: the asset's own docs/12 row ceiling (never above the class)
 "tier": "standard",                  # hero / standard / background (05 5.3)
 "dims_m": (0.35, 0.35, 0.55),        # real size, Blender X, Y (front is -Y), Z up; None for a free axis
 "size_note": None,                   # gameplay reason when 5 to 15% off
 "origin": "base",                    # base (default), centre or free
 "sets": [{"name": "Bollard", "set": "Iron", "size": 1024, "wet": False}],   # T_Bollard_Iron_ALB ... in assets/textures/<Asset>/ (or "dir")
 "atlas": None,                       # name of the shared atlas when the class uses one
 "meshes": [{"object": lod0, "set": "Iron"}, {"object": col}],   # role and LOD come from the name suffix
 "attachments": [att],                # optional; default: empties named ATT* or parented to the meshes
 "waivers": {"LOD0 floor": "reason"}, # a failed check passes only with a logged reason
 "tiling": False, "lod_symmetry": None}
```

`dims.md` (R0): put one line `dims_m: <x> x <y> x <z>` (metres, `-` for a free axis) anywhere in the file.

## Verified (2026-10-17, Blender 5.2.2)

`selftest/run_selftest.sh`: a 0.35 x 0.55 m bollard (672 tris, LOD1 336, `_COL`, `ATT_RopeNeck`) validates (39 rows) and exports;
the FBX reads back with UnitScaleFactor 100 and axes (1, 1, 2, 1), as rbxkit writes them; a copy built in metres fails the size
check and exports nothing; LOD2 checked with the `large_prop` class. Not yet checked in Studio by this batch (B01's Spike 1 set).
