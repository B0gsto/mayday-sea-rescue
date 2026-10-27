# M_Bld_RescueHQ result (round 4, 2026-10-27, docs/25 J walk-in)

Validate PASS (1713 checks, 0 failed, 62 waived: texture sets and LOD UV layout for the Lego flat colours). LOD0
10,108 tris (Lv1 4,948 incl. interior, unchanged / Lv2 additions 5,160), LOD1 4,264, LOD2 2,148 (exported, incl. COL).
Wall triangles (skin + cream core + red base course): Lv1 1,944, Lv2 1,908 (budgets 5k / 9k / 2k). Hand-made LODs
(floors 40 / 24 tris); steps run: build, validate, export, turntable (no `lod` step).
Bbox 34.3 x 23.8 x 31.4 studs (Lv1 + Lv2, origin = lot centre at ground level, `origin: free`), door faces -Y
(Roblox -Z). Flat colours, one per mesh.

## Round 4 changes (art director round 3: Lv1 8.5 ships, Lv2 8): Lv2 only, Lv1 untouched
1. Top-down read: the deck is red tiles (`Lv2_L05_Deck` now Red, red studs) with 4 darker course lines
   (`Lv2_L05_Lines`, RoofLine) inside a white studded 2-stud rim (`Lv2_L05_Edge` now White). The lifebuoy emblem sits
   on a white 4x4 pad in the back strip (navy centre, ring OD 3.6: it had to shrink to fit beside the bigger watch room).
2. Watch room 16 x 10.2 (was 12.4 x 8: +29% / +28%), same height; a mid post on every glass side. Its gable has
   Lv1's slope (3 / 9.6), a 1-stud overhang past the white eave plate, 6 ridge studs (as Lv1) and 3 course lines.
3. Medic wing: white 3x3 plaque with a red cross on the street (-Y) face (the window moved west to 13.0..16.2 to make
   room); a red runner from the east doorway to the counter. The link is Lv1's east doorway (5.4 clear between the
   jambs, floor to the wing ceiling at 7.6, i.e. full height); the counter's red-cross front faces it on the same axis.
   Wing collision already left it open (checked: no Lv2 box between x 10.8 and 12 below the band).
4. Mast pole 0.42 across the flats (radius 0.24, 6 sides; was 0.35), pennants 1.5x (2.1 along the halyard, 1.95 out,
   0.12 thick). Lv2 collision: the watch room is now a pedestal/room box plus an overhanging roof box.

## Round 3 changes (art director round 2: Lv1 7.5, Lv2 7; Lv2 items 1, 6 superseded by round 4)
1. Red roof through every level: the watch room wears the Lv1 gable scaled down (same `gable()` helper: red slopes,
   white studded ridge, course lines) on a white eave plate; the main deck is edged with red studded plates.
2. Mast: 0.4-stud white pole, one yardarm near the top, halyard to a deck cleat with red / yellow / blue / white
   pennants, flat navy radar bar on top. The striped drum is gone.
3. Signs: Lv1 a white-framed navy plaque over the door (proud of the wall on a bracket) with a 3-stud red/white
   lifebuoy; Lv2 the same plaque (2.7-stud lifebuoy) on the watch-room pedestal front.
4. Interior, walls only: 4x3 sea chart board above the chart table, round clock, west-wall hook rail with 2 yellow
   life jackets (replaces the notice board), lifebuoy. Wing: white medic counter with a red cross, grey top, first-aid
   box hung on the wall above its end (beside the east window).
5. Lv2 upper storey: the red band is now 1 brick high; the storey sits on the band footprint (25.4 x 19.4, 3 solid
   courses hide the hut roof) with one wrap-round window band (3 courses, navy mullions every ~3.5 studs).
6. Deck emblem: a complete red torus lifebuoy with 4 white bands on a round navy disc. Lv1 roof: 6 studs on a flat
   2-stud white ridge, 4 darker course lines per slope.

## Levels (Lv2 = only the pieces added on top of Lv1)
Layers: Lv1 L01 plinth, floor, runner, base course / L02 walls, core, frames, glass, owner door / L03 upper walls,
interior / L04 roof, ridge, lines / L05 pole, flag, bell, lifebuoy, sign. Lv2 L01 wing plinth+floor / L02 wing,
medic counter / L03 band, storey floor / L04 storey / L05 deck, edge, emblem / L06 watch room, roof, sign / L07 mast.
Two `OwnerColour` door meshes (one per level, only Lv1 has leaves). `Lv1` / `Lv2` empties in the .blend only.
Attachments (moved onto the new plaques): ATT_Sign_01 (0, -10.12, 9.45), ATT_Sign_02 (0, -9.25, 20.1).

## Walk-in
Front doorway 6 wide (5.2 clear, 6.6 high), east side doorway 6 wide, tan floor, red runner, nothing on the floor.
`_Lv1_Col_COL` / `_Lv2_Col_COL`: per-level separate boxes, doorways and interiors open (Lv2 boxes follow the
storey, deck, round-4 watch room + overhanging roof and thin mast; the wing link stays open).

## Renders
`build/prod/M_Bld_RescueHQ/review/M_Bld_RescueHQ/2026-10-27_sheet.png` (copy `sheet.png`): 8 turntable views, 6
close-ups incl. `ThroughDoor`. Levels sheet `levels/levels_sheet.png` (copy `sheet_levels.png`), now with a 6th
column `Wing` for Lv2: roofs off, from the main room through the east doorway, runner, counter with the red cross.

## Open
- Bricks are 1x6 (1x4 would break the 2k wall budget). The Lv2 storey and watch room are closed volumes (no stairs).
- The life jackets sit near the front of the west wall: seen in the CutAway, not in the through-door view.
- Studio import pass pending; no art-director round 4 score yet.
