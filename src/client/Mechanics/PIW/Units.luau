--!strict
-- PIW/Units: the game's real-world scale and small flat-plane helpers shared by the Person in the
-- Water mechanics. Pure (Lune-tested in tests/MechPIW*.spec.luau).
-- Scale (docs 05 section 4.1, VehicleConfig): 1 m = 3 studs, gravity 9.81 m/s^2 = 29.43 studs/s^2.
local Units = {}

Units.STUDS_PER_M = 3
Units.KNOT = 1.543 -- studs/s (0.514 m/s)
Units.GRAVITY = 29.43 -- studs/s^2, the Workspace.Gravity the project designs for
Units.BODY_LENGTH = 5.4 -- studs, one adult body length (1.8 m): "arm's length" for a swimmer

-- The wind's push direction: WeatherController blows rain along (cos w, 0, sin w).
function Units.windVector(windDirection: number): Vector3
	return Vector3.new(math.cos(windDirection), 0, math.sin(windDirection))
end

function Units.flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function Units.flatDistance(a: Vector3, b: Vector3): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

function Units.unitOr(v: Vector3, fallback: Vector3): Vector3
	local f = Units.flat(v)
	if f.Magnitude < 1e-4 then
		return fallback
	end
	return f.Unit
end

-- Angle in degrees between two flat directions (0..180).
function Units.angleBetween(a: Vector3, b: Vector3): number
	local ua, ub = Units.unitOr(a, Vector3.xAxis), Units.unitOr(b, Vector3.xAxis)
	return math.deg(math.acos(math.clamp(ua:Dot(ub), -1, 1)))
end

-- A small deterministic hash of a string to 0..1 (casualty ids drive their profile and rhythm).
function Units.hash01(s: string, salt: number?): number
	local h = 2166136261 + (salt or 0) * 16777619
	for i = 1, #s do
		h = bit32.bxor(h, string.byte(s, i))
		h = (h * 16777619) % 4294967296
	end
	return (h % 100000) / 100000
end

-- Passage (docs 09 step 3): time against the best safe route.
function Units.routeRatio(elapsed: number, distance: number, cruiseSpeed: number): number
	local best = math.max(1, distance / math.max(1, cruiseSpeed))
	return math.max(1, elapsed / best)
end

return Units
