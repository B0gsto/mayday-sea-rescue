--!strict
-- SeamarkRules (RP-I1b-2): the Gale Isles buoyage as pure data plus the light and motion rules, shared by the
-- server placement (src/server/World/Seamarks.luau) and the client motion / flash (SeamarkController). Unit-tested
-- in tests/Seamarks.spec.luau. No requires: safe to load in Lune.
--
-- IALA Region A (art/reference/M_Hbr_NavMark_*/dims.md). The harbour (map/Build.luau buildBreakwater) opens south:
-- the 60-stud mouth at x = +-30, z 352..368, the dredged channel |x| < 40 inside it (tools/world/layout.py
-- HARBOUR.channelHalf). A vessel entering from seaward steers north (-Z), so its port hand is west (-X): red cans
-- (even numbers) on the west of the channel, green cones (odd numbers) on the east, numbered from seaward. The
-- fairway buoy (safe water) is the landfall mark at the head of the channel and the bell buoy the outer port-hand
-- mark. Cardinals sit on the named side of the danger they mark (a West mark: pass to the west of it), with
-- depths read off map/generated/terrain_height.i16. Moorings: yellow swing moorings in the harbour pool off the
-- channel, each with its pick-up buoy streamed the same way (the tide sets them all alike).
--
--   SeamarkRules.Marks                   { Mark }: id, asset, name, x, z, yaw (deg), light?, map? (blip style)
--   SeamarkRules.Lights[characteristic]  { color, seq = { on, off, on, off, ... } } seconds, one period
--   SeamarkRules.period(seq)             the period (s)
--   SeamarkRules.isOn(seq, t)            the light is lit at time t (s, any clock; loops)
--   SeamarkRules.phase(id)               a stable 0..1 phase offset per mark (marks do not flash in step)
--   SeamarkRules.lightsOn(state, base, sunY)  photocell: night, dusk (sun under about 4 deg) or a storm
--   SeamarkRules.motion(kind)            heave / tilt response of a hull class ("pillar" | "ball")
--   SeamarkRules.tiltFrom(nx, nz, follow, maxDeg)  pitch / roll (rad) from the surface normal, clamped

local SeamarkRules = {}

export type Mark = {
	id: string,
	asset: string,
	name: string,
	x: number,
	z: number,
	yaw: number,
	light: string?,
	map: string?,
}

export type Light = { color: Color3, seq: { number } }

local RED = Color3.fromRGB(255, 46, 34)
local GREEN = Color3.fromRGB(52, 255, 110)
local WHITE = Color3.fromRGB(255, 246, 226)

local function q(
	n: number,
	tail: number
): { number } -- n quick flashes (0.3 s on / 0.7 s off), the last off `tail`
	local seq = {}
	for i = 1, n do
		table.insert(seq, 0.3)
		table.insert(seq, if i == n then tail else 0.7)
	end
	return seq
end

local south = q(6, 0.7)
table.insert(south, 2)
table.insert(south, 7)

-- the studio rhythms of art/reference/<asset>/dims.md, one period each
SeamarkRules.Lights = {
	["Fl R 4s"] = { color = RED, seq = { 0.5, 3.5 } },
	["Fl G 5s"] = { color = GREEN, seq = { 0.5, 4.5 } },
	["Fl(2) R 10s"] = { color = RED, seq = { 0.5, 1, 0.5, 8 } },
	["Q W"] = { color = WHITE, seq = { 0.3, 0.7 } },
	["Q(3) W 10s"] = { color = WHITE, seq = q(3, 7.7) },
	["Q(6)+LFl W 15s"] = { color = WHITE, seq = south },
	["Q(9) W 15s"] = { color = WHITE, seq = q(9, 6.7) },
	["Fl(2) W 5s"] = { color = WHITE, seq = { 0.4, 0.6, 0.4, 3.6 } },
	["LFl W 10s"] = { color = WHITE, seq = { 2, 8 } },
} :: { [string]: Light }

local PORT, STBD = "M_Hbr_NavMark_Port", "M_Hbr_NavMark_Starboard"
local MOOR, PICK = "M_Hbr_MooringBuoy", "M_Hbr_PickupBuoy"

local marks: { Mark } = {
	-- the harbour approach (lateral, entering north from seaward)
	{
		id = "Fairway",
		asset = "M_Hbr_NavMark_SafeWater",
		name = "Haven Fairway",
		x = 0,
		z = 1080,
		yaw = 12,
		light = "LFl W 10s",
		map = "SeamarkSafe",
	},
	{
		id = "No2Bell",
		asset = "M_Hbr_NavMark_Bell",
		name = "No 2 Bell",
		x = -60,
		z = 880,
		yaw = 200,
		light = "Fl(2) R 10s",
		map = "SeamarkPort",
	},
	{
		id = "No1",
		asset = STBD,
		name = "No 1",
		x = 60,
		z = 880,
		yaw = 35,
		light = "Fl G 5s",
		map = "SeamarkStarboard",
	},
	{
		id = "No4",
		asset = PORT,
		name = "No 4",
		x = -55,
		z = 660,
		yaw = 140,
		light = "Fl R 4s",
		map = "SeamarkPort",
	},
	{
		id = "No3",
		asset = STBD,
		name = "No 3",
		x = 55,
		z = 660,
		yaw = 290,
		light = "Fl G 5s",
		map = "SeamarkStarboard",
	},
	{
		id = "No6",
		asset = PORT,
		name = "No 6",
		x = -50,
		z = 460,
		yaw = 75,
		light = "Fl R 4s",
		map = "SeamarkPort",
	},
	{
		id = "No5",
		asset = STBD,
		name = "No 5",
		x = 50,
		z = 460,
		yaw = 180,
		light = "Fl G 5s",
		map = "SeamarkStarboard",
	},
	-- inside the mouth: the edges of the dredged channel up to the station slipway
	{
		id = "No8",
		asset = PORT,
		name = "No 8",
		x = -46,
		z = 230,
		yaw = 250,
		light = "Fl R 4s",
		map = "SeamarkPort",
	},
	{
		id = "No7",
		asset = STBD,
		name = "No 7",
		x = 46,
		z = 230,
		yaw = 10,
		light = "Fl G 5s",
		map = "SeamarkStarboard",
	},
	-- the Morwenna wreck (WorldConfig.POIs, off the ring east of the hub): clear water to its west
	{
		id = "MorwennaWest",
		asset = "M_Hbr_NavMark_West",
		name = "Morwenna West",
		x = 1000,
		z = -640,
		yaw = 60,
		light = "Q(9) W 15s",
		map = "SeamarkCardinal",
	},
	-- and to its south
	{
		id = "MorwennaSouth",
		asset = "M_Hbr_NavMark_South",
		name = "Morwenna South",
		x = 1100,
		z = -540,
		yaw = 320,
		light = "Q(6)+LFl W 15s",
		map = "SeamarkCardinal",
	},
	-- the Skerries ledges (1480..1720, 1280..1540, down to 1 m): marked north, west and east
	{
		id = "SkerriesNorth",
		asset = "M_Hbr_NavMark_North",
		name = "Skerries North",
		x = 1580,
		z = 1240,
		yaw = 100,
		light = "Q W",
		map = "SeamarkCardinal",
	},
	{
		id = "SkerriesWest",
		asset = "M_Hbr_NavMark_West",
		name = "Skerries West",
		x = 1400,
		z = 1440,
		yaw = 215,
		light = "Q(9) W 15s",
		map = "SeamarkCardinal",
	},
	{
		id = "SkerriesEast",
		asset = "M_Hbr_NavMark_East",
		name = "Skerries East",
		x = 1800,
		z = 1490,
		yaw = 170,
		light = "Q(3) W 10s",
		map = "SeamarkCardinal",
	},
	-- Gull Stone: the lone rock head of SkerriesReefE (K1 rocks to about 1 m), deep water all round
	{
		id = "GullStone",
		asset = "M_Hbr_NavMark_IsolatedDanger",
		name = "Gull Stone",
		x = 2336,
		z = 1484,
		yaw = 25,
		light = "Fl(2) W 5s",
		map = "SeamarkDanger",
	},
}

-- swing moorings in the harbour pool (west and east of the channel, clear of the -165, 30 slipway, the pontoons
-- by the hospital and the dock, and the Admiralty anchor by the east wall), each with its pick-up buoy
local MOORINGS = {
	{ -232, 168 },
	{ -186, 214 },
	{ -252, 256 },
	{ -204, 300 },
	{ 168, 186 },
	{ 214, 292 },
}
local PICKUP_OFFSET = { 3.2, 2.4 } -- studs (x, z) from the mooring buoy: all streamed the same way
for i, m in MOORINGS do
	table.insert(marks, {
		id = `Mooring{i}`,
		asset = MOOR,
		name = `Visitors' mooring {i}`,
		x = m[1],
		z = m[2],
		yaw = (i * 47) % 360,
	})
	table.insert(marks, {
		id = `Pickup{i}`,
		asset = PICK,
		name = `Pick-up buoy {i}`,
		x = m[1] + PICKUP_OFFSET[1],
		z = m[2] + PICKUP_OFFSET[2],
		yaw = (i * 83) % 360,
	})
end

SeamarkRules.Marks = marks

function SeamarkRules.period(seq: { number }): number
	local sum = 0
	for _, s in seq do
		sum += s
	end
	return sum
end

function SeamarkRules.isOn(seq: { number }, t: number): boolean
	local p = SeamarkRules.period(seq)
	if p <= 0 then
		return false
	end
	local u = t % p
	local acc = 0
	for i, s in seq do
		acc += s
		if u < acc then
			return i % 2 == 1 -- odd entries are "on"
		end
	end
	return false
end

function SeamarkRules.phase(id: string): number
	local h = 7
	for i = 1, #id do
		h = (h * 131 + string.byte(id, i)) % 1000003
	end
	return (h % 1000) / 1000
end

-- Light-sensitive switch of a buoy lantern: on at night and at dusk, and in a storm (the sky goes dark).
-- sunY is Lighting:GetSunDirection().Y; base the Lighting WeatherBase attribute.
function SeamarkRules.lightsOn(state: string, base: string?, sunY: number): boolean
	if state == "Storm" or state == "Warning" then
		return true
	end
	if base == "Night" then
		return true
	end
	return sunY < 0.07
end

export type Motion = { heave: number, follow: number, maxTilt: number, lag: number }

-- How a hull answers the waves: heave (share of the surface rise it rides), follow (share of the surface slope
-- it leans to), maxTilt (deg), lag (s, first-order smoothing; the tall pillar buoys are slower).
function SeamarkRules.motion(asset: string): Motion
	if asset == MOOR or asset == PICK then
		return { heave = 1, follow = 1, maxTilt = 30, lag = 0.15 }
	end
	return { heave = 0.92, follow = 0.75, maxTilt = 16, lag = 0.45 }
end

-- Pitch (about X, positive tips the top toward +Z) and roll (about Z, positive toward -X) so the buoy's up leans
-- along the surface normal (nx, ny, nz) scaled by `follow`, clamped to maxDeg.
function SeamarkRules.tiltFrom(
	nx: number,
	nz: number,
	follow: number,
	maxDeg: number
): (number, number)
	local lim = math.rad(maxDeg)
	local pitch = math.clamp(math.asin(math.clamp(nz, -1, 1)) * follow, -lim, lim)
	local roll = math.clamp(-math.asin(math.clamp(nx, -1, 1)) * follow, -lim, lim)
	return pitch, roll
end

return SeamarkRules
