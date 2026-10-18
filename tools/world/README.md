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

**Terrain pass T4.** `choose()` dithers with tileable blue noise through a Gumbel transform (stochastic soft-argmax:
comparable weights mix across 2-3 voxels, no clumps), a 10-stud value noise and softened log weights, and the land
slope / height drivers are noise-broken, so no smooth field thresholds into a band or a contour seam. New slots:
TurfWorn (`WORN` = Brick: trampled turf over earth, a 28-stud halo round wet hollows, gullies and banks between turf
and mud / earth), SandRipple (`RIPPLE` = Glacier: wind ripples on open dune faces and the upper dry beach), Wrack
(`WRACK` = Ice: the high-water strand line on the beach, and the top of the shingle at cove backs, which now band wet
sand -> shingle -> wrack -> worn turf; Harbour Cove too). Grass (Turf) is the main sward again (about 2x T3's
cells; Moor down by half) because only Grass gets `Terrain.Decoration`: now on, GrassLength 0.5, Grass MaterialColor
olive (`library.GRASS_COLOR`) with the Turf albedo pre-divided by it. Tiles down to 8-13 studs plus a gained scan
normal and a fine detail normal (`process.py` DETAIL); Moor tinted with lichen grey, dark heather and turf green.
Terracettes 0.5 studs over 6-36 deg, plus fine 8-16 stud roughness. Scatter: turf / marram budgets +50%
(PLANT_CAP 4400). Before / after: `assets/review/terrain/t4_contact.png` (T3 row, T4 row; `t4_shots.json`).

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

**Terrain pass T5.** Sand and cove macro variation: damp dark patches and pale dry (rippled) pockets on the open beach,
damp dune slacks (wet sand in dune hollows), damp seepage / dry pockets / blown sand at the cove backs and in Harbour
Cove; `process.py` SANDFX bakes damp / dry patches plus shell grit, shell fragments and pebble speckle into SandDry,
SandWet, SandRipple, Wrack and Shingle, and SANDTONE splits the tones (dry paler and warmer, ripple palest, wet darker
and cooler; T4 had all three at one brown). Road verges: a near-solid 2-4 stud gravel (Pavement) / soil lip at the
asphalt edge plus soil spill fingers. Turf heath tones: sparse heather, gorse and bracken blend layers in the Turf and
TurfOlive albedos. Scatter: turf clumps x a 28-stud patch noise (dense clumps, bare between), and two debris rock
stages (boulder scans at 0.07-0.35 scale, kept by `thin()`): `verge` stones 1.5-6 studs off the asphalt and `strand`
pebbles / cobbles on the wrack, shingle and sand at the cove backs (the beach-rescue sand strip stays clear).
LightingPresets Clear / Overcast: less haze (Overcast Density 0.31, Haze 1.3; Clear 0.24 / 0.45), slight saturation and
contrast (Overcast +0.02 / 0.14, Clear +0.06 / 0.12); Storm unchanged. DuneBank, CoveBack and RoadVerge re-framed at
1.7 m eye height (`t5_shots.json`), plus a HarbourOcean grade check. `assets/review/terrain/t5_contact.png` (T4 row, T5 row).

**Terrain pass T6.** Harbour hillside (`harbour_hill()`, 14-520 studs south of the town platform, applied after the
platform blend): `hill_relief()` adds Cornish hedges (turf-and-stone field banks 2-3 studs high, ~9 across, with
gateways) on a warped Voronoi field pattern (`field_cells()`, ~74-stud fields), 1-1.6 stud hummocks and granite
outcrops 2-6 studs proud; each field gets its own sward (green pasture, straw, olive, heather / gorse heath, bracken),
banks LeafyGrass with a little stone, no mud in the field floors. Scatter: gorse on the banks, heather / bracken in
their fields (Town budgets up, PLANT_CAP 4740, hillside counted as seen), and an `outcrop` rock stage (480 boulders /
ledge slabs on inland Rock). Outcrops everywhere larger and more numerous; Grass's share down in `turf()` so the
Decoration blades break into patches; GrassLength 0.3. Harbour Cove: fuller upper beach (ct^1.8) so the dry
foreground sits above the calm swell (it washed a dark sheet over the T5 foreground) and damp patches only near the
tide. `assets/review/terrain/t6_contact.png` (T5 row, T6 row; `t6_shots.json`).

**Terrain pass T7.** Grass Decoration A/B (GrassLength 0.1 vs off, RoadVerge + SlopeOutcrops, lower 40% of frame):
the 0.1 blades still covered 28% of the SlopeOutcrops foreground, raised saturation (104 vs 92) and lowered fine
detail (edge energy 4.7 vs 7.4), so Decoration is OFF (`studio_terrain.py` passes "false"); compensated by +400 turf
clumps (Town / CoastRoad / Inland; plants Low tier still 50% seen). Strand debris: a `strand` plant kind with four
tiny flat meshes (`art/source/veg/Strand`: shells, pebbles, wrack clump, driftwood; one 1024 atlas, 245-320 tris) in
16-piece clusters on the wrack / shingle / upper dry sand, the dune toe and Harbour Cove's upper beach (may use the
upper half of the beach-rescue strip: non-colliding). `process.py` RIPPLE: stronger wind ripples (~10 cm crests) on
SandDry, SandRipple, Wrack and faint ones on SandWet. Harbour hillside: heath fields and hedge banks no longer solid
Moor (the dark mossy foreground blotch), heath patchy over the field sward. `t7_contact.png` (T6 row, T7 row).
