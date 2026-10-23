-- Affordable: the cheapest Cash buy the phone's red dot and the Vehicles app highlight (docs/16 B5).
return function(t)
	local A = t.load("src/shared/Affordable.luau")
	local Rules = t.load("src/shared/ProgressionRules.luau")

	local function noPass()
		return false
	end

	t.test("nothing with no Cash; the jet ski Engine at 300", function()
		local d = Rules.defaultData()
		t.expect(A.cheapest(Rules.snapshot(d), noPass)).toBeNil()
		d.cash = 300
		local pick = A.cheapest(Rules.snapshot(d), noPass)
		t.expect(pick.key).toBe("JetSki/Engine")
		t.expect(pick.price).toBe(300)
	end)

	t.test("a fitted upgrade drops out; the RIB needs its rank", function()
		local d = Rules.defaultData()
		d.cash = 5000
		d.vehicleUpgrades.JetSki = 3 -- Engine + Hull fitted
		t.expect(A.cheapest(Rules.snapshot(d), noPass)).toBeNil()
		d.rep = 400 -- rank 2: the RIB is for sale
		local pick = A.cheapest(Rules.snapshot(d), noPass)
		t.expect(pick.vehicleId).toBe("RIB")
		t.expect(pick.upgradeId).toBeNil()
	end)

	t.test("a pass-owned RIB offers its upgrades", function()
		local d = Rules.defaultData()
		d.cash = 700
		d.rep = 400 -- the RIB's upgrades need its rank
		d.vehicleUpgrades.JetSki = 3
		local pick = A.cheapest(Rules.snapshot(d), function(id)
			return id == "RIB"
		end)
		t.expect(pick.key).toBe("RIB/Engine")
		t.expect(pick.price).toBe(625)
	end)
end
