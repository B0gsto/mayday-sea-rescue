# M_Bld_FishMarketAddons result (docs/25 B + J, 2026-10-27, art-director round 3)

Validate PASS (388 checks, 0 failed, 78 waived: gameplay node/layer naming, flat-palette LOD UV layout). LOD0 5,816
tris / 11 visual meshes (budget 8,000): Lv2 3,384, Lv3 2,432; LOD1 2,908, LOD2 1,452; COL 23 boxes x 12 tris (Lv2 12,
Lv3 11), all in the LOD0 FBX. Set: 1
(T_FishMarket_Brick, 16-cell flat palette, 1024; palette unchanged). Size 36.60 x 18.20 x 12.98 studs = 12.20 x 6.07 x
4.33 m. Origin the code market's ground centre, add-ons sit on its plinth top at z 0.92, built at the market's final
1.15 scale (place with no extra scale).

Round 3 (round-2 scores Lv2 8.0, Lv3 8.5 passed; Lv3 untouched, Lv2 only):
- Fish: one tidy row of four big flat fish (2.3 studs, lying on the ice, pointed head, V tail, gill line, ink eye),
  orange / silver-grey / yellow / silver-grey, heads to the customer, gaps of ice between them, on an inset light-blue
  ice tray with a dark bluish-grey rim between the posts. No green/blue/red fish; the counter-top studs went under the
  tray.
- Vendor spot: a smooth white 3 x 2.3 stud tile behind each counter (no studs), with a two-crate stack on each side
  (crates only behind the counter). ATT_Work_Stall3/4 moved onto the tile; collision boxes follow the new stacks.
- Awning top: a dark plaque with an orange fish (yellow tail and fin, white eye), tilted with the slope; the awning
  studs under it are skipped. Reads from the high/top-down view.

Round 2 (from the round-1 scores Lv2 6.5, Lv3 7.5):
- Studs (1-stud grid, r 0.32, 0.2 tall, hexagonal): counter tops, the tan stall pads (on every free cell), awning tops
  (tilted with the slope, one per stripe per row), crate tops, bench seat, chimney cap, ridge cap.
- Awnings: 7 alternating blue/white stripes, a stepped valance (0.5 / 0.25 stud drop), raised 0.3 so the valance clears
  head height (collision box moved with it). Posts blue (they end under the awning), counters blue with a white studded
  top plate.
- Fish: body brick, wedge tail, accent dorsal plate, stud eye, 1.7 studs long (stalls), 4 colour pairs; six per counter
  on a light-blue ice slab. Two stacked brown slatted crates and one more at the back of each pad (the crates keep the
  vendor spot ATT_Work_Stall3/4 free).
- Smokehouse: brown plank walls (9 bevelled courses, windows aligned to courses), brown gables with a gold fish glyph,
  doorway 6.6 outer / 6.0 clear studs (frames 0.3), five smoked orange/gold fish hung in the xz plane on the rail,
  fish on the side racks the same orange/gold; floor is a plain tan plate (no studs, no blobs); firewood pyramid
  removed; bench is 2 barrels and a plank seat flush against the front wall (y 8.0), studded.

Lv1 market is still `fishMarket()` in `src/shared/DockPieces.luau`. Lv2: two flank stalls at (+-14, 3) facing inward.
Lv3: 9 x 8 walk-in smokehouse at x -3..6, y 8..16, chimney to 13.7.

Nodes (layers bottom to top): `Lv2` (`L01_Base`, `L02_Counters`, `L03_Frames`, `L04_Awnings`, `L05_Stock`), `Lv3`
(`L01_Base`, `L02_Walls`, `L03_Roof`, `L04_Racks`, `L05_Fish`, `L06_Chimney`). Collision: one simple box per object,
`Lv2_Col01_COL`..`Lv2_Col12_COL` (per stall: counter, awning, two upper posts, two crate stacks) and
`Lv3_Col01_COL`..`Lv3_Col11_COL` (smokehouse walls in six bites, roof/chimney overhead, chimney, two side racks, bench).
Roblox hulls each mesh, so a merged `_COL` would fill the 6-stud doorway and the vendor tiles; split boxes keep the door,
interior walkway and the fishers' tiles open. Attachments (plinth top): ATT_Work_Stall3 (16.75, 3.0, 0.95),
ATT_Work_Stall4 (-16.75, 3.0, 0.95) (round 3: moved onto the vendor tiles), ATT_Work_RackLeft (-1.2, 11.5, 0.95), ATT_Work_RackRight (4.2, 11.5, 0.95).

Renders: `build/prod/M_Bld_FishMarketAddons/review/M_Bld_FishMarketAddons/2026-10-27_sheet.png` plus turntable and
close-ups; `levels/levels_sheet.png` (copy: `sheet_levels.png` here).

Open: not playtested in Studio or wired into the game; add-ons are not in `src`, docs/12 or
`art/reference/M_Bld_FishMarketAddons/dims.md`; placement assumes the market frame at final 1.15 scale with no extra
ScaleTo. The smokehouse sits +1.5 in x to clear the existing left rack (right stall 5.9 studs away, left 8.9;
intentional). The side racks show best from inside or at an angle through the wide door; the central hanging fish and
chimney show straight on. Hanging fish are visual only (bottom 6.5, just above the player head at 6.45); floor, pad and
awning studs are visual (collision stays flat boxes); awning valance bottom 6.64. Hanging smoked fish read as a row of
tall orange tags from the door. The stall fish face the customer, so from the low stall-detail angle (behind the
counter end) they overlap visually; they read best from the square. LOD1/LOD2 are 50%/25% of LOD0. Awaiting the
round-3 art-director score.

Collision fix (2026-10-27, after the HQ Studio playtest showed a merged multi-box `_COL` hulled shut across its door):
split `Lv2_COL` / `Lv3_COL` into 23 single-box `_COL` objects (`out_cols` in build.py). Visual meshes, LODs and the
texture set are unchanged (same tri counts; texture PNGs byte-identical). Re-ran build, lod, validate, export,
turntable. Not yet checked in Studio.
