# M_Rock_IslandProxy_Kit (P1)

Validate **PASS**: 74 checks, 0 failed, 3 waived. Source: `build.py` + `proxygeo.py`.

Pieces, from the two land components in `terrain_height.i16` (Terrain mapping, 1 stud sink, skirt to -14):

| Piece | LOD0 | LOD1 | LOD2 |
|---|---|---|---|
| M_Rock_IslandProxy_GreatGale | 2,999 | 1,198 | 448 |
| M_Rock_IslandProxy_SkerryIsle | 2,350 | 939 | 352 |
| **Kit** | **5,349** | **2,137** | **800** |

One baked colour set `T_IslandProxy_Terrain` (2048 ALB/NOR/RGH/MET), colours sampled from the real Terrain MaterialVariant albedos through `terrain_material.u8`; AO in gullies. `check_textures.py` passes 17/17. No attachments.

Kit is authored in world space (Blender `(-world x, world z, height)`): place the Model at the map origin. `M_Rock_IslandProxy_Kit.placements.json` lists each piece's world box and centre.

Waived: texel density (a 5 km island cannot meet 05 5.3 at 2048), `_COL` (far proxy, Terrain owns collision). Open: Great Gale is clipped by the bake window, so its skirt forms a wall at the map edges; LOD2 coastlines are very coarse, as intended for far range.
