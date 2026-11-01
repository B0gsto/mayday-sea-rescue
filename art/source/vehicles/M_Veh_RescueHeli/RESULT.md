# M_Veh_RescueHeli (2026-11-01, Opus 5.5, Blender MCP, 6 AD rounds)

Lego coastguard rescue helicopter. Validate PASS; zfight 0 visible. Each LOD holds Body, Paint (the orange shell),
MainRotor, TailRotor meshes (Builder welds *MainRotor*/*TailRotor* to the spinning RotorHub/TailHub). LOD0 tris: body 8,618 + paint 1,248,
main rotor 3,096, tail 280; LOD1 9,510; LOD2 2,678. One flat-colour set T_RescueHeli_Lego (NOR/RGH/MET = Depot palette bytes).

Ids (r6): LOD0 134104686361988, LOD1 140703481744638, LOD2 128057877179940; ALB 81237289705982 (palette cell 9 green).
Attachments: ATT_MainRotor, TailRotor, DriverSeat, PassengerSeat1, EyePoint, WinchPoint, WinchHook,
SurvivorSlot1/2, PetSeat, Camera. Greybox stays as physics + fallback.

AD (bar 9.1; 3 Opus ADs, median): r1 7.0, r2 8.0, r3 8.3, r4 8.8, r5 8.9, r6 9.0 (each round won pairwise).
Below the bar after round 6; ships r6 (greybox in game scored 6.2). Sheets: build/status/2026-11-01/perfect/
M_Veh_RescueHeli/r5_sheet.png, r6_sheet.png (main checkout).
r5: white rear clamshell doors (charcoal split, orange crosses, red/green tail-light studs, yellow handles), charcoal
strut collars, 2x2 rotor hub (was 3x3) with a 1x1 tower. r6: white stabiliser endplates 40% lower with orange
studded caps, crosses 2x, bigger tail lights, charcoal rear skid caps, solid yellow stowed ring (R 0.95).
r7 list: tail boom / fin still read as orange bars from the chase cam (white top half or charcoal bands); one big
cross across both doors + a c_rear still; blades 25% narrower; tinted glass with a pilot / seat; ring 24+ segments.

Livery: the orange shell is its own MeshPart (M_Veh_RescueHeli_Paint_LOD*, LiveryPaint.MESH_RULES primary, map-only
template in Cosmetics/Liveries/Appearances), so a bought livery recolours it like the greybox's Paint = "Body".
Winch: no modelled cable (VehicleService draws it from ATT_WinchPoint); hook block + ring hang stowed under the drum
(ATT_WinchHook 7.9, -0.25, 2.4). Not seen in Studio (owner Studio stop).
