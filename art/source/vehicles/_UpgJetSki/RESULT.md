# Jet Ski stage upgrade pieces (L2-L10): result

Concept: artifact 236fbf08 (Jet Ski Stage). Geometry: `pieces.py` + `kitgeo.py`, one thin `build.py` per piece in `art/source/vehicles/M_Upg_JetSki_*`. Rebuild: `python3 art/source/vehicles/_UpgJetSki/palette.py build/prod/_UpgJetSki/textures`, then in Blender `import pipeline; pipeline.run_all()`, then `upload.sh` from the game root.

## Ids

Every piece is authored in the frame of the shipped `M_Veh_JetSki` (pwc.py + `frame_offset.json`), so its **Model pivot is the hull origin: offset (0, 0, 0)**. `Model:PivotTo(hullModel:GetPivot())` is all a piece needs. `MeshPart centre` is where the part lands relative to that pivot, in Roblox axes (x starboard, y up from the keel, z aft, bow at -z). Not checked in Studio.

| Lv | Asset | LOD0 | LOD1 | LOD2 | Offset | MeshPart centre | Size | Tris LOD0 / 1 / 2 |
|---|---|---|---|---|---|---|---|---|
| 2 | `M_Upg_JetSki_SharkFin` | 86465182695980 | 134241892768069 | 112727638403061 | (0, 0, 0) | (0.000, 2.906, -2.569) | 2.87 x 3.51 x 9.62 | 1254 / 614 / 152 |
| 3 | `M_Upg_JetSki_RescueSled` | 140104156373329 | 125104302855746 | 116147832255778 | (0, 0, 0) | (0.000, 1.517, 3.969) | 3.56 x 1.33 x 3.28 | 1112 / 536 / 184 |
| 4 | `M_Upg_JetSki_TwinEngines` | 109746114632041 | 92875863722533 | 96657775688362 | (0, 0, 0) | (0.000, 2.350, 4.029) | 3.44 x 1.64 x 2.50 | 1464 / 696 / 24 |
| 5 | `M_Upg_JetSki_FlamePipes` | 104145567662833 | 71274745607661 | 99642071428432 | (0, 0, 0) | (0.000, 2.299, 6.420) | 3.70 x 1.69 x 2.50 | 1184 / 576 / 192 |
| 6 | `M_Upg_JetSki_BananaBoat` | 88729526606715 | 107782778027397 | 116272580245952 | (0, 0, 0) | (0.000, 1.085, 7.264) | 1.33 x 1.89 x 4.27 | 1104 / 552 / 196 |
| 7 | `M_Upg_JetSki_HugeSpoiler` | 116063672328978 | 123430915890969 | 133230004747334 | (0, 0, 0) | (0.000, 2.850, 4.122) | 13.60 x 2.59 x 3.14 | 1184 / 512 / 48 |
| 8 | `M_Upg_JetSki_BullNose` | 79574888573578 | 133634224577330 | 138274608484908 | (0, 0, 0) | (0.000, 3.214, -8.751) | 8.52 x 4.81 x 2.46 | 2712 / 1320 / 264 |
| 9 | `M_Upg_JetSki_HornStack` | 119756776932316 | 80816688960742 | 137744251423796 | (0, 0, 0) | (0.000, 2.621, -8.440) | 7.33 x 2.34 x 1.84 | 1128 / 424 / 128 |
| 10 | `M_Upg_JetSki_TurboCrown` | 132262536386007 | 120869815945534 | 78549653640317 | (0, 0, 0) | (0.000, 4.700, -6.176) | 5.30 x 4.40 x 5.19 | 2068 / 946 / 396 |

Round 3 ids; they replace every earlier id. Shared palette set (one SurfaceAppearance for all nine), `T_UpgJetSki_Brick_*`, 1024 px: ALB 138465572041285, NOR 134063939343985, RGH 101311551756925, MET 133041942279003. RGH and MET carry per-colour roughness and metal, so chrome and gold need them. NOR has the same bytes as the Depot's flat normal, so it reuses that id.

LOD0 total with all nine on: 13210 tris (hull not counted).

## Checks

validate PASS for all nine (waived: `_COL proxy`, `LOD UV layout`, `texture sets`, reasons in `pieces.py`). zfight: 27 exported FBX read back, 0 visible pairs; all nine LOD0 together with the hull's LOD0 (no Sled), 0 visible pairs involving a piece. That combined scan also finds small coplanar pairs inside the shipped hull itself (Decals against Hull, up to 0.02 stud^2, count varies by run). Left alone: the hull is not ours to redesign. Sheet: `build/status/2026-11-04/art/jetski.png`.

## For the wiring code

- **Bare ski:** the shipped hull still has its old sled. Hide the `M_Veh_JetSki_Sled` MeshPart from L1 on, or it clashes with Rescue Sled (concept build order, step 1). The sheet is rendered that way.
- **Cumulative, order matters:** Twin Engines sit on the sled, Flame Pipes on the engines, Banana Boat docks on the sled's stern, Huge Spoiler rests on the engines, Horn Stack on the Bull Nose, Turbo Crown on the hood and the bull's head. Levels show every earlier piece; a piece shown without its mount floats.
- **Collision:** pieces are visual only (`CanCollide` off); the hull's `_COL` stays the collision.
- **Waterline:** the concept's phone view floats the hull at keel + 0.92. The banana's underside and the bull's nose ring come close to or below that.
- **Width:** Huge Spoiler is about 13.2 studs wide and the horns about 9, against a 3.9 stud hull, so they clear docks and gates differently. Crown top is y 6.9.

## Changed from the concept (AD rounds 2 and 3, coordinator's fix lists)

The L10 goal is one joke: a crowned bull charging at the bow, with the rider behind it and a huge low wing and flames behind them.

- **Turbo Crown:** huge (band up to r 2.2), straight on the hood and the bull's head at z -3.7, no pillar or tower. Saturated gold (metal 0.5 so it stays yellow). The fan is replaced by one orange dome.
- **Huge Spoiler:** 12.4 wide with big endplates, low (y 3.25), resting on the engines, no pylons. The rider stays above it from the chase camera.
- **Bull Nose:** a shallow blue head (new colour `BullBlue`) with big eyes, angry brows, a cream muzzle, nostrils, a gold ring and big cream horns. It starts at the bow tip, so the orange hull shows behind it. The chrome bar is gone.
- **Horn Stack:** the bull's ears are now gold air horns, with red squeeze bulbs on its cheeks. Gold instead of the concept's chrome, no base block.
- **Twin Engines:** two low navy pods flush on the transom, on the sled deck. No towers, legs, clamps or props.
- **Flame Pipes:** much bigger, from flared chrome nozzles on the pods.
- **Shark Fin:** one clean saturated teal fin (new colour `SharkTeal`, the bow sticker matches) moved to the passenger seat, mid-back. Low enough to leave the helmet and the sides of the vest in view from the chase camera; it does cover the middle of the torso.
- **Rescue Sled:** 2.4 long, was 3.5. The life ring hangs on the stern, facing the chase camera.
- **Banana Boat:** no rope and no tow eye; it docks on the sled's stern on a short coupler, under the ring. The whole boat ends at z 11.55 in the concept frame, was 15.65.
- **Studs:** all 0.8 pitch, 0.54 across (concept 0.5, 0.34), to read on a phone.

Kept from round 1: sticker lifted 0.075 (concept 0.045) to clear the hull's livery by the z-fight rule, covering GI-17 on both bows. RESCUE is printed on the side tile's own face in Arial Rounded Bold; the concept's Lilita One isn't installed. Flames are opaque palette colours with no glow: Neon or light from code needs its own hook. LOD1 drops stud bevels; LOD2 drops studs, bevels, teeth. Some LODs were further decimated by the pipeline to its target.

The rider on the sheet is a preview-only stand-in for scale (`preview.py`), not exported. The sheet's phone cell uses the concept's real camera (70 degrees vertical, 19.5:9).
