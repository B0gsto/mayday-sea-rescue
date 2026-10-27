# M_Bld_RescueBoathouseAddons result (docs/25 B + J, 2026-10-27, art-director round 3)

Validate PASS (362 checks, 0 failed, 72 waived: gameplay node/layer naming, flat-palette LOD UV layout). LOD0 7,276
tris / 9 visual meshes (budget 8,000): Lv2 3,060, Lv3 4,216; LOD1 3,638, LOD2 1,816; COL 27 boxes x 12 tris
(Lv2 10, Lv3 17), all in the LOD0 FBX. Set: 1 (T_RescueBoathouse_Brick, 16-cell flat palette, 1024; round 2 swapped
the unused green / cyan / pink cells for medium stone grey, dark red and dark tan). Size 46.00 x 28.02 x 11.48 studs
(y -13.10..14.92, z 0.92..12.40). Origin the code boathouse's ground centre, add-ons sit on its plinth top at z 0.92, built at the
boathouse's final 1.15 scale (place with no extra scale). Front -Y.

Lv1 boathouse is still `rescueBoathouse()` in `src/shared/DockPieces.luau`. Lv2: RIB pontoon in the right half of
the pen (wet slip x 12.4..17.9, y -12.4..3.8, deck to x 23), RIB at (15.15, -4.3), mannequin-high fuel pump on the
back deck, big life-jacket rack against the right fence. Lv3: lifeboat berth in the left half (wet slip x -21.0..-14.8,
y -12.6..11.0, walkway to x -10.9, back deck to y 12.6), lifeboat at (-17.9, -0.6), bow at y -10.6 with 2 studs of
water ahead, a solid red shed roof over the stern (y 7.6..14.8), crew bench on the walkway's east edge, yellow davit
on the walkway's water edge at (-14.0, -4.6), arm reaching west over the foredeck.

Round 3 (art director round 2: Lv2 8.5 passed and is unchanged, Lv3 8.0):
1. Davit moved off the near (west) corner to the far (east) quay edge, standing on the walkway at (-14.0, -4.6) with
   the arm, head block and hook mirrored to reach west over the foredeck; from the front 3Q it stands behind the bow and
   the lifeboat's whole side shows. Walk line moved to x -12.95 to clear its base; bollards (y -11.2, 1.0, 10.5) and
   cleats (y -8.8, 5.6) re-spaced along the longer walkway.
2. Lifeboat 28% longer: 20.0 long x 4.9 beam (RIB 11.6 x 4.3). lifeboat() draws the 15.6 boat and stretches it along Y
   (LB_K 1.28), then adds the studs round. Berth slip 16.6 -> 23.6 long, extended aft only (the code lifebuoy rack sits
   just in front of the front rim); the bow stops 2 studs short of the front rim.
3. Roof is solid red: red courses, red gable fills, red ridge cap with 8 red studs, dark-red eave ties (no white or
   stone stripes). It moved aft to y 7.6..14.8 over the stern cockpit, 5.4 studs behind the mast and clear of the
   wheelhouse (ends y 6.8); roof posts follow it (y 8.5, 13.9).

Round 2 (art director round 1: Lv2 7.5, Lv3 6.5):
1. Lifeboat is now clearly the upgrade: 15.6 long x 4.9 beam (RIB 11.6 x 4.3), freeboard 3.1, thin white gunwale cap
   instead of the heavy navy rim, a two-tier navy wheelhouse (lower tier to z 5.5, upper to 7.2) with glass window
   strips on all sides, white mullions and a door, an orange top with studs (z 7.5), a mast to z 12.4 with a spar, a
   blue-ended light bar and an aerial, a stern cockpit with orange hatch, yellow rail and red life ring. RIB top is 5.8.
2. Lv3 roof moved back and cut to a 12.3 x 7.2 shed (y 1.4..8.6): bow, deck, wheelhouse and mast show from above.
   The roof is six stepped Lego slope courses per side (red / dark red), stone-grey stepped gable ends with the life-ring
   sign, a stone ridge cap with studs, white eave trim only. Roof ridge z 9.6, eave 7.2.
3. Less white: rims, steps, posts, gables and ridge cap are stone grey; pontoon and walkway decks are tan planks with
   dark-tan seams and staggered butt joints; white is trim, mullions and life rings only.
4. Props bigger: fuel pump 5.6 tall (was 1.9) with a yellow base block, red body, grey canopy, yellow price sign,
   display, side holster and a thick hose to the RIB, reel on the back; jacket rack 1.5x (jackets 1.65 x 2.3, locker
   9.3 long, frame to z 6.4); davit post 1.1 square, arm 0.95 x 0.95, head block, hook block and J-hook (was 0.46 arm);
   crew bench 6.0 long x 1.45 deep with a high slat back, on the walkway's east edge at y -12.4..-6.4 (the side step moved
   to y -4.6..-0.2).
5. Lv2 pontoon is a work area: three yellow bollards, two big yellow cleats at the mooring lines, a yellow dashed walk
   line (x 20.3), the tan planks, a yellow safety edge. Lv3 walkway has the same kit.

Nodes (layers bottom to top): `Lv2` (`L01_Pontoon`, `L02_FuelPump`, `L03_JacketRack`, `L04_RIB`, `L05_Mooring`),
`Lv3` (`L01_Berth`, `L02_Frame`, `L03_Lifeboat`, `L04_Fittings`). Collision: one simple box per object,
`Lv2_Col01_COL`..`Lv2_Col10_COL` (deck, two steps, wet slip, three rims, RIB, fuel pump, jacket rack) and
`Lv3_Col01_COL`..`Lv3_Col17_COL` (walkway, back deck, wet slip, three rims, side step, lifeboat hull, wheelhouse,
bench seat, bench back, davit post, roof overhead, four posts). Roblox hulls each mesh, so a merged `_COL` would fill
the slips; split boxes keep both wet slips, the walkway and the back deck walkable. Attachments: ATT_Work_Pontoon
(20.30, -4.20, 1.62), ATT_Work_Fuel (20.55, 2.65, 1.62), ATT_Work_Berth (-13.00, 2.40, 1.62), ATT_Work_Davit
(-13.60, -2.80, 1.62; at the davit's winch side, moved with the davit).

Renders: `build/prod/M_Bld_RescueBoathouseAddons/review/M_Bld_RescueBoathouseAddons/2026-10-27_sheet.png` plus turntable and
five close-ups (rib, jackets, pump, lifeboat, davit); `levels/levels_sheet.png` (copy: `sheet_levels.png` here; Lv2 and
Lv2+Lv3, front 3Q / side / top).

Open: not playtested in Studio or wired into the game; add-ons are not in `src`, docs/12 or
`art/reference/M_Bld_RescueBoathouseAddons/dims.md`; placement assumes the code boathouse at final 1.15 scale with
no extra ScaleTo. The lot's front gate opening is 11.5 studs (posts at +-5.75); the add-ons fill the outer thirds
and leave the middle x -10.3..11.9 open, so the route in through the gate stays clear. The Lv3 shed roof reaches y 14.9
(code back posts start at y 16.0, back fence 18.7) and the berth's front rim y -13.1 sits just behind the code
lifebuoy rack (about y -14.5..-13.3, x -21.5..-16.5); check both in Studio. The davit base leaves a 2.3-stud lane on
the walkway. The mast top (12.4) still rises above the roof ridge (9.6) in the low front 3Q, in front of it. Pillar
colour is the stone-grey palette cell, so a Studio material remap may tint it. LOD1/LOD2 are 50%/25% of LOD0. Palette,
studs and all small parts are visual; collision stays flat boxes. Awaiting the art-director round.
