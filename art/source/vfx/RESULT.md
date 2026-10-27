# VFX flipbooks (render.py, round 2)

Sheets are in `build/prod/vfx/<name>.png`, with the contact sheet at `build/prod/vfx/sheet.png`. Each sheet is 1024x1024 RGBA with straight alpha. Frames run left to right, top to bottom. Re-render with `~/RobloxProjects/tools/blender-run.sh art/source/vfx/render.py` (add `-- --only a,b` for some sheets, `-- --contact` for the contact sheet only).

| Name | Grid / cell | Use | ParticleEmitter (FlipbookLayout, Lifetime) |
|---|---|---|---|
| splash_crown | 4x4 / 256 | survivor pickup splash | Grid4x4, 0.7 s, 1 particle, Size 4->5 |
| droplets | 2x2 / 512 | chunky drops flung out | Grid2x2, RandomMode, 0.8 s, Size 0.8->0.3, gravity |
| foam_ring | 4x4 / 256 | foam ring on the water (top-down) | Grid4x4, 1.0 s, Orientation FacingCameraWorldUp/flat on water, Transparency 0->0.2 |
| puff_smoke | 4x4 / 256 | studded puff balls that pop (build dust) | Grid4x4, 0.8 s, Transparency 0 (no fade: the balls pop themselves), Size 5 |
| lego_plates | 2x2 / 512 | flat plates and tiles, RandomMode | Grid2x2, 1.2 s, spin and gravity |
| confetti_bricks | 2x2 / 512 | bricks and plates, RandomMode | Grid2x2, 1.5 s, RotSpeed 90..360 |
| coin | 4x4 / 256 | spinning coin loop | Grid4x4, loop |
| shockwave_ring | 4x4 / 256 | one chunky white ground ring (top-down) | Grid4x4, 0.8 s, flat on the ground, Transparency curve 0->0.5 |
| spin_streak | 2x2 / 512 | one arc, rotated by the emitter | Grid2x2, 0.5 s, RotSpeed 360..720; the 4 frames only change the sweep |
| rain_streak | 2x2 / 512 | rain, RandomMode | Grid2x2, 0.6 s, Speed 40..60 |

Round-2 changes:

- **droplets:** drops are about 80% of the old size, with at least 19% padding on every side.
- **foam_ring:**
  - The largest ring is about 85% of the cell, with at least 8.6% padding.
  - The blobs pop out over frames 10-16, so the last frames hold a sparse fade, not empty cells.
- **puff_smoke:**
  - 5 opaque studded balls: they grow in, shrink, then pop one after another (frames 12-16).
  - There is no alpha or blur fade; use the emitter's Transparency for that.
- **shockwave_ring:**
  - A single crisp band, about 3x thicker, growing to 84% of the cell. The white colour (#F4FBFF) is flat across the whole sheet, so there is no grey or orange fringe.
  - Frames 13-16 are semi-transparent (alpha 0.45 at the end). Tint with the emitter Color if you need it; no orange.
- **spin_streak:**
  - One arc with the same centre, radius and mid-angle every frame (90 degrees), so the frames do not jitter. Rotate it with the emitter.
  - Only the sweep length changes (100 / 124 / 150 / 124 degrees), and the glow arc that showed a grey rim is dropped.

Contact-sheet cell padding is printed by the renderer (`pad [...]`, as a fraction of the cell). Every fixed sheet has at least 8.4% on each side.
