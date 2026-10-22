# M_Veh_HarbourGT — result

**Validate: PASS** (318 checks, 0 failed, 15 waived: texel density on wheel / underbody parts at 1024 ship maps, LOD
UV layout and LOD2 geometry from collapse decimation). LOD0 **28,286** tris, LOD1 9,896, LOD2 2,826; `_COL` hull.

- Built with `_CarPremium/carkit.py` (parametric skin, wheels, brakes, seats). 4 sets, all `_Wet`, ship 1024 (masters
  2048): Body, Cab (interior + see-from-inside glass), Wheels (4 wheels, static brakes, wells), Trim.
- Attachments: `ATT_Wheel_FL/FR/RL/RR` (wheelbase 2.65 m, track 1.62 m, radius 0.35 m = LandVehicleConfig.HarbourGT),
  `ATT_DriverSeat`, `ATT_Seat2`, `ATT_EyePoint`, head / tail / brake / reverse lamps, `ATT_DriveAttachment`
  (`frame_offset.json`).
- Review: assets/review/premium/cars.png, three art-director rounds (round-3 fixes applied, not re-reviewed).
- Open: glass is opaque from outside (single-sided, see-through from the cockpit); no Studio preset shots yet;
  check_textures not run (crimson paint is above the 0.45 saturation ceiling, needs a signal mask like the pickup's).
