# M_Prop_JettyCrane: perfect pass (docs/28), 2026-10-31 / 11-01

Bar: median of 3 fresh Opus ADs scores 9.1+. **Reached: r11 shipped (median 9.1: 9.1/9.1/9.1, all better than r10 9.0).**
Shipped r11 (2026-11-01, FIN5): LOD0 71490822192410, LOD1 134456974048052, LOD2 135932892587615 (was r10:
84626608435007 / 119405138772748 / 110631269589818; r8: 105813117125800 / 73207410742283 / 135397079542887;
r3: 131828506127675 / 86006746697409 / 73426253708503). ATT_Lamp_Cab +0.2 (deck +0.2), ATT_Lamp_JibTip unchanged:
`DockPieces.slipCrane` hangs amber NightLamp bulbs on them.

| Round | AD score | Main notes |
|---|---|---|
| r1-r2 | 6.5 / 7.6 | see git log |
| r3 (was live) | 8.3 (in-game sheet) | thin jib, flat bracing, cab lost, thin rope, dark at dusk |
| r4 | 8.3 | kinked diagonals cutting frames, matte clay, hook through ring |
| r5 | 8.7 | faceted hook, plain hook block, polygonal studs, hard edges |
| r6 | 8.7 | sheave read as a washer, roof studs off-grid, flat glazing, no slewing ring |
| r7 | 8.7 | hook-block crease (coplanar dome caps), latch stub, frame nubs, no jib heel pin |
| r8 | 8.8 | red band as two slabs on the hook block, first jib stud into the cab frame, clutter under the cab, cab/lamp small at phone size |
| r9 | 9.0 (3 ADs: 9.0/9.0/9.0) | budget class rock capped at 10,000 tris (large_prop's 8,000 was the limit); one wrap-round hook band, studs clear of the cab, smooth slew ring, cab +10%, taller lamp. Left: plain slew slab, off-grid roof studs, thin mast at phone size |
| r10 | 9.0 (9.0/9.0/9.0, all: a touch better than r9) | regular 2x3 roof studs + lamp front-centre, mast chords +20% / braces +15%, jib top chord +20%, grooved slew ring. Left: groove does not read (ring wider than the mast, deeper dark gap), thin jib at 64 px (yellow lower chords or a walkway), brace-end nodes |
| r11 (shipped) | 9.1 (9.1/9.1/9.1) | mast-wide light races with a 0.6-deep black groove + dark floor (deck +0.2), yellow lower jib chords 1.0x0.8 (were white 0.75), braces 0.6, white gusset plates on mast nodes, white collars on jib lower-chord nodes, slew-ring close-up. 8510 tris, validate PASS, zfight 0 |

r11: LOD0 8,510 / LOD1 3,402 / LOD2 1,274 tris (rock 10,000), sheet build/status/2026-11-01/perfect/M_Prop_JettyCrane/r11_sheet.png.
r10: 7946 / 10000 tris (budget rock, asset row 10000), validate PASS, zfight 0 visible pairs.
r8: 7926 / 8000 tris, validate PASS, zfight 0 visible pairs left. Sheets and close-ups (cab, jib root, hook, base):
build/status/2026-10-31/perfect/M_Prop_JettyCrane/ (r4-r10, M_Prop_JettyCrane_r8.blend).

Open (r11 ADs): slew deck still a flat sharp slab (bevel + studs), groove could be ~1.5x taller, small base pad
(outriggers), stray dark strip right of the ring; LOD1/LOD2 FBX zfight not checked. Not checked in Studio: the lamp
bulbs and the new mesh in game.
