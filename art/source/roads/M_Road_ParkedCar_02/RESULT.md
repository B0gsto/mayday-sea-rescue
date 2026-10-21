# M_Road_ParkedCar_02 — result (round 3: shared smooth-shell method)

**Validate: PASS** (290 checks, 0 failed, 14 waived — the existing LOD1/LOD2 UV-layout waiver). FBX and sheet regenerated in `build/prod/M_Road_ParkedCar_02`.

Round 3 (shared helpers in `_01/cargeo.py`, same method on all three cars):
- Body shell, canopy: monotone-spline profiles (no more smoothstep terraces), Catmull-Rom sections and stations added only where the shape bends (`smooth_loft`); the _HP is lofted ~10x denser so the baked normal map carries a smooth surface. Arch lips and tread sipes are now _HP-only (baked).
- Headlamps, tail lamps, grille: lenses laid flush on the panel (`Snap` / `Strip` / `flush_lamp`), headlamp wrapping the wing, tail lamp wrapping the tailgate corner onto the quarter plus a D-pillar lens; reflectors, projectors, DRL and light guides sit in an _HP recess baked onto the lens, dark shut line round each.
- Paint bakes at **110,14,20** (was 122+): metal 0, clear-coat roughness 0.25, flake bump; dark trims lifted to luma 34 and no AO in the Body albedo, so the bake's albedo floor no longer lifts the whole set.

- LOD0 **14,658** tris, LOD1 **5,119**, LOD2 **1,458**; `_COL` 24.
- 2 sets at 4096 (Body, Wheels); 4 wheel attachments unchanged. Bbox 5.78 x 14.00 x 4.47 studs (unchanged).
- Open: Studio preset row pending; no reference photos; the D-pillar lens sits on a tight canopy curve and its outline reads a little ragged close up.

## 2026-10-22 arch fix (re-uploaded)

Wheel arches are a real tunnel in the body shell (inner wall + roof at the arch curve, WheelWell-baked faces) instead of the thick liner block that buried the tyre and hung below the sill; underbody floor and rails narrowed clear of the tyres; wheels inset so the sidewall sits just inside the arch lip (HUB_X now 2.18). Validate PASS, LOD0 14746 tris. Sheet: assets/review/cars/contact.png (Opus art-director: SHIP). Open: tyre/rim LOD0 segment counts facet at ~5 m (no tri headroom on _02/_03).
