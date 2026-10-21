# M_Kit_StretcherBasket — result

**Validate: PASS** (40 checks, 0 failed, 1 waived: *LOD UV layout* — collapse decimation drops 23 % of the UV area;
both LODs keep the same lanes and atlas). `check_textures.py`: 30/30 PASS (OpenGL normals, luma ranges, `_Wet`
darker/glossier, hi-vis orange covered by `signal_mask.png`).

- LOD0 **2,988** tris, LOD1 **1,494** (ceilings 3,000 / 1,500). Real size 0.62 x 2.13 x 0.20 m (x +2.4 %, z +2.0 %),
  base at Z 0, head at -Y with the raised head section.
- Set: one own set `T_StretcherBasket_Kit_{ALB,NOR,RGH,MET}` + `_Wet`, 1024 px, 204 px/stud, painted procedurally by
  `maketex.py` from `features.json` (real hole / weld / strap positions).
- Attachments: `ATT_Lift_FL/FR/RL/RR` (the four lifting eyes), `ATT_Casualty` (bed centre, 2 cm above the tub floor).
- Built: galvanised rail + 4 cross ribs + 2 turned-up skids, bolted mid-join sleeves, 4 lifting eyes, 4 grab handles,
  orange HDPE tub (moulded ribs, 8 drilled and 8 painted drain holes), bolted foot plate, 4 webbing straps with cam
  buckles; salt, mud, rust and scuff wear.
- Open issues: no `art/reference/` board (dims from docs/12); the Studio preset row is pending (1.4 item 7); the
  raised head section is 1.6 cm, capped by the 0.20 m height spec.
