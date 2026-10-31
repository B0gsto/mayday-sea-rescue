# M_Prop_PrizeWheel (2026-10-31, round 1: Sonnet 5.5)

Validate PASS (90 checks, 0 failed, 17 waived: layer naming, LOD UV layout/UV faces, no ATT). LOD0 7,668 tris
(L01_Stand 2,108, L02_Rotor 5,456, L03_Flapper 92, Col01_COL 12), LOD1 3,828, LOD2 1,912. zfight (Blender) 0 pairs.
Set: 1 (T_PrizeWheel_Brick: 8x8 palette atlas with per-cell rough/metal: gloss plastic, polished gold, chrome).
Origin = the wheel's `at` (stand foot), front -Y; hub (0,10,-3.6), flapper hinge (0,17.9,-4.82) in studs.
Ids: LOD0 105640824287180, LOD1 108084525137319, LOD2 140393696134901 (moderation Approved).
Wired: PrizeWheel.build(at, handlers, art) swaps in L02_Rotor (pivot = hub), L03_Flapper (pivot = hinge), Stand + base
collider; the old Parts stay as the fallback. Normal map not wired (flat bytes; gen_asset_ids found no alias).
AD round 1: 7/10 (contact sheet build/status/2026-10-31/wheel1/contact_small.png). Fixes for round 2: bigger/chunkier
flapper and a real housing; gems ~1.6x on a white disc; fewer grey Common reads (gold vs yellow trim); raised/shaded
dividers; Lego brick columns with studs. Studio checks (spin lands under pointer, zfight_scan) NOT run (owner stop).
