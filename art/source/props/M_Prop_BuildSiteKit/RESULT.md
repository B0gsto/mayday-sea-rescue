# M_Prop_BuildSiteKit (2026-11-01, PERF-BL2 r1-r4 + FIN9 r5-r6: Opus 5.5, Blender MCP)

**Shipped r6 (AD median 8.8; bar 9.1 not met).** Ids: LOD0 75254069839731, LOD1 124941006039198, LOD2 85634491056108
(ALB unchanged). LOD0 4,240 tris (large_prop 8000), validate PASS (354 checks), zfight 0 visible pairs, the slung brick
clears the preview building's footprint (0 verts inside).

| Round | AD (3 fresh Opus, median) | Changes / left |
|---|---|---|
| r5 | 8.6 (8.6/8.6/8.7) | mast chords 1.3x, cones 1.5x, one-colour stacks (red), calm lower fence rail, hook at 10.5 on a longer jib, brick hangs higher and turned across the jib (clears the corner). Left: all-red stacks blob with the red/white posts, busy gate/barrier, thin jib |
| r6 | 8.8 (8.7/8.8/8.8) | stacks blue, gate posts plain yellow (no lamp domes), plain white leaf, yellow/black barrier (no lamp), mast lattice 0.4, jib deck/chord/lattice thicker. Left: blue stacks merge with the blue scaffold (green suggested; the 3 pallets share meshes), jib still thin, red/white boom on the gate, thin hook cable |

r1-r4 notes below (ids there are r4's, replaced).

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
