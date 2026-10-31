-- selene: allow(undefined_variable)
-- Worker clips (WorkerController): Idle, Idle2, Walk, Carry, Hammer, Point, Climb, Celebrate. R15 blocky, faces -Z.
-- Conventions: ~/RobloxProjects/TameATitan/docs/animation-guide.md. Clips are in place; looping clips end on their first key.
-- AD rounds: build/status/2026-10-31/perfect/anim/RESULT.md (main checkout).
local IK = require("_ik")
local S = IK.stance
local A = IK.arm
local M = AnimKit.merge
local sin, cos, pi = math.sin, math.cos, math.pi

-- relaxed hanging arms (never dead straight), close to the torso
local function arms(rs, re, ls, le)
	return {
		RightShoulder = rs or { x = 4, z = 5 },
		RightElbow = re or { x = 14 },
		LeftShoulder = ls or { x = 2, z = -6 },
		LeftElbow = le or { x = 12 },
	}
end

-- loop helper: n evenly spaced keys over T from f(phase 0..1), last key = first (f must be periodic)
local function cycle(T, n, f, ease)
	local keys = {}
	for i = 0, n do
		local ph = (i % n) / n
		table.insert(keys, { t = math.floor(T * i / n * 1000 + 0.5) / 1000, ease = ease or "Linear", pose = f(ph) })
	end
	return keys
end

---------------------------------------------------------------- Idle: contrapposto, breathing, a look round with a snap
-- weight on the right leg (locked), the left knee breaks forward and in
local LF, RF = { x = -0.6, z = -0.28, yaw = 16, k = 0.3 }, { x = 0.6, z = 0.06, yaw = -12 }
local function body(dx, dy, wx, wy)
	return M(S({ pos = { 0.18 + dx, -0.02 + dy, 0 }, y = 5, z = -5 }, LF, RF), { Waist = { x = wx, y = wy, z = 4 } })
end
local function head(nx, ny)
	return { Neck = { x = nx, y = ny, z = -4 } }
end
local function idleArms(sh, drag)
	return arms({ x = 4 - sh, z = 5 + sh }, { x = 14 + sh + drag }, { x = 3 - sh, z = -4 - sh }, { x = 16 + sh + drag })
end
local Idle = {
	name = "WorkerIdle",
	priority = "Idle",
	loop = true,
	-- sparse keys: each joint eases between its own keys
	keys = {
		{ t = 0.0, pose = M(body(0, 0, 0, -5), head(0, 0), idleArms(0, 0)) },
		{ t = 0.9, pose = M(body(0.01, 0.07, 6, -5), head(2, 2)) }, -- breathe in: chest up
		{ t = 1.1, pose = idleArms(5, 0) }, -- shoulders follow the breath
		{ t = 1.8, pose = M(body(0, -0.02, -2, -5), idleArms(0, 0)) }, -- breathe out
		{ t = 2.7, pose = body(0.01, 0.06, 5, -5) }, -- breathe in
		{ t = 2.9, pose = idleArms(4, 0) },
		{ t = 3.0, pose = head(-4, -6) }, -- anticipation: dip the other way
		{ t = 3.2, ease = "Cubic", dir = "Out", pose = head(3, 34) }, -- snap a look left
		{ t = 3.3, pose = body(0.03, 0.05, 4, -2) },
		{ t = 3.4, pose = M(head(2, 28), idleArms(4, 4)) }, -- settle
		{ t = 3.7, pose = body(0.03, 0.03, 3, 1) }, -- the torso follows the head, late
		{ t = 4.2, pose = M(head(1, 27), body(0.02, 0.01, 1, 0), idleArms(2, 1)) },
		{ t = 4.6, ease = "Cubic", dir = "InOut", pose = head(-2, 2) }, -- look back
		{ t = 4.7, pose = idleArms(0, 4) }, -- the elbows drag after the turn
		{ t = 4.8, pose = body(0, -0.02, -2, -5) }, -- breathe out
		{ t = 5.0, pose = idleArms(0, 0) },
		{ t = 5.1, pose = body(0.02, -0.02, -1, -5) }, -- weight settles
		{ t = 5.4, pose = M(body(0, 0, 0, -5), head(0, 0), idleArms(0, 0)) },
	},
}

---------------------------------------------------------------- Idle2: foreman, fists on hips, rocks onto the toes, surveys
local function hips(sh)
	return {
		RightShoulder = A(-15, 50 + sh, 90), -- elbows winged out, fists on the belt (checked by FK + Studio probe)
		RightElbow = { x = 110 },
		RightWrist = { x = 0, z = 0 },
		LeftShoulder = A(-15, -50 - sh, -90),
		LeftElbow = { x = 110 },
		LeftWrist = { x = 0, z = 0 },
	}
end
local F2L, F2R = { x = -0.72, z = 0, yaw = 14 }, { x = 0.72, z = 0, yaw = -14 }
local function stand2(ry, rootx, wx, mode)
	local lf, rf = table.clone(F2L), table.clone(F2R)
	if mode == "toe" then
		lf.toe, rf.toe, lf.p, rf.p = true, true, -32, -32
	elseif mode == "heel" then
		lf.heel, rf.heel, lf.p, rf.p = true, true, 8, 8
	end
	return M(S({ pos = { 0, ry, 0 }, x = rootx }, lf, rf), { Waist = { x = wx } })
end
local function look2(nx, ny, wy)
	return { Neck = { x = nx, y = ny }, Waist = wy and { x = 3, y = wy } or nil }
end
local Idle2 = {
	name = "WorkerIdle2",
	priority = "Idle",
	loop = true,
	-- sparse keys: each joint eases between its own keys; the arms trail the body by ~0.1 s
	keys = {
		{ t = 0.0, pose = M(stand2(-0.04, 2, 3), look2(2, 0), hips(0)) },
		{ t = 0.3, ease = "Cubic", dir = "In", pose = stand2(-0.16, 3, 2) }, -- dip
		{ t = 0.4, pose = hips(2) },
		{ t = 0.7, ease = "Cubic", dir = "Out", pose = M(stand2(0.22, -3, -1, "toe"), look2(-2, 0)) }, -- up on the toes
		{ t = 0.8, pose = hips(8) }, -- the elbows wing on the rise
		{ t = 1.0, ease = "Cubic", dir = "In", pose = M(stand2(0.22, -3, 0, "toe"), look2(-1, 4)) },
		{ t = 1.35, ease = "Cubic", dir = "InOut", pose = stand2(-0.08, 3, 4) }, -- drop, speeding into the heels
		{ t = 1.45, pose = hips(-3) }, -- elbows overshoot on the drop
		{ t = 1.55, ease = "Cubic", dir = "InOut", pose = stand2(-0.1, 4, 5, "heel") }, -- rock back past rest
		{ t = 1.7, pose = M(stand2(-0.04, 2, 3), look2(4, 4)) },
		{ t = 1.75, pose = hips(0) },
		{ t = 1.9, ease = "Cubic", dir = "Out", pose = look2(7, 40) }, -- head leads the survey
		{ t = 2.02, pose = { Waist = { x = 3, y = 12 } } },
		{ t = 2.45, pose = look2(6, 36) }, -- hold
		{ t = 2.7, ease = "Cubic", dir = "InOut", pose = look2(3, -4) },
		{ t = 2.85, ease = "Cubic", dir = "Out", pose = look2(7, -40) },
		{ t = 2.97, pose = { Waist = { x = 3, y = -12 } } },
		{ t = 3.3, pose = look2(6, -36) }, -- hold
		{ t = 3.6, ease = "Cubic", dir = "Out", pose = M(look2(2, 4), { Waist = { x = 3, y = 0 } }) }, -- swing past centre
		{ t = 3.8, pose = look2(2, 3) },
		{ t = 4.0, pose = M(stand2(-0.04, 2, 3), look2(2, 0), hips(0)) },
	},
}

---------------------------------------------------------------- Walk: bouncy jaunty stride, chest up, feet planted (IK)
local WT, STRIDE = 0.453, 0.68 -- covers 4 * STRIDE / WT = 6.0 studs/s at speed 1 (WorkerController ANIM_PACE)
local function foot(ph, sgn)
	-- ph 0..0.5 stance (front -> back), 0.5..1 swing (back -> front)
	if ph < 0.5 then
		local s = ph / 0.5
		local f = { x = sgn * 0.55, z = -STRIDE + 2 * STRIDE * s, yaw = -sgn * 6 }
		if s < 0.18 then -- heel strike rolls flat
			f.heel, f.p = true, 18 * (1 - s / 0.18)
		elseif s > 0.8 then -- push off the ball
			f.toe, f.p = true, -30 * (s - 0.8) / 0.2
		end
		return f
	end
	local s = (ph - 0.5) / 0.5
	local e = s * s * (3 - 2 * s)
	return {
		x = sgn * 0.55,
		z = STRIDE - 2 * STRIDE * e,
		h = 0.6 * sin(pi * s ^ 0.75),
		p = -30 + 48 * s,
		toe = s < 0.25,
		heel = s >= 0.25,
		yaw = -sgn * 6,
	}
end
local function sharp(b)
	return (if b < 0 then -1 else 1) * math.abs(b) ^ 0.6
end
local function walkPose(ph)
	local c = cos(2 * pi * ph) -- +1 when the left foot is forward
	local bob = sharp(cos(2 * pi * (2 * (ph - 0.05) - 0.5))) -- down just after contact, up at passing
	local bobL = sharp(cos(2 * pi * (2 * (ph - 0.1) - 0.5))) -- the head follows through
	local a = cos(2 * pi * (ph - 0.1)) -- arms lag the hips
	local fl = cos(2 * pi * (ph - 0.18)) -- hands lag the arms
	local function swing(v)
		return 30 * v
	end
	return M(
		S({ pos = { -0.1 * sin(2 * pi * ph), -0.02 + 0.12 * bob, 0 }, x = -2, y = -7 * c, z = 5 * sin(2 * pi * ph) }, foot(ph, -1), foot((ph + 0.5) % 1, 1)),
		{
			Waist = { x = 1 - 5 * bobL, y = 11 * c, z = -3 * sin(2 * pi * ph) },
			Neck = { x = 1 + 3 * bobL, y = -4 * c, z = -4 * sin(2 * pi * ph) },
			RightShoulder = { x = swing(a), z = 13 },
			RightElbow = { x = 22 + 18 * math.max(a, 0) },
			RightWrist = { x = 12 * math.max(fl, 0) },
			LeftShoulder = { x = swing(-a), z = -13 },
			LeftElbow = { x = 22 + 18 * math.max(-a, 0) },
			LeftWrist = { x = 12 * math.max(-fl, 0) },
		}
	)
end
local Walk = { name = "WorkerWalk", priority = "Movement", loop = true, keys = cycle(WT, 16, walkPose) }

---------------------------------------------------------------- Carry: a brick stack overhead, elbows out (upper body, over Walk)
-- the stack sits on the head (WorkerController bricks); hands cup the base brick's sides. One loop = 2 walk cycles
-- (2 * WT): the load sinks on each footfall (4 dips), sways once per cycle and counters the walk's hip yaw, so the
-- stack stays steady. WorkerController plays it at Walk's speed.
local CT = 2 * WT
local function carryPose(ph)
	local step = (ph * 4) % 1 -- 0 at each footfall
	local dip = math.max(0, math.cos(2 * pi * step)) ^ 2 -- sharp sink at the footfall, eased rise
	local cyc = (ph * 2) % 1 -- one walk cycle
	local sway = -5 * sin(2 * pi * (cyc - 0.05))
	local lag = math.max(0, math.cos(2 * pi * (step - 0.08))) ^ 2 -- the left arm a beat late
	return {
		Waist = { x = -1 - 2 * dip, y = 7 * cos(2 * pi * cyc), z = sway },
		Neck = { x = 1 + 2 * dip, z = -sway * 0.6 },
		RightShoulder = A(175 - 5 * dip, -28, 85), -- raised: -out tilts outward; elbows out (FK + Studio probe)
		RightElbow = { x = 50 + 12 * dip },
		RightWrist = { x = -35, z = 10 },
		LeftShoulder = A(171 - 5 * lag, 28, -85),
		LeftElbow = { x = 54 + 12 * lag },
		LeftWrist = { x = -35, z = -10 },
	}
end
local Carry = { name = "WorkerCarry", priority = "Action", loop = true, keys = cycle(CT, 16, carryPose) }

---------------------------------------------------------------- Hammer: wind up, whip down, hit-stop, bounce (full body)
-- the hammer head is along the hand's -Z (WorkerController dress: forward when the arm hangs)
local HL, HR = { x = -0.62, z = -0.4, yaw = 12 }, { x = 0.66, z = 0.35, yaw = -16 }
local function hammer(o)
	return M(S({ pos = { 0, o.ry, 0 }, x = o.rootx or 0, y = 6 }, HL, HR), {
		Waist = { x = o.wx, y = o.wy, z = 2 },
		Neck = { x = o.nx, y = o.ny or -4 },
		RightShoulder = { x = o.rs, z = o.rz or 8 },
		RightElbow = { x = o.re },
		RightWrist = { x = o.rw },
		LeftShoulder = { x = 48, z = 6 }, -- steadies the nail, low at the work
		LeftElbow = { x = o.le or 18 },
		LeftWrist = { x = -10 },
	})
end
-- shoulder leads, elbow drags, wrist snaps last
local IMPACT = hammer({ ry = -0.36, rootx = -6, wx = -22, wy = 6, nx = -24, rs = 48, re = 22, rw = -62 })
local Hammer = {
	name = "WorkerHammer",
	priority = "Action",
	loop = true,
	fill = true,
	keys = {
		{ t = 0.0, ease = "Constant", pose = IMPACT, markers = { Hit = 1 } },
		{ t = 0.03, ease = "Cubic", dir = "Out", pose = IMPACT }, -- hit-stop
		{ t = 0.1, ease = "Cubic", dir = "InOut", pose = hammer({ ry = -0.42, rootx = -7, wx = -20, wy = 4, nx = -28, rs = 60, re = 30, rw = -50, le = 28 }) }, -- bounce, nod, the left hand flinches
		{ t = 0.3, ease = "Cubic", dir = "Out", pose = hammer({ ry = -0.24, rootx = -2, wx = -6, wy = -9, nx = -26, ny = 6, rs = 112, rz = 18, re = 60, rw = -10 }) },
		{ t = 0.52, ease = "Cubic", dir = "InOut", pose = hammer({ ry = -0.16, rootx = 0, wx = 4, wy = -18, nx = -30, ny = 12, rs = 150, re = 95, rw = 15 }) }, -- cocked
		{ t = 0.66, ease = "Cubic", dir = "In", pose = hammer({ ry = -0.12, rootx = 1, wx = 9, wy = -19, nx = -30, ny = 12, rs = 154, re = 105, rw = 20 }) }, -- coil back
		{ t = 0.82, ease = "Linear", pose = hammer({ ry = -0.3, rootx = -6, wx = -18, wy = 4, nx = -26, rs = 95, rz = 18, re = 70, rw = -10 }) }, -- whip: body leads
		{ t = 0.9, pose = IMPACT },
	},
}

---------------------------------------------------------------- Point: snap a point out to sea, two jabs, relax (upper body)
local function point(wx, wy, nx, ny, rs, rz, re, rw, ls, le)
	return {
		Waist = { x = wx, y = wy },
		Neck = { x = nx, y = ny },
		RightShoulder = { x = rs, z = rz },
		RightElbow = { x = re },
		RightWrist = { x = rw },
		LeftShoulder = { x = ls, z = -10 },
		LeftElbow = { x = le },
	}
end
local P0 = point(0, 0, 0, 0, 4, 5, 14, 0, 2, 12)
local PHOLD = point(-4, -16, 6, -10, 90, 30, 4, 0, -15, 60)
local RECOIL = point(4, -15, 6, -10, 76, 30, 60, -18, -15, 60)
local JAB = point(-9, -18, 11, -11, 100, 30, 0, 6, -20, 62)
local Point = {
	name = "WorkerPoint",
	priority = "Action",
	loop = true,
	keys = {
		{ t = 0.0, pose = P0 },
		{ t = 0.22, ease = "Cubic", dir = "In", pose = point(4, 8, -4, -14, -28, 12, 95, -20, 8, 20) }, -- cock the fist back; eyes find the target
		{ t = 0.36, ease = "Cubic", dir = "Out", pose = point(-6, -20, 7, -13, 98, 34, 0, 8, -40, 50) }, -- snap out, the left arm counters
		{ t = 0.55, pose = PHOLD },
		{ t = 0.74, ease = "Cubic", dir = "In", pose = RECOIL },
		{ t = 0.86, ease = "Cubic", dir = "Out", pose = JAB },
		{ t = 1.0, ease = "Cubic", dir = "In", pose = RECOIL },
		{ t = 1.1, ease = "Cubic", dir = "Out", pose = JAB },
		{ t = 1.18, pose = point(-6, -17, 7, -10, 104, 30, 2, 2, -16, 60) }, -- settle
		{ t = 1.35, pose = PHOLD },
		{ t = 1.8, ease = "Cubic", dir = "In", pose = point(-3, -12, 4, -6, 84, 24, 12, 0, -10, 40) },
		{ t = 1.98, ease = "Cubic", dir = "InOut", pose = point(3, 2, -1, 2, -6, 5, 22, 4, 4, 14) }, -- drop past rest
		{ t = 2.4, pose = P0 },
	},
}

---------------------------------------------------------------- Climb: hand over hand up a ladder (faces the rungs)
-- reach: the high hand grabs the next rung; pull: the elbow drives down to the chest; the legs follow 0.06 s later
local function climbArms(reachR, pull)
	local hi = { s = A(172, -12, 0), e = 22 } -- raised arms: -out keeps the hands at shoulder width
	local lo = { s = A(104, -12, 0), e = 84 }
	local mid = { s = A(125, -12, 0), e = 70 } -- pulling, the elbow drives down
	local tuck = { s = A(118, -12, 0), e = 115 } -- releasing, the hand comes back in
	local r, l
	if pull then
		r, l = if reachR then mid else tuck, if reachR then tuck else mid
	else
		r, l = if reachR then hi else lo, if reachR then lo else hi
	end
	return {
		RightShoulder = r.s,
		RightElbow = { x = r.e },
		RightWrist = { x = -10 },
		LeftShoulder = { x = l.s.x, y = -l.s.y, z = -l.s.z },
		LeftElbow = { x = l.e },
		LeftWrist = { x = -10 },
	}
end
local LUP = { h = 52, k = -95, a = 10 } -- stepping up
local LPUSH = { h = 6, k = -6, a = -25 } -- straight, pushing off the toes
local LLIFT = { h = 50, k = -95, a = 0 } -- mid-step, still lifting
local LDRIVE = { h = 18, k = -25, a = -15 } -- mid-step, taking the weight
local function legsOf(l, r)
	return {
		LeftHip = { x = l.h, z = -4 },
		LeftKnee = { x = l.k },
		LeftAnkle = { x = l.a },
		RightHip = { x = r.h, z = 4 },
		RightKnee = { x = r.k },
		RightAnkle = { x = r.a },
	}
end
local function lerpLeg(a, b, k)
	return { h = a.h + (b.h - a.h) * k, k = a.k + (b.k - a.k) * k, a = a.a + (b.a - a.a) * k }
end
local function climbBody(dy, wx, wy, ny)
	return { Root = { pos = { 0, -0.1 + dy, -0.15 }, x = -6 }, Waist = { x = wx, y = wy }, Neck = { x = 16, y = ny } }
end
-- legs keyed 0.06 s after the arms; the loop seam (t 0 / 0.9) sits between the 0.83 and 0.96 leg keys
local SEAM = 0.07 / 0.13
local LEG_SEAM = legsOf(lerpLeg(LDRIVE, LUP, SEAM), lerpLeg(LLIFT, LPUSH, SEAM))
local Climb = {
	name = "WorkerClimb",
	priority = "Movement",
	loop = true,
	-- sparse keys: each joint eases between its own keys
	keys = {
		{ t = 0.0, ease = "Cubic", dir = "Out", pose = M(climbBody(0, -4, 7, 8), climbArms(true, false), LEG_SEAM) }, -- right hand grabs, look up at it
		{ t = 0.04, ease = "Cubic", dir = "InOut", pose = M(climbBody(-0.12, -8, 7, 8), { RightElbow = { x = 42 } }) }, -- catch: sag
		{ t = 0.06, pose = legsOf(LUP, LPUSH) },
		{ t = 0.12, pose = climbBody(0, -5, 6, 6) },
		{ t = 0.26, ease = "Cubic", dir = "Out", pose = M(climbBody(0.16, -2, 0, 0), climbArms(true, true)) }, -- pull
		{ t = 0.32, pose = legsOf(LLIFT, LDRIVE) },
		{ t = 0.45, ease = "Cubic", dir = "Out", pose = M(climbBody(0, -4, -7, -8), climbArms(false, false)) },
		{ t = 0.49, ease = "Cubic", dir = "InOut", pose = M(climbBody(-0.12, -8, -7, -8), { LeftElbow = { x = 42 } }) },
		{ t = 0.51, pose = legsOf(LPUSH, LUP) },
		{ t = 0.57, pose = climbBody(0, -5, -6, -6) },
		{ t = 0.71, ease = "Cubic", dir = "Out", pose = M(climbBody(0.16, -2, 0, 0), climbArms(false, true)) },
		{ t = 0.77, pose = legsOf(LDRIVE, LLIFT) },
		{ t = 0.9, pose = M(climbBody(0, -4, 7, 8), climbArms(true, false), LEG_SEAM) },
	},
}

---------------------------------------------------------------- Celebrate: crouch, big hop with a V, punches to the sky (one-shot)
local CF0, CF1 = { x = -0.6, z = -0.1, yaw = 10 }, { x = 0.6, z = 0.1, yaw = -10 }
local function air(h)
	return { x = -0.62, z = 0.25, h = h, p = -25, toe = true }, { x = 0.62, z = 0.3, h = h + 0.1, p = -25, toe = true }
end
local NEUTRAL = M(S({ pos = { 0, -0.04, 0 } }, CF0, CF1), { Waist = { x = 0 }, Neck = { x = 0 } }, arms())
local FIST_HIP = { LeftShoulder = A(-15, -50, -90), LeftElbow = { x = 110 } }
local function pump(up, ry, wx, bend, over)
	return M(
		S({ pos = { 0, ry, 0 }, y = 8, z = -4 }, CF0, CF1), -- lean toward the fist on the hip
		{ Waist = { x = wx, y = if up then 12 else -4, z = -6 }, Neck = { x = if up then 10 else 0, y = -6 } },
		{
			RightShoulder = if up then { x = over and 180 or 172, z = 20 } else { x = 70, z = 30 },
			RightElbow = { x = if up then 12 else 125 },
			RightWrist = { x = 0 },
		},
		FIST_HIP,
		{ LeftElbow = { x = 110 + (bend or 0) } }
	)
end
local Celebrate = {
	name = "WorkerCelebrate",
	priority = "Action2",
	loop = false,
	fill = true,
	keys = {
		{ t = 0.0, pose = NEUTRAL },
		{ t = 0.2, ease = "Cubic", dir = "In", pose = M(S({ pos = { 0, -0.6, 0 }, x = -12 }, CF0, CF1), {
			Waist = { x = -16 },
			Neck = { x = 6 },
		}, arms({ x = -40, z = 12 }, { x = 30 }, { x = -40, z = -12 }, { x = 30 })) }, -- crouch, arms swing back
		{ t = 0.32, ease = "Cubic", dir = "Out", pose = M(S({ pos = { 0, 0.7, 0 }, x = 4 }, air(0.7)), {
			Waist = { x = 8 },
			Neck = { x = 10 },
		}, arms({ x = 120, z = 30 }, { x = 40 }, { x = 120, z = -30 }, { x = 40 })) }, -- launch: arms trail the body
		{ t = 0.5, pose = M(S({ pos = { 0, 1.5, 0 }, x = 6 }, air(1.4)), {
			Waist = { x = 12 },
			Neck = { x = 16 },
			LeftKnee = { x = -60 },
			RightKnee = { x = -50 },
		}, arms({ x = 166, z = 44 }, { x = 4 }, { x = 166, z = -44 }, { x = 4 })) }, -- apex: big V, legs tucked
		{ t = 0.56, ease = "Cubic", dir = "In", pose = M(S({ pos = { 0, 1.45, 0 }, x = 6 }, air(1.35)), {
			Waist = { x = 12 },
			Neck = { x = 16 },
			LeftKnee = { x = -60 },
			RightKnee = { x = -50 },
		}, arms({ x = 168, z = 46 }, { x = 4 }, { x = 168, z = -46 }, { x = 4 })) }, -- hang
		{ t = 0.7, ease = "Cubic", dir = "Out", pose = M(S({ pos = { 0, -0.55, 0 }, x = -8 }, CF0, CF1), {
			Waist = { x = -14 },
			Neck = { x = 2 },
		}, arms({ x = 70, z = 50 }, { x = 45 }, { x = 70, z = -50 }, { x = 45 })) }, -- land, squash, arms drop with the weight
		{ t = 0.86, ease = "Cubic", dir = "Out", pose = pump(true, -0.04, 6, 0, true) }, -- punch to the sky, overshoot
		{ t = 0.92, pose = pump(true, -0.04, 6) }, -- hold
		{ t = 1.04, ease = "Cubic", dir = "Out", pose = pump(false, -0.22, -6, 12) },
		{ t = 1.18, ease = "Cubic", dir = "Out", pose = M(pump(true, 0.22, 10, 0, true), S({ pos = { 0, 0.22, 0 }, y = 8, z = -4 }, air(0.2))) }, -- last pump + hop
		{ t = 1.24, pose = M(pump(true, 0.18, 10), S({ pos = { 0, 0.18, 0 }, y = 8, z = -4 }, air(0.16))) },
		{ t = 1.42, ease = "Cubic", dir = "Out", pose = M(pump(false, -0.32, -12, 8), {
			RightShoulder = { x = 30, z = 25 },
			RightElbow = { x = 120 },
			Neck = { x = -6, y = -6 },
		}) }, -- "YES!": elbow pulled down
		{ t = 1.62, ease = "Cubic", dir = "InOut", pose = M(S({ pos = { 0, -0.1, 0 }, y = 4 }, CF0, CF1), { Waist = { x = -4 }, Neck = { x = -4 } }, arms()) }, -- settle, nod
		{ t = 1.85, ease = "Cubic", dir = "InOut", pose = NEUTRAL },
	},
}

return { Idle, Idle2, Walk, Carry, Hammer, Point, Climb, Celebrate }
