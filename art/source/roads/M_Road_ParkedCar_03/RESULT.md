# M_Road_ParkedCar_03 — result (round 2: shared smooth-shell method)

**Validate: PASS** (290 checks, 0 failed, 12 waived: LOD1/LOD2 UV layout after decimation; the single-sided canopy/load-box skins as before; a standby "UV faces" waiver for LOD2 collapse slivers). FBX and sheet in `build/prod/M_Road_ParkedCar_03`.

Same method as _01/_02 (shared `_01/cargeo.py`): body shell, cab canopy and load box use `smooth_loft` (monotone-spline profiles, Catmull-Rom sections, extra stations only where the shape bends, ~10x denser _HP baked into the normal map). The round chrome "eye" headlamp buckets are replaced by flush lenses wrapping the cab corners (reflector, projector, DRL and indicator baked from an _HP recess) and the upper grille is flush with a chrome bar. Door seams, livery text and stripe now snap to the smoothed panel. Arch lips and tread sipes are _HP-only (baked).

Kept: plain white paint, "GALE ISLE PLUMBING" / "01872 555 021" livery, plates "GI16 VNX", tall vertical tail lamps, barn doors, steel wheels.

- LOD0 **14,844** tris, LOD1 **5,192**, LOD2 **1,477**; `_COL` 24.
- Two 4096 sets (Body, Wheels); 4 wheel attachments unchanged. Bbox 5.90 x 13.23 x 5.58 studs (unchanged).
- Open: Studio preset pending; no reference dims/photos; a small white sliver of the shell shows below the front bumper end at the arch.

## 2026-10-22 arch fix (re-uploaded)

Wheel arches are a real tunnel in the body shell (inner wall + roof at the arch curve, WheelWell-baked faces) instead of the thick liner block that buried the tyre and hung below the sill; underbody floor and rails narrowed clear of the tyres; wheels inset so the sidewall sits just inside the arch lip (HUB_X now 2.16). Validate PASS, LOD0 14916 tris. Sheet: assets/review/cars/contact.png (Opus art-director: SHIP). Open: tyre/rim LOD0 segment counts facet at ~5 m (no tri headroom on _02/_03).
