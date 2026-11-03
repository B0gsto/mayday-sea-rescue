# M_Pet_Otter

Low-poly faceted Otter pet in Bosun LP style, one mesh per WildlifeRig part (src/shared/Config/Wildlife.luau order). Shared code: `art/source/characters/_Pets/petkit.py`.

- validate: PASS, 410 checks, 0 failed, 41 waived (one swatch set for the dog class, swatch texel density, LOD UV bounds / UV faces from per-face swatches). Origin `free`: the rig pivot on the ground.
- Tris: LOD0 2112, LOD1 834, LOD2 204 (budget class `dog`, asset ceiling 3,000).
- FBX nodes (rig-index order): Body, Tummy, Head, Muzzle, Nose, EyeLeft, EyeRight, GlintLeft, GlintRight, EarLeft, EarRight, PawLeft, PawRight, Tail. Duplicate rig names (Eye, Glint, Flipper) are split Left/Right; `M_Pet_Otter.mapping.json` gives rig name, rig index, `at` CFrame, mesh size and bounds offset per node. Each node's origin is its part `at` CFrame.
- Textures: `T_Otter_Coat_ALB/NOR/RGH/MET` 1024 (pass check_textures), plus `T_Otter_Rare_ALB` for the rare colour variant.
- Names: `M_Pet` is not a names.py category, so meshes / FBX are `M_Ani_Otter`; folders stay `M_Pet_Otter`.

Outputs: `build/prod/M_Pet_Otter/fbx/M_Pet_Otter/M_Ani_Otter_LOD0.fbx` (+LOD1, LOD2), `build/prod/M_Pet_Otter/textures/M_Pet_Otter/`, `build/prod/M_Pet_Otter/review/M_Pet_Otter/turntable/`, sheet `build/prod/M_Pet_Otter/review/M_Pet_Otter/2026-10-24_sheet.png`.

Open: The placeholder Body box was 2.5 wide x 1.15 long; the mesh is long and narrow (about 1.1 x 2.9) so head and tail connect: swap must use the mapping `size`, not the placeholder size. Hind feet are part of Body (no rig part). No Studio import yet; WildlifeRig still builds Parts (swap not wired, no src edits).

## 2026-11-01 perfect pass r1 (tour 7.2: "cute but tiny and flat brown")

- Whole otter 1.3x about the rig pivot (`SCALE`, petkit `build(scale=)`): every shape and every `at` position, so the mapping's `at`/`size` carry it (mesh now 1.87 x 6.69 x 2.15 studs, was ~5.1 long). Head cluster (Head, Muzzle, Nose, Eyes, Glints, Ears) another 1.15x about the Head part.
- Cream belly (whole Tummy), cream chest bib and chin/face patch, all-cream muzzle; thicker feet (lens 0.2), ears and tail (cone 0.3 -> 0.07, darker tip); a Lego stud on the tail.
- zfight in session (collect/analyse, LOD0-2): 0 pairs. Rare `T_Otter_Rare_ALB` still written.
- Code: WildlifeRig reads the uploaded MeshParts' CFrames (relative to the template pivot) and Sizes, not mapping.json; Wildlife.luau `at`/size only drive the block fallback (left unchanged, so the fallback stays smaller). PetSeat.Sizes.Otter.built = 5.08 is a constant, so the following pet grows 1.3x in game; updating `built` to the new length would cancel the scale-up. attachments.json: none.

## 2026-11-01 perfect pass r2 (r1 AD 8.0: "still a speck; flat brown; origami facets")

- `SCALE` 1.3 -> 1.4 (r1 x1.08) about the rig pivot; mesh 2.02 x 2.33 x 7.20 studs (w x h x l). Head cluster still 1.15x about Head.
- Saturated chocolate coat: fur #6B3F22/#93603A, furLight #A97A52, furDark #4A2A16, paw #4A2E1C, dot #7E5636; cream belly/muzzle unchanged. Rare ref -> #7F4F2E (silver ALB keeps its brightness).
- Studs: a 0.3 back stud (Body) and a 0.26 crown stud (Head), both furLight; the invisible tail stud removed.
- ABS shading: petkit `build(smooth=40)` (shade smooth + sharp edges above 40 deg; LOD1/2 already smooth via weighted normals).
- validate PASS (394 checks, 0 failed, 44 waived). Tris LOD0 2168, LOD1 856, LOD2 212. zfight in session (collect/analyse, all LODs): 0 pairs.
- PetSeat `built` unchanged on purpose, so the seated otter grows 1.08x too.

## r3 (2026-11-03)

- SCALE 1.6 about the rig pivot: mesh 2.30 x 7.64 x 2.66 studs (w x l x h). Undersides 25 % darker (petkit `under=0.25`, twin atlas cells).
- Chocolate coat #5A3A22/#684530, brighter cream face + chest patch 1.2x, readable eye glints; tail 20 % shorter with a 30 % thicker tapered root; whiskers 2 a side, thicker and shorter. Rare ref -> #61402A (silver ALB still written).
- validate PASS (394 checks, 0 failed, 45 waived). Tris LOD0 2144, LOD1 846, LOD2 208. zfight in session (all LODs): 0 pairs.
- PetSeat `built` (nose to tail, LOD0): 7.637.
