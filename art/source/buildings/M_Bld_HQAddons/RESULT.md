# M_Bld_HQAddons result (docs/25 A + J, 2026-10-27; passed art director Lv4 8.5, Lv5 8.5; walk-in stair fix after)

## Round PERF-HQ r5 (2026-11-01, after AD r4 L3 9.0 / L4 8.8 / L5 9.1; unjudged)

Leaves (Lv3 bay, Lv4 block) open 90 deg, square to the facade, clear of the windows; ridges (hall, bay, radio room) are stepped 2-stud white segments with 0.05 seams, a red stud each and red end caps (gables, both cupola sides); grey mortar course lines + staggered head joints (3 studs) on the hall's 4 walls and the Lv4 block front/east; plaque 13.3 x 4.15 red rim for the 12 x 3 sign, ATT_Sign_03 z 12.2 -> 12.5 (0, -20.59, 12.5); orange lifeboat on a grey wheeled trolley at x -12 (bow to the path, Lv3_Col16); mast legs 0.9, dish 6.75 across on a 2x2 grey bracket, pad 4.0; Lv5 tower windows 2.4 x 3.4 with the hall's frames, cross bars and studded sills. Palette cell 9 cyan -> orange (the chart sea uses glass blue): ALB regenerated, re-upload the texture.
Tris Lv3 15,816, Lv4 10,794, Lv5 7,931; LOD0 34,541, LOD1 14,579 (LOD1 share scaled x0.845 to fit 15k), LOD2 8,626 (waived). Validate PASS (846, 0 failed), zfight 0 left (3 faces moved); FBX + turntable done.

## Round PERF-HQ r4 (2026-11-01, after AD r3 L3 8.9 / L4 8.4 / L5 9.0; unjudged)

Lv4: a walk-in front block before the radio wing, footprint x 26.9..43.2, y -15.4..-3.0 (above z 14.5 the back stops at -3.45, the west face steps to 27.6 above the eave, clear of the hall gable at 27.5 and 0.5 off the Lv5 stair at 43.72): 15 red/white courses to 18.0, studded navy deck, red/white chequer parapet + red cap (19.65), deep-red portal 6.4 x 8.1 at x 32.2..38.6 with red leaves swung 115 deg out, radio-wave plaque, 4 inset windows, open through to the wing door; COL Lv4_Col14..23. Grey 4.5 parabolic dish (dark rim, 3-strut feed horn) at z 27; red studded canopy porch on 2 white posts over the station door. Lv3: boathouse leaves swung 115 deg out from the portal, red kneelers under the gable overhang, cross ridge cap widened + red studs (the "white rod"), main ridge cap 1.2 high, roof studs 1.3x. Lv5: gold/red crest roundel over the bay lifebuoy, red/white band under the gallery, red cap band at the tower base, red 2-rise brick stringers on the stair and landing.
Tris Lv3 11,724, Lv4 10,100, Lv5 7,811; LOD0 29,635, LOD1 14,812, LOD2 7,400. Validate PASS (841, 0 failed), zfight 0 left (3 faces moved); FBX + turntable done.

## Round PERF-HQ r3 (2026-11-01, after AD r2 L3 9.2 / L4 8.7 / L5 9.2; unjudged)

Lv4: a one-storey radio room on the wing roof west of the mast (x 28.8..33.6, y 0.4..8.4, 15.05..20.05: red/white courses, red pilasters, framed inset window band facing the path + one on the -X end, stepped red studded roof, white red-studded ridge cap, top 22.8, one COL box), clear of the Lv5 fences/landing/bridge; mast legs 0.6, 14 bands of ~2 studs. Lv3: red ball finial on a short gold spike (weathervane gone), back-wall red pilasters at x +/-4.5/13.5. Lv5: brown riser plates under tan nosings, red stud-capped handrail posts every 2 treads (step sizes, COL unchanged).
Tris Lv3 11,612, Lv4 6,572, Lv5 6,039; LOD0 24,223, LOD1 12,106, LOD2 6,046. Validate PASS (791, 0 failed), zfight 0 left; FBX + turntable done.

## Round PERF-HQ r2 (2026-11-01, after AD r1 8.2; unjudged)

Lv3: 3 mirror windows on the solid +X front half (x 9/15/21, pane on the face, wall solid inside), red 1x2 brick pilasters (4 corners, front x +/-12/18, -X end y +/-4, +X end y -11.5/12), red boathouse leaves flat on the bay side walls (|x| 5.55..6.0, white rails + Z-brace, dark seams, no COL), a ridge lookout cupola at x 5.7..10.3 (glass, red stepped roof, gold weathervane, top 36.6).
Lv4: mast 30.5 -> 44 (9 red/white bands), red/white warning-light cap, dish 6.5 across at z 26, red/white block band on the front parapet. Tris Lv3 11,364, Lv4 5,160, Lv5 5,651; LOD0 22,175, LOD1 11,080, LOD2 5,534. Validate PASS, zfight 0 left.

## Round PERF-HQ r1: Lv3 station (2026-11-01, unjudged)

The code `station()` shell as Lv3_* meshes (white courses, red base, grey stud plinth, white eave, blue gable,
windows on the code spots): L01_Base 1,170, L02_Walls 1,938, L03_Trim 1,444, L04_Front 1,120, L05_Roof 4,034 = 9,706
tris. New: inset 4 x 5 windows (glass 0.3 behind a navy frame, red studded sill; the +X y 0/8 pair flush behind the
wing), stepped-tile roof with stud rows and a red-studded white ridge cap, and a path-facing entrance bay: deep-red
portal round the 10 x 9 door (leaves open inside the bay, no COL), framed plaque, crow-stepped white cross gable with
red copings, lifebuoy roundel and a short flag mast. ATT_Sign_03 (0, -20.59, 12.2) added. COL: Lv3_Col01..15.
Budget now hero_building (LOD shares kept by patch_lod_targets; LOD2/texture sets waived); palette cell 5 = deep red.

PERF-HQ r1: Lv4/Lv5 (unjudged). Lv4: a deep-red portal (0.8 jambs, lintel, red keystone) round the open door, a
red-framed white plaque on a grey ledge above it (the signal icon moved onto it), every window a proud navy frame
with the glass 0.3 behind it, a white mullion and a red studded sill; mast legs 0.36, a 5.2-wide white dish with a
red rim and feed facing the path at z 23.5. Lv5: the same portal on the tower door, 1.8-wide inset windows with
sills, gold tile studs on the lantern eave, red studs on each roof step, a gold plate / spike / ball finial (top
50.55). Footprints, ATT_*, COL, stair and bridge unchanged. Lv4 4,612 tris, Lv5 5,651; LOD0 19,973 (40k), LOD1
9,982, LOD2 4,982. Validate PASS, zfight 0 left.


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
