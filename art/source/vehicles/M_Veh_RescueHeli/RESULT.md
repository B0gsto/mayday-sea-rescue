# M_Veh_RescueHeli (2026-11-01, Opus 5.5, Blender MCP, 8 AD rounds)

Lego coastguard rescue helicopter. Validate PASS; zfight 0 visible (all LODs). Each LOD holds Body, Paint (the orange
shell), Glass (r7), Gear (r8: skids + winch), MainRotor, TailRotor meshes (Builder welds *MainRotor*/*TailRotor* to the
spinning RotorHub/TailHub, the rest to HullRoot). LOD0 tris: body 7,996 + paint 1,996 + glass 220 + gear 5,100, main rotor
2,744, tail 280 (18,336); LOD1 13,148; LOD2 3,360. AssetLoader.PART_SETS has the Gear = "Lego" row. Sets:
T_RescueHeli_Lego (flat palette) + r7 T_RescueHeli_Glass (RGBA tint, alpha 150; NOR/RGH/MET = the same Depot bytes).
r7 Glass set: AssetLoader.PART_SETS row + gen_asset_ids ALPHA_TRANSPARENCY_SETS (M_Veh_RescueHeli, Glass); upload.sh
uploads every map in assets/textures (copy build/prod textures + fbx into assets/ first).

Ids (r8): LOD0 134981220202490, LOD1 119938875844656, LOD2 73201580130072; Lego ALB 78317319857460; Glass ALB 93793360278467, NOR 134063939343985, RGH 77394710200809, MET 82741558542658. ATT_WinchHook now (7.9, -0.25, 2.8).
Attachments: ATT_MainRotor, TailRotor, DriverSeat, PassengerSeat1, EyePoint, WinchPoint, WinchHook,
SurvivorSlot1/2, PetSeat, Camera. Greybox stays as physics + fallback.

AD (bar 9.1; 3 Opus ADs, median): r1 7.0, r2 8.0, r3 8.3, r4 8.8, r5 8.9, r6 9.0, r7 9.0, r8 9.15 PASS (each round won pairwise;
anchors BoardKit r4 9.2 + HQ r6 9.22 from r7). Ships r8. Sheets + r7_AD.md / r8_AD.md (r8 polish list): build/status/2026-11-01/perfect/
M_Veh_RescueHeli/r5..r8_sheet.png (main checkout).
r5: white rear clamshell doors (charcoal split, orange crosses, red/green tail-light studs, yellow handles), charcoal
strut collars, 2x2 rotor hub (was 3x3) with a 1x1 tower. r6: white stabiliser endplates 40% lower with orange
studded caps, crosses 2x, bigger tail lights, charcoal rear skid caps, solid yellow stowed ring (R 0.95).
r7: boom white upper half + charcoal tail bands, fin white top with orange crosses; one big door cross (split runs
through it) + c_rear still; blades 25% narrower (2x4 tips); see-through windscreen over a dash, two seats and a minifig
pilot; ring 28x10; LOD1/2 coplanar spots fixed. Sheet r7_sheet.png (9.0).
r8: framed recessed rear leaves (white rims, hinge plates, raised cross plate under a charcoal boom collar, handles
outside its arms); ring smooth-shaded (lego.torus emitted flat faces: the root cause) at 48x12, 0.4 aft; tinted side
and door glass over a grey wall + seat back; white boom (orange underside only), 0.3 charcoal bands, stabiliser caps
white with orange tips; glass roughness 0.5 (no hotspot); 2-stud blade tiles, tips 1.5 long; domed 24-sided lamps and
skid caps. Sheet r8_sheet.png.

Livery: the orange shell is its own MeshPart (M_Veh_RescueHeli_Paint_LOD*, LiveryPaint.MESH_RULES primary, map-only
template in Cosmetics/Liveries/Appearances), so a bought livery recolours it like the greybox's Paint = "Body".
Winch: no modelled cable (VehicleService draws it from ATT_WinchPoint); hook block + ring hang stowed under the drum
(ATT_WinchHook 7.9, -0.25, 2.4). Not seen in Studio (owner Studio stop).
