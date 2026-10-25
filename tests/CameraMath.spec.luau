-- CameraMath: horizon frame, smoothing and the chase spring arm.
return function(t)
	local M = t.load("src/client/Camera/CameraMath.luau")

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

	t.test("speedFov kicks in with speed and caps", function()
		t.expect(M.speedFov(75, 0, 60, 8)).toBe(75)
		t.expect(M.speedFov(75, 60, 60, 8)).toBeCloseTo(83, 1e-9)
		local mid = M.speedFov(75, 40, 60, 8)
		t.expect(mid > 75 and mid < 83).toBeTruthy()
		t.expect(M.speedFov(105, 60, 60, 20)).toBe(110)
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
