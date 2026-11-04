# RIB stage upgrade pieces (L12-L20): result

Concept: artifact 0ae647e2 (RIB Stage Concept). Geometry: `pieces.py` (mesh helpers from `../_UpgJetSki/kitgeo.py`), one thin `build.py` per piece in `art/source/vehicles/M_Upg_RIB_*`. Rebuild: `python3 art/source/vehicles/_UpgRIB/palette.py build/prod/_UpgRIB/textures`, then in Blender `import pipeline; pipeline.run_all()`, then `upload.sh` from the game root.

## Ids

Round 2 ids; they replace every earlier id.

Every piece is authored in the frame of the shipped `M_Veh_RIB` (`frame_offset.json`), so its **Model pivot is the hull origin: offset (0, 0, 0)**. `Model:PivotTo(hullModel:GetPivot())` is all a piece needs. `MeshPart centre` is relative to that pivot, in Roblox axes (x starboard, y up from the skeg base, z aft, bow at -z). Not checked in Studio.

| Lv | Asset | LOD0 | LOD1 | LOD2 | Offset | MeshPart centre | Size | Tris LOD0 / 1 / 2 |
|---|---|---|---|---|---|---|---|---|
| 12 | `M_Upg_RIB_MegaOutboard` | 98639198529084 | 86059475039109 | 72315557690119 | (0, 0, 0) | (0.011, 3.897, 14.291) | 6.33 x 10.79 x 6.83 | 2410 / 1204 / 602 |
| 13 | `M_Upg_RIB_ArchSpoiler` | 116030585968562 | 88196744663885 | 136511797522834 | (0, 0, 0) | (-0.000, 9.569, 12.478) | 13.84 x 13.24 x 6.61 | 2928 / 1318 / 340 |
| 14 | `M_Upg_RIB_NeonFins` | 79328733337164 | 73222465070696 | 94722638916549 | (0, 0, 0) | (-0.000, 5.997, 2.355) | 15.18 x 6.90 x 21.01 | 560 / 280 / 304 |
| 15 | `M_Upg_RIB_FatTubes` | 86697296702116 | 93432947657491 | 103797818273246 | (0, 0, 0) | (-0.000, 4.364, -0.681) | 15.49 x 5.05 x 28.29 | 6004 / 2684 / 748 |
| 16 | `M_Upg_RIB_Grandstand` | 117595243418650 | 134490912634144 | 70432418561412 | (0, 0, 0) | (-0.000, 6.740, -6.213) | 6.20 x 9.82 x 6.46 | 3072 / 1536 / 768 |
| 17 | `M_Upg_RIB_PaddleWheel` | 109320639614548 | 106619047072083 | 132796902749912 | (0, 0, 0) | (-0.000, 4.935, 1.576) | 20.20 x 8.19 x 8.72 | 5216 / 2608 / 1036 |
| 18 | `M_Upg_RIB_SharkJaws` | 136929174244204 | 92368658020360 | 76217202482056 | (0, 0, 0) | (-0.000, 8.782, -12.749) | 18.60 x 16.04 x 12.24 | 6676 / 2888 / 824 |
| 19 | `M_Upg_RIB_ExhaustOrgan` | 128653515821273 | 85194605282436 | 84571332158836 | (0, 0, 0) | (-0.000, 7.342, 7.076) | 14.32 x 11.00 x 2.20 | 3056 / 1528 / 640 |
| 20 | `M_Upg_RIB_ThunderWing` | 128101179605400 | 106932148401910 | 109157104963269 | (0, 0, 0) | (-0.000, 17.114, 12.376) | 22.24 x 7.74 x 2.94 | 584 / 264 / 104 |

Shared palette set (one SurfaceAppearance for all nine), `T_UpgRIB_Brick_*`, 1024 px: ALB 90625295362268, NOR 134063939343985, RGH 138028895836822, MET 77201546496505. RGH and MET carry per-colour roughness and metal. NOR has the same bytes as the other kits' flat normal, so it reuses that id.

LOD0 total with all nine on: 30506 tris (hull not counted).

## Checks

validate PASS for all nine (waived: `_COL proxy`, `LOD UV layout`, `texture sets`; `LOD0 floor` where a piece is under 1000 tris; reasons in `pieces.py`). zfight: 27 exported FBX read back, 0 visible pairs; all nine LOD0 together with the hull's LOD0 (no Engines), 0 visible pairs involving a piece. That scan also finds 7 pairs inside the shipped hull itself; left alone. `preview.zfight_with_hull()` reads the exported LOD0s. Sheet: `build/status/2026-11-04/art/rib.png`. The sheet's phone cell uses the concept's camera (0, 19.1, 40) looking at (0, 5.5, 0), 55 degrees vertical; the driver there is a preview-only stand-in (`preview.py`), not exported.

## For the wiring code

- **Hide the hull's `M_Veh_RIB_Engines` MeshPart from L12 on**, or the old outboards poke through the Mega Outboard (the concept's "replaces" note). The sheet is rendered that way.
- **Keep `M_Veh_RIB_Tubes` and `_Decals` on at L15.** The concept hid the collar; here the fat tube sits on the old one, so nothing floats and no code step is needed.
- **Cumulative, order matters:** Fat Tubes carries the sockets for the spoiler posts and Neon Fins; Paddle Wheel, Shark Jaws and Exhaust Organ sit on Fat Tubes; Thunder Wing grows from the Arch Spoiler's endplates. A piece shown without its mount floats.
- **Collision:** pieces are visual only (`CanCollide` off); the hull's `_COL` stays the collision.
- **Width:** Thunder Wing 22.2 studs (was 28.4), Paddle Wheel 20.2 (was 24), Shark Jaws 18.6, against an 8.7 stud hull, so docks and gates clear differently. Top is y 21 (bolt tips).
- **Paddle Wheel is one mesh:** both wheels and their boxes are one MeshPart, so they cannot spin. Spinning needs them split out.
- **Neon Fins are opaque palette colour** with no glow: Neon material or light from code needs its own hook.

## Changed from the concept (art director round 1 at 6.5, coordinator's fix list)

The L20 goal is one joke: the shark. A huge open-mouthed shark on the bow, its dorsal fin rising behind the crowd, an orange rescue boat behind it, and a spoiler topped with one clean bolt each side.

- **Shark Jaws:** much bigger (18.6 wide with pectoral fins, top y 16.8): bigger eyes, 8 + 6 larger teeth, dark mouth wall hiding the tube's nose, white lower jaw, gills. Dorsal fin sculpted to a point so it reads from behind. Pectoral fins added: they say "shark" from the chase camera.
- **Thunder Wing:** one kink per bolt, 46 degrees up, thinner (2.9 deep), studs on the aft face. No second wing, posts, slots or livery.
- **Exhaust Organ:** shrunk to three small stepped pipes per side on a collar round the fat tube, tops y 12.8 (concept 19.4), under the spoiler and outside its posts in the chase view, so the layers read cowl, driver and crowd, spoiler, bolts.
- **Paddle Wheel:** shrunk (radius 3.3, concept 4.4), moved forward to z 1.5, orange boxes, dark rims, white paddles.
- **Colours:** the hull's orange and charcoal are the anchor. Blue is the shark and spoiler; yellow is now only the bolts, the engine badge and two fan shirts. Fat tube band is white, not yellow; Neon Fins are bright blue (concept green), so they read as more shark fins; cowl is charcoal with an orange band (concept yellow).
- **Mounts:** stepped plinths and orange clamps on the spoiler posts, wrap-round collars carrying the tube fenders, sockets where posts and fins come through the fat tube, a bolted flange on each sponson, a transom plate on the engine.
- **Surface:** stud rows along the fat tubes, foil, wheel boxes, head and bolts; dark seam grooves on the tubes and cowl; bolt heads on plates; bigger bevels.
- **Grandstand:** faces aft, so the chase camera sees the fans. Flags and poles cut as thin noise; seats merged into the tiers.
- **Mega Outboard:** cowl wider and lower (top y 8.9, concept 11.3); driver stays in view.
- **Arch Spoiler:** arched foil raised to y 15 (concept 12.9), so driver and crowd read under it.
- **Neon Fins:** four tall fins only. Keel fin and chine strips cut.
- **Studs:** 1.0 pitch, 0.68 across (concept 0.6, 0.36), to read on a phone.

No ATT_ attachments are exported (Jet Ski kit has none either); add them when VFX wiring needs them.
