# M_Prop_BuildSiteKit (2026-11-01, PERF-BL2 r1-r4 + FIN9 r5-r6: Opus 5.5, Blender MCP)

**Shipped r8 (AD median 9.15 = 9.1/9.15/9.2; bar 9.1 PASS; r7 8.9, r6 8.8).** Ids: LOD0 83598223677081, LOD1
132983174625303, LOD2 97455737881261; ALB 83295799662146 (r7/r8 palette; Reviewing at upload). AssetIds carries
ATT_StackB / ATT_StackC; ConstructionController needs all 20 modules (per-pallet L09-L17 courses). Tris LOD0 5,536 /
LOD1 2,762 / LOD2 1,368 (large_prop 8000). Open: flat red jib/mast sawtooth lattice, slings barely visible, flat
scaffold braces/planks, lime next to the green stack; LOD1/LOD2 FBX zfight not checked; turntable rows use pipeline
lighting (yellow reads tan there). Not run: Studio / in-game look.

| Round | AD (3 fresh Opus, median) | Changes / left |
|---|---|---|
| r5 | 8.6 (8.6/8.6/8.7) | mast chords 1.3x, cones 1.5x, one-colour stacks (red), calm lower fence rail, hook at 10.5 on a longer jib, brick hangs higher and turned across the jib (clears the corner). Left: all-red stacks blob with the red/white posts, busy gate/barrier, thin jib |
| r6 | 8.8 (8.7/8.8/8.8) | stacks blue, gate posts plain yellow (no lamp domes), plain white leaf, yellow/black barrier (no lamp), mast lattice 0.4, jib deck/chord/lattice thicker. Left: blue stacks merge with the blue scaffold (green suggested; the 3 pallets share meshes), jib still thin, red/white boom on the gate, thin hook cable |
| r7 | 8.9 | each pallet its own course meshes L09-L17_Stack{Low,Mid,Top}{A,B,C} (A green, B orange, C lime; ATT_Stack / ATT_StackB / ATT_StackC; palette cells 3 ink -> green, 14 glass -> lime, so the ALB needs a re-upload), Sign/Cone/Barrier renumbered L18-L20, yellow/black gate boom, jib 1.3x (deck, chord, lattice), cable 0.44, white loose brick. LOD0 5,056 / LOD1 2,528 / LOD2 1,252, validate PASS (494), zfight 0. Not uploaded: AssetIds needs the new ATT_StackB/C (until then the controller keeps the Parts) |
| r8 | 9.15 (9.1/9.15/9.2) | yellow #F2C21B (palette cell 6), orange/green/lime more saturated (ALB re-upload needed), bevels capped 0.05 in K.box (straight brick sides, no wedges), studded fence top course, white loose brick removed, gate boom 3 bands 0.8 thick, clear J hook + two 0.15 slings, sign rim 0.2 proud + top stud row + 0.6 legs on 2x2 foot plates, jib lattice 0.6, 2x2 studs on the ballast; preview renders Standard -1 EV like the BoardKit anchor. LOD0 5,524 / LOD1 2,762 / LOD2 1,368 (FBX, incl. COL), validate PASS (494), zfight 0 |

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
