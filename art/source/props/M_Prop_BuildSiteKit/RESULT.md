# M_Prop_BuildSiteKit (2026-11-01, PERF-BL2: Opus 5.5, Blender MCP, 4 AD rounds)

Validate PASS (354 checks, 0 failed, 71 waived: layer naming, LOD UV layout). LOD0 4,560 tris, LOD1 2,274, LOD2 1,128
(large_prop 8000). zfight: LOD0 0 visible pairs (run.py), LOD1 / LOD2 0 visible (zfight_check.py on the FBXs).
One flat-palette set (T_BuildSiteKit_Brick; NOR/RGH/MET = the Depot palette bytes, SHARED_BYTES). Yellow cell brightened
to 255,200,12 (the jetty 255,188,0 read ochre in shade).

Modules (each mesh placed by ConstructionController.kitProps from its ATT_<slot> origin): L01_FencePanel (8 studs,
tiles + stretches), L02_FenceGate, L03_FencePost, L04_ScaffoldBay (6 x 2.4 x 5, stacks +5), L05_CraneBase,
L06_CraneSlew + L07_CraneHook (slew / bob round ATT_CranePivot, 20.6 up), L08_StackPallet + L09/L10/L11 Low/Mid/Top
(fill states: tops hide first), L12_SignBoard (ATT_SignUI), L13_Cone, L14_Barrier, Col01_COL.

Ids: LOD0 108631160743774, LOD1 92712016149318, LOD2 117455714827399; ALB 135401836063414 (Reviewing at upload).
Wiring: DepotArtService publishes DepotTemplates.BuildSiteKit; the code-built Parts stay as the fallback.

AD (fresh Opus each round, bar 9.1): r1 7.4, r2 7.6, r3 8.3, r4 8.4. Sheets: build/status/2026-11-01/perfect/
M_Prop_BuildSiteKit/r1..r4/contact.png (main checkout). Below the bar after the 4-round cap. r4 open fixes: hook/brick
hangs outside the back fence (kept clear of the walls), one colour per pallet, front edge still busy, mast chords
1.3x, cones 1.5x. Not run: Studio zfight_scan / in-game look (tour said the old site did not render: verify).
