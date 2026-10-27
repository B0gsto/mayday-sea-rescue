# M_Bld_ClinicAddons result (docs/25 B and J, 2026-10-27, self-review rounds)

Round 3 (art-director round 2: Lv2 8.0, Lv3 8.5, bar 8.5). Validate PASS (414 checks, 0 failed, 82 waived). LOD0 7,068
tris (budget 8,000): Lv2 2,048, Lv3 5,020; LOD1 3,531, LOD2 1,763. Size 72.87 x 39.70 x 15.65 studs (y grew: the
ambulance pad is longer). Round-3 changes: (1) the Lv2 pavilion roof is 7 slope rows, red/white/red.. (4 red rows twice
the width of 3 white), with a white ridge cap and white studs along it, the same language as the Lv3 roof. (2) The
ambulance and its collision box moved 5.5 studs south (`AMB_DY`; van y -17.9..-4.8, ATT_Park_Ambulance (31.8, -11.4));
its pad grew to y -19.1..1.9 so the forecourt stays one pad; the open rear-door tips now stop 6.3 studs short of the
hospital front wall and point at the doorway. (3) The green medic floor patch is a light-blue studded tile with a flat
red cross (`medic_tile`, palette GLASS cell, no new colours); the same tile sits under the Lv2 counter and medic spot
(x -34.0..-27.4, y -8.6..-3.6, no studs under the counter). The Lv3 desk front panel and screen bar are still green
(not in the fix list).

Round 2 (art-director round 1: Lv2 7.0, Lv3 7.5, bar 8.5). Validate PASS (414 checks, 0 failed, 82 waived). LOD0 6,960
tris / 11 visual meshes (budget 8,000): Lv2 1,932, Lv3 5,028; LOD1 3,478, LOD2 1,734; COL 27 boxes x 12 tris (Lv2 12,
Lv3 15), in the LOD0 FBX. Set: 1 (T_Clinic_Brick, 16-cell flat palette, 1024; no new colours: the medic tile and desk
accent use the green cell). Size 72.87 x 34.20 x 15.65 studs. Origin the code clinic's ground centre, front -Y; built at
the clinic's final 1.15 scale (place with no extra scale).

Round-2 changes: (1) Lego: 6-sided studs (open bottoms) on every pad rim (rim now 0.9 wide), ridge caps, counter and desk
tops, sign tops, ambulance roofs and hood; plate/brick seam lines and staggered joints on the hospital walls; round-plate
caps under the pavilion roof on all six posts. (2) Colour: pavilion has red eave fascias, red barge boards, red ridge cap
and red column bases; hospital has a red mid-height band (z 3.0..4.2), red eave band, bigger red-framed windows
(3.2 wide, z 4.9..7.4, front, back and both long walls), a red cross on a white gable plate facing the approach, and a
red roof with white stripes (the pavilion roof stays white, so the two read apart from above). (3) Signs stand up: a
double-faced red-framed ridge sign with a cross on both faces on each roof (pavilion ridge z 11.4..14.0, hospital 12.9..15.5).
(4) Medic station: desk 5.4 x 2.2 (x 25.7..31.1, y 16.0..18.2) with a green front panel, studded tan top, monitor, keyboard,
tray and the cross cabinet; green studded floor tile (x 25.7..31.1, y 12.0..16.0); ATT_Work_Desk moved to (28.4, 14.6).
(5) Ambulance rebuilt chunky: hood/cab/box bricks, 5.6 x 13.1 x 6.8, big r1.7 wheels with stud hubs, red + blue plain light
bar, roof studs, open rear doors (150 deg) with a dark bay and red stretcher; moved west to x 29.0..34.6 on a pad
x 28.4..35.2, y -13.6..1.9 (ATT_Park_Ambulance (31.8, -5.9)); the red kerb blocks were dropped.

Earlier layout unchanged: Lv2 open pavilion, left flank x -35.6..-20.6, y -10.6..7.6, six posts, three beds with IV stands, medic
counter (ATT_Work_Bed1..3, MedicCounter); Lv3 walk-in hospital wing x 20.6..36.2, y 1.9..20.1, 6-stud doorway (6.0 clear,
top 7.9), four beds (ATT_Work_Bed4..7), desk. Nodes: `Lv2` (`L01_Base`..`L05_Counter`), `Lv3` (`L01_Base`..`L06_Ambulance`).
Collision: one box per object, `Lv2_Col01..12_COL`, `Lv3_Col01..15_COL`; the ambulance box is x 29.0..34.6 (the van still
leaves 5.1 of the 6-stud doorway approach clear; the open doors have no collision).

Renders: `build/prod/M_Bld_ClinicAddons/review/M_Bld_ClinicAddons/2026-10-27_sheet.png` plus turntable and close-ups;
`levels/levels_sheet.png` (copy: `sheet_levels.png` here).

Open: not playtested or wired into the game; not in `src`, docs/12 or `art/reference/M_Bld_ClinicAddons/dims.md`. Pavilion
beds and blankets are not studded (tri budget). The open rear doors swing toward the doorway but the van sits beside
the approach, not in it. Awaiting the round-3 art-director score.
