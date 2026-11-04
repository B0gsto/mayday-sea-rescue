# M_Bld_UpgradeStation round 3 (2026-11-04, Opus 5.5, Blender instance 4 over TCP; AD round 1: 6.5, round 2: 6.8)

Validate PASS (554 checks, 0 failed, 28 waived: texture sets, LOD UV). Zfight on all 3 FBX: 0 visible (hidden pairs remain). Tris LOD0 16,294 of 40,000 / LOD1 6,044 / LOD2 2,111. Box colliders in `_ColNN_COL`. One atlas (red and yellow stud patches added).

Ids: LOD0 104512628163798, LOD1 127529515553036, LOD2 89249063532313. ALB 71426657340889, NOR 86703344289683, RGH 124418267059037, MET 87820449258254 (maps Reviewing at upload).

Origin: baseplate top. **Water sits 1.5 below the origin**; quay top +0.4. Model forward (Roblox -Z) = open sea.

Bay unchanged: 24 wide (fenders gone, so fully clear), 30 long. Clear above water: 15.83 over the middle 10 (tool tips), 13.15 across the full 24 (hook tip, x 6.6). The build asserts no collider in the bay and floods a walk from spawn to the workshop.

Attachments (Roblox studs; `assets/fbx/M_Bld_UpgradeStation/*.attachments.json` has look/up). Unchanged: ATT_BoatLanding (0,-1.5,12) look -Z; ATT_BoardScreen (18.92,9.76,11.80) look (-.866,0,-.5), screen 14.82 x 9.36; ATT_BoardButton; ATT_PlayerSpawn; BayMouth; QuayLadderTop; ToolsHub; HoistHook; SparePile. **Moved with their props:** ATT_WorkshopDoor (-21,.4,3.75) look +X (side door, from the inner quay), ATT_WorkbenchTop (-26,3.4,5.7), ATT_NavLight_Port/Stbd (∓17,23.5,-3.5).

Cut from the concept: fenders, bollards, lamps, lifebuoy, flowers, bushes, round trees, crates, engine, spring, prop, bolts. Sheet's phone view is landscape 844 x 390 with a new camera, not the concept's portrait frame, which cannot show the workshop.

Game: SurfaceGui on a new Part at ATT_BoardScreen, Front face, 0.06 off the screen; button label too. Neon on `_Glow*`. A light at ATT_WorkbenchTop would help the interior. Island ground must not fill the bay. AssetIds not regenerated. Not seen in Studio.
