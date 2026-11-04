# M_Bld_UpgradeStation final (2026-11-04, Opus 5.5, Blender instance 4 over TCP; AD 6.5, 6.8, then the owner's must-fix: board centred)

Validate PASS (554 checks, 0 failed, 28 waived: texture sets, LOD UV). Zfight on all 3 FBX: 0 visible (hidden pairs remain). Tris LOD0 15,610 / LOD1 5,924 / LOD2 2,111. Box colliders in `_ColNN_COL`. One atlas.

Ids: LOD0 130722240623800, LOD1 79190196494999, LOD2 77541869675498. ALB 71426657340889, NOR 86703344289683, RGH 124418267059037, MET 87820449258254 (maps Reviewing at upload).

Origin: baseplate top. **Water sits 1.5 below the origin**; quay top +0.4. Model forward (Roblox -Z) = open sea.

**Bay at scale 1 (multiply by the game's model scale):** 24 wide (Roblox x -12..12), 30 long (Roblox z -8..22, back edge at +22, the mouth end at -8). Clear above water: 15.83 over the middle 10 (tool tips), 13.15 across the full 24 (hook tip, x 6.6). Board and console stay behind the back edge (console front 0.05 short of it). The build asserts no collider in the bay and floods a walk from spawn to the workshop.

Board: centred at x 0 behind the bay's back edge, square to the sea, on legs. ATT_BoardScreen (0,11.08,25.365) look -Z, up +Y, screen 14.82 x 9.36, 7.9..17.3 above water. ATT_BoardButton (0,5.36,23.87) look -Z, on the back kerb. Walkers pass behind the board; tree_cone_a moved to x -18 for that.

Other attachments (`assets/fbx/M_Bld_UpgradeStation/*.attachments.json`): ATT_BoatLanding (0,-1.5,12) look -Z; ATT_WorkshopDoor (-21,.4,3.75) look +X; ATT_WorkbenchTop (-26,3.4,5.7); ATT_NavLight_Port/Stbd (∓17,23.5,-3.5); ATT_PlayerSpawn (14.3,.4,20.6), still beside the board's old spot; BayMouth, QuayLadderTop, ToolsHub, HoistHook, SparePile.

Game: SurfaceGui on a new Part at ATT_BoardScreen, Front face, 0.06 off the screen; button label too. Button prompt needs range: the nearest walkable quay is about 10 studs off at scale 1. A boat at ATT_BoatLanding looks seaward, so the player's default camera faces away from the board until turned. A high far camera loses the screen's top behind the beam. Neon on `_Glow*`. A light at ATT_WorkbenchTop helps the interior. Island ground must not fill the bay. AssetIds not regenerated. Not seen in Studio.
