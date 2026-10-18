# R1a roads: how the road ribbon should use these materials (for I1)

R1a ships surfaces and furniture only. No game code or map file was changed. This note covers how the roads are built
today and how a later integration batch should apply the new sets.

## How roads are built today

- `tools/world/layout.py` `ROADS` holds the polylines (studs, +X east, -Z north), with `surface` and `width`:
  Harbour Road 18 studs (6 m, Asphalt), Coast Road 18 (Asphalt), Chapel Hill 12 (Asphalt), High Road 15 (Asphalt),
  Haven Head track 10 (Ground), Haven Sands slipway 12 (Concrete). There are two car parks (`CAR_PARKS`).
- `tools/world/gen_terrain.py` `pave()` flattens the terrain along each Catmull-Rom smoothed polyline and paints the
  terrain material (Asphalt / Ground / Concrete). `materials()` dithers gravel and worn earth into the verges.
  B02's MaterialService overrides make terrain Asphalt use `asphalt_02`, Pavement use "Gravel" and Cobblestone use "Cobbles".
- `src/shared/Config/WorldConfig.luau` (generated) exports `Roads` with Y from the terrain bake. `RoadHeading`,
  `LandVehicleService` and the map image read it.
- There is **no road mesh yet**. `map/Build.luau` builds no roads. Kerbs, markings and street furniture do not exist in
  the place.

## What R1a provides

All of these are in `assets/textures/M_Road_Ribbon/`, ship 1024, with 2048 masters in `art/source/roads/M_Road_Ribbon/textures/`.
After `tools/gen_asset_ids.py` they appear as `AssetIds.Textures.M_Road_Ribbon.<Set>` and as SurfaceAppearances in
`script.Appearances.M_Road_Ribbon.<Set>.Dry|Wet` (AssetLoader).

| Set | Kind | UV convention |
|---|---|---|
| `Asphalt` | strip: worn asphalt_04 with clean_asphalt patches (a trench and two boxes), tar crack sealing, a centre joint overband, wheel-track polish, oil drips, and kerb-line silt and grime. `_Wet` adds gutter puddles and glossy tar | U along the road, **8 m per 1.0** (tiles). V across the carriageway, 0 = left kerb line, 1 = right. The grime is in the outer 0.9 m of each edge |
| `Cobbles` | strip: Harbour Road granite setts (cobblestone_04) with sand and moss in the joints, polished wheel tracks and gutter grime | as Asphalt (8 m, 6 m wide) |
| `Gravel` | strip: Haven Head track (gravel_road) with two compacted ruts 1.6 m apart (puddles when wet), a loose centre with grass tufts and grassy verges | U 8 m; V across 3.33 m |
| `Kerb` | strip: granite kerb, two 0.9 m stones per 1.0 U (1.8 m), with joints, road dirt and tyre scuffs on the face, a worn arris and lichen on the top | U along, 1.8 m. V across the unfolded profile: 0 to 0.3125 road face (0.125 m), to 0.3625 arris, to 0.7375 top (0.15 m), to 1.0 back face (0.105 m) |
| `AsphaltTile`, `CobblesTile`, `GravelTile`, `KerbTile` | seamless tiles for MaterialVariants and Parts | 4 m, 2 m, 2 m, 1 m per tile |
| `Markings` | RGBA decal atlas, AlphaMode **Transparency** (`gen_asset_ids.py` `ALPHA_TRANSPARENCY_SETS` now includes it) | rects in `assets/materials/roads_variants.json` `markings.rects` (u0 v0 u1 v1, v up), at 256 px/m (cat's eyes 512) |

The marking cells are: `CentreDash` (one 4 m by 100 mm dash in a 4.5 by 0.5 m cell; Diagram 1008, verify gap 8 m),
`EdgeLine` (100 mm continuous, 4 m period), `DoubleYellow` (2 by 100 mm lines with a 75 mm gap, 4 m period),
`GiveWayLines` (Diagram 1003: two rows of 600 mm marks with 300 mm gaps, 200 mm wide; 3.6 m tile across the lane),
`GiveWayTriangle` (Diagram 1023: 3.75 by 1.5 m outline), `CatsEyeWhite` and `CatsEyeRed` (0.25 m cells, top view).
The yellow and red cells are signal colours (`art/source/roads/M_Road_Ribbon/T_Road_Markings_signal.png`). Every marking
size is a UK Traffic Signs Manual value from memory: **verify it before shipping.**

## Recommended ribbon build

Build the ribbon **offline in Blender**, not at run time. Map ids can't be written from game scripts, and an
EditableMesh ribbon would also need the SurfaceAppearance cloned in. Use a generator under
`art/source/roads/M_Road_Ribbon/` that reads `tools/world/layout.py` `ROADS` and the baked heights
(`map/generated/terrain_height.i16`, the same Catmull-Rom curve as `pave()`). It should export chunk MeshParts of about
10 to 12 m with LOD0/1/2. Each chunk's ribbon gets the `Asphalt` (or `Cobbles` / `Gravel`) SurfaceAppearance through
`AssetLoader`.

1. **Carriageway**: one quad row across, about 200 tris per 10 m (a vertex every 1 to 2 m along, more on bends).
   Set U = arc length / 8 m, running continuously along the whole road so the pattern doesn't restart at chunk seams.
   For V, keep the edge grime 0.9 m wide on every road width: put verts at 0.9 m from each edge and map them to
   V = 0.15 and 0.85, so only the middle stretches. Harbour Road and Coast Road are 6 m (exact). Chapel Hill is 4 m
   and High Road is 5 m.
2. **Cobbles**: use `Cobbles` on Harbour Road where it runs along the quay (x from -300 to 180, in front of the
   station, the Chandlery and the slipway head). Use `Asphalt` elsewhere, with a 2 m cross-fade quad pair at the change.
3. **Kerbs**: sweep the unfolded profile (face 0.125 m up, 20 mm arris, 0.15 m top, back face down to the footway) along
   both edges of town roads, about 8 tris per 0.9 m stone. U = arc length / 1.8 m. Drop kerbs at the slipway and
   station apron (ramp the profile to 25 mm). Rural roads (High Road beyond the town, Haven Head track) have no kerbs.
   Use the verge MaterialVariants there.
4. **Markings**: build them as separate thin ribbons 5 mm (0.015 studs) above the carriageway, following the same
   curve, with quads mapped to the atlas rects:
   - centre dashes: one quad per dash, 4 m mark, gap per diagram;
   - edge lines on the Coast Road and High Road: 4 m quads chained;
   - double yellows on Harbour Road outside the station and Chandlery;
   - give-way at Chapel Hill / Harbour Road: the lines across the minor road plus the triangle about 15 m back;
   - cat's eyes every 18 m on the Coast Road and High Road centre lines (white), and red on the left edge on the
     Haven Head approach.

   Use one MeshPart per chunk for its markings, with the `Markings` SurfaceAppearance (Transparency).
   `CastShadow = false`, `CanCollide = false`, `CanQuery = false`. Check for z-fighting at 500 studs and on the phone
   frame. If it shows, raise to 0.03 studs.
5. **Wet**: every set has `_Wet`. AssetLoader tags the chunks `HasWetVariant` and `AssetLoader.setWet` swaps them with
   the weather, like the other wet assets.
6. **Terrain and MaterialVariants**: the ribbon sits about 0.05 studs above the painted terrain, and terrain paint
   stays under it as the far fallback. For verges, car parks and lay-bys, add the four variants in
   `assets/materials/roads_variants.json` `variants`. For each: name, `BaseMaterial`, `StudsPerTile`, pattern, and
   ColorMap / NormalMap / RoughnessMap / MetalnessMap from `AssetIds.Textures.M_Road_Ribbon.<Set>` (dry), plus a
   `<Name>_Wet` twin from the `_Wet` maps. Add them to `src/materials/MaterialService.model.json` by extending
   `art/source/materials/wire.py`, which is B02's file. R1a did not write it. Whether `RoadAsphaltWorn` should replace
   B02's `Asphalt` terrain override is an art-director call.

## Street furniture (shared `Street` atlas, `T_Street_Main_*`)

`M_Road_StreetLamp`, `M_Road_Bench`, `M_Road_Bin` and `M_Road_Bollard` are uploaded as Models (LOD0/1/2) with `_COL`.
Each one's `assets/textures/<Asset>/` holds an identical copy of the atlas, which is one upload by content hash.
Because the copies are byte-identical, `gen_asset_ids.py` lists the atlas only once, under `Textures.M_Road_StreetLamp.Main` (and `Appearances.M_Road_StreetLamp/Main`). The three others are listed in `AssetLoader.SHARED_SETS` (src/server/Assets/AssetLoader.luau: `M_Road_Bench`, `M_Road_Bin`, `M_Road_Bollard` -> `"M_Road_StreetLamp"`, R1a-fix), so they resolve to that SurfaceAppearance. Place them with `AssetLoader.cloneStatic(asset, lod, true)`. The origin is on the ground at the post or centre.
Attachments (`assets/fbx/<Asset>/<Asset>.attachments.json`):

- `M_Road_StreetLamp`: `ATT_Light` sits under the LED lens and points down. Use a warm white SpotLight there, about
  3000 K, Angle 110, Range 40 studs, Brightness 2 to 3, Shadows on for the Harbour Road lamps only. On the `Lens`
  MeshPart (`M_Road_StreetLamp_Lens`), set Material Neon with Color (255, 214, 170) at night and back to the
  SurfaceAppearance by day, as the Chandlery Glow part does. The bracket points +X in Blender (-X in Roblox), so turn
  the lamp so the head reaches over the carriageway. `ATT_Base` marks the ground point.
- `M_Road_Bench`: `ATT_Seat` is the seat centre for an NPC sit pose. Then `ATT_Base`.
- `M_Road_Bin`: `ATT_Opening` is the open top, for litter interactions. Then `ATT_Base`.
- `M_Road_Bollard`: `ATT_Base`.

Spacing: lamps about 30 m apart on alternate sides of Harbour Road and Chapel Hill. Bollards at 1.5 m centres along the
quay edge and the station apron. Benches and bins face the harbour on the quay.
