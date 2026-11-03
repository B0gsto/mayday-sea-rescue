# M_Ani_GreySeal ("Old Ned", grey seal bull)

- **r6 (2026-11-01, AD r5 8.8 fix list, all six; last round):** (1) Torso section: a rounded rectangle with a crisp
  0.036 m (0.11 stud) corner (`seal_shape.corner`), sampled by weighted arc length (`rr_arc`, the corners get 3.5x
  their share of the 48 ring points) so the flat top / flanks stay flat and the bevels crisp; a 0.004 m crown keeps the
  flat rings non-collinear (collinear rings made the LOD decimate open edges). Profile boxy (full girth, flat back) from
  the chest to y 0.74, then a short taper to a blunt 0.27-stud tail end (no pinched V between the hind flippers); the
  head keeps r5's 30 % corners. (2) Swim: chest ~+9 deg, neck ~+20, head ~+15, tail +19 and hind flippers ~+10..20 up,
  a bigger lateral S (tail 16, neck counter-turn 10), a 15 deg banking roll peaking at f37 (the sheet frame); fore
  flippers ~14 deg off the flanks. (3) Plate + studs #979CA1 (two steps lighter than the back), moved onto the flat,
  unbent back (y 0.74 to -0.10, studs at 0.60 / 0.32 / 0.04), so the three studs stand level. (4) Neutral, very slightly
  cool stone grey: back panel #6C7176, flanks #7B8086 (the step on the corner bevel), dapples #45494D (8: + rump + nape),
  seam #3A3E42, near-white bib / muzzle #F5F4F0 rising toward the muzzle on the head (a V that joins the muzzle box).
  (5) Flippers slate #3C4046, tips #33363B, a lighter #5B6067 rim along the bevelled edges; fore 1.12x (squared tips),
  hind 1.15x chord. (6) Roughness 0.44 coat / 0.48 belly / 0.42 flippers / 0.40 plate; a 3.5 % collar ledge ring
  in front of the neck crease (`folds`).
- **validate: PASS** (78 checks, 0 failed, 0 waived). **zfight:** 0 visible pairs (collect()/analyse(), 6 LOD meshes).
- **Tris:** LOD0 8,632 (Body 5,448 / Head 3,184) / LOD1 3,448 / LOD2 860. **Dims:** 3.009 x 7.629 x 2.820 studs (r5
  2.750 x 7.572 x 2.787: wider from the bigger fore flippers; DIMS_M = built).
- **RIG:** RIG_Seal 16 bones, 5 clips; RIG FBX exported in session (1.46 MB, all five A_Seal_* stacks). No fore-flipper
  vertex above the chest crest in any clip (every 3rd frame). No read-back import.
- **Sheet:** build/status/2026-11-01/perfect/animals/M_Ani_GreySeal/r6_sheet.png (+ _small); poses Swim f37 / HaulOut f22.

- **r5 (2026-11-01, AD r4 8.7 fix list, all six):** (1) Body and head sections are rounded rectangles
  (`seal_shape.section` via `rr`): flat top and side panels, corner radius ~30 % of the half size from the hips to the
  nose (rounder toward the tail), so the head has a flat top and a flat front; flipper / muzzle bevels 0.028-0.030 m
  (~0.09 stud). (2) Six bigger hard-edged dapples #4D4239 (0.6-0.75 stud across), 3 a side on the back / flanks;
  the crown spots dropped (head, neck, plate clean). (3) Coat #6A5C50 (~12 % darker, warmer), seam #3E352E, near-white
  bib / muzzle #F7F1E4, flippers #2F2924 with #241F1B tips; roughness 0.32 coat / 0.36 belly / 0.30 flippers / 0.28
  plate / 0.22 nose (no clearcoat: Roblox SurfaceAppearance has none). (4) Plate and studs in the dapple tone #4D4239,
  plate 0.95 stud wide with a 0.05 stud lip, seated on the flat back panel, centred on the spine over the broad back
  (y 0.62 to -0.26); studs 0.72 stud across, 0.32 tall. (5) Swim: body level, head up ~12-14 deg, fore-flippers swept
  ~25 deg back along the flanks with level tips, hind flippers in a ~40 deg-a-side V, a ~12 deg S-curve (wave
  amplitudes 1.5x); the sheet shows Swim f29 (the S reads there; f19 is a C). (6) A light-grey #C7C3BD ring
  (~0.045 stud) round each eye; the "w" smile 1.5x and ~0.06 stud thick; whisker dots 1.3x (r 0.021 m, as big as
  fits between the nose and the smile); nose block 20 % smaller, top edge kept, rounder corners; neck ~10 % wider at
  the torso with one shallow 4 % crease (y -0.645, `seal_shape.folds`).
  LODs decimate with X symmetry (`lod_symmetry`): the flat panels otherwise lost 15-18 % UV area at LOD2.
  adsheet.py: a pose entry may carry a frame, `(name, fn, frame)`, set on every scene before the shot (r4's fix,
  moved out of the temp script).
- **validate: PASS** (78 checks, 0 failed, 0 waived). **zfight:** 0 visible pairs (collect()/analyse(), 6 LOD meshes).
- **Tris:** LOD0 9,064 (Body 5,880 / Head 3,184) / LOD1 3,620 / LOD2 904. **Dims:** 2.750 x 7.572 x 2.787 studs
  (unchanged; DIMS_M matches the build).
- **RIG:** RIG_Seal 16 bones, 5 clips; RIG FBX exported in session (export_rig.py settings, window temp_override,
  1.46 MB, all five A_Seal_* stacks in the file). No read-back import.
- **Sheet:** build/status/2026-11-01/perfect/animals/M_Ani_GreySeal/r5_sheet.png (+ _small); poses Swim f29 / HaulOut f22.

- **r4 (2026-11-01, AD r3 8.1 fix list, all six):** (1) Three clean zones: body #776A60 clean mid stone grey, belly /
  throat / muzzle #F2E8D0 cream, flippers #3B332D charcoal-brown with #2E2823 tips, seam line #4A4038; dapples
  #5A4F47 hard-edged, 4 a side mirrored (0.42-0.57 stud) + 2 on the crown. Checked at game distance on sea and grass.
  (2) A bevelled 1x3 brick plate (#6A5E55, 0.15 stud proud, follows the back) with three studs 0.6 across, 0.27 tall,
  crisp lip. (3) Hips-to-nose section boxier (superellipse p 0.52); skull 8 % narrower with a rounded back edge, neck
  ~15 % wider so the head flows out of it. (4) Poses: Swim level with a slight nose-down tilt, fore-flippers swept
  back 22 deg, hind fan spread 12 deg a side; HaulOut f22 a banana (neck/head ~25 deg over the rest arch, fore-flippers
  planted, tail + hind flippers up ~18 deg). Sheet bug fixed: the render takes the window scene's frame, so r3 drew
  frame 1 (the streamline) for both poses; the sheet now sets every scene's frame. No fore-flipper vertex above the
  chest in any clip (checked every 3rd frame). (5) Eyes r 0.081 m (90 %), 0.1 stud clear of the nose and muzzle, a
  second catch-light; muzzle box 1.15x (grown down); a single "w" smile under the nose; 3 larger whisker dots a side.
  (6) Flippers, muzzle box and nose are rounded-rectangle sections (`seal_shape.rr`) with 0.06-0.075 stud bevels; fore
  flippers 1.3x thicker. UVs: flipper/box rings spaced by arc length (`ring_tus`, the paint uses the same table) and
  the muzzle front is its own planar-mapped region (MUZZLE_F), so LOD2 keeps its UV area (a cylindrical front disc
  failed the LOD UV check).
- **validate: PASS** (78 checks, 0 failed, 0 waived). **zfight:** 0 visible pairs (collect()/analyse(), 6 LOD meshes).
- **Tris:** LOD0 8,872 (Body 5,688 / Head 3,184) / LOD1 3,548 / LOD2 885. **Dims:** 2.750 x 7.572 x 2.787 studs.
- **RIG:** RIG_Seal 16 bones, 5 clips; RIG FBX exported in session (export_rig.py settings, window temp_override,
  1.46 MB, all five A_Seal_* stacks in the file). Read-back import skipped (it crashed Blender in r3).
- **Sheet:** build/status/2026-11-01/perfect/animals/M_Ani_GreySeal/r4_sheet.png (+ _small); poses Swim f19 / HaulOut f22.

- **r3 (2026-11-01, AD r2 7.4 fix list, all six):** (1) Palette pushed warm so it RENDERS warm under the sheet's blue
  sky (albedo #7D766E rendered cool #909497 on teal water): coat #8A7B6B, five flat hard-edged dapples #61554B (0.6-0.9
  stud, back/flanks only), cream belly/throat/muzzle #F5EDDF, flippers #4E453E with #40382F tips, studs #776B5F;
  saddle dropped. (2) Eyes r 0.090 m (1.32x) moved off the top corners onto the skull's flat face plane above the
  muzzle (~2/3 of the ball proud), dark ring where they meet the face, catch-light turned to the front.
  (3) Skull box 1.25x (superellipse p ~0.54, ~0.1 stud bevel) ending in a flat face; a separate cream muzzle box
  0.9 x 0.6 studs, 0.5 out (lofted with the flipper code, MUZZLE spec), black nose block 0.47 x 0.28 studs (NOSE spec),
  3 whisker dots a side, painted smile; the lower muzzle box is the Jaw (bone moved to the mouth line). (4) Taller
  S-curve: BEND_UP 42 deg, BEND_BACK 24 deg (muzzle bottom ~1.3 studs above ground); fore flippers 1.22x long / 1.25x
  wide, hind fan ~2 studs across, harder bevels (FLIP_SQ 0.42). STREAMLINE/HaulOut f1 retuned: Swim head/neck/chest
  pitch matches r2 (-1.6 / 3.1 / 1.5 deg); no fore-flipper vertex rises above the chest in any clip. (5) Studs 0.66
  across, 0.27 tall, 0.05 bevel lip, at hips/mid/shoulders; flatter back (section p 0.64); the belly cell is stepped
  in 6 % (~0.05 stud) at the grey/cream seam (seal_shape.SEAM_*), dark seam line on the step. Paint fix: the texture
  now maps UV tu through the station table (loft and flipper/box regions), so paint lands on the geometry exactly.
  (6) adsheet.py: bounds from evaluated matrices (the settle move was stale, which pushed the close-ups off-centre),
  close-up camera aimed from its own quaternion, near clip 0.01.
- **validate: PASS** (78 checks, 0 failed, 0 waived). **zfight:** 0 pairs (collect()/analyse(), 6 LOD meshes).
- **Tris:** LOD0 8,152 (Body 4,920 / Head 3,232) / LOD1 3,260 / LOD2 814. **Dims:** 2.739 x 7.452 x 2.748 studs
  (r2 2.418 x 7.618 x 2.178; taller head arch, wider fore flippers). DIMS_M updated.
- **RIG:** RIG_Seal 16 bones, 5 clips; RIG FBX re-exported in session and read back: 2 meshes,
  16 bones, 5 animations, 8,152 tris. Live-session note: importing the FBX into a second scene (switching
  window.scene) crashed Blender; import into the current scene (window temp_override) instead.
- **Rendered colour:** coat ~#8E8C89 in the 3/4 close-up, reads warm taupe on teal water next to the cool grey figure.
- **Sheet:** build/status/2026-11-01/perfect/animals/M_Ani_GreySeal/r3_sheet.png (+ _small); poses Swim f19 / HaulOut f22.

- **r2 (2026-11-01, AD r1 6.6 fix list, all six):** the game shows the static rest mesh, so the rest pose is now the
  haul-out arch: `seal_shape.bend()` lifts head and chest (28 deg up through chest/neck, 12 deg back over the head;
  chin ~1.0 stud above the belly line), applied to the vertices and bones (weights and paint stay in straight space).
  (1) Palette: coat #6E7378, darker back saddle #5D6267, belly/muzzle #D9DDE2 with a thin #4A4E53 bevel line, flipper
  tips #474B50; spots removed; roughness 0.55 (no glossy spine streak). (2) Fore flippers: flat paddles (chord
  horizontal) ~1.2 x 0.6 x 0.3 studs out of the body, splayed ~26 deg out and down to prop the chest. (3) Hind: thick
  (0.3-0.35 stud) bevelled wedges in a V, ~1.7 studs across. (4) Head sections +15 % with a neck dip, blockier
  (superellipse), a soft stop into a squared muzzle block with a flat front face; eyes r 0.068 m (1.35x), nose pad
  1.4x. (5) Banana arch; Swim clip streamlines it (STREAMLINE: neck/chest down, fore-flippers tucked), HaulOut rises
  from that to the rest pose. (6) Three spine studs (0.5 stud across, 0.15 tall). HaulOut shards fixed: fore-flipper
  X turns were positive (tips swung up through the back); now they plant (negative X), Flee likewise; checked, no
  fore-flipper vertex rises above the chest in any clip.
- **validate: PASS** (78 checks, 0 failed, 0 waived). **zfight:** 0 pairs (collect()/analyse(), 6 LOD meshes).
- **Tris:** LOD0 9,064 / LOD1 3,624 / LOD2 905. **Dims:** 2.418 x 7.618 x 2.178 studs (r1 1.748 x 7.796 x 1.484:
  +0.69 tall from the raised head, +0.67 wide from the splayed fore flippers; the body is still 1.75 wide). DIMS_M
  updated to the pose.
- **RIG:** RIG_Seal 16 bones (flipper bones now run down the new blade axes; all bones follow the bend), 5 clips;
  RIG FBX re-exported in session and read back: 2 meshes, 16 bones, 5 animations, 9,064 tris.
- **Live-session note:** run.py's template open_mainfile leaves a stale context in the same MCP call; open the
  template in one call, then call run.run() with open_scene stubbed in the next.
- **Sheet:** build/status/2026-11-01/perfect/animals/M_Ani_GreySeal/r2_sheet.png (+ _small); poses Swim f19 / HaulOut f22.

- **r1 (2026-11-01, toy pass, PERF-BL8):** refined to a Lego-toy seal, same shape, size, RIG_Seal bones and clips.
  Flat blue-grey plastic coat with a few soft painted spots (no mottle, scars or skin noise), clearly lighter belly and
  muzzle block, rounded-box (superellipse) body/head sections, a squared bevelled muzzle with whisker-pad dots, black
  nose pad and a short smile; big glossy black bead eyes (r 5 cm, forward on the brow) with a white catch-light (right
  eye mirrored so both share it); chunky slab flippers (1.6x thicker, fore 15% bigger) with darker tips; a bevelled
  Lego stud on the lower back. Whisker prisms and the 20 claw cones dropped (unreadable at game distance).
- **validate: PASS** (78 checks, 0 failed, 0 waived: the old LOD UV waiver is gone with the claws/whiskers).
- **zfight:** 0 visible pairs (run.py fix + in-session collect()/analyse() over all 6 LOD meshes).
- **Tris:** LOD0 8,920 / LOD1 3,566 / LOD2 889 (budget 12,000 / 4,800 / 1,440).
- **Sets:** T_Seal_Coat 2048, T_Seal_Face 1024 (ALB/NOR/RGH/MET + _Wet twins). 2 sets.
- **Dims:** 1.748 x 7.796 x 1.484 studs.
- **Rig/clips:** RIG_Seal, 16 bones, A_Seal_Swim / Surface / Look / HaulOut / Flee; RIG FBX re-exported in the live
  session (export_rig.py settings, window temp_override) and read back: 2 meshes, 16 bones, 5 animations, 8,920 tris.
  posepass.py not re-run (its read_factory_settings would kill the MCP add-on); the AD sheet poses row shows Swim / HaulOut.
- **FBXs:** LOD0-2 + RIG in build/prod/M_Ani_GreySeal/fbx/M_Ani_GreySeal/.
- **Game code:** WildlifeController finds the head part by name ("head"): M_Ani_GreySeal_Head_* names unchanged.
- **Sheet:** build/status/2026-11-01/perfect/animals/M_Ani_GreySeal/r1_sheet.png (+ _small).
- **Open issues:** HaulOut head lift is subtle at frame 34 (clip unchanged); spots are faint by design.
