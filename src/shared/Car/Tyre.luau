--!strict
-- Tyre model: a surface grip table (docs 10 section 2.2) and a simplified Pacejka "magic formula"
-- slip curve, F = D sin(C atan(B x)), for longitudinal slip ratio and lateral slip angle, joined
-- by a friction ellipse. Pure maths, no Roblox services (Lune-tested in tests/Car.spec.luau).
--
-- The longitudinal side is quasi-static (no wheel spin state, which is numerically stiff at a
-- 60 Hz frame): a wheel delivers its demanded force while that is under the curve's peak and
-- reports the slip ratio that gives it; past the peak it spins up or locks, slides at the curve's
-- sliding value and reports the larger slip. ABS and traction control hold it at the peak.
local Tyre = {}

export type Surface = {
	id: string,
	grip: number, -- peak friction multiplier, dry (asphalt = 1)
	wetGrip: number, -- in full rain
	rolling: number, -- rolling resistance coefficient (force / load)
	roughness: number, -- 0..1, for suspension buzz, camera shake and tyre noise
}

local function surface(
	id: string,
	grip: number,
	wetGrip: number,
	rolling: number,
	roughness: number
): Surface
	return { id = id, grip = grip, wetGrip = wetGrip, rolling = rolling, roughness = roughness }
end

-- Grip values from docs 10 section 2.2 (tune); rolling resistance from typical tyre data
-- (0.012 on asphalt, 0.15 to 0.3 in soft sand).
Tyre.Surfaces = {
	Asphalt = surface("Asphalt", 1.0, 0.75, 0.013, 0.05),
	Cobbles = surface("Cobbles", 0.85, 0.6, 0.02, 0.5),
	Concrete = surface("Concrete", 0.9, 0.7, 0.013, 0.1),
	Slipway = surface("Slipway", 0.5, 0.5, 0.015, 0.15), -- weedy wet concrete in the tide zone
	Gravel = surface("Gravel", 0.7, 0.65, 0.04, 0.6),
	Dirt = surface("Dirt", 0.65, 0.4, 0.035, 0.45),
	WetSand = surface("WetSand", 0.65, 0.65, 0.06, 0.2), -- hard sand below the tide line
	Sand = surface("Sand", 0.5, 0.55, 0.16, 0.3), -- soft dry sand and dunes; rain firms it a bit
	Mud = surface("Mud", 0.35, 0.3, 0.12, 0.4),
	Grass = surface("Grass", 0.6, 0.4, 0.05, 0.5),
	Rock = surface("Rock", 0.8, 0.55, 0.02, 0.7),
	Wood = surface("Wood", 0.7, 0.45, 0.015, 0.3),
	Metal = surface("Metal", 0.65, 0.4, 0.012, 0.2),
	Snow = surface("Snow", 0.3, 0.3, 0.06, 0.2),
	Ice = surface("Ice", 0.12, 0.08, 0.01, 0.0),
}

-- Enum.Material names (BaseParts and Terrain) to surfaces. Terrain with MaterialVariants reports
-- the base material (verify in Studio). Unknown materials (greybox Plastic) drive like concrete.
Tyre.MaterialSurface = {
	Asphalt = "Asphalt",
	Concrete = "Concrete",
	Pavement = "Cobbles",
	Cobblestone = "Cobbles",
	Brick = "Cobbles",
	Slate = "Rock",
	Granite = "Rock",
	Rock = "Rock",
	Basalt = "Rock",
	Limestone = "Rock",
	Sandstone = "Rock",
	Marble = "Rock",
	CrackedLava = "Rock",
	Pebble = "Gravel",
	Gravel = "Gravel",
	Salt = "Gravel",
	Ground = "Dirt",
	Sand = "Sand",
	Mud = "Mud",
	Grass = "Grass",
	LeafyGrass = "Grass",
	WoodPlanks = "Wood",
	Wood = "Wood",
	Metal = "Metal",
	DiamondPlate = "Metal",
	CorrodedMetal = "Metal",
	Snow = "Grass", -- terrain T3: the Snow slot carries the TurfStraw turf variant (no snow on the isles)
	Ice = "Ice",
	Glacier = "Ice",
}

Tyre.TIDE_BAND = 4.5 -- studs above sea level that the sea keeps wet (1.5 m, mid tide + swash) -- tune

-- The surface for a ray hit: material name and the hit's height above sea level.
function Tyre.surfaceFor(materialName: string, heightAboveSea: number): Surface
	local id = (Tyre.MaterialSurface :: any)[materialName] or "Concrete"
	if heightAboveSea < Tyre.TIDE_BAND then
		if id == "Sand" then
			id = "WetSand"
		elseif id == "Concrete" then
			id = "Slipway"
		end
	end
	return (Tyre.Surfaces :: any)[id] :: Surface
end

-- Road wetness 0..1 from the storm intensity (Weather.getIntensity): rain starts at about 0.15.
function Tyre.wetness(intensity: number): number
	return math.clamp((intensity - 0.15) / 0.45, 0, 1)
end

-- Grip multiplier for a surface at a wetness.
function Tyre.grip(s: Surface, wetness: number): number
	return s.grip + (s.wetGrip - s.grip) * math.clamp(wetness, 0, 1)
end

-- The normalised magic formula: 0 at x = 0, peak 1 at x = peakSlip(B, C).
function Tyre.curve(x: number, b: number, c: number): number
	return math.sin(c * math.atan(b * x))
end

function Tyre.peakSlip(b: number, c: number): number
	return math.tan(math.pi / (2 * c)) / b
end

-- The slip on the rising side of the curve that gives a fraction r (0..1) of the peak.
function Tyre.slipFor(r: number, b: number, c: number): number
	return math.tan(math.asin(math.clamp(r, 0, 1)) / c) / b
end

-- Longitudinal force for a demanded force (drive + brake + rolling, at the contact patch) and the
-- peak available (mu * load). Returns force, slip ratio (signed) and whether the wheel slides.
function Tyre.longitudinal(
	demand: number,
	peak: number,
	b: number,
	c: number,
	assist: boolean
): (number, number, boolean)
	if peak <= 0 then
		return 0, 0, false
	end
	local sign = if demand < 0 then -1 else 1
	local r = math.abs(demand) / peak
	if r <= 1 then
		return demand, sign * Tyre.slipFor(r, b, c), false
	end
	local xPeak = Tyre.peakSlip(b, c)
	if assist then
		-- ABS / traction control cycle around the peak slip
		return sign * peak * 0.97, sign * xPeak, false
	end
	local slip = math.min(1, xPeak + (r - 1) * 0.5)
	return sign * peak * Tyre.curve(slip, b, c), sign * slip, true
end

Tyre.LOW_SPEED = 2 -- studs/s: slip angles are relaxed below this so a parked car doesn't jitter

-- Lateral force from the contact patch's sideways and rolling velocity (wheel frame, studs/s).
-- Returns force (opposing vLat) and the slip angle (radians).
function Tyre.lateral(
	vLat: number,
	vLong: number,
	peak: number,
	b: number,
	c: number
): (number, number)
	if peak <= 0 then
		return 0, 0
	end
	local alpha = math.atan2(vLat, math.max(math.abs(vLong), Tyre.LOW_SPEED))
	local f = peak * Tyre.curve(math.abs(alpha), b, c)
	return if alpha > 0 then -f else f, alpha
end

-- Friction ellipse: scales (fx, fy) back inside the ellipse with semi-axes maxFx, maxFy.
function Tyre.combine(fx: number, fy: number, maxFx: number, maxFy: number): (number, number)
	if maxFx <= 0 or maxFy <= 0 then
		return 0, 0
	end
	local e = (fx / maxFx) ^ 2 + (fy / maxFy) ^ 2
	if e <= 1 then
		return fx, fy
	end
	local s = 1 / math.sqrt(e)
	return fx * s, fy * s
end

return Tyre
