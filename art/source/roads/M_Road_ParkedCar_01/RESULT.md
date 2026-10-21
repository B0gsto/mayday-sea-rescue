# M_Road_ParkedCar_01 — result (round 2: shared smooth-shell method)

**Validate: PASS** (290 checks, 0 failed, 13 waived: LOD UV layout after collapse decimation). FBX and contact sheet regenerated in `build/prod/M_Road_ParkedCar_01`.

`cargeo.py` (shared by _01.._03) gained the smooth-body method:
- `spline` (monotone cubic profiles; the old per-segment smoothstep terraced bonnet and roof), `refine_rings` / `smooth_loft` (Catmull-Rom sections and extra stations only where the shape bends; the _HP is lofted ~10x denser so the baked normal map carries a smooth surface onto LOD0).
- `Snap` / `Strip` / `flush_lamp`: lenses, grilles and shut lines laid flush on the shell as built, sampled finer across creases; reflectors, projectors, DRL and light guides sit in an _HP recess baked onto the lens.

On this car: shell and canopy use `smooth_loft`; swept headlamps and hatch-corner tail lamps are flush lenses wrapping the wing / quarter; slim upper grille flush with a chrome bar; hatch shut lines moved inboard of the lamps; arch lips and tread sipes are _HP-only (baked).

- LOD0 **13,900** tris, LOD1 **4,855**, LOD2 **1,387**; `_COL` 24.
- 2 sets at 4096 (Body, Wheels). 4 attachments (`ATT_Wheel_FL/FR/RL/RR`) unchanged. Bbox 5.40 x 11.71 x 4.55 studs (unchanged); plates "GI15 KXR" kept.
- Open: Studio preset row pending; no reference photo; glossy lens facets at the hatch crease catch small hard-edged reflections.

## 2026-10-22 arch fix (re-uploaded)

Wheel arches are a real tunnel in the body shell (inner wall + roof at the arch curve, WheelWell-baked faces) instead of the thick liner block that buried the tyre and hung below the sill; underbody floor and rails narrowed clear of the tyres; wheels inset so the sidewall sits just inside the arch lip (HUB_X now 1.95). Validate PASS, LOD0 13976 tris. Sheet: assets/review/cars/contact.png (Opus art-director: SHIP). Open: tyre/rim LOD0 segment counts facet at ~5 m (no tri headroom on _02/_03).
