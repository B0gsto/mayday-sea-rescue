# M_Veh_LifeguardPickup — result

**Validate: PASS** (385 checks, 0 failed, 20 waived: 14 *LOD UV layout*, 6 LOD2 *geometry* — collapse decimation of
small seal, plate and tread islands). `check_textures.py`: 116 of 120 rows pass.

- LOD0 **26,717** tris (row 30,000), LOD1 **9,339**, LOD2 **2,670**; `_COL` 52 tris. Real size 1.94 x 5.52 x 1.97 m
  (x +4.7 % door mirrors, y +3.4 % board overhang, inside the 5 % free band; z +8.4 % light bar, size_note).
- 4 sets, all `_Wet`: Body 4096, Cab 2048, Wheels 4096, Rack 2048 (58 to 79 px/stud, standard tier).
- 30 attachments: `ATT_Wheel_FL/FR/RL/RR` (physics hubs), `ATT_DriverSeat`, `ATT_Seat2..5`, `ATT_EyePoint`,
  `ATT_LightBar`, `ATT_Beacon_01..04`, head / tail / brake / reverse lamps, `ATT_TowHitch`, `ATT_Board`,
  `ATT_KitLocker_L/R`, `ATT_WorkLamp_L/R`, `ATT_DriveAttachment` (the Builder chassis root; `frame_offset.json`
  holds the offset and bbox).
- Bevelled panel body with arch flares, RHD cab interior, tinted glass (front windows down), four separate wheel
  meshes, underbody, bed rack and board, kit lockers, amber rotator bar; salt, rust and edge wear baked.
- Open: no reference photos (dims.md only); Studio preset row pending; 3 NOR rows (98.0 to 98.7 % vs 99 %) and
  1 Rack metal-albedo row (177 vs 180) fail on island-border and pad blends, not on orientation (red 0.50, green 0.50).
