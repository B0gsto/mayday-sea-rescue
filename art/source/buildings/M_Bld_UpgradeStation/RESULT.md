# M_Bld_UpgradeStation (2026-11-04, Opus 5.5, Blender MCP instance 4 over TCP)

Validate PASS (612 checks, 0 failed, 29 waived: texture sets, LOD UV). Zfight on all 3 FBX: 0 pairs. Tris LOD0 32,396 / LOD1 9,810 / LOD2 2,336, hero_building. 18 meshes, 42 box colliders (`_ColNN_COL`). One atlas.

Ids: LOD0 102247232754687, LOD1 128694848151855, LOD2 108432468616969. ALB 75532055165253, NOR 92156615740053, RGH 91236347861117, MET 87820449258254 (maps Reviewing at upload).

Origin: baseplate top. **Water must sit 1.5 below the origin**; quay top +0.4. Model forward (Roblox -Z) = open sea.

Bay: 24 wide (22.7 between fenders), 30 long. Clear above water: 16.9 over the middle 10 (hoist rail), 13.15 across the full 24 (hook tip, x 6.6). Build check also keeps colliders out of the bay and floods a walk from spawn to the workshop.

Attachments (Roblox studs from origin; `assets/fbx/M_Bld_UpgradeStation/*.attachments.json` has look/up): ATT_BoatLanding (0,-1.5,12) look -Z; ATT_BoardScreen (18.92,9.76,11.80) look (-.866,0,-.5), screen 14.82 x 9.36; ATT_BoardButton (17.62,4.04,11.05); ATT_WorkshopDoor (-26,.4,13); ATT_PlayerSpawn (14.3,.4,20.6); plus ATT_BayMouth, QuayLadderTop, NavLight_Port/Stbd, ToolsHub, HoistHook, WorkbenchTop, SparePile.

Game: SurfaceGui on a new Part at ATT_BoardScreen, Front face, 0.06 off the screen; button label too. Set Neon on `_Glow*` meshes. Island ground must not fill the bay. AssetIds not regenerated; `Glass` is opaque. Not seen in Studio.
