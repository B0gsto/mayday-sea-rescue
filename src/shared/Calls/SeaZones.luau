--!strict
-- SeaZones (docs/29 B): five circles round the lagoon, measured flat from RingLayout.Center. Further = better
-- survivors and better free-roam pay. Pure data and maths, Lune-tested (tests/SeaZones.spec.luau). Used by
-- RescueService (rarity), AmbientMix (spawns, pay), WeatherController (water, fog, light), MapController (circles) and
-- SeaZoneController (buoy line, banner). A crossing reads through the air and the water (owner 2026-11-07: no wall):
-- SeaZones.lookAt blends two zones' looks over BLEND studs either side of a line, by distance.
local Config = script.Parent.Parent:WaitForChild("Config") -- required on the client too
local RingLayout = require(Config:WaitForChild("RingLayout"))
local WorldConfig = require(Config:WaitForChild("WorldConfig"))

export type Zone = {
	id: string,
	name: string,
	outer: number, -- studs from the centre where it ends
	weights: { number }, -- % Common..Mythic (WorkerRules opts.weights), sums to 100
	pay: number, -- x AmbientMix.CASH
	color: Color3, -- the line: buoys, map circle
	kit: string, -- the banner's Kit gradient
	gem: string, -- the banner's Kit icon: the zone's best rarity
	water: Color3, -- OceanWaterColor by day
	haze: Color3, -- Atmosphere colour
	hazeMix: number, -- how far the haze goes to `haze`
	density: number, -- added Atmosphere density (fog)
	hazeAdd: number, -- added Atmosphere haze (how milky the distance is)
	exposure: number, -- added ExposureCompensation (darker further out)
	saturation: number, -- added ColorCorrection saturation
	overcast: number, -- share of the Overcast preset
}
-- What the sea looks like right now: eased toward a zone by SeaZones.ease.
export type Look = {
	water: Color3,
	waterMix: number,
	haze: Color3,
	hazeMix: number,
	density: number,
	hazeAdd: number,
	exposure: number,
	saturation: number,
	overcast: number,
}

local SeaZones = {}

SeaZones.HYSTERESIS = 60 -- studs past a line before a crossing counts: no banner spam along a line -- tune
SeaZones.EASE = 0.6 -- s, the look's time constant: about 2 s to settle (smooths teleports) -- tune
SeaZones.BLEND = 300 -- studs either side of a line over which the look blends: 600 of each 1,200 band is pure -- tune
SeaZones.LINE_SHOW = 560 -- studs from a line where its buoys appear: bands are 1,200 wide, so one line at most -- tune
SeaZones.POOL = 24 -- buoys in the pool
SeaZones.SPACING = 90 -- studs between buoys, about -- tune

SeaZones.Zones = {
	{
		id = "Shallows",
		name = "Shallows",
		outer = 1600,
		weights = { 78, 18, 4, 0, 0, 0 },
		pay = 1,
		color = Color3.fromHex("2FE0D0"),
		kit = "teal",
		gem = "gem_rare",
		water = Color3.fromHex("1E9FB0"),
		haze = Color3.fromHex("D6E6F0"),
		hazeMix = 0,
		density = 0,
		hazeAdd = 0,
		exposure = 0,
		saturation = 0.05,
		overcast = 0,
	},
	{
		id = "KelpBanks",
		name = "Kelp Banks",
		outer = 2800,
		weights = { 55, 28, 13, 4, 0, 0 },
		pay = 1.25, -- docs/29's 1.5 / 2.5 / 4 / 6 gave a full RIB or lifeboat 1.8-1.9x the calls (tests/Pacing)
		color = Color3.fromHex("4FE07A"),
		kit = "green",
		gem = "gem_epic",
		water = Color3.fromHex("177F6E"),
		haze = Color3.fromHex("C9E6D2"),
		hazeMix = 0.6,
		density = 0.06,
		hazeAdd = 0.3,
		exposure = 0,
		saturation = 0,
		overcast = 0,
	},
	{
		id = "CoralDrift",
		name = "Coral Drift",
		outer = 4000,
		weights = { 32, 33, 22, 10, 3, 0 },
		pay = 2,
		color = Color3.fromHex("A77BFF"),
		kit = "purple",
		gem = "gem_legendary",
		water = Color3.fromHex("2E4FA8"),
		haze = Color3.fromHex("D2C6F2"),
		hazeMix = 0.75,
		density = 0.12,
		hazeAdd = 0.7,
		exposure = -0.05,
		saturation = 0,
		overcast = 0,
	},
	{
		id = "StormReach",
		name = "Storm Reach",
		outer = 5200,
		weights = { 15, 28, 30, 19, 7, 1 },
		pay = 3,
		color = Color3.fromHex("7FB6E8"),
		kit = "blue",
		gem = "gem_mythic",
		water = Color3.fromHex("284A6A"),
		haze = Color3.fromHex("8C9AAB"),
		hazeMix = 0.9,
		density = 0.14,
		hazeAdd = 1,
		exposure = -0.2,
		saturation = -0.15,
		overcast = 0.85,
	},
	{
		id = "WreckAbyss",
		name = "Wreck Abyss",
		outer = math.huge,
		weights = { 5, 15, 30, 30, 16, 4 },
		pay = 4,
		color = Color3.fromHex("6A5CFF"),
		kit = "pink",
		gem = "gem_mythic",
		water = Color3.fromHex("0F1838"),
		haze = Color3.fromHex("3A3F66"),
		hazeMix = 1,
		density = 0.28,
		hazeAdd = 1.6,
		exposure = -0.35,
		saturation = -0.25,
		overcast = 1,
	},
} :: { Zone }

-- No tint at all (the cold open keeps its own look).
SeaZones.NEUTRAL = table.freeze({
	water = SeaZones.Zones[1].water,
	waterMix = 0,
	haze = SeaZones.Zones[1].haze,
	hazeMix = 0,
	density = 0,
	hazeAdd = 0,
	exposure = 0,
	saturation = 0,
	overcast = 0,
}) :: Look

local NUMBERS = { "hazeMix", "density", "hazeAdd", "exposure", "saturation", "overcast" }

local function fromCentre(x: number, z: number): number
	local c = RingLayout.Center
	local dx, dz = x - c.X, z - c.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- The zone index (1..5) and zone at a world position.
function SeaZones.zoneAt(pos: Vector3): (number, Zone)
	local r = fromCentre(pos.X, pos.Z)
	for i, zone in SeaZones.Zones do
		if r < zone.outer then
			return i, zone
		end
	end
	return #SeaZones.Zones, SeaZones.Zones[#SeaZones.Zones]
end

-- The zone you count as in, from the one you were in: a crossing needs HYSTERESIS studs past the line.
function SeaZones.step(current: number, pos: Vector3): number
	local at = SeaZones.zoneAt(pos)
	if at == current then
		return current
	end
	local r = fromCentre(pos.X, pos.Z)
	local inner = if current > 1 then SeaZones.Zones[current - 1].outer else 0
	local outer = SeaZones.Zones[current].outer
	if r > inner - SeaZones.HYSTERESIS and r < outer + SeaZones.HYSTERESIS then
		return current
	end
	return at
end

-- A survivor's rarity table where they spawn.
function SeaZones.weightsAt(pos: Vector3): { number }
	local _, zone = SeaZones.zoneAt(pos)
	return zone.weights
end

-- Eases `look` toward `target` by dt s, in place. target: a Zone (waterMix 1) or SeaZones.NEUTRAL.
function SeaZones.ease(look: Look, target: any, dt: number)
	local k = 1 - math.exp(-dt / SeaZones.EASE)
	look.water = look.water:Lerp(target.water, k)
	look.waterMix += ((target.waterMix or 1) - look.waterMix) * k
	look.haze = look.haze:Lerp(target.haze, k)
	for _, key in NUMBERS do
		look[key] += (target[key] - look[key]) * k
	end
end

-- The look at a world position: one zone's mid-band, two zones blended (smoothstep) within BLEND of a line.
function SeaZones.lookAt(pos: Vector3): Look
	local r = fromCentre(pos.X, pos.Z)
	local i = SeaZones.zoneAt(pos)
	local a, b, t = SeaZones.Zones[i], SeaZones.Zones[i], 0
	if i > 1 and r < SeaZones.Zones[i - 1].outer + SeaZones.BLEND then
		a, t = SeaZones.Zones[i - 1], 0.5 + (r - SeaZones.Zones[i - 1].outer) / (2 * SeaZones.BLEND)
	elseif i < #SeaZones.Zones and r > a.outer - SeaZones.BLEND then
		b, t = SeaZones.Zones[i + 1], 0.5 - (a.outer - r) / (2 * SeaZones.BLEND)
	end
	t = t * t * (3 - 2 * t)
	local look = {
		water = a.water:Lerp(b.water, t),
		waterMix = 1,
		haze = a.haze:Lerp(b.haze, t),
	} :: any
	for _, key in NUMBERS do
		look[key] = (a :: any)[key] + ((b :: any)[key] - (a :: any)[key]) * t
	end
	return look
end

-- Slots round a line: a multiple of POOL, so slot k always takes buoy k % POOL + 1 and a moving window only moves
-- the buoy that fell off its end.
function SeaZones.slotCount(line: number): number
	local around = 2 * math.pi * SeaZones.Zones[line].outer
	return SeaZones.POOL * math.max(1, math.round(around / (SeaZones.POOL * SeaZones.SPACING)))
end

-- The line near (x, z): the index of the zone it closes (1..4) and the slot nearest you, nil past LINE_SHOW.
function SeaZones.lineNear(x: number, z: number): (number?, number)
	local r = fromCentre(x, z)
	for line = 1, #SeaZones.Zones - 1 do
		if math.abs(r - SeaZones.Zones[line].outer) <= SeaZones.LINE_SHOW then
			local c = RingLayout.Center
			local angle = math.atan2(z - c.Z, x - c.X) % (2 * math.pi)
			return line, math.round(angle / (2 * math.pi) * SeaZones.slotCount(line))
		end
	end
	return nil, 0
end

-- Where slot k of a line stands, at sea level. A slot wraps round the circle.
function SeaZones.slotPoint(line: number, k: number): Vector3
	local c = RingLayout.Center
	local radius = SeaZones.Zones[line].outer
	local angle = k / SeaZones.slotCount(line) * 2 * math.pi
	return Vector3.new(c.X + math.cos(angle) * radius, 0, c.Z + math.sin(angle) * radius)
end

-- Is this point on an outer island? (lines cross some of them: no buoys ashore)
function SeaZones.onLand(p: Vector3): boolean
	for _, island in WorldConfig.Islands do
		local dx, dz = p.X - island.center.X, p.Z - island.center.Z
		if dx * dx + dz * dz < island.radius * island.radius then
			return true
		end
	end
	return false
end

return SeaZones
