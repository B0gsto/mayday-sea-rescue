-- Progression: rank thresholds, storm Cash multipliers, gear bonus math and purchase checks.
return function(t)
	local Rules = t.load("src/shared/ProgressionRules.luau")
	local Config = t.load("src/shared/Config/ProgressionConfig.luau")

	local function data(cash, rep, gear, vehicles)
		local d = Rules.defaultData()
		d.cash = cash
		d.rep = rep
		d.gear = gear or {}
		d.vehicles = vehicles or {}
		-- certified for every rank, so these cases test Rep, Cash and gear (tests/Certs.spec.luau
		-- covers the certification gate)
		for _, id in Config.CertOrder do
			d.certs[id] = true
		end
		return d
	end

	t.test("rank from Rep follows the docs 03 thresholds", function()
		t.expect(Rules.rankIndexForRep(0)).toBe(1)
		t.expect(Rules.rankIndexForRep(399)).toBe(1)
		t.expect(Rules.rankIndexForRep(400)).toBe(2)
		t.expect(Rules.rankIndexForRep(899)).toBe(2)
		t.expect(Rules.rankIndexForRep(900)).toBe(3)
		t.expect(Rules.rankIndexForRep(1e9)).toBe(#Config.Ranks)
		t.expect(Rules.rankForRep(950).displayName).toBe("Rescue Swimmer")
	end)

	t.test("progress to next rank", function()
		local nextRank, progress = Rules.progressToNext(200)
		t.expect(nextRank.id).toBe("Lifeguard")
		t.expect(progress).toBeCloseTo(0.5, 1e-9)
		local top, full = Rules.progressToNext(5000)
		t.expect(top).toBeNil()
		t.expect(full).toBe(1)
	end)

	t.test("storm multipliers boost Cash only", function()
		t.expect(Rules.stormCashMultiplier("Calm", false)).toBe(1)
		t.expect(Rules.stormCashMultiplier("Warning", true)).toBe(1)
		t.expect(Rules.stormCashMultiplier("Storm", false)).toBe(1.5)
		t.expect(Rules.stormCashMultiplier("Storm", true)).toBe(2)
		local cash, rep = Rules.applyAward(250, 60, "Storm", false)
		t.expect(cash).toBe(375)
		t.expect(rep).toBe(60)
		local gCash, gRep = Rules.applyAward(250, 60, "Storm", true)
		t.expect(gCash).toBe(500)
		t.expect(gRep).toBe(60)
		local zero = Rules.applyAward(-10, 5, "Calm", false)
		t.expect(zero).toBe(0)
	end)

	t.test("gear bonus math", function()
		t.expect(Rules.gearBonus({}, "speed")).toBe(1)
		t.expect(Rules.gearBonus(nil, "speed")).toBe(1)
		t.expect(Rules.gearBonus({ EngineTune = 1 }, "speed")).toBeCloseTo(1.08, 1e-9)
		t.expect(Rules.gearBonus({ EngineTune = 2 }, "speed")).toBeCloseTo(1.16, 1e-9)
		t.expect(Rules.gearBonus({ StrongGrip = 1 }, "pullTime")).toBeCloseTo(0.75, 1e-9)
		t.expect(Rules.gearBonus({ StrongGrip = 1 }, "speed")).toBe(1)
		t.expect(Rules.gearBonus({ EngineTune = 99 }, "speed")).toBeCloseTo(1.24, 1e-9)
		t.expect(Rules.gearBonus({ Unknown = 3 }, "speed")).toBe(1)
		t.expect(Rules.gearBonus({ EngineTune = 1 }, "searchRadius")).toBe(1)
	end)

	t.test("gear purchase checks price, rank and max level", function()
		local ok, _, price = Rules.canBuyGear(data(300, 0), "EngineTune")
		t.expect(ok).toBe(true)
		t.expect(price).toBe(300)
		local poor = Rules.canBuyGear(data(299, 0), "EngineTune")
		t.expect(poor).toBe(false)
		local lowRank, why = Rules.canBuyGear(data(99999, 0, { EngineTune = 2 }), "EngineTune")
		t.expect(lowRank).toBe(false)
		t.expect(why).toBe("Needs Rescue Swimmer")
		local l3 = Rules.canBuyGear(data(4000, 900, { EngineTune = 2 }), "EngineTune")
		t.expect(l3).toBe(true)
		local maxed, maxWhy = Rules.canBuyGear(data(99999, 900, { EngineTune = 3 }), "EngineTune")
		t.expect(maxed).toBe(false)
		t.expect(maxWhy).toBe("Max level")
		t.expect((Rules.canBuyGear(data(99999, 900), "Nope"))).toBe(false)
	end)

	t.test("vehicle gates: jet ski free, RIB needs rank and Cash", function()
		t.expect((Rules.canUseVehicle(data(0, 0), "JetSki"))).toBe(true)
		local ok, why = Rules.canUseVehicle(data(99999, 0), "RIB")
		t.expect(ok).toBe(false)
		t.expect(why).toBe("Needs Rescue Swimmer")
		t.expect((Rules.canUseVehicle(data(99999, 900), "RIB"))).toBe(false)
		t.expect((Rules.canBuyVehicle(data(3999, 900), "RIB"))).toBe(false)
		local buy, _, price = Rules.canBuyVehicle(data(4000, 900), "RIB")
		t.expect(buy).toBe(true)
		t.expect(price).toBe(4000)
		t.expect((Rules.canUseVehicle(data(0, 900, {}, { RIB = true }), "RIB"))).toBe(true)
		t.expect((Rules.canUseVehicle(data(0, 900), "Helicopter"))).toBe(false)
	end)

	t.test("migrate repairs corrupt saves and stamps the version", function()
		local d = Rules.migrate({
			cash = -5,
			rep = 0 / 0,
			gear = { EngineTune = 10, Junk = 2 },
			vehicles = { RIB = true, Boat = true },
		})
		t.expect(d.version).toBe(Config.SchemaVersion)
		t.expect(d.cash).toBe(0)
		t.expect(d.rep).toBe(0)
		t.expect(d.gear.EngineTune).toBe(Rules.maxGearLevel())
		t.expect(d.gear.Junk).toBeNil()
		t.expect(d.vehicles.RIB).toBe(true)
		t.expect(d.vehicles.Boat).toBeNil()
		t.expect(Rules.migrate("garbage").cash).toBe(0)
	end)

	t.test("snapshot carries rank and next threshold", function()
		local s = Rules.snapshot(data(10, 450))
		t.expect(s.rank).toBe("Lifeguard")
		t.expect(s.rankIndex).toBe(2)
		t.expect(s.nextRankRep).toBe(900)
	end)
end
