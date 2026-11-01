-- selene: allow(undefined_variable)
-- Player clips (SprintController): Run, the sprint (Shift / L3 / full touch stick, 20 studs/s). R15, faces -Z, in place.
local IK = require("_ik")
local S = IK.stance
local M = AnimKit.merge
local sin, cos, pi = math.sin, math.cos, math.pi

local RT = 0.5 -- one cycle = two strides; SprintController scales the speed by ground speed / RUN_PACE (20)

-- one foot's path over its cycle (ph 0 = lands in front): stance, toe-off, heel kick, knee drive, reach
local PATH = { -- ph, z, h, p (pitch, +toes up)
	{ 0.0, -0.9, 0, 6 },
	{ 0.135, 0.05, 0, 0 },
	{ 0.27, 1.0, 0, -40 }, -- toe-off (flight ~23% of each stride)
	{ 0.5, 0.75, 1.5, -65 }, -- heel kicks up behind
	{ 0.7, -0.55, 1.3, -20 }, -- knee drive
	{ 0.86, -1.05, 0.45, 2 }, -- reach
	{ 1.0, -0.9, 0, 6 },
}
local function foot(ph, sgn)
	for i = 1, #PATH - 1 do
		local a, b = PATH[i], PATH[i + 1]
		if ph >= a[1] and ph <= b[1] then
			local s = (ph - a[1]) / (b[1] - a[1])
			if i > 2 then -- in the air: ease the arc; on the ground the foot slides back at an even speed
				s = s * s * (3 - 2 * s)
			end
			local f = {
				x = sgn * 0.5,
				z = a[2] + (b[2] - a[2]) * s,
				h = a[3] + (b[3] - a[3]) * s,
				p = a[4] + (b[4] - a[4]) * s,
				yaw = -sgn * 4,
				k = 0.2,
			}
			f.toe = ph > 0.16 and ph < 0.6
			return f
		end
	end
	error("phase out of range")
end
local function run(ph)
	local c = cos(2 * pi * ph) -- +1 when the left foot lands in front
	local bob = cos(2 * pi * (2 * ph - 0.8)) -- +1 in the flight phase, -1 mid-stance
	local a = cos(2 * pi * (ph + 0.14)) -- each arm fully back when its own knee drives up
	local function swing(v)
		return if v > 0 then 38 * v else 70 * v -- longer behind than in front
	end
	return M(S({ pos = { 0, -0.1 + 0.2 * bob, 0 }, x = -18, y = -9 * c, z = 3 * sin(2 * pi * ph) }, foot(ph, -1), foot((ph + 0.5) % 1, 1)), {
		Waist = { x = -6 - 2 * bob, y = 11 * c, z = -2 * sin(2 * pi * ph) },
		Neck = { x = 20 + 2 * bob, y = -5 * c },
		RightShoulder = { x = -8 + swing(a), z = 8 },
		RightElbow = { x = 66 + 10 * math.max(a, 0) },
		RightWrist = { x = -10 },
		LeftShoulder = { x = -8 + swing(-a), z = -8 },
		LeftElbow = { x = 66 + 10 * math.max(-a, 0) },
		LeftWrist = { x = -10 },
	})
end
local keys = {}
for i = 0, 16 do
	table.insert(keys, { t = math.floor(RT * i / 16 * 1000 + 0.5) / 1000, ease = "Linear", pose = run((i % 16) / 16) })
end

return { { name = "PlayerRun", priority = "Movement", loop = true, keys = keys } }
