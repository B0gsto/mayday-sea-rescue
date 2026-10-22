# M_Veh_LighthouseCruiser — result

**Validate: PASS** (326 checks, 0 failed, 15 waived: texel density on wheel / underbody parts at 1024 ship maps, LOD
UV layout and LOD2 geometry from collapse decimation). LOD0 **29,904** tris, LOD1 10,459, LOD2 2,984; `_COL` hull.

- Built with `_CarPremium/carkit.py`; fascia raked 9 degrees above the bumper (`rake`). 4 sets, all `_Wet`, ship 1024
  (masters 2048): Body, Cab (5-seat interior + glass incl. panoramic roof), Wheels, Trim (grille, lamps, rails, roof
  bar, mirrors, hitch).
- Attachments: `ATT_Wheel_FL/FR/RL/RR` (wheelbase 2.92 m, track 1.66 m, radius 0.41 m = LandVehicleConfig
  .LighthouseCruiser), `ATT_DriverSeat`, `ATT_Seat2..5`, `ATT_EyePoint`, head / tail / brake / reverse lamps,
  `ATT_TowHitch`, `ATT_RoofLamp_01..04`, `ATT_DriveAttachment` (`frame_offset.json`).
- Review: assets/review/premium/cars.png, three art-director rounds (round-3 fixes applied, not re-reviewed).
- Open: roof-bar lamps are mesh only (no game light wired to ATT_RoofLamp_*); glass opaque from outside; no Studio
  preset shots; check_textures not run (red paint above the saturation ceiling, needs a signal mask).
