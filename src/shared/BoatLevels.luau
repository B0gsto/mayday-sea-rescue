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

-- L2 is exactly the first rescue's pay; the rest come from the trip model in tests/Pacing.spec -- tune
-- stylua: ignore
local PRICE = {
	0, Grading.Payout.Tutorial[1].cash, 600, 800, 1200, 1300, 1500, 2200, 2800, 3500,
	4100, 5500, 6000, 7000, 7500, 8500, 10000, 11000, 12000, 13000,
	14000, 20000, 21000, 22000, 23000, 24000, 27000, 28000, 30000, 31000,
	32000, 36000, 37000, 39000, 40000, 41000, 42000, 44000, 45000, 46000,
	48000, 55000, 57000, 59000, 61000, 63000, 65000, 67000, 69000, 72000,
}

-- level -> { name, kind }. Exaggerated, one clearly visible piece each (docs/30 table).
-- stylua: ignore
local PIECES = {
	{ "Bare jet ski", "none" }, { "Racing fins", "fin" }, { "Twin engines", "engine" }, { "Exhaust flames", "flame" }, { "Rescue sled", "sled" },
	{ "Big spoiler", "spoiler" }, { "Nose cone", "nose" }, { "Side pods", "tube" }, { "Turbo stack", "stack" }, { "Flame jets", "rocket" },
	{ "Fat tubes", "tube" }, { "Big outboards", "engine" }, { "Race spoiler", "spoiler" }, { "Twin fins", "fin" }, { "Roll bar", "arch" },
	{ "Neon strips", "neon" }, { "Turbo stack", "stack" }, { "Nose ram", "nose" }, { "Side rockets", "rocket" }, { "Monster engines", "wall" },
	{ "Armour plates", "plate" }, { "Huge lamps", "lamp" }, { "Side rockets", "rocket" }, { "Foil wings", "wing" }, { "Big spoiler", "spoiler" },
	{ "Ram bow", "nose" }, { "Roof rack", "arch" }, { "Neon keel", "neon" }, { "Twin stacks", "stack" }, { "Rocket wall", "wall" },
	{ "Main foils", "wing" }, { "Giant jets", "rocket" }, { "Tall fin", "fin" }, { "Foil struts", "strut" }, { "Neon wings", "neon" },
	{ "Air scoops", "stack" }, { "Delta spoiler", "spoiler" }, { "Sharp nose", "nose" }, { "Thrust ring", "arch" }, { "Jet wall", "wall" },
	{ "Boosters", "rocket" }, { "Gold plate", "gold" }, { "Solar sails", "wing" }, { "Twin boosters", "stack" }, { "Gold spoiler", "spoiler" },
	{ "Gold nose", "nose" }, { "Neon ring", "arch" }, { "Giant fins", "fin" }, { "Gold armour", "plate" }, { "The Wall", "wall" },
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
			turnRadius = 100 + 0.25 * speed,
			reach = math.max(14, math.floor(speed * BoatLevels.REACH_TIME + 0.5)),
			callReach = if stageIndex == 1 then 2000 elseif stageIndex == 2 then 3500 else 5500,
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
		if row.speed >= speed and row.room >= room then
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
	out.turnRate = math.max(spec.turnRate, math.deg(yaw) * 1.15)
	out.lateralGrip = math.max(spec.lateralGrip, yaw / 2.8) -- at most about 25 degrees of slip in a hard turn
	out.survivorCapacity = row.room
	out.hullSize = spec.hullSize * s
	out.draft = spec.draft * s
	out.massHint = spec.massHint * s * s * s
	out.turnRadiusSlow = spec.turnRadiusSlow * s
	local points = {}
	for i, p in spec.floatPoints do
		points[i] = p * s
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
-- any look at any scale), later levels bigger. Art replaces these after a concept and AD (design before Blender).
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

function BoatLevels.pieceParts(value: any, hullSize: Vector3): { PiecePart }
	local row = BoatLevels.row(value)
	local out: { PiecePart } = {}
	for level = BoatLevels.Stages[row.stage].first, row.level do
		local piece = ROWS[level]
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
	end
	return out
end

return BoatLevels
