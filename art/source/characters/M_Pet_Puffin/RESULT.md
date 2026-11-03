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

## 2026-11-01 perfect pass r1 (tour 8.4: "bigger striped beak, head stud, soft spec on the black")

- Beak ~1.2x and longer, five brick bands (slate, yellow, orange, yellow, orange tip) in more saturated orange/yellow; the yellow bands stand 5 % proud and bands overlap 0.02 so no end caps share a plane. A subtle black Lego stud sunk into the crown. Black zone lifted and glossier (roughness 0.42) for a soft spec.
- validate PASS (279 checks, 0 failed, 25 waived; new waiver "UV faces": LOD1 collapse of the stud leaves 2 zero-area UV faces, same waiver as the petkit pets). Tris LOD0 1,648, LOD1 824. zfight in session (LOD0+LOD1): 0 pairs. Rig order, names and `at` frames unchanged.
- Lineup: `build/status/2026-11-01/perfect/animals/Pets/r1_sheet.png`.

## 2026-11-01 perfect pass r2 (r1 AD 8.4: "beak a flat plate from the front")

- Whole puffin 1.2x about the rig pivot (lpkit `build_asset(scale=1.2)`); mesh 1.77 x 3.14 x 3.04 studs (w x l x h). Names, order, angles unchanged; mapping.json carries the scaled positions.
- Beak: a tapered wedge (tip width 60 % of the base, was 20 %), 2-segment bevels; band order slate, yellow, orange, yellow tip band (~25 % of the length), orange tip. A 0.05 white rim behind each red eye ring; a 0.06 white lip flange where the belly meets the black body. Black roughness 0.42 -> 0.34 (stronger soft spec); slate #6E8CAE/#4E6680 and feet #FF8A2A more saturated; chunkier foot/leg/tail bevels (2 segments).
- ABS shading: `smooth=40`.
- validate PASS (268 checks, 0 failed, 25 waived). Tris LOD0 2648, LOD1 1324 (small_prop 3000). zfight in session (collect/analyse, LOD0+LOD1): 0 pairs. Exported. No rare albedo (none before).
- Lineup: `build/status/2026-11-01/perfect/animals/Pets/r2_sheet.png`.

## r3 (2026-11-03)

- SCALE 1.06, down from 1.2: r2 stood 3.04 studs, over the 2.3-2.7 band. Mesh 1.57 x 2.77 x 2.68 studs (w x l x h). Undersides 25 % darker.
- Beak: tip 20 % narrower, ~0.1 stud rounded shoulder per stripe, yellow bands prouder, so it reads as a stepped 3D wedge head-on (~0.5 body widths out). White mask 15 % wider.
- validate PASS (268 checks, 0 failed, 25 waived). Tris LOD0 2648, LOD1 1324. zfight in session (all LODs): 0 pairs. No rare albedo (none before).
- PetSeat `built` (head height, LOD0): 2.681.

## r4 (2026-11-03)

- Beak 20 % narrower, up to the eye line (Beak y 1.98 -> 2.08), three clean bands (grey, proud yellow, orange) with a longer orange taper as the tip. White mask +15 % (eyes and glints 0.04 forward to stay proud). Wings: bevelled box (bevel 0.11, 0.3 thick) with chamfered ends instead of a ball.
- Mesh 1.70 x 2.83 x 2.68 studs (w x l x h).
- validate PASS (279 checks, 0 failed, 25 waived). Tris LOD0 2488, LOD1 1244. zfight in session (all LODs): 0 pairs.
- PetSeat `built` (head height, LOD0: 2.681). Not edited in PetSeat.luau.
