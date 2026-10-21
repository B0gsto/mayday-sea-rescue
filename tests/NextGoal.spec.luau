-- NextGoal: the one unlock nearest to the player (docs/03 section 10, docs/15 section 3).
return function(t)
	local N = t.load("src/shared/NextGoal.luau")
	local Rules = t.load("src/shared/ProgressionRules.luau")
	local SeasonRules = t.load("src/shared/SeasonRules.luau")

	local NOW = 1792800000 + 10 * 86400 -- mid Season 1

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

	t.test("a fresh profile is closest to the certification that gates its first rank", function()
		local goals = N.goals(snap(Rules.defaultData()), NOW)
		local best = goals[1]
		t.expect(best.kind).toBe("Cert")
		t.expect(best.key).toBe("Cert:Helm")
		t.expect(best.value).toBe(0)
		t.expect(best.target).toBe(3) -- the exercise + two live operations
		t.expect(best.fraction).toBe(0)
		t.expect(best.unit).toBe("Steps")
		for _, g in goals do
			t.expect(g.kind == "Rank").toBe(false) -- the rank is gated until Helm is passed
		end
	end)

	t.test("with the gate passed, ties go rank > cert > gear > season", function()
		local d = Rules.defaultData()
		d.certs.Helm = true
		local goals = N.goals(snap(d), NOW)
		t.expect(kinds(goals)).toEqual({ "Rank", "Cert", "Gear", "Gear", "Season" })
		t.expect(goals[1].key).toBe("Rank:Lifeguard")
		t.expect(goals[1].value).toBe(0)
		t.expect(goals[1].target).toBe(400)
		t.expect(goals[1].unit).toBe("Rep")
	end)

	t.test("the nearest goal wins on fraction; ties prefer the vehicle", function()
		local d = Rules.defaultData()
		d.cash = 3200
		d.rep = 950
		d.gear = { EngineTune = 2, StrongGrip = 3 }
		for _, id in { "Helm", "CasualtyCare", "RescueSwimmer" } do
			d.certs[id] = true
		end
		local goals = N.goals(snap(d), NOW)
		-- Rescue Swimmer rank: the next rank's Coxswain certification is missing, so the rank
		-- goal is not live and the RIB (0.8) is the nearest unlock
		t.expect(goals[1].key).toBe("Vehicle:RIB")
		t.expect(goals[1].value).toBe(3200)
		t.expect(goals[1].target).toBe(4000)
		t.expect(goals[1].fraction).toBeCloseTo(0.8, 1e-9)
		t.expect(goals[2].key).toBe("Gear:EngineTune:3")
		t.expect(goals[2].fraction).toBeCloseTo(0.8, 1e-9)
		for _, g in goals do
			t.expect(g.kind == "Rank").toBe(false)
		end
	end)

	t.test("a missing certification is the goal instead of a gated rank", function()
		local d = Rules.defaultData()
		d.rep = 900
		d.certs.Helm = true
		d.certs.CasualtyCare = true
		d.exercises.ExerciseSwimTest = "Silver"
		local goals = N.goals(snap(d), NOW)
		t.expect(goals[1].key).toBe("Cert:RescueSwimmer")
		t.expect(goals[1].value).toBe(1) -- the exercise; one live swimmer recovery still to go
		t.expect(goals[1].target).toBe(2)
		t.expect(goals[1].fraction).toBe(0.5)
		t.expect(goals[1].unit).toBe("Steps")
		for _, g in goals do
			t.expect(g.kind == "Rank").toBe(false)
		end
	end)

	t.test("Admiral makes the next Service Star the goal", function()
		local d = Rules.defaultData()
		d.rep = 162000
		d.cash = 1e9
		d.gear = { EngineTune = 3, StrongGrip = 3 }
		d.vehicles = { JetSki = true, RIB = true, Lifeboat = true, RescueHelicopter = true }
		d.vehicleUpgrades = { JetSki = 7, RIB = 7, Lifeboat = 7 }
		for _, id in { "Helm", "CasualtyCare", "RescueSwimmer", "Coxswain" } do
			d.certs[id] = true
		end
		local best = N.best(snap(d), NOW)
		t.expect(best.kind).toBe("Rank")
		t.expect(best.key).toBe("Star:1")
		t.expect(best.label).toBe("Star 1")
		t.expect(best.value).toBe(12000)
		t.expect(best.target).toBe(30000)
		t.expect(best.fraction).toBeCloseTo(0.4, 1e-9)
		d.rep = 192000
		t.expect(N.best(snap(d), NOW).key).toBe("Star:2")
		t.expect(N.best(snap(d), NOW).fraction).toBeCloseTo(0.4, 1e-9)
	end)

	t.test("an owned boat's next upgrade is a goal", function()
		local d = Rules.defaultData()
		d.rep = 6000
		d.cash = 2500
		d.vehicles = { RIB = true }
		d.certs.Helm = true
		d.certs.RescueSwimmer = true
		local goals = N.goals(snap(d), NOW)
		local upgrade
		for _, goal in goals do
			if goal.kind == "Upgrade" then
				upgrade = goal
			end
		end
		t.expect(upgrade).toBeTruthy()
		t.expect(upgrade.key).toBe("Upgrade:RIB:Engine")
		t.expect(upgrade.label).toBe("RIB Tuned engine")
		t.expect(upgrade.target).toBe(1000)
		t.expect(upgrade.value).toBe(1000) -- affordable: full bar
		t.expect(upgrade.unit).toBe("Cash")
	end)

	t.test("a reached but unclaimed season tier is a full goal", function()
		local d = Rules.defaultData()
		d.rep = 150000
		d.cash = 1e9
		d.gear = { EngineTune = 3, StrongGrip = 3 }
		d.vehicles = { JetSki = true, RIB = true, Lifeboat = true, RescueHelicopter = true }
		d.vehicleUpgrades = { JetSki = 7, RIB = 7, Lifeboat = 7 }
		for _, id in { "Helm", "CasualtyCare", "RescueSwimmer", "Coxswain" } do
			d.certs[id] = true
		end
		local season = SeasonRules.newState()
		season.xp = 100
		d.flags.season = SeasonRules.flagTable(season)
		local best = N.best(snap(d), NOW)
		t.expect(best.kind).toBe("Season")
		t.expect(best.key).toBe("Season:1")
		t.expect(best.value).toBe(100)
		t.expect(best.target).toBe(100)
		t.expect(best.fraction).toBe(1)
	end)
end
