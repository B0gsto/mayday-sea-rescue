-- Marina (docs/23 (k), WP-19b): the six islands are the plots; every lot sits at the same place in its berth
-- frame; the returning player's spot is on the jetty finger; assignment and the spawn lock.
return function(t)
	local M = t.load("src/shared/Marina.luau")
	local L = t.load("src/shared/Config/RingLayout.luau")
	local BayLaunch = t.load("src/shared/Boat/BayLaunch.luau")

	local function near(a: CFrame, b: CFrame): boolean
		return (a.Position - b.Position).Magnitude < 1e-3
			and a.LookVector:Dot(b.LookVector) > 0.9999
	end

	t.test(
		"one plot per island, the berth is the island's boat berth, bow out of the cove",
		function()
			t.expect(M.COUNT).toBe(6)
			for i, isle in L.Islands do
				local b = M.berth(i)
				t.expect(near(b, isle.berths.Boat)).toBe(true)
				t.expect(b.LookVector:Dot(isle.facing) > 0.99).toBe(true)
				t.expect(near(M.spawn(i), isle.spawn)).toBe(true)
			end
		end
	)

	t.test("every island's lots sit at the same place in its berth frame", function()
		for i, isle in L.Islands do
			local b = M.berth(i)
			for name, lot in isle.lots do
				t.expect(near(b * M.LOTS[name].cf, lot.cframe)).toBe(true)
			end
			t.expect(near(b * M.SUB, isle.berths.Sub)).toBe(true)
			t.expect(near(b * M.ISLAND, isle.frame)).toBe(true)
		end
	end)

	t.test(
		"the jetty finger joins the jetty, clears the craft, and holds the returning player's spot",
		function()
			local jetty = M.LOTS.Jetty
			t.expect(math.abs(M.JETTY.x0 - (jetty.cf.X + jetty.size.X / 2)) < 1e-3).toBe(true)
			t.expect(M.JETTY.x1 < -7).toBe(true) -- a craft is 14 wide on the berth centre line
			for _, offset in { BayLaunch.STAND } do
				local p = offset.Position
				t.expect(p.X >= M.JETTY.x0 and p.X <= M.JETTY.x1).toBe(true)
				t.expect(p.Z >= M.JETTY.out and p.Z <= M.JETTY.z1).toBe(true)
			end
		end
	)

	t.test("assign gives the lowest free island, nil when full", function()
		t.expect(M.assign({})).toBe(1)
		t.expect(M.assign({ [1] = true, [2] = true, [4] = true })).toBe(3)
		local full = {}
		for i = 1, M.COUNT do
			full[i] = true
		end
		t.expect(M.assign(full)).toBeNil()
	end)

	t.test(
		"Harbour Master: most people rescued among islands with a Station, ties keep the holder",
		function()
			t.expect(M.harbourMaster({})).toBeNil()
			t.expect(M.harbourMaster({ { key = "a", rescued = 900, station = false } })).toBeNil()
			local list = {
				{ key = "a", rescued = 30, station = true },
				{ key = "b", rescued = 50, station = true },
				{ key = "c", rescued = 70, station = false }, -- more, but no station
				{ key = "d", rescued = 50, station = true },
			}
			t.expect(M.harbourMaster(list)).toBe("b")
			t.expect(M.harbourMaster(list, "d")).toBe("d")
			t.expect(M.harbourMaster(list, "a")).toBe("b")
		end
	)
	t.test("the spawn lock lets one spawn per berth through until released", function()
		local locks = {}
		t.expect(M.lock(locks, "berth1")).toBe(true)
		t.expect(M.lock(locks, "berth1")).toBe(false) -- a second request in the same moment
		t.expect(M.lock(locks, "berth2")).toBe(true)
		locks.berth1 = nil
		t.expect(M.lock(locks, "berth1")).toBe(true)
	end)
end
