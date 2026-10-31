-- selene: allow(undefined_variable)
-- NPC clips (NpcFactory POSES; Wave also the Whistle cosmetic): Idle, Wave, Sit, Tread. R15 blocky, faces -Z.
-- AD rounds: build/status/2026-10-31/perfect/anim/RESULT.md (main checkout).
local IK = require("_ik")
local S = IK.stance
local A = IK.arm
local M = AnimKit.merge

---------------------------------------------------------------- Idle: arms folded, weight shifts, a glance, a free-foot tap
local FL, FR = { x = -0.62, z = -0.1, yaw = 12 }, { x = 0.62, z = 0.05, yaw = -12 }
local function folded(sh)
	return { -- forearms level across the chest, right over left
		RightShoulder = A(25 + sh, -12, 90), -- forearms crossing close to the chest, right over left (FK + Studio probe)
		RightElbow = { x = 85 },
		RightWrist = { x = 0 },
		LeftShoulder = A(20 + sh, 12, -100),
		LeftElbow = { x = 92 },
		LeftWrist = { x = 0 },
	}
end
local function idle(dx, dy, rz, tap, wx, wy)
	-- dx < 0: weight on the left leg; the free foot taps its toes (heel down, toes up)
	local lf, rf = table.clone(FL), table.clone(FR)
	if tap then
		local free = if dx < 0 then rf else lf
		free.heel, free.p = true, tap
	end
	return M(S({ pos = { dx, dy, 0 }, z = rz, y = -dx * 20 }, lf, rf), { Waist = { x = wx or 0, z = -rz, y = wy or dx * 25 } })
end
local function look(nx, ny, nz)
	return { Neck = { x = nx, y = ny, z = nz } }
end
local Idle = {
	name = "NpcIdle",
	priority = "Idle",
	loop = true,
	keys = {
		{ t = 0.0, pose = M(idle(-0.14, -0.06, 3), look(0, 0, 4), folded(0)) }, -- weight on the left
		{ t = 0.4, pose = idle(-0.14, -0.06, 3, 25) }, -- the free (right) foot taps
		{ t = 0.55, pose = idle(-0.14, -0.09, 3) },
		{ t = 0.7, pose = idle(-0.14, -0.06, 3, 25) },
		{ t = 0.85, pose = idle(-0.14, -0.09, 3) },
		{ t = 1.0, pose = idle(-0.14, -0.06, 3, 25) },
		{ t = 1.15, pose = idle(-0.14, -0.07, 3) },
		{ t = 1.4, pose = M(idle(-0.14, -0.04, 3, nil, 3), look(3, 6, 5), folded(4)) }, -- breathe in
		{ t = 1.9, ease = "Cubic", dir = "In", pose = M(idle(-0.17, -0.2, 6), look(0, 2, 4), folded(0)) }, -- dip before the shift
		{ t = 2.25, pose = look(0, 0, 0) },
		{ t = 2.35, ease = "Cubic", dir = "Out", pose = idle(0.19, -0.04, -4) }, -- onto the right, overshoot
		{ t = 2.5, ease = "Cubic", dir = "Out", pose = M(look(-2, -45, -7), idle(0.17, -0.05, -4, nil, 0, -8)) }, -- glance, the chest follows
		{ t = 2.65, pose = look(-2, -40, -6) },
		{ t = 2.75, pose = idle(0.15, -0.06, -3, nil, 0, -6) },
		{ t = 2.9, pose = idle(0.15, -0.06, -3, 25, 0, -6) }, -- the free (left) foot taps, impatient
		{ t = 3.0, pose = look(-6, -40, -6) }, -- nod
		{ t = 3.05, pose = idle(0.15, -0.08, -3, nil, 0, -6) },
		{ t = 3.2, pose = M(look(-2, -40, -6), idle(0.15, -0.06, -3, 25, 0, -6)) },
		{ t = 3.35, ease = "Cubic", dir = "InOut", pose = idle(0.15, -0.08, -3, nil, 0, -6) },
		{ t = 3.6, ease = "Cubic", dir = "InOut", pose = look(0, 0, 4) },
		{ t = 4.1, pose = M(idle(-0.05, -0.05, 0, nil, 3), folded(2)) }, -- a breath on the way back
		{ t = 4.4, pose = M(idle(-0.14, -0.06, 3), look(0, 0, 4), folded(0)) },
	},
}
table.sort(Idle.keys, function(a, b)
	return a.t < b.t
end)

---------------------------------------------------------------- Wave: big overhead wave, other hand cupped at the mouth
local WL, WR = { x = -0.66, z = -0.05, yaw = 10 }, { x = 0.62, z = 0.1, yaw = -12 }
local function wave(rz, dy, wz, wy, call)
	return M(S({ pos = { -0.06, dy, 0 }, z = 2 }, WL, WR), {
		Waist = { x = 2, z = wz, y = wy },
		Neck = { x = if call then -6 else 3, z = -wz * 0.5 },
		RightShoulder = { x = -6, y = 0, z = rz },
		LeftShoulder = { x = 118, z = 18 }, -- hand cupped in front of the mouth, calling out
		LeftElbow = { x = if call then 150 else 140 },
		LeftWrist = { x = -10, y = -40 },
	})
end
local function elbow(e)
	return { RightElbow = { x = e } }
end
-- two waves per loop, a little different; fast swing in (Cubic In), overshoot, hold, slower swing out; the elbow drags
local Wave = {
	name = "NpcWave",
	priority = "Action",
	loop = true,
	keys = {
		{ t = 0.0, ease = "Cubic", dir = "In", pose = M(wave(108, -0.15, -2, 0), elbow(5)) },
		{ t = 0.07, pose = elbow(35) },
		{ t = 0.14, ease = "Cubic", dir = "Out", pose = M(wave(178, -0.02, -14, -8, true), elbow(5)) }, -- over the top, call
		{ t = 0.26, ease = "Cubic", dir = "InOut", pose = wave(170, -0.04, -13, -8) }, -- settle, hold
		{ t = 0.38, pose = elbow(35) },
		{ t = 0.5, ease = "Cubic", dir = "In", pose = M(wave(102, -0.15, -2, 0), elbow(5)) }, -- out: the wave lands
		{ t = 0.57, pose = elbow(35) },
		{ t = 0.64, ease = "Cubic", dir = "Out", pose = M(wave(180, -0.02, -14, -8, true), elbow(5)) },
		{ t = 0.76, ease = "Cubic", dir = "InOut", pose = wave(174, -0.04, -13, -8) },
		{ t = 0.88, pose = elbow(35) },
		{ t = 1.0, ease = "Cubic", dir = "InOut", pose = M(wave(110, -0.15, -2, 0), elbow(5)) },
		{ t = 1.2, pose = M(wave(108, -0.15, -2, 0), elbow(5)) },
	},
}

---------------------------------------------------------------- Sit: on the ground hugging the knees, shivering in a blanket
local SF, SR = { x = -0.42, z = -1.05, yaw = 6 }, { x = 0.42, z = -1.0, yaw = -6 }
-- hug = 0 hunched over the knees, 1 rocked back (the shoulders open so the forearms stay on the knees)
local function sit(hug, nx, ny, wy, sq, shiver, lift)
	local rx, wx = -14 + 12 * hug, -22 + 14 * hug
	return M(S({ pos = { 0, -1.66 + (lift or 0), 0.25 }, x = rx }, SF, SR), {
		Waist = { x = wx, y = wy, z = shiver },
		Neck = { x = nx, y = ny, z = -shiver * 0.6 },
		RightShoulder = { x = 40 + 24 * hug + sq, z = -30 }, -- forearms cross in front of the shins, right over left
		RightElbow = { x = 96 - 6 * hug },
		LeftShoulder = { x = 40 + 24 * hug + sq, z = 30 },
		LeftElbow = { x = 108 - 18 * hug },
	})
end
local Sit = { name = "NpcSit", priority = "Idle", loop = true, keys = {} }
local function add(t, pose, ease, dir)
	table.insert(Sit.keys, { t = t, pose = pose, ease = ease, dir = dir })
end
local function burst(t0, n)
	for i = 1, n do
		local s = if i % 2 == 1 then 6 else -6
		add(t0 + i * 0.07, sit(0, 8, 0, 0, if i % 2 == 1 then 4 else -4, s, if i % 2 == 1 then 0.03 else 0), "Linear")
	end
end
add(0.0, sit(0, 8, 0, 0, 0, 0))
burst(0.0, 8) -- chin on the knees, eyes peeking out
add(0.7, sit(0, 8, 0, 0, 0, 0), "Cubic", "InOut")
add(1.5, sit(1, 24, 35, 8, 0, 0), "Cubic", "Out") -- rock back, look up the shore
add(2.2, sit(1, 22, 30, 7, 0, 0), "Cubic", "InOut")
add(2.5, sit(0, 8, 2, 0, 0, 0))
burst(2.5, 8)
add(3.2, sit(0, 8, 0, 0, 0, 0)) -- calm hold
add(3.6, sit(0, 8, 0, 0, 0, 0))

---------------------------------------------------------------- Tread: treading water, a bit frantic (bicycle kicks, sculling)
-- 32 keys of 0.12 s: legs cycle every 4 keys (bicycle, 180 apart), arms scull out/in every 4 keys at the water line,
-- the body bobs low on each downstroke, the head holds a look left then right
local function leg(q)
	return ({
		{ x = 52, k = -94, a = -35 }, -- forward, tucked
		{ x = 10, k = -30, a = 10 }, -- downstroke: toes up, pushing
		{ x = -5, k = -40, a = -20 },
		{ x = 30, k = -100, a = -35 }, -- recover
	})[q % 4 + 1]
end
local LOOK = { 0, 0, 4, 10, 22, 32, 32, 32, 32, 30, 18, 6, 0, 0, 0, 0, 0, 0, -4, -10, -22, -32, -32, -32, -32, -30, -18, -6, 0, 0, 0, 0 }
local Tread = { name = "NpcTread", priority = "Idle", loop = true, keys = {} }
for i = 0, 32 do
	local k = i % 32
	local l, r = leg(k), leg(k + 2)
	local out = (1 + math.cos(2 * math.pi * k / 4)) / 2 -- 1 = swept out, 0 = swept in
	local feather = math.sin(2 * math.pi * k / 4) * 35 -- palms turn with the sweep
	local ny = LOOK[k + 1]
	table.insert(Tread.keys, {
		t = math.floor(0.12 * i * 1000 + 0.5) / 1000,
		ease = "Linear",
		pose = {
			Root = { pos = { 0, if k % 2 == 1 then -0.03 else 0.03, 0 }, x = 6 },
			Waist = { x = -8 },
			Neck = { x = 14, y = ny, z = ny * 0.18 },
			RightShoulder = { x = 18, z = 18 + 20 * out },
			RightElbow = { x = 75 },
			RightWrist = { z = feather },
			LeftShoulder = { x = 18, z = -18 - 20 * out },
			LeftElbow = { x = 75 },
			LeftWrist = { z = -feather },
			LeftHip = { x = l.x, z = -18 },
			LeftKnee = { x = l.k },
			LeftAnkle = { x = l.a },
			RightHip = { x = r.x, z = 18 },
			RightKnee = { x = r.k },
			RightAnkle = { x = r.a },
		},
	})
end

return { Idle, Wave, Sit, Tread }
