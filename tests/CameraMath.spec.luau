-- CameraMath: head stabilisation blend, springs and the chase spring arm.
return function(t)
	local M = t.load("src/client/Camera/CameraMath.luau")

	local function rollOf(cf)
		-- angle of the right vector above/below the horizon
		return math.asin(math.clamp(cf.RightVector.Y, -1, 1))
	end

	local hull = CFrame.Angles(0, math.rad(40), 0) * CFrame.Angles(math.rad(12), 0, math.rad(20))

	t.test("stabilise 0 is hull locked", function()
		local r = M.stabilise(hull, 0)
		t.expect((r.LookVector - hull.LookVector).Magnitude).toBeCloseTo(0, 1e-6)
		t.expect((r.UpVector - hull.UpVector).Magnitude).toBeCloseTo(0, 1e-6)
	end)

	t.test("stabilise 1 is horizon locked but keeps the heading", function()
		local r = M.stabilise(hull, 1)
		t.expect(r.UpVector.Y).toBeCloseTo(1, 1e-5)
		t.expect(r.LookVector.Y).toBeCloseTo(0, 1e-5)
		t.expect(M.heading(r)).toBeCloseTo(M.heading(hull), 1e-5)
	end)

	t.test("stabilise blends roll monotonically and roughly linearly", function()
		local full = math.abs(rollOf(hull))
		local half = math.abs(rollOf(M.stabilise(hull, 0.5)))
		local most = math.abs(rollOf(M.stabilise(hull, 0.8)))
		t.expect(half < full).toBeTruthy()
		t.expect(most < half).toBeTruthy()
		t.expect(half).toBeCloseTo(full * 0.5, math.rad(2))
	end)

	t.test("stabilise clamps out-of-range settings", function()
		t.expect(M.stabilise(hull, 3).UpVector.Y).toBeCloseTo(1, 1e-5)
		t.expect((M.stabilise(hull, -1).UpVector - hull.UpVector).Magnitude).toBeCloseTo(0, 1e-6)
	end)

	t.test("horizonFrame survives a vertical look", function()
		local up = CFrame.lookAt(Vector3.zero, Vector3.new(0, 1, 0), Vector3.new(0, 0, 1))
		local f = M.horizonFrame(up)
		t.expect(f.UpVector.Y).toBeCloseTo(1, 1e-5)
	end)

	t.test("damp is frame-rate independent", function()
		local a = 10
		for _ = 1, 10 do
			a = M.damp(a, 0, 0.2, 0.01)
		end
		local b = M.damp(10, 0, 0.2, 0.1)
		t.expect(a).toBeCloseTo(b, 1e-9)
		t.expect(M.damp(10, 0, 0.2, 0.2)).toBeCloseTo(5, 1e-9)
	end)

	t.test("dampAngle takes the short way round", function()
		local a = M.dampAngle(math.rad(170), math.rad(-170), 0.1, 0.05)
		t.expect(math.abs(M.wrap(a - math.rad(180))) < math.rad(10)).toBeTruthy()
	end)

	t.test("spring settles on target and is stable at a huge dt", function()
		local x, v = 0, 0
		for _ = 1, 600 do
			x, v = M.spring(x, v, 1, 2, 1, 1 / 60)
		end
		t.expect(x).toBeCloseTo(1, 1e-3)
		local y, w = M.spring(0, 0, 1, 5, 0.5, 10)
		t.expect(math.abs(y) <= 1.0001 and math.abs(w) < 1).toBeTruthy()
		local p = M.spring(Vector3.zero, Vector3.zero, Vector3.new(1, 0, 0), 2, 1, 1 / 60)
		t.expect(p.X > 0).toBeTruthy()
	end)

	t.test("gLean leans into a right turn and caps", function()
		local roll, pitch = M.gLean(Vector3.new(M.G, 0, 0), 1, math.rad(10))
		t.expect(roll).toBeCloseTo(math.rad(6), 1e-6)
		t.expect(pitch).toBeCloseTo(0, 1e-9)
		local big = M.gLean(Vector3.new(10 * M.G, 0, 0), 1, math.rad(10))
		t.expect(big).toBeCloseTo(math.rad(10), 1e-9)
		local _, back = M.gLean(Vector3.new(0, 0, -M.G), 1, math.rad(10)) -- accelerating forward
		t.expect(back > 0).toBeTruthy()
	end)

	t.test("speedFov kicks in with speed and caps", function()
		t.expect(M.speedFov(75, 0, 60, 8)).toBe(75)
		t.expect(M.speedFov(75, 60, 60, 8)).toBeCloseTo(83, 1e-9)
		local mid = M.speedFov(75, 40, 60, 8)
		t.expect(mid > 75 and mid < 83).toBeTruthy()
		t.expect(M.speedFov(105, 60, 60, 20)).toBe(110)
	end)

	t.test("head bob is subtle and off at zero", function()
		local off, roll = M.headBob(1.3, 0)
		t.expect(off.Magnitude).toBe(0)
		t.expect(roll).toBe(0)
		for i = 0, 40 do
			local o = M.headBob(i * 0.2, 1)
			t.expect(math.abs(o.Y) <= M.BOB_Y + 1e-9 and math.abs(o.X) <= M.BOB_X + 1e-9)
				.toBeTruthy()
		end
		t.expect(M.bobRate(100)).toBeCloseTo(3 * math.pi, 1e-9)
	end)

	t.test("spring arm shortens on a hit and keeps a minimum", function()
		t.expect(M.armDistance(30, nil, 0.5, 3)).toBe(30)
		t.expect(M.armDistance(30, 40, 0.5, 3)).toBe(30)
		t.expect(M.armDistance(30, 12, 0.5, 3)).toBe(11.5)
		t.expect(M.armDistance(30, 1, 0.5, 3)).toBe(3)
	end)

	t.test("spring arm snaps in and eases out", function()
		t.expect(M.relaxArm(30, 10, 0.4, 1 / 60)).toBe(10)
		local out = M.relaxArm(10, 30, 0.4, 0.4)
		t.expect(out).toBeCloseTo(20, 1e-9)
	end)

	t.test("look-ahead is flat and capped", function()
		local a = M.lookAhead(Vector3.new(0, 20, -50), 0.5, 10)
		t.expect(a.Y).toBe(0)
		t.expect(a.Magnitude).toBeCloseTo(10, 1e-9)
		t.expect(M.lookAhead(Vector3.new(4, 0, 0), 0.5, 10).X).toBeCloseTo(2, 1e-9)
	end)

	t.test("camera stays above the swell", function()
		t.expect(M.aboveSwell(Vector3.new(1, 2, 3), 4, 1.5).Y).toBe(5.5)
		t.expect(M.aboveSwell(Vector3.new(1, 9, 3), 4, 1.5).Y).toBe(9)
	end)

	t.test("chase offset sits behind the heading", function()
		local boat = CFrame.lookAt(Vector3.zero, Vector3.new(1, 0, 0))
		local o = M.chaseOffset(M.heading(boat), 0, 0, 10)
		t.expect((o - Vector3.new(-10, 0, 0)).Magnitude).toBeCloseTo(0, 1e-6)
		local up = M.chaseOffset(0, 0, math.rad(30), 10)
		t.expect(up.Y).toBeCloseTo(5, 1e-6)
		t.expect(up.Magnitude).toBeCloseTo(10, 1e-6)
	end)

	t.test("two-bone IK keeps bone lengths and bends toward the pole", function()
		local s = Vector3.new(0, 0, 0)
		local target = Vector3.new(0.3, -0.6, -1.2)
		local pole = Vector3.new(1, -2, 0)
		local elbow, wrist = M.twoBoneIK(s, target, 0.93, 0.81, pole)
		t.expect((elbow - s).Magnitude).toBeCloseTo(0.93, 1e-4)
		t.expect((wrist - elbow).Magnitude).toBeCloseTo(0.81, 1e-4)
		t.expect((wrist - target).Magnitude).toBeCloseTo(0, 1e-4)
		local mid = (s + wrist) * 0.5
		t.expect((elbow - mid):Dot(pole - mid) > 0).toBeTruthy()
		-- out of reach: the arm straightens toward the target
		local _, far = M.twoBoneIK(s, Vector3.new(0, 0, -10), 0.93, 0.81, pole)
		t.expect(far.Magnitude).toBeCloseTo(1.74, 1e-2)
	end)

	t.test("deadzone rescales", function()
		t.expect(M.deadzone(0.1, 0.15)).toBe(0)
		t.expect(M.deadzone(1, 0.15)).toBeCloseTo(1, 1e-9)
		t.expect(M.deadzone(-1, 0.15)).toBeCloseTo(-1, 1e-9)
	end)

	t.test("shake scales with trauma squared and the setting", function()
		local noise = function()
			return 1
		end
		t.expect(M.shake(0.5, 0, 1, noise).Magnitude).toBe(0)
		local a = M.shake(0.5, 1, 1, noise).X
		local b = M.shake(1, 1, 1, noise).X
		t.expect(a).toBeCloseTo(b * 0.25, 1e-9)
	end)
end
