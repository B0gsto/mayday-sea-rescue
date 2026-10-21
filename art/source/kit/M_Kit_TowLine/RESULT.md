# M_Kit_TowLine — result

**Validate: PASS** (79 checks, 0 failed, 4 waived: *LOD UV layout* — collapse decimation of the two-layer flake
merges UV islands; every LOD still samples the same tiling trim). `check_textures.py`: 54/54 PASS.

- LOD0 **2,492** tris (flake 2,136, shackle 356, `_COL` 12), LOD1 **1,245**, LOD2 **623**; ceilings 2,500 /
  1,250 / 625. Real size 1.82 x 1.64 x 0.24 studs (0.61 x 0.55 x 0.08 m), base at Z 0.
- Sets: `T_TowLine_Rope_*` 1024 tiling rope trim (cream 3-strand polyester, red marker yarn, deck grime, salt)
  and `T_TowLine_Hardware_*` 512 galvanised steel, each + `_Wet`; written by `maketex.py` at build time.
- Attachments: `ATT_Grip` (flake top), `ATT_Eye`, `ATT_Shackle` (pin), `ATT_LineEnd` (whipped end).
- Built: 20 mm line, 0.45 m OD two-layer flake (~11.5 m drawn) with the working end out through the outer turn,
  a bight round the centre hole onto layer two, the free end draped over the edge and whipped; long splice
  throat, spliced eye round a galvanised thimble, 16 mm screw-pin bow shackle standing in the eye, wire moused.
- Open issues: no `art/reference/` photo board (size from `dims.md` + docs/12); Studio preset row pending
  (1.4 item 7); the flake is the stowed coil — in-game the running tow is the Beam/rope mesh.
