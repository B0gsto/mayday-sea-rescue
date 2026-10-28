return function(t)
	local P = t.load("src/shared/LoadingPath.luau")
	local ring = Vector3.new(0, 10, 0)

	local function near(a: Vector3, b: Vector3, eps: number)
		t.expect(a.X).toBeCloseTo(b.X, eps)
		t.expect(a.Y).toBeCloseTo(b.Y, eps)
		t.expect(a.Z).toBeCloseTo(b.Z, eps)
	end

	t.test("orbit circles the ring at the start height", function()
		near(P.orbit(ring, 0).Position, ring + Vector3.new(P.START_RADIUS, P.START_HEIGHT, 0), 1e-6)
		local quarter = P.orbit(ring, math.pi / 2)
		near(quarter.Position, ring + Vector3.new(0, P.START_HEIGHT, P.START_RADIUS), 1e-6)
		t.expect(quarter.LookVector.Y < 0).toBe(true)
	end)
end
