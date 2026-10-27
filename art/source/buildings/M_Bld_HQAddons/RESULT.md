# M_Bld_HQAddons result (docs/25 A + J, 2026-10-27; passed art director Lv4 8.5, Lv5 8.5; walk-in stair fix after)

Validate PASS (596 checks, 0 failed, 120 waived: gameplay node/layer naming, flat-palette LOD UV layout). LOD0 7,895
tris / 12 visual meshes (budget 8,000): Lv4 3,914 (Base 396, Walls 682, Trim 620, Interior 624, Roof 616, Mast 976),
Lv5 3,981 (Base 332, Tower 534, Trim 1,959, Balcony 664, Lantern 464, Beacon 28); LOD1 3,946, LOD2 1,966; COL 60
boxes x 12 tris (Lv4 12, Lv5 48). Set: 1 (T_HQAddons_Brick, 16-cell flat palette, 1024, unchanged). Size 34.6 x 28.5
x 49.7 studs (the two add-ons, not the station; the stair took y from -4.6 to -18.7). Origin the
HQ lot ground centre, built at 1x. Blender +X = in-game -X (roblox = -bx, bz, by): in game the wing attaches to the
station's -X wall and the tower stands one bridge further out on the same side (the Blender views mirror that).

Walk-in fix (after the pass), Lv5 only: an outside stair to the wing roof, so the bridge is reachable. It climbs
straight up the front of the wing / tower gap (x 43.8..50.0, 6.2 wide, 5.0 clear between the fence posts; game: island
right -44..-50, fwd -9..+7, clear of the plaza (right +/-40) and the Depot stub (right -69)) from y -18.7 to a tan
landing (y -3.3..0.4, top 15.62 = the east parapet cap) beside the bridge: 15 risers of 1.04, 1.1 treads, two tan
studs a tread, solid white sloped fence panels with red rails and red stud-capped posts both sides. A solid white
panel fence with red rails runs round the wing roof edge (front and back caps, the station end at x 27.85, clear of
its gable overhang to 27.5, the east cap behind the bridge); the landing (3.1 wide onto the east cap) and the bridge
step plate are the two openings. The gap behind the landing stays open under the bridge. Collision: a box per step
and the landing, a full-height box per side fence (5.0 clear between), one per roof fence side. To pay for it the
hidden faces went: stud bottoms (all studs_on), the wall course tops under the next course / roof / ledge, the first
course bottoms on the plinths (Lv4 looks unchanged). It could not stay inside the old 14.4 depth: the 5-stud gap
behind is the bridge and its knee braces, and a 15.6 climb at <= 1.1 a step needs 14 treads.

Round 3 fixes (art director round 2), Lv5 only: (1) night beacon: no halo spheres, no bloom; the Lv5_L05_Beacon lamp
(8-sided lens drum r 1.55 on a grey pedestal, a gold lens band, gold cap) emits steady amber in the night render only,
lit by one point light in the lantern; the glass cell glows a soft warm light (render-only cell mask). No beam.
(2) lantern: a light-blue pane in all 8 bays (two per side, gold mullion, gold bottom / mid / top bars) from the sill
to 2 studs under the eave, so the lamp head shows in the open band above them; lantern 0.6 taller (6.6), eave trimmed
to 0.2 past the posts and 0.45 thick, red roof steps 3.2 / 2.5 / 1.8 / 1.1. (3) walkway: the ground path and its
fences are gone; a raised bridge (deck top 16.0, resting on the wing's east parapet cap, studs inside the deck, Lego
style) runs from a step plate on the wing roof (15.05 -> 15.55 -> 16.0) to a new 4.2 x 6.6 red-framed door on the
tower's west face at its second floor; navy girder and two knee braces under it, 2.2-stud Lego fence panels with red
top rails each side. For the 6.6 door the tower's lower stage gained one course (10, 22.6); everything above moved up
2.2 (balcony 38.6, tower top 49.7). Lv4 geometry is untouched (the bridge sits on its parapet cap).

Lv4 radio wing (docs/25 A: "+ radio mast wing"): a walk-in double-height radio hall against the station wall, 16.4 x
12 studs (26.4..43.2 x -3..9), tan stud plinth 17.6 x 13.6, 12 red/white courses (red courses k 0, 4, 8), navy eave
bands at the storey line and under the roof, a 6 x 6.975 door with a navy frame, a white signal plaque with three
bars and a yellow dot, a yellow lifebuoy, white parapet with red cap and studs, a 3.6-stud white pad for the mast.
Inside: a white desk (1.9 x 7.7, 2.58 above the floor) with three dark radio sets (glass screens, red/green buttons,
knobs), an ink back panel, the chart board on the back wall (white frame, cyan sea, tan islands, grid, red route,
yellow pins), a shelf with three binders and two warm ceiling lamps. Floor clear.

Lv5 beacon tower (docs/25 A: "+ gold beacon tower"): a 8.2-stud-square lower stage (0.6..22.6, 10 courses) and 7.0
upper stage (23.2..38.6, 7 courses), red at courses 0/4/8 and 12/16, a 4.2 x 6.6 red-framed front door, a 4.2 x 6.6
west door at the second floor (16.0) for the bridge, small navy windows on the upper stage and the second floor, the
crest above the front door, the 11.4 balcony at 38.6..39.2, the glazed gold lantern room 40.1..45.8 with the lamp
41.1..45.5, a red roof to 48.85 and a gold finial to 49.65. Walk-in: the ground floor (0.72..15.4, warm lamp under the
slab, a notice board) and the second floor (16.0..22.6, lamp under the ledge) behind the bridge door; the upper stage
is solid. The balcony is decorative (no ladder); the Lv5 stair climbs to the wing roof and the bridge.

Nodes (layers bottom to top): `Lv4` (`L01_Base`, `L02_Walls`, `L03_Trim`, `L04_Interior`, `L05_Roof`, `L06_Mast`), `Lv5`
(`L01_Base`, `L02_Tower`, `L03_Trim`, `L04_Balcony`, `L05_Lantern`, `L05_Beacon`;
the bridge lives in Trim, the second floor in Tower).
Collision: one simple box per object, `Lv4_Col01_COL`..`Lv4_Col12_COL` (plinth, floor, three front bites around the
door, back, west, east, roof, desk, mast, step) and `Lv5_Col01_COL`..`Lv5_Col27_COL` (plinth, floor, threshold, three
front bites, back, west below the bridge door, two west bites beside it, second floor, east, ledge, upper stage,
balcony deck, four fence sides, lantern room, lantern top, crest, bridge deck, two bridge fences, roof step plate,
front step, 14 stair steps, landing, two stair side fences, four roof fences). Attachments (Blender coords; game = (-bx, bz, by)): ATT_Work_Radio
(39.6, 4.0, 0.72), ATT_RadioMast (36.0, 4.2, 15.4), ATT_Beacon (55.0, 3.0, 41.1), ATT_Balcony (55.0, -3.0, 39.2).

Renders: `build/prod/M_Bld_HQAddons/review/M_Bld_HQAddons/2026-10-27_sheet.png` plus turntable and close-ups (radio
wing, radio room, beacon tower, lantern, stair + bridge, crest). `levels/levels_sheet.png` (copy: `sheet_levels.png`
here) predates the stair (not re-rendered).

Open: wired in game (DockPieces `hq()` via `addonMesh`, the code mast / gold ball only when the mesh is missing), not
playtested since the stair: walk an R15 up the 1.04 steps, onto the cap and across the bridge into the tower. The
station's side windows at y 0 and 8 sit behind the wing (accepted). LOD1/LOD2 are 50%/25% of LOD0.
