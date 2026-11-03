# M_Bld_BoatYardAddons result

Shipped r5 (AD median 8.6; r2 8.43, r3 8.77, r4 8.8, stop rule; all 3 judges rated r5 above r4 pairwise). Ids: LOD0 102629971947480, LOD1 130896691043221, LOD2 108045817507863; ALB 127251361759849. Not seen in Studio. Next round per build/status/2026-11-01/perfect/buildings/BoatYard/r5_AD.md: calm one-tone floor, wider shed clear of the crane, chunkier Lv2 crane.

PERF-BL9 r5 (2026-11-03, not uploaded; AD r4 median 8.8): Lv1 boat: full-width cradle beams gone, 4 grey brick stands (3 courses, dark seams)
with yellow caps, saddles and hull-side wedges, the underside open between them (cradle collision follows: walkable gap); slim light keel;
bow lofted over 3 plan stations (blunt front facet, foot z 6.6: no shaded underside from the path); yellow band z 8.25-9.0; small black anchor
on the starboard front facet on a short chain. Gantry legs 13 brick courses, girder 6 bricks, dark seams. Slip: dark grey rails 1 wide, 0.3 proud,
y -13.2 on, on low black sleepers every 2 studs. Floor: palette LBG warmed to (198,192,180), running-bond tiles on a dark bed, colour tile
patches. Pad: red/blue 2-stud border, crates 4 x 3.9, a 4.4-tall timber stack, 2 yellow bollards. Office plaque: white boat icon on navy.
Lv2: bench x -5.6, y -14.4, S 1.25, plinth 0.7 (front y -17.8: door lane 2.95 wide), white pegboard, 5-stripe red/white awning 2 studs deep; crane tower
x 12.5, red brick courses between white collars. Lv3: shed roof x 12.0..19.7 (a crane-width of sky to the tower), left post x 12.6 on a quay strip
to x 13.2, dark inner wall, hull x 15.4; water deep blue + cyan shallows, 3 raised pale wave plates, white stud ripples, denser quay studs, plaque 0.84x.
Collision bug: the right front wall's box is now `Lv1_L07_Col01_COL` (dropped with the wall at Lv3 by the existing DockPieces match); the water gate box
covers the wall line alone. ATT_Work_Hull (9, 18, 0.92), ATT_Work_Bench (-5.6, -18.5, 0.92). LOD0 34,250 / LOD1 17,117 / LOD2 8,550; validate PASS (593, 0
failed, 124 waived); [zfight] 0 visible. Code: AssetIds attachments. The palette changed: the ALB needs a re-upload with the meshes. Sheet: `lineup.py r5`.

PERF-BL9 r4 (2026-11-03, not uploaded; AD r3 median 8.77): path view decluttered and brightened. Lv1 bow: fuller stem (foot z 7.1),
yellow 1-stud stripe under the white one, white waterline, white anchor on the stem, no dark boot-top/keel strip, light keel;
cradle beams and slip sleepers orange-tan, cable and tyres out of the gate, gate piers 0.9 lower, light winch cheeks. Office: double
door in a white frame: left leaf shut (solid blue, small window, knob, wall behind it), right bay the same open doorway; drum and
shutter gone, red studded step, plaque 1.3x, ink interior quad gone; second window gone. Pad: dark seams, orange/white stud border,
2-high crates at the right; dinghy and timber gone. Front wall: blue accent course. West crates moved behind the office. Lv2 crane: tower
(13.5, 18), half width 1.3, ring z 28.3 (peak 33.95), two-course red/white base, jib flipped outward (tip x 19.35) so nothing crosses
the gantry leg, crate 1.3x high against the sky. Bench: x -7.2, y -15.2, S 0.96, 3 big tools 1.5x (red hammer, blue wrench, dark saw),
3-stripe 1-stud awning, tool chest gone (it blocked the office door). Lv3: right front wall moved to Lv1_L07 (gone at Lv3), low
red/white water gate in its place (deck z 2.40), water z 2.30 cyan with white ripple tiles, light coping, hull 1.1x; shed eave 15, ridge 20.45,
roof x 10.5..19.7, left posts on a quay strip (eave right of the crane tower in the path view), white/red stepped gable, 7-stripe awning.
ATT_Work_Hull (10, 18, 0.92), ATT_Work_Bench (-7.2, -18.7, 0.92). LOD0 32,386 / LOD1 16,187 / LOD2 8,085; validate PASS (598, 0 failed,
125 waived); [zfight] 0 visible. Code: AssetIds attachments, DockPieces boatYard() sign 9 x 3.4 at y 25.1. Sheet: `lineup.py r4`.

PERF-BL9 r3 (2026-11-03, not uploaded; AD r2 median 8.43): Lv1 office brick courses (0.05 seams), red base course + band under the
eaves, one door: blue roller shutter rolled up over a dark doorway (the swung leaf went, a second framed window took its
spot), plaque 1.5x. New `Lv1_L09_Pad` (right half, every level): tan plate pad, yellow/black line, upturned blue dinghy on
trestles, timber stack, full stud rows; `Lv1_L07_Paint` adds the line + stud rows (front right, gone at Lv3). Lv1 boat: dark
boot-top + white waterline sweeping up the bow, keel strip, plank seams; spreader 2 studs over the cabin, two chunky chains, mast
lowered under it. Lv2 crane: tower (11, 14.5), half width 1.25, one mast section higher (ring z 20.7), 6x6 base with studded
ballast stacks, jib 2.05 deep, cab + crate 1.5x (crate blue, clear of the yellow leg). Lv2 bench 1.3x in the gate mouth (x -4.7, y
-16.4), plinth, orange canopy, lower board, tall tool chest beside it. Lv3: shed shortened to the dock's back third (roof y
-9.4..-1.7), brick back wall, gable plaque with wrench, bunting gone; dark rim, water plane z 2.2 with ripples, hull 1.2x afloat
in the open (no mast), caisson 2 lower (z 3.4) with bolder stripes, short posts, winch beam gone, two bollards. ATT_Work_Hull
(7.5, 14.5, 0.92), ATT_Work_Bench (-4.7, -20.4, 0.92). LOD0 31,624 / LOD1 15,803 / LOD2 7,896; validate PASS (608, 0 failed, 127
waived); [zfight] 0 visible. Code: AssetIds attachments. Sheet: `lineup.py r3` (close_slip_L1 replaced by close_pad_L1).

PERF-BL9 r2 (2026-11-01, not uploaded; AD r1 median 7.07): the level ladder moved to where the path sees it. Lv2 =
`Lv2_L01_Crane` (red jib crane at the right back, tower (15, 14.5), white collars, truss jib over the slipway with a
hook, slings and a slatted crate, studded counterweights, A-frame peak; top ~22) + `Lv2_L02_Bench` (red bench, tan
pegboard with 4 brick tools, vice, toolbox, facing the path at x -6.55, y -13.6). Lv3 = `Lv3_L01_Dock` (wet dock in the
right front, rim x 9.6..18.6, y -20.55..-2.0: grey stepped walls, coping with studs and a yellow/black edge, red/white
caisson at the path end between studded orange posts with a red winch beam), `L02_Water`, `L03_Shed` (half-open boat
shed, white posts, back wall, stepped studded blue roof + orange ridge, bunting; top ~16.5), `L04_Hull` (the red hull
afloat, short mast + beacon). Old Lv2 portal crane/engine, Lv3 dry dock, pump house and tall mast removed. Lv1: office
1.35x set back with its door on the path face (blue leaf, knob, window, orange surround, step, framed boat plaque,
framed inset windows with white sills, studded roof + ridge cap); gantry hook ends at a spreader with slings to the
hull sides, yellow foot flanges + stud seams on the legs; cradle posts grey with red caps; continuous slip rails on
sleepers + hazard edging; wide tan work strip, stud patches; slatted 2-high crates (moved to the west back), Lego
tyres with hubs, studded pallets, lumber pallet; wall tops 1x2 grey cap plates. `Lv1_L07_Paint` (paint pallet) is
dropped at Lv3. ATT_Work_Hull (12.4, 14.5, 0.92) crane foot, ATT_Work_Bench (-6.55, -16.8, 0.92), ATT_Work_Dock
(8.7, -15.0, 0.92). LOD0 27,734 / LOD1 13,860 / LOD2 6,927; validate PASS (590, 0 failed, 122 waived); [zfight] 0
visible. Code: name sign stays on the gantry beam at every level (DockPieces boatYard), AssetIds attachments.

PERF-BL9 r1 (2026-11-01, not uploaded): Lv1 joins as a mesh (Lv1_L01_Floor tiles + tan path + orange slab trim, L02_Walls
brick courses/stud caps/orange piers, L03_Boat hull with tapered bow, stripe, portholes, rails, console, framed cabin
windows, studded roof, mast; L04_Gantry; L05_Office walk-in yard office with framed door, boat plaque, inset windows,
stepped studded blue roof; L06_Props tool chest, tyres, winch, paint cans, crates; L08_Slip rails + sleepers;
L07_SlipEast dropped at Lv3). Lv3 hull gets a dressed mast (peak 31 studs, above the gantry). Budget hero_building,
LOD0 22,068 / LOD1 11,030 / LOD2 5,513; validate PASS (782, 0 failed, 162 waived); [zfight] 0 visible. Code:
DockPieces boatYard() (lv1 opt-in, keeps plinth, sign, rock, hidden Console). Sheet: lineup.py.

## docs/25 B + J (2026-10-27)

Validate PASS (459 checks, 0 failed, 92 waived: gameplay node/layer naming, flat-palette LOD UV layout). LOD0 7,648
tris / 10 meshes (budget 8,000): Lv2 3,244 (gantry + cab 1,264, hoist + engine stand 1,072, bench 276, tools 632), Lv3
4,404 (walls 2,416, water 12, steps 144, gate 1,080, blocks 132, hull 620); LOD1 3,821, LOD2 1,909; COL 504 (42 boxes of
12). Set: 1 (T_BoatYard_Brick, 16-cell flat palette, 1024). Bbox 38.72 x 33.10 x 17.34 studs (12.91 x 11.03 x 5.78 m). Origin
the code yard's ground centre, ground z 0, plinth top z 0.92, front -Y, built at the yard's final 1.15 scale (place
with no extra scale). The bbox spans the crane, the east bench, the pump house and the west dock walls, not the whole
39.5 x 43.5 lot.

Lv2: a four-post yellow portal crane straddling the dry dock's line in the west third (posts x -19.15 / -9.20, y 2.0 /
9.4; girder z 16.8..18.0 along x): the west legs (0.8 wide) stand on a dark concrete footing over the code yard's white
side wall (x -19.72..-18.70, top z 3.70, covers the wall's 3.68 top in that span), outside the Lv3 dock wall; the east
legs on a footing on the yard beside the east wall (x -9.90..-8.50); studded yellow base plates, side ties at z 9.4 /
13.4, dark end caps, girder studs and two studs per end-beam span (post cap to girder). The cab sits on a dark railed platform (z 9.3, two braces) bolted to the yard side of the east front
post, with a red door onto the platform and a yellow ladder up from the yard on its front edge. A red trolley at the
dock's centre line (x -14.125, y 5.7) lowers a black chain, a hook block and a 2 x 3 stud red engine (three black heads,
silver pulley, exhaust side, sump z 6.90) just above an engine stand (Lv2 landing spot): dark base + yellow plate (x
+-1.5, y 4.10..7.30, the Lv3 fourth hull support), a dark column, a yellow top plate with four studs (top z 6.48) and two
timber chocks (top 6.60). In Lv3 the column hides inside the solid hull and the studs and chocks show in the open hatch;
the engine hangs 0.15 above the coaming (6.75). Bench and tools unchanged. Lv3: as before (dock walls, caisson, stairs, ladder, pump house, water strip),
plus: the hull's deck has an open engine hatch (yellow coaming, dark hole 2.2 x 3.4) right under the hook; the hull is
one red bilge-chine loft with a flat bottom and a raked bow (stem post on the bow) instead of stepped bands; three keel
blocks (y 3.4, 9.0, 12.0, no hidden studs) with the Lv2 engine stand as the fourth support between them; shores at HY +- 1.5
(clear of the west footing); fence panels light grey with a yellow cap rail (were white/red, blurred into the hull
stripe), split around the west footing; bollards moved off the footings.

Nodes (layers bottom to top): `Lv2` (`L01_Gantry`, `L02_Hoist`, `L03_Bench`, `L04_Tools`), `Lv3` (`L01_Walls`,
`L02_Water`, `L03_Steps`, `L04_Gate`, `L05_Blocks`, `L06_Hull`). Collision `<Node>_ColNN_COL`, one convex box per
object (Lv2 footings + plates, posts, girder, cab platform, cab, engine stand base + column, bench, board; Lv3 walls, gate, posts,
beam, 6 treads, hull in four bites, keel blocks + cradle, ladder, fences, pump house): the walkways, the basin and the
space under the crane stay open. The west walkway (the 1.6-stud dock wall coping, x -18.75..-17.15, between the code side wall and
the basin) is clear: the west legs stand outside it, and the west fence panel and its collision stop at the crane span
(y 0.8..10.6), so the lane there is 1.55 studs plus the basin edge (a 2-stud root part passes); the walkway is 1.6 wide
by geometry, no 6-stud lane fits on the west. The east walkway (ATT_Work_Hull / ATT_Work_Dock) stays clear. The hull's collision starts at
z 3.50 and there is no basin-floor collision (falling in puts the player on the plinth).
Attachments: ATT_Work_Hull (-10.5, 6.0, 3.26), ATT_Work_Bench (15.45, 0, 0.92), ATT_Work_Dock (-10.5, 13.4, 3.26):
unchanged, nothing they mark moved.

Round 4 (art director round 3: Lv2 8.0, Lv3 8.5) fixes: palette yellow 255,205,0 -> 255,213,0 (Lego Bright Yellow)
for every yellow piece; engine lowered from z 8.6 to 7.3 over a tall studded engine stand (was a low cradle 5.4 below);
end-beam studs; west legs moved off the dock walkway onto the code side wall line (posts 1.10 -> 0.80 wide, collision
moved with them, west fence collision split at the crane span). Budget: vertical brick seams keep only their front and
side faces (back, top and bottom were hidden in the wall, the horizontal seams and the floor): walls 2,818 -> 2,416. AgX
still softens the yellow a little in the Blender renders; the ALB cell is 255,213,0.

Round 3 (art director round 2: Lv2 7.5, Lv3 8.0) fixes: crane moved over the dock with the hook over the hull's open
hatch (Lv3) / an engine cradle (Lv2); cab on a platform with a ladder and a door; palette yellow 255,188,0 (mustard) ->
255,205,0 (bright Lego yellow) everywhere; grey/yellow railings; bilge-chine hull with a raked bow; studs 10-12 segments
with no hidden bottom caps (pays for the extra segments), fence posts 8, bollards 12. Code-yard clearance: the east
footing (y 1.0..10.4) clears the code gantry leg (x -9.78, y +-0.69); the cab platform (x -8.65..-4.90, y 0.55..3.45,
z 9.0) and its ladder (x -6.0..-5.4, y 0.43) clear the code workboat hull (x +-4.26) and cradle (y >= 4.48). In the
Blender renders AgX still dulls the yellow a little; in Roblox the ALB cell is 255,205,0.

Round 2 (art director round 1: Lv2 6.5, Lv3 7) fixes: Lv2 engine/cab/rail plates; Lv3 solid red hull (no hollow interior,
no shore pickets, no orange wedge stern), dry floor + water strip; walk-in pump house; hazard caisson; brick seams,
yellow coping edge, bollards, fence panels; 3D brick tools. Hull half beam 2.05 -> 1.75 and keel 2.05 -> 2.80 so the
blocks and shores read in the 1.3-stud gap; the hull collision moved up 0.75 with it. ATT_Work_Hull / Bench / Dock
are unchanged (the pump house moved clear of them: hut x -8.2..-2.2, ATT_Work_Dock at -10.5, 13.4 is on the walkway
beside its west wall). Seams are thin boxes only on the basin faces and the yard side of the east wall (wall layer
2,964 tris, the budget's biggest part).

Round 1 review fixes (kept): neutral-HDRI softbox replaced by a matte studio cylinder in the level renders; side
renders at -90; camera margin 1.03.

Renders: 2026-10-27_sheet.png plus turntable, close-ups (gantry, cab, bench, dry dock, hull, pump house) and
levels/levels_sheet.png (copy: sheet_levels.png here).
The sheet's studio row is pending (0/4): that pass is the shared Studio 1.4 item, not part of these renders.
Open: not playtested or wired into the game (constraints for this asset); `boatYard()` (DockPieces.luau:1716) has no
`addonMesh` call yet, so the add-ons are invisible until wired. When wiring: keep the code plinth, workboat + cradle,
fence, slipway and front clutter; the code gantry (x +-9.78, beam z 28: now a second crane beside the Lv2 one over the dock), tool chests (x 13.4..17.5, y -10.8) and tyres
overlap or duplicate the Lv2 kit and should be removed/guarded in the addon branch; hide Lv3 until level 5. The pump house (x -8.2..-2.2, y 12.4..18.4) and its pipe are on the yard's north-west: check the code yard has nothing there when wiring. No
art/reference dims file, so the spec dims are the measured bbox (validator 0.0% off).
