# RIB stage upgrade pieces (L12-L20): result

Concept: artifact 0ae647e2 (RIB Stage Concept). Geometry: `pieces.py` (mesh helpers from `../_UpgJetSki/kitgeo.py`), one thin `build.py` per piece in `art/source/vehicles/M_Upg_RIB_*`. Rebuild: `python3 art/source/vehicles/_UpgRIB/palette.py build/prod/_UpgRIB/textures`, then in Blender `import pipeline; pipeline.run_all()`, then `upload.sh` from the game root.

## Ids

Round 3 ids; they replace every earlier id.

Every piece is authored in the frame of the shipped `M_Veh_RIB` (`frame_offset.json`), so its **Model pivot is the hull origin: offset (0, 0, 0)**. `Model:PivotTo(hullModel:GetPivot())` is all a piece needs. `MeshPart centre` is relative to that pivot, in Roblox axes (x starboard, y up from the skeg base, z aft, bow at -z). Not checked in Studio.

| Lv | Asset | LOD0 | LOD1 | LOD2 | Offset | MeshPart centre | Size | Tris LOD0 / 1 / 2 |
|---|---|---|---|---|---|---|---|---|
| 12 | `M_Upg_RIB_MegaOutboard` | 122320592445349 | 127878069442866 | 96038485319866 | (0, 0, 0) | (0.011, 3.897, 14.291) | 6.33 x 10.79 x 6.83 | 2410 / 1204 / 602 |
| 13 | `M_Upg_RIB_ArchSpoiler` | 131134470933375 | 124828336065215 | 124815326827560 | (0, 0, 0) | (-0.000, 8.839, 11.688) | 13.44 x 11.98 x 6.56 | 1424 / 578 / 236 |
| 14 | `M_Upg_RIB_NeonFins` | 72329043429762 | 84523306083279 | 105154504332735 | (0, 0, 0) | (-0.000, 6.006, 2.355) | 15.18 x 6.88 x 21.01 | 384 / 384 / 256 |
| 15 | `M_Upg_RIB_FatTubes` | 101081840884770 | 70443479599324 | 140394473275915 | (0, 0, 0) | (-0.000, 4.870, -0.343) | 15.49 x 6.06 x 28.96 | 6332 / 2704 / 828 |
| 16 | `M_Upg_RIB_Grandstand` | 117595243418650 | 134490912634144 | 70432418561412 | (0, 0, 0) | (-0.000, 6.740, -6.213) | 6.20 x 9.82 x 6.46 | 3072 / 1536 / 768 |
| 17 | `M_Upg_RIB_PaddleWheel` | 133311546322137 | 92946640205751 | 108214220460630 | (0, 0, 0) | (-0.000, 4.935, 1.576) | 20.20 x 8.19 x 8.72 | 4872 / 2436 / 1052 |
| 18 | `M_Upg_RIB_SharkJaws` | 88611961898504 | 78848919349112 | 115929708138480 | (0, 0, 0) | (-0.000, 11.382, -12.606) | 18.60 x 21.24 x 12.52 | 6676 / 2888 / 824 |
| 19 | `M_Upg_RIB_ExhaustOrgan` | 133320752988996 | 128025747485496 | 115565020715266 | (0, 0, 0) | (-0.000, 6.042, 7.076) | 14.32 x 8.40 x 1.70 | 1904 / 952 / 400 |
| 20 | `M_Upg_RIB_ThunderWing` | 80355391833667 | 97759578350775 | 81648303666104 | (0, 0, 0) | (-0.000, 14.903, 12.446) | 19.43 x 3.43 x 1.76 | 296 / 168 / 104 |

Shared palette set (one SurfaceAppearance for all nine), `T_UpgRIB_Brick_*`, 1024 px: ALB 90625295362268, NOR 134063939343985, RGH 138028895836822, MET 77201546496505. RGH and MET carry per-colour roughness and metal. NOR has the same bytes as the other kits' flat normal, so it reuses that id.

LOD0 total with all nine on: 27370 tris (hull not counted).

## Checks

validate PASS for all nine (waived: `_COL proxy`, `LOD UV layout`, `texture sets`; `LOD0 floor` where a piece is under 1000 tris; reasons in `pieces.py`). zfight: 27 exported FBX read back, 0 visible pairs; all nine LOD0 together with the hull's LOD0 (no Engines), 0 visible pairs involving a piece. That scan also finds a few pairs inside the shipped hull itself (6 or 7, varies by run); left alone. `preview.zfight_with_hull()` reads the exported LOD0s. Sheet: `build/status/2026-11-04/art/rib.png`. The sheet's phone cell uses the concept's camera (0, 19.1, 40) looking at (0, 5.5, 0), 55 degrees vertical; the driver there is a preview-only stand-in (`preview.py`), not exported.

## For the wiring code

- **Hide the hull's `M_Veh_RIB_Engines` MeshPart from L12 on**, or the old outboards poke through the Mega Outboard (the concept's "replaces" note). The sheet is rendered that way.
- **Keep `M_Veh_RIB_Tubes` and `_Decals` on at L15.** The concept hid the collar; here the fat tube sits on the old one, so nothing floats and no code step is needed.
- **Cumulative, order matters:** Fat Tubes carries the sockets for the spoiler posts and Neon Fins; Paddle Wheel, Shark Jaws and Exhaust Organ sit on Fat Tubes; Thunder Wing grows from the Arch Spoiler's endplates. A piece shown without its mount floats.
- **Collision:** pieces are visual only (`CanCollide` off); the hull's `_COL` stays the collision.
- **Width:** Paddle Wheel 20.2 studs, Thunder Wing 19.4, Shark Jaws 18.6, against an 8.7 stud hull, so docks and gates clear differently. Top is y 22 (dorsal fin tip).
- **Paddle Wheel is one mesh:** both wheels and their boxes are one MeshPart, so they cannot spin. Spinning needs them split out.
- **Neon Fins are opaque palette colour** with no glow: Neon material or light from code needs its own hook.

## Changed from the concept (art director rounds 1 and 2, coordinator's fix lists)

The L20 goal is one joke: the shark. A huge open-mouthed shark on the bow, its giant dorsal fin towering over everything from the chase camera, an orange rescue boat behind it.

- **Shark Jaws:** much bigger (18.6 wide with pectoral fins): bigger eyes, 8 + 6 larger teeth, dark mouth wall hiding the tube's nose, white lower jaw, gills. Dorsal fin rises to y 22, swept aft over the crowd, concave trailing edge; from the chase camera it stands clear above the wing and bolts. Pectoral fins added: they also read from behind.
- **Thunder Wing:** cut to two small one-kink bolts on the spoiler's endplates, 19.4 across, tips under the fin in the chase view. Still yellow. No second wing, posts, slots or livery.
- **Arch Spoiler:** thin foil (0.6 thick, chord 3.9) at y 14.3, trailing edge and endplates in hull orange, so it reads as trim, not a blue slab. Driver and crowd read under it. Posts flare out of the tube in hull orange, then charcoal, with one orange clamp.
- **Exhaust Organ:** cut hard to two short stepped pipes per side on a collar round the fat tube, tops y 9 and 10.2 (concept six pipes to 19.4). Only just an organ now; the rear view needed it gone.
- **Paddle Wheel:** shrunk (radius 3.3, concept 4.4), moved forward to z 1.5. Hull-orange sponson flares out of the fat tube; orange boxes, dark rims, white paddles.
- **Fat Tubes:** hull-orange flared fairings where the spoiler posts and fins come through; wrap-round collars carry the fenders; white band (concept yellow); stud rows and seam grooves.
- **Colours:** the hull's orange and charcoal are the anchor. Blue is the shark, foil centre and Neon Fins (bright blue, concept green, so they read as more shark fins). Yellow is only the bolts, the engine badge and two fan shirts. Cowl is charcoal with an orange band (concept yellow).
- **Grandstand:** faces aft, so the chase camera sees the fans. Flags and poles cut as thin noise; seats merged into the tiers.
- **Mega Outboard:** cowl wider and lower (top y 8.9, concept 11.3); driver stays in view. Dark stacks, not chrome.
- **Neon Fins:** four tall fins only. Keel fin and chine strips cut.
- **Studs:** 1.0 pitch, 0.68 across (concept 0.6, 0.36), to read on a phone.

No ATT_ attachments are exported (Jet Ski kit has none either); add them when VFX wiring needs them.
