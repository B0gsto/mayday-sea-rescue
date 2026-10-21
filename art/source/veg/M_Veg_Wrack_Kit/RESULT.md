# M_Veg_Wrack_Kit (S2): intertidal wrack mats

Validate PASS, 127 checks, 0 failed, 4 self-waived (LOD UV layout x3; geometry at LOD2: collapse
decimation can orphan 4 to 8 empty vertices of ~1800, nothing renders).

**Tris.** LOD0 5448 (`Bladder_01` 1476, `Bladder_02` 1584, `Egg_01` 1464, `Decal_01` 924), LOD1
2724, LOD2 1362. Each mat 0.9 to 1.2 m across, 0.15 to 0.5 m tall, on its own rock-hugging shell
with modelled bladders / egg pods placed where the atlas paints them.

**Sets.** One: the shared atlas `FoliageMarine / Main` at 2048 (this kit owns the `M_Veg_Wrack`
cell, u 0.25..0.75, v 0.75..1.00). Maps and 4096 masters in `build/prod/M_Veg_Wrack_Kit/`.
Other cells are kept from the kelp kit's map when found, so a cell merge before upload is needed.

**Attachments.** `ATT_Base_Bladder_01`, `_Bladder_02`, `_Egg_01`, `_Decal_01`, each at its mat's
base on the display line: Blender X 0 / 6.15 / 12.30 / 18.45 studs (Roblox offset = -X, Y 0, Z 0).

**Open.** (1) `tools/blender/turntable.py`'s review material has no ALB alpha / blend mode, so the
sheet shows the frond cards opaque; Roblox `AlphaMode Transparency` cuts them as painted. (2)
Fronds are glossy-wet (roughness 0.30 to 0.45): check in Studio.
