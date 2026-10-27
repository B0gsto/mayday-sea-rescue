# M_Bld_Depot result (walk-in redesign v2 round 4, 2026-10-27, docs/25 J)

Validate PASS (641 checks, 0 failed, 135 waived: naming for the gameplay node/layer names, LOD UV layout for the
shared flat palette, real size x for the crane jib over the berth). LOD0 7,792 tris / 26 meshes (budget 8,000), LOD1
3,888 (of 4,000), LOD2 1,937 (of 2,000). Set: 1 (T_Depot_Brick, 16-cell flat palette, unchanged).

Nodes (layers bottom to top): `Lv1` (`L01_Foundation`, `L02_Frame`, `L03_Rack`, `L04_Roof`, `L05_Sign`,
`Stack_1..4`), `Lv2` (`L01_Base`, `L02_Frame`, `L03_Rack`, `L04_Roof`, `L05_Sign`, `Stack_1..4`), `Lv3`
(`L01_Base`, `L02_Trestles`, `L03_Belt`, `L04_Hopper`), `FreightQuay` (`L01_Piles`, `L02_Deck`, `L03_Bollards`,
`L04_Derrick`). Collision: `Lv1_COL`, `Lv2_COL`, `Lv3_COL`, `FreightQuay_COL`, separate convex boxes / gable prisms;
doorways and interiors stay open (the Lv3 chute and drop tube are overhead, 6.0+ studs up).

Round 4 (AD v2 r3: Depot 8 (Lv1 8.5, Lv2 8, Lv3 7.5), FreightQuay 7.5):
- Lv3 east side reads as a belt on posts: the lift tower and the hopper leg are yellow, the grey trestle heads are
  gone, and the two trestles became one slimmer yellow trestle (y 6.6), so there are clear gaps between lift, trestle
  and hopper leg in Front3Q.
- Chute mouth lowered: the drop tube now ends in a red flared mouth (3.4 x 3.4 at the bottom) 6.0 studs over the bay
  floor, right over the blue plate. ATT_ConveyorEnd follows it (z 9.0 -> 7.1; name unchanged).
- Quay crane: 3x3 mast (seams, slewing ring and turntable sized up; base studs moved to the corners), a big dark grey
  counterweight (3.2 x 3.6 x 3.0, black seam) that stands above and beside the counter-jib (seen in Front3Q and High),
  cab moved out to clear the wider mast; the hook now carries a bright green 2x2 brick with four studs.

Round 3 (AD v2 r2: Depot 7.5 (Lv3 6.5), FreightQuay 6):
- Lv3 belt reads from above: a grey lift tower at the back corner raises bricks (red / blue on a black lift belt) from
  the feed tray to a yellow head; from there the belt runs the length of the east side and over the eave (top 14.6 to
  16.0, above the 13.4 eave), face up, on two chunky yellow 2x2 trestles plus the hopper's grey leg, with yellow side
  rails and four spaced bright bricks (red, blue, green, orange). Hopper raised (rim 15.5).
- Lv3 clutter gone: the dark chute bar across the bay, its roof hanger and the brick in the chute are removed. A closed
  yellow chute now sits tight behind the lintel (z 12.0 to 12.9, out of sight from the front) and a yellow tube drops
  straight down onto the blue plate (mouth unchanged at ATT_ConveyorEnd). Bay 1's east-wall port moved up to z 11.9 to
  13.1 to match (the only Lv1 change: a hole in the east wall, not visible in the Lv1 views).
- Crane: 4x4 studded base, grey turntable, 2x2 yellow mast with seams, yellow cab with a window, red jib about twice
  as long (13 studs), slewed toward the berth so its tip reaches over the barge's cargo, counterweight, cat-head with
  black tie cables, trolley, black cable, hook block, hook and a slung brown crate.
- Quay deck: yellow / black edge stripe along the sea side and the south end; four black tyre fenders on the sea face,
  flush with x 24.0 (the deck face moved in to 23.4), between the piles; barge gap measured 0.90 studs. Bollards moved
  to (21.6, +-5.0) so every item keeps 2+ studs clear.

Attachments (unchanged positions): ATT_PickUp_Lv1/Lv2, ATT_DropOff_Lv1/Lv2 (plate centres), ATT_DropOff_Lv3 (quay
feed plate), ATT_ConveyorEnd (flared mouth, 6.0 over the bay floor), ATT_BargeMoor (32.8, 0, 0.5; 0.90-stud gap).

Renders: turntable + close-ups in build/prod/M_Bld_Depot/review/M_Bld_Depot/turntable; levels/level_<Lv1|Lv2|Lv3>_
Interior.png and _CutAway.png; 2026-10-27_sheet.png (copy: sheet.png), levels_sheet.png (copy: sheet_levels.png).

Open: spec origin is now `free` (the jib overhang moves the bbox centre; the origin is still the lot centre at ground
level, so placement in game is unchanged). The trestle and hopper feet straddle the quay deck's land-side kerb (Lv3 is
always built with the quay). No ATT_PickUp_Lv3. LOD1/LOD2 near their caps (98%). The quay counterweight is dark grey on
the grey review ground (low contrast in renders only). Not playtested in Studio; awaiting the round 4 art-director
score.
