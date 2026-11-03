# M_Prop_HubKit (2026-11-03, Opus 5.5, Blender MCP, 4 AD rounds)

Validate PASS. Tris LOD0 37,664, LOD1 12,195, LOD2 2,439. One flat-palette set (T_HubKit_Brick; NOR/RGH/MET = the Depot
palette bytes, SHARED_BYTES). AD: hub centre 5.5 -> 8.6 on sheets at r4; unseen in game.

Modules: L01_Atoll, L09_AtollDress, L02_Beacon, L08_BeaconLens (Neon in code), L10_BeaconGlass (Transparency 0.75),
L11_BeaconTop, L03_Wreck, L04_Buoy, L05_RockA, L06_RockB, L07_Raft.

Attachments: ATT_Atoll, ATT_Beacon, ATT_Wreck, ATT_Buoy, ATT_RockA, ATT_RockB, ATT_Raft (ground origins along +x),
ATT_Light (lens centre).

Ids: LOD0 88613009854216, LOD1 112011585002545, LOD2 116835442105145; ALB 76696982722535 (Approved).

Layout: build.py LAYOUT (22 rows, radius <= 236 of the ring centre), copied into src/server/World/HubLandmark.luau, which
adds invisible colliders for the atoll tiers, ramp and beacon only. Rocks, wreck, buoys and rafts have none.
