# M_Prop_CommonsKit: result (2026-11-01)

One Lego Blender kit for the idle crew's commons (`shared/Hangout.luau`, `DockPieces.hangout`) and the six sold
decorations (`DockPieces.decoration`). Spec: `SPEC.md`. Rebuild: `build.py` (with `lego.py`, `palette.py`,
`maketex.py`; `preview.py` renders the review sheets; `mcp_run.py` runs it through the Blender MCP). Source:
`M_Prop_CommonsKit.blend`. One flat palette material, texture set `T_CommonsKit_Brick` (NOR / RGH / MET are the Depot
palette's bytes, SHARED_BYTES; only the ALB is new).

## Modules (one mesh each, origin = the code frame it replaces)

| Mesh | Code frame / slot |
|---|---|
| H01_Canteen | Hangout `Canteen` (ATT_Canteen) |
| H02_Campfire, H02_CampfireGlow | `Campfire` |
| H04_ParkBench | `BenchA` and `BenchB` (slot Bench, placed twice) |
| H05_BenchPatio, H05_BenchPatioGlow | `BenchA` frame (one patio under both benches) |
| H06_Hammock | `Hammock` |
| H07_IceCart | `Cart` |
| H08_ChatEast | `ChatEast` |
| H09_ChatWest, H09_ChatWestGlow | `ChatWest` |
| D01_FlowerBed | decor `FlowerBed` |
| D02_PicnicTable | `PicnicTable` |
| D03_LampRow, D03_LampRowGlow | `LampRow` |
| D04_FlagPole, D04_FlagCloth, D04_FlagEmblem | `FlagPole` (the cloth becomes the recoloured "Flag") |
| D05_Statue | `Statue` |
| D06_Fountain, D06_FountainWater | `Fountain` |
| Col01_COL | token (the kit never collides) |

LOD1 / LOD2 carry the same 21 meshes with `_LOD1` / `_LOD2` suffixes (checked by deserializing the downloaded rbxm).

## ATT_* (43, `assets/fbx/M_Prop_CommonsKit/M_Prop_CommonsKit.attachments.json`, roblox_from_origin)

- 13 module roots along +X: ATT_Canteen (0), Campfire (18), Bench (31), Hammock (51), Cart (59), ChatEast (67),
  ChatWest (74), FlowerBed (83), PicnicTable (93), LampRow (103), FlagPole (113), Statue (122), Fountain (131).
- Crew spots: Canteen_Eat FL / FR / BL / BR, Campfire_Sit FL / FR / BL / BR, Campfire_Warm L / R, Bench_Sit L / R,
  Hammock_Lie, Cart_Cone L / R, ChatEast_01..03, ChatWest_L / R.
- Light / FX points: Campfire_Flame, Campfire_Lamp, BenchPatio_Lamp, ChatWest_Lamp, LampRow_Lamp_01..03,
  FlagPole_Cloth, FlagPole_Top, Fountain_Jet.
- Every ATT unchanged since r1. AssetIds.Attachments.M_Prop_CommonsKit matches the round-4 JSON exactly (43 / 43,
  same order, same values).

## Numbers

- Tris: LOD0 24,045, LOD1 14,919, LOD2 2,852 (budget class hero_building waiver, as SeaPlateKit).
- validate PASS. zfight_check: 0 visible coplanar overlaps on LOD0, LOD1, LOD2.

## Final (2026-11-01): AD, upload, wiring

AD medians (three Opus ADs per round): r1 8.3, r2 8.8, r3 8.9, r4 9.0 (judges 9.0 / 8.9 / 9.0). r4 is BELOW the 9.1
perfect-pass bar; r4 ships. r4 module medians: Canteen 9.1, Campfire 8.9, Bench 9.0, Hammock 8.5, Cart 8.8, ChatEast
8.8, ChatWest 8.8, FlowerBed 9.1, PicnicTable 9.1, LampRow 9.1, FlagPole 9.0, Statue 9.2, Fountain 9.1.

For a later round (r4 AD):
- Hammock (8.5): still reads as a lounger: two matching tan-capped 2x2 posts standing clear at each end, sling sag
  ~1 brick below the ties past head and feet, rope lines.
- Stand-spot occlusion (Cart, ChatEast, ChatWest): the fixed ATTs put minifigs between the camera and the prop; move
  the stand spots ~0.5-1 stud (Hangout.SPOTS, with tests) or rotate the pairs so the table reads between them; lean
  rail behind ChatWest; second camera-side cart wheel.
- Campfire: chunkier 2-stud logs with end caps, stone ring +1 plate in front of the logs, stacked trans flame pieces.
- Bench: armrest end blocks, slat gap in the backrest. FlagPole: 2-stud pole, flag 1.3-1.4x.

Sheets (main checkout): build/status/2026-11-01/perfect/M_Prop_CommonsKit/r1/ .. r4/ (r<N>_sheet.png, r<N>_AD.md,
per-module g_<Module>.png game-camera and t_<Module>.png close shots, overview.png).

Uploaded (manifest, assets/models/M_Prop_CommonsKit{,_LOD1,_LOD2}.rbxm): LOD0 75671637336264, LOD1 90912448153218,
LOD2 118958986993115; T_CommonsKit_Brick_ALB 98917262750062 (moderation Reviewing at upload). NOR / RGH / MET reuse
T_Depot_Brick 134063939343985 / 77394710200809 / 82741558542658. AssetIds Models + Attachments and the Appearances
palette entry added by hand (gen_asset_ids in a worktree re-points other assets).

Wiring: DepotArtService preloads the kit. `DockPieces.commonsKit(m, place)` clones each { mesh, slot, frame } at
frame * CFrame.new(-ATT_<slot>) into a "CommonsKit" model (anchored, no collide / query / touch), all or nothing.
`hangout` dresses the Canteen, Campfire, both benches + patio, Hammock, Cart, ChatEast, ChatWest; `decoration` dresses
each sold decor from its mesh list. Glow meshes go Neon (WARM), the fountain water Glass (as the code Water), the flag
cloth is renamed "Flag" (Fabric) so DockService still paints the owner's colour. When the kit is placed, every code Part
of that prop stays as collider / seat / anchor but goes invisible (Transparency 1, no shadow, stud textures removed);
the hidden code bulbs keep their NightLamp lights.
Fallback: no asset id, a failed load or a missing mesh (and Lune tests) build the code Parts exactly as before.
check.sh: ALL CHECKS PASSED (825 tests).

In-game: not yet seen (no Studio run, not published).
