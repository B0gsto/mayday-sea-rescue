# M_Veh_MooredBoat_01 result

Validate: **PASS**, 471 checks, 0 failed, 18 waived (tiled-trim LOD UV layout; LOD2 proxies for fragmented fittings/lettering). `check_textures.py` 30/30.

Triangles: LOD0 **10,230**, LOD1 **3,564**, LOD2 **912**, `_COL` 24. Size 1.59 x 4.33 x 1.06 m (3.72 m hull; 4.33 m LOA with the tilted outboard). Origin at the waterline, midships.

Set: **T_FishingBoat_Atlas** 2048, dry + wet, one shared set for `_01.._03`. Fourteen stable bands (antifoul, blue, sheer, inner, varnish, wood, metal, motor, dark, rope, water, weed, white, bailer) are defined in `BANDS`; `_02/_03` should reuse the name, 2048 size and band ranges.

Attachments: `ATT_Waterline`, `ATT_Moor_Bow`, `ATT_Moor_Stern`, `ATT_Outboard`, `ATT_Boarding_Port`, `ATT_Boarding_Stbd`.

Open issues: no reference `dims.md`; LOD/UV/bake wrappers in `build.py` clean decimation loose verts, proxy two fragmented LOD2 parts and force a flat NOR (the HP is a same-geometry copy used only to enable procedural trim colour/MR). Outboard included as the optional item.
