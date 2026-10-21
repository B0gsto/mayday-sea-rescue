# M_Road_CrashBarrier

**Validate: PASS (64 checks, 0 failed, 0 waived).** One 4 m modular UK W-beam section for the Haven Head road. Origin on
the ground at the -X end post (x runs along Blender +X, Roblox -X); the piece tiles end to end.

- **Tris:** LOD0 4,028 (docs/12 row: 1,000 to 6,000 per 5 m; spec ceiling 4,800), LOD1 2,014, LOD2 1,006, `_COL` 36 (3
  closed boxes). Size 4.045 x 0.152 x 0.720 m: 312 mm W-beam, crests at 0.55 m, top 0.71 m; 90 x 76 mm I-section posts on
  2 m centres with the panel joint at a post; the +X end is the lapped panel (10 mm step).
- **Sets:** `T_CrashBarrier_Galv_{ALB,NOR,RGH,MET}` 1024 + `_Wet` (one trim set, roads style): galvanised sheet with
  road splash, dried salt, rust weeping from the fastener lines and the beam's top edge, scuffed bare steel.
  `layout.py`: galv (U tiles every 1.9 m, V = height above ground 0 to 1.15 m), reflector plate, dull fixing cell.
- **Attachments:** `ATT_Snap_Start` (x 0, local -Y out along -X), `ATT_Snap_End` (x 4 m, out along +X), `ATT_Base`.
- **Open:** shipping copies sit in `build/prod` (task's arms-length rule) - run `python3 barriertex.py` with no `--out`
  to write `assets/textures/M_Road_CrashBarrier/`. The MaterialVariant row in `variants_row.json` waits on B02's
  `wire.py`. Beam/post sizes are the docs row's "verify" figures.
