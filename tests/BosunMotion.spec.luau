-- BosunMotion (scripted motion on the rigid dog) and BosunWetness (coat wetness).
return function(t)
	local M = t.load("src/shared/Dog/BosunMotion.luau")
	local W = t.load("src/shared/Dog/BosunWetness.luau")

	local function run(state, seconds, input)
		local pose
		local steps = math.floor(seconds * 60)
		for _ = 1, steps do
			input.dt = 1 / 60
			pose = M.step(state, input)
		end
		return pose
	end

	local function pitchOf(cf)
		local x = cf:ToEulerAnglesYXZ()
		return x
	end
	local function yawOf(cf)
		local _, y = cf:ToEulerAnglesYXZ()
		return y
	end
	local function rollOf(cf)
		local _, _, z = cf:ToEulerAnglesYXZ()
		return z
	end

	t.test("breathing moves him a little even standing still", function()
		local s = M.new()
		local lo, hi = math.huge, -math.huge
		for _ = 1, 600 do
			local pose = M.step(s, { dt = 1 / 60, mode = "Follow", speed = 0, excited = 0 })
			lo = math.min(lo, pose.Root.Position.Y)
			hi = math.max(hi, pose.Root.Position.Y)
		end
		t.expect(hi - lo > 0.01).toBeTruthy()
		t.expect(hi - lo < 0.3).toBeTruthy()
	end)

	t.test("standing still he sits; walking he gets up", function()
		local s = M.new()
		run(s, 6, { mode = "Follow", speed = 0, excited = 0 })
		t.expect(s.sit > 0.9).toBeTruthy()
		local pose = M.step(s, { dt = 1 / 60, mode = "Follow", speed = 0, excited = 0 })
		t.expect(pitchOf(pose.Hips) > math.rad(10)).toBeTruthy() -- rear lowered
		run(s, 1, { mode = "Follow", speed = 8, excited = 0 })
		t.expect(s.sit < 0.1).toBeTruthy()
	end)

	t.test("waiting ashore he sits at once", function()
		local s = M.new()
		run(s, 2, { mode = "Wait", speed = 0, excited = 0 })
		t.expect(s.sit > 0.9).toBeTruthy()
	end)

	t.test("walking bobs and rocks him; standing does not", function()
		local s = M.new()
		local lo, hi = math.huge, -math.huge
		for _ = 1, 120 do
			local pose = M.step(s, { dt = 1 / 60, mode = "Follow", speed = 9, excited = 0 })
			local p = pitchOf(pose.Root)
			lo, hi = math.min(lo, p), math.max(hi, p)
		end
		t.expect(hi - lo > math.rad(1.5)).toBeTruthy()
		t.expect(s.gait > 0.5).toBeTruthy()
	end)

	t.test("head turns toward the look target, clamped", function()
		local yaw, pitch = M.lookAngles(Vector3.new(-1, 0, -1)) -- ahead-left
		t.expect(yaw).toBeCloseTo(M.MAX_YAW, 1e-6) -- 45 degrees, clamped
		t.expect(pitch).toBeCloseTo(0, 1e-6)
		local smallYaw = M.lookAngles(Vector3.new(0.2, 0, -1))
		t.expect(smallYaw < 0).toBeTruthy() -- right is negative yaw
		local _, up = M.lookAngles(Vector3.new(0, 5, -1))
		t.expect(up).toBeCloseTo(M.MAX_PITCH_UP, 1e-6)
		local s = M.new()
		local pose =
			run(s, 2, { mode = "Follow", speed = 0, excited = 0, look = Vector3.new(-0.3, 0, -1) })
		t.expect(yawOf(pose.Neck) > math.rad(10)).toBeTruthy()
		t.expect(math.abs(yawOf(pose.Ruff)) < math.abs(yawOf(pose.Neck))).toBeTruthy()
	end)

	t.test("excited, the rear wags; calm, it does not", function()
		local s = M.new()
		local lo, hi = math.huge, -math.huge
		for _ = 1, 180 do
			local pose = M.step(s, { dt = 1 / 60, mode = "Follow", speed = 0, excited = 1 })
			local y = yawOf(pose.Hips)
			lo, hi = math.min(lo, y), math.max(hi, y)
		end
		t.expect(hi - lo > math.rad(4)).toBeTruthy()
		local c = M.new()
		lo, hi = math.huge, -math.huge
		for _ = 1, 180 do
			local pose = M.step(c, { dt = 1 / 60, mode = "Follow", speed = 0, excited = 0 })
			local y = yawOf(pose.Hips)
			lo, hi = math.min(lo, y), math.max(hi, y)
		end
		t.expect(hi - lo < math.rad(0.5)).toBeTruthy()
	end)

	local function tailRange(state, seconds, input)
		local lo, hi, liftSum, n = math.huge, -math.huge, 0, 0
		for _ = 1, math.floor(seconds * 60) do
			input.dt = 1 / 60
			local pose = M.step(state, input)
			local y = yawOf(pose.Tail)
			lo, hi = math.min(lo, y), math.max(hi, y)
			liftSum += -pitchOf(pose.Tail)
			n += 1
		end
		return hi - lo, liftSum / n
	end

	t.test(
		"the tail wags and lifts when excited; the rear wiggle stays small with a tail joint",
		function()
			local s = M.new()
			run(s, 1.5, { mode = "Follow", speed = 0, excited = 1, tailJoint = true })
			local swing, lift =
				tailRange(s, 1, { mode = "Follow", speed = 0, excited = 1, tailJoint = true })
			t.expect(swing > math.rad(30)).toBeTruthy()
			t.expect(lift > math.rad(15)).toBeTruthy()
			local lo, hi = math.huge, -math.huge
			for _ = 1, 60 do
				local pose = M.step(
					s,
					{ dt = 1 / 60, mode = "Follow", speed = 0, excited = 1, tailJoint = true }
				)
				lo, hi = math.min(lo, yawOf(pose.Hips)), math.max(hi, yawOf(pose.Hips))
			end
			t.expect(hi - lo < math.rad(3.5)).toBeTruthy()
			local c = M.new()
			local calmSwing =
				tailRange(c, 2, { mode = "Follow", speed = 0, excited = 0, tailJoint = true })
			t.expect(calmSwing < math.rad(1)).toBeTruthy()
		end
	)

	t.test("sitting the tail is low and nearly still", function()
		local s = M.new()
		run(s, 3, { mode = "Wait", speed = 0, excited = 0.45, tailJoint = true })
		local swing, lift =
			tailRange(s, 1, { mode = "Wait", speed = 0, excited = 0.45, tailJoint = true })
		t.expect(lift < -math.rad(5)).toBeTruthy()
		t.expect(swing < math.rad(6)).toBeTruthy()
	end)

	t.test("tired after a long run the tail hangs low", function()
		local s = M.new()
		run(s, 30, { mode = "Follow", speed = 14, excited = 0 })
		run(s, 1.5, { mode = "Follow", speed = 0, excited = 0 })
		t.expect(s.tired > 0.3).toBeTruthy()
		t.expect(s.tailLift < -math.rad(8)).toBeTruthy()
	end)

	t.test("swimming the tail streams out raised; wet ashore or cold it tucks", function()
		local s = M.new()
		run(s, 3, { mode = "Swim", speed = 3, excited = 0, wetness = 1 })
		t.expect(s.tailLift > math.rad(10)).toBeTruthy()
		local w = M.new()
		run(w, 3, { mode = "Follow", speed = 0, excited = 0, wetness = 1 })
		t.expect(w.tuck > 0.9).toBeTruthy()
		t.expect(w.tailLift < -math.rad(30)).toBeTruthy()
		local c = M.new()
		run(c, 3, { mode = "Follow", speed = 8, excited = 0, cold = 1 })
		t.expect(c.tuck > 0.9).toBeTruthy()
		local d = M.new()
		run(d, 3, { mode = "Follow", speed = 8, excited = 0, wetness = 0.1 })
		t.expect(d.tuck < 0.05).toBeTruthy()
	end)

	t.test("aboard he leans into the turn and against the deck's roll", function()
		local roll = M.leanTarget(Vector3.new(10, 0, 0), 0, 0) -- deck accelerating right: a right turn
		t.expect(roll < 0).toBeTruthy() -- right side down
		local _, pitch = M.leanTarget(Vector3.new(0, 0, -10), 0, 0) -- surging ahead
		t.expect(pitch < 0).toBeTruthy() -- nose down, bracing forward
		local level = M.leanTarget(Vector3.zero, math.rad(10), 0) -- deck rolled right side up
		t.expect(level < 0).toBeTruthy()
		local big = M.leanTarget(Vector3.new(500, 0, 0), 0, 0)
		t.expect(big).toBeCloseTo(-M.MAX_LEAN, 1e-6)
		local s = M.new()
		local pose = run(s, 2, {
			mode = "Ride",
			speed = 0,
			excited = 0,
			accel = Vector3.new(12, 0, 0),
			deckRoll = 0,
			deckPitch = 0,
		})
		t.expect(rollOf(pose.Root) < -math.rad(1)).toBeTruthy()
	end)

	t.test("swimming floats him low and nose up; climbing out he shakes", function()
		local s = M.new()
		local pose = run(s, 3, { mode = "Swim", speed = 3, excited = 0 })
		t.expect(pose.Root.Position.Y < -0.5).toBeTruthy()
		t.expect(pitchOf(pose.Root) > math.rad(5)).toBeTruthy()
		M.step(s, { dt = 1 / 60, mode = "Follow", speed = 0, excited = 0 })
		t.expect(s.shake > 0).toBeTruthy()
		run(s, 1.2, { mode = "Follow", speed = 0, excited = 0 })
		t.expect(s.shake).toBe(0)
	end)

	t.test("poses stay finite with odd input", function()
		local s = M.new()
		local pose = M.step(s, { dt = 5, mode = "Bogus", speed = -3, excited = 7 })
		for _, cf in { pose.Root, pose.Neck, pose.Hips, pose.Ruff, pose.Tail } do
			local p = cf.Position
			t.expect(p.X == p.X and p.Y == p.Y and p.Z == p.Z).toBeTruthy()
		end
	end)

	t.test("LOD picks by distance with hysteresis", function()
		t.expect(M.lodFor(10)).toBe(0)
		t.expect(M.lodFor(80)).toBe(1)
		t.expect(M.lodFor(400)).toBe(2)
		t.expect(M.lodFor(M.LOD_AT[1] + 2, 0)).toBe(0) -- just past the edge: stays
		t.expect(M.lodFor(M.LOD_AT[1] + 10, 0)).toBe(1)
		t.expect(M.lodFor(M.LOD_AT[1] - 2, 1)).toBe(1)
		t.expect(M.lodFor(500, 0)).toBe(2)
	end)

	t.test("water soaks him fast, rain slowly, and he dries over time", function()
		local w = 0
		for _ = 1, 4 do
			w = W.step(w, 0.5, { submerged = true, rain = 0 })
		end
		t.expect(w).toBe(1)
		local dry = W.step(1, W.DRY_SECONDS / 2, { submerged = false, rain = 0 })
		t.expect(dry).toBeCloseTo(0.5, 1e-6)
		t.expect(W.step(dry, W.DRY_SECONDS, { submerged = false, rain = 0 })).toBe(0)
		local r = W.step(0, 10, { submerged = false, rain = 1 })
		t.expect(r > 0 and r < W.WET_ON).toBeTruthy()
		r = W.step(r, 200, { submerged = false, rain = 1 })
		t.expect(r).toBeCloseTo(W.RAIN_MAX, 1e-6)
		t.expect(W.step(1, 30, { submerged = false, rain = 0.6 })).toBe(1) -- no drying in the rain
		t.expect(W.shake(1)).toBeCloseTo(1 - W.SHAKE_LOSS, 1e-6)
	end)

	t.test("the wet look switches with hysteresis", function()
		t.expect(W.isWet(false, 0.3)).toBe(false)
		t.expect(W.isWet(false, W.WET_ON)).toBe(true)
		t.expect(W.isWet(true, 0.2)).toBe(true)
		t.expect(W.isWet(true, W.WET_OFF)).toBe(false)
	end)
end
