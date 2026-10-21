# M_Veh_Coastguard4x4 — result

**Validate: PASS** (401 checks, 0 failed, 28 waived: 20 LOD UV layout, 8 LOD2 geometry — collapse decimation of thin
lettering, tread blocks, cables and straps). `check_textures.py`: 116 rows, 6 fail (4 NOR tangent-space padding,
2 metal-albedo 172/176 vs 180), the same bake-border pattern as the Ambulance and LifeguardPickup.

- LOD0 **28,919** tris (row 30,000), LOD1 **10,109**, LOD2 **2,879**; `_COL` 42 tris, `_HP` 64,426.
- Real size 2.06 x 5.21 x 2.36 m (width over mirrors, height to the beacon domes; the row's 4.6 to 5.3 m length is
  met including the rear-door spare).
- 4 sets, all `_Wet`: Body 4096, Rack 4096, Cab 2048, Wheels 4096 (52 to 131 px/stud, standard tier).
- 41 attachments: `ATT_Wheel_FL/FR/RL/RR` (physics hubs, wheelbase 2.794 m, track 1.486 m), `ATT_DriverSeat`,
  `ATT_Seat2..5`, `ATT_EyePoint`, door markers, `ATT_Winch`, `ATT_Snorkel`, `ATT_TowHitch`, `ATT_SpareWheel`,
  `ATT_RoofRack`, `ATT_Mast`, `ATT_Floodlight`, `ATT_RopeKit`, `ATT_Tripod`, `ATT_Stretcher`, light bar and
  `ATT_Beacon_01..06` (blue), head / tail / brake / reverse lamps, `ATT_DriveAttachment` (`frame_offset.json`).
- Invented Gale Isles livery: white body, navy lower panels, yellow/navy chequer, cliff-and-wave crest, lettering.
  High-roof station wagon, roof rack with stowed telescopic floodlight mast, rope bags, A-frame and stretcher,
  winch bumper, side steps, spare on the rear door, mud/salt wear.
- Open: no reference photos (`dims.md` absent); Studio preset rows pending; the 6 texture rows above.
