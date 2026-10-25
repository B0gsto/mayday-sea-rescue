# M_Pet_Gull

Low-poly faceted herring gull pet (Bosun LP style), segmented for WildlifeRig.

- `validate`: PASS, 286 checks, 0 failed, 26 waived (texel density and LOD UV layout: per-face swatch atlas). `check_textures`: PASS.
- Tris: LOD0 1,696, LOD1 848 (`small_prop`, 3,000). One set `T_Gull_Feathers` (1024).
- 15 nodes in `Wildlife.Species.Gull.parts` order: Body, Belly, Head, Beak, EyeLeft, EyeRight, GlintLeft, GlintRight, WingLeft, WingRight, Tail, LegLeft, LegRight, FootLeft, FootRight (Left = Roblox -X). `M_Pet_Gull.mapping.json` gives node, part, index, rest CFrame, mesh size.
- Look: white body with a grey mantle, spread grey wings with black tips and white mirrors, yellow beak with a red gonys spot, orange eye ring, pink legs (real herring gull; the block rig used yellow).
- Outputs: `build/prod/M_Pet_Gull/fbx/M_Pet_Gull/M_Ani_Gull_LOD0.fbx` (+ LOD1), textures, turntable, `review/M_Pet_Gull/2026-10-24_sheet.png`.

## Open

- FBX stem is `M_Ani_Gull` ("Pet" is not a names.py category).
- The Body mesh includes a neck so the head joins the body; tail is a thin fan.
- The snow-gull palette is not in the atlas. Not imported into Studio yet.
