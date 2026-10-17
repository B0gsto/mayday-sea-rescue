# Spike 1 build notes (B01, 2026-10-17)

Scripts: `make_textures.py` (Pillow), `build_spike1.py` (one `blender-run.sh` run, ~1 min), `upload_all.sh` (with-lock,
route `delivery`), `inspect_meshes.py` (lune rbxm-inspect plus a mesh-header parse of each MeshContent asset).
Raw data: `fbx_readback.json`, `upload_log.txt`, `rbxm_findings.json`. Export used rbxkit's settings exactly (-Z fwd, Y up,
FBX_SCALE_UNITS, scale 1, triangulated), called directly because `rbxkit.export_fbx` asserts tris <= 20,000.
All 22 uploads succeeded (exit 0). Models came back as .rbxm via `delivery`; studio route never used.

## Models (assets/fbx/Spike1/*.fbx -> assets/models/<name>.rbxm, all moderation Approved)

| Name | Exported tris | Model id | Stored mesh tris / verts | MeshPart Size (studs) |
|---|---|---|---|---|
| M_Spike1_ScaleCube | 12 | 99212271339218 | 12 / 24 | 3 x 3 x 3 (1 m = 3 studs confirmed) |
| M_Spike1_RefBox | 12 | 124101679376385 | 12 / 24 | 1 x 5.5 x 1 (Blender Z -> Roblox Y) |
| M_Spike1_TexPlane | 2 | 134846170816032 | 2 / 4 | 12 x 0.001 x 12 |
| M_Spike1_Tris09990 | 9,990 | 118575254499229 | 9,990 / 29,970 | 12 x 1.09 x 12 |
| M_Spike1_Tris19990 | 19,990 | 127935384871864 | 19,990 / 59,970 | 12 x 1.10 x 12 |
| M_Spike1_Tris20500 | 20,500 | 107853799637000 | **19,905** / 10,154 | 12 x 1.10 x 12 |
| M_Spike1_Tris21500 | 21,500 | 82241768209454 | **19,896** / 10,149 | 12 x 1.09 x 12 |
| M_Spike1_Tris30000 | 30,000 | 126935964886724 | **19,826** / 10,106 | 12 x 1.10 x 12 |
| M_Spike1_Tentacle20 | 2,560 | 71211016289278 | 2,560 / 7,656, 20 bones, 1 bone subset | 2 x 20 x 2 |
| M_Spike1_Tentacle40 | 5,120 | 133379345248155 | 5,120 / 15,276, 40 bones, 2 bone subsets | 2 x 20 x 2 |

Each rbxm: 1 Model with 1 MeshPart (PhysicalConfigData present).

- **Triangle limit: nothing is rejected.** Open Cloud accepts 20,500 / 21,500 / 30,000 and silently decimates to just under
  20,000 (stored mesh v2.00 header: 19,905 / 19,896 / 19,826 tris, verts welded to ~10.1k). 19,990 is kept exactly. So the
  cap is 20,000 per MeshPart, enforced by decimation, not error. Working rule of 10,000 stays (budget headroom, not a limit).
- **Skinned:** both tentacles import skinned (`HasSkinnedMesh = true`), mesh v4.01 with 20 / 40 bones, max 4 weights per vertex
  as authored. rbxm tree: MeshPart > nested `Bone_00..Bone_NN` chain (all 20 / 40 present), plus AnimationController and a
  Folder of CFrameValues (66 / 126). The 40-bone mesh is split into 2 bone subsets (probably a per-subset bone cap; exact cap not read).
  No animation exported (optional; skipped). Deformation itself is untested until Studio.
- Exported FBX verts are unwelded (mesh_smooth_type FACE splits per face); Roblox keeps them as sent below 20k tris.

## Images (assets/textures/Spike1/, all 12 Image uploads succeeded, moderation **Reviewing** at upload time)

| Size | ALB | NOR | RGH | MET |
|---|---|---|---|---|
| 1024 | 133497070455294 | 71516326342804 | 106584681481305 | 108926989495989 |
| 2048 | 113981166754593 | 76902494683852 | 114094302637870 | 118576858914698 |
| 4096 | 77900366731410 | 79130005892903 | 128068413526739 | 134209066827654 |

- **Asset delivery serves every image at 1024 x 1024** (2048 and 4096 uploads included). In the served 2048 ALB the 1-px
  zones are flat grey and the 2-px checker is half contrast; in the served 4096 ALB everything up to the 4-px checker is flat.
  Whether the engine streams a higher-res version in-game is the Studio stage's question (look at the labelled zones).
- `check_textures.py --cap 4096`: names fail (`1024` is not PascalCase, names as specified); content: NOR passes OpenGL and
  tangent-space, RGH / MET single-channel pass; ALB fails metal-albedo and saturation (expected for a test chart).

## Ready-to-run list for the Studio stage

1. `python3 ~/RobloxProjects/tools/assets.py refresh /Users/bogdan/RobloxProjects/MaydaySeaRescue` (images were Reviewing).
2. Insert `assets/models/M_Spike1_{ScaleCube,RefBox,TexPlane,Tris09990,Tris19990,Tris20500,Tris21500,Tris30000,Tentacle20,Tentacle40}.rbxm`.
3. Clone TexPlane 3 times; SurfaceAppearance per size with the image ids above (rbxassetid://<id>) for Color/Normal/
   Roughness/MetalnessMap. Check the 1/2/4-px zones and the corner pixel grids on PC and phone emulator at close range.
4. Tentacles: rotate `Bone_10` / `Bone_30` in Edit mode; confirm the 40-bone mesh deforms along its whole length (both bone subsets).
5. Tris20500/21500/30000: compare shading against Tris19990 for decimation artefacts; check RenderFidelity LOD switching.
6. Re-run `python3 art/spike1/inspect_meshes.py` to refresh `rbxm_findings.json` if re-uploaded.
