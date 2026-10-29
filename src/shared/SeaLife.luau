--!strict
-- SeaLife (sea1, owner 2026-10-29: "more content on the sea, it looks too empty"): where the client's ambient sea
-- life and things to see sit (SeaLifeController draws them, local only). Pure data and paths, Lune-safe
-- (tests/SeaLife.spec.luau checks every route and spot is open water, clear of the berths, the bridges and the
-- islands). Paths run on Workspace:GetServerTimeNow(), so every client sees the same boat in the same place.
--   * Boats: the existing fishing-boat meshes (M_Veh_MooredBoat_02 / _03) on lazy loops round the ring, two
--     herring gulls trailing each;
--   * Pods: Lego dolphins swimming a loop, leaping one after another near the camera (VFX dolphin_leap);
--   * Whale: a Lego whale far out that breaches now and then (VFX whale_breach);
--   * Sandbars: low Lego sand plates (no collision: shallows you skim over), each marked by Lego isolated-danger
--     buoys; Gull Bank carries a beached Lego wreck and a gull loop;
--   * WreckMarks: Lego blue/yellow wreck buoys over the sunken Morwenna (WorldConfig POI 1);
--   * Flotsam: drifting crates, a barrel and planks.
local SeaLife = {}

export type Loop = { centre: Vector3, r: number, speed: number, dir: number, phase: number }

SeaLife.Boats = {
	{
		asset = "M_Veh_MooredBoat_02",
		loop = { centre = Vector3.zero, r = 1450, speed = 9, dir = 1, phase = 0 },
	},
	{
		asset = "M_Veh_MooredBoat_03",
		loop = { centre = Vector3.zero, r = 1450, speed = 8, dir = 1, phase = 2.1 },
	},
	{
		asset = "M_Veh_MooredBoat_02",
		loop = { centre = Vector3.zero, r = 1450, speed = 9, dir = 1, phase = 4.2 },
	},
	{
		asset = "M_Veh_MooredBoat_03",
		loop = { centre = Vector3.zero, r = 1150, speed = 7, dir = -1, phase = 1 },
	},
} :: { { asset: string, loop: Loop } }

SeaLife.Pods = {
	{ size = 4, loop = { centre = Vector3.zero, r = 1300, speed = 14, dir = -1, phase = 0.5 } },
	{
		size = 3,
		loop = { centre = Vector3.new(2400, 0, -200), r = 300, speed = 10, dir = 1, phase = 0 },
	},
} :: { { size: number, loop: Loop } }

SeaLife.Whale =
	{ centre = Vector3.new(-2200, 0, -1800), r = 220, speed = 5, dir = 1, phase = 0 } :: Loop
SeaLife.BREACH_EVERY = { 35, 70 } -- s between breaches while the camera is in range -- tune

SeaLife.Sandbars = {
	{
		id = "GullBank",
		at = Vector3.new(-1515, 0, 875),
		size = Vector2.new(150, 80),
		yaw = 25,
		wreck = true,
	},
	{
		id = "EastShoal",
		at = Vector3.new(1530, 0, -1290),
		size = Vector2.new(110, 60),
		yaw = -40,
		wreck = false,
	},
}

SeaLife.WreckMarks = { Vector3.new(1060, 0, -640), Vector3.new(1140, 0, -640) } -- either side of the Morwenna

SeaLife.Flotsam = {
	Vector3.new(-950, 0, -900),
	Vector3.new(1250, 0, 350),
	Vector3.new(-1700, 0, -300),
	Vector3.new(300, 0, -1500),
	Vector3.new(-600, 0, 1600),
	Vector3.new(2000, 0, 500),
	Vector3.new(700, 0, 1300),
	Vector3.new(-2000, 0, -1000),
}

-- Draw distances (studs from the camera), x the quality scale (High 1, Medium 0.75, Low 0.5).
SeaLife.NEAR = { boat = 1400, pod = 450, whale = 900, sandbar = 1200, flotsam = 450 }

-- Where a loop is at time t (flat, Y 0) and its heading (unit, flat). A slow radial wander keeps it lazy.
function SeaLife.at(l: Loop, t: number): (Vector3, Vector3)
	local a = l.phase + l.dir * t * l.speed / l.r
	local r = l.r + 0.04 * l.r * math.sin(a * 3)
	local p = l.centre + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	local a2 = a + l.dir * 0.01
	local r2 = l.r + 0.04 * l.r * math.sin(a2 * 3)
	local q = l.centre + Vector3.new(math.cos(a2) * r2, 0, math.sin(a2) * r2)
	return p, (q - p).Unit
end

-- Height (studs above the sea) and pitch (radians, nose up +) of a leap `u` (0..1) of `height` studs: a parabola.
function SeaLife.leap(u: number, height: number): (number, number)
	local y = 4 * height * u * (1 - u)
	return y, math.atan(4 * height * (1 - 2 * u) / 18) -- 18: the leap's length in studs
end

return SeaLife
