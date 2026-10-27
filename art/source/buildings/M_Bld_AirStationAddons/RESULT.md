# M_Bld_AirStationAddons result (docs/25 B and J, 2026-10-27, round 2 + island fit)

Lv2 refuel pad + Lv3 patrol hut add-ons for the code-built Air Station, on the ground beside the hangar and helipad.
Validate PASS (336 checks, 0 failed, 67 waived). LOD0 6,800 tris in 10 meshes (budget 8,000): Lv2 3,276, Lv3 3,524;
LOD1 3,397, LOD2 1,695; 17 COL boxes x 12 tris, in the LOD0 FBX. Size 44.00 x 51.00 x 19.60 studs (14.67 x 17.0 x 6.53 m),
built at 1x (the AirStation row has no scale); origin the hangar's ground centre, front -Y. Set: 1
(T_AirStationAddons_Brick, 16-cell flat palette, 1024; red 224/56/40, yellow 255/213/0).

Round 2 (AD round 1: Lv2 8.0, Lv3 7.5): (1) the hut moved by (-6, +9): pad x -51.5..-31.5, y 6..27, walls x -49.5..-33.5,
y 9..24 -> 13 studs from the hangar plinth (x -18.5), 14 from the code helipad slab (y -8), door on open ground; (2) the tower
cab is 4 studs tall with light-blue glass (two panes per side, navy frames) on all four sides over a red skirt, a navy roof
slab and a small yellow railing round it; (3) the bowser parks on a new 20 x 20.4 stud striped apron (yellow / navy hazard
blocks round the edge) east of the pad, x 49..69; (4) the hose reel is 1.5x: red drum, yellow flanges, 3 black hose coils,
yellow crank, on a yellow plate on the apron, black hose run to a yellow coupling on the bowser's west flank; (5) the bench
is a Lego bench: yellow studded seat, four navy legs + side rails, navy back posts, red slat and top rail.

Island fit (2026-10-27, placement only, every piece's look unchanged): each node is authored at its round-2 spot and
moved by `SHIFT` on output: Lv2 (-6, 0), Lv3 (81.5, -27). In Blender studs the Lv2 pad is now x 19..43, y -3..21 (0.5 off
the hangar plinth), apron x 43..63, bowser x 53.6..60.0, reel plate x 44.6..50.6; the hut pad x 36..56, y -30..-9, in
front of the refuel pad (6-stud lane to it, 17.5 to the plinth, nowhere near the helipad), door to the open front.
`fit_check.py` (island right = 88 - x, fwd = -124 - y; all LODs, COL boxes, ATT marks): Lv3 right 32..52, fwd
-115..-94 (pass); ATT right 31.2..59.4, fwd -133..-95.5 (pass); Lv2 right 25..69, fwd -145..-121; no overlap with the
hangar plinth or helipad. Open: the apron's east edge sits at island right 25.0 (the Trophy Hall lot's edge, not in it;
bowser wheels at 27.0), short of right > 27: the 44-stud Lv2 row (pad 24 + apron 20) cannot fit between the plinth
(right 69.5) and right 27 (42.5 studs) without the apron overlapping the pad or the pad overlapping the plinth.
The round-2 coordinates below are before SHIFT.

Layout (Blender studs, fit against DockPieces): code hangar plinth x +-18.5, y +-15.5, helipad slab centre (-38, -27).
Lv2 pad x 25..49, y -3..21 (base 0..0.35, deck 0.60, rim 0.68, H centre 34.6/9.0), apron x 49..69, y -0.5..19.9 (deck 0.60):
bowser x 59.6..66.0, y 3.0..16.4 (tank z 4.7, r 2.5), hose reel plate x 50.6..56.6, y 7.5..12.0, windsock on the pad's
north-east corner (base x 44.2..47.0, y 17.3..20.1, pole 16.2, sock to x 54.1, over the apron's corner). Lv3: authored at the old
spot and moved by HUT_SHIFT (-6, +9) on output: walls 16 x 15, doorway 6 wide (top 7.4) with a studded threshold; roof
ridge 12.4; tower saddle red, cab z 12.8..16.8, glass 13.9..16.2, navy slab to 17.3, railing to 18.15, yellow beacon to 19.6;
outside a bench left of the door, inside navy lockers, the flight board and the plotting table under it. The refuel pad is
45 studs from the main pad, so no lane there.

Nodes: Lv2 (L01_RefuelPad, L02_Bowser, L03_FuelReel, L04_Windsock), Lv3 (L01_Base, L02_Walls, L03_Roof, L04_Tower,
L05_Crew, L06_Bench). Attachments (after SHIFT): ATT_Work_RefuelPad (28.6, 9.0, 0.68), ATT_Park_Bowser (56.8, 8.0, 0.60),
ATT_Work_FuelReel (47.6, 5.5, 0.60), ATT_Work_PatrolHut (46.0, -28.5, 0.60), ATT_Work_FlightBoard (46.0, -14.0, 0.70).
Piece map: Lv2 RefuelPad / Refuel, Lv3 PatrolHut / Patrol.

Renders: `build/prod/M_Bld_AirStationAddons/review/M_Bld_AirStationAddons/2026-10-27_sheet.png`, turntable (9 views +
6 close-ups: refuel_pad, bowser, fuel_reel, hut, hut_door, tower), and `levels/levels_sheet.png` (copy: `sheet_levels.png` here):
grey code hangar + helipad proxy, Lv2 / Lv2+Lv3 front, rear, top + three close reads.

Open: not playtested or wired into `src`, docs/12 or `art/reference/M_Bld_AirStationAddons/dims.md`. No reference photo
exists for this asset; Studio preset shots are pending (12.1.4 item 7). The windsock sits on the refuel pad's corner, not
on the code helipad's windsock spot. Waivers: gameplay node/layer names (docs/25 B) and the flat-palette LOD UV layout
(one shared material, decimation merges cells; `tiling=True`).
