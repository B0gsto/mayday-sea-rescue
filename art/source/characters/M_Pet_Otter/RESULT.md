# M_Pet_Otter

Low-poly faceted Otter pet in Bosun LP style, one mesh per WildlifeRig part (src/shared/Config/Wildlife.luau order). Shared code: `art/source/characters/_Pets/petkit.py`.

- validate: PASS, 394 checks, 0 failed, 35 waived (one swatch set for the dog class, swatch texel density, LOD UV bounds / UV faces from per-face swatches). Origin `free`: the rig pivot on the ground.
- Tris: LOD0 2056, LOD1 812, LOD2 200 (budget class `dog`, asset ceiling 3,000).
- FBX nodes (rig-index order): Body, Tummy, Head, Muzzle, Nose, EyeLeft, EyeRight, GlintLeft, GlintRight, EarLeft, EarRight, PawLeft, PawRight, Tail. Duplicate rig names (Eye, Glint, Flipper) are split Left/Right; `M_Pet_Otter.mapping.json` gives rig name, rig index, `at` CFrame, mesh size and bounds offset per node. Each node's origin is its part `at` CFrame.
- Textures: `T_Otter_Coat_ALB/NOR/RGH/MET` 1024 (pass check_textures), plus `T_Otter_Rare_ALB` for the rare colour variant.
- Names: `M_Pet` is not a names.py category, so meshes / FBX are `M_Ani_Otter`; folders stay `M_Pet_Otter`.

Outputs: `build/prod/M_Pet_Otter/fbx/M_Pet_Otter/M_Ani_Otter_LOD0.fbx` (+LOD1, LOD2), `build/prod/M_Pet_Otter/textures/M_Pet_Otter/`, `build/prod/M_Pet_Otter/review/M_Pet_Otter/turntable/`, sheet `build/prod/M_Pet_Otter/review/M_Pet_Otter/2026-10-24_sheet.png`.

Open: The placeholder Body box was 2.5 wide x 1.15 long; the mesh is long and narrow (about 1.1 x 2.9) so head and tail connect: swap must use the mapping `size`, not the placeholder size. Hind feet are part of Body (no rig part). No Studio import yet; WildlifeRig still builds Parts (swap not wired, no src edits).
