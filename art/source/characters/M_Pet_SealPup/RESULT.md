# M_Pet_SealPup

Low-poly faceted SealPup pet in Bosun LP style, one mesh per WildlifeRig part (src/shared/Config/Wildlife.luau order). Shared code: `art/source/characters/_Pets/petkit.py`.

- validate: PASS, 356 checks, 0 failed, 35 waived (one swatch set for the dog class, swatch texel density, LOD UV bounds / UV faces from per-face swatches). Origin `free`: the rig pivot on the ground.
- Tris: LOD0 2040, LOD1 810, LOD2 196 (budget class `dog`, asset ceiling 3,000).
- FBX nodes (rig-index order): Body, Belly, Head, Snout, Nose, EyeLeft, EyeRight, GlintLeft, GlintRight, FlipperLeft, FlipperRight, Tail. Duplicate rig names (Eye, Glint, Flipper) are split Left/Right; `M_Pet_SealPup.mapping.json` gives rig name, rig index, `at` CFrame, mesh size and bounds offset per node. Each node's origin is its part `at` CFrame.
- Textures: `T_SealPup_Coat_ALB/NOR/RGH/MET` 1024 (pass check_textures), plus `T_SealPup_Rare_ALB` for the rare colour variant.
- Names: `M_Pet` is not a names.py category, so meshes / FBX are `M_Ani_SealPup`; folders stay `M_Pet_SealPup`.

Outputs: `build/prod/M_Pet_SealPup/fbx/M_Pet_SealPup/M_Ani_SealPup_LOD0.fbx` (+LOD1, LOD2), `build/prod/M_Pet_SealPup/textures/M_Pet_SealPup/`, `build/prod/M_Pet_SealPup/review/M_Pet_SealPup/turntable/`, sheet `build/prod/M_Pet_SealPup/review/M_Pet_SealPup/2026-10-24_sheet.png`.

Open: Head and body still read a little as two balls from the side (the rig `at` positions are fixed). Golden rare ALB is more saturated than check_textures allows (0.65, by design). No Studio import yet; WildlifeRig still builds Parts (swap not wired, no src edits).

## 2026-11-01 perfect pass r1 (tour 7.8: "pale grey washes out near the white water")

- Blue-grey coat (fur #647C94/#8FA4BA, cooler belly), darker flippers with near-black `tip` bands on the flipper and tail edges, white eye rings (sclera 0.52 behind the 0.36 pupil, in the Eye part), a chunky lighter belly-line lip on the Body and a blue-grey Lego stud on the back. Rare reference moved to the new mid tone (#7A90A7) so `T_SealPup_Rare_ALB` keeps its gold brightness.
- Same rig: parts, order, `at` CFrames unchanged (Body mesh size grows to 2.19 x 1.48 x 2.68 from the lip/stud).
- zfight in session (collect/analyse, LOD0-2): 0 pairs.

## 2026-11-01 perfect pass r2 (r1 AD 7.6: "saucer ring, still small, origami")

- Whole pup 1.2x about the rig pivot (petkit `scale=1.2`); mesh 3.63 x 2.23 x 4.77 studs (w x h x l). Seated pup grows too (PetSeat `built` unchanged).
- Saucer lip dropped (Body is coat + belly only). Steel-blue coat #6F8FB0/#7FA3C8, flipper #527296/#5F80A4, tips 30 % darker #202C3A/#26323F, back stud 0.4 (#9CBCDC). Rare ref -> #7799BC.
- Eye whites 0.52 -> 0.44 (-15 %), glints 0.12 -> 0.15 (readable highlight dot), whiskers 30 % shorter.
- ABS shading: petkit `smooth=40`.
- validate PASS (340 checks, 0 failed, 36 waived). Tris LOD0 1944, LOD1 772, LOD2 188. zfight in session (all LODs): 0 pairs.
