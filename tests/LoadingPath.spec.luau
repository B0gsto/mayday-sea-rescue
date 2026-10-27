return function(t)
	local P = t.load("src/shared/LoadingPath.luau")
	local ring = Vector3.new(0, 10, 0)
	local from = CFrame.lookAt(Vector3.new(300, 650, 0), ring)
	local to = CFrame.lookAt(Vector3.new(10, 20, -1000), Vector3.new(0, 18, -1010))

	local function near(a: Vector3, b: Vector3, eps: number)
		t.expect(a.X).toBeCloseTo(b.X, eps)
		t.expect(a.Y).toBeCloseTo(b.Y, eps)
		t.expect(a.Z).toBeCloseTo(b.Z, eps)
	end

	-- 0 when p is on the straight line between a and b
	local function offLine(p: Vector3, a: Vector3, b: Vector3): number
		local ab = b - a
		local t0 = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
		return (p - (a + ab * t0)).Magnitude
	end

	t.test("orbit circles the ring at the start height", function()
		near(P.orbit(ring, 0).Position, ring + Vector3.new(P.START_RADIUS, P.START_HEIGHT, 0), 1e-6)
		local quarter = P.orbit(ring, math.pi / 2)
		near(quarter.Position, ring + Vector3.new(0, P.START_HEIGHT, P.START_RADIUS), 1e-6)
		t.expect(quarter.LookVector.Y < 0).toBe(true)
	end)

	t.test("handoff starts at the loading view and ends exactly behind the player", function()
		near(P.handoff(from, to, 0).Position, from.Position, 1e-6)
		near(P.handoff(from, to, 1).Position, to.Position, 1e-6)
		t.expect(P.handoff(from, to, 1).LookVector:Dot(to.LookVector)).toBeCloseTo(1, 1e-5)
	end)

	t.test("handoff is one straight tween, no orbit", function()
		for i = 0, 20 do
			local p = P.handoff(from, to, i / 20).Position
			t.expect(offLine(p, from.Position, to.Position) < 1e-3).toBe(true)
		end
	end)

	t.test("handoff eases out: past halfway at half time, never back", function()
		local mid = P.handoff(from, to, 0.5)
		local half = from.Position:Lerp(to.Position, 0.5)
		t.expect((mid.Position - from.Position).Magnitude > (half - from.Position).Magnitude)
			.toBe(true)
		local last = 0
		for i = 0, 20 do
			local d = (P.handoff(from, to, i / 20).Position - from.Position).Magnitude
			t.expect(d >= last - 1e-6).toBe(true)
			last = d
		end
		t.expect(last).toBeCloseTo((to.Position - from.Position).Magnitude, 1e-5)
	end)

	t.test("handoff clamps outside 0..1 and lasts about 1.2 s", function()
		near(P.handoff(from, to, -1).Position, from.Position, 1e-6)
		near(P.handoff(from, to, 2).Position, to.Position, 1e-6)
		t.expect(P.HANDOFF_SECONDS).toBeCloseTo(1.2, 1e-6)
	end)
end
