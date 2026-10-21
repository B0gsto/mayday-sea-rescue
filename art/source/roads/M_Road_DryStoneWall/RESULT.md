# M_Road_DryStoneWall

**Validate: PASS (72 checks, 0 failed, 7 waived).** One 5 m modular Cornish dry-stone wall section for the Haven Head
road. Origin on the ground at the -X end (x runs along Blender +X = Roblox -X); the piece tiles end to end.

- **Tris:** LOD0 4,878 (docs/12 row: 1,000 to 6,000 per 5 m; spec ceiling 6,000), LOD1 2,438, LOD2 1,218, `_COL` 12.
  Size 5.03 x 0.62 x 1.20 m, exact: 1.20 m high including 0.30 m of coping, 0.62 m thick at the base, 0.46 m at the
  bed (6 courses of rubble over two skins, through stones every 1.65 m, hearting between them).
- **Sets:** `T_DryStoneWall_Granite_{ALB,NOR,RGH,MET}` 1024 + `_Wet`, one trim set: six cells (wall / cope / lichen /
  moss / joint / grass) over the `granite_tile` scan (Poly Haven CC0), grout lines patched out and flat-fielded, graded
  to the 05 granite `#8A8781`, with mud splash, rain wash, salt bloom, lichen colonies, moss and grass.
- **Attachments:** `ATT_Snap_Start` (x 0, out along -X), `ATT_Snap_End` (x 5 m, out along +X), `ATT_Base`,
  `ATT_Vault` (the wall's top centre, for a step-over). `M_Road_DryStoneWall_EndCap_LOD0` is the terminal cap.
- **Waived:** LOD UV area / UV faces / geometry - collapse decimation of ~180 separate stones removes the stones it
  drops (bounds stay 0.000-0.007).
- **Open:** shipping copies sit in `build/prod` (task's arms-length rule) - run `python3 walltex.py` with no `--out`
  to write `assets/textures/M_Road_DryStoneWall/`. `variants_row.json` waits on B02's `wire.py`. Stone and coping
  sizes are the docs row's "verify" figures.
