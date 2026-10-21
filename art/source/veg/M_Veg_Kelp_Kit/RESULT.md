# M_Veg_Kelp_Kit (M_Veg_Kelp_01 to _04) — result

**Validate: PASS** (125 checks, 0 failed, 6 waived: *LOD UV layout* — LODs rebuild from the same straps
with fewer segments/columns by design, every LOD samples the same atlas cell).

- Blade mass now dominates: each plant carries a broad ruffled palm (lamina) off the stipe top that
  splits into 11 to 14 long straps, 7 to 10.5 cm wide and 1.0 to 1.5 m long — as long as or longer than
  the stipe. Fewer, wider, longer straps; triangles moved out of the stipe into the blade.
- Pose: the strap bundle leaves the crown together, low and downstream, and arcs over into the flood as
  one overlapping wet-mop/ponytail mass that sags and clumps, not a radial palm crown.
- Stipes: `_01` 0.95 m, `_02` 0.45 m flexible arched stipe with the palm lying almost flat on the rock
  (L. digitata), `_03` 1.35 m, `_04` twin 1.05 / 0.85 m from one holdfast.
- Holdfast rock rebuilt as a lumpy, noise-displaced rounded granite boulder (30-column dome, no facet
  ring), with six root-like haptera hugging its curve and flaring onto the stone.
- Colour kept (olive-brown/golden-brown, no green), palette, `ATT_Holdfast_01..04`, Sway vertex colour,
  atlas cell rules and names unchanged.
- LOD0 **5,952** tris (**1,375 / 1,487 / 1,495 / 1,595** per plant; ceiling 6,000), LOD1 2,296,
  LOD2 1,400. Heights 1.22 / 0.62 / 1.78 / 1.36 m; bases at Z 0 on the 2 m display line.
- Build emits its own LOD1/LOD2, so runs use `build,validate,export,turntable` (the `lod` decimate step
  would double-create them). FBX re-exported to `build/prod/M_Veg_Kelp_Kit/fbx/`; textures in
  `build/prod/M_Veg_Kelp_Kit/textures/`.
- Open: no `art/reference/M_Veg_Kelp_Kit/dims.md`; Studio presets and in-engine sway still pending.
