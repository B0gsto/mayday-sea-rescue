-- StepTrail: footprints spaced along the route, alternating feet, turning with the corners.
return function(t)
	local StepTrail = t.load("src/shared/StepTrail.luau")

	t.test("prints every spacing studs from first, capped at the route end", function()
		local s = StepTrail.steps({ Vector3.new(0, 0, 0), Vector3.new(10, 0, 0) }, 1, 2, 20, 0)
		t.expect(#s).toBe(5)
		t.expect(s[1].pos.X).toBeCloseTo(1)
		t.expect(s[5].pos.X).toBeCloseTo(9)
	end)

	t.test("count caps the prints and feet alternate left then right", function()
		local s = StepTrail.steps({ Vector3.new(0, 0, 0), Vector3.new(10, 0, 0) }, 1, 2, 2, 1)
		t.expect(#s).toBe(2)
		t.expect(s[1].left).toBe(true)
		t.expect(s[1].pos.Z).toBeCloseTo(-0.5) -- facing +X, left is -Z
		t.expect(s[2].pos.Z).toBeCloseTo(0.5)
	end)

	t.test("the trail turns the corner and skips zero-length legs", function()
		local s = StepTrail.steps({
			Vector3.new(0, 0, 0),
			Vector3.new(2, 0, 0),
			Vector3.new(2, 0, 0),
			Vector3.new(2, 0, 4),
		}, 1, 2, 10, 0)
		t.expect(#s).toBe(3)
		t.expect(s[2].pos.X).toBeCloseTo(2)
		t.expect(s[2].pos.Z).toBeCloseTo(1)
		t.expect(s[2].dir.Z).toBeCloseTo(1)
	end)
end
