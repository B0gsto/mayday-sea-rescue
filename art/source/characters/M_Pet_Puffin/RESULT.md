# M_Pet_Puffin

Low-poly faceted Atlantic puffin pet (Bosun LP style), segmented for WildlifeRig.

- `validate`: PASS, 268 checks, 0 failed, 24 waived (texel density and LOD UV layout: per-face swatch atlas, as Bosun LP). `check_textures`: PASS.
- Tris: LOD0 1,524, LOD1 762 (`small_prop`, 3,000). One set `T_Puffin_Feathers` (1024).
- 14 nodes in `Wildlife.Species.Puffin.parts` order: Body, Belly, Head, Face, Beak, EyeLeft, EyeRight, GlintLeft, GlintRight, WingLeft, WingRight, FootLeft, FootRight, Tail. Duplicate part names get Left (Roblox -X) / Right; `M_Pet_Puffin.mapping.json` gives node, part, index, rest CFrame and mesh size. Each FBX node sits at its PartSpec `at`.
- Outputs: `build/prod/M_Pet_Puffin/fbx/M_Pet_Puffin/M_Ani_Puffin_LOD0.fbx` (+ LOD1), textures, turntable, `review/M_Pet_Puffin/2026-10-24_sheet.png`.

## Open

- FBX stem is `M_Ani_Puffin` ("Pet" is not a names.py category); folders use M_Pet_Puffin.
- Wings tuck against the body (the rig tilts them out); Face mostly sits inside the Head.
- The albino palette is not in the atlas: rare variant needs a second ALB or a tint.
- Not imported into Studio; WildlifeRig still builds block Parts (no src edits).
