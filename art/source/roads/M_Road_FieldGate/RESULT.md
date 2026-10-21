# M_Road_FieldGate

**Validate: PASS (77 checks, 0 failed, 0 waived); check_textures PASS (27, 0 failed).** A Cornish five-bar timber
field gate for the Haven Head road: hanging and slamming post, the swinging five-bar leaf, two galvanised
hook-and-band hinges, a latch bar and forged keeper, a nine-link holding-open chain. Origin on the ground at the
hanging post's centre (X along Blender +X, Roblox -X).

- **Tris:** LOD0 4,172 (docs/12 row: 1,000 to 6,000 per 5 m; spec ceiling 6,000), LOD1 2,086, LOD2 1,042, `_COL` 36
  (posts, plus the leaf's own `M_Road_FieldGate_Leaf_COL` for swinging). Size 3.97 x 0.376 x 1.55 m:
  leaf 3.60 m heel to head stile x 1.20 m, five 100 x 40 mm bars at 0.235 m centres,
  hinges at 0.21 / 1.15 m, mud and moss at the post feet.
- **Sets:** `T_FieldGate_Timber_{ALB,NOR,RGH,MET}` 1024 + `_Wet`; `layout.py` timber (U 1.8 m along the piece, V =
  height 0 to 1.6 m), galv fittings, oiled fixings.
- **Attachments:** `ATT_Hinge` (the leaf's pivot: x 0.065, y -0.145, z 0.68, swing about its vertical), `ATT_Base`,
  `ATT_Latch`, `ATT_Chain`.
- **Open:** maps ship in `build/prod` (arms-length rule); `gatetex.py` with no `--out` writes
  `assets/textures/M_Road_FieldGate/`. The MaterialVariant row waits on B02's `wire.py`.
