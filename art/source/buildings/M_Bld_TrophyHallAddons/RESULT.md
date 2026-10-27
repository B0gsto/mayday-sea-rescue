# M_Bld_TrophyHallAddons result (docs/25 B, 2026-10-27, round 3)

Lv2 + Lv3 add-ons for the code-built Trophy Hall (`trophyHall()`, `DockPieces.luau`), Lego style, front -Y.
Round 3 (AD round 2: Lv2 8.0, Lv3 8.5 passed and untouched). Validate PASS (475 checks, 0 failed, 93 waived). LOD0
7,926 tris of 8,000 visual (+43 COL boxes x 12; the LOD0 FBX shows 8,442); LOD1 3,961 / 4,000, LOD2 1,977 / 2,000. Size
50 x 28.1 x 32.25 studs on the hall's 50 x 28 lot. One texture set, `T_TrophyHall_Brick` (1,024, 16-cell flat
palette, one material). Origin the code hall's ground centre; place with no extra scale.

Nodes and layers: `Lv2` (`L01_Base`, `L02_Colonnade`, `L03_Drum`, `L04_Dome`, `L05_Plinths`) and `Lv3`
(`L01_Portico`, `L02_Gallery`, `L03_Plinths`, `L04_GoldDome`, `L05_Lantern`), one palette mesh per layer.

Round 3 changes (Lv2 only):
1. Lv2 dome top: the navy shell stops at r 3.0 under a sand cap (r 3.1, z 20.75..21.3) with a ring of eight sand
   studs and a gold finial (top 22.7); the eight sand ribs now run up into the cap. All of it sits inside the Lv3 gold
   shell and lantern base, so the Lv3 look is unchanged.
2. Lv2 banners: the blank white squares are now gold anchors (shank, stock, crown, flukes).
3. Budget: hidden faces trimmed (bottoms of boxes and lathes that sit on a bigger top or the ground, the porthole
   inner ends buried in the drum, the dome bottom); `lego.box(bottom=)`, `lego.cyl_radial(inner=)`. The shared
   pedestal and seam trims also drop hidden faces from Lv3 plinths/gallery (no visible change).
4. `fit_check.py` PASS, same numbers as round 2 (below).

Round 2 changes (AD order):
1. Lv2 drum is a sand band 2.6 studs tall (navy cornice bands) with eight light-blue portholes (1.8 wide) in gold rims.
2. Lv2 red banners (2 x 5 studs, gold rod/hem, white emblem) hang on the outer -Y faces of the two front columns; the
   Lv3 portico banners are gone (they hid the Lv2 ones) and the portico columns moved to x +-6.4 / +-9.6 (a red frieze
   on the architrave instead); portico steps widened to +-10.9.
3. Lv3 galleries: navy backdrop wall with red panels behind the plinths, solid navy entablature (gold trim lines,
   red frieze) and a sand cap with gold studs; the canopy now starts behind the plinths (y -9.7), so plinth tops show
   from above.
4. Gold dome: ribs raised 0.3 off the shell (0.95 x 0.7 studs) in a deeper orange-gold (palette cell 5, 214/126/12),
   a deep-gold equator band, and a lantern about 1.8x bigger (glass r 1.85, eight posts, red band, gold cap, spire; top 32.25).
5. Floors: navy border tiles under every column and plinth, a red aisle with gold edges down each Lv2 wing and a red
   path from the rotunda opening to it (the wing studs skip the aisle and path).
6. Footprint, in game coords (right = -Blender x, fwd = -122 - Blender y), `fit_check.py`: Lv2 right +-24.75, fwd
   -135.70..-111.30; Lv3 right +-24.80, fwd -135.45..-108.00; ATT_Plinth right +-22.30, fwd -132.80..-110.25. All inside
   the hall's own lot (right +-25, fwd -136..-108), on the plate (back edge fwd -160) and behind the bridge road (fwd -78);
   the Air Station lot (right 67..109) and Lookout lot (right 54..70) are well clear.

Attachments: ATT_Plinth_01..08 at the Lv2 wing plinths, 09..14 at the Lv3 gallery plinths (moved with them: y -11.75).
Collision: one box per object, `Lv2_Col01..20_COL` and `Lv3_Col01..23_COL` (43 boxes, in the LOD0 FBX), incl. the gallery wall.

Renders: `build/prod/M_Bld_TrophyHallAddons/review/M_Bld_TrophyHallAddons/2026-10-27_sheet.png` (turntable 8/8,
close-ups 4, silhouette) and `levels/levels_sheet.png` (copy: `sheet_levels.png` here); turntable and close-ups
in `.../turntable/`, level views in `.../levels/`.

Regenerate:
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- \
        --build art/source/buildings/M_Bld_TrophyHallAddons/build.py \
        --out-root build/prod/M_Bld_TrophyHallAddons --steps build,lod,validate,export,turntable
    ~/RobloxProjects/tools/blender-run.sh art/source/buildings/M_Bld_TrophyHallAddons/views.py
    python3 art/source/buildings/M_Bld_TrophyHallAddons/views_sheet.py
    ~/RobloxProjects/tools/blender-run.sh art/source/buildings/M_Bld_TrophyHallAddons/fit_check.py
    python3 tools/blender/sheet.py --asset M_Bld_TrophyHallAddons --out-root build/prod/M_Bld_TrophyHallAddons

Open: not playtested, not wired into `src`, docs/12 or `art/reference/M_Bld_TrophyHallAddons/dims.md`; Lv1 is the
code wall (this file starts at Lv2). Awaiting the round-3 art-director score.
