# M_Veh_Ambulance — result

**Validate: PASS** (421 checks, 0 failed, 27 waived: 24 *LOD UV layout*, 3 LOD2 *geometry* — collapse decimation of
beacon domes, grille and text islands). `check_textures.py`: 120 rows, 5 fail (see open).

- LOD0 **28,844** tris (row 30,000), LOD1 **10,085**, LOD2 **2,872**; `_COL` 44 tris, `_HP` 71,158. Real size
  6.91 x 20.42 x 9.10 studs = 2.30 x 6.81 x 3.03 m vs the row's 6.8 x 2.3 x 2.9 (PASS; Z 3.03 m is the box-roof
  beacons and vents over the 2.9 m box, `size_note`).
- 4 sets, all `_Wet`: Body, Box, Cab, Wheels (4096 each, 55 to 106 px/stud, standard tier).
- 32 attachments: `ATT_Wheel_FL/FR/RL/RR` (physics hubs, wheelbase 4.33 m, track 1.71 m), `ATT_DriverSeat`,
  `ATT_Seat2`, `ATT_EyePoint`, `ATT_RearDoor_L/R`, `ATT_StretcherLoad`, `ATT_HandoverPoint` (rear doors + 4.5
  studs, standing height), `ATT_SideDoor`, `ATT_LightBar`, `ATT_Beacon_01..08` (blue), `ATT_GrilleLamp_L/R`,
  head / tail / brake / reverse lamps, `ATT_DriveAttachment` (Builder chassis root; `frame_offset.json`).
- Invented "Gale Isles Ambulance" livery: white, high-vis yellow/green chequer bands, mirrored "AMBULANCE" on the
  front pod, the Cottage Hospital heart-over-waves roundel, no cross. Cab interior, high box windows, nearside
  sliding door, rear doors with windows, chevron rear, rear step, salt and road grime.
- Open: 3 NOR rows (95.6 to 98.6 % vs 99 %) and 2 metal-albedo rows (177 / 171 vs 180) fail on padding and grimy
  steel, as the LifeguardPickup does; no Studio preset rows; `LandVehicleConfig` handover offset is 15 studs.
