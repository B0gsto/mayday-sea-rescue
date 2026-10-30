--!strict
-- Hangout (owner 2026-10-29: "idle rescuers ... playing on their phones, chatting, staying around the item, some
-- sleeping, some eating inside a house that we can enter"): where a worker with no job slot spends the day. The
-- commons behind the HQ (it arrives with the streets, DockPieces.hangout builds the props): a walk-in canteen hut,
-- a campfire with log benches, two park benches, a hammock, an ice-cream cart, two chat circles; plus three Bunkhouse
-- bunks while one stands. Every prop sits in island (r, f) space clear of the streets (8 wide), the avenue's belts,
-- the build lots, the Boats stand and the berths. A spot is local to its prop (x right, z back; the prop's front is
-- -Z): where the worker stands (x, z), what it faces (fx, fz), its activity (WorkerController poses it) and an
-- optional rest (sit / lie: the hips' spot, y up from the ground; head: the way a sleeper's head points). Pure
-- (tests/Hangout.spec.luau).
local DockConfig = require(script.Parent:WaitForChild("Config"):WaitForChild("DockConfig"))
local Marina = require(script.Parent:WaitForChild("Marina"))

local Hangout = {}

export type Act = "Phone" | "Chat" | "Eat" | "Sleep" | "Cone" | "Warm"
export type Spot = {
	prop: string,
	x: number,
	z: number,
	fx: number,
	fz: number,
	act: Act,
	rest: Vector3?, -- sit / lie spot (prop space, y = up from the prop's ground)
	head: Vector2?, -- lying: the head's way (prop x, z)
}

-- island (r, f, yaw): r right, f out toward the cove; yaw turns the prop's front (-Z) round
Hangout.PROPS = {
	Canteen = { r = 40, f = -48, yaw = 90, size = Vector2.new(14, 12) }, -- open front onto the avenue
	Campfire = { r = 20, f = -62, yaw = 0, size = Vector2.new(12, 12) },
	ChatEast = { r = 20, f = -42, yaw = 0, size = Vector2.new(5, 5) },
	BenchA = { r = -20, f = -40, yaw = 180, size = Vector2.new(6, 3) }, -- facing the spawn and the bridge road
	BenchB = { r = -32, f = -40, yaw = 180, size = Vector2.new(6, 3) },
	Cart = { r = -22, f = -60, yaw = -90, size = Vector2.new(5, 4) }, -- serving the avenue
	Hammock = { r = -44, f = -58, yaw = 0, size = Vector2.new(3, 10) },
	ChatWest = { r = -34, f = -68, yaw = 0, size = Vector2.new(5, 3) },
} :: { [string]: { r: number, f: number, yaw: number, size: Vector2 } }

Hangout.CANTEEN_FLOOR = 0.4 -- the canteen's floor plate top
Hangout.STOOL = 1.6 -- seat tops over the canteen floor
Hangout.LOG = 1.3 -- the campfire logs
Hangout.BENCH = 1.5 -- the park benches
Hangout.HAMMOCK = 2.3

local F, S, L, B = Hangout.CANTEEN_FLOOR, Hangout.STOOL, Hangout.LOG, Hangout.BENCH
local V3 = Vector3.new
-- the Bunkhouse mesh's Lv1 bunks (M_Bld_Bunkhouse mesh space: the mesh stands unscaled, Studio 2026-10-30: its Lv1
-- floor is 1.1 over the lot, not 1.32): stand on the room side by the
-- pillow end facing the bunk, lie on the lower blanket (FL1 1.1 + 2.0), the head on the pillow (the root 1.65 below it)
local FL1, MAT = 1.1, 2.0
local function bunk(x: number, z: number, bx: number, bz: number, head: Vector2): Spot
	return {
		prop = "Bunkhouse",
		x = x,
		z = z,
		fx = if head.X == 0 then bx else x,
		fz = if head.X == 0 then z else bz,
		act = "Sleep",
		rest = V3(bx, FL1 + MAT, bz),
		head = head,
	}
end

-- in fill order: the first few idle workers already show every kind of rest
Hangout.SPOTS = {
	{ prop = "ChatEast", x = 0, z = -1.8, fx = 0, fz = 0, act = "Chat" },
	{ prop = "ChatEast", x = 1.56, z = 0.9, fx = 0, fz = 0, act = "Chat" },
	{ prop = "BenchA", x = -1.2, z = 0, fx = -1.2, fz = -3, act = "Phone", rest = V3(-1.2, B, 0) },
	{
		prop = "Canteen",
		x = -1.6,
		z = -2.9,
		fx = -1.6,
		fz = 0,
		act = "Eat",
		rest = V3(-1.6, F + S, -2.9),
	},
	{
		prop = "Canteen",
		x = 1.6,
		z = 1.9,
		fx = 1.6,
		fz = 0,
		act = "Eat",
		rest = V3(1.6, F + S, 1.9),
	},
	{ prop = "Cart", x = -1.3, z = -3.2, fx = -1.3, fz = 0, act = "Cone" },
	{
		prop = "Hammock",
		x = 0,
		z = 0,
		fx = 0,
		fz = -4,
		act = "Sleep",
		rest = V3(0, Hangout.HAMMOCK, 0),
		head = Vector2.new(0, 1),
	},
	bunk(9.0, 3.0, 11.5, 3.8, Vector2.new(0, -1)), -- room A, the west wall
	{
		prop = "Campfire",
		x = -1.3,
		z = -4.5,
		fx = -1.3,
		fz = 0,
		act = "Chat",
		rest = V3(-1.3, L, -4.5),
	},
	{ prop = "Campfire", x = 1.3, z = 4.5, fx = 1.3, fz = 0, act = "Chat", rest = V3(1.3, L, 4.5) },
	{ prop = "ChatEast", x = -1.56, z = 0.9, fx = 0, fz = 0, act = "Chat" },
	{ prop = "BenchA", x = 1.2, z = 0, fx = 1.2, fz = -3, act = "Phone", rest = V3(1.2, B, 0) },
	{ prop = "ChatWest", x = -1.1, z = 0, fx = 0, fz = 0, act = "Chat" },
	{ prop = "ChatWest", x = 1.1, z = 0, fx = 0, fz = 0, act = "Chat" },
	{
		prop = "Canteen",
		x = 1.6,
		z = -2.9,
		fx = 1.6,
		fz = 0,
		act = "Eat",
		rest = V3(1.6, F + S, -2.9),
	},
	{ prop = "Campfire", x = 4.6, z = 0, fx = 0, fz = 0, act = "Warm" },
	{ prop = "BenchB", x = -1.2, z = 0, fx = -1.2, fz = -3, act = "Phone", rest = V3(-1.2, B, 0) },
	bunk(-9.0, 3.0, -11.5, 3.8, Vector2.new(0, -1)), -- room D
	{ prop = "Cart", x = 1.3, z = -3.2, fx = 1.3, fz = 0, act = "Cone" },
	{
		prop = "Canteen",
		x = -1.6,
		z = 1.9,
		fx = -1.6,
		fz = 0,
		act = "Eat",
		rest = V3(-1.6, F + S, 1.9),
	},
	{
		prop = "Campfire",
		x = 1.3,
		z = -4.5,
		fx = 1.3,
		fz = 0,
		act = "Chat",
		rest = V3(1.3, L, -4.5),
	},
	{ prop = "BenchB", x = 1.2, z = 0, fx = 1.2, fz = -3, act = "Phone", rest = V3(1.2, B, 0) },
	bunk(7.4, 4.6, 6.6, 7.5, Vector2.new(1, 0)), -- room B, the back wall
	{
		prop = "Campfire",
		x = -1.3,
		z = 4.5,
		fx = -1.3,
		fz = 0,
		act = "Chat",
		rest = V3(-1.3, L, 4.5),
	},
	{ prop = "Campfire", x = -4.6, z = 0, fx = 0, fz = 0, act = "Warm" },
} :: { Spot }

-- the prop's frame (front -Z) in the berth frame `bay`, on the ground (the Bunkhouse: its lot)
function Hangout.frame(bay: CFrame, prop: string): CFrame
	if prop == "Bunkhouse" then
		return bay * DockConfig.Buildings.Bunkhouse.spot
	end
	local p = Hangout.PROPS[prop]
	return bay * Marina.ISLAND * CFrame.new(p.r, 0, -p.f) * CFrame.Angles(0, math.rad(p.yaw), 0)
end

-- The worker's feet CFrame (facing its activity) and its rest relative to the feet (nil: stands).
function Hangout.place(bay: CFrame, s: Spot): (CFrame, CFrame?)
	local at = Hangout.frame(bay, s.prop)
	local y = if s.prop == "Bunkhouse" then FL1 elseif s.prop == "Canteen" then F else 0
	local p = (at * CFrame.new(s.x, y, s.z)).Position
	local look = (at * CFrame.new(s.fx, y, s.fz)).Position
	local feet = CFrame.lookAt(p, look)
	if not s.rest then
		return feet, nil
	end
	local rp = (at * CFrame.new(s.rest)).Position
	local rest = if s.head
		then CFrame.lookAt(rp, rp - at:VectorToWorldSpace(Vector3.new(s.head.X, 0, s.head.Y))) -- +Z = head
		else CFrame.new(rp) * feet.Rotation
	return feet, feet:ToObjectSpace(rest)
end

-- Spot k is open on this island: the bunks need a Bunkhouse.
function Hangout.open(s: Spot, bunkhouse: boolean): boolean
	return s.prop ~= "Bunkhouse" or bunkhouse
end

-- Next seating for `idle` (worker index list, any order) given last time's `had` (index -> spot): keeps everyone
-- who still has an open spot, seats newcomers in fill order, and when `move` is a worker index (rotation) walks
-- them to the free spot `pick` chooses among the open free ones (1..n -> k-th). Past the spots: unseated (inside).
function Hangout.seat(
	idle: { number },
	had: { [number]: number },
	bunkhouse: boolean,
	move: number?,
	pick: ((n: number) -> number)?
): { [number]: number }
	local out, taken = {}, {}
	for _, i in idle do
		local k = had[i]
		if
			k
			and Hangout.SPOTS[k]
			and Hangout.open(Hangout.SPOTS[k], bunkhouse)
			and not taken[k]
		then
			out[i], taken[k] = k, true
		end
	end
	local function free(): { number }
		local list = {}
		for k, s in Hangout.SPOTS do
			if not taken[k] and Hangout.open(s, bunkhouse) then
				table.insert(list, k)
			end
		end
		return list
	end
	for _, i in idle do
		if not out[i] then
			local k = free()[1]
			if not k then
				break
			end
			out[i], taken[k] = k, true
		end
	end
	if move and out[move] and pick then
		local list = free()
		if #list > 0 then
			taken[out[move]] = nil
			local k = list[math.clamp(pick(#list), 1, #list)]
			out[move], taken[k] = k, true
		end
	end
	return out
end

return Hangout
