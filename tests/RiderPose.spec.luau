-- RiderPose: the jet ski rider's lean, crouch and bump bounce.
return function(t)
	local R = t.load("src/shared/Boat/RiderPose.luau")

	local function run(s, seconds, input)
		local pose
		for _ = 1, math.floor(seconds * 60) do
			input.dt = 1 / 60
			pose = R.step(s, input)
		end
		return pose
	end
	local function base()
		return { yawRate = 0, speed = 20, topSpeed = 40, vertical = 0, scale = 1 }
	end

	t.test("leans into a left turn at speed, not while idling round", function()
		local i = base()
		i.yawRate = 0.8
		local _, _, roll = run(R.new(), 1, i).Root:ToEulerAnglesYXZ()
		t.expect(roll > math.rad(6) and roll <= R.MAX_LEAN + 1e-6).toBeTruthy()
		i.speed = 0
		_, _, roll = run(R.new(), 1, i).Root:ToEulerAnglesYXZ()
		t.expect(math.abs(roll) < 0.01).toBeTruthy()
	end)

	t.test("tucks forward under acceleration more than cruising", function()
		local s = R.new()
		local i = base()
		i.speed = 0
		local pitchAccel
		for n = 1, 30 do
			i.speed = n -- +60 studs/s^2
			i.dt = 1 / 60
			pitchAccel = R.step(s, i).Waist:ToEulerAnglesYXZ()
		end
		local cruise = run(R.new(), 1, base()).Waist:ToEulerAnglesYXZ()
		t.expect(pitchAccel < cruise).toBeTruthy()
		t.expect(cruise < 0).toBeTruthy()
	end)

	t.test("a slam dips the hips then settles; reduce motion skips it", function()
		local s = R.new()
		local i = base()
		run(s, 0.5, i)
		i.vertical = 15
		local hit = run(s, 0.1, i).Root.Position.Y
		local settled = run(s, 2, i).Root.Position.Y
		t.expect(hit < settled - 0.1).toBeTruthy()
		local r = R.new()
		local j = base()
		j.scale = 0.4
		run(r, 0.5, j)
		j.vertical = 15
		run(r, 0.1, j)
		t.expect(r.y == 0).toBeTruthy()
	end)

	t.test(
		"the hull banks 12-18 deg into a carve in ~0.15 s, less under reduce motion, none idling",
		function()
			local b = 0
			for _ = 1, 9 do -- 0.15 s
				b = R.bank(b, 0.8, 40, 1, 1 / 60)
			end
			t.expect(b > math.rad(9)).toBeTruthy()
			for _ = 1, 60 do
				b = R.bank(b, 0.8, 40, 1, 1 / 60)
			end
			t.expect(b > math.rad(12) and b <= math.rad(18)).toBeTruthy()
			local right, idle, calm = 0, 0, 0
			for _ = 1, 60 do
				right = R.bank(right, -5, 40, 1, 1 / 60)
				idle = R.bank(idle, 0.8, 0, 1, 1 / 60)
				calm = R.bank(calm, 5, 40, 0.4, 1 / 60)
			end
			t.expect(right < -math.rad(12)).toBeTruthy() -- a right turn banks right
			t.expect(math.abs(idle) < 1e-6).toBeTruthy()
			t.expect(calm > 0 and calm <= R.MAX_BANK * 0.4 + 1e-6).toBeTruthy()
		end
	)

	t.test("the head counters the hull bank (nearer level)", function()
		local i = base()
		i.yawRate = 0.8
		i.bank = math.rad(16)
		local _, _, neck = run(R.new(), 1, i).Neck:ToEulerAnglesYXZ()
		t.expect(neck < -math.rad(10)).toBeTruthy()
	end)

	t.test(
		"spray: rooster tail with speed, side spray only on a hard carve, none astern",
		function()
			local tailSlow = R.spray(12, 80, 0)
			local tailFast, side = R.spray(60, 80, 0)
			t.expect(tailSlow > 0 and tailSlow < tailFast and tailFast == 1).toBeTruthy()
			t.expect(side == 0).toBeTruthy()
			local _, carve = R.spray(50, 80, 0.7)
			t.expect(carve >= 0.75).toBeTruthy()
			local back, sideBack = R.spray(-30, 80, 1)
			t.expect(back == 0 and sideBack == 0).toBeTruthy()
		end
	)

	t.test("a slam is flagged for the splash even under reduce motion", function()
		local s = R.new()
		local i = base()
		i.scale = 0.4
		run(s, 0.5, i)
		i.vertical = 15
		i.dt = 1 / 60
		R.step(s, i)
		t.expect(s.slam).toBe(true)
		R.step(s, i)
		t.expect(s.slam).toBe(false)
	end)
end
