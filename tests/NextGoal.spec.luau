-- NextGoal (docs/24 E/F): the permanent Next chip's building order, prerequisites and the running site.
return function(t)
	local N = t.load("src/shared/NextGoal.luau")
	local DockConfig = t.load("src/shared/Config/DockConfig.luau")
	local BuildTimer = t.load("src/shared/BuildTimer.luau")

	local function facts(over)
		local f = { cash = 0, owned = {}, construction = nil }
		for k, v in over or {} do
			f[k] = v
		end
		return f
	end

	t.test("a fresh island builds the first unlock-order building (Pontoon)", function()
		local g = N.next(facts())
		t.expect(g.kind).toBe("Build")
		t.expect(g.key).toBe(DockConfig.BUILDINGS[1])
		t.expect(g.price).toBe(DockConfig.Buildings[g.key].cash)
		t.expect(g.progress).toBe(0)
	end)

	t.test("owned buildings are skipped; a missing prerequisite holds a later row back", function()
		local g = N.next(facts({ owned = { Pontoon = true } }))
		t.expect(g.key).toBe("Workshop")
		t.expect(g.name).toBe("Workshop")
		-- Boathouse needs the Workshop; Fish shed is earlier in the order and free
		g = N.next(facts({ owned = { Pontoon = true, Workshop = true } }))
		t.expect(g.key).toBe("FishShed")
		t.expect(g.progress).toBe(0)
	end)

	t.test("the Cash bar fills to the price", function()
		local price = DockConfig.Buildings.Pontoon.cash
		local g = N.next(facts({ cash = price / 2 }))
		t.expect(g.progress).toBeCloseTo(0.5, 1e-9)
		t.expect(N.next(facts({ cash = price * 3 })).progress).toBe(1)
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
