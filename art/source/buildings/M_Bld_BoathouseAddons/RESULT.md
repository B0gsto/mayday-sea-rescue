# M_Bld_BoathouseAddons result (PERF-BL11, was docs/25 Lv3 add-on only)

Shipped r6 (AD median 9.03; r1 8.0, r2 8.7, r3 8.83, r4 9.0, r5 9.0, cap 6; Lv3 8.8 is the gap). Ids: LOD0 84876267561523, LOD1 88085866697598, LOD2 71886407094869; ALB 117574394415719. Not seen in Studio. Next round per build/status/2026-11-01/perfect/buildings/Boathouse/r6_AD.md.

PERF-BL11 r6 (2026-11-03, not uploaded): the Lv3 hall stands 6 further to the sea (x 44..61, deck x 30..67.5, 8 x 2 plates, a dark edge trim, a low walk-over stop bar where Lv2's lane meets it): the gable, Lifeboat and 02 are fully clear with a sky gap in the path view. The new `Lv2_L05_LaneWet` (the lane's wet end) drops at Lv3 (DockPieces `boathouseLevel`). Lookout 10% smaller with a white cap; Launch sign 14 x 3.1; 03 k 1.0. Mast off the deck's sea end at (69.1, -45.8), lamp z 22 (was 25.5), head 25% smaller, a studded red hood, a stepped bracket, a brick base; it stays inside the path frame. Lv2: Lifeboat sign 22 x 4.8 at z 16.4, 02 k 1.5, gable rise 2.8 (peak 32.8), post caps 15% wider (2 stripes kept), lane 20% wider, rails 1.5x, raised sleeper tiles, a white tile band on the back wall. Lv1: side windows +20% with dark frames and red sills, two white brick pilasters a side, brick courses on the bay's inner sides, 6 yellow wall lamps, slipway sleeper tiles with 0.05 seams. LOD0 32,834 / LOD1 16,409 / LOD2 8,196; validate PASS (624, 0 failed, 131 waived); [zfight] 0 visible pairs. Code: DockPieces `lifeboatSlip` (sign), `boathouseLevel` (Launch sign, wet lane); AssetIds (ATT_ReadyRoom moved; no code reads it). Sheet: `lineup.py r6`. Routes (flood fill of the COL boxes, radius 1 and 1.5): every bay, the shed, the deck, the porch and the hall's inside are reachable. The r5 back wall closes the walk through the shed's back (end gaps 0.7); round either end of the shed instead. Not seen in Studio.

PERF-BL11 r5 (2026-11-03, not uploaded): Lv3 gets its own silhouette. Hall x 38..55, y -45..-38 (17 x 7, walls 11.25, eave 11.9, 6 courses, ridge 19.1, cap 20.6; deck x 30..55.5), a blue lookout with a studded red cap on the ridge (top 23), its back end clear of the Lifeboat sign from the plaza; door 7.2 x 6.85 clear, new code sign "Launch" 11.4 x 2.5 in a frame over it, "03" above; mast moved past Lv2's lane to x 67.7 (open cove, same y), lens x 1.2, head on a grey bracket. Launch boat: stepped brick hull, red waterline, bigger foredeck studs; deck in tan plates with 0.05 seams, a tan stud row, two bollards, red-banded pilings; dark ramp sleepers. Lv1: arch interior darker (back wall dark grey, sides and ceiling mid grey), a 1-stud dark reveal behind the arch. Lv2: posts x 1.19 thicker, 3 courses with a proud red band and a dark base seam; front 77.6 and back 42/54/66 posts gone, a dark coursed back wall instead (x 33..75, own collision box). LOD0 30,646 / LOD1 15,316 / LOD2 7,651; validate PASS (601, 0 failed, 126 waived); [zfight] 0 visible pairs. Code: DockPieces `boathouseLevel` (Launch sign); AssetIds (ATT_ReadyRoom moved; no code reads it). Sheet: `lineup.py r5`. Open: hall shift is limited by Lv2's lane and the door porch (about 1 x, 0.6 y, not 4-6); r4 list items 6, 7 not done (Lv2 plaque margins, barge boards, Lv1/Lv2 slipways, flank, path seams). Not seen in Studio.

PERF-BL11 r4 (2026-11-03, not uploaded): Lv3 simplified to read alone. The hall moved to the deck's sea end (x 38..53, 15 x 7, ridge 14.9, cap 16.4; deck x 30..54), right of Lv2's boat, its cap just clear of the Lifeboat sign from the plaza; the launch turned 180 degrees (`launch_turn`, ramp x 30 -> 14), so only low things stand in front of Lv2's colonnade and open water separates it from Lv1's slipway. Gone: GO plaque, life-ring board, red kerb block, winch motor, bow stop, yellow rim and studs. One clean grey winch with a yellow drum, grey cradle, boat x 1.15, white 0.4 deck trim, door 6 x 6.4, one big side window, mast at the sea corner (55.2, -46.6). All gables: continuous barge board + thin white fascia via `rakes` (studs and ridge caps kept). Lv2: Lifeboat sign 19 x 4.1 at z 16.6, "02" x 1.30 clear of the rakes. Lv1: mid-grey back wall, light seams, sleepers every 3 studs, full-length bevelled kerbs, yellow rail end caps. LOD0 29,598 / LOD1 14,794 / LOD2 7,391; validate PASS (616, 0 failed, 128 waived); [zfight] 0 visible pairs. Code: DockPieces `lifeboatSlip` (sign); AssetIds (ATT_Launch, ATT_Work_Winch, ATT_ReadyRoom moved; no code reads them). Sheet: `lineup.py r4`. Open: hall is +20% wide, not +25-30% (sign and mast limit it); the hall hides the top of Lv2's wet lane from the plaza. Not seen in Studio.

PERF-BL11 r3 (2026-11-03, not uploaded): Lv3 is one hall, not twin roofs: the deck moved to x 12.4..36 (23.6 x 12), clear of the Lv1 lane; a single red stepped gable with its ridge along Y facing the path (ridge 15.75, cap 17.25; the cone from the plaza to the Lifeboat sign caps it there), "03" sticker; the blue cabin at x 13.35..25.85, y -42.3..-35.4 (12.5 wide, walls 9.6) with the walk-in door moved to the path side (5.4 wide, head 5.6), red surround, a GO plaque, coursed walls, a lit interior; piers = Lv2's post at 70%, 3 courses, red stud caps; fascia = a white brick course + red trim; winch x 33.5, ramp 36..52 (steeper), mast base a 2-course studded plinth, head 1.3x bevelled on a yellow bracket. ATT_Launch, ATT_Work_Winch, ATT_ReadyRoom moved (AssetIds; no code reads them). All roofs: studs r 0.95 / h 0.42, chunky white stepped ridge caps. Lv1: stepped brick barge boards, white coursed gables with a 1-stud blue trim, back wall brick-coursed with three blue panels and two life rings (rack gone; the red dashes were the back quoins poking through, now outside only). Lv2: Lifeboat sign 22.4 x 4.8 at z 17.2, "02" x 1.55, posts x 1.3 with stepped footings and caps, red plate band z 9.6..11.05, eave +1, white tile strips on the pad edges, boat 1 forward. LOD0 30,624 / LOD1 15,305 / LOD2 7,645; validate PASS; [zfight] 0 visible pairs. Code: DockPieces `lifeboatSlip` (sign size, height); AssetIds. Sheet: `lineup.py r3`. Open: from the plaza the hall covers most of the Lv2 boat's body at Lv3 (bow, sign and gable stay clear). Not seen in Studio.

PERF-BL11 r2 (2026-11-03, not uploaded): the plaza view now sees the whole arch, sign and lane. Lv3: everything west of x 6.6 gone (bay x 6.6..33, deck 23 x 12); the ready room moved to x 13..23 with its door turned to the plaza and a lit back wall; winch x 26 (ATT_ReadyRoom, ATT_Work_Winch moved, ATT_Launch kept; no code reads them but AssetIds); Lv1 lane's wet end stays at Lv3 (drop code removed); columns = Lv2's stacked posts, stud footings; fascias = stepped seamed plates + red tile course; low ridges 12.2 / 13.6; go lamp on its own banded mast off the ramp's far end (x 54, lamp 25.5, housing 1.5x), own peak with sky. Lv2: cross gable 7 nearer the path on a tiled studded pad, x 61, hw 14, peak 30, code sign 16.9 x 3.64; lifeboat = Lv1's workboat x 1.15 with an orange stripe, bow out in the sun; a ramp to the water like Lv1's. Lv1: red/white base course, red quoins, plinth rim, lit side walls, rack and lamp on the back wall, chunky slats, lane kerb; white roof bands gone, straight barge boards on every roof. Sheet: icon stand-ins are life rings (the game's are real images). LOD0 29,332 / LOD1 14,663; validate PASS (651, 0 failed, 135 waived); [zfight] 0 visible pairs. Code: DockPieces `lifeboatSlip` (sign), `boathouseLevel`; AssetIds. Not seen in Studio.

PERF-BL11 r1 (2026-11-03, not uploaded; palette changed, so a new ALB too): the Boathouse's Lv1 and Lv2 shed become meshes (code Parts stay the
fallback; the code keeps plinths, name signs, board slot, slipway). Lv1: blue brick walls, white piers, a big arched boat-bay door (blue voussoirs,
yellow keystone, half-rolled red shutter, clear +-12 wide, 10.5 high), portholes, stepped studded red roof (one white band, dark eave, ridge cap), blue
stepped gable, code sign 18.6 x 3.72 in a red frame, hull-number sticker "01", flag; white workboat on brick stands in the door's mouth, a walk-over stone
lane with yellow rails out over the cove walk to the water (`Lv1_L07_LaneWet` drops at Lv3). Lv2 (x 29..79): stacked-brick posts, stepped blue roof,
a cross gable facing the path (peak 26.5, second code sign "Lifeboat" 13 x 2.8, sticker "02"), orange lifeboat on a trolley (`Lv2_L04_Lifeboat`
hides while yours is out). Lv3: roof gap over the lane (x +-6.5) and lower sections so the door, sign and Lv2 gable stay visible from the plaza;
columns are stacked bricks with footings and bevelled caps (12, were 12 flat + braces; X braces, knee braces and handrails gone); the ready room is bright
blue with two windows toward the plaza; kerb split round the lane. ATT_* unchanged. Palette: cells 12/13 are dark blue/blue (were unused), orange
lighter. Budget hero_building, LOD shares patched (large_prop 50/25%). LOD0 27,522 / LOD1 13,756; validate PASS (661, 0 failed, 137 waived); [zfight] 0
visible pairs. Code: DockPieces `boathouse`, `lifeboatSlip`, `boathouseLevel`; WorkerController `bayBoat`. Sheet: `lineup.py r1`; path view = the plaza
centre (right 5, fwd 16). Not seen in Studio. Older sections below describe the Lv3 bay before this pass. fit_check.py predates it.

## Lv3 bay, docs/25 round 3

Validate PASS (356 checks, 0 failed, 67 waived: gameplay node/layer naming, flat-palette LOD UV layout).
LOD0 7,894 tris / 7 visual meshes (budget 8,000): L01_Deck 1,864, L02_QuayEdge 452, L03_Ramp 204, L04_Roof 3,012,
L05_ReadyRoom 1,000, L06_Launch 1,102, L07_Lifeboat 260; LOD1 3,943, LOD2 1,970; COL 32 boxes x 12 tris, all in the
LOD0 FBX. Set: 1 (T_Boathouse_Brick, 16-cell flat palette, 1024; cell 8 is go-lamp green).
Size 79.75 x 14.55 x 33.35 studs (x -27.75..52.00, y -47.55..-33.00, z -4.80..28.55). Origin the code boathouse's
ground centre, built at its final 1.2 scale (no extra scale). Sea = +x, plaza = -x, cove = -Y.

## Island fit (fit_check.py, PASS)
Game frame: right = -80 - y, fwd = 58 + x (Boathouse spot isle(-80, 58, -90), Blender X flips on export). Extents:
visual right -47.00..-32.45, fwd 30.25..110.00; COL right -46.20..-32.60, fwd 30.40..110.00; ATT right -42.4..-39.0,
fwd 38.5..100. Every box is on the plate or over the cove water, clear of the cove walk (right -56..-48), the code
boathouse plinth, the code slip and its slipway, the Harbour pontoon (right -32..-24: 0.45 stud clear), the Jetty lot
and head deck, and every other DockConfig lot. The pontoon caps the bay's depth at 12 studs.

## Round 3 changes (AD 7.5, fixes in priority order)
1. Lifeboat: the trolley moved from the covered pad to the top of the slipway (1..12 studs down the slope from the
   head, tilted with it, mostly past the roof end) so front and high views see it. It carries an orange-and-white Lego
   lifeboat (orange hull, white gunwale deck, white wheelhouse with a navy window band, orange studded roof, navy
   transom band, white foredeck studs), bow to the sea, as its own mesh `Lv3_L07_Lifeboat`. Trolley: yellow bunks
   on black wheels, grey cross members, red bow stop, yellow hook eye; the winch cable now runs out to it.
2. Roof: three stepped sections (ends eave 13.5 / ridge 18.5, middle x -7..18 eave 15 / ridge 20.5), each ringed by a
   white fascia band up its first course and across both gable feet; columns are 1.5 (ends) and 3 (middle) taller.
3. Go lamp on a white mast with two red bands rising from the sea-end ridge (lamp centre z 26, top 28.6, 8 above the
   highest ridge); green lenses face both the sea and the quay.
Budget: deck plank butt joints every 9 studs (was 5.2) pays for the boat and mast.

## Parts
Nodes (layers bottom to top): `Lv3` (`L01_Deck`, `L02_QuayEdge` = the kerb, `L03_Ramp`, `L04_Roof`, `L05_ReadyRoom`,
`L06_Launch` = winch, trolley, lamp mast, cable, `L07_Lifeboat`). Collision: one box per object, `Lv3_Col01_COL`..
`Lv3_Col32_COL` (deck, kerb, room walls/stubs/header, bench, winch, six ramp steps, three roof sections, 12 columns,
one tilted box round the lifeboat and trolley). Attachments: ATT_Launch (42.0, -41.0, ramp; now under the static
boat), ATT_Work_Winch (10.0, -37.6, 0.55), ATT_ReadyRoom (-19.5, -41.0, 0.55).

Renders: `build/prod/M_Bld_BoathouseAddons/review/M_Bld_BoathouseAddons/2026-10-27_sheet.png` plus turntable and five
close-ups (ready_room, winch, lifeboat, go_light, roof); levels sheet `levels/levels_sheet.png` (copy:
`sheet_levels.png` here) with grey Lv1/Lv2 stand-ins at their game positions and a grey pontoon.

Open: not playtested in Studio or wired into the game; not in `src`, docs/12 or `art/reference/M_Bld_BoathouseAddons/dims.md`.
Code launching a spawned boat should hide `Lv3_L07_Lifeboat` (and its COL box Lv3_Col32) meanwhile. The ramp's top ends
at z -4.2 (0.2 under sea level). Jetty-head and slip footprints in fit_check are estimated from DockConfig/DockPieces/
RingLayout, not read from Studio. Code placing the asset must use the boathouse's CFrame with no extra scale or mirror.
Awaiting the art-director round.
