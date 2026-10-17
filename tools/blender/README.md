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

# the template scene (art/blender/_template.blend; run once, and after editing template.py or the HDRIs)
~/RobloxProjects/tools/blender-run.sh tools/blender/template.py
# turntable (8 EEVEE views + silhouette, about 5 s for a prop) -> <review>/<Asset>/turntable/
~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --asset <Asset> --steps build,lod,validate,export,turntable

# no heavy slot (system python3 + Pillow + numpy)
python3 tools/blender/sheet.py --asset <Asset> [--out-root build/x] [--studio <dir>] [--reference <photo>]   # 1536 px sheet
python3 tools/blender/check_textures.py assets/textures/<Asset>/ [--cap 4096] [--alpha] [--wet] [--signal-mask T_<Name>_<Set>=mask.png]
python3 -m unittest discover -b -s tools/blender -p 'test_*.py'
tools/blender/selftest/run_selftest.sh        # tests + the bollard end to end (2 short Blender runs) -> build/blender-selftest/
# bake one set fast (B01): masters at 512 instead of 4096
MAYDAY_BAKE_SIZE=512 MAYDAY_BAKE_SET=<Set> ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --asset <Asset> --steps build,lod,bake,validate
python3 tools/blender/scan_ingest.py --src <maps dir> --asset <Asset> --name <Name> --set <Set> --url <page> --author <a> --batch <Batch> [--wet] [--max-saturation 0.44]
```

## Steps (run.py)

`build, lod, bake, validate, export, turntable` always run in that order. `export` needs `validate` in the same run and
writes nothing when it fails; exit status 1 on any failure. `bake` / `turntable` call `bake.run(spec, report)` /
`turntable.run(spec, report, ok)` (skipped while a file is missing). The scene starts from
`art/blender/_template.blend` when it exists (`template.py`), else an empty factory scene. HDRIs: `art/blender/hdri/`,
credits in `art/blender/LICENCES.md`. Report:
`assets/review/<Asset>/<date>_report.json`. The `.blend` is saved next to `build.py`.

| File | Job |
|---|---|
| `common.py` | paths (12 1.3), `EXPORT_CAP` 4096 (max any map may be, Spike 1), `SHIP_SIZE` 1024 (default set / sheet / sky size until a phone memory test), `MASTER` 4096, 3 studs per metre, `dims.md` parser, image-size reader |
| `names.py` | name rules: `M_<Cat>_<Name>[_NN][_HP\|_LOD0\|_LOD1\|_LOD2\|_COL]`, `T_<Name>_<Set>_<ALB\|NOR\|RGH\|MET>[_Wet]`, `ATT_*`, `RIG_`, `A_`, `FX_`, `SFX_` |
| `budgets.py` | per-class LOD0 / per-MeshPart / LOD1 / LOD2 triangles, texture sets, `_COL` rule, texel tiers, size tolerances |
| `validate.py` | the checks (below); pure rule functions at the top |
| `versions.py` | `lod` step: `_LOD1` / `_LOD2` by bisected collapse decimation, UVs kept, weighted normals |
| `export.py` | one FBX per LOD via `rbxkit.export_fbx` (measured: `-Z` forward, `Y` up, `FBX_SCALE_UNITS`, scale 1; 1 unit = 1 stud; `roblox = (-bx, bz, by)`), read back; `_COL` goes in the LOD0 file; `<Name>.attachments.json` |
| `uvlayout.py` | UV stats, texel density, LOD layout comparison, island count |
| `texgen.py` | atlas shelf packing, bake margin, cap downsizing, texel maths |
| `template.py` | builds `art/blender/_template.blend`: metric scale 1 (1 unit = 1 stud), collection `Template` (5.5-stud `TPL_Mannequin`, `TPL_Water` at Z 0, dock lineup of vehicle footprints, palette swatches, `CAM_Template`), worlds `WLD_Neutral` / `WLD_OvercastSea` / `WLD_OvercastCoast` (`set_world`), EEVEE 768 px AgX. Never exported: no empties, export / validate only see the spec |
| `turntable.py` | `turntable` step: 4 angles (Front3Q, Side, Rear3Q, High) x neutral / overcast framed so the asset fills 70%+ of the cell (`MIN_FILL`; the mannequin may be cropped beside small props), PBR maps from the spec's sets, mannequin beside the asset; up to 6 close-ups `closeup_<name>.png` at 1024 px, hero distance (6 studs), neutral HDRI, from `spec["closeups"]` (`[{"name", "target": [x, y, z] Blender studs, "dist", "az", "el"}]`, `common.closeup_targets`; default: the 4 upper bbox corners + centre); `silhouette.png`, `turntable.json` with in-frame boxes and fill; restores the scene |
| `sheet.py` | 1536 px wide contact sheet (system python3): 384 px rows neutral, overcast, Studio presets (`*<Preset>*`, dry first; pending until shot), a detail row of the close-ups (3 per row, 512 px cells), then reference photo, 64 px silhouette, footer (tris, sets, size check, validate) |
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

B01 (2026-10-17): the bollard built from the template with `--steps build,lod,validate,export,turntable` validates (50 rows)
and exports as before; the turntable renders 8 views + silhouette at 768 px in about 3 s with the four placeholder maps
applied, asset and mannequin inside every frame; the same with `--no-template`. `sheet.py` fills 8/8 turntable cells and
the silhouette (outputs in `build/b01-turntable/`).

### B01 cubemap / rope / flipbook

| File | Job |
|---|---|
| `cubemap.py` | sky cubemaps (system python3): the five procedural presets moved from `art/ocean/bake_skies.py` (now a shim, same CLI, byte-identical faces), and HDRI mode: equirect `.hdr` (own RGBE reader) or `.exr` (convert in Blender first) -> `<Name>_<Bk\|Dn\|Ft\|Lf\|Rt\|Up>.png`, exposure, ACES / Reinhard / clip, `--sun-clamp auto`, `--yaw`, seam check, sun direction |
| `rope.py` | (Blender) rope tubes from centrelines (three-strand, braid, plain), flat coil, catenary hang, mooring line with eye, knotted net; U round / V along in trim tiles (`tiling`), `sides` + `max_tris` budget; procedural tiling trim `T_Rope_<Set>_ALB/NOR/RGH/MET` (pure numpy, passes `check_textures.py`) |
| `flipbook.py` | (Blender) sim -> 4x4 / 8x8 RGBA sheet at `--size` (default `SHIP_SIZE`), frames evenly sampled, `FX_<Group>_<Name>.png` + `.json`; demos: Mantaflow smoke puff, particle spray (each under 10 s) |
| `bake.py` | `bake` step: Cycles `_HP` -> `_LOD0` per set (NOR OpenGL, AO, curvature, thickness), `_ALB` from base colours + edge wear / salt / rust-streak masks, `_RGH` / `_MET` greyscale, `_Wet`; masters at the bake size (MASTER, `bake_size` / `MAYDAY_BAKE_SIZE`), maps at the set `size` (default SHIP_SIZE, at most EXPORT_CAP); one set a run (`only_set` / `MAYDAY_BAKE_SET`); no `_HP`: bakes from LOD0, flat NOR. Set fields in its docstring |
| `scan_ingest.py` | CC0 scan folder (Poly Haven / ambientCG) -> `T_` set: name mapping, DirectX -> OpenGL, ARM / ORM unpack, luma fit, optional `--max-saturation`, `_Wet`, licence row to `art/status/<Batch>.csv`; pure python3, or `--blend --object` in Blender to box-project onto our UVs |
| `pbrmaps.py` | pure numpy map maths shared by both (PNG writer, downsize, padding, UV coverage, wear masks, albedo fit, wet, flips) |

```sh
python3 tools/blender/cubemap.py [Preset ...] [--out DIR] [--size N]
python3 tools/blender/cubemap.py --hdri sky_1k.hdr --name Kloofendal --sun-clamp auto [--exposure EV] [--yaw DEG] [--out DIR]
~/RobloxProjects/tools/blender-run.sh tools/blender/cubemap.py -- --exr-to-hdr in.exr in.hdr
~/RobloxProjects/tools/blender-run.sh tools/blender/rope.py -- --demo --out build/b01-rope [--max-tris 2000]
python3 tools/blender/rope.py --trim-only --set Manila --profile three_strand --out <dir>
~/RobloxProjects/tools/blender-run.sh tools/blender/flipbook.py -- --demo smoke|spray [--grid 4|8] --out build/b01-flipbook
~/RobloxProjects/tools/blender-run.sh tools/blender/flipbook.py -- --blend X.blend --name FX_<Group>_<Name> --grid 8 [--frames A B]
```

### Import orientation (2026-10-17)

The FBX export is right (`roblox = (-bx, bz, by)`): uploaded Models arrive with every MeshPart upright and the Model
`WorldPivot` at the Blender origin. But the cloud importer keeps each FBX node's axis-conversion rotation in the MeshPart
`PivotOffset` (Orientation 90, 0, 0). `tools/studio/import_asset.luau` set `PrimaryPart`, which makes `GetPivot()` that
rotated part pivot, so `PivotTo(CFrame.new(x, y, z))` tipped the model 90 degrees (the RIB stood on its stern) and moved
config attachments with it. The importer now re-points every `PivotOffset` at the authored `WorldPivot` first: assets
land upright, forward -Z, pivot at the Blender origin. Regression: `tools/studio/import_test.luau` (synthetic B00
bollard with the importer's rotated PivotOffset, and the imported RIB's box: length on Z, height on Y), run by
`art/source/vehicles/M_Veh_RIB/studio_pass.sh`; `test_closeups.py` guards the fix in the source.
