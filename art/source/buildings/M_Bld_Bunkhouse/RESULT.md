# M_Bld_Bunkhouse result (round 3, 2026-10-27, docs/25 B + J walk-in, Lego style)

## In-game fixes (2026-10-27, after the M_Bld_RescueHQ Studio playtest; shapes, colours and layout unchanged)
1. **Palette texture** (Roblox ignores FBX material colours, so flat materials rendered pale grey): one set
   `T_Bunkhouse_Brick` ALB / NOR / RGH / MET (1024, 8 x 8 cells of 128 px; `palette.py`, `maketex.py`, as M_Bld_Depot)
   in `build/prod/M_Bld_Bunkhouse/textures/M_Bld_Bunkhouse/`. All 21 round-3 colours (the warm-yellow `Lamp` panes and
   `OwnerColour` too) are cells with their old roughness in RGH; each mesh is one colour, so every face's UVs sit
   inside its colour's cell (LODs keep them through decimation). Materials: `MI_Bunkhouse_Brick`, plus `MI_Lamp` (same
   set) so the night view can light the panes.
2. **Collision split**: one object per convex box, `M_Bld_Bunkhouse_Lv<l>_Col<NN>_COL` (Lv1 25, Lv2 42, Lv3 21,
   Lv4 9, Lv5 7 = 104, all in the LOD0 FBX). Stairs already had boxes (12 solid Lv2 steps, 11 Lv3 treads). A box check
   (`/tmp`, not kept) found every doorway (Lv1 front / west / 2 room, Lv2 front / stair / cross, Lv3 back, Lv4 front),
   the Lv2 landing and the stair walkways clear; only the roof plates' existing overhangs reach 0.6 studs over the east
   stair's inner edge and 0.8 over the back treads' (the visual roofs do the same; 3.0 / 2.8 studs stay clear).
3. Rebuilt: validate PASS (2,745 checks, 0 failed, 128 waived: LOD UV layout only); LOD0 7,774 visual tris (FBX 9,022
   with the 104 _COL boxes), LOD1 3,458, LOD2 1,148. Turntable, sheet and levels sheet re-rendered (no missing-texture
   pixels; night panes lit).
4. **Stair collision** (Studio playtest: the walk stopped at the east stair's ninth step): the Lv1 roof plate and Lv2
   floor boxes stop at x 14.2 (the east stair's inner edge), the Lv2 roof and Lv3 deck boxes at y 10.0 (the back treads'
   inner edge), and the Lv5 stair-side fence box is 0.25 thick (y 9.75 .. 10.0); visuals unchanged. A box check (every
   step / tread box against the boxes up to 6 studs above it) leaves only the landing's own edge fences and a 0.04 lip
   of the Lv1 floor box at the first step. Rebuilt: validate PASS (2,745 checks), only LOD0 changed and was re-uploaded.

**Game code to update (not done here, outside this folder):** `src/shared/DockPieces.luau` `levelMesh` reads the
collision level with `_Lv(%d)_Col_COL$`; the new names need `_Lv(%d)_Col%d+_COL$`, or every _COL counts as Lv1 and the
higher levels' collision shows before they are built. The `OwnerColour` doors now carry the red palette cell; if the
loader puts the SurfaceAppearance on them, DockService's `Flag` colour will not show (skip the set on `Flag` parts).
The asset needs re-uploading (not done).

Round 2 art director: Lv1 8.5 (passed), Lv1-3 8.0, Lv1-5 7.5. Round 3 changes (Lv1 untouched, 2,216 tris as before):
1. Lv2 hall: the red cross-wall bunk is mirrored (`bunk(..., head_hi=True)`), so its 6.2-tall head board stands at the east
   end against the blue bunk's foot instead of facing the balcony door; from the doorway the open bunk frames on both
   sides read and nothing tall stands in the middle.
2. Every railing is now a solid white Lego fence panel (0.5 thick) with a blue 0.9 x 0.4 cap and blue cap studs about every
   3.5 studs (`fence()`): balcony (front + 2 sides), east stair (one sloped panel along the step backs, 3.0 tall), the landing
   (side + back), the back stair (sloped, on the stringer) and the whole Lv5 deck (gate at the stair head). No posts or
   balusters. Flat runs carry collision (new on the balcony and landing); sloped stair panels have none, as before.
3. Lv5 terrace: planters removed (open floor; the two benches stay against the side fences); the light strands are now
   0.4-thick rope-tan (`Cork`) instead of thin black. The unused `Black` material is gone.

Round 2 (kept): Lv4 14 x 9 west annex with its own doorway; 7 light poles, 18 plain bulbs, 4 x 3 flag; 2 shuttered windows
per side on Lv1-3; 2 x 2 stilts under the balcony, landing and back stair; 5 x 3 roof stud grids; open Lv2 stair doorway.
Night: a Night column (Front3Q, dark sky, Lamp panes emitting in the render only) is on the levels sheet. The turntable
sheet's "Studio Night" cell stays pending: it is filled only by Roblox Studio shots (not started, per the brief).

Budget: hidden faces are trimmed (`Group.box(drop=...)`: log course tops / bottoms under the next course or roof, side-wall
ends, pane edges, shutter backs, resting bottoms), so validate PASS (round 3: 2,542 checks; see the fixes above for the current run). Budget class
`large_prop`: LOD0 **7,774 tris** of 8,000 (168 meshes), LOD1 3,458 (of 4,000), LOD2 1,148 (of 2,000).

| Level | LOD0 tris | What it adds |
|---|---|---|
| Lv1 Bunk Hut | 2,216 | 28 x 20, 5 log courses, 6-stud front doorway, lobby (rug, 4 lockers, coat rail with 4 life jackets, ring, shelf), 2 bunk rooms through 5-stud doorways (5 bunks = sleeps 10, dresser, ring, shelf), side doorway west (for Lv4), 2 shuttered windows per side, studded roof plate, awning, bed sign |
| Lv2 Upper Floor | 2,360 | floor plate on the Lv1 roof studs, hall + dorm (5 more bunks, bulletin board, bench, 3 rings, shelf), front balcony on 2x2 stilts (double door, fence panels), outside stair up the east wall (12 steps + landing on 2x2 stilts, open doorway, fence panels), 2 shuttered windows per side, studded roof |
| Lv3 Loft | 1,180 | deck plate over the Lv2 roof (the terrace), 20 x 14 loft with 4 hammocks, 2 shuttered windows per side, back door, back stair (11 cantilevered treads, 2x2 stilts, sloped fence panel) up to the deck, gable roof |
| Lv4 Side Wing | 742 | 14 x 9 annex west of Lv1 (see 1.) |
| Lv5 Roof Terrace | 1,276 | studded fence round the deck, 2 benches, light poles + rope-tan bulb strands, flag (see 2., 3.) |

Nodes: `Lv1`..`Lv5` (empties, .blend only; the FBX importer flattens them). Meshes `M_Bld_Bunkhouse_Lv<l>_L<k>_<Word>_LOD0`,
layers L01..L05 bottom to top per level (Lv5: L02..L05): L01 plinth / floor / rug / stair / balcony deck, L02 lower log
courses + furniture, L03 upper courses + windows + upper bunks + rings / shelves, L04 roof plates, L05 studs / awning / sign / fences (Lv5: fences in L02).
One mesh per colour per layer. Doors: `..._L02_OwnerColour_Door_LOD0` in Lv1 (2 leaves), Lv2 (balcony 2 leaves + stair 2
leaves) and Lv3 (loft); the Lv4 doorway is open (no leaf). Collision: one box per object, `_Lv<l>_Col<NN>_COL`
(wall segment / floor / bunk / step / stilt / flat fence run; doorways and interiors open). Windows: warm-yellow `Lamp`
palette cell (no emission in the asset).

Dims (Lv1..Lv5 together, origin = lot centre at ground, door faces -Y = Roblox -Z): 46.9 x 28.25 x 45.4 studs
(x -28.9..18.0 incl. wing and stair, y -13.8..14.45, z 0..45.4). Lv1 alone: 28 x 20 x 12.7. Floors (studs): Lv1 1.1, Lv2 12.7, Lv3 23.9.
Attachments: ATT_Door_01 (0, -12.6, 0), ATT_Sign_01 (0, -10.4, 9.4), ATT_Bed_01 (-11.5, 4.2, 1.1), ATT_Stair_01 (16, -9.8, 0),
ATT_Balcony_01 (0, -11.8, 12.7), ATT_Hammock_01 (-6.5, 0, 27.4), ATT_Deck_01 (1.6, 11.8, 23.9), ATT_Wing_01 (-21, -4.5, 1.1),
ATT_Flag_01 (-9.5, 0, 45.0).

Sheets: `build/prod/M_Bld_Bunkhouse/review/M_Bld_Bunkhouse/levels/levels_sheet.png` (copy `sheet_levels.png`): Lv1 alone,
Lv1-3, Lv1-5 x 3/4 front, side, top, Interior, roofs-off CutAway and Night. Turntable sheet `.../2026-10-27_sheet.png`
(copy `sheet.png`), 8 views + 6 close-ups (Lv1Door, ThroughDoor, Lv2Balcony, Lv2Stair, Lv4Wing, Lv5Terrace).
Rebuild: maketex.py, then build.py header; views `views.py` + `views_sheet.py`; turntable sheet `python3 tools/blender/sheet.py --asset
M_Bld_Bunkhouse --out-root build/prod/M_Bld_Bunkhouse`.

## Open / waived
- Stair steps are 1.06 / 1.02 studs high (12 and 11 steps): fine for a Humanoid, not yet walked in Studio.
- Lv2's 12 east steps are solid blocks (separate collision boxes).
- LOD1 / LOD2 drop meshes under 24 / 72 tris (studs, ropes, bulbs) and are hand-made decimations (no `lod` step, as the HQ).
- Lv2 roof studs are hidden under the Lv3 deck plate once Lv3 is built (levels never remove pieces).
- The lit-window night look is a render-only emission on `MI_Lamp`; the game has to light the `Lamp` meshes at dusk.
- Sloped stair fence panels have no collision (as the old stair rails); not walked in Studio.
- No art-director score for round 3 yet.
