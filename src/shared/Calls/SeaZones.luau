--!strict
-- SeaZones (docs/29 B): five circles round the lagoon, measured flat from RingLayout.Center. Further = better
-- survivors and better free-roam pay. Pure data and maths, Lune-tested (tests/SeaZones.spec.luau). Used by
-- RescueService (rarity), AmbientMix (spawns, pay), WeatherController (tint, fog), MapController (circles) and
-- SeaZoneController (buoy line, banner).
local Config = script.Parent.Parent:WaitForChild("Config") -- required on the client too
local RingLayout = require(Config:WaitForChild("RingLayout"))
local WorldConfig = require(Config:WaitForChild("WorldConfig"))

export type Zone = {
	id: string,
	name: string,
	outer: number, -- studs from the centre where it ends
	weights: { number }, -- % Common..Mythic (WorkerRules opts.weights), sums to 100
	pay: number, -- x AmbientMix.CASH
	color: Color3, -- the line: buoys, curtain, map circle
	kit: string, -- the banner's Kit gradient
	gem: string, -- the banner's Kit icon: the zone's best rarity
	water: Color3, -- OceanWaterColor by day
	haze: Color3, -- Atmosphere colour
	hazeMix: number, -- how far the haze goes to `haze`
	density: number, -- added Atmosphere density (fog)
	overcast: number, -- share of the Overcast preset
}
-- What the sea looks like right now: eased toward a zone by SeaZones.ease.
export type Look = {
	water: Color3,
	waterMix: number,
	haze: Color3,
	hazeMix: number,
	density: number,
	overcast: number,
}

local SeaZones = {}

SeaZones.HYSTERESIS = 60 -- studs past a line before a crossing counts: no banner spam along a line -- tune
SeaZones.EASE = 0.6 -- s, the look's time constant: about 2 s to settle -- tune
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
		water = Color3.fromHex("1C8A94"),
		haze = Color3.fromHex("D6E6F0"),
		hazeMix = 0,
		density = 0,
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
		water = Color3.fromHex("1D7F62"),
		haze = Color3.fromHex("CFE8D6"),
		hazeMix = 0.7,
		density = 0.02,
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
		water = Color3.fromHex("3F4BAE"),
		haze = Color3.fromHex("D8CFF4"),
		hazeMix = 0.8,
		density = 0.04,
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
		water = Color3.fromHex("35587C"),
		haze = Color3.fromHex("93A4B6"),
		hazeMix = 0.9,
		density = 0.1,
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
		water = Color3.fromHex("14163C"),
		haze = Color3.fromHex("34346A"),
		hazeMix = 1,
		density = 0.16,
		overcast = 0.6,
	},
} :: { Zone }

-- No tint at all (the cold open keeps its own look).
SeaZones.NEUTRAL = table.freeze({
	water = SeaZones.Zones[1].water,
	waterMix = 0,
	haze = SeaZones.Zones[1].haze,
	hazeMix = 0,
	density = 0,
	overcast = 0,
}) :: Look

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
	look.hazeMix += (target.hazeMix - look.hazeMix) * k
	look.density += (target.density - look.density) * k
	look.overcast += (target.overcast - look.overcast) * k
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
