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

## 2026-11-01 perfect pass r1 (tour 7.9: "fatter body, shorter wings, chunkier yellow beak/feet, darker wingtips")

- Plumper toy body (1.5 x 1.2 x 1.95, softer back taper), bigger neck and belly; wings span 1.95 (was 2.5) and thicker, black tips start at 60 % span and are darker/glossier; chunkier beak (wider, deeper, bigger hook and gonys spot); legs and feet now chunky yellow (pink zone dropped); eyes and orange rings a touch bigger.
- validate PASS (297 checks, 0 failed, 26 waived). Tris LOD0 1,888, LOD1 944. zfight in session (collect/analyse, LOD0+LOD1): 0 pairs. Rig order, names and `at` frames unchanged.
- Lineup: `build/status/2026-11-01/perfect/animals/Pets/r1_sheet.png`.

## 2026-11-01 perfect pass r2 (r1 AD 7.6: "spidery T-pose wings, pale, small")

- Whole gull 1.2x about the rig pivot (lpkit `build_asset(scale=1.2)`, new); mesh 3.32 x 2.58 x 4.13 studs (w x h x l).
- Rig `at` positions moved (names/order/angles unchanged): everything above the legs 0.1 lower (legs 0.62 -> 0.48, 20 % shorter visible leg), head cluster (Beak, Eyes, Glints) pulled in 0.85x about the Head, head 0.85x. Positions in the table are pre-scale; mapping.json carries the scaled ones.
- Wings 30 % shorter (SPAN 1.95 -> 1.4) and drooped (DROOP 0.42, ~23 deg with the part roll); mid-grey mantle #9AA6B4/#848F9C; 0.3 grey head stud; beak 1.5x longer with the red spot out near the tip; chunkier bevels (beak/legs/feet 2 segments, wings 0.05).
- ABS shading: lpkit `smooth=40` (new; default 0 keeps Puffin, SeaChest, Kelp unchanged).
- validate PASS (286 checks, 0 failed, 25 waived: new "UV faces" waiver like Puffin, LOD1 head-stud collapse). Tris LOD0 2308, LOD1 1154 (small_prop 3000). zfight in session: 0 pairs.

## r3 (2026-11-03)

- SCALE 1.25: mesh 2.06 x 3.96 x 2.69 studs (w x l x h). Undersides 25 % darker (lpkit `under=0.25`).
- Beak 30 % shorter and straight (hook removed), red gonys dot on the lower mandible. Wings folded 70 deg down against the flank with a short rounded black tip, tip swept back (rig `at` unchanged; PetMotion's shoulder now resolves to the wing top because the part is taller than wide). Mantle #8A99A8/#7A8997.
- validate PASS (286 checks, 0 failed, 25 waived). Tris LOD0 2268, LOD1 1134. zfight in session (all LODs): 0 pairs. No rare albedo (none before).
- PetSeat `built` (head height, LOD0): 2.685.

## r4 (2026-11-03)

- Mantle #84919E/#7A8794 (~#7F8C99). Black wingtip 0.24 -> 0.45 of the span, CURL 0.2 -> 0.12 so it shows from the front. Red dot 2x. Head cluster (Head, Beak, Eyes, Glints) +15 %, down 0.055 so it stays under 2.7. Legs 1.4x thicker. Yellow more saturated #FFC800/#F2A200.
- Mesh 2.20 x 4.13 x 2.70 studs (w x l x h).
- validate PASS (297 checks, 0 failed, 27 waived). Tris LOD0 2268, LOD1 1134. zfight in session (all LODs): 0 pairs.
- PetSeat `built` (head height, LOD0: 2.696). Not edited in PetSeat.luau.
