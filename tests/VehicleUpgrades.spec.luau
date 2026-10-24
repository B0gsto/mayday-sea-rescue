-- VehicleUpgrades: docs 03 section 4.1 prices, rank gates, fit order and the real stat changes.
return function(t)
	local U = t.load("src/shared/VehicleUpgrades.luau")
	local VehicleConfig = t.load("src/shared/Config/VehicleConfig.luau")
	local ProgressionConfig = t.load("src/shared/Config/ProgressionConfig.luau")
	local Rules = t.load("src/shared/ProgressionRules.luau")

	local function prices(vehicleId)
		local out = {}
		for _, upgrade in U.Vehicles[vehicleId] do
			table.insert(out, upgrade.price)
		end
		return out
	end

	t.test("prices follow docs 03 4.1 (25 / 50 / 100 % of the vehicle price)", function()
		t.expect(prices("JetSki")).toEqual({ 300, 800 }) -- free vehicle: fixed
		t.expect(prices("RIB")).toEqual({ 625, 1250, 2500 })
		t.expect(prices("Lifeboat")).toEqual({ 3000, 6000, 12000 })
	end)

	t.test(
		"boats fit Engine, Hull and an Extra seat (+1 aboard); the jet ski skips the seat",
		function()
			t.expect(#U.Vehicles.JetSki).toBe(2)
			for _, vehicleId in U.VehicleOrder do
				local list = U.Vehicles[vehicleId]
				if vehicleId ~= "JetSki" then
					t.expect(#list).toBe(3)
					t.expect(list[3].id).toBe("Fit")
					t.expect(list[3].name).toBe("Extra seat")
					t.expect(list[3].effect).toBe("+1 aboard")
				end
				for _, upgrade in list do
					t.expect(upgrade.name ~= "" and upgrade.effect ~= "").toBe(true)
					t.expect(upgrade.rankIndex)
						.toBe(ProgressionConfig.Vehicles[vehicleId].rankIndex)
				end
			end
		end
	)

	t.test("a purchase needs the vehicle, the rank and the Cash", function()
		local ok, reason = U.canBuy("RIB", "Engine", 0, 5000, 3, false)
		t.expect({ ok, reason }).toEqual({ false, "Not owned" })
		ok, reason = U.canBuy("RIB", "Engine", 0, 5000, 1, true)
		t.expect({ ok, reason }).toEqual({ false, "Needs Lifeguard" })
		ok, reason = U.canBuy("RIB", "Engine", 0, 624, 3, true)
		t.expect({ ok, reason }).toEqual({ false, "Need Cash" })
		ok = U.canBuy("RIB", "Engine", 0, 625, 2, true)
		t.expect(ok).toBe(true)
		ok = U.canBuy("RIB", "Hull", 0, 1250, 3, true) -- independent fits: no fixed order
		t.expect(ok).toBe(true)
		ok, reason = U.canBuy("JetSki", "Fit", 0, 9000, 1, true) -- the jet ski holds one
		t.expect({ ok, reason }).toEqual({ false, "Unknown upgrade" })
		ok, reason = U.canBuy("RIB", "Engine", 1, 9000, 3, true)
		t.expect({ ok, reason }).toEqual({ false, "Fitted" })
	end)

	t.test("the mask round-trips and next walks the levels", function()
		local mask = 0
		for i, id in U.UpgradeOrder do
			t.expect(U.has(mask, id)).toBe(false)
			t.expect(U.next("RIB", mask).id).toBe(id)
			mask += U.bit(id)
			t.expect(U.has(mask, id)).toBe(true)
			local following = U.Vehicles.RIB[i + 1]
			t.expect(if U.next("RIB", mask) then U.next("RIB", mask).id else nil)
				.toBe(if following then following.id else nil)
		end
		t.expect(mask).toBe(7)
		t.expect(U.mask(9)).toBe(7)
		t.expect(U.mask("x")).toBe(0)
	end)

	t.test("the profile keeps a sanitised mask per boat", function()
		local raw = Rules.defaultData()
		raw.vehicleUpgrades = { RIB = 5, JetSki = 99, Lifeboat = "x", Nope = 3 }
		local saved = Rules.migrate(raw)
		-- the jet ski's old seat bit comes off (ProgressionRules pays it back)
		t.expect(saved.vehicleUpgrades).toEqual({ RIB = 5, JetSki = 3 })
		t.expect(Rules.snapshot(saved).vehicleUpgrades).toEqual({ RIB = 5, JetSki = 3 })
		t.expect(Rules.fromSnapshot(Rules.snapshot(saved)).vehicleUpgrades)
			.toEqual({ RIB = 5, JetSki = 3 })
	end)

	t.test("fitted upgrades change the real handling numbers and the seat count", function()
		local base = VehicleConfig.RIB
		local engine = U.apply(base, U.bit("Engine"))
		t.expect(engine.topSpeed).toBeCloseTo(base.topSpeed * 1.15, 1e-9)
		t.expect(engine.accel).toBeCloseTo(base.accel * 1.15, 1e-9)
		t.expect(engine.turnRate).toBe(base.turnRate)

		local hull = U.apply(base, U.bit("Hull"))
		t.expect(hull.dampingRatio > base.dampingRatio).toBe(true)
		t.expect(hull.leanFactor < base.leanFactor).toBe(true)
		t.expect(hull.turnRate > base.turnRate).toBe(true)
		t.expect(hull.lateralGrip >= base.lateralGrip).toBe(true)

		local full = U.apply(base, 7)
		t.expect(full.survivorCapacity).toBe(base.survivorCapacity + 1)
		t.expect(full.topSpeed).toBeCloseTo(engine.topSpeed, 1e-9)
		t.expect(U.apply(base, 0)).toBe(base) -- nothing fitted: the config table itself
		t.expect(VehicleConfig.RIB.survivorCapacity).toBe(base.survivorCapacity) -- never mutated
	end)
end
