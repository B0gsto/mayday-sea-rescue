# M_Ani_HerringGull (AN1)

One adult European herring gull in a neutral glide pose: 1.40 m span, 0.588 m long, bbox-centred origin. Lofted
geometry (NACA-section wings with sawtooth primary tips, plump body, tucked legs); feather relief is the normal map.

- **Validate: PASS** (59 checks, 0 failed, 1 waived: LOD2 UV layout).
- **Tris:** LOD0 2,780 / LOD1 1,112 / LOD2 278 (docs row 3,000 / 1,200 / 400), one MeshPart, no `_COL` (class
  `dog_fur_cards`).
- **Set** `T_Gull_Feather` 1024 ALB / NOR / RGH / MET, painted by atlas region: white head and body, grey mantle and
  coverts, black primaries with the white mirror, white secondary tips and tail, yellow bill with the red gonys spot,
  pale yellow eye, pink legs. `check_textures`: 18 checks, 0 failed. Signal mask beside `build.py`.
- **Rig** `RIG_HerringGull`, 13 bones (Root, Body, Neck, Head, Tail, Wing_1/2 and Leg_1/2 per side), analytic skin,
  every vertex weighted, max 2 influences, weights sum to 1. `M_Ani_HerringGull_Rig.fbx` (glide rest) and
  `M_Ani_HerringGull_Anims.fbx` (glide, flap, land, stand, call, baked AnimationStacks) from `export_rig.py`.
- Attachment: none.
- Open: clips unverified in Studio (`run.py`'s clips steps are not ported); the LOD2 waiver; no in-game pass; no
  reference photo in `art/reference/M_Ani_HerringGull/`.
