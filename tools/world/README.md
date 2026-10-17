# World terrain pipeline

Bakes the Gale Isles terrain (docs/10-world-and-map.md) and merges it into `build/MaydaySeaRescue.rbxl`.

| Step | Command | Output |
|---|---|---|
| 1. Bake (deterministic, seeded) | `python3 tools/world/gen_terrain.py [--preview build/world/terrain_preview.png]` | `map/generated/terrain.json`, `terrain_height.i16` (int16 LE, Y x 8), `terrain_material.u8`; `src/shared/Config/WorldConfig.luau` (generated, then run `stylua` on it) |
| 2. Write in Studio | `python3 tools/world/studio_terrain.py` | `map/terrain/Terrain.rbxm` |
| 3. Build | `~/RobloxProjects/tools/build.sh .` | `build/MaydaySeaRescue.rbxl` with the Terrain |

**Layout.** `tools/world/layout.py` is the only hand-edited input: island polygons with a coast kind and height per vertex
(cliff, rocky, beach, harbour, mud) covering the whole of Great Gale and Skerry Isle, the harbour basin (fitted to the
greybox breakwater, mouth at z = 368), the town platform at Y = 4, Haven Sands (beach, dunes, the Bar), reefs, kelp beds,
Old Ned's gully, roads, car parks, points and POIs. Only the MVP square (x, z in +-2,560, 4-stud cells, 1,281 x 1,281)
is baked; widen `HALF_EXTENT` to bake more of the island.

**Writing.** Lune cannot write voxels (verified: the `Terrain` class exists in Lune but has no voxel API).
`studio_terrain.py` (1) stages the bake as base64 StringValues in a copy of the build (`make_work_place.luau`), so no data
goes through `execute_luau`; (2) opens it as `TestBench-MaydayTerrain` via `tools/studio-open.py`; (3) under the
machine-wide Studio lock runs `write_terrain.luau`: `WriteVoxels` per 64 x 64 column tile as a shell (40 studs under
land, 20 under the seabed, extended to the lowest neighbour so cliffs have no holes), the Needle's Eye arch
(`FillBall`), material tints (`SetMaterialColor`), then `SerializationService:SerializeInstancesAsync({Terrain})`,
returned in 72 KB base64 slices (execute_luau output is cut at about 100,000 characters); (4) closes the window
without saving. `--export-only` re-exports from an already open `TestBench-MaydayTerrain` window (for example a build).
No Terrain water is written; sea level is Y = 0 and the mesh ocean covers the seabed.

**Merge (how build.sh gets the Terrain).** `map/Build.luau` calls `ctx.readModel("map/terrain/Terrain.rbxm")` and
parents that `Terrain` instance into Workspace (replacing any existing one). Lune carries its `SmoothGrid`
(about 5 MB), `PhysicsGrid` and `MaterialColors` through unchanged, and Studio loads the result as normal Terrain
(checked: the built place opens with the voxels). No base place file is needed. If `Terrain.rbxm` is missing, Build
falls back to the old part-built ocean floor and land (Workspace attribute `WorldTerrain` says which).

**Materials.** `materials()` in gen_terrain.py blends, per 4-stud voxel cell, by slope, height, curvature (hollows:
box-blurred height minus height), distance to the sea and to the road edge: weights per material, then a dithered
pick (white noise + fine value noise), so every area mixes 2-3 materials and Roblox's voxel blending gives soft
transitions. Land: Grass (Turf) and LeafyGrass (Moor: straw grass / heath, more on cliff tops and the Beacon), worn
Ground patches, Mud in hollows, Rock by slope plus outcrops, Basalt streaks on low steep faces; rocky shores Basalt /
Rock / Slate (kelp rock) at the tide line; beaches Sandstone (wet sand) + Slate at the tide line, Sand, a Limestone
(shell gravel / shingle) berm at the dune toe, marram (Grass + LeafyGrass) taking over the dunes; Pavement (gravel)
and Ground along the road and track verges. Seabed (under the mesh ocean): Salt (SeabedSand), Limestone, Slate, Rock,
Mud (harbour bed). Asphalt, Concrete (slipway), Cobblestone (quayside) under the road meshes. The Terrain writer's
`colors` mode also sets `Terrain.Decoration` (wind-animated grass on Grass; colour = the Grass MaterialColor) and
`GrassLength`. Look-dev capture: `tools/world/lookdev_capture.sh <round>` (play mode, `tools/world/lookdev-shots.json`).

**Open.** The shore bake for `Waves.luau` (doc 10 section 6.4), MaterialVariants, the doc 10 harbour re-lay (mouth
at about 900 studs; gameplay code and tests still use z = 368), `GameConfig.MapRadius` 2,000 vs WorldConfig's 2,500.
