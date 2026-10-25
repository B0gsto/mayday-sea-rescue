# M_Pet_SealPup

Low-poly faceted SealPup pet in Bosun LP style, one mesh per WildlifeRig part (src/shared/Config/Wildlife.luau order). Shared code: `art/source/characters/_Pets/petkit.py`.

- validate: PASS, 340 checks, 0 failed, 33 waived (one swatch set for the dog class, swatch texel density, LOD UV bounds / UV faces from per-face swatches). Origin `free`: the rig pivot on the ground.
- Tris: LOD0 1648, LOD1 652, LOD2 158 (budget class `dog`, asset ceiling 3,000).
- FBX nodes (rig-index order): Body, Belly, Head, Snout, Nose, EyeLeft, EyeRight, GlintLeft, GlintRight, FlipperLeft, FlipperRight, Tail. Duplicate rig names (Eye, Glint, Flipper) are split Left/Right; `M_Pet_SealPup.mapping.json` gives rig name, rig index, `at` CFrame, mesh size and bounds offset per node. Each node's origin is its part `at` CFrame.
- Textures: `T_SealPup_Coat_ALB/NOR/RGH/MET` 1024 (pass check_textures), plus `T_SealPup_Rare_ALB` for the rare colour variant.
- Names: `M_Pet` is not a names.py category, so meshes / FBX are `M_Ani_SealPup`; folders stay `M_Pet_SealPup`.

Outputs: `build/prod/M_Pet_SealPup/fbx/M_Pet_SealPup/M_Ani_SealPup_LOD0.fbx` (+LOD1, LOD2), `build/prod/M_Pet_SealPup/textures/M_Pet_SealPup/`, `build/prod/M_Pet_SealPup/review/M_Pet_SealPup/turntable/`, sheet `build/prod/M_Pet_SealPup/review/M_Pet_SealPup/2026-10-24_sheet.png`.

Open: Head and body still read a little as two balls from the side (the rig `at` positions are fixed). Golden rare ALB is more saturated than check_textures allows (0.65, by design). No Studio import yet; WildlifeRig still builds Parts (swap not wired, no src edits).
