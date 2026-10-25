return function(t)
	local P = t.load("src/shared/LoadingPath.luau")
	local TAU = math.pi * 2
	local hub = Vector3.new(0, 10, 0)
	local island = Vector3.new(0, 12, -1100)
	local angle = 0.7
	local finish = CFrame.lookAt(Vector3.new(10, 20, -1000), Vector3.new(0, 18, -1010))
	local look = Vector3.new(0, 9, -1070)
	local sweep = Vector3.new(18, 15, -1058)

	local function near(a: Vector3, b: Vector3, eps: number)
		t.expect(a.X).toBeCloseTo(b.X, eps)
		t.expect(a.Y).toBeCloseTo(b.Y, eps)
		t.expect(a.Z).toBeCloseTo(b.Z, eps)
	end

	t.test("ease clamps and is symmetric", function()
		t.expect(P.ease(0)).toBe(0)
		t.expect(P.ease(1)).toBe(1)
		t.expect(P.ease(0.5)).toBe(0.5)
		t.expect(P.ease(-1)).toBe(0)
		t.expect(P.ease(2)).toBe(1)
	end)

	t.test("orbit circles the hub at the start height", function()
		near(P.orbit(hub, 0).Position, hub + Vector3.new(P.START_RADIUS, P.START_HEIGHT, 0), 1e-6)
		local quarter = P.orbit(hub, math.pi / 2)
		near(quarter.Position, hub + Vector3.new(0, P.START_HEIGHT, P.START_RADIUS), 1e-6)
		t.expect(quarter.LookVector.Y < 0).toBe(true)
	end)

	t.test("spiral starts at the orbit pose", function()
		local start = P.spiral(0, hub, island, angle)
		near(start.Position, P.orbit(hub, angle).Position, 1e-6)
	end)

	t.test("spiral ends low over the island after TURNS turns", function()
		local endPose = P.spiral(1, hub, island, angle)
		local a = angle + P.TURNS * TAU
		near(
			endPose.Position,
			island
				+ Vector3.new(math.cos(a) * P.END_RADIUS, P.END_HEIGHT, math.sin(a) * P.END_RADIUS),
			1e-4
		)
	end)

	t.test("approach starts at the spiral end", function()
		local from = P.spiral(1, hub, island, angle)
		local first = P.approach(0, from, sweep, look, finish)
		near(first.Position, from.Position, 1e-6)
		near(first.LookVector, from.LookVector, 1e-6)
	end)

	t.test("approach passes the sweep point and looks at the sign halfway", function()
		local from = P.spiral(1, hub, island, angle)
		local mid = P.approach(0.5, from, sweep, look, finish)
		near(mid.Position, sweep, 1e-6)
		near(mid.LookVector, CFrame.lookAt(sweep, look).LookVector, 1e-6)
	end)

	t.test("approach ends exactly on the finish pose", function()
		local from = P.spiral(1, hub, island, angle)
		local last = P.approach(1, from, sweep, look, finish)
		near(last.Position, finish.Position, 1e-6)
		near(last.LookVector, finish.LookVector, 1e-6)
	end)

	t.test("flyover is continuous and keeps moving through the seam", function()
		-- the flyover time where the eased progress crosses SPIRAL_SHARE
		local lo, hi = 0, 1
		for _ = 1, 40 do
			local mid = (lo + hi) / 2
			if P.ease(mid) < P.SPIRAL_SHARE then
				lo = mid
			else
				hi = mid
			end
		end
		local a = P.flyover(lo, hub, island, angle, sweep, look, finish)
		local b = P.flyover(hi + 1e-6, hub, island, angle, sweep, look, finish)
		near(a.Position, b.Position, 0.01)
		t.expect(a.Position.Y > 50).toBe(true)
		local before = P.flyover(lo - 0.01, hub, island, angle, sweep, look, finish)
		local after = P.flyover(lo + 0.01, hub, island, angle, sweep, look, finish)
		t.expect((after.Position - before.Position).Magnitude > 1).toBe(true)
	end)

	t.test("flyover starts high and ends at the finish", function()
		local start = P.flyover(0, hub, island, angle, sweep, look, finish)
		near(start.Position, P.orbit(hub, angle).Position, 1e-6)
		local last = P.flyover(1, hub, island, angle, sweep, look, finish)
		near(last.Position, finish.Position, 1e-6)
	end)
end
