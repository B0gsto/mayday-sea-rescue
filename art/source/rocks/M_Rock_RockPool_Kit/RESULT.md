# M_Rock_RockPool_Kit (K1)

Four low intertidal granite outcrops with a rock pool each (docs/12 2.6, WorldConfig `HavenSandsRockPools`): each
variant is a polar jointed mass (ridge ring with knuckle peaks and a spillway, the pool bowl, a wave-cut outer slope,
granite jointing displaced and sea-smoothed in the tide band), a flat water sheet whose boundary follows the
displaced shoreline, a closed `_COL` and an `ATT_Pool_NN` at the water surface centre. One Granite atlas (4096, the
row's "1 atlas"): the K1 CC0 scan granite baked through the scans' own UVs (`pooltex.py`), then the intertidal
zonation (`compose_maps.py`): dark wet lower band, barnacle and limpet crust, green weed at the pool rim, pink
coralline in the pool and at the waterline, black Verrucaria, lichen on the high rock.

- **Validate: PASS** (267 checks, 0 failed, 4 waived: LOD2 UV layout after collapse decimation).
- **Tris:** LOD0 14,772 of 15,000 (3,399 / 3,599 / 3,799 / 3,399 + water 576); LOD1 5,900, LOD2 2,206 (total
  ceilings, rock class); `_COL` 420 each, closed.
- **Set** T_Pool_Granite 4096, ALB / NOR / RGH / MET + _Wet; 63 to 113 px/stud rock, 70 to 94 water.
- **Size** 24 x 21 x 4.05 studs (8 x 7 x 1.35 m) as a 2 x 2 group; each outcrop 2.6 to 4.2 m, pools 1.0 to 2.0 m
  wide and 0.17 to 0.31 m deep. **Attachments** `ATT_Pool_01` to `_04` at the four water surfaces.
- Water sheets are `M_Rock_RockPool_Water_NN` (the repo name rule wants the number last, not `<variant>_Water`);
  set `CanCollide` / `CanQuery` off on them in Studio.
- Open: Studio preset cells pending; not uploaded.
