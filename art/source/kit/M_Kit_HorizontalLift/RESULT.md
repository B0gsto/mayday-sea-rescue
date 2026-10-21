# M_Kit_HorizontalLift — result

**Validate: PASS** (83 checks, 0 failed; 1 waived: *LOD UV layout* — decimation of thin rope tubes and the flaked
strop moves UVs; every LOD samples the same trim). `check_textures.py`: 58/58 PASS.

- LOD0 **2,960** tris (rope 2,192, fittings 768, `_COL` 12), LOD1 **1,480**, LOD2 **740**; ceilings 3,000 /
  1,500 / 750. Real size 2.50 x 1.46 x 0.10 m (7.51 x 4.38 x 0.29 studs), base Z 0, front -Y.
- Sets: `T_HorizontalLift_Rope_*` 1024 tiling three-strand trim (faded hi-vis polypropylene, deck grime, salt) and
  `T_HorizontalLift_Fittings_*` 1024 four lanes (galvanised steel, SOLAS orange HDPE, black webbing, retro tape),
  each + `_Wet`, written by `maketex.py` at build time.
- Attachments: `ATT_Grip`, `ATT_Corner_01..04`, `ATT_Lift` (ring), `ATT_StropEnd`, `ATT_BuoyantEdge`.
- Built: 2.0 x 1.2 m net, 0.20 m knotted mesh laced to a 16 mm bolt rope; 3 m strop, eye over a 124 mm galvanised
  ring with moused bow shackle, flaked beside the head end; three floats on the buoyant edge, two webbing handles,
  three retro bands.
- Open issues: no reference board (`dims.md` "n/a, verify"); Studio preset row pending; own trim + fittings sheet
  serve the row's "kit soft set" (as M_Kit_TowLine and M_Kit_HeavingLine do, rope.py being the row's source); strop
  flaked, not rigged; no `src` code references this kit yet.
