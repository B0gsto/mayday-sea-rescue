# M_Bld_BoathouseAddons result (docs/25, 2026-10-27, art-director round 3)

Validate PASS (356 checks, 0 failed, 67 waived: gameplay node/layer naming, flat-palette LOD UV layout).
LOD0 7,894 tris / 7 visual meshes (budget 8,000): L01_Deck 1,864, L02_QuayEdge 452, L03_Ramp 204, L04_Roof 3,012,
L05_ReadyRoom 1,000, L06_Launch 1,102, L07_Lifeboat 260; LOD1 3,943, LOD2 1,970; COL 32 boxes x 12 tris, all in the
LOD0 FBX. Set: 1 (T_Boathouse_Brick, 16-cell flat palette, 1024; cell 8 is go-lamp green).
Size 79.75 x 14.55 x 33.35 studs (x -27.75..52.00, y -47.55..-33.00, z -4.80..28.55). Origin the code boathouse's
ground centre, built at its final 1.2 scale (no extra scale). Sea = +x, plaza = -x, cove = -Y.

## Island fit (fit_check.py, PASS)
Game frame: right = -80 - y, fwd = 58 + x (Boathouse spot isle(-80, 58, -90), Blender X flips on export). Extents:
visual right -47.00..-32.45, fwd 30.25..110.00; COL right -46.20..-32.60, fwd 30.40..110.00; ATT right -42.4..-39.0,
fwd 38.5..100. Every box is on the plate or over the cove water, clear of the cove walk (right -56..-48), the code
boathouse plinth, the code slip and its slipway, the Harbour pontoon (right -32..-24: 0.45 stud clear), the Jetty lot
and head deck, and every other DockConfig lot. The pontoon caps the bay's depth at 12 studs.

## Round 3 changes (AD 7.5, fixes in priority order)
1. Lifeboat: the trolley moved from the covered pad to the top of the slipway (1..12 studs down the slope from the
   head, tilted with it, mostly past the roof end) so front and high views see it. It carries an orange-and-white Lego
   lifeboat (orange hull, white gunwale deck, white wheelhouse with a navy window band, orange studded roof, navy
   transom band, white foredeck studs), bow to the sea, as its own mesh `Lv3_L07_Lifeboat`. Trolley: yellow bunks
   on black wheels, grey cross members, red bow stop, yellow hook eye; the winch cable now runs out to it.
2. Roof: three stepped sections (ends eave 13.5 / ridge 18.5, middle x -7..18 eave 15 / ridge 20.5), each ringed by a
   white fascia band up its first course and across both gable feet; columns are 1.5 (ends) and 3 (middle) taller.
3. Go lamp on a white mast with two red bands rising from the sea-end ridge (lamp centre z 26, top 28.6, 8 above the
   highest ridge); green lenses face both the sea and the quay.
Budget: deck plank butt joints every 9 studs (was 5.2) pays for the boat and mast.

## Parts
Nodes (layers bottom to top): `Lv3` (`L01_Deck`, `L02_QuayEdge` = the kerb, `L03_Ramp`, `L04_Roof`, `L05_ReadyRoom`,
`L06_Launch` = winch, trolley, lamp mast, cable, `L07_Lifeboat`). Collision: one box per object, `Lv3_Col01_COL`..
`Lv3_Col32_COL` (deck, kerb, room walls/stubs/header, bench, winch, six ramp steps, three roof sections, 12 columns,
one tilted box round the lifeboat and trolley). Attachments: ATT_Launch (42.0, -41.0, ramp; now under the static
boat), ATT_Work_Winch (10.0, -37.6, 0.55), ATT_ReadyRoom (-19.5, -41.0, 0.55).

Renders: `build/prod/M_Bld_BoathouseAddons/review/M_Bld_BoathouseAddons/2026-10-27_sheet.png` plus turntable and five
close-ups (ready_room, winch, lifeboat, go_light, roof); levels sheet `levels/levels_sheet.png` (copy:
`sheet_levels.png` here) with grey Lv1/Lv2 stand-ins at their game positions and a grey pontoon.

Open: not playtested in Studio or wired into the game; not in `src`, docs/12 or `art/reference/M_Bld_BoathouseAddons/dims.md`.
Code launching a spawned boat should hide `Lv3_L07_Lifeboat` (and its COL box Lv3_Col32) meanwhile. The ramp's top ends
at z -4.2 (0.2 under sea level). Jetty-head and slip footprints in fit_check are estimated from DockConfig/DockPieces/
RingLayout, not read from Studio. Code placing the asset must use the boathouse's CFrame with no extra scale or mirror.
Awaiting the art-director round.
