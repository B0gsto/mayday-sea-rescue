# Jet Ski stage upgrade pieces (L2-L10): result

Concept: artifact 236fbf08 (Jet Ski Stage). Geometry: `pieces.py` + `kitgeo.py`, one thin `build.py` per piece in `art/source/vehicles/M_Upg_JetSki_*`. Rebuild: `python3 art/source/vehicles/_UpgJetSki/palette.py build/prod/_UpgJetSki/textures`, then in Blender `import pipeline; pipeline.run_all()`, then `upload.sh` from the game root.

## Ids

Every piece is authored in the frame of the shipped `M_Veh_JetSki` (pwc.py + `frame_offset.json`), so its **Model pivot is the hull origin: offset (0, 0, 0)**. `Model:PivotTo(hullModel:GetPivot())` is all a piece needs. `MeshPart centre` is where the part lands relative to that pivot, in Roblox axes (x starboard, y up from the keel, z aft, bow at -z). Not checked in Studio.

| Lv | Asset | LOD0 | LOD1 | LOD2 | Offset | MeshPart centre | Size | Tris LOD0 / 1 / 2 |
|---|---|---|---|---|---|---|---|---|
| 2 | `M_Upg_JetSki_SharkFin` | 126992599806706 | 70409497965561 | 73665651100814 | (0, 0, 0) | (0.000, 2.892, -6.336) | 2.87 x 3.48 x 2.08 | 1182 / 590 / 184 |
| 3 | `M_Upg_JetSki_RescueSled` | 123649729918810 | 133462597322688 | 133710880214917 | (0, 0, 0) | (0.000, 1.582, 3.784) | 3.56 x 1.21 x 2.91 | 1016 / 504 / 184 |
| 4 | `M_Upg_JetSki_TwinEngines` | 84027593433033 | 109288128186616 | 86354779532265 | (0, 0, 0) | (0.000, 1.826, 6.404) | 4.40 x 4.43 x 2.75 | 1216 / 608 / 144 |
| 5 | `M_Upg_JetSki_FlamePipes` | 119014295879530 | 92645413156328 | 117071727731509 | (0, 0, 0) | (0.000, 3.097, 7.849) | 3.67 x 1.17 x 1.90 | 1368 / 684 / 268 |
| 6 | `M_Upg_JetSki_BananaBoat` | 74932549448904 | 136494554102962 | 124354575840738 | (0, 0, 0) | (0.000, 1.085, 8.668) | 1.33 x 1.89 x 3.85 | 1104 / 552 / 196 |
| 7 | `M_Upg_JetSki_HugeSpoiler` | 128761736597531 | 98391996635105 | 101998095013763 | (0, 0, 0) | (0.000, 3.664, 3.399) | 9.40 x 3.37 x 3.17 | 1032 / 516 / 72 |
| 8 | `M_Upg_JetSki_BullNose` | 119155549509789 | 76193740204066 | 105447078803526 | (0, 0, 0) | (0.000, 2.821, -8.401) | 6.92 x 3.80 x 2.56 | 1516 / 712 / 156 |
| 9 | `M_Upg_JetSki_HornStack` | 89270811296918 | 127262750284551 | 134072664979564 | (0, 0, 0) | (0.000, 4.490, -8.617) | 3.87 x 2.18 x 3.09 | 1268 / 500 / 140 |
| 10 | `M_Upg_JetSki_TurboCrown` | 84536257755954 | 88938467975500 | 86910248243477 | (0, 0, 0) | (0.000, 5.915, -4.556) | 4.47 x 6.43 x 4.37 | 2124 / 1018 / 416 |

Round 2 ids; they replace every round 1 id. Shared palette set (one SurfaceAppearance for all nine), `T_UpgJetSki_Brick_*`, 1024 px: ALB 110827072925864, NOR 134063939343985, RGH 101311551756925, MET 133041942279003. RGH and MET carry per-colour roughness and metal, so chrome and gold need them. NOR has the same bytes as the Depot's flat normal, so it reuses that id.

LOD0 total with all nine on: 11826 tris (hull not counted).

## Checks

validate PASS for all nine (waived: `_COL proxy`, `LOD UV layout`, `texture sets`, reasons in `pieces.py`). zfight: 27 exported FBX read back, 0 visible pairs; all nine LOD0 together with the hull's LOD0 (no Sled), 0 visible pairs involving a piece. That combined scan also finds small coplanar pairs inside the shipped hull itself (Decals against Hull, up to 0.02 stud^2, count varies by run). Left alone: the hull is not ours to redesign. Sheet: `build/status/2026-11-04/art/jetski.png`.

## For the wiring code

- **Bare ski:** the shipped hull still has its old sled. Hide the `M_Veh_JetSki_Sled` MeshPart from L1 on, or it clashes with Rescue Sled (concept build order, step 1). The sheet is rendered that way.
- **Cumulative:** Twin Engines mounts on the sled, Flame Pipes on the engines, Banana Boat docks under the engine deck, Huge Spoiler on the sled's mount plate, Horn Stack on the Bull Nose. Levels show every earlier piece.
- **Collision:** pieces are visual only (`CanCollide` off); the hull's `_COL` stays the collision.
- **Waterline:** the concept's phone view floats the hull at keel + 0.92. Engine legs and props, and the banana's underside, sit below that.
- **Width and height:** Huge Spoiler is 9 studs wide and the crown tops out at y 9.1, so both clear gates and roofs differently from the hull.

## Changed from the concept (AD round 2, 6/10, coordinator's fix list)

- **Scale:** L7-L10 are 1.5-2x. Spoiler wing 8.4 x 0.7 x 2.6 with big endplates; crown band 1.6x.
- **Stern:** 3 studs shorter overall (ends at z 12.75 in the concept frame, was 15.65). Sled 2.4 long, was 3.5.
- **Engines:** cowls sit on a 4.4 wide navy brick deck, thick 1.0 legs, no clamp blocks. They moved out to x +-1.25.
- **Banana:** no rope and no tow eye. The nose docks under the engine deck between the legs on a short coupler.
- **Bull Nose:** one big rounded blue block (new colour `BullBlue`) with two big cream horns and a gold ring. The chrome bar, bead-chain horns and dark tips are gone.
- **Horn Stack:** bigger trumpets, tilted up, on a red base.
- **Turbo Crown:** saturated gold (metal 0.5 so it stays yellow) on a navy tower, moved forward to z -2.1, so it stands clear above the helmet from the chase camera. The fan is replaced by one orange dome.
- **Shark Fin:** bluer grey, white tip, wider studded plate.
- **Studs:** all 0.8 pitch, 0.54 across (concept 0.5, 0.34), to read on a phone.

Kept from round 1: sticker lifted 0.075 (concept 0.045) to clear the hull's livery by the z-fight rule, covering GI-17 on both bows. RESCUE is printed on the side tile's own face in Arial Rounded Bold; the concept's Lilita One isn't installed. Flames are opaque palette colours with no glow: Neon or light from code needs its own hook. LOD1 drops stud bevels; LOD2 drops studs, bevels, teeth. Some LODs were further decimated by the pipeline to its target.

The rider on the sheet is a preview-only stand-in for scale (`preview.py`), not exported. The sheet's phone cell uses the concept's real camera (70 degrees vertical, 19.5:9), which round 1's sheet did not.
