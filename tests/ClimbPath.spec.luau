-- Ops/ClimbPath: the climb rides in the hull's frame (docs/NEXT 0c), so the server and every client can
-- play the same path on their own copy of the hull.
return function(t)
	local ClimbPath = t.load("src/shared/Ops/ClimbPath.luau")
	local hull = CFrame.new(100, 2, -30) * CFrame.Angles(0.1, 0.6, -0.05)
	local start = Vector3.new(-4, 0, 9)
	local seat = CFrame.new(1.5, 2, -3)
	local function at(x: number)
		return ClimbPath.at(hull, start, 1, 4, seat, x)
	end

	t.test("starts in the water where the survivor was", function()
		local want = hull * CFrame.new(start)
		t.expect((at(0).Position - want.Position).Magnitude).toBeCloseTo(0, 1e-6)
	end)

	t.test("ends seated on the slot", function()
		local want = hull * seat
		t.expect((at(1).Position - want.Position).Magnitude).toBeCloseTo(0, 1e-6)
		t.expect((at(1).LookVector - want.LookVector).Magnitude).toBeCloseTo(0, 1e-6)
	end)

	t.test("time clamps at both ends", function()
		t.expect((at(-1).Position - at(0).Position).Magnitude).toBeCloseTo(0, 1e-6)
		t.expect((at(2).Position - at(1).Position).Magnitude).toBeCloseTo(0, 1e-6)
	end)

	t.test("reaches the hull side on the survivor's side", function()
		local edge = (hull * seat).Position + hull.RightVector * (4 + 0.8) - Vector3.new(0, 1.6, 0)
		t.expect((at(0.45).Position - edge).Magnitude).toBeCloseTo(0, 1e-6)
	end)
end
