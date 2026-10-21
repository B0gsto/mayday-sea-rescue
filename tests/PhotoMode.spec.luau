-- PhotoMath: the free-camera clamps and colour grades behind photo mode (UI/PhotoMode).
return function(t)
	local M = t.load("src/shared/PhotoMath.luau")

	local function approx(a, b, eps)
		t.expect(math.abs(a - b) <= eps).toBeTruthy()
	end

	t.test("clampReach leaves a point inside the reach sphere alone", function()
		local focus = Vector3.new(10, 5, -4)
		local pos = focus + Vector3.new(3, 7, -9)
		local out = M.clampReach(focus, pos, 40)
		t.expect((out - pos).Magnitude).toBeCloseTo(0, 1e-6)
	end)

	t.test("clampReach pulls a distant point onto the sphere, keeping its direction", function()
		local focus = Vector3.new(100, 0, 100)
		local pos = focus + Vector3.new(0, 30, -80)
		local out = M.clampReach(focus, pos)
		approx((out - focus).Magnitude, M.REACH, 1e-4)
		local before = (pos - focus).Unit
		local after = (out - focus).Unit
		approx((before - after).Magnitude, 0, 1e-4)
	end)

	t.test("clampReach honours a custom reach and a point at the focus", function()
		local focus = Vector3.new(1, 2, 3)
		approx(
			(M.clampReach(focus, focus + Vector3.new(0, 100, 0), 12) - focus).Magnitude,
			12,
			1e-4
		)
		t.expect(M.clampReach(focus, focus, 12)).toBe(focus)
	end)

	t.test("lookCFrame yaw and pitch aim the lens", function()
		local pos = Vector3.new(0, 10, 0)
		local forward = M.lookCFrame(pos, 0, 0, 0).LookVector
		approx(forward.X, 0, 1e-5)
		approx(forward.Y, 0, 1e-5)
		approx(forward.Z, -1, 1e-5)
		local up = M.lookCFrame(pos, 0, math.rad(30), 0).LookVector
		approx(up.Y, math.sin(math.rad(30)), 1e-5)
		local right = M.lookCFrame(pos, math.rad(-90), 0, 0).LookVector
		approx(right.X, 1, 1e-5)
		approx(right.Z, 0, 1e-5)
	end)

	t.test("lookCFrame tilt rolls the horizon without moving the aim", function()
		local pos = Vector3.new(4, 5, 6)
		local flat = M.lookCFrame(pos, math.rad(35), math.rad(10), 0)
		local rolled = M.lookCFrame(pos, math.rad(35), math.rad(10), math.rad(25))
		approx((flat.LookVector - rolled.LookVector).Magnitude, 0, 1e-5)
		t.expect(math.abs(rolled.RightVector.Y) > math.abs(flat.RightVector.Y)).toBeTruthy()
	end)

	t.test("lookCFrame clamps pitch and tilt to the shot limits", function()
		local pos = Vector3.new(2, 0, 2)
		local crazy = M.lookCFrame(pos, 0, 3, -3)
		approx(crazy.LookVector.Y, math.sin(M.PITCH_MAX), 1e-5)
		approx(crazy.UpVector.Y, math.cos(M.PITCH_MAX) * math.cos(M.TILT_MAX), 1e-4)
	end)

	t.test("clampShot clamps all three values", function()
		local p, tilt, fov = M.clampShot(5, -5, 500)
		approx(p, M.PITCH_MAX, 1e-9)
		approx(tilt, -M.TILT_MAX, 1e-9)
		approx(fov, M.FOV_MAX, 1e-9)
		local p2, tilt2, fov2 = M.clampShot(-5, 5, 1)
		approx(p2, -M.PITCH_MAX, 1e-9)
		approx(tilt2, M.TILT_MAX, 1e-9)
		approx(fov2, M.FOV_MIN, 1e-9)
	end)

	t.test("every grade stays inside ColorCorrectionEffect's ranges", function()
		t.expect(#M.Grades >= 3).toBeTruthy()
		for _, g in M.Grades do
			t.expect(type(g.name) == "string" and #g.name > 0).toBeTruthy()
			t.expect(g.brightness >= -1 and g.brightness <= 1).toBeTruthy()
			t.expect(g.contrast >= -1 and g.contrast <= 1).toBeTruthy()
			t.expect(g.saturation >= -1 and g.saturation <= 1).toBeTruthy()
		end
	end)

	t.test("gradeAt clamps out-of-range indices", function()
		t.expect(M.gradeAt(0)).toBe(M.Grades[1])
		t.expect(M.gradeAt(-3)).toBe(M.Grades[1])
		t.expect(M.gradeAt(99)).toBe(M.Grades[#M.Grades])
	end)

	t.test("nextGrade cycles through every preset and wraps", function()
		local i = 1
		local seen = {}
		for _ = 1, #M.Grades do
			seen[i] = true
			i = M.nextGrade(i)
		end
		t.expect(i).toBe(1)
		for n = 1, #M.Grades do
			t.expect(seen[n] == true).toBeTruthy()
		end
	end)
end
