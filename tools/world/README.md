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

**Materials.** `materials()` in gen_terrain.py weighs every material per 4-stud voxel cell by slope (12-stud
smoothed), height, curvature (hollows: box-blurred height minus height), distance to the sea and to the road edge,
then `choose()` takes a soft argmax: log weight + a domain-warped multi-octave patch noise per material + a little
per-cell jitter. Where weights compete the noise decides, so materials form coherent organic patches (10-200 studs)
with 1-2 cell feathered borders that Roblox's voxel blending softens (terrain pass T2 replaced the old per-cell
white-noise dither, which speckled 2-3 materials into blotches: 36 % of land neighbours differed, now about 10 %).
Coastal layering: Sandstone (wet sand) -> Sand -> a CrackedLava-slot Shingle strand line at the dune toe -> marram dunes
(Grass with sand blowouts, LeafyGrass heath on the back dunes) -> Grass (Turf) with LeafyGrass (Moor: heather /
gorse) patches, more on cliff tops, windward swathes and the Beacon; Ground (Earth) in erosion gullies and on banks;
Mud in wet hollows and on the harbour foreshore (with Shingle); Rock on every slope over about 37 deg (no grass on
cliff faces), outcrops and crags; rocky shores Basalt / Rock / Slate (kelp rock) with Shingle at the cove backs
(also the back of Harbour Cove); Pavement (gravel) and Ground along the verges, Rock in road cuttings. Seabed
(under the mesh ocean): Salt (SeabedSand), Limestone, Slate, Rock, Mud (harbour bed). Asphalt, Concrete (slipway),
Cobblestone (quayside) under the road meshes. **Micro-relief** (`micro_relief()`, land only): hummocks (up to about
1.5 studs), sheep-track terracettes along the contours of 8-30 deg slopes, erosion gullies (2 studs deep) down the
fall line of steeper banks; masked off beaches, dunes, the waterline, the town platform / harbour and 25-45 studs
round points and POIs; roads and car parks are flattened over it. Tiles: `STUDS_PER_TILE` in
art/source/materials/library.py (Turf 18, Moor 20, Granite 22 studs ...; real-scale 6-8 stud tiles showed a grid
at range); run `art/source/materials/wire.py` after changing it (no re-upload). The Terrain writer's `colors` mode
sets the MaterialColors (white, except an olive LeafyGrass multiplier that matches Moor's luma to Turf's) and
`Terrain.Decoration` / `GrassLength`. Look-dev capture: `tools/world/lookdev_capture.sh <round>` (play mode, `tools/world/lookdev-shots.json`).

**Terrain pass T3.** Turf is split into three macro-patch variants: Turf (olive, Grass slot), TurfStraw (straw /
dead grass, `STRAW` = the Snow slot) and TurfOlive (dark lush sward in hollows, `OLIVE` = the WoodPlanks slot), driven
by 110-150 stud domain-warped fields (straw on exposed, convex, cliff-top ground; olive in hollows). `choose()` adds a
6-stud value-noise dither and stronger per-cell jitter, so every border with comparable weights dithers at voxel scale
over a wide fringe (blown sand 80 studs onto the back-dune turf, gravel grit up to 7 studs and worn ground 16 studs off
the road edge, a patchy shingle strand instead of a continuous dark berm). Relief: 5-15 stud hummocks in patchy
fields, granite outcrops 2-6 studs proud on ridges and knolls (forced Rock), and a sea-cut dune front (a 3-5 stud
scarp at the dune toe plus a second step 15-20 studs behind). `flat_keep()` masks all T3 relief off roads (+16 studs),
car parks (+12) and points / POIs (30), so road profiles, pads and the station keep their heights. Materials use a
20-stud slope so hummocks do not trip the rock threshold. Albedos re-graded in `process.py` MACRO (target medians +
tileable blend layers): Turf, TurfStraw, TurfOlive, Moor (the olive LeafyGrass MaterialColor is now white), Earth,
Mud (peat), KelpRock (slate), Shingle. Before / after: `assets/review/terrain/t3_contact.png` (`t3_shots.json`).

**Open.** The shore bake for `Waves.luau` (doc 10 section 6.4), MaterialVariants, the doc 10 harbour re-lay (mouth
at about 900 studs; gameplay code and tests still use z = 368), `GameConfig.MapRadius` 2,000 vs WorldConfig's 2,500.

**Props (rocks + vegetation).** `python3 tools/world/scatter_props.py [--seed N] [--preview build/world/props_preview.png]`
reads the bake + layout.py and writes `map/generated/props.json` (compact, deterministic; seed defaults to
`layout.SEED`): `assets` (names), `rocks` and `plants` as `[a, x, y, z, yaw, tx, tz, s, b]` rows (a = 1-based asset
index; y = bilinear terrain height; the consumer does `CFrame.new(x,y,z) * CFrame.Angles(rad(tx), 0, rad(tz)) *
CFrame.Angles(0, rad(yaw), 0)`, scales by s and sinks b of the scaled height; `b = -1` = waterline mode: the asset's
`ATT_Waterline` goes to y = 0 +- 0.6 tide jitter). Rocks (K1, about 800): waterline ledges + Boulder_04/05 on rocky and
cliff shores, boulders at cliff feet and on the shallow reef tops, Cliff chunks on slopes over 40 deg, weighted
Poisson-disk by footprint. Plants (G1, cap 3,500 in the MVP radius): clustered (centres + gaussian offsets) by
material, slope, hollows and coast distance, per-kind per-region budgets in `PLANT_BUDGET`. Excluded: roads + 8 studs
verge, slipways (12), car parks (10), harbour basin + quay + arms, the town platform (turf allowed on its 20-stud rim),
station / Chandlery box, Harbour Cove, the beach sand strip (marram only on the dunes behind it), points (30), POIs
(25), paved materials, and anything under water except reef boulders and the waterline pieces.
