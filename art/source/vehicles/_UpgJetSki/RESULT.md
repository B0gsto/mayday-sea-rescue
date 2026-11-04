# Jet Ski stage upgrade pieces (L2-L10): result

Concept: artifact 236fbf08 (Jet Ski Stage). Geometry: `pieces.py` + `kitgeo.py`, one thin `build.py` per piece in `art/source/vehicles/M_Upg_JetSki_*`. Rebuild: `python3 art/source/vehicles/_UpgJetSki/palette.py build/prod/_UpgJetSki/textures`, then in Blender `import pipeline; pipeline.run_all()`, then `upload.sh` from the game root.

## Ids

Every piece is authored in the frame of the shipped `M_Veh_JetSki` (pwc.py + `frame_offset.json`), so its **Model pivot is the hull origin: offset (0, 0, 0)**. `Model:PivotTo(hullModel:GetPivot())` is all a piece needs. `MeshPart centre` is where the part lands relative to that pivot, in Roblox axes (x starboard, y up from the keel, z aft, bow at -z). Not checked in Studio.

| Lv | Asset | LOD0 | LOD1 | LOD2 | Offset | MeshPart centre | Size | Tris LOD0 / 1 / 2 |
|---|---|---|---|---|---|---|---|---|
| 2 | `M_Upg_JetSki_SharkFin` | 82444059904089 | 131071879953776 | 75993324346987 | (0, 0, 0) | (0.000, 2.892, -6.336) | 2.87 x 3.48 x 2.08 | 1190 / 538 / 156 |
| 3 | `M_Upg_JetSki_RescueSled` | 71584694312151 | 118216129917569 | 77115545041045 | (0, 0, 0) | (0.000, 1.558, 4.329) | 3.40 x 1.16 x 4.00 | 1828 / 344 / 184 |
| 4 | `M_Upg_JetSki_TwinEngines` | 127661786716659 | 132637615796944 | 139575020895164 | (0, 0, 0) | (0.000, 1.857, 7.279) | 3.50 x 4.03 x 2.70 | 1652 / 824 / 168 |
| 5 | `M_Upg_JetSki_FlamePipes` | 129182068797850 | 71075862318850 | 128326767518110 | (0, 0, 0) | (0.000, 3.091, 8.961) | 2.90 x 0.90 x 1.60 | 1368 / 684 / 268 |
| 6 | `M_Upg_JetSki_BananaBoat` | 112354636600269 | 75372654414765 | 137000869678428 | (0, 0, 0) | (0.000, 1.119, 10.126) | 1.25 x 1.80 x 6.66 | 1406 / 702 / 328 |
| 7 | `M_Upg_JetSki_HugeSpoiler` | 70816735216301 | 77220106432595 | 80938518912264 | (0, 0, 0) | (0.000, 3.435, 3.189) | 6.28 x 2.91 x 1.80 | 1328 / 264 / 72 |
| 8 | `M_Upg_JetSki_BullNose` | 120960635352046 | 83066127514262 | 81724561997964 | (0, 0, 0) | (0.000, 2.328, -7.518) | 5.10 x 2.63 x 2.51 | 2552 / 1216 / 272 |
| 9 | `M_Upg_JetSki_HornStack` | 105718699157976 | 132484549921746 | 83677121663832 | (0, 0, 0) | (0.000, 3.429, -8.239) | 2.95 x 1.56 x 2.15 | 1944 / 708 / 140 |
| 10 | `M_Upg_JetSki_TurboCrown` | 122753421892403 | 75987354365707 | 138644955671608 | (0, 0, 0) | (0.000, 4.825, -3.906) | 2.79 x 3.11 x 2.73 | 3216 / 1452 / 460 |

Shared palette set (one SurfaceAppearance for all nine), `T_UpgJetSki_Brick_*`, 1024 px: ALB 123903720233065, NOR 134063939343985, RGH 84877019945075, MET 136774512814925. RGH and MET carry per-colour roughness and metal, so chrome and gold need them. NOR has the same bytes as the Depot's flat normal, so it reuses that id.

LOD0 total with all nine on: 16484 tris (hull not counted).

## Checks

validate PASS for all nine (waived: `_COL proxy`, `LOD UV layout`, `texture sets`, reasons in `pieces.py`). zfight: 27 exported FBX read back, 0 visible pairs; all nine LOD0 together with the hull's LOD0 (no Sled), 0 visible pairs. Sheet: `build/status/2026-11-04/art/jetski.png`.

## For the wiring code

- **Bare ski:** the shipped hull still has its old sled. Hide the `M_Veh_JetSki_Sled` MeshPart from L1 on, or it clashes with Rescue Sled (concept build order, step 1). The sheet is rendered that way.
- **Cumulative:** Twin Engines mounts on the sled, Flame Pipes on the engines, Banana Boat's rope on the engine plate, Huge Spoiler on the sled's mount plate, Horn Stack on the Bull Nose. Levels show every earlier piece.
- **Collision:** pieces are visual only (`CanCollide` off); the hull's `_COL` stays the collision.
- **Waterline:** the concept's phone view floats the hull at keel + 0.92. Engine legs and props, and the banana's underside, sit below that.

## Changed from the concept

- Sticker lifted 0.075 (concept 0.045) to clear the hull's livery panels by the z-fight rule; it covers GI-17 on both bows, as the concept says.
- RESCUE is printed on the side tile's own face (no plane on top) in Arial Rounded Bold; the concept's Lilita One isn't installed.
- Flames are opaque palette colours, no glow or transparency: one MeshPart per piece, and the stubs are chrome. Neon or light from code needs its own hook.
- LOD1 drops studs; LOD2 drops studs, bevels, teeth, fan blades. Some LODs were further decimated by the pipeline to its target.

The rider on the sheet is a preview-only stand-in for scale (`preview.py`), not exported.
