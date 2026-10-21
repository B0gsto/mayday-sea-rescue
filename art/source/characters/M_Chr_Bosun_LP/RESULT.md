# M_Chr_Bosun_LP

Low-poly segmented Bosun for the existing BosunRig / BosunMotion (no src edits).

## Result

- `validate`: PASS, 962 checks, 0 failed, 87 waived. Waivers: one 1024 texture set (brief), swatch-atlas texel density, and LOD UV bounds for the per-face palette; origin is the ground between the feet, so the footprint was centred for the prop-style bbox check and parts were re-origined at their rig CFrames after validation.
- 4,940 LOD0 tris, 1,940 LOD1, 466 LOD2. 35 meshes named exactly like `BosunRig.PARTS`; 8 harness meshes stay separate.
- One `T_Bosun_Coat` set (ALB/NOR/RGH/MET, 1024), pass `check_textures`; signal mask for the orange harness. No fur cards.
- FBX nodes carry the rig CFrames with their origins at the part centres; `.mapping.json` has size, rest CFrame, parent, joint, pivot and harness flag.

## Outputs

- `build/prod/M_Chr_Bosun_LP/fbx/M_Chr_Bosun_LP/M_Chr_Bosun_LP_LOD0.fbx`
- `build/prod/M_Chr_Bosun_LP/M_Chr_Bosun_LP.mapping.json`
- Sheet: `build/prod/M_Chr_Bosun_LP/review/M_Chr_Bosun_LP/2026-10-19_sheet.png`
- Poses: `pose_sit.png`, `pose_trot.png`, `pose_swim.png` beside the sheet.

## Open

Sit is an approximate FK pose; no Roblox Studio import pass yet.
