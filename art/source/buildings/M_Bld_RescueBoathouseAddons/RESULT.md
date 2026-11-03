# M_Bld_RescueBoathouseAddons result (docs/25 B + J, 2026-10-27, art-director round 3)

Shipped r6 (AD median 8.93; r1 8.03, r2 8.8, r3 8.8, r4 8.93, r5 8.93, cap 6). Ids: LOD0 116757607794615, LOD1 88387634235000, LOD2 116162836339061; ALB 115194074228860. Not seen in Studio. Next round per build/status/2026-11-01/perfect/buildings/RescueBoathouse/r6_AD.md.

PERF-BL11 r6 (2026-11-03, not uploaded, last round): fix list r5_AD, polish only. Crest: a 20% larger ring on a white plaque with a red rim and a red stepped backing; the dark block that poked through the board is gone. Roof: the mid-slope white band gone, bright red edge tiles, one straight 2-stud white tile course on a red lip along the front eave. Lv1: dormers 1 up on a square red collar; arch crown and stepped corners trimmed 1 brick, launch rails moved out each side of the hull (ending short of the boat slot), stands light grey, apron yellow/grey, hall wall seams halved; walk-in door: 2-stud step, small white-red awning. Lv2: white stepped edge tiles (edge, edge_t) over a red stair-step chevron, white field, orange trim beside the plaque, red plaque frame, boat relief, red/white stripe on the blue ridge. Lv3: hoisted boat is one smooth hull (the dinghy's lines), white rub rail, orange cabin, two 0.4 slings, top 2 under the header; a 2-brick red/white tower stage between the windows, studded white crown tiles. Hall wall check: no player route blocked (open x +-10..side walls at every level; Lv3 via the walkway), but two worker slots fell foul of it, so WORK_SPOTS.RescueBoathouse moved: trailer slot behind the wall, chair slot off its end. ATT_* unchanged. Sheet: `lineup.py r6`. Not seen in Studio.

PERF-BL11 r5 (2026-11-03, not uploaded): fix list r4_AD, calm roof, Lv1's slip the hero. Roof: one white band (course 4), the course 6 band gone. Lv1: dinghy 20% bigger, ~1 up, bow 1 forward past the plinth (no COL there; BOAT_K, BOAT_DZ; console hides the code Console, so no code change), water wedge under it, a calm white hall wall behind (HALL_Y, +-10, COL, walk round it to the trailer), ramp ends there, oars and fuel can gone, table legs grey; back window outside only. Crest: ring on a white-rimmed navy plaque leaning back 16 degrees, foot ~1.3 over the sign; cupola 2.5 up on a dark-red stalk. Sign: gold frame 0.6, white rim. Flanks: 2 pilasters, a life-ring plaque on the mid post (in L07/L08). Left front: framed blue walk-in door 4 x 7, ajar, step, gap in the low wall, COL clear (replaces the inner left window). Lv2: gable rise 2.6 (peak 29.15), blue ridge cap, one white band, plaque +25%, stepped studded lintel, 1 trim row less, RIB +25% (RIB_K), slip 1.2 wider, COL follow. Palette orange lighter. Lv3: boom 1.5x (to x -5.2, z 17.4), mast back 0.85 clear, hanging boat with stepped bow bricks and a cabin; tower 2-stud top band, lookout +10%, flag, a grey seam at the roof. ATT_* and code unchanged. Sheet: `lineup.py r5`. Not seen in Studio.

PERF-BL11 r4 (2026-11-03, not uploaded): fix list r3_AD, bolder not busier. Lv1: lintel 1.4 up (DOOR_Z 9.2), dinghy 1.8 forward (BOAT_Y -15.0, blunter bow stays on the plinth; console and COL follow), name sign 16.56 x 5.0 at z 12.82 (letters +16%, stroke 5), its ring inside, the gable ring a navy crest proud of the roof's front edge (plaque gone), soffit cut at the sign frame; two 4.2 windows a side, ~1 brick clear of the red piers, the lifering panel gone; main roof: studs r 0.85, a stepped 2-tall ridge cap, a second white band near the ridge, a white lip + full-size 2-stud eave tiles. Left dormer now drops with L08 (Lv3 crane's place). Lv2: 1-stud recess beside the sign (bay x 9.5..23.7), water from the lip wall to wall ~4 deep (slip y0 -18.15, deck y0 -14.2, COL follow), yellow lip, awning/door 1 up, RIB 3 forward, 2 white trim rows. Lv3: tower x -23.2..-16.2, y -19.3..-12.66, 4 bold red/white bands of 3 bricks, no checks, quoins or small windows, 2 big windows per seen face, door wider, gallery/cab ~20% wider; crane: brick mast (replaces the jamb, COL) + boom 1.2 thick at z 16.9..18.1 above the eave, strut 2x, red block and hook, blue crate 4 wide. Code (rescueBoathouse): sign size/height, UIStroke 5, Console z -d/2 + 4.21. ATT_* unchanged. Sheet: `lineup.py r4`. Not seen in Studio.

PERF-BL11 r3 (2026-11-03, not uploaded): fix list r2_AD. Lv1: the T hatches give way to a dormer pair (x +-13.5, y -13.5, framed blue windows on the -Y and outward faces, stepped red cap; the right one drops with L07); the mouth is 20% wider (clear x +-7.2, GATE 8.0), a red/white striped drum, a 1-stud red arch, a full-width white apron with a 2-deep yellow/red hazard edge, the dinghy 1 higher (console and COL follow; the code Console stays hidden); sign 25% larger and red with white stroked letters, its ring inside the sign, the gable ring proud of the roof edge; rear corner piers, 2 pilasters, a 2-brick base, a stepped red + white eave; a red + white course under the side eaves. Lv2: gable peak 26.15 and 1 forward on red corbels, blue/white header drum, roller door half up, blue apron, hazard curb, roof studs and white eave tile matching the main roof. Lv3: tower narrower (x -23..-17.4), grey stepped plinth, 2-stepped shaft with running-bond seams and quoins, door, a framed window per storey, corbel collar, railed gallery, a lantern about 20% narrower with mullions, 2-step studded roof; a yellow lift crane arm 8 tall over the bay; a low wall with the rail 1 brick lower and a thin jamb ~2 clear of the tower. Culled: stud sides n 8 -> 6, hidden stud/plinth/shell faces, inner back-wall seams. Code (rescueBoathouse): sign size and height, BRICK_RED, UIStroke. ATT_* unchanged. Sheet: `lineup.py r3`. Not seen in Studio.

PERF-BL11 r2 (2026-11-03, not uploaded): fix list r1_AD. Roof: white eave course + studded eave tile, a white course mid-slope, 3-wide white ridge cap 1 proud, red/dark-red edges unbroken,
gable tucked 0.12 under the treads (no white at seams), a mid-ridge cupola (Lv1's own peak), roof vents. Lv1: boat 5 forward (bow at the gate, console and collision follow, tapered bow COL), bright
white slip ramp + big yellow rails from the plinth lip, thick white door frame with stepped arch bricks, grey stepped pier footings, side walls with a window between red piers (in L07/L08), big
life ring over the sign icon + red header strip. Lv2: bay ridge 4 over the main ridge (top z 24.65), gable 1.6 proud, opening raised to z 11.2, orange/white/blue trim, plaque on blue; RIB and slip 4.5
forward, water blue on both slips. Lv3: tower moved to the front-left corner on a stepped base with red buttresses (tree no longer touches; top z 32.1), lantern 1.35x, half-height wall + yellow rail
beside it. Code (rescueBoathouse): Console 5 forward, sign text on two lines, NoTree when the Lv1 mesh loads. ATT_* unchanged. Sheet: `lineup.py r2`. Not seen in Studio.

PERF-BL11 r1 (2026-11-03, not uploaded): Lv1 boathouse becomes a mesh (code Parts stay as the fallback; the code keeps the plinth, a larger name
sign 11.5 x 3.45, the lamp and the Console hidden in the mesh console). Lv1: thick stepped red roof (8 courses a side, ridge 19.55, dark-red eave and
edge tiles, studs on every tread, ridge cap), white brick gable with a framed red/white life-ring plaque, red brick boat-bay portal with a rolled-up
striped door and step, yellow sign rim, two framed flanks (inset windows with sills, big lifebuoy board), back wall with a big window, white ceiling, calm
grey tile floor with a tan path and grey slip rails, dinghy on brick stands, table, trailer, oars, chair. Lv2: the right flank and low wall drop (`Lv1_L07_*`);
an orange side bay opens with its own stepped gable (peak 22.15, above the main ridge) and a RIB plaque, a walk-over curb so the RIB shows. Lv3: the
left flank, low wall and chair drop (`Lv1_L08_*`, `Lv1_L09_*`); an orange bay opens on the lifeboat; the hidden stern shed is replaced by a red/white
watch tower through the roof (top z 33.9, glazed cabin, orange stepped cap, light bar); the davit moved aft to y 7.6 (wheelhouse clear from the path; ATT_Work_Davit
(-13.6, 9.4), AssetIds updated); side step moved to y 0.4..4.8, clear of the table. LOD0 31,394 / LOD1 15,694 / LOD2 7,839; validate PASS (683, 0 failed,
143 waived); [zfight] 0 visible pairs. Budget hero_building, LOD shares patched (large_prop 50/25%), like the Boat Yard. Sheet: `lineup.py r1`. Not seen in Studio.

Validate PASS (362 checks, 0 failed, 72 waived: gameplay node/layer naming, flat-palette LOD UV layout). LOD0 7,276
tris / 9 visual meshes (budget 8,000): Lv2 3,060, Lv3 4,216; LOD1 3,638, LOD2 1,816; COL 27 boxes x 12 tris
(Lv2 10, Lv3 17), all in the LOD0 FBX. Set: 1 (T_RescueBoathouse_Brick, 16-cell flat palette, 1024; round 2 swapped
the unused green / cyan / pink cells for medium stone grey, dark red and dark tan). Size 46.00 x 28.02 x 11.48 studs
(y -13.10..14.92, z 0.92..12.40). Origin the code boathouse's ground centre, add-ons sit on its plinth top at z 0.92, built at the
boathouse's final 1.15 scale (place with no extra scale). Front -Y.

Lv1 boathouse is still `rescueBoathouse()` in `src/shared/DockPieces.luau`. Lv2: RIB pontoon in the right half of
the pen (wet slip x 12.4..17.9, y -12.4..3.8, deck to x 23), RIB at (15.15, -4.3), mannequin-high fuel pump on the
back deck, big life-jacket rack against the right fence. Lv3: lifeboat berth in the left half (wet slip x -21.0..-14.8,
y -12.6..11.0, walkway to x -10.9, back deck to y 12.6), lifeboat at (-17.9, -0.6), bow at y -10.6 with 2 studs of
water ahead, a solid red shed roof over the stern (y 7.6..14.8), crew bench on the walkway's east edge, yellow davit
on the walkway's water edge at (-14.0, -4.6), arm reaching west over the foredeck.

Round 3 (art director round 2: Lv2 8.5 passed and is unchanged, Lv3 8.0):
1. Davit moved off the near (west) corner to the far (east) quay edge, standing on the walkway at (-14.0, -4.6) with
   the arm, head block and hook mirrored to reach west over the foredeck; from the front 3Q it stands behind the bow and
   the lifeboat's whole side shows. Walk line moved to x -12.95 to clear its base; bollards (y -11.2, 1.0, 10.5) and
   cleats (y -8.8, 5.6) re-spaced along the longer walkway.
2. Lifeboat 28% longer: 20.0 long x 4.9 beam (RIB 11.6 x 4.3). lifeboat() draws the 15.6 boat and stretches it along Y
   (LB_K 1.28), then adds the studs round. Berth slip 16.6 -> 23.6 long, extended aft only (the code lifebuoy rack sits
   just in front of the front rim); the bow stops 2 studs short of the front rim.
3. Roof is solid red: red courses, red gable fills, red ridge cap with 8 red studs, dark-red eave ties (no white or
   stone stripes). It moved aft to y 7.6..14.8 over the stern cockpit, 5.4 studs behind the mast and clear of the
   wheelhouse (ends y 6.8); roof posts follow it (y 8.5, 13.9).

Round 2 (art director round 1: Lv2 7.5, Lv3 6.5):
1. Lifeboat is now clearly the upgrade: 15.6 long x 4.9 beam (RIB 11.6 x 4.3), freeboard 3.1, thin white gunwale cap
   instead of the heavy navy rim, a two-tier navy wheelhouse (lower tier to z 5.5, upper to 7.2) with glass window
   strips on all sides, white mullions and a door, an orange top with studs (z 7.5), a mast to z 12.4 with a spar, a
   blue-ended light bar and an aerial, a stern cockpit with orange hatch, yellow rail and red life ring. RIB top is 5.8.
2. Lv3 roof moved back and cut to a 12.3 x 7.2 shed (y 1.4..8.6): bow, deck, wheelhouse and mast show from above.
   The roof is six stepped Lego slope courses per side (red / dark red), stone-grey stepped gable ends with the life-ring
   sign, a stone ridge cap with studs, white eave trim only. Roof ridge z 9.6, eave 7.2.
3. Less white: rims, steps, posts, gables and ridge cap are stone grey; pontoon and walkway decks are tan planks with
   dark-tan seams and staggered butt joints; white is trim, mullions and life rings only.
4. Props bigger: fuel pump 5.6 tall (was 1.9) with a yellow base block, red body, grey canopy, yellow price sign,
   display, side holster and a thick hose to the RIB, reel on the back; jacket rack 1.5x (jackets 1.65 x 2.3, locker
   9.3 long, frame to z 6.4); davit post 1.1 square, arm 0.95 x 0.95, head block, hook block and J-hook (was 0.46 arm);
   crew bench 6.0 long x 1.45 deep with a high slat back, on the walkway's east edge at y -12.4..-6.4 (the side step moved
   to y -4.6..-0.2).
5. Lv2 pontoon is a work area: three yellow bollards, two big yellow cleats at the mooring lines, a yellow dashed walk
   line (x 20.3), the tan planks, a yellow safety edge. Lv3 walkway has the same kit.

Nodes (layers bottom to top): `Lv2` (`L01_Pontoon`, `L02_FuelPump`, `L03_JacketRack`, `L04_RIB`, `L05_Mooring`),
`Lv3` (`L01_Berth`, `L02_Frame`, `L03_Lifeboat`, `L04_Fittings`). Collision: one simple box per object,
`Lv2_Col01_COL`..`Lv2_Col10_COL` (deck, two steps, wet slip, three rims, RIB, fuel pump, jacket rack) and
`Lv3_Col01_COL`..`Lv3_Col17_COL` (walkway, back deck, wet slip, three rims, side step, lifeboat hull, wheelhouse,
bench seat, bench back, davit post, roof overhead, four posts). Roblox hulls each mesh, so a merged `_COL` would fill
the slips; split boxes keep both wet slips, the walkway and the back deck walkable. Attachments: ATT_Work_Pontoon
(20.30, -4.20, 1.62), ATT_Work_Fuel (20.55, 2.65, 1.62), ATT_Work_Berth (-13.00, 2.40, 1.62), ATT_Work_Davit
(-13.60, -2.80, 1.62; at the davit's winch side, moved with the davit).

Renders: `build/prod/M_Bld_RescueBoathouseAddons/review/M_Bld_RescueBoathouseAddons/2026-10-27_sheet.png` plus turntable and
five close-ups (rib, jackets, pump, lifeboat, davit); `levels/levels_sheet.png` (copy: `sheet_levels.png` here; Lv2 and
Lv2+Lv3, front 3Q / side / top).

Open: not playtested in Studio or wired into the game; add-ons are not in `src`, docs/12 or
`art/reference/M_Bld_RescueBoathouseAddons/dims.md`; placement assumes the code boathouse at final 1.15 scale with
no extra ScaleTo. The lot's front gate opening is 11.5 studs (posts at +-5.75); the add-ons fill the outer thirds
and leave the middle x -10.3..11.9 open, so the route in through the gate stays clear. The Lv3 shed roof reaches y 14.9
(code back posts start at y 16.0, back fence 18.7) and the berth's front rim y -13.1 sits just behind the code
lifebuoy rack (about y -14.5..-13.3, x -21.5..-16.5); check both in Studio. The davit base leaves a 2.3-stud lane on
the walkway. The mast top (12.4) still rises above the roof ridge (9.6) in the low front 3Q, in front of it. Pillar
colour is the stone-grey palette cell, so a Studio material remap may tint it. LOD1/LOD2 are 50%/25% of LOD0. Palette,
studs and all small parts are visual; collision stays flat boxes. Awaiting the art-director round.
