# M_Bld_BoatYardAddons result (docs/25 B + J, 2026-10-27)

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
