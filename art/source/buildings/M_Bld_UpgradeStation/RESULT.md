# M_Bld_UpgradeStation round 2 (2026-11-04, Opus 5.5, Blender instance 4 over TCP; AD round 1: 6.5)

Validate PASS (642 checks, 0 failed, 29 waived: texture sets, LOD UV). Zfight on all 3 FBX: 0 visible. Tris LOD0 38,695 of 40,000 / LOD1 9,515 / LOD2 2,357. 48 box colliders (`_ColNN_COL`). One atlas.

Ids: LOD0 119984647249639, LOD1 125162955190792, LOD2 77106582921897. ALB 103003933336111, NOR 92156615740053, RGH 97171665789110, MET 87820449258254 (maps Reviewing at upload).

Origin: baseplate top. **Water sits 1.5 below the origin**; quay top +0.4. Model forward (Roblox -Z) = open sea. Pier heads add 3 studs seaward of the old island edge.

Bay unchanged: 24 wide (22.7 between fenders), 30 long. Clear above water: 16.9 over the middle 10 (hoist rail), 13.15 across the full 24 (hook tip, x 6.6). The build asserts no collider in the bay and floods a walk from spawn to the workshop.

Attachments (Roblox studs; `assets/fbx/M_Bld_UpgradeStation/*.attachments.json` has look/up). Unchanged: ATT_BoatLanding (0,-1.5,12) look -Z; ATT_BoardScreen (18.92,9.76,11.80) look (-.866,0,-.5), screen 14.82 x 9.36; ATT_BoardButton (17.62,4.04,11.05), now inside the taller button; ATT_PlayerSpawn (14.3,.4,20.6); BayMouth, QuayLadderTop, NavLight_Port/Stbd, ToolsHub, HoistHook. **Moved with their props:** ATT_WorkshopDoor (-24.5,.4,2) look -Z, ATT_WorkbenchTop (-24,3.2,15), ATT_SparePile (-28.5,.4,-4.5).

Game: SurfaceGui on a new Part at ATT_BoardScreen, Front face, 0.06 off the screen; button label too. Neon on `_Glow*`. Island ground must not fill the bay. The pillar blotch was the tools' cast shadow, not geometry: the sheet's sun moved, and a game sun could bring it back. AssetIds not regenerated; `Glass` opaque. Not seen in Studio.
