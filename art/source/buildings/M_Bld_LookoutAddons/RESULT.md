# M_Bld_LookoutAddons result (docs/25 B + J, 2026-10-27)

Round 4 (art director round 3: Lv2 8.5 PASSED, unchanged; Lv3 8.0: only the radar is reworked). Validate PASS (288
checks, 0 failed, 57 waived: gameplay node/layer naming, flat-palette LOD UV layout). LOD0 6,172 visual tris / 8 meshes
(budget 8,000): Lv2 4,690 (gallery 1,328, railing 1,732, lantern 1,062, deck 568), Lv3 1,482 (searchlight base 208,
yoke 124, radar 772, searchlight 378); LOD1 3,084, LOD2 1,538; COL 17 boxes x 12 tris. Set: 1 (`T_LookoutAddons_Brick`, 16-cell flat palette, 1024; cell 13 is now
pale warm glass 255,238,168). Origin the code tower's ground centre; add-ons at the tower's final 1.5 scale (place with
no extra scale, at the `LookoutTower` spot `isle(62, -95, 0)`); bbox 23.0 x 20.8 x 25.5 studs (x -12.04..10.95,
y -12.13..8.67, z 29.82..55.30; the telescope hood looks over the front rail, the radar dish over the front-left corner).

## What the levels add (the code `lookout()` stays Lv1)

- Lv2 (config piece `Lamp`, effect `GoldCalls15`): a viewing gallery around the platform's front and sides (deck top
  31.32, outer edge 10.8, 2.55 wide, open at the back for the code truss ladder), a red/white rail with corner posts, a
  lantern room on the gable ridge's front half (a grey square saddle block bedded in the roof with a flush 12-stud
  grey plate on top, a straight-sided white drum r 4 with a red band, white corner posts, low sills and thin glazing
  bars with open panes round a round pale-warm lens with a brass ring that shows through every pane, a white cornice
  as the one trim band, a solid red cap, the gold finial), a big brass telescope (white bands, dark lens, brass hood and eyepiece, brown
  tripod) on the front-left gallery corner and a big brass bell under a red gallows on the front-right corner.
- Lv3 (config piece `Spotlight`, effect `GoldCalls2`): a searchlight on the back-right roof slope (white block bedded
  into the slope, flush flat grey stud baseplate, round red turntable, red U-fork yoke with round arm tops, long white
  barrel (4.5 studs) with a red front rim and a domed pale warm glass lens, tilted up 12 degrees) and a radar on the
  front-left roof corner, clear of the lantern in the front 3/4 view (white block with a red band bedded in the eave, a
  flush grey stud baseplate and red turntable like the searchlight's, a thick red mast with a white collar, a brass tilt
  hub, a 5.6-stud dish: deep white bowl, thick red rim, grey back cone, a dark feed-horn stick with a brass horn; the
  dish faces out over the front-left corner, tilted up 35 degrees, so the 3/4 front view sees it in profile).
- Colours follow the code tower (red / white / dark grey / glass) with brass and warm accents. The roof heights follow
  the code gable (ridge along Z, z 43.8 - |x| * 2/3).

## Nodes (one palette mesh per layer, bottom to top)

- `Lv2`: `Lv2_L01_Gallery`, `Lv2_L02_Railing`, `Lv2_L03_Lantern`, `Lv2_L04_Deck`
- `Lv3`: `Lv3_L01_SearchlightBase`, `Lv3_L02_Yoke`, `Lv3_L03_Radar`, `Lv3_L04_Searchlight`

## Collision (separate convex boxes, never one box)

- Lv2: `Lv2_Col01`..`03` gallery deck (left / front / right strips, top 31.32, walkable), `Col04` front rail,
  `Col05` left rail, `Col06` left back return, `Col07` right rail, `Col08` right back return, `Col09` telescope,
  `Col10` bell, `Col11` lantern saddle + plate, `Col12` lantern drum + room. The cabin and its doorway stay the code tower's; the back
  opening to the ladder is clear.
- Lv3: `Lv3_Col01` searchlight block + plate, `Col02` turntable/yoke/drum, `Col03` radar block + plate + turntable, `Col04` radar dish,
  `Col05` radar mast.
- All boxes are 12 tris; the gallery deck is three walkable slabs, not a solid block.

## Attachments (deck top / drum centre, from the report)

- `ATT_Watch_Lamp` (-5.6, -9.2, 31.32), `ATT_Watch_Spotlight` (5.6, -9.2, 31.32): front deck, standing spots just
  inboard of the telescope (front-left) and the bell (front-right), where the watch effects play.
- `ATT_SearchlightPivot` (6.6, 5.2, 44.0): drum centre, pivot for turning the searchlight.

## Renders

- Standard sheet: `build/prod/M_Bld_LookoutAddons/review/M_Bld_LookoutAddons/2026-10-27_sheet.png` (turntable and
  close-ups alongside).
- Levels: `build/prod/M_Bld_LookoutAddons/review/M_Bld_LookoutAddons/levels/levels_sheet.png` (row Lv2, row Lv2+Lv3
  with 3/4 front, side, top, then deck / lantern / searchlight details) with the grey code-tower proxy; copy
  `art/source/buildings/M_Bld_LookoutAddons/sheet_levels.png`.

## Files

`build.py`, `palette.py`, `lego.py`, `maketex.py`, `views.py`, `views_sheet.py`, `M_Bld_LookoutAddons.blend`; outputs
under `build/prod/M_Bld_LookoutAddons/` (FBX LOD0/1/2, textures, review, report).

## Open

- Not playtested in Studio or wired into the game (the tower and its cabin are code-built); the add-ons are layered
  empties for the construction rise, not merged into `lookout()`.
- The lantern room, searchlight and radar are solid rooftop mechanisms (a few plain boxes each).
- The lantern panes are open bays (one opaque palette material, no glass). The lens glows only in the levels-sheet
  renders (views.py adds a render-only emissive slot on palette cell 13); in game and in the turntable it is a flat
  pale warm colour.
- In the standard turntable (no tower proxy) the grey saddle block shows as a plain grey block under the drum; on the
  tower it sits flush in the gable.
- Awaiting the art-director score for the radar fix (round 4).
