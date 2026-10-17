--!strict
-- Car units: real-world numbers (metres, kg, N, N m) to the project's scale (docs 05 section 4.1,
-- docs 02 section 4.2). 1 m = 3 studs; 1 RMU = 1 stud^3 of water = 37 kg (as VehicleConfig);
-- gravity 9.81 m/s^2 = 29.43 studs/s^2. Force unit: RMU stud/s^2; torque: RMU stud^2/s^2.
local Units = {}

Units.M = 3 -- studs per metre
Units.KG = 1 / 37 -- RMU per kg
Units.N = 3 / 37 -- force units per newton (1 kg m/s^2 = 1/37 RMU * 3 studs/s^2)
Units.NM = 9 / 37 -- torque units per newton metre
Units.KMH = 3 / 3.6 -- studs/s per km/h (0.8333)
Units.G = 29.43 -- studs/s^2 (Workspace.Gravity)
Units.RPM = 2 * math.pi / 60 -- rad/s per rpm
Units.AIR_DENSITY = 1.225 -- kg/m^3

-- Aerodynamic drag coefficient k so that drag = k * v^2 (v in studs/s, force in game units)
-- for a frontal drag area cdA (m^2): 0.5 rho cdA (v/3)^2 newtons.
function Units.dragK(cdA: number): number
	return 0.5 * Units.AIR_DENSITY * cdA / (Units.M * Units.M) * Units.N
end

return Units
