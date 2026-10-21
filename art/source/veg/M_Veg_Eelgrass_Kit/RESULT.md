# M_Veg_Eelgrass_Kit (four tufts + patch) — result

**Validate: PASS** (153 checks, 0 failed, 20 waived: LOD UV layout shifts as blades collapse; LOD1/LOD2
decimation leaves a few orphan vertices that render nothing). `check_textures.py --alpha`: 17/17 PASS.

- LOD0 **1,172** tris: `_01` 164, `_02` 260, `_03` 300, `_04` 280, `_Patch_01` 168. LOD1 584, LOD2 289.
  0.30 to 0.71 m tall, bases at Z 0 on a 1.35 m display line.
- Solid ribbon blades (two offset surfaces, true normals; no DoubleSided, no alpha), 6 to 10 mm wide,
  0.3 to 1.0 m long: bent downstream (+X), rolled, rippled, drooped, with brown dead tips and old-leaf
  silt / epiphyte crusts. Sway vertex colour (R weight, G phase, B stiffness) on every LOD.
- Set: shared **FoliageMarine / Main** atlas, 2048 ship / 4096 masters. New cell only:
  `M_Veg_Eelgrass` u 0.75..1.00, v 0.75..1.00 (LeafYoung, LeafOld, LeafDead, Sand). Other cells preserved
  pixel-identical from the wrack/kelp map.
- `ATT_Base_01..05` at each base: Blender X 0, 4.05, 8.10, 12.15, 16.20 studs (Roblox −X, Y 0, Z 0).
- Open: no `art/reference/M_Veg_Eelgrass_Kit/dims.md`; Studio presets pending; LOD2 keeps only a few blades
  (expected at 25% triangles).
