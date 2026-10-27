-- NextGoal (docs/24 E/F): the permanent Next chip's building order, prerequisites and the running site.
return function(t)
	local N = t.load("src/shared/NextGoal.luau")
	local DockConfig = t.load("src/shared/Config/DockConfig.luau")
	local BuildTimer = t.load("src/shared/BuildTimer.luau")

	local function facts(over)
		local f = { cash = 0, owned = { Harbour = true }, construction = nil }
		for k, v in over or {} do
			f[k] = v
		end
		return f
	end

	t.test("a fresh island builds the free HQ first", function()
		local g = N.next(facts())
		t.expect(g.kind).toBe("Build")
		t.expect(g.key).toBe("HQ")
		t.expect(g.price).toBe(0)
		t.expect(g.progress).toBe(0)
		t.expect(N.next(facts({ owned = { Harbour = true, HQ = true } })).key).toBe("Depot")
	end)

	t.test("owned buildings are skipped in unlock order", function()
		local g = N.next(facts({ owned = { Harbour = true, HQ = true, Depot = true } }))
		t.expect(g.key).toBe("Workshop")
		t.expect(g.name).toBe("Workshop")
		g = N.next(facts({ owned = { Harbour = true, HQ = true, Depot = true, Workshop = true } }))
		t.expect(g.key).toBe("Bunkhouse")
	end)

	t.test("the Cash bar fills to the price", function()
		local price = DockConfig.Buildings.Depot.cash
		local owned = { Harbour = true, HQ = true }
		local g = N.next(facts({ cash = price / 2, owned = owned }))
		t.expect(g.progress).toBeCloseTo(0.5, 1e-9)
		t.expect(N.next(facts({ cash = price * 3, owned = owned })).progress).toBe(1)
	end)

	t.test("a running site is the goal and shows its progress and time left", function()
		local g = N.next(
			facts({ cash = 999999, construction = { key = "Workshop", progress = 0.25, rate = 2 } })
		)
		t.expect(g.kind).toBe("Site")
		t.expect(g.key).toBe("Workshop")
		t.expect(g.progress).toBe(0.25)
		local work = BuildTimer.work(DockConfig.Buildings.Workshop.cash)
		t.expect(g.timeLeft).toBeCloseTo(work * 0.75 / 2, 1e-9)
	end)

	t.test("a decoration site is a construction too", function()
		local g = N.next(facts({ construction = { key = "FlowerBed", progress = 0.5, rate = 1 } }))
		t.expect(g.kind).toBe("Site")
		t.expect(g.name).toBe("Flower bed")
		t.expect(g.timeLeft).toBeCloseTo(BuildTimer.DECOR * 0.5, 1e-9)
	end)

	t.test("every building owned: no goal", function()
		local owned = {}
		for _, key in DockConfig.BUILDINGS do
			owned[key] = true
		end
		t.expect(N.next(facts({ owned = owned }))).toBeNil()
	end)
end
