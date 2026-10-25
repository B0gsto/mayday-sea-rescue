# M_Prop_SeaChest

Low-poly faceted sea chest for the daily-reward StreakCrate: planked wood, iron bands, brass corners, lock plate and hasp, rope beckets on both short sides.

- `validate`: PASS, 54 checks, 0 failed, 4 waived (texel density, LOD UV layout: swatch atlas). `check_textures`: PASS (wood, brass and rope in the signal mask: stylised palette).
- Tris: LOD0 2,688, LOD1 1,343 (`small_prop`, 3,000). One set `T_SeaChest_Wood` (1024).
- Nodes: `Base` (origin = ground centre, the crate's `at`) and `Lid` (origin at the hinge, Roblox (0, 3.1, -1.8); rotate about X to open, as StreakCrate.open). `ATT_LidHinge` marks the hinge. Sizes match StreakCrate at scale 1 (body 5.6 x 3.1 x 3.6, lid 6.0 x 0.55 x 3.95, flat top at y 3.65 for the pip strip).
- Outputs: `build/prod/M_Prop_SeaChest/fbx/M_Prop_SeaChest/M_Prop_SeaChest_LOD0.fbx` (+ LOD1), `M_Prop_SeaChest.mapping.json`, textures, turntable, `review/M_Prop_SeaChest/2026-10-24_sheet.png`.

## Open

- Front (lock, hasp) faces Roblox +Z like the code-built crate, so the turntable's "Front3Q" shows the back.
- The hasp tab hangs 0.4 below the lid and swings up with it. Welcome crate = scale the model 1.35. Not imported into Studio.
