-- Progression: storm Cash multipliers, purchase checks and save migration (no ranks: docs/23 (q), WP-28).
return function(t)
	local Rules = t.load("src/shared/ProgressionRules.luau")
	local Config = t.load("src/shared/Config/ProgressionConfig.luau")
	local U = t.load("src/shared/VehicleUpgrades.luau")

	local function data(cash, buildings, vehicles)
		local d = Rules.defaultData()
		d.cash = cash
		d.dockBuildings = buildings or {}
		d.vehicles = vehicles or {}
		return d
	end

	t.test("storm multipliers boost Cash", function()
		t.expect(Rules.stormCashMultiplier("Calm", false)).toBe(1)
		t.expect(Rules.stormCashMultiplier("Warning", true)).toBe(1)
		t.expect(Rules.stormCashMultiplier("Storm", false)).toBe(1.5)
		t.expect(Rules.stormCashMultiplier("Storm", true)).toBe(2)
		t.expect((Rules.applyAward(250, "Storm", false))).toBe(375)
		t.expect((Rules.applyAward(250, "Storm", true))).toBe(500)
		t.expect((Rules.applyAward(-10, "Calm", false))).toBe(0)
	end)

	t.test("flat passive awards ignore every multiplier; op awards still stack", function()
		-- normal op: x2.2 paid Cash (2x Cash + 10% friend), x2 storm
		local cash, mult = Rules.applyAward(250, "Storm", true, 2.2)
		t.expect(cash).toBe(1100)
		t.expect(mult).toBeCloseTo(4.4, 1e-9)
		local flatCash, flatMult = Rules.applyAward(250, "Storm", true, 2.2, true)
		t.expect(flatCash).toBe(250)
		t.expect(flatMult).toBe(1)
	end)

	t.test("vehicle gates: jet ski free, the RIB needs the boathouse then Cash", function()
		t.expect((Rules.canUseVehicle(data(0), "JetSki"))).toBe(true)
		local ok, why = Rules.canUseVehicle(data(99999), "RIB")
		t.expect(ok).toBe(false)
		t.expect(why).toBe("Not owned")
		local buy, reason = Rules.canBuyVehicle(data(99999), "RIB")
		t.expect(buy).toBe(false)
		t.expect(reason).toBe("Needs Boathouse")
		t.expect(Rules.vehicleLock(data(0), "RIB")).toBe("Boathouse")
		t.expect(Rules.vehicleLock(data(0, { Boathouse = true }), "RIB")).toBeNil()
		t.expect((Rules.canBuyVehicle(data(2499, { Boathouse = true }), "RIB"))).toBe(false)
		local price
		buy, _, price = Rules.canBuyVehicle(data(2500, { Boathouse = true }), "RIB")
		t.expect(buy).toBe(true)
		t.expect(price).toBe(2500)
		-- owned craft keep launching without the building (bought before WP-28, or a website pass)
		t.expect((Rules.canUseVehicle(data(0, {}, { RIB = true }), "RIB"))).toBe(true)
		t.expect(Rules.vehicleLock(data(0), "Lifeboat")).toBe("LifeboatSlip")
		t.expect(Rules.vehicleLock(data(0), "Submarine")).toBe("SubPen")
		t.expect(Rules.vehicleLock(data(0), "RescueHelicopter")).toBe("Hangar")
		t.expect(Rules.vehicleLock(data(0), "StormRunner")).toBe("Boathouse")
		t.expect(Rules.vehicleLock(data(0), "JetSki")).toBeNil()
	end)

	t.test("vehicle ownership: Cash-owned OR pass-owned; Robux-only needs the pass", function()
		t.expect(Rules.vehiclePass("RIB")).toBe("RIBPass")
		t.expect(Rules.vehiclePass("JetSki")).toBeNil() -- free from the start
		t.expect(Rules.ownsVehicle(data(0), "RIB")).toBe(false)
		t.expect(Rules.ownsVehicle(data(0, {}, { RIB = true }), "RIB")).toBe(true)
		t.expect(Rules.ownsVehicle(data(0), "RIB", true)).toBe(true)
		t.expect((Rules.canUseVehicle(data(0), "RIB", true))).toBe(true)
		-- a Robux-only vehicle: never from Cash or a stale profile entry
		for _, id in
			{
				"StormRunner",
				"Tidewalker",
				"RiptideX",
				"GildedGull",
			}
		do
			t.expect(Rules.vehiclePass(id) ~= nil).toBe(true)
			local ok, why =
				Rules.canUseVehicle(data(1e9, { Boathouse = true }, { [id] = true }), id)
			t.expect(ok).toBe(false)
			t.expect(why).toBe("Robux only")
			t.expect((Rules.canBuyVehicle(data(1e9, { Boathouse = true }), id))).toBe(false)
			t.expect((Rules.canUseVehicle(data(0), id, true))).toBe(true)
		end
	end)

	t.test("dock decor keys survive the save migration, junk keys drop", function()
		local d = Rules.migrate({
			dockBuildings = { FlowerBed = true, Lighthouse = true, SubPen = true, Junk = true },
		})
		t.expect(d.dockBuildings.FlowerBed).toBe(true)
		t.expect(d.dockBuildings.Lighthouse).toBe(true)
		t.expect(d.dockBuildings.SubPen).toBe(true)
		t.expect(d.dockBuildings.Junk).toBeNil()
	end)

	t.test("old dock levels map onto the tree; Rep and the level stay saved", function()
		local lv3 = Rules.migrate({ dockLevel = 3, rep = 4200 })
		t.expect(lv3.dockBuildings).toEqual({ Pontoon = true, Workshop = true, Boathouse = true })
		t.expect(lv3.dockLevel).toBe(3)
		t.expect(lv3.rep).toBe(4200)
		local lv5 = Rules.migrate({ dockLevel = 5, dockBuildings = { Hangar = true } })
		for _, key in
			{
				"Pontoon",
				"Workshop",
				"Boathouse",
				"LookoutTower",
				"Crane",
				"Station",
				"TrophyHall",
				"Hangar",
				"Helipad", -- the old hangar came with its pad
			}
		do
			t.expect(lv5.dockBuildings[key]).toBe(true)
		end
		t.expect(lv5.dockBuildings.SubPen).toBeNil()
		t.expect(next(Rules.migrate({ dockLevel = 1 }).dockBuildings)).toBeNil()
		-- idempotent: saving re-runs migrate on the live table
		t.expect(Rules.migrate(Rules.migrate({ dockLevel = 2 })).dockBuildings)
			.toEqual({ Pontoon = true })
	end)

	t.test("a fresh profile starts with the docs 03 starting Cash", function()
		-- docs 03: the cold open pays the first Cash, so a new profile starts at 0
		t.expect(Config.StartingCash).toBe(0)
		t.expect(Rules.defaultData().cash).toBe(Config.StartingCash)
	end)

	t.test("migrate repairs corrupt saves and stamps the version", function()
		local d = Rules.migrate({
			cash = -5,
			rep = 0 / 0,
			gear = { Junk = 2, StrongGrip = "x" },
			vehicles = { RIB = true, Boat = true },
		})
		t.expect(d.version).toBe(Config.SchemaVersion)
		t.expect(d.cash).toBe(0)
		t.expect(d.rep).toBe(0)
		t.expect(d.vehicles.RIB).toBe(true)
		t.expect(d.vehicles.Boat).toBeNil()
		t.expect(next(d.vehicleUpgrades)).toBeNil()
		t.expect(Rules.migrate("garbage").cash).toBe(0)
	end)

	t.test(
		"retired gear loads safely: Engine Tune fits the jet ski Engine, the rest is paid back",
		function()
			local engine = U.bit("Engine")
			-- level 1 Engine Tune: the same +8% as the jet ski's Engine upgrade, nothing else
			local one = Rules.migrate({ cash = 10, gear = { EngineTune = 1 } })
			t.expect(one.vehicleUpgrades.JetSki).toBe(engine)
			t.expect(one.cash).toBe(10)
			t.expect((one :: any).gear).toBeNil()
			-- higher levels come back as Cash (1,200 + 4,000); levels past 3 are clamped
			t.expect(Rules.migrate({ gear = { EngineTune = 10 } }).cash).toBe(5200)
			-- already fitted: the level-1 price comes back instead
			local fitted =
				Rules.migrate({ gear = { EngineTune = 1 }, vehicleUpgrades = { JetSki = engine } })
			t.expect(fitted.vehicleUpgrades.JetSki).toBe(engine)
			t.expect(fitted.cash).toBe(300)
			-- Strong Grip did nothing with auto_board: every level paid back
			t.expect(Rules.migrate({ cash = 1, gear = { StrongGrip = 2 } }).cash).toBe(1501)
			-- the jet ski's old seat upgrade comes off (it holds one) and its 1,500 is paid back
			local seat = Rules.migrate({ vehicleUpgrades = { JetSki = 7, RIB = 7 } })
			t.expect(seat.vehicleUpgrades.JetSki).toBe(engine + U.bit("Hull"))
			t.expect(seat.vehicleUpgrades.RIB).toBe(7)
			t.expect(seat.cash).toBe(1500)
			-- idempotent: saving re-runs migrate on the live table
			local again =
				Rules.migrate(Rules.migrate({ gear = { EngineTune = 3, StrongGrip = 1 } }))
			t.expect(again.cash).toBe(1200 + 4000 + 300)
			t.expect(again.vehicleUpgrades.JetSki).toBe(engine)
		end
	)

	t.test("snapshot carries Cash, people rescued and the island's buildings, no rank", function()
		local d = data(10, { Pontoon = true })
		d.totalRescues = 7
		local s = Rules.snapshot(d)
		t.expect(s.cash).toBe(10)
		t.expect(s.totalRescues).toBe(7)
		t.expect(s.dockBuildings).toEqual({ Pontoon = true })
		t.expect(s.rank).toBeNil()
		t.expect(s.rep).toBeNil()
		t.expect(Rules.fromSnapshot(s).dockBuildings).toEqual({ Pontoon = true })
	end)
end
