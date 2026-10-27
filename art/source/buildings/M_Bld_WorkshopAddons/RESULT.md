# M_Bld_WorkshopAddons result (docs/25 B + J, 2026-10-27, art-director round 3)

Validate PASS (237 checks, 0 failed, 47 waived: gameplay node/layer naming, flat-palette LOD UV layout). LOD0 3,648
tris / 9 meshes (budget 8,000): Lv2 2,296 (benches 1,060, saw 708, rack 396, posts 72, roof 60), Lv3 1,352 (cradle 60,
ribs 216, planks 516, hoist 560); LOD1 1,824, LOD2 906; COL 120 + 156. Set: 1 (T_WorkshopAddons_Brick, 16-cell flat
palette, 1024). Origin the code yard's ground centre, add-ons sit on its plinth top at z 0.96, built at the yard's final
1.2 scale (place with no extra scale).

Round 3 (AD r2: Lv2 8, Lv3 7.5, bar 8.5):
- Hull: ribs are one raked frame per side that stops flush under the gunwale (no stepped teeth); the gunwale and top
  strake sweep up 2 plates (0.8) over the bow taper, stem post raised with it; the bottom red strake now runs the
  whole length, so the stern half is one clean partial strake under bare ribs; the stepped white transom is one flat
  orange-tan trapezoid board with the red cap.
- Hoist: the red trolley block sits over the stern half (x -2.6); rope, hook and two black slings carry the next white
  strake (x -5.0..-0.2, z 6.75..7.75), lowered over the open stern half.
- Saw: blade radius 1.15 -> 1.70, light silver face (palette cell 1 now 198,202,208) in a dark rim, centre at table
  level so the top half stands clear; housing, riving knife and guard resized; shelf boards moved clear.
- Lean-to: middle post row removed (front and back rows only), so the west side and entrance are open; lumber rack
  moved onto that open side (x 7.25..9.85, y 9.4..12.6), planks run front to back with red / white / orange-tan / tan
  / blue / yellow ends facing the yard; its top tier now fits under the cap.

Round 2 (AD r1: Lv2 7, Lv3 6, bar 8.5):
- Hull: pointed bow (half-beam tapers 2.4 -> 0.4 over the last 3.4 studs), stem post 1 stud over the gunwale, flat
  stepped transom, keel spine, stepped-U ribs; bow half planked in three strakes (red / white / red), stern half bare
  orange-tan ribs; hoist stays dark brown.
- Saw: upright light-grey blade 2.3 studs across, top third above the table, red guard on a riving knife, one orange-tan
  plank being ripped along a yellow fence; the extra red blocks are gone; studs on both table slabs.
- Lean-to roof and posts reach 3.5 studs in front of the bench (sawyer stands under cover); lumber moved to its own open
  four-tier rack west of the lean-to (x 7.25..9.85, y 12.55..13.55).
- Pegboards: tan boards in a dark frame, two posts down to the bench, hammer / wrench / saw hung over red / green / blue
  outlines.
- Palette: yellow 255,188,0 (was butter), red 235,30,30, cell 13 now orange-tan; studded yellow hoist ridge, red pulley.

Nodes (layers bottom to top): `Lv2` (`L01_Workbenches`, `L02_SawBench`, `L03_LumberRack`, `L04_LeanToPosts`,
`L05_Roof`), `Lv3` (`L01_Cradle`, `L02_Ribs`, `L03_Planks`, `L04_Hoist`). Collision `Lv2_COL`, `Lv3_COL`: separate
convex boxes (benches, saw + blade guard, rack, posts, roof overhead, hull in four bites rising with the sheer, hoist
legs in two segments); walkways and the space under the A-frames stay open. Attachments (plinth top): ATT_Work_Bench2 (-15.25, 3.6), ATT_Work_Bench3
(-15.25, 9.9), ATT_Work_SawBench (14.2, 7.85, moved with the bench front), ATT_Work_BoatFrame (0, 7.0).

Renders: 2026-10-27_sheet.png plus turntable, close-ups and levels/levels_sheet.png (copy: sheet_levels.png here).
Open: not playtested in Studio or wired into the game (the yard and its props are code-built); the lean-to
roof extends to y 13.55, matching the old roof, which already overhangs the yard's back fence by about 0.5 stud; the
rack leaves about 0.65 stud between it and the Lv3 hoist's east legs (no walkway intended there). The hanging strake
has no collision (5.8 studs over the floor, above the hull). Awaiting the round-3 art-director score.
