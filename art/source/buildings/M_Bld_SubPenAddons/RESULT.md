# M_Bld_SubPenAddons result (docs/25 B + J, 2026-10-27, round 3)

Validate PASS (386 checks, 0 failed, 77 waived: gameplay node/layer naming, flat-palette LOD UV layout). LOD0 7,820
tris / 10 meshes (budget 8,000): Lv2 3,508 (gantry 1,244, hoist 330, mini-sub 692, dive rack 1,242), Lv3 4,312 (basin
1,434, pontoon 708, treasure 1,066, crane 468, table 304, flag 332); LOD1 3,906, LOD2 1,948; COL 324 (27 boxes of 12:
Lv2 9, Lv3 18). Set 1 (T_SubPen_Brick, 16-cell flat palette, 1024, dry). Bbox 30.92 x 44.37 x 15.32 studs (10.31 x
14.79 x 5.11 m), x -12.17..18.75, y -7.20..37.17, z 0.00..15.32. Origin the code pen's ground centre, ground z 0, plinth
top z 0.80, front -Y (seaward), 1x. The bbox spans the east rim (gantry, hanging sub, dive rack) and the salvage wet
dock behind the pen (+Y); it is not the whole pen: the Lv1 plinth, deck, pool, gantry and dome are not modelled.

Island fit (`fit_check.py`, game frame: right = 90 - x, fwd = 128 - y; Blender X flips on export): every visual LOD,
COL box and ATT stays on the plate (RingLayout rects: chamfers, cove notch), off every DockPieces street (8 wide; the
cove walk is right 48..56, fwd 18..152) and off every other DockConfig lot. Extents: Lv2 right 71.24..87.70, fwd
109.04..135.22 (inside the 40 x 40 lot, right 70..110, fwd 108..148); Lv3 right 77.83..102.17, fwd 90.83..109.40
(behind the lot; the nearest lot, isle(80, 58, 90) 44 x 36, ends at fwd 80); ATT right 75.40..90.40, fwd
97.40..128.00. PASS. Round 2 put the dock east of the pen at right 52.83..69.17: 3 studs onto the cove walk (no room
to slide it toward the pen: the plinth and the gantry footings), so the whole of Lv3 (meshes, COL, ATT) is turned 90
degrees onto the back by `lv3_xf` ((x, y) -> (-y, x)); its look is unchanged, the steps still climb from the plinth
edge and the flag board now faces east toward the cove walk.

Lv2: a yellow cantilever gantry on the east plinth rim: dark footings (x 15.30..18.50, y +-5.60, top 1.05) with yellow
hazard-striped plates and studs (top 1.75), dark collars, 1.5-wide legs with black brick seams (5 courses) to a
12.80..14.20 beam across y +-6.60 (brick seams, yellow hazard-striped end plates), a jib x 4.70..17.65 (seams, studs,
braces) and an 8-stud lane between the footings (y +-4.0). A red winch housing on the jib tip (x 4.90..6.85, top 15.15)
shows a silver drum with dark flanges poking out of both sides; a thick black cable runs over a sheave on two yellow
hanger plates and straight down (x 3.95, z 14.45..11.30) to a plain red hook block with a dark sheave disc and a dark
shackle (10.00..11.30); two straight flat dark-grey straps run from the block to two lugs fore and aft of the sail (a
clean triangle, no claw). The mini-sub (scale 1.1, 8.5 studs long, no cradle or stand) hangs in free air at x 3.95,
hull z 4.6..7.1 (sail to 8.7, fin and periscope to 9.5), y -4.1..4.4, x 2.3..5.6: yellow hull, red nose dome, three
round portholes a side (light rims, navy glass), red sail with INK windows and a grey top plate, periscope, a swept red
tail fin, stern planes, dark prop. It clears the code gantry legs (x +-10, y +-8) and stays inside the pool (r 6.9 of
8). The rig tops out at 15.32, below the code gantry beams at 16.0. Dive rack: a navy brick wall (x 17.40..18.60, y
8.00..18.80, top 8.20, red studded cap to 8.65) on the east plinth rim just north of the gantry (the gantry's north
footing ends at y 7.2), its west face toward the deck carrying a white board, screen, bench, yellow and red air
cylinders, a dark buoy, fins and masks, plus a tan bench; its east back (the side view) now has 3 courses of brick
seams, a red band (z 3.0..3.6) and a red diver-down flag with a white diagonal (z 4.4..7.2). The rack and its bench
(x 16.10..18.60) sit wholly on the plinth rim east of the deck edge (15).

Lv3 (coordinates in its build frame, east of the pen; `lv3_xf` turns them onto the back, so build x -> +Y, build -y ->
+X): a walled wet dock east of the plinth (x 20.90..37.10, y +-12.10): dark brick walls, light coping 1.45, studded tops,
bollards, water z 1.10, the west side open at y +-1.90 onto three tan steps (18.60..22.80, tops 1.00/1.25/1.50) from
the plinth. A tan walk-on pontoon (22.60..34.40, y +-9.80, deck 1.50) with a blue/white rim holds an open brown coin
crate (23.20..27.80 x -6.80..-2.20, rim 3.70, gold bands) with a stepped gold coin mound climbing to 5.45 over the rims,
coins on the rims and a spilled hoard on the deck; a closed red crate with gold bands and lock (28.80..32.40 x
4.80..8.40, top 4.50) under a gold anchor (to 8.2) with the gold ship's wheel (to 7.25) leaning on it; a sorting table
with a hand wheel and a gold heap (23.60..28.20 x 5.20..8.60, top 3.45); a red salvage crane on a dark footing
(31.40..34.40 x -9.50..-6.50) with a light-grey cab and its jib over the pontoon, a blue crate on the hook; and a navy
flag board on the pontoon's south rim (22.45..28.95 x -9.45..-8.72, field z 6.00..9.20 above the coin pile, cap 9.45)
with the red diver-down flag and white diagonal on the left and a big gold anchor icon (ring, stock, stem, U base,
flukes) on the right, a yellow studded cap. The anchor left the pallet: the whole pontoon east of the coin crate (x
27.80..34.40, y -9.80..4.80) is open, so the ramp-to-crane path is far wider than 4 studs (only the 2-stud strip behind
the board narrows).

Nodes (layers bottom to top): `Lv2` (`L01_Gantry`, `L02_Hoist`, `L03_MiniSub`, `L04_DiveRack`), `Lv3` (`L01_Basin`,
`L02_Pontoon`, `L03_Treasure`, `L04_Crane`, `L05_Table`, `L06_Flag`). Collision `<Node>_ColNN_COL`, one convex box
per object (Lv2: 2 footings, 2 legs, beam, dive wall, bench, sub body, sail tower; Lv3: 5 basin walls, 3 steps,
pontoon, 2 crates, wheel, table, flag board, crane footing/plinth/column/cab), so the pen deck, the steps, the
pontoon lane and the water edges stay open. The cable, straps, hook block and all thin props have no collision (the sub
is out of reach). The anchor on the crate has no collision. The pontoon's collision ends at the deck and there is no
basin-floor collision.
Attachments (final frame): ATT_Work_Gantry (14.60, 0, 1.20), ATT_Work_DiveRack (14.60, 12.80, 1.20), ATT_Work_Salvage
(0, 27.50, 1.50), ATT_Work_Crane (-0.40, 30.60, 1.50), ATT_Sign_Salvage (9.58, 25.70, 7.60).

Round 3 (AD round 2: Lv2 8.0, Lv3 8.5 passed, untouched apart from the move): the dive rack's back gets brick seams, a
red band and a diver-down flag; the mini-sub scales 0.8 -> 1.1 with three portholes a side and a swept red tail fin and
hangs from two straight straps off a plain red hook block (the four black slings and black hook read as a spider
claw); Lv3 turned onto the back of the pen to clear the cove walk (fit above); views and close-ups re-aimed at it.
Round 2 (AD round 1: Lv2 7.0, Lv3 7.5): the hoist now reads (sub hangs free on slings from a red hook block, thick
black cable, no cradle or skids, 6 studs long); gantry gets hazard-striped foot and beam-end plates, black brick seams
and a red winch with a visible drum; dive rack moved next to the gantry (mirrored onto the east rim, red studded cap);
gold palette cell 198,143,38 -> 238,168,0 (read as tan), gold anchor icon on the board, gold crate bands, higher coin
mound over the rims; one red and one blue crate break up the brown; anchor moved to the red crate; board raised above
the pile. Round 1 self-review fixes (kept): the sub's long slim hull with red nose and sail, the flag on the seaward
face with posts behind the board, coin crate rims lowered, water raised to 1.10, the pontoon studs based on the deck.
Tri trims to make room: bottom faces dropped on stacked boxes (lego.box `bottom=False`), 6-sided small studs, seam
quads keep only their visible faces.

Renders: `build/prod/M_Bld_SubPenAddons/review/M_Bld_SubPenAddons/2026-10-27_sheet.png` (turntable 8/8 neutral +
overcast, silhouette; close-ups 6/8 at 1024: gantry, winch, mini-sub, dive rack, salvage, treasure; the renderer caps
at six, crane and flag are covered by the levels sheet); `.../levels/levels_sheet.png` (12 views at 640 in 4 rows:
Lv2, Lv2+Lv3 (3/4 back, side, top), details, details 2; copy `sheet_levels.png` here; the gantry detail includes the
hoist and views the rig from -X). The sheet's studio row is pending (0/4): that pass is the shared Studio 1.4 item. No Lv1 in the renders.
Open: not playtested or wired (constraints for this asset); `subPen()` (DockPieces.luau:1068) has no `addonMesh`
call yet, so the add-ons are invisible until wired. When wiring: keep the code plinth, deck, pool and dome; the code
gantry (legs x +-10 / y +-8, beams z 16..17.4) stays and reads as a second, taller portal above the Lv2 cantilever,
so either hide its beams when the add-on shows or accept the double read; the gantry and the dive-rack wall stand on
the plinth rim (gantry x 15.3..18.5, y +-7.2; rack x 16.1..18.6, y 8.0..18.8, top z 0.80), so that rim must be clear;
the hanging sub (x 2.3..5.6, z 4.6+) is inside the pool radius, so check the dome shell clears it; the salvage dock
stands on the island ground behind the 40 x 40 lot (x +-12.2, y 18.6..37.2, z 0; island right 78..102, fwd 91..109),
so check the ground is flat and free there and hidden until its level unlock. No art/reference dims file, so the spec dims are the measured bbox.
