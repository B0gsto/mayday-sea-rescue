--!strict
-- BoatLevels (docs/30 section 2): the one boat ladder. Fifty rows: top speed, turning circle, room, scale, hull stage,
-- the named piece that level bolts on, the Cash price and the pick-up reach. Pure, Lune-tested (tests/BoatLevels.spec).
-- Levels drive the stats of whatever hull the boat wears (paid boats are looks only). Heli and Sub ignore them.
local Grading = require(script.Parent.Ops.Grading)

export type Stage = { hull: string, first: number, last: number, name: string }
export type Row = {
	level: number,
	speed: number, -- studs/s
	room: number, -- survivors aboard (past the visible seats they just count)
	scale: number, -- x the hull
	stage: number, -- 1..5
	hull: string,
	piece: string, -- what this level bolts on
	kind: string, -- its placeholder shape (BoatLevels.pieceParts)
	price: number, -- Cash to reach this level from the one below (L1 is free)
	turnRadius: number, -- studs: the turning circle at top speed
	reach: number, -- studs from the hull side: fast boats take survivors from further off
	callReach: number, -- studs from home: how far out this boat's calls go
	tank: number, -- s of full throttle (docs/31 C, Boat/Fuel)
}
export type PiecePart = {
	name: string,
	size: Vector3,
	offset: Vector3,
	color: Color3,
	neon: boolean,
}

local BoatLevels = {}

BoatLevels.MAX = 50
BoatLevels.ACCEL_K = 0.375 -- accel = top speed x this (L1: the jet ski's 30): every level hits top in about 6 s -- tune
BoatLevels.REACH_TIME = 0.18 -- s of top speed the reach covers, so a 0.25 s scan never drives past someone -- tune
BoatLevels.MAX_LENGTH = 72 -- studs: looks stop growing here (a x2.5 lifeboat would not fit the bay) -- tune
-- Mechanics, skills and the Nitro multiply this top speed; never past the tested limit (tests/BoatLevels.spec).
BoatLevels.SPEED_LIMIT = 1100
-- deg/s yaw cap for L1-L3 below the jet ski's 110 (playtest 2026-11-07: an L2 jet ski turned hard and overshot calls;
-- the level's own circle at top speed still wins when it needs more) -- tune
BoatLevels.EARLY_TURN_RATE = 80
BoatLevels.EARLY_TURN_LEVELS = 3
BoatLevels.FLOOR_SLACK = 1 -- studs/s: the stock jet ski's 80.2 is L1's 80, not a faster boat that needs L2

BoatLevels.Stages = {
	{ hull = "JetSki", first = 1, last = 10, name = "Jet ski" },
	{ hull = "RIB", first = 11, last = 20, name = "RIB" },
	{ hull = "Lifeboat", first = 21, last = 30, name = "Lifeboat" },
	{ hull = "Hydrofoil", first = 31, last = 40, name = "Hydrofoil" },
	{ hull = "RocketCutter", first = 41, last = 50, name = "Rocket Cutter" },
} :: { Stage }

-- stylua: ignore
local SPEED = { -- docs/30: huge early % jumps, huge late numbers -- tune
	80, 120, 170, 225, 285, 315, 345, 375, 405, 430,
	450, 470, 490, 510, 530, 550, 570, 585, 605, 620,
	640, 660, 675, 695, 715, 730, 750, 765, 785, 800,
	815, 830, 845, 860, 875, 890, 905, 920, 935, 950,
	965, 980, 995, 1010, 1025, 1040, 1055, 1070, 1085, 1100,
}

-- stylua: ignore
local ROOM_FROM = { [1] = 1, [3] = 2, [6] = 3, [11] = 4, [16] = 5, [21] = 8, [26] = 9, [31] = 10, [41] = 12, [50] = 14 }

-- L2-L5 take exactly the first four rescues' pay (500, 600, 600, 700: 550 and 650 carry the 50 over), one trip each
-- (playtest 2026-11-07: L4-L5 took two trips while a 1,900 Cash building looked closer); the rest come from the trip model in tests/Pacing.spec: zones, then the
-- run's x2 (a Go back trip is shorter than its window), so past L8 they are about x3 a flat-pay ladder -- tune
local TUT = Grading.Payout.Tutorial
-- stylua: ignore
local PRICE = {
	0, TUT[1].cash, 550, 650, TUT[4].cash, 1300, 1500, 2200, 2800, 4300,
	6000, 9300, 11500, 15000, 18000, 21000, 25000, 28500, 31500, 35000,
	38500, 56500, 60500, 64500, 69000, 72500, 82000, 85500, 92500, 96000,
	100000, 113000, 117000, 124000, 128000, 132000, 136000, 143000, 148000, 152000,
	159000, 184000, 192000, 199000, 207000, 214000, 221000, 228000, 235000, 245000,
}

-- level -> { name, kind }. Exaggerated, one clearly visible piece each (docs/30 table). A new hull is its stage's first
-- piece, so kind "none" is fine there.
-- stylua: ignore
local PIECES = {
	{ "Bare jet ski", "none" }, { "Shark fin", "fin" }, { "Rescue sled", "sled" }, { "Twin engines", "engine" }, { "Flame pipes", "flame" },
	{ "Banana boat", "tube" }, { "Huge spoiler", "spoiler" }, { "Bull nose", "nose" }, { "Horn stack", "stack" }, { "Turbo crown", "rocket" },
	{ "Big RIB", "none" }, { "Mega outboard", "engine" }, { "Arch spoiler", "spoiler" }, { "Neon fins", "fin" }, { "Fat tubes", "tube" },
	{ "Grandstand", "arch" }, { "Paddle wheel", "rocket" }, { "Shark jaws", "nose" }, { "Exhaust organ", "stack" }, { "Thunder wing", "wall" },
	{ "Big lifeboat", "none" }, { "Armour spikes", "plate" }, { "Huge lamps", "lamp" }, { "Ice plough", "nose" }, { "Roof rockets", "rocket" },
	{ "Crew deck", "arch" }, { "Lamp tower", "stack" }, { "Foil lift", "wing" }, { "Rear rockets", "wall" }, { "Battle bridge", "arch" },
	{ "Hydrofoil", "none" }, { "Giant jets", "rocket" }, { "T-tail", "fin" }, { "Sky stilts", "strut" }, { "Needle nose", "nose" },
	{ "Sky wings", "wing" }, { "Afterburners", "wall" }, { "Radar dish", "stack" }, { "Top jet", "spoiler" }, { "Turbo halo", "arch" },
	{ "Rocket Cutter", "none" }, { "Side boosters", "rocket" }, { "Gold plating", "gold" }, { "Wave wall", "wing" }, { "Gold eagle", "nose" },
	{ "Rocket fins", "fin" }, { "Gold throne", "arch" }, { "Party cannons", "stack" }, { "Mega trophy", "spoiler" }, { "Sun booster", "wall" },
}

local ROWS: { Row } = {}
do
	local room, stageIndex = 1, 1
	for level = 1, BoatLevels.MAX do
		room = ROOM_FROM[level] or room
		if level > BoatLevels.Stages[stageIndex].last then
			stageIndex += 1
		end
		local speed = SPEED[level]
		ROWS[level] = {
			level = level,
			speed = speed,
			room = room,
			scale = 1 + 1.5 * (level - 1) / (BoatLevels.MAX - 1),
			stage = stageIndex,
			hull = BoatLevels.Stages[stageIndex].hull,
			piece = PIECES[level][1],
			kind = PIECES[level][2],
			price = PRICE[level],
			turnRadius = 108 + 0.15 * speed, -- L1 is the jet ski's circle; L50 was 375 and felt like ice (about 500 in play) -- tune
			reach = math.max(14, math.floor(speed * BoatLevels.REACH_TIME + 0.5)),
			callReach = if stageIndex == 1 then 2000 elseif stageIndex == 2 then 3500 else 5500,
			tank = 24 + 0.4 * (level - 1), -- tune
		}
	end
end
BoatLevels.Rows = ROWS

-- Sanitise a stored level (corrupt saves included).
function BoatLevels.level(value: any): number
	if type(value) ~= "number" or value ~= value then
		return 1
	end
	return math.clamp(math.floor(value), 1, BoatLevels.MAX)
end

function BoatLevels.row(value: any): Row
	return ROWS[BoatLevels.level(value)]
end

-- The next rung, or nil at L50.
function BoatLevels.nextRow(value: any): Row?
	return ROWS[BoatLevels.level(value) + 1]
end

BoatLevels.EARLY_FLOOR_BELOW = 5 -- under this level any rescue pays at least the next level, so L2-L5 take one trip each

-- The least a rescue pays at this boat level (free-roam ones pay little early on), 0 from EARLY_FLOOR_BELOW up.
function BoatLevels.earlyPayFloor(value: any): number
	local nextRow = BoatLevels.nextRow(value)
	return if nextRow and BoatLevels.level(value) < BoatLevels.EARLY_FLOOR_BELOW
		then nextRow.price
		else 0
end

-- ok, reason, price for buying the next level: Cash only.
function BoatLevels.canBuy(value: any, cash: number): (boolean, string, number)
	local nextRow = BoatLevels.nextRow(value)
	if not nextRow then
		return false, "Max", 0
	end
	if cash < nextRow.price then
		return false, "Need Cash", nextRow.price
	end
	return true, "ok", nextRow.price
end

function BoatLevels.isStageHull(id: any): boolean
	for _, stage in BoatLevels.Stages do
		if stage.hull == id then
			return true
		end
	end
	return false
end

-- 0..1 of the way up the ladder, for the board's bar, and the same for where each stage starts.
function BoatLevels.progress(value: any): number
	return (BoatLevels.level(value) - 1) / (BoatLevels.MAX - 1)
end

-- Save migration: the lowest level that holds this old boat's speed and room, so nobody ever goes down.
function BoatLevels.floorFor(speed: number, room: number): number
	for level, row in ROWS do
		if row.speed >= speed - BoatLevels.FLOOR_SLACK and row.room >= room then
			return level
		end
	end
	return BoatLevels.MAX
end

-- The docs/30 floors for a boat owned before the ladder: its stat floor, and L11 / L21 for the RIB / Lifeboat.
function BoatLevels.legacyFloor(id: string, spec: any): number
	if spec.craft then
		return 1
	end
	local floor = BoatLevels.floorFor(spec.topSpeed, spec.survivorCapacity)
	if id == "RIB" then
		floor = math.max(floor, 11)
	elseif id == "Lifeboat" then
		floor = math.max(floor, 21)
	end
	return floor
end

-- The approved meshes, per hull id (art/source/*/_Upg*/RESULT.md). A later hull or piece is one more entry here (and
-- its ids from tools/gen_asset_ids.py); a level with no mesh keeps its placeholder Parts, and any other hull a look
-- wears keeps them all, since a mesh only fits the hull it was authored on.
--   origin     where the meshes' pivot sits in the hull's root frame, at x1 (Builder.*_ORIGIN)
--   width      the widest mesh, at x1: the bay's fit (tests/BoatLevels.spec)
--   pieces     level -> asset, cumulative through the stage
--   hide       the hull's own parts (by name prefix) from a level on
--   move       the hull's own parts moved (hull studs at x1) from a level on
--   rise       the hull floats this much higher (hull studs at x1) from a level on
--   chase      { from, x } the chase camera's arm, the last that applies
--   glow       ATT_* marker prefix -> a steady PointLight's colour
--   pilot      a mesh shown only while nobody drives: the driver sits where it rides
BoatLevels.HullArt = {
	JetSki = {
		origin = Vector3.new(0, -1.1, 2.3213),
		width = 13.6,
		pieces = {
			[2] = "M_Upg_JetSki_SharkFin",
			[3] = "M_Upg_JetSki_RescueSled",
			[4] = "M_Upg_JetSki_TwinEngines",
			[5] = "M_Upg_JetSki_FlamePipes",
			[6] = "M_Upg_JetSki_BananaBoat",
			[7] = "M_Upg_JetSki_HugeSpoiler",
			[8] = "M_Upg_JetSki_BullNose",
			[9] = "M_Upg_JetSki_HornStack",
			[10] = "M_Upg_JetSki_TurboCrown",
		},
		hide = { { from = 3, prefixes = { "M_Veh_JetSki_Sled" } } },
	},
	RIB = {
		origin = Vector3.new(0, -2.1, -0.0761),
		width = 28.45,
		pieces = {
			[12] = "M_Upg_RIB_MegaOutboard",
			[13] = "M_Upg_RIB_ArchSpoiler",
			[14] = "M_Upg_RIB_NeonFins",
			[15] = "M_Upg_RIB_FatTubes",
			[16] = "M_Upg_RIB_Grandstand",
			[17] = "M_Upg_RIB_PaddleWheel",
			[18] = "M_Upg_RIB_SharkJaws",
			[19] = "M_Upg_RIB_ExhaustOrgan",
			[20] = "M_Upg_RIB_ThunderWing",
		},
		hide = { { from = 12, prefixes = { "M_Veh_RIB_Engines" } } },
	},
	Lifeboat = {
		origin = Vector3.zero,
		width = 26.1,
		pieces = {
			[22] = "M_Upg_Lifeboat_ArmourSpikes",
			[23] = "M_Upg_Lifeboat_HugeLamps",
			[24] = "M_Upg_Lifeboat_IcePlough",
			[25] = "M_Upg_Lifeboat_RoofRockets",
			[26] = "M_Upg_Lifeboat_CrewDeck",
			[27] = "M_Upg_Lifeboat_LampTower",
			[28] = "M_Upg_Lifeboat_FoilLift",
			[29] = "M_Upg_Lifeboat_RearRockets",
			[30] = "M_Upg_Lifeboat_BattleBridge",
		},
		hide = { { from = 23, prefixes = { "Stay" } } },
		move = {
			{
				from = 30,
				by = Vector3.new(0, 7.2, 0),
				prefixes = {
					"MastBase",
					"Mast",
					"Yard",
					"RadarPedestal",
					"Radar",
					"NavMasthead",
					"Antenna",
					"BeaconBase",
					"Beacon",
				},
			},
		},
		rise = { from = 28, y = 8.1 },
		chase = { { from = 27, x = 1.45 } },
		glow = {
			ATT_Lens = Color3.fromRGB(255, 244, 214),
			ATT_Beacon = Color3.fromRGB(255, 244, 214),
			ATT_Flame = Color3.fromRGB(255, 170, 90),
		},
	},
	-- Hydrofoil and RocketCutter: Parts until new concepts pass (owner 2026-11-05; both meshes read as weapons).
} :: { [string]: any }

-- Hull studs (at x1) this hull floats higher at this level.
function BoatLevels.rise(hull: string, value: any): number
	local art = BoatLevels.HullArt[hull]
	local rise = art and art.rise
	return if rise and BoatLevels.level(value) >= rise.from then rise.y else 0
end

-- Every mesh, for the server's preload.
function BoatLevels.meshAssets(): { string }
	local out = {}
	for _, art in BoatLevels.HullArt do
		for _, asset in art.pieces do
			table.insert(out, asset)
		end
		if art.pilot then
			table.insert(out, art.pilot)
		end
	end
	return out
end

-- What the look is scaled by: the level's scale, held under MAX_LENGTH on the long hulls.
function BoatLevels.scaleFor(spec: any, value: any): number
	return math.min(
		BoatLevels.row(value).scale,
		math.max(1, BoatLevels.MAX_LENGTH / spec.hullSize.Z)
	)
end

-- A copy of the hull's spec with the level's stats and scale (the physics, seats and anti-teleport read this).
-- nil level or a heli / sub: the spec itself.
function BoatLevels.apply(spec: any, value: any): any
	if value == nil or spec.craft then
		return spec
	end
	local row = BoatLevels.row(value)
	local s = BoatLevels.scaleFor(spec, value)
	local out: any = table.clone(spec)
	local v = row.speed
	out.topSpeed = v
	out.accel = v * BoatLevels.ACCEL_K
	out.brakeDecel = math.max(spec.brakeDecel, out.accel * 0.6)
	-- the circle at top speed comes from the row, so a fast boat never feels like ice
	out.maxLateralG = v * v / (row.turnRadius * 29.43)
	local yaw = v / row.turnRadius
	local cap = if row.level <= BoatLevels.EARLY_TURN_LEVELS
		then math.min(spec.turnRate, BoatLevels.EARLY_TURN_RATE)
		else spec.turnRate
	out.turnRate = math.max(cap, math.deg(yaw) * 1.15)
	out.lateralGrip = math.max(spec.lateralGrip, yaw / 2.8) -- at most about 25 degrees of slip in a hard turn
	out.survivorCapacity = row.room
	out.hullSize = spec.hullSize * s
	out.draft = spec.draft * s
	out.massHint = spec.massHint * s * s * s
	out.turnRadiusSlow = spec.turnRadiusSlow * s
	local rise = Vector3.new(0, BoatLevels.rise(spec.id, value) * s, 0)
	local points = {}
	for i, p in spec.floatPoints do
		points[i] = p * s - rise
	end
	out.floatPoints = points
	return out
end

-- Mechanics and skills multiply the top speed; this keeps the product under the tested limit.
function BoatLevels.capMultiplier(topSpeed: number, mult: number): number
	return math.min(mult, math.max(1, BoatLevels.SPEED_LIMIT / topSpeed))
end

-- Wake and trail per level: wider, longer, and it turns colour with the stage (Ocean/Wake reads WakeLevel).
local WAKE_COLOR = {
	Color3.fromHex("#E8EEEC"), -- foam
	Color3.fromHex("#7FE3FF"), -- neon cyan
	Color3.fromHex("#8CFFB0"), -- neon green
	Color3.fromHex("#D9A6FF"), -- violet
	Color3.fromHex("#FFD65C"), -- gold
}
function BoatLevels.wake(value: any): (number, Color3)
	local row = BoatLevels.row(value)
	return 1 + 2 * BoatLevels.progress(value), WAKE_COLOR[row.stage]
end

-- Placeholder Parts for every piece of this level's stage so far: hull-relative (fractions of hullSize, so they fit
-- any look at any scale), later levels bigger. BoatLevels.HullArt's meshes replace them on their own hull.
local RED = Color3.fromRGB(214, 58, 48)
local ORANGE = Color3.fromRGB(255, 142, 38)
local GREY = Color3.fromRGB(72, 80, 88)
local WHITE = Color3.fromRGB(236, 236, 228)
local CYAN = Color3.fromRGB(70, 214, 255)
local GOLD = Color3.fromRGB(245, 190, 60)
local NAVY = Color3.fromRGB(30, 58, 110)

-- kind -> { size xyz, offset xyz (fractions of the hull), color, neon, mirrored }
-- stylua: ignore
local SHAPES: { [string]: { any } } = {
	fin = { Vector3.new(0.09, 0.9, 0.22), Vector3.new(0.42, 0.62, 0.31), RED, false, true },
	engine = { Vector3.new(0.3, 0.72, 0.17), Vector3.new(0.27, 0.41, 0.53), GREY, false, true },
	flame = { Vector3.new(0.17, 0.22, 0.31), Vector3.new(0.27, 0.11, 0.71), ORANGE, true, true },
	sled = { Vector3.new(1.13, 0.17, 0.23), Vector3.new(0, -0.08, 0.63), WHITE, false, false },
	spoiler = { Vector3.new(1.31, 0.09, 0.14), Vector3.new(0, 1.03, 0.43), RED, false, false },
	nose = { Vector3.new(0.34, 0.31, 0.24), Vector3.new(0, 0.23, -0.58), NAVY, false, false },
	tube = { Vector3.new(0.21, 0.42, 0.72), Vector3.new(0.59, 0.07, 0.04), WHITE, false, true },
	stack = { Vector3.new(0.13, 1.17, 0.07), Vector3.new(0.19, 0.97, 0.21), GREY, false, true },
	rocket = { Vector3.new(0.27, 0.48, 0.42), Vector3.new(0.73, 0.33, 0.27), ORANGE, false, true },
	arch = { Vector3.new(1.07, 0.11, 0.09), Vector3.new(0, 1.42, -0.03), CYAN, false, false },
	neon = { Vector3.new(0.07, 0.09, 0.83), Vector3.new(0.53, -0.21, 0.01), CYAN, true, true },
	plate = { Vector3.new(0.11, 0.67, 0.49), Vector3.new(0.56, 0.29, -0.17), GREY, false, true },
	lamp = { Vector3.new(0.27, 0.42, 0.09), Vector3.new(0.31, 1.21, -0.37), WHITE, true, true },
	wing = { Vector3.new(0.87, 0.07, 0.33), Vector3.new(0.87, 0.19, -0.09), NAVY, false, true },
	strut = { Vector3.new(0.09, 0.97, 0.13), Vector3.new(0.49, -0.47, -0.21), GREY, false, true },
	gold = { Vector3.new(0.11, 0.53, 0.77), Vector3.new(0.61, 0.43, 0.09), GOLD, false, true },
	wall = { Vector3.new(0.47, 1.37, 0.27), Vector3.new(0.39, 0.71, 0.79), GOLD, false, true },
}

-- The Parts of one level's piece.
function BoatLevels.levelParts(level: number, hullSize: Vector3): { PiecePart }
	local piece = ROWS[level]
	local out: { PiecePart } = {}
	local shape = SHAPES[piece.kind]
	if shape then
		local size, at = shape[1] * hullSize, shape[2] * hullSize
		local sides: { number } = if shape[5] then { -1, 1 } else { 1 }
		for _, side in sides do
			table.insert(out, {
				name = `Lv{level}{piece.kind}{if side < 0 then "L" else "R"}`,
				size = size,
				offset = Vector3.new(at.X * side, at.Y, at.Z),
				color = shape[3],
				neon = shape[4],
			})
		end
	end
	return out
end

function BoatLevels.pieceParts(value: any, hullSize: Vector3): { PiecePart }
	local row = BoatLevels.row(value)
	local out: { PiecePart } = {}
	for level = BoatLevels.Stages[row.stage].first, row.level do
		local parts = BoatLevels.levelParts(level, hullSize)
		table.move(parts, 1, #parts, #out + 1, out)
	end
	return out
end

return BoatLevels
