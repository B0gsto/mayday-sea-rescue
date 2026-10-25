# M_Pet_Turtle

Low-poly faceted Turtle pet in Bosun LP style, one mesh per WildlifeRig part (src/shared/Config/Wildlife.luau order). Shared code: `art/source/characters/_Pets/petkit.py`.

- validate: PASS, 340 checks, 0 failed, 38 waived (one swatch set for the dog class, swatch texel density, LOD UV bounds / UV faces from per-face swatches). Origin `free`: the rig pivot on the ground.
- Tris: LOD0 1910, LOD1 758, LOD2 186 (budget class `dog`, asset ceiling 3,000).
- FBX nodes (rig-index order): Shell, Plastron, Head, EyeLeft, EyeRight, GlintLeft, GlintRight, FlipperFrontLeft, FlipperFrontRight, FlipperBackLeft, FlipperBackRight, Tail. Duplicate rig names (Eye, Glint, Flipper) are split Left/Right; `M_Pet_Turtle.mapping.json` gives rig name, rig index, `at` CFrame, mesh size and bounds offset per node. Each node's origin is its part `at` CFrame.
- Textures: `T_Turtle_Coat_ALB/NOR/RGH/MET` 1024 (pass check_textures), plus `T_Turtle_Rare_ALB` for the rare colour variant.
- Names: `M_Pet` is not a names.py category, so meshes / FBX are `M_Ani_Turtle`; folders stay `M_Pet_Turtle`.

Outputs: `build/prod/M_Pet_Turtle/fbx/M_Pet_Turtle/M_Ani_Turtle_LOD0.fbx` (+LOD1, LOD2), `build/prod/M_Pet_Turtle/textures/M_Pet_Turtle/`, `build/prod/M_Pet_Turtle/review/M_Pet_Turtle/turntable/`, sheet `build/prod/M_Pet_Turtle/review/M_Pet_Turtle/2026-10-24_sheet.png`.

Open: Shell plates read slightly grid-like up close. Golden rare ALB saturation 0.68 (by design). No Studio import yet; WildlifeRig still builds Parts (swap not wired, no src edits).
