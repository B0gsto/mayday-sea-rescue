# M_Veh_RIB
dims_m: 2.85 x 8.44 x 3.0
Reference: Atlantic 85-class inshore lifeboat (generic details, not a replica).
- Length overall 8.44 m (RNLI page says nearly 8.5 m); beam 2.85 m; draught about 0.53 m.
- Displacement about 1.8 t (mass); crew 4; top speed about 35 kn.
- Twin Yamaha outboards, about 115 hp each (per fact sheets; verify).
- Height to A-frame top: about 3.0 m (verify); tube diameter about 0.5 m (verify).
- Studs at 1 stud = 0.28 m: 30.1 x 10.2 studs (row says 25 x 8.5; see note).
Note: the row's 25 x 8.5 studs implies about 3 studs/m, not Roblox's 3.57 studs/m. Decide the scale before validate.
Sources:
- https://en.wikipedia.org/wiki/Atlantic_85-class_lifeboat
- https://rnli.org/what-we-do/lifeboats-and-stations/our-lifeboat-fleet/b-class-lifeboat
V2 (2026-10-17): dims_m reordered to the pipeline axes (X beam 2.85, Y length 8.44, Z keel to radar top 3.0); the earlier
line had length first. Scale is 3 studs per metre (tools/blender/common.py, Spike 1 measured; VehicleConfig.RIB.hullSize
8.55 x 3.3 x 25.3 uses the same). Overall length in the model includes the outboard cowls (about 2.5% over 8.44 m).
