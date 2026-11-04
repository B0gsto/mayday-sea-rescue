# RIB stage upgrade pieces (L12-L20): result

Concept: artifact 0ae647e2 (RIB Stage Concept). Geometry: `pieces.py` (mesh helpers from `../_UpgJetSki/kitgeo.py`), one thin `build.py` per piece in `art/source/vehicles/M_Upg_RIB_*`. Rebuild: `python3 art/source/vehicles/_UpgRIB/palette.py build/prod/_UpgRIB/textures`, then in Blender `import pipeline; pipeline.run_all()`, then `upload.sh` from the game root.

## Ids

Every piece is authored in the frame of the shipped `M_Veh_RIB` (`frame_offset.json`), so its **Model pivot is the hull origin: offset (0, 0, 0)**. `Model:PivotTo(hullModel:GetPivot())` is all a piece needs. `MeshPart centre` is relative to that pivot, in Roblox axes (x starboard, y up from the skeg base, z aft, bow at -z). Not checked in Studio.

| Lv | Asset | LOD0 | LOD1 | LOD2 | Offset | MeshPart centre | Size | Tris LOD0 / 1 / 2 |
|---|---|---|---|---|---|---|---|---|
| 12 | `M_Upg_RIB_MegaOutboard` | 70563698713016 | 130524306765486 | 109022318997102 | (0, 0, 0) | (0.011, 3.897, 14.291) | 6.33 x 10.79 x 6.83 | 1518 / 758 / 486 |
| 13 | `M_Upg_RIB_ArchSpoiler` | 124954465174783 | 123340117435572 | 94885735943322 | (0, 0, 0) | (-0.000, 9.449, 12.613) | 13.52 x 13.00 x 6.28 | 980 / 458 / 168 |
| 14 | `M_Upg_RIB_NeonFins` | 90629080029018 | 92400242265440 | 138941144991421 | (0, 0, 0) | (-0.000, 6.009, 2.358) | 15.14 x 6.85 x 20.98 | 384 / 384 / 256 |
| 15 | `M_Upg_RIB_FatTubes` | 85576999063939 | 138799474149536 | 76312052081249 | (0, 0, 0) | (-0.000, 4.200, -0.681) | 15.04 x 4.40 x 28.29 | 3196 / 1220 / 500 |
| 16 | `M_Upg_RIB_Grandstand` | 97614390491941 | 100645475721822 | 135926698188308 | (0, 0, 0) | (-0.000, 6.747, -6.215) | 6.00 x 9.81 x 6.43 | 2784 / 1392 / 696 |
| 17 | `M_Upg_RIB_PaddleWheel` | 76154205834196 | 72976635737108 | 128040962797393 | (0, 0, 0) | (-0.000, 6.165, 3.676) | 24.00 x 10.54 x 11.26 | 3912 / 1956 / 978 |
| 18 | `M_Upg_RIB_SharkJaws` | 70652591807313 | 105243537709759 | 124175027087838 | (0, 0, 0) | (-0.000, 7.598, -12.660) | 9.59 x 12.87 x 8.24 | 5124 / 2352 / 684 |
| 19 | `M_Upg_RIB_ExhaustOrgan` | 100776840024989 | 97258457280862 | 129767023843422 | (0, 0, 0) | (-0.000, 9.776, 5.776) | 11.84 x 15.35 x 3.40 | 2872 / 1436 / 604 |
| 20 | `M_Upg_RIB_ThunderWing` | 81290368198868 | 93819504102567 | 133037015568680 | (0, 0, 0) | (-0.000, 16.533, 12.376) | 28.45 x 7.45 x 3.90 | 104 / 104 / 104 |

Shared palette set (one SurfaceAppearance for all nine), `T_UpgRIB_Brick_*`, 1024 px: ALB 82036918491208, NOR 134063939343985, RGH 138028895836822, MET 77201546496505. RGH and MET carry per-colour roughness and metal. NOR has the same bytes as the other kits' flat normal, so it reuses that id.

LOD0 total with all nine on: 20874 tris (hull not counted).

## Checks

validate PASS for all nine (waived: `_COL proxy`, `LOD UV layout`, `texture sets`; `LOD0 floor` where a piece is under 1000 tris; reasons in `pieces.py`). zfight: 27 exported FBX read back, 0 visible pairs; all nine LOD0 together with the hull's LOD0 (no Engines), 0 visible pairs involving a piece. That scan also finds 7 pairs inside the shipped hull itself; left alone. Sheet: `build/status/2026-11-04/art/rib.png`. The sheet's phone cell uses the concept's camera (0, 19.1, 40) looking at (0, 5.5, 0), 55 degrees vertical; the driver there is a preview-only stand-in (`preview.py`), not exported.

## For the wiring code

- **Hide the hull's `M_Veh_RIB_Engines` MeshPart from L12 on**, or the old outboards poke through the Mega Outboard (the concept's "replaces" note). The sheet is rendered that way.
- **Keep `M_Veh_RIB_Tubes` and `_Decals` on at L15.** The concept hid the collar; here the fat tube sits on the old one, so nothing floats and no code step is needed.
- **Cumulative, order matters:** Neon Fins are tall so they still stand clear when Fat Tubes swallow their roots; Paddle Wheel's sponson and Shark Jaws sit on Fat Tubes; Exhaust Organ's banks rest on the deck and Fat Tubes; Thunder Wing grows from the Arch Spoiler's endplates. A piece shown without its mount floats.
- **Collision:** pieces are visual only (`CanCollide` off); the hull's `_COL` stays the collision.
- **Width:** Paddle Wheel is 24 studs wide and Thunder Wing 28.4, against an 8.7 stud hull, so docks and gates clear differently. Top is y 20.3 (bolt tips).
- **Paddle Wheel is one mesh:** both wheels and their boxes are one MeshPart, so they cannot spin. Spinning needs them split out.
- **Neon Fins are opaque palette colour** with no glow: Neon material or light from code needs its own hook.

## Changed from the concept (art director's lessons)

The L20 goal is one joke: a shark boat whose spoiler sprouts two huge lightning bolts, with the driver and a cheering crowd in view from the chase camera.

- **Thunder Wing:** no second wing, posts, slots or livery. Two chunky bolts grow out of the spoiler's endplates. On a chase camera a flat wing's top collapses into a line; the bolts stay readable.
- **Colours:** base is the hull's orange and charcoal, accents are one yellow and one blue, neutrals white, dark, chrome. Neon green fins become neon yellow, red wheels yellow and white, shark blue, pink mouth dark, rainbow bands one blue band.
- **Grandstand:** faces aft, so the chase camera sees the fans, on yellow wedge cheeks. Flags and poles cut as thin noise; seats merged into the tiers.
- **Exhaust Organ:** two banks of three fat pipes with the driver in the gap, tallest outside, top y 17.4 (concept: six thin pipes to 19.4 in one wall).
- **Mega Outboard:** cowl wider and lower (top y 8.9, concept 11.3); driver stays in view. Vents, handle, ram tubes cut.
- **Arch Spoiler:** arched foil raised to y 15 (concept 12.9), so driver and crowd read under it. Fat wedge uprights. Chevrons, flap, tail lights cut.
- **Paddle Wheel:** six fat paddles, three thick spoke bars, sculpted sponson, solid inner wall. Thin axles and pedestals cut.
- **Neon Fins:** four tall fins only. Keel fin and chine strips cut (under or at the water, thin).
- **Shark Jaws:** few big teeth (8 + 6), dark mouth wall hiding the tube's nose, white lower jaw.
- **Studs:** 1.0 pitch, 0.68 across (concept 0.6, 0.36), to read on a phone.

No ATT_ attachments are exported (Jet Ski kit has none either); add them when VFX wiring needs them.
