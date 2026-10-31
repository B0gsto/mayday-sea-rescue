# M_Prop_PrizeWheel (2026-10-31, round 2: Opus 5.5, Blender MCP)

Validate PASS (90 checks, 0 failed, 20 waived: layer naming, LOD UV layout/UV faces). LOD0 7,740 tris (L01_Stand 2,892,
L02_Rotor 4,704, L03_Flapper 144, Col01_COL 12), LOD1 3,870, LOD2 1,934. zfight: LOD0/LOD2 0 visible; LOD1 had 1
decimation pair on a column brick's back face, fixed with `zfight_check.py --fix-fbx` (re-run that after `lod`).
Set: 1 (T_PrizeWheel_Brick palette atlas; Legendary is now a deep metallic gold).
Origin = the wheel's `at`; hub (0,10,-3.6), flapper hinge (0,17.9,-4.82) in studs (unchanged).
Ids: LOD0 97184488264751, LOD1 116553799953798, LOD2 101911048150193; ALB 127897426291027, RGH 84404228511082,
MET 132223528155264 (textures Reviewing at upload).
Round 2 changes: blue flapper housing with cheeks + chrome hinge pin; chunky outlined flapper with a red arrowhead whose
tip sits just inside the peg ring; gems ~1.25x linear (~1.55x area) on white discs (12 tiles leave no room for 1.6x
linear); white rim trim (gold never meets yellow); raised trapezoid dividers (white crest, silver flanks, navy strip);
stacked brick columns with side/front studs, studded header brick.
AD round 2: 7.5/10 (build/status/2026-10-31/wheel2/contact_small.png). Round 3 fixes: tint the discs to a light shade
of their tile (or 0.7x, pushed out) so colour fills the wedge; Common: silver-white gem, darker warmer grey tile; base
plate front shading smear (smoothing on the bevel); put an icon or studs on the housing's blank yellow plate; slimmer,
bevelled chrome hub ring. Studio checks (spin lands under pointer, flapper swing vs cheeks, zfight_scan) NOT run.
