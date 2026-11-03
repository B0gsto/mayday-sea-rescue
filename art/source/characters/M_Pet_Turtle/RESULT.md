# M_Pet_Turtle

Low-poly faceted Turtle pet in Bosun LP style, one mesh per WildlifeRig part (src/shared/Config/Wildlife.luau order). Shared code: `art/source/characters/_Pets/petkit.py`.

- validate: PASS, 340 checks, 0 failed, 38 waived (one swatch set for the dog class, swatch texel density, LOD UV bounds / UV faces from per-face swatches). Origin `free`: the rig pivot on the ground.
- Tris: LOD0 1910, LOD1 758, LOD2 186 (budget class `dog`, asset ceiling 3,000).
- FBX nodes (rig-index order): Shell, Plastron, Head, EyeLeft, EyeRight, GlintLeft, GlintRight, FlipperFrontLeft, FlipperFrontRight, FlipperBackLeft, FlipperBackRight, Tail. Duplicate rig names (Eye, Glint, Flipper) are split Left/Right; `M_Pet_Turtle.mapping.json` gives rig name, rig index, `at` CFrame, mesh size and bounds offset per node. Each node's origin is its part `at` CFrame.
- Textures: `T_Turtle_Coat_ALB/NOR/RGH/MET` 1024 (pass check_textures), plus `T_Turtle_Rare_ALB` for the rare colour variant.
- Names: `M_Pet` is not a names.py category, so meshes / FBX are `M_Ani_Turtle`; folders stay `M_Pet_Turtle`.

Outputs: `build/prod/M_Pet_Turtle/fbx/M_Pet_Turtle/M_Ani_Turtle_LOD0.fbx` (+LOD1, LOD2), `build/prod/M_Pet_Turtle/textures/M_Pet_Turtle/`, `build/prod/M_Pet_Turtle/review/M_Pet_Turtle/turntable/`, sheet `build/prod/M_Pet_Turtle/review/M_Pet_Turtle/2026-10-24_sheet.png`.

Open: Shell plates read slightly grid-like up close. Golden rare ALB saturation 0.68 (by design). No Studio import yet; WildlifeRig still builds Parts (swap not wired, no src edits).

## 2026-11-01 perfect pass r1 (tour 8.0: "studded raised shell tiles, yellow-green belly rim, bigger head/eyes")

- Scutes inset deeper and raised 0.06 (tiles with dark seams); a Lego stud (r 0.15, along the tile normal, base sunk) on each of the 13 vertebral/costal tiles; the shell skirt and the plastron's outer ring are a new yellow-green `bellyRim` zone (plastron widened to 1.0 x 1.2); head 1.15x, eyes 0.3 (was 0.24), glints bigger.
- validate PASS (356 checks, 0 failed, 38 waived). Tris LOD0 2,482, LOD1 986, LOD2 242. zfight in session (LOD0-2): 0 pairs. Rare `T_Turtle_Rare_ALB` still written. Rig order, names and `at` frames unchanged.
- Lineup: `build/status/2026-11-01/perfect/animals/Pets/r1_sheet.png`.

## 2026-11-01 perfect pass r2 (r1 AD 7.8: "tiles read as painted lines; dull green; small")

- Whole turtle 1.2x about the rig pivot (petkit `build(scale=1.2)`); mesh 4.82 x 4.72 x 1.09 studs (w x l x h). Names, order, angles unchanged; mapping.json carries the scaled `at`/size.
- Shell plates raised 0.08 with a 0.03 plate-coloured chamfer (second inset); 3 bigger studs (r 0.18) on the centre-ridge vertebral tiles only (the 10 costal studs dropped). Brighter Lego greens: scute #4BA03C/#3E8A31, scuteLight #6DBE4E, rim #3A8A33, seam #21401D; skin #5A8A47/#7FA866, scale #8DB463; plastron/cream a touch warmer. Flippers 15 % thicker (lens 0.184 / 0.15) with darker tips (new `skinDark` #3B5E2E, outer 55 %). Rare ref -> #6C9956; `T_Turtle_Rare_ALB` still written.
- ABS shading: `smooth=40`. Close-up camera scaled with the asset.
- validate PASS (340 checks, 0 failed, 37 waived). Tris LOD0 2594, LOD1 1032, LOD2 254. zfight in session (collect/analyse, all LODs): 0 pairs. Exported (LOD0-2).
- Lineup: `build/status/2026-11-01/perfect/animals/Pets/r2_sheet.png`.

## r3 (2026-11-03)

- SCALE 1.45: mesh 5.82 x 5.97 x 1.77 studs (w x l x h); stays flat by design, the read comes from the dome and raised head. Undersides 25 % darker.
- Shell dome 1.4x higher; head + front flippers up 0.3 studs; head 1.3x, eyes and glints a further 1.2x; seams dark green #2A5C26 and 1.5x wider; tan plastron edge and skirt #E6CF86; centre plate stud r 0.26, the 2 ridge studs kept. Rare ALB still written.
- validate PASS (340 checks, 0 failed, 40 waived). Tris LOD0 2594, LOD1 1032, LOD2 254. zfight in session (all LODs): 0 pairs.
- PetSeat `built` (shell length, LOD0): 3.844.

## r4 (2026-11-03)

- Flippers 2x thicker with a blunt edge, 25 % shorter past the shell edge, speckle halved. Yellow-green head (headSkin #A4C440, headScale). Head + eyes up 10 % (+0.168 studs). Shell zones 15 % darker. Ridge studs in a new bright `stud` zone, centre r 0.32. Tan skirt rebuilt 2x tall on a clean ellipse 10 % out: at 1.03 flare the raised rim plates hid it (only seam spikes showed). Rare ALB still written.
- Mesh 5.16 x 5.97 x 2.03 studs (w x l x h). High point 2.567 studs, up from 2.399 in r3: the head is the top and the AD asked for it 10 % higher (still inside 2.3-2.7).
- validate PASS (356 checks, 0 failed, 42 waived). Tris LOD0 2630, LOD1 1046, LOD2 258. zfight in session (all LODs): 0 pairs.
- PetSeat `built` (shell length, LOD0: 4.147). Not edited in PetSeat.luau.

## r5 (2026-11-03)

- Bug fixed: the shell grid winds downward, so before r5 the "raised" plates were sunk behind a raised seam lattice and the ridge studs pointed inward (read from the code and measured on the first r5 build, r4 mesh not re-inspected). Depth and stud normals flipped; plates now stand proud of real grooves.
- Plates 25 % larger: 4 vertebral, 3 costal a side, wider marginals; grooves 0.0525 -> 0.07. The big centre stud straddles the middle seam (4 plates, sunk past the groove floor). Lighter centre row (`vert`, `vertLight`). Hull +15 % (0.87 -> 1.0, plates at the top). Tan rim 1.3x tall on a 13 % ellipse; plastron 0.13 down to stay below its cap.
- Front flippers 15 % shorter with blunt rounded tips; rear flippers 40 % thicker.
- Mesh 4.95 x 5.97 x 2.12 studs (w x l x h). High point 2.567 studs (the head, unchanged).
- validate PASS (340 checks, 0 failed, 44 waived). Tris LOD0 2466, LOD1 980, LOD2 240. zfight in session (all LODs): 0 pairs.
- PetSeat `built` (shell length, LOD0: 4.260). Not edited in PetSeat.luau.
