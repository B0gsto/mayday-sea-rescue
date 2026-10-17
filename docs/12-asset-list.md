# 12 · Asset list (MVP, photoreal)

Every MVP art and audio asset for *Mayday: Sea Rescue*, how it gets made, what it may cost, and which agent batch builds it. **If an asset is not on this list, it does not get built.** To add one, add a row here first.

Who owns what:

- [Document 05](05-art-direction.md) owns the look, the budgets (section 5.6), texel density (5.3), the palette (3), the readability rules (9), the no-slop rules (10) and the sourcing rules (11). Budgets here are copied from 05 or set in its spirit; where they differ, 05 wins.
- [Document 06](06-tools-and-pipeline.md) owns the pipeline steps (section 2) and Spike 1, which settles every engine limit marked (verify) below.
- [Document 10](10-world-and-map.md) owns places, positions and scope tags; [document 09](09-rescue-operations.md), section 12, owns the equipment list; [document 11](11-dispatcher-and-voice.md) owns voice lines and the radio chain.
- `src/shared/Config/WorldConfig.luau` owns POI positions and footprints; `map/Build.luau` holds the greybox each asset replaces.

Marks: **(tune)** a first guess; **(verify)** a fact we could not confirm (engine limit, real dimension, licence). Real dimensions in this file are general knowledge unless a source is named, so **every real dimension is (verify) against the asset's reference board** (05 section 10.1) even where the mark is not repeated.

---

## 1. Pipeline and definition of done

### 1.1 What we take from Gulp

Gulp (`~/RobloxProjects/Gulp`) has a working headless Blender-to-Roblox pipeline: a one-command step runner, a budget table, a validator that fails the build, an exporter, LOD generation, an EEVEE preview and a Pillow contact sheet. It is built for a **stylized** game (vertex colours, palette snapping, outline shells, procedural fish bodies), so we port the skeleton and replace the art rules with PBR ones.

Mayday's library lives in **`tools/blender/`** in this repo (the repo already has `tools/`; [document 06](06-tools-and-pipeline.md), section 2.4, still says `scripts/blender/`, which does not exist; 06 should be updated to match).

| Gulp file (`assets/source/_shared/blender/`) | Action | What changes for Mayday |
|---|---|---|
| `run.py` (step runner, exit 1 on failure, nothing exported when validate fails) | **Port** | Steps become `build, lod, bake, validate, export, turntable`; drop `shell`; keep `clips` and `clips-rbxm` for rigged assets only. Per-asset spec gains `dims_m` (real size from the reference board), `tier` (hero / standard / background) and `sets` (texture sets). |
| `budgets.py` (triangle and bone table) | **Rewrite the table, keep the shape** | Rows from 05 section 5.6 (section 2 of this file adds land vehicles, props and vegetation). `MAX_PER_MESHPART = 10000`; `LOD_SHARE` per class (vehicles about 0.35 / 0.1, rocks 0.4 / 0.15, props 0.5 / cull). `RIG_MAX_BONES = 32` is too low for the dog and humans: set from Spike 1's skinned-mesh bone test (verify). |
| `validate.py` (names, budgets, mesh rules) | **Port and extend** | Keep the name regexes (new categories, 1.3), per-MeshPart and LOD budgets, bone and socket checks. Add: **real-size check** (bounding box against `dims_m` x 3 studs per metre, 5% pass, up to 15% with a note in the spec, fail beyond; 05 section 4.1), **one material per mesh** (verify), **UVs present on every LOD and identical layout across LODs**, **texel density** per tier (51 / 100 to 128 / 25 px per stud), **`_COL` proxy present** for vehicles and big props, **attachment empties named `ATT_*`**. Drop vertex-colour and palette-snap checks. |
| `export.py` | **Port, but take the axis and scale constants from `tools/blender/rbxkit.py`** | Gulp's `FBX_GLOBAL_SCALE = 0.01` with `FBX_SCALE_ALL` is marked unconfirmed in its own header. The shared `rbxkit.py` records a **measured** mapping: FBX `axis_forward='-Z'`, `axis_up='Y'`, `FBX_SCALE_UNITS`, global scale 1, so **1 Blender unit = 1 stud** and `roblox = (-bx, bz, by)`. Use `rbxkit.export_fbx`. Rigged assets export with the armature. |
| `versions.py` (LOD and shell) | **Port the `lod` step only** | Collapse decimation to `_LOD1` / `_LOD2` with UVs preserved (same texture sets), weighted normals re-applied; remove the vertex-colour snap and the whole `shell` step. |
| `uvlayout.py` | **Port** | Becomes the texel-density and UV-island checker for PBR sets; drop the creature family layout. |
| `texgen.py` | **Port the rectangle maths** | Atlas packing for the shared prop, kit and foliage atlases. `MAX_TEXTURE = 1024` becomes `EXPORT_CAP` read from one constant (1024 until Spike 1), with `MASTER = 4096`. Drop placeholder stamping. |
| `preview.py` + `sheet.py` | **Port** | Becomes `turntable.py`: 4 angles under the neutral studio HDRI and the overcast sea HDRI, PBR maps applied, next to the 5.5-stud avatar mannequin. `sheet.py` lays out the contact sheet in system `python3` with Pillow: 4 turntable cells, 4 Studio preset cells (added after the Studio pass, 1.4), 1 reference photo, the 64 px silhouette (05 section 10.3 step 4) and a footer with tris, sets and size check. Saved at 768 px for review. |
| `template.py` | **Rewrite** | Builds `art/blender/_template.blend` per 06 section 2.1 step 2: 1 unit = 1 stud, the 5.5-stud mannequin, a water plane at Z 0 (Blender up), the dock lineup of every vehicle's real footprint, the two HDRIs, the reference palette as swatches. |
| `common.py` | **Port** | Paths for this repo (1.3); drop species and fog-zone constants. |
| `weightcheck.py`, `rigs.py`, `clips.py`, `animrbx.py`, `clipsheet.py`, `clips_selftest.py` | **Port for the dog and NPCs only** | R15-compatible human skeleton and the Bosun quadruped rig; clips written as `KeyframeSequence` .rbxm with no Studio click. Max 4 weights per vertex. |
| `test_validate_names.py` | **Port** | Tests for the new names. |
| `palette.py` | **Replace** | With `tools/blender/check_textures.py` (06 section 2.1 step 13): albedo sRGB 30 to 240 on non-metal pixels, metal albedo 180 to 250, saturation ceiling about 45% outside signal masks, OpenGL normal (green-channel test), single-channel roughness and metalness, size at or under `EXPORT_CAP`, suffix names. |
| `fishbody.py`, `fishshape.py`, `mouth.py`, `preyart.py`, `meshgen.py`, `placeholder*.py`, `tilegen.py` | **Do not port** | Stylized and fish-specific. |

**New files with no Gulp equivalent** (all in `tools/blender/`):

| File | Job |
|---|---|
| `bake.py` | Cycles bake `_HP` to `_LOD0`: tangent-space normal (OpenGL), AO, curvature, thickness; composes `_ALB` from measured or scanned base colours plus mask-driven wear (edge wear, salt crust, rust streaks; 05 section 5.4; no random grunge), writes `_RGH` and `_MET` single-channel, and the `_Wet` variants (albedo about -25% value, roughness about -0.3; tune). Masters at 4096, then downsized to `EXPORT_CAP`. One run per texture set so no run passes the 10-minute heavy-slot cap. |
| `flipbook.py` | Renders a Blender fluid, smoke or particle sim to a 4x4 or 8x8 sheet at `EXPORT_CAP` (06 section 2.4). |
| `cubemap.py` | HDRI to six `Sky` faces. Already prototyped as `art/ocean/bake_skies.py`; move it here. |
| `scan_ingest.py` | Imports a CC0 scan (Poly Haven, ambientCG), converts maps to our suffixes, flips DirectX normals to OpenGL, re-bakes to our UVs and writes the licence row (1.5). |
| `rope.py` | Generates rope, coils, nets and lines from curves (three-strand and braid profiles) with a tiling rope trim; used by the harbour, Chandlery and kit batches. |
| `tools/studio/import_asset.luau` | Studio side: given the `.rbxm` that `tools/assets.py` downloads back, adds a `SurfaceAppearance` per MeshPart from the uploaded map ids, converts `ATT_*` markers to `Attachment`s (empties may not survive the importer; verify, fall back to marker meshes), sets `CollisionFidelity`, `RenderFidelity` (05 section 5.6), `CastShadow` off on tiny parts, and saves the model as a Package. |

**Shared tools used as they are** (`~/RobloxProjects/tools/`):

- `blender-run.sh <script.py> -- args`: headless Blender 5.2 (`--background --factory-startup -noaudio --python-exit-code 1`) inside one slot of the 2-slot machine-wide heavy pool (`with-heavy.sh`, FIFO), with a second guard that waits while 2 Blender processes are already running. **Every Blender job in every batch goes through it.**
- `tools/blender/rbxkit.py`: measured axis helpers, `export_fbx`, emissive bake helpers, `ROBLOX_TRI_LIMIT = 20000`.
- `assets.py`: Open Cloud upload with a sha256-keyed manifest (`assets/manifest.json`, already in use for the ocean maps). FBX uploads come back as `assets/models/<name>.rbxm`; PNG uploads give an Image id usable directly in `SurfaceAppearance` and `MaterialVariant`. Re-uploading identical bytes is a no-op; manifest writes are locked, so parallel agents are safe. `sync` reads `art/assets.json`.
- `with-lock.sh studio -- ...`, `studio-shot.py` (shots JSON to contact sheet), `studio-insert.py`: the in-engine screenshot pass (1.4).
- `audio-search.py`: searches and verifies licensed public Roblox audio (section 4).

### 1.2 What changes for photoreal PBR

- **SurfaceAppearance maps.** Every mesh ships `ColorMap` (`_ALB`), `NormalMap` (`_NOR`, OpenGL, tangent space), `RoughnessMap` (`_RGH`) and `MetalnessMap` (`_MET`); alpha assets (foliage, fur cards, decals, nets) add `AlphaMode` Transparency or Overlay (verify sorting and cost). Hero assets with a wet state ship a second `SurfaceAppearance` with `_Wet` maps for the runtime swap (verify that a swap is allowed; 06 section 2.2).
- **1024 versus verify-4096.** The official texture page states both caps (05 section 5.1). Author every master at **4096** in `art/`, export at **1024** to `assets/textures/` until Spike 1 measures 2048 and 4096 on a phone. The cap is one constant (`EXPORT_CAP` in `tools/blender/common.py`); re-exporting the whole library at a new cap is one scripted run, no re-authoring. Hero close-up assets (the arms, jet ski close-up set, RIB console, the dog's head, Aggie's head) are laid out so they can take 2048 if Spike 1 allows.
- **LODs.** `_LOD0`, `_LOD1`, `_LOD2` share UVs and texture sets. Vessels, land vehicles and the dog get custom LOD models swapped by `LodController` with hysteresis; buildings, rocks and props use `RenderFidelity` Automatic (switch distances 250 and 500 studs are from snippets only; verify); far objects use Performance. Islands and the Harbor Light get Persistent low proxies (10 section 6.3).
- **Trim sheets and MaterialVariants** replace unique textures on anything repeated: building kits, quays, rails, rub strakes, window frames. Terrain and big surfaces use the MaterialVariant library (batch B02), each with a wet twin.
- **Collision.** Visual meshes `CanCollide = false`; `_COL` boxes or hulls do physics on vehicles and large props.

### 1.3 Folders and names

| What | Where |
|---|---|
| Reference board (10 to 20 photos, `dims.md` with sources) | `art/reference/<Asset>/` |
| Build script, spec, `.blend` masters, 4096 maps | `art/source/<kind>/<Asset>/` (`kind` = vehicles, buildings, harbour, roads, veg, rocks, seabed, kit, characters, animals, fx) |
| Exported FBX | `assets/fbx/<Asset>/` |
| Exported maps at `EXPORT_CAP` | `assets/textures/<Asset>/` |
| Downloaded engine models | `assets/models/<Asset>.rbxm` (written by `tools/assets.py`) |
| Contact sheets, validate reports, art-director verdicts | `assets/review/<Asset>/` |
| Per-batch status | `art/status/<Batch>.csv` (`asset, priority, status, assetId, source, licence, ai_used, reviewer, notes`); one file per batch so parallel agents never share a file |

Names (adapted from Gulp's chapter 07 section 1.2; PascalCase words, no spaces or hyphens):

| Kind | Pattern | Examples |
|---|---|---|
| Mesh | `M_<Cat>_<Name>[_NN][_HP\|_LOD0\|_LOD1\|_LOD2\|_COL]` | `M_Veh_RIB_LOD0`, `M_Bld_Cottage_Wall_02_LOD1`, `M_Prop_Bollard_01_COL` |
| Texture | `T_<Name>_<Set>_<ALB\|NOR\|RGH\|MET>[_Wet]` | `T_RIB_Hull_ALB`, `T_RIB_Hull_RGH_Wet` |
| Rig / clip | `RIG_<Name>`, `A_<Rig>_<Action>` | `RIG_Bosun`, `A_Bosun_SwimTow` |
| Effect, sound | `FX_<Group>_<Name>`, `SFX_<Group>_<Name>[_NN]` | `FX_Spray_BowSheet`, `SFX_Eng_RIB_Plane` |

Categories: `Veh` (vehicles and operation craft), `Bld` (buildings and building kits), `Hbr` (harbour structures and props), `Road`, `Veg`, `Rock`, `Sea` (seabed), `Kit` (rescue kit), `Chr` (characters), `Ani` (animals), `Prop` (generic dressing).

### 1.4 Definition of done (per asset)

An asset is **done** only when every box is ticked in its `art/status/<Batch>.csv` row and the evidence is in `assets/review/<Asset>/`:

1. **Reference board** in `art/reference/<Asset>/` with 10 to 20 real photos (shape, detail, materials, wear, wet weather) and `dims.md` giving the real class and dimensions with a source link (manufacturer or class page; (verify) where only general knowledge exists).
2. **Real dimensions checked**: `validate` passes the size check against `dims_m` (5% free, up to 15% with a written gameplay note, never more), and the turntable shows it beside the 5.5-stud mannequin.
3. **Triangle budget**: LOD0 total, per-MeshPart (10,000 or fewer) and LOD1 / LOD2 within the row's budget; `validate` passes.
4. **Texture budget**: the number of sets and their size match the row; maps at `EXPORT_CAP` for shipping, 4096 masters kept.
5. **PBR maps present**: `_ALB`, `_NOR`, `_RGH`, `_MET` for every set (plus `_Wet` where the row says wet), and `check_textures.py` passes.
6. **Turntable render**: 4 angles, neutral and overcast-sea HDRI, with the reference photo and the 64 px silhouette on one 768 px contact sheet.
7. **In-engine screenshot**: imported through `tools/assets.py` and `import_asset.luau`, shot in Studio in Clear, Overcast, Storm and Night (dry and wet for hero assets), at High and with the Low quality / phone frame (05 section 10.3 steps 5 and 6), added to the same contact sheet.
8. **Art-director pass**: a fresh, short-lived Sonnet reviewer sees only the contact sheet, 05 (sections 3, 5, 9, 10) and the asset brief, and returns `pass` or at most 5 fixes. The question is "does this look real next to the photo?". Hero assets need a pass in all four presets; filler props in Overcast only.
9. **Recorded**: asset ids in `assets/manifest.json` (via `tools/assets.py`), the status row filled with source, licence, author, date and **AI used: none / concept only / assisted** (05 section 10.2), and credits noted for any CC0 or commissioned work.
10. **Readability** (casualties, hazards, nav marks, the objective): the section 9 checks of 05 pass on a phone-size Overcast screenshot.

### 1.4a Fidelity bar (set by the wave 1 sign-off, 2026-10-17)

Every later batch must meet all five before sign-off:

- **Reference-matched livery and colour.** A same-light side-by-side with the reference photo shows shape, palette and decals within one step.
- **Wear and detail at 2 m.** Every hero asset has wear, salt staining, visible fasteners, seams and fittings at 2 m camera distance. No smooth plastic planes.
- **Distinct materials.** Each material has its own roughness and metalness; fabric, rubber, paint and metal are distinguishable in the maps.
- **Form reads in all four presets.** No pure black or pure white albedo (keep albedo roughly 20 to 240 sRGB); Night shows detail under practical lights.
- **Studio evidence first.** Dry and wet in-engine shots with no artefacts (alpha ghosting, z-fighting), on a neutral backdrop at hero distance, scoring at least 5/10 against the photo. The bar rises as the art improves.

### 1.5 Sourcing rules (from 05 section 11)

- **Blender model + bake** (owned) is the default for every hero asset and anything with a real class to match.
- **CC0 scans**: Poly Haven and ambientCG (CC0 per research; confirm on each site's licence page and log the asset URL). Used for rocks, ground, stone, wood, metal and paint materials, HDRIs and some props. Quixel / Fab is **not used** until its licence is checked for Roblox upload (unverified).
- **Sketchfab**: CC0 or CC-BY with credit only, never NC or ND, re-textured to pass every check.
- **Commission**: written work-for-hire with full rights transfer and a no-AI clause. Listed below as an option where a person's face or a quadruped's animation would otherwise be the risk.
- **Creator Store**: filler props at most, scripts stripped, sandboxed; never hero assets. **AI**: reference and concept only; nothing AI-made ships untouched.

---

## 2. MVP assets

**Priority:** **P0** needed for the first public test (the cold open, Operation 1 Person in the Water, Operation 2 Disabled Vessel, the station, the Chandlery, Haven Sands); **P1** before the public launch of the MVP map (the big call, the rest of the town); **P2** later. Where this differs from a document 10 scope tag, the note says why.

**Source codes:** **BL** Blender model + bake (owned); **SC** CC0 scan (PH = Poly Haven, ACG = ambientCG; CC0, confirm per asset); **BL+SC** Blender model textured or detailed from CC0 scans; **CM** commission (work-for-hire, no-AI clause); **MPFB** MakeHuman / MPFB2 base mesh (output CC0 per MakeHuman; asset packs mix CC0 and CC-BY, use CC0 only; verify).

Budgets are LOD0 / LOD1 / LOD2 triangles and texture sets at `EXPORT_CAP` (1024 until Spike 1). "Atlas" means a shared set listed in batch B02 or the batch that owns it.

### 2.1 Hero vehicles

| Asset | Real-world reference (class, dimensions) | Source | Budget | Pri | Batch |
|---|---|---|---|---|---|
| `M_Veh_JetSki` + rescue sled | Three-seat rescue PWC, about 3.4 x 1.2 m (10.2 x 3.6 studs) per 05; rear rescue sled board with 6 handles about 2.0 x 1.2 m (verify) | BL | 20,000 / 8,000 / 2,000; 2 sets (hull, sled and fittings) + `_Wet`; livery decal mesh | P0 (cold open) | V1 |
| `M_Veh_JetSki_CloseUp` | Bars with grips, kill-switch lanyard, throttle, mirrors, console (speed, fuel, compass), VHF in a clip (05 section 8.5) | BL | 8,000 on top of the jet ski; 1 set, laid out for 2048 (verify) | P0 | V1 |
| `M_Veh_RIB` | Atlantic 85-style inshore lifeboat: about 8.4 m LOA, 2.85 m beam (25 x 8.5 studs) per 05; grey tube collar with rub strakes, A-frame with lights and radar, twin outboards (about 115 hp each, verify); generic details, not a replica | BL | 35,000 / 12,000 / 3,000; 4 sets (hull and tubes, deck and console, A-frame and engines, decals) + `_Wet` | P0 (first production asset, sets the fidelity bar; 06 section 7 step 17) | V2 |
| `M_Veh_RIB_Helm` | Console with wheel, throttles, compass, chartplotter, VHF, grab handles, seats (jockey pods) | BL | 15,000; 2 sets | P0 | V2 |
| `M_Veh_LifeguardPickup` | Double-cab lifeguard pickup (Hilux / Ranger class): about 5.3 m L, 1.85 m W, 1.8 m H (16 x 5.6 x 5.4 studs) (verify); light bar, board rack, kit lockers, tow hitch; invented livery | BL | 30,000 / 12,000 / 3,000 (tune, not in 05's table); 4 sets (body, cab interior and glass, wheels and underbody, rack and light bar); 4 separate wheel meshes | P0 | V3 |
| `M_Veh_Ambulance` | UK box-body paramedic ambulance on a 3.5 to 5 t van chassis (Sprinter / Ducato class): about 6.8 m L, 2.3 m W, 2.9 m H (verify); invented "Gale Isles Ambulance" livery, **no cross emblem**, invented chequer (verify that the chequer pattern carries no protection) | BL | 30,000 / 12,000 / 3,000; 4 sets; rear doors closed (no interior until [P1]) | P1 (10 section 7 says "cut if the MVP slips") | V4 |
| `M_Veh_Coastguard4x4` | Coastguard rescue team 4x4 (Defender 110 / pickup class, about 4.6 to 5.3 m L; verify against HM Coastguard team vehicles); cliff rope kit, floodlight mast | BL | 30,000 / 12,000 / 3,000; 4 sets | P2 (10: [L]) | V5 |
| `M_Veh_BoatTrailer_RIB`, `M_Veh_BoatTrailer_JetSki` | Twin-axle braked trailer for an 8.5 m RIB (about 9.5 m overall with drawbar) and a single-axle PWC trailer (about 4.5 m) (verify) | BL | 8,000 / 4,000 / 1,000 each; 1 set + galvanised trim | P2 | V5 |
| `M_Veh_ATV` + beach sled | Lifeguard quad (420 to 700 cc class): about 2.1 x 1.2 x 1.2 m (verify); rescue board and tube rack; towed casualty sled about 2 m | BL | 15,000 / 6,000 / 1,500; 2 sets; sled 2,000 | P2 (10: [L]) | V5 |

**Operation craft** (not in the brief's list, but Operations 1 to 3 cannot run without them):

| Asset | Real-world reference | Source | Budget | Pri | Batch |
|---|---|---|---|---|---|
| `M_Veh_Optimist` | Barnaby's *The Optimist*: a 7 m wooden or GRP motor fishing boat with a small wheelhouse, samson post and stern cleats (Op 2 attachment points) (tune) | BL | 25,000 / 10,000 / 2,500; 3 sets, heavier wear (05 section 5.4) | P0 (Op 2) | C1 |
| `M_Veh_Kayak`, `M_Veh_Paddleboard` | Sit-on-top kayak about 3.0 to 3.5 m; inflatable SUP about 3.2 x 0.8 m (verify) | BL | 3,000 and 1,500; shared craft atlas | P0 (Op 1 casualty context) | C1 |
| `M_Veh_Liferaft` | SOLAS 6 to 12 person canopied liferaft, about 2.5 to 3.5 m diameter (verify); SOLAS orange canopy, retro tape, boarding ramp | BL | 6,000 / 2,500 / 800; 1 set + `_Wet` | P1 (Op 3) | C2 |
| `M_Veh_GaleQueen` | *Gale Queen*: small island ro-pax ferry about 40 to 50 m (tune), shown capsized on her side and upturned; hull grab lines for the hull team, compartments to knock on | BL | 90,000 / 30,000 / 8,000; 6 to 8 sets + trim (05 big-call row) | P1 (Op 3 is a storm big call; 06 section 7 step 15 schedules it after the MVP playtest) | C2 |
| `M_Veh_MooredBoat_01` to `_03` | Set dressing: a punt (about 4 m), a crabber (about 10 m), a small trawler (about 15 m) (tune) | BL | 12,000 / 25,000 / 30,000 LOD0, aggressive LOD; shared fishing-boat atlas | P1 | C3 |

### 2.2 Buildings

| Asset | Real-world reference | Source | Budget | Pri | Batch |
|---|---|---|---|---|---|
| `M_Bld_Station` (boathouse, crew room, changing room and lockers, kit store, Aggie's office, honour board, lookout) | RNLI-style boathouse and crew facility in granite and slate; greybox footprint 60 x 50 studs, 26 studs high (about 20 x 17 x 8.7 m); compound about 120 x 80 m (10 section 1.2) | BL+SC (granite, slate from PH / ACG) | Hero: exterior 40,000 / 15,000 / 3,000; interior 30,000 (streamed); 4 sets + building trim sheet | P0 | H1 |
| `M_Bld_Slipway` + winch house + bay doors | Concrete inshore slipway with steel launch rails, about 5 m wide at about 1:6 (verify), weedy wet lower section; boathouse roller doors; bow winch | BL + MaterialVariant | 8,000; concrete and weedy-concrete variants (B02) + 1 set | P0 | H1 |
| `M_Bld_Chandlery_Ext` | Granite and slate shopfront, 20 x 12 m, two floors (10 section 1.2): painted fascia, deep bay window, hanging sign, chalk board | BL+SC | 25,000 / 10,000 / 2,500; 2 sets + building trim | P0 (the store) | H2 |
| `M_Bld_Chandlery_Int` | Pine floorboards, tongue-and-groove walls, beams, counter with brass till, chart table, labelled drawers, loft fitting room with mirror, dog basket, skylight (05 section 4.3) | BL | Hero interior 40,000; 4 sets + trim | P0 | H2 |
| `M_Prop_Chandlery_*` (about 30 props) | Rope coils (three-strand, braid), shackles and blocks, fenders and buoys from the beams, lifejackets and drysuits on rails, mannequins, product tags, swatch and horn boards | BL (`rope.py`) | 30,000 total; 1 shared chandlery prop atlas | P0 | H2 |
| `M_Bld_Harbourmaster` | Small granite office, about 10 x 8 m (10 section 1.2), storm queue board in the window | BL, kit-based | 15,000 / 6,000 / 1,500; kit trim + 1 set | P1 exterior (it stands on the quay next to the Chandlery); P2 interior (10: desk [L]) | H4 |
| `M_Bld_BoatyardShed` + `M_Hbr_TravelHoist` + cradles and stands + fuel dock pumps + price board | Steel-framed boat shed about 30 x 15 m, about 9 m eaves (verify); 35 t-class travel hoist about 8 m wide, 9 m tall (verify); yard 80 x 50 m | BL+SC | Shed 20,000; hoist 15,000; cradle 2,000 each; pumps 3,000; shared yard atlas | P1 | H4 |
| `M_Bld_Cottage_Kit` (walls, corners, windows, doors, roofs, chimneys, gutters, downpipes, porches, steps, garden walls; about 25 pieces) | Cornish granite and render fisherman's cottages and painted terraces: about 5 to 6 m frontage, 7 to 8 m deep, two storeys, about 5 m to the eaves, 0.5 to 0.6 m walls (verify) | BL+SC | 3,000 to 8,000 per module, LOD1 50%; 1 building trim sheet + render, granite, slate MaterialVariants | P0 kit | H3 |
| `M_Bld_Cottage_01` to `_10` (assembled variants) | 6 variants for the harbour front and Chapel Hill (render colours within the saturation ceiling, granite, slate-hung), 4 more for the edges | Assembled from the kit | 25,000 to 40,000 per house from modules | 6 at P0, 4 at P1 | H3 |
| `M_Bld_Hospital` + ambulance bay canopy + pontoon | Small cottage hospital, two storeys, about 30 x 15 m (tune); greybox 60 x 40 studs. **Replace the greybox's red cross (`CrossV`, `CrossH` in `map/Build.luau`)**: the emblem is legally protected (05 section 4.2); use an invented sign | BL, kit-based | 35,000 / 14,000 / 3,000; kit trim + 2 sets | P1 (drop-off works on the greybox for the first test) | H5 |
| `M_Bld_HarbourLight` | Round white-painted or granite pier light on the east wall head, about 12 m (tune; 05 gives 10 to 25 m), lantern, gallery, real light characteristic (05 section 6.3) | BL+SC | 20,000 / 8,000 / 2,000 + Persistent proxy 500; 2 sets + emissive lens | P0 (MVP lighthouse history) | H6 |
| `M_Bld_LifeguardTower` | Raised beach lifeguard hut on legs: cabin about 3 x 3 m, deck about 3 m up (verify against RNLI lifeguard units), flagpole, rescue board rack | BL | 12,000 / 5,000 / 1,200; 2 sets | P0 | H6 |
| Town extras: fish market, Nell's bait kiosk, ferry pier and ticket booth, Haven Sands café and toilets, chapel | Real vernacular (10 section 2.4) | Kit-based BL | 10,000 to 25,000 each | P1 (chapel P2) | H7 |

### 2.3 Harbour structures and props

All small props share one **harbour prop atlas** (2 sets: metal and rope/plastic) unless noted.

| Asset | Real-world reference | Source | Budget | Pri | Batch |
|---|---|---|---|---|---|
| `M_Hbr_QuayKit` (quay wall, edge copings, granite steps, wall head, breakwater rock armour) | Granite block quay walls, Cornish harbours; quay edge coping about 0.6 m, steps 0.3 m risers (verify) | BL+SC (PH granite scans) | 5,000 to 10,000 per piece; MaterialVariants + 1 trim | P0 | HP1 |
| `M_Hbr_Pontoon` (straight, corner, gangway, finger) | Floating marina pontoon, about 2.4 m wide, 6 to 12 m sections, about 0.5 m freeboard (verify) | BL | 3,000 per section; 1 set | P0 (Op 2 berth) | HP1 |
| `M_Hbr_Ladder` | Galvanised quay ladder, about 0.45 m wide, recessed, weed and rust at the bottom | BL | 1,500; atlas | P0 | HP1 |
| `M_Hbr_Bollard_01` to `_03` | Cast-iron harbour bollards, about 0.5 to 0.6 m tall, 0.35 m diameter (verify); rope wear | BL | 800 each; atlas | P0 | HP2 |
| `M_Hbr_Cleat_01` to `_02` | Galvanised mooring cleats 0.3 to 0.45 m (verify) | BL | 400 each; atlas | P0 | HP2 |
| `M_Hbr_Fender_*` (cylindrical 3 sizes, ball, tyre fender on the quay) | Cylinder fenders about 0.2 x 0.6 m to 0.3 x 1.0 m, ball fender about 0.6 m (verify); **shared with the kit fenders (2.8)** | BL | 600 to 1,200 each; atlas | P0 | HP2 |
| `M_Hbr_MooringBuoy`, `M_Hbr_PickupBuoy` | Mooring buoys 0.6 to 1.0 m diameter (verify), chains | BL | 1,500; atlas | P0 | HP2 |
| `M_Hbr_NavMark_*` (port can, starboard cone, four cardinals, isolated danger, bell buoy) | IALA Region A buoyage (verify colours and topmarks against IALA); pillar buoys about 3 to 5 m tall (verify) | BL | 3,000 each; 1 set; real lights | P0 (hazard readability, 05 section 9) | HP2 |
| `M_Hbr_LobsterPot_01` to `_02`, `M_Hbr_FishBox`, `M_Hbr_NetPile` | Inkwell pot and parlour creel about 0.8 x 0.5 x 0.4 m (verify); fish boxes; heaped trawl net (alpha cards) | BL (`rope.py`) | 1,500 to 3,000; atlas | P0 | HP2 |
| `M_Hbr_Rope_*` (coils, flaked lines, mooring lines in catenary, chain) | Three-strand and braid, 12 to 24 mm (verify) | BL (`rope.py`) | 500 to 2,500; rope trim | P0 | HP2 |
| `M_Hbr_LifebuoyStation` | Quay lifebuoy housing with a 0.75 m ring (05 section 4.1) and throw line | BL | 1,500; atlas | P0 | HP2 |

### 2.4 Roads and street furniture

| Asset | Real-world reference | Source | Budget | Pri | Batch |
|---|---|---|---|---|---|
| `M_Road_Ribbon` profiles (Harbour Road 6 m, Coast Road 6 m, track) + kerbs + PBR decal lines and cat's eyes | UK roads, white and yellow lines (verify markings) | BL generator + ACG asphalt and cobble scans (CC0) | Spline-generated ribbons, about 200 tris per 10 m; MaterialVariants + 1 decal set | P0 | R1 |
| `M_Road_StreetLamp`, `M_Road_Bench`, `M_Road_Bin`, `M_Road_Bollard` | Town lamps about 5 to 6 m (warm sodium / LED), benches 1.8 m | BL | 800 to 2,500; street atlas | P0 | R1 |
| `M_Road_Sign_*` (invented UK-style signs, fingerpost, tide board, launch sign, car park sign, cliff warning) | UK sign proportions (verify), no real sign copies | BL + vector art | 300 to 1,500; sign atlas | P0 | R1 |
| `M_Road_CrashBarrier`, `M_Road_FieldGate`, `M_Road_CornishHedge`, `M_Road_DryStoneWall` | W-beam barrier about 0.7 m high; five-bar gate about 3.6 m; Cornish hedge about 1.5 m; dry-stone wall about 1.2 m (verify) | BL+SC | 1,000 to 6,000 per 5 m piece; trim + MaterialVariant | P0 (Haven Head road) | R1 |
| `M_Road_BeachFlags` | Red-and-yellow and black-and-white chequered beach flags (verify meanings with RNLI) | BL (cloth sim baked) | 600; atlas | P0 | R1 |
| `M_Road_ParkedCar_01` to `_03` | Generic hatchback, estate, van (not replicas) | BL | 15,000 / 6,000 / 1,500 each; 2 sets | P1 | R1 |

### 2.5 Vegetation

Two foliage atlases (land, marine), alpha cards with `AlphaMode` Transparency (verify sorting and cost). Wind sway by script or bones (verify skinned cost); no sway at Low.

| Asset | Real-world reference | Source | Budget | Pri | Batch |
|---|---|---|---|---|---|
| `M_Veg_Grass_*` (coastal turf tufts, marram for the dunes) | Coastal grass, marram 0.5 to 1.2 m (verify) | BL + PH CC0 grass scans | 300 to 1,500 per clump; land atlas | P0 | G1 |
| `M_Veg_Gorse_01` to `_03` | European gorse bushes 1 to 2 m, yellow flowers | BL | 3,000 to 6,000; land atlas | P0 | G1 |
| `M_Veg_Heather_01` to `_03` | Ling and bell heather 0.2 to 0.5 m | BL | 1,000 to 2,000; land atlas | P0 | G1 |
| `M_Veg_SeaThrift_01` to `_02` | Thrift cushions 0.1 to 0.3 m with pink heads (keep under the saturation ceiling; tune) | BL | 300 to 800; land atlas | P0 | G1 |
| `M_Veg_Kelp_01` to `_04` | Laminaria (forest kelp), stipe 1 to 2 m (verify) for Old Ned's gully and the Haven Head beds (WorldConfig `KelpBeds`) | BL | 2,000 to 4,000 per plant, instanced; marine atlas | P0 | S2 |
| `M_Veg_Wrack_*` (seaweed on rocks: bladder wrack, egg wrack, decal-mesh mats) | Intertidal wracks in the splash zone | BL + PH scans | 500 to 2,000 per mat; marine atlas | P0 | S2 |
| `M_Veg_Eelgrass_*` | Seagrass meadow, Calm Bay (WorldConfig `Eelgrass`) | BL | 300 per card cluster; marine atlas | P1 | S2 |

### 2.6 Rocks and cliff kit

| Asset | Real-world reference | Source | Budget | Pri | Batch |
|---|---|---|---|---|---|
| `M_Rock_Cliff_01` to `_08` (Haven Head faces, 40 m headland) | Cornish granite cliffs, joint-block structure | SC (PH and ACG CC0 rock scans) + BL sculpt and bake | 5,000 to 15,000 / 40% / 15%; 1 unique set each + tiling detail | P0 | K1 |
| `M_Rock_Boulder_01` to `_06`, `M_Rock_Ledge_01` to `_04` (shore, rock pools, reefs) | Granite boulders and wave-cut ledges, splash-zone wet | SC + BL | 2,000 to 8,000; 1 set per two pieces + detail | P0 | K1 |
| `M_Rock_NeedlesEye` | The Needle's Eye granite arch over Old Ned's gully (WorldConfig `GullyArch`: 30 x 60 studs) | BL sculpt from scans | 12,000 / 5,000 / 1,500; 1 set | P0 | K1 |
| `M_Rock_RockPool_*` + rock pool life (anemones, crabs, blenny, starfish) | Haven Sands rock pools (WorldConfig `HavenSandsRockPools`) | SC + BL | Rocks 3,000 to 6,000; life 500 to 2,000 each; 1 atlas | P0 rocks, P1 life | K1 |
| `M_Rock_IslandProxy_*` | Persistent far proxies for headlands and islets (10 section 6.3) | BL bake from the heightmap | 1,000 to 3,000 each; 1 baked colour set | P1 | K1 |

### 2.7 Seabed

| Asset | Real-world reference | Source | Budget | Pri | Batch |
|---|---|---|---|---|---|
| `M_Sea_Morwenna` (oak ribs, keel, stem and sternpost, strakes, windlass, chain, the bell) | 1902 wooden two-masted trading schooner, 25 to 35 m class (verify); WorldConfig footprint 84 x 21 studs (28 x 7 m) at 7 m depth; replaces `buildSchooner` | BL + PH wood scans | 30,000 / 12,000 / 3,000 (ribs instanced); 2 sets (wreck wood, iron and bronze) + kelp and silt overlay | P0 | S1 |
| `M_Sea_Bell` | Ship's bell, about 0.3 to 0.4 m (verify), verdigris | BL | 1,500; shared wreck set | P0 | S1 |
| `M_Sea_AdmiraltyAnchor` | 1840s Admiralty-pattern anchor; WorldConfig gives 15 x 9 studs (5 x 3 m), which is a large-ship anchor (verify; shrink if the reference says so); replaces `buildAnchor` | BL | 4,000 / 1,600 / 400; 1 set (wrought iron, concretion) | P0 | S1 |
| `M_Sea_MailSeaplane` | Generic 1960s single-engine floatplane, Otter class about 12.8 m long, 17.7 m span (verify); WorldConfig 39 x 50 studs (13 x 16.7 m); not a replica | BL | 25,000 / 10,000 / 2,500; 2 sets | P1 (10 tags it [L]; it is already in `WorldConfig.POIs` and the greybox) | S1 |
| `M_Sea_Boulder_*`, `M_Sea_MooringBlock`, `M_Sea_LostPot`, `M_Sea_BottleField`, `M_Sea_SandRipples` decals | Harbour approaches gravel and boulders, lost creels | SC + BL | 1,000 to 6,000; seabed atlas | P0 boulders, P1 clutter | S2 |

### 2.8 Rescue kit

Seen in first person within 1 m, so hand-held kit is **hero close-up** texel density (100 to 128 px per stud). One shared **kit atlas** (2 sets: soft goods, hard goods; 2048 if Spike 1 allows, verify) plus `_Wet`. Signal colours per 05 section 3.2 (SOLAS orange for casualty items, Hull Orange and Hi-Vis for crew items).

| Asset | Real-world reference | Source | Budget | Pri | Batch |
|---|---|---|---|---|---|
| `M_Kit_ThrowBag` (+ deployed line) | Rescue throw bag about 0.35 m x 0.15 m diameter, 15 to 25 m floating line (verify) | BL (`rope.py`) | 2,500; kit atlas; line as `Beam` / rope mesh | P0 | E1 |
| `M_Kit_RescueTube` | Foam lifeguard rescue tube about 1.0 x 0.15 x 0.08 m with clip and 2 m leash (verify) | BL | 1,500; kit atlas | P0 | E1 |
| `M_Kit_Lifebuoy` | Lifebuoy 0.75 m OD (05) with a light and retro tape | BL | 1,500; kit atlas | P0 | E1 |
| `M_Kit_ThermalBlanket` | Foil blanket about 2.1 x 1.3 m; thermal protective aid bag about 2 x 1 m (verify); cloth-sim poses baked | BL | 2,000 per pose; kit atlas | P0 | E1 |
| `M_Kit_FirstAidBag`, `M_Kit_OxygenBag` | Response bag about 0.5 x 0.3 x 0.3 m; oxygen bag with a CD-size cylinder about 0.55 m and non-rebreather mask (verify; RNLI Casualty Care) | BL | 2,500 each; kit atlas | P0 | E1 |
| `M_Kit_VHFHandset` (handheld + fixed handset with curly cord) | Handheld marine VHF about 0.13 x 0.06 x 0.04 m (verify) | BL | 3,000; kit hard set | P0 | E1 |
| `M_Kit_ChartTablet` | Rugged 10-inch tablet in a waterproof case, about 0.27 x 0.18 x 0.02 m (verify); screen is a UI surface | BL | 1,500; kit hard set | P0 | E1 |
| `M_Kit_HandFlare`, `M_Kit_ParaFlare`, `M_Kit_Strobe` | Red hand flare about 0.25 m, parachute rocket about 0.35 m, lifejacket strobe about 0.1 m (verify) | BL | 500 to 1,200; kit atlas; emissive heads | P0 | E1 |
| `M_Kit_LineKnife` | Rescue line knife with a blunt tip | BL | 600; kit hard set | P1 | E1 |
| `M_Kit_HorizontalLift` | Generic parbuckle recovery net / strop, about 2 x 1.2 m (verify); not a branded product | BL (`rope.py`) | 3,000 per pose; kit soft set | P0 | E2 |
| `M_Kit_TowLine`, `M_Kit_Bridle`, `M_Kit_HeavingLine`, shackles | Tow rope about 50 m of 16 to 20 mm polyester (verify), two-leg bridle about 5 m, weighted heaving line; tension shown by Beam / rope mesh in game | BL (`rope.py`) | Coils 1,500 to 2,500; rope trim | P0 (Op 2) | E2 |
| `M_Kit_Fender_*`, mooring lines | Shared with `M_Hbr_Fender_*` (HP2 builds them, E2 only rigs the boat-side lanyards) | HP2 | n/a | P0 | E2 |
| `M_Kit_StretcherBasket`, `M_Kit_TriageTags` | Basket stretcher about 2.1 x 0.6 m; coloured triage tags (verify) | BL | 3,000 / 300; kit atlas | P1 (Op 3) | E2 |

### 2.9 Characters

> **Decision 2026-10-17 (user): Roblox characters for people, for now.** Custom human characters are paused. All human NPCs (crew, Chief Aggie, casualty variants, ferry passengers, townsfolk) use Roblox R15 characters dressed with realistic clothing and accessories (HumanoidDescription: drysuits, oilskins, lifejackets, helmets). The already-approved `M_Chr_Casualty_Swimmer` stays in use as the Person in the Water casualty. Batches CH2, CH3 and the human parts of CH4 and CH5 are on hold; Bosun (CH6, CH7) and the first-person arms (CH4) continue.

> **Moderation rule for every CH batch (CH1 to CH5), from 2026-10-17.** Never upload a bare human body mesh: Roblox moderates each mesh alone, and two unclothed body meshes were removed for "Sexual Content" (account strikes). Clothing is real geometry merged into the same mesh as the body; no anatomical detail on skin areas; `M_Chr_HumanBase_M`/`_F` stay local Blender sources and are never exported or uploaded; no naked-body texture sets are uploaded; every upload has its real asset name, never "mesh". The full rule is in [document 06, section 2.1a](06-tools-and-pipeline.md#21a-character-uploads-moderation-rule-mandatory). The `M_Chr_HumanBase_*` row below is a **local source**, not an upload.

Human NPCs are realistic skinned meshes on an **R15-compatible skeleton** so they share avatar animations (verify skinned realistic meshes on R15 and the bone cap, Spike 1). No injuries, no blood (05 section 8.2).

| Asset | Real-world reference | Source | Budget | Pri | Batch |
|---|---|---|---|---|---|
| `M_Chr_HumanBase_M`, `_F` + `RIG_Human` | Adults 1.6 to 1.9 m (4.8 to 5.7 studs) | MPFB base (CC0 parts only, verify) + BL sculpt, retopo, skin bake; or CM | 20,000 / 8,000 / 2,000; 2 sets (body, head) + hair cards | P0 | CH1 |
| `M_Chr_Casualty_Swimmer` (SOLAS lifejacket, strobe, retro tape) | The readability test case (06 section 7 step 17) | BL on the base | As above; lifejacket in kit soft set | P0 (fidelity bar) | CH1 |
| `M_Chr_Casualty_*` (kayaker in a buoyancy aid, paddleboarder, fisherman in oilskins, ferry passenger, walker) with 3 heads and 3 skin tones mixed | Real clothing classes; age, build and skin tone vary (05 section 8.2) | BL on the base | 20,000 / 8,000 / 2,000 each; 2 sets + shared clothing atlas | P0 (4 variants), P1 (ferry passengers) | CH2 |
| `M_Chr_Crew_*` (NPC crew, 3 variants in drysuit, lifejacket, helmet) | RNLI-style crew kit without RNLI marks; Hi-Vis Yellow and navy | BL on the base | 20,000 / 8,000 / 2,000; reuse crew kit sets | P0 | CH3 |
| `M_Chr_Aggie` | Chief Agnes Brightwater, retired coxswain, 60s, cocoa mug (01) | BL on the base, hero face; CM option for the head sculpt | 20,000; 2 sets, head laid out for 2048 (verify) | P0 (cold open) | CH3 |
| `M_Chr_CrewKit_*` (drysuit layered clothing, crew lifejacket with light and tape, helmet with visor, gloves, boots) | Player on-duty kit (05 section 8.1) | BL | Within layered clothing and accessory limits (verify); 1 to 2 sets per item | P0 | CH4 |
| `M_Chr_FPArms` (+ sleeve and glove variants per uniform) | Viewmodel forearms with neoprene rescue gloves, latex wrist seals, retro tape (05 section 8.5) | BL | 12,000; 2 sets (2048 if allowed, verify); `_Wet` | P0 | CH4 |
| `A_Human_*` (tread water, wave for help, panic, float exhausted, shiver, sit wrapped, crew brace, hand-over-hand, throw-bag swing, Aggie slipway walk) and `A_FPArms_*` hand poses (05 section 8.5) | Real movement from video reference | BL keyframe; licensed mocap only with a written licence (verify; Mixamo terms unclear) | 30 fps clips, 1 to 6 s | P0 | CH5 |
| `M_Chr_Bosun` + fur cards + harness | Newfoundland, 66 to 71 cm at the shoulder (2.1 studs), an adult male of about 68 kg (05 section 4.1); black coat, webbed paws; Hull Orange water-rescue harness with handle and retro tape, no cross | BL sculpt + bake; CM option | 25,000 + up to 15,000 fur cards / 10,000 / 3,000; 3 sets (body, fur cards, harness) + `_Wet` | P0 (fidelity bar) | CH6 |
| `RIG_Bosun` + `A_Bosun_*` (idle, walk, trot, run, sit, bark, swim, swim-tow with line, climb aboard, shake-off, ride the footwell) | Keyframed from real Newfoundland water-rescue footage (05 section 8.4) | BL custom quadruped rig (spine, tail, ears, jowls, legs); CM option for licensed quadruped mocap (verify) | Bone count per Spike 1 (verify); 30 fps | P0 | CH7 |

### 2.10 Animals

| Asset | Real-world reference | Source | Budget | Pri | Batch |
|---|---|---|---|---|---|
| `M_Ani_GreySeal` "Old Ned" + rig and clips (swim, surface, look, haul-out, flee) | Grey seal bull about 2.5 m (7.5 studs), 170 to 310 kg (verify) | BL | 12,000 / 5,000 / 1,500; 2 sets + `_Wet` | P0 (MVP has one seal) | AN1 |
| `M_Ani_HerringGull` + clips (glide, flap, land, stand, call) | Herring gull 55 to 67 cm long, 1.3 to 1.5 m span (verify) | BL | 3,000 / 1,200 / 400; 1 set; flocks instanced | P0 | AN1 |
| `FX_Ani_FishShoal_*` (mackerel, sand eels, pollack) | Calm Bay shoals (10 section 4.3) | BL render to flipbook sprites | 1 flipbook each | P1 | AN1 |

### 2.11 VFX textures

All flipbooks rendered from real Blender simulations with `flipbook.py`, lit particles (`LightInfluence` 1), at `EXPORT_CAP`. Existing ocean maps in `assets/ocean/` (foam, caustics, normals, skies) are re-checked against `check_textures.py` and logged, not remade.

| Asset | Reference | Source | Budget | Pri | Batch |
|---|---|---|---|---|---|
| `FX_Spray_BowSheet`, `FX_Spray_SlamBurst`, `FX_Spray_Mist`, `FX_Spray_Spindrift` | RNLI launch and storm footage | BL fluid sim | 8x8 flipbooks; particle counts per tier (06 section 3.5) | P0 | FX1 |
| `FX_Foam_HullRing`, `FX_Foam_WakeRibbon`, `FX_Foam_CrestStreak`, `FX_Foam_Swash` | Real wake and swash foam | BL sim + bake (reuse `assets/ocean/ocean_foam*.png` where it passes) | 1 set each, alpha | P0 | FX1 |
| `FX_Rain_Streak`, `FX_Rain_SplashRing`, `FX_Rain_Drip`, `FX_Rain_OnWater` | Real rain photography | BL | 4x4 flipbooks | P0 | FX2 |
| `FX_Smoke_Orange`, `FX_Smoke_Black`, `FX_Smoke_Exhaust` | Orange smoke canister, diesel haze | BL smoke sim | 8x8 flipbooks | P0 orange, P1 black and exhaust | FX2 |
| `FX_Flare_Head`, `FX_Flare_Sparks`, `FX_Flare_Smoke`, `FX_Flare_Parachute` | Red hand flare (Distress Red, 05 section 3.2) | BL | 4x4 flipbooks + emissive | P0 | FX2 |
| `FX_Water_DogShake`, `FX_Under_MarineSnow`, `FX_Under_Bubbles`, `FX_Under_LightShaft`, `FX_Oil_Sheen`, `FX_Mist_Bank`, `FX_Lightning_Bolt` | 05 section 7.3, 10 section 6.5 | BL | 4x4 flipbooks / single maps | P0 dog and underwater, P1 the rest | FX2 |

---

## 3. Batches and order

### 3.1 Rules for every batch

- **One agent, one batch, about 40 turns, disjoint files.** A batch owns only its `art/source/<kind>/<Asset>/`, `art/reference/<Asset>/`, `assets/{fbx,textures,review}/<Asset>/` folders and its own `art/status/<Batch>.csv`. Nobody but the pipeline batches edits `tools/blender/`; nobody but the integration batch edits `map/Build.luau` or `src/`. Uploads go through `tools/assets.py` (its manifest is locked), wrapped in `tools/with-lock.sh assets.MaydaySeaRescue`.
- **Models:** builders and fixers are Opus (`effort: high`); the art-director and sign-off reviewers are fresh Sonnet agents (`effort: high`) that see only the contact sheet, the brief and 05; reference-dimension gathering, licence lookups, audio searches and pass/fail checks (does `validate` pass, does `check_textures.py` pass) are Haiku (`effort: low`).
- **Hand-off:** each batch returns a summary under 300 words (assets done, ids, open fixes, file paths). A batch that fails review twice ends; a new short fix batch gets the summary and the reviewer's list.
- **Inside a batch:** reference board, then build and `validate` in short Blender runs, then bakes (one texture set per run), then turntable, then upload, then one Studio pass, then one art-director review, then at most one fix loop.

### 3.2 The batches

| Wave | Batch | Deliverable | Model | Depends on |
|---|---|---|---|---|
| 0 | **B00** Pipeline core | `tools/blender/` port: `run.py`, `common.py`, `budgets.py`, `validate.py`, `export.py` (rbxkit constants), `versions.py` (lod only), `uvlayout.py`, `texgen.py`, `check_textures.py`, name tests | Opus | none |
| 0 | **B01** Template, bake, look-dev | `template.py` and `_template.blend` (CC0 HDRIs from Poly Haven), `bake.py`, `turntable.py` + `sheet.py`, `scan_ingest.py`, `rope.py`, `flipbook.py`, move `cubemap.py`; `tools/studio/import_asset.luau`; a look-dev shot setup (`art/lookdev/shot-setup.luau`, based on `art/ocean/shot-setup.luau`, applying the four presets dry and wet); the Spike 1 test set (scale cube, 20,000-tri mesh, 1024 / 2048 / 4096 sets, a skinned mesh) | Opus | B00 interfaces (agree file names first; files are disjoint) |
| 0 | **B02** Material library | MaterialVariants for the terrain slots in 10 section 6.1, quay stone, cobbles, concrete, weedy concrete, tarmac, non-slip deck, each with a wet twin (ACG / PH CC0); the building trim sheet; the harbour, kit, street and foliage atlas layouts | Opus | B01 `scan_ingest.py` |
| 0 | **R0** Reference dimensions | `art/reference/<Asset>/dims.md` for every row in section 2 with source links, (verify) where none is found | Haiku (web research) | none |
| 0 | **AU1** Audio search | Candidate ids for section 4 from `audio-search.py`, verified public; Freesound CC0 candidates with URLs | Haiku | none |
| 1 | **V2** RIB + helm | The first production asset: **its sign-off sets the fidelity bar** for all later batches | Opus | B00, B01, B02, Spike 1 result |
| 1 | **CH1** Human base (local only) + swimmer casualty | The readability test case. Only the clothed swimmer is uploaded (06 section 2.1a) | Opus | B00, B01 |
| 1 | **CH6** Bosun model, fur, harness | Static model at LOD0 to LOD2 | Opus | B00, B01 |
| 1 | Fidelity-bar sign-off | One Sonnet sign-off of V2, CH1 and CH6 together, side by side with reference photos | Sonnet | wave 1 |
| 2a | P0 places and craft | V1 jet ski + close-up · H1 station + slipway · H2 Chandlery (ext, int, props) · H3 cottage kit + 6 variants · H6 Harbor Light + lifeguard tower · HP1 quay kit, pontoons, ladders · HP2 harbour props · C1 *The Optimist*, kayak, paddleboard | Opus each | wave 1 sign-off |
| 2b | P0 kit, people, nature, VFX, audio | E1 hand-held kit · E2 rigging kit · CH2 casualty variants · CH3 crew + Aggie · CH4 crew kit + FP arms · CH5 human clips · CH7 Bosun rig + clips · K1 rocks and cliffs · G1 land vegetation · S1 wrecks (Morwenna, anchor, bell, then seaplane) · S2 seabed + marine vegetation · R1 roads and street furniture · AN1 seal and gulls · FX1 spray and foam · FX2 rain, smoke, flares, underwater · AU2 sound design | Opus each | wave 1 sign-off (CH5 and CH7 need CH1 and CH6) |
| 3 | P1 | V4 ambulance · H4 harbourmaster + boatyard · H5 hospital · H7 town extras · C2 *Gale Queen* + liferaft · C3 moored boats · P1 remainder of each earlier batch | Opus each | wave 2 |
| 4 | P2 | V5 coastguard 4x4, trailers, ATV | Opus | wave 3 |
| after each wave | **I1** Integration | Swaps the greybox in `map/Build.luau` for the new Packages, keeps `GREYBOX` tags on what remains, adds `AssetIds.luau` generation; then one Sonnet milestone sign-off per wave in all four presets | Opus, then Sonnet | the wave |

Waves 2a and 2b are about 24 batches; with the 20-agents-per-thread limit, start 2a, then start 2b batches as 2a batches finish. Most of the time in each batch is spent waiting for a heavy slot, so fanning out further than the queue can serve buys nothing (3.3).

### 3.3 The 2-heavy-jobs limit (Blender and Studio)

- **Every Blender job** runs through `~/RobloxProjects/tools/blender-run.sh`, which takes one slot of the 2-slot heavy pool (`with-heavy.sh`, FIFO via `tools/locks.py`) and also refuses to start a third Blender process. So the machine never runs more than two Blender jobs, however many agents are working.
- **Keep runs short.** Heavy holds have a 10-minute advisory cap. Split work so each run fits: build + lod + validate in one run (usually under 2 minutes), **one bake run per texture set**, one turntable run (EEVEE, 4 views at 768 px). Iterate bakes at 1024 and low samples; bake 4096 masters once, after the art-director pass.
- **Do the light work outside Blender**: `check_textures.py`, contact sheets (`sheet.py`, system `python3` with Pillow), status rows, uploads and reference boards need no heavy slot.
- **Studio counts as a heavy job.** The screenshot pass takes the machine-wide Studio lock first, then one heavy slot (the documented nesting order is studio, then heavy), so Studio plus Blender never exceeds two:
  `tools/with-lock.sh studio --owner "<Batch> shots" -- tools/with-heavy.sh -- python3 tools/studio-shot.py --setup art/lookdev/shot-setup.luau --shots assets/review/<Asset>/shots.json --out assets/review/<Asset>/studio.png`
- **One Studio pass per batch**, covering every asset in the batch in one `shots.json` (four presets, dry and wet for hero assets, High and Low quality), inserted with `tools/studio-insert.py` into the shared look-dev place, captured at about half scale and combined into the contact sheet. The pass must finish inside the 10-minute cap; the Studio lock is FIFO, so other batches queue behind it. Builders never look at the images; only the Sonnet reviewer does.

---

## 4. Audio

Sources and licences (05 section 11; confirm each before use and log it in the batch status file):

- **RL: Roblox licensed library** (Pro Sound Effects, APM and Roblox's own uploads, found with `tools/audio-search.py`, which checks the public flag). Free to use in Roblox experiences under Roblox's terms. **Not cleared for off-platform use** such as the trailer (verify); [document 07](07-store-page-thumbnails-and-trailer.md) needs owned or cleared audio for that.
- **FS: Freesound CC0 only** (verify the licence on each clip page; no CC-BY-NC). Uploaded through `tools/assets.py` and Roblox audio moderation.
- **RC: our own recordings** (owned): real engines, harbour ambience, rope and foley, the dog (with an owner's consent).
- **CM: commission**: work-for-hire, full rights, no-AI clause; for hero loops that must also serve marketing.
- Voice lines are owned by [document 11](11-dispatcher-and-voice.md) (ElevenLabs); interface sounds are not listed here.

| Group | Sounds (`SFX_` names) | Source | Licence | Pri |
|---|---|---|---|---|
| Engines | `SFX_Eng_JetSki_{Idle,Low,High,Cavitate,Start,Stop}`, `SFX_Eng_RIB_{Idle,Mid,Plane,Trim}` (twin outboards, layered by RPM), `SFX_Eng_Pickup_{Idle,Load,Rev}` (diesel), `SFX_Eng_Optimist_{Idle,Cough,Die}`, `SFX_Eng_Ambulance_Idle`, `SFX_Siren_Ambulance` (invented two-tone, verify it copies no real tone pattern), later ATV and 4x4 | RC first (marina and slipway recordings), RL fallback, CM for the RIB hero loop | Owned / Roblox / work-for-hire | P0 (ambulance P1) |
| Hull and tyres | `SFX_Hull_{Slap,Slam,SprayHiss}`, `SFX_Tyre_{Asphalt,Cobble,Gravel,Sand}`, `SFX_Trailer_Winch` | RL, RC | Roblox / Owned | P0 |
| Waves | `SFX_Wave_{OpenSwell,Harbour,BeachCalm,BeachStorm,RockBreak,BlowHole}`, `SFX_Bell_Buoy` | RC (coast recordings), RL, FS CC0 | Owned / Roblox / CC0 | P0 |
| Wind | `SFX_Wind_{Light,Strong,Gale}`, `SFX_Wind_RiggingWhistle`, `SFX_Wind_Halyard` | RL, FS CC0 | Roblox / CC0 | P0 |
| Rain | `SFX_Rain_{Light,Heavy,OnRoof,OnWater,OnHood}` | RL, FS CC0 | Roblox / CC0 | P0 |
| Thunder | `SFX_Thunder_{Crack,Near,Roll_01..03}` | RL, FS CC0 | Roblox / CC0 | P0 |
| Radio | `SFX_Radio_{Open,Burst,Tail,Static,DSCAlarm}` per 11 section 3 (120 ms burst, 180 ms tail, no roger beep; verify the DSC alarm sound) | Designed by us from recorded noise (RC), RL fallback | Owned / Roblox | P0 |
| Rope and lines | `SFX_Rope_{Creak_Low,Creak_High,PayOut,Coil}` (by tension), `SFX_Line_Snap`, `SFX_ThrowBag_{Throw,Land}`, `SFX_Line_Splash` | RC foley, RL | Owned / Roblox | P0 |
| Animals | `SFX_Gull_{Call_01..04,Flock}` (herring gull), `SFX_Seal_{Grunt,Moan,Splash}` | FS CC0, RL | CC0 / Roblox | P0 |
| The dog | `SFX_Dog_{Bark,WoofAlert,Pant,Whine,ShakeOff,SplashIn,SwimPaddle}` | RC (a real Newfoundland, owner consent), RL fallback | Owned / Roblox | P0 |
| People and foley | `SFX_Step_{Wood,Cobble,Sand,WetDeck,Grating}`, `SFX_Drysuit_Rustle`, `SFX_Splash_{Entry,Climb}`, `SFX_Casualty_Whistle`, `SFX_Flare_{Ignite,Burn}`, `SFX_Hull_Knock` (Op 3) | RC foley, RL | Owned / Roblox | P0 (knock P1) |
| Underwater | `SFX_Under_{Ambience,Bubbles,Muffle}` | RL, FS CC0 | Roblox / CC0 | P0 |
| Places | `SFX_Amb_{Harbour,Town,Chandlery,Station}`, `SFX_Chandlery_{DoorBell,Till,Floorboard}`, `SFX_Station_{RollerDoor,LaunchPager,Winch}` | RC, RL | Owned / Roblox | P0 |

Audio batches: **AU1** (Haiku, wave 0) finds and verifies candidates; **AU2** (Opus, wave 2b) designs the loops (RPM layering, tension-driven rope creak, the radio chain), uploads them and records licences. Recording sessions (RC) are a task for the user; until they exist, RL clips stand in and are marked `temp` in the status file.

---

## 5. Open issues

- Spike 1 decides the texture cap, the skinned bone count, empties as attachments, runtime `SurfaceAppearance` swaps and layered clothing limits; several budgets above change with it.
- The greybox hospital has a red cross (`CrossV`, `CrossH` in `map/Build.luau`); it must go with H5 at the latest, and should go sooner.
- Document 06 section 2.4 names `scripts/blender/` and `scripts/tools/`; this file puts the library in `tools/blender/`. Document 06 should be updated to match.
- Document 10 tags the mail seaplane, harbourmaster, ATV and coastguard 4x4 [L]; this list gives them P1 or P2 to match.
- The Admiralty anchor's WorldConfig size (5 m) needs checking against an 1840s reference.
- Child casualties are not planned; canon (01) should confirm before any are added.
