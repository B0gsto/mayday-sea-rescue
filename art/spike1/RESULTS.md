# Spike 1 results: Studio stage (B01, 2026-10-17)

Two scripted Studio sessions on TestBench-mayday-spike1 (a copy of the game place built by `tools/studio/smoke.py open`;
never saved, closed at the end; 4.1 and 2.3 min). Probes, raw data and captures are in `art/spike1/studio/`:
`setup.luau` (Edit probe), `probe_server.luau` (play-mode Script, normal game identity), `run_spike.py` / `run_spike2.py`
(drivers), `results_session1.json` / `results.json` (raw), `analyze.py` / `band.py` (Pillow + numpy), `captures*/`.
`assets.py refresh` before the run: all 12 images and 10 models **Approved**. Graphics: Studio on this Mac, Edit quality
`EditQualityLevel` forced from Automatic to **Level21** (put back to Automatic afterwards), `QualityLevel`, `SavedQualityLevel`
and `MeshPartDetailLevel` left on Automatic / DistanceBased. Captures are 1472 x 828.

## 1. Texture resolution actually displayed

Method: three clones of the test plane with one SurfaceAppearance each (1024 / 2048 / 4096 ALB, NOR, RGH, MET). World points
of the ALB zones came from the plane's EditableMesh UVs. Close-ups looked straight down at the 1-, 2- and 4-px checker zones
(FOV 10, 6 / 3 / 2 studs away, so one 4096 texel is 2.3 / 4.6 / 6.9 screen px). `band.py` takes the 2-D FFT of the central
512 px and reads the magnitude at the checker fundamental for one-texel cells at 4096 / 2048 / 1024 / 512, relative to the
median spectrum. Planes without detail at that frequency score about 4 to 110.

| Zone (plane) | Score at its own frequency (6 / 3 / 2 studs) | Reads as |
|---|---|---|
| 1-px checker, 1024 plane | 9,586 / 12,598 / 13,658 (1024 band) | full 1024 (reference) |
| 1-px checker, 2048 plane | 5,013 / 8,808 / 8,870 (2048 band); the 1024 plane scores 77 to 114 there | **full 2048** |
| 1-px checker, 4096 plane | 1,367 / 4,401 / 7,613 (4096 band); the 1024 plane scores 4 to 19 there | **full 4096** |
| 2-px / 4-px checker, 4096 plane | 5,203 (2048 band) / 11,568 (1024 band) at 6 studs | full detail |

| | Research said | Measured | Rule for us |
|---|---|---|---|
| Texture cap | 1024 or 4096 (the official page says both) | The engine **displays 4096** (and 2048) uploads at full detail in Studio (PC, Level21). The B01 finding that Asset Delivery serves every image at 1024 is a download-API thing only. `AssetService:CreateEditableImageAsync` returns **1024 x 1024 for all six ids tried** (ALB and NOR at each size), so EditableImage clamps and cannot tell you the stored size | `EXPORT_CAP = 4096` (= MASTER). Pick the size per asset from the texel tiers (05 section 5.3); 4096 only where a hero needs it |
| Phones, streaming, low quality levels | Downsizing reported | **Not measured** (no phone or emulator run, no low QualityLevel pass) | Open: run a memory and phone pass before shipping any 4096 set |

## 2. Triangles per MeshPart (EditableMesh from `MeshContent`, `#GetFaces()`)

| Exported | 9,990 | 19,990 | 20,500 | 21,500 | 30,000 |
|---|---|---|---|---|---|
| Faces in Studio | 9,990 | 19,990 | **19,905** | **19,896** | **19,826** |

Research said about 20 to 21k, reject or decimate disputed. Measured: **20,000 cap, enforced by silent decimation, never by
rejection.** Over-cap meshes also lose their split verts (10.1k verts against 59,970 at 19,990), which welds normals and UV
seams. Rule: keep at most 10,000 per MeshPart (working rule); `validate.py` must fail anything over 19,990, because Roblox
will not.

## 3. SurfaceAppearance

| Test | Measured | Rule for us |
|---|---|---|
| Four maps apply | ColorMap, NormalMap, RoughnessMap and MetalnessMap set from Edit (plugin identity) and read back; renders (item 1) | Importer path works |
| Script edits maps at runtime | `ColorMap`, `ColorMapContent` and `NormalMap` writes, and even a **read** of `ColorMap`, fail: "lacking capability Plugin". A new `SurfaceAppearance` cannot get maps either | No runtime map changes |
| Script edits `Color` / `AlphaMode` at runtime | Both **ok** from a server Script | `Color` tint is available for cheap wet darkening |
| Swap a stored SurfaceAppearance (wet state) | Server Script moves the old SA to ServerStorage and parents a clone of a pre-built SA: ok, the change replicates (the client sees `Swapped`, Color 1, 0.15, 0.15), and it **renders**: a play capture of the swapped plane reads R/G 1.55 against 1.00 / 0.95 for the untouched planes | Wet state = pre-built SA variants, swapped by parenting (as `import_asset.luau` stores them) |
| AlphaMode | Opaque, Overlay, Transparency and TintMask all settable (Edit and runtime). Visual effect not tested (the test ALB has no alpha) | Test with a real decal or fur card |
| SA on an EditableMesh MeshPart | `CreateMeshPartAsync(Content.fromObject(em))` plus a SA: renders the same as the asset plane (band scores within 0.3%). In play the part reaches the client with an empty MeshId; whether it renders there was not checked | Edit-time works; the ocean decision still needs a runtime (client-built) test |

## 4. Skinned meshes

Measured: `HasSkinnedMesh = true`. **20 and 40 `Bone` instances** are present; the EditableMesh reports 20 / 40 bones and
2,560 / 5,120 faces. Deformation: rotating a bone's `CFrame` in Edit changes the render. Pixel diffs against the rest pose
(two views): T20 Bone_10 0.38 to 0.46% of the frame; T40 Bone_10 0.34 to 0.81%; **T40 Bone_30 (second bone subset) 0.07 to
0.13%**, confined to the tip region. So both subsets deform. No bone limit was hit at 40 (a per-subset cap may sit below 40;
the importer splits subsets itself).

Orientation finding: the rig is lying down. The bone chain runs along world -Z (Bone_00 at z = 0, the last bone at z = -19,
Bone_00 WorldOrientation (-90, 0, 0)), and the Model's bounding box is 2 x 2 x 20, while the MeshPart Size is 2 x 20 x 2.
After `Model:PivotTo` the MeshPart itself reported Orientation (-90, 0, 0). Rule: check armature axes on the first real rig
(the dog), and stand rigs up in Blender or fix the export axes before rigging.

## 5. Scale, pivot, orientation, ATT_ empties

| | Measured | Rule for us |
|---|---|---|
| Scale | ScaleCube Size = MeshSize = 3 x 3 x 3; RefBox 1 x 5.5 x 1 (tall on Y) | 1 Blender unit = 1 stud, 1 m = 3 studs confirmed |
| Orientation | Static meshes import at (0, 0, 0), Blender Z up becomes Roblox Y up | No correction for static meshes |
| Pivot | The Model's WorldPivot sits at the Blender origin (cube 1.5 below its centre, RefBox 2.75, tentacle 10). The MeshPart PivotOffset is 0 for static meshes (centre) and (0, -10, 0) for the skinned one | Place Blender origins where the asset should pivot; use `Model:PivotTo` |
| ATT_ empties | **Untested**: no Spike 1 asset contains one (0 Attachments in every rbxm) | Open: one test FBX with an ATT_ empty; keep the marker-mesh fallback (the importer handles both) |

## 6. Tools

- `art/lookdev/shot-setup.luau`: runs without error in Edit and in the Client. `apply('Overcast', false)`, `('Storm', true)`,
  `('Night', false)`, `('Overcast', true)` and `('Clear', false)` all return. In Edit `ShowDevelopmentGui` goes false; in
  play all 10 PlayerGui ScreenGuis end up disabled. The wet swap works: ColorMap toggles between the dry and wet ids and the
  Configuration holds `SurfaceAppearance_Wet` / `_Dry`. `_G.LookDev.shot` locks the play camera, which the
  `screen_capture` camera_position does not do in play. No console errors in either session.
- `tools/studio/import_asset.luau`: runs clean on the test plane (1 SA, 1 wet variant, the `HasWetVariant` tag, no
  warnings). One wrong claim in it: "triangle counts are not readable from Luau". They are
  (`#AssetService:CreateEditableMeshAsync(part.MeshContent):GetFaces()`, item 2), so the report could give real counts.
  Not changed here.
- `EXPORT_CAP` is now 4096 (the cap); a new `common.SHIP_SIZE = 1024` is the default size for any set, sheet or sky face
  that does not ask for more (bake, validate, scan_ingest, flipbook, rope, texgen; `cubemap.py` keeps its tuned 1024). Tests updated.
