# M_Veh_RescueHeli (2026-11-01, Opus 5.5, Blender MCP, 4 AD rounds)

Lego coastguard rescue helicopter. Validate PASS; zfight 0 visible. Each LOD holds Body, MainRotor, TailRotor
meshes (Builder welds *MainRotor*/*TailRotor* to the spinning RotorHub/TailHub). LOD0 tris: body 9,730, main rotor
3,580, tail 280; LOD1 9,554; LOD2 2,678. One flat-colour set T_RescueHeli_Lego (NOR/RGH/MET = Depot palette bytes).

Ids: LOD0 116855230983785, LOD1 124913578377799, LOD2 124542949894576; ALB 129013036076823 (Reviewing at upload).
Attachments: ATT_MainRotor, TailRotor, DriverSeat, PassengerSeat1, EyePoint, WinchPoint, WinchHook,
SurvivorSlot1/2, PetSeat, Camera. Greybox stays as physics + fallback.

AD (bar 9.1): r1 7.0, r2 8.0, r3 8.3, r4 8.8. Below the bar after the 4-round cap; ships as the best round
(greybox in game scored 6.2). r5 list: build/status/2026-11-01/perfect/M_Veh_RescueHeli/r4_AD.md (main checkout).

Known: livery recolour not applied (single-material mesh); the modelled hoist cable/hook overlaps the runtime
cable at WinchPoint. Not seen in Studio (owner Studio stop).
