-- NextGoal (docs/24 E/F, docs/25 A): the Next chip's next affordable level, the HQ needs, the running site.
return function(t)
	local N = t.load("src/shared/NextGoal.luau")
	local DockConfig = t.load("src/shared/Config/DockConfig.luau")
	local BuildTimer = t.load("src/shared/BuildTimer.luau")

	local function facts(over)
		local f = { cash = 0, levels = { Harbour = 1 }, construction = nil }
		for k, v in over or {} do
			f[k] = v
		end
		return f
	end

	t.test("the boat's next level leads, past any building or site, until it is maxed", function()
		local BoatLevels = t.load("src/shared/BoatLevels.luau")
		local g = N.next(facts({ cash = 250, boatLevel = 1 }))
		t.expect(g.kind).toBe("Boat")
		t.expect(g.level).toBe(2)
		t.expect(g.price).toBe(BoatLevels.nextRow(1).price)
		t.expect(g.progress).toBe(250 / g.price)
		local site = { key = "Depot", level = 1, progress = 0.5, rate = 1 }
		t.expect(N.next(facts({ boatLevel = 3, construction = site })).kind).toBe("Boat")
		t.expect(N.next(facts({ cash = 1e9, boatLevel = 3 })).progress).toBe(1)
		t.expect(N.next(facts({ boatLevel = BoatLevels.MAX, construction = site })).kind)
			.toBe("Site")
	end)

	t.test("the island stays quiet until boat level 5", function()
		t.expect(N.treeQuiet(nil)).toBe(true)
		t.expect(N.treeQuiet(4)).toBe(true)
		t.expect(N.treeQuiet(5)).toBe(false)
	end)

	t.test("a fresh island builds the free HQ first, and it reads affordable", function()
		local g = N.next(facts())
		t.expect(g.kind).toBe("Build")
		t.expect(g.key).toBe("HQ")
		t.expect(g.level).toBe(1)
		t.expect(g.price).toBe(0)
		t.expect(g.progress).toBe(1)
	end)

	t.test("an affordable level wins, in card order", function()
		local levels = { Harbour = 1, HQ = 1, Workshop = 1 } -- the step after the tutorial's Workshop
		local depot = DockConfig.Buildings.Depot.levels[1].cash
		local g = N.next(facts({ cash = depot, levels = levels }))
		t.expect(g.key).toBe("Depot")
		t.expect(g.progress).toBe(1)
	end)

	t.test("short of Cash: save toward what the next HQ level needs, then the HQ", function()
		local g = N.next(facts({ cash = 1, levels = { Harbour = 1, HQ = 1, Depot = 1 } }))
		t.expect(g.kind).toBe("Build")
		t.expect(g.level).toBe(1)
		t.expect(g.key ~= "HQ" and g.key ~= "Depot").toBe(true)
		local all = {
			Harbour = 1,
			HQ = 1,
			Depot = 1,
			Workshop = 1,
			SeaPlate1 = 1,
			Bunkhouse = 1,
			FishShed = 1,
		}
		g = N.next(facts({ cash = 1, levels = all }))
		t.expect(g.key).toBe("HQ")
		t.expect(g.level).toBe(2)
		t.expect(g.progress).toBeCloseTo(1 / DockConfig.Buildings.HQ.levels[2].cash, 1e-9)
	end)

	t.test("a running site is the goal and shows its progress and time left", function()
		local g = N.next(facts({
			cash = 999999,
			levels = { Harbour = 1, HQ = 2, Workshop = 1 },
			construction = { key = "Workshop", level = 2, progress = 0.25, rate = 2 },
		}))
		t.expect(g.kind).toBe("Site")
		t.expect(g.key).toBe("Workshop")
		t.expect(g.level).toBe(2)
		t.expect(g.progress).toBe(0.25)
		local work = BuildTimer.work(DockConfig.Buildings.Workshop.levels[2].cash)
		t.expect(g.timeLeft).toBeCloseTo(work * 0.75 / 2, 1e-9)
	end)

	t.test("a decoration site is a construction too", function()
		local g = N.next(facts({ construction = { key = "FlowerBed", progress = 0.5, rate = 1 } }))
		t.expect(g.kind).toBe("Site")
		t.expect(g.name).toBe("Flower bed")
		t.expect(g.timeLeft).toBeCloseTo(BuildTimer.DECOR * 0.5, 1e-9)
	end)

	t.test("every building maxed: no goal", function()
		local levels = {}
		for _, key in DockConfig.BUILDINGS do
			levels[key] = #DockConfig.Buildings[key].levels
		end
		t.expect(N.next(facts({ cash = 1e9, levels = levels }))).toBeNil()
	end)
end
