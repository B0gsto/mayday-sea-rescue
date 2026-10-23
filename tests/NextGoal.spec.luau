-- NextGoal: the rank bar or the next boat with its Cash, whichever is nearer (docs/16 K6).
return function(t)
	local N = t.load("src/shared/NextGoal.luau")
	local Rules = t.load("src/shared/ProgressionRules.luau")

	local function snap(data)
		return Rules.snapshot(data)
	end

	local function kinds(goals)
		local out = {}
		for _, g in goals do
			table.insert(out, g.kind)
		end
		return out
	end

	t.test("only two kinds: the next rank and the next boat", function()
		local goals = N.goals(snap(Rules.defaultData()))
		t.expect(kinds(goals)).toEqual({ "Rank", "Vehicle" }) -- both empty: the rank wins the tie
		t.expect(goals[1].key).toBe("Rank:Lifeguard")
		t.expect(goals[1].target).toBe(400)
		t.expect(goals[1].unit).toBe("Rep")
		t.expect(goals[2].key).toBe("Vehicle:RIB")
		t.expect(goals[2].vehicleId).toBe("RIB")
		t.expect(goals[2].target).toBe(2500)
		t.expect(goals[2].unit).toBe("Cash")
	end)

	t.test("the nearest goal wins on fraction", function()
		local d = Rules.defaultData()
		d.rep = 100 -- 0.25 of Lifeguard
		d.cash = 2000 -- 0.8 of the RIB
		t.expect(N.best(snap(d)).key).toBe("Vehicle:RIB")
		d.cash = 200
		t.expect(N.best(snap(d)).key).toBe("Rank:Lifeguard")
	end)

	t.test(
		"the next boat moves on once the RIB is owned; a Robux pass boat is never a goal",
		function()
			local d = Rules.defaultData()
			d.vehicles = { RIB = true }
			local goals = N.goals(snap(d))
			t.expect(goals[2].key).toBe("Vehicle:Lifeboat")
			t.expect(goals[2].target).toBe(12000)
			d.vehicles.Lifeboat = true
			t.expect(kinds(N.goals(snap(d)))).toEqual({ "Rank" })
		end
	)

	t.test("Admiral makes the next Service Star the goal", function()
		local d = Rules.defaultData()
		d.rep = 162000
		d.vehicles = { RIB = true, Lifeboat = true }
		local best = N.best(snap(d))
		t.expect(best.kind).toBe("Rank")
		t.expect(best.key).toBe("Star:1")
		t.expect(best.label).toBe("Star 1")
		t.expect(best.value).toBe(12000)
		t.expect(best.target).toBe(30000)
		t.expect(best.fraction).toBeCloseTo(0.4, 1e-9)
		d.rep = 192000
		t.expect(N.best(snap(d)).key).toBe("Star:2")
	end)
end
