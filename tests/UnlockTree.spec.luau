-- UnlockTree (docs/23 (q), WP-28; docs/25 K2): levels, HQ gates, aliases, Bunkhouse cap and legacy refunds.
return function(t)
	local U = t.load("src/shared/UnlockTree.luau")
	local D = t.load("src/shared/Config/DockConfig.luau")
	local Progression = t.load("src/shared/Config/ProgressionConfig.luau")

	t.test("rows and levels are legal: real needs, sane HQ gates", function()
		for _, key in D.BUILDINGS do
			local b = D.Buildings[key]
			for _, need in b.needs do
				t.expect(D.Buildings[need] ~= nil).toBe(true)
			end
			for n, lvl in b.levels do
				t.expect(lvl.hq >= 0 and lvl.hq <= 5).toBe(true)
				for _, need in lvl.needs or {} do
					t.expect(D.Buildings[need] ~= nil).toBe(true)
				end
				if n > 1 then
					t.expect(lvl.hq >= b.levels[n - 1].hq).toBe(true)
				end
			end
		end
		t.expect(U.maxLevel("HQ")).toBe(5)
		t.expect(U.maxLevel("Workshop")).toBe(3)
		t.expect(U.maxLevel("Nope")).toBe(0)
		t.expect(U.levelOf({ Workshop = 2.9 }, "Workshop")).toBe(2)
		t.expect(U.levelOf({}, "Workshop")).toBe(0)
	end)

	t.test("ownedSet keeps every old reader working", function()
		t.expect(U.ownedSet({ Harbour = 1 })).toEqual({ Harbour = true })
		t.expect(U.ownedSet({ Harbour = 3, Boathouse = 2, AirStation = 1, HQ = 3 })).toEqual({
			Harbour = true,
			Pontoon = true,
			Crane = true,
			Boathouse = true,
			LifeboatSlip = true,
			AirStation = true,
			Hangar = true,
			Helipad = true,
			HQ = true,
			Station = true,
		})
	end)

	t.test("Cash buys the next level, in order, inside the HQ gate and with the Cash", function()
		local base = { Harbour = 1, HQ = 1 }
		local ok, reason, price, need = U.canBuild("Workshop", 1, base, 499)
		t.expect({ ok, reason, price, need }).toEqual({ false, "Cash", 500, nil })
		t.expect(U.canBuild("Workshop", 1, base, 500)).toBe(true)
		ok, reason = U.canBuild("Workshop", 2, { Workshop = 1, HQ = 0 }, 1e9)
		t.expect({ ok, reason }).toEqual({ false, "HQ" })
		ok, reason, price = U.canBuild("Workshop", 3, { Workshop = 1, HQ = 3 }, 1e9)
		t.expect({ ok, reason, price }).toEqual({ false, "Order", 11000 })
		t.expect(U.canBuild("Workshop", 2, { Workshop = 1, HQ = 2 }, 1500)).toBe(true)
		t.expect(select(2, U.canBuild("Workshop", 1, { Workshop = 1, HQ = 1 }, 1e9))).toBe("Owned")
		t.expect(select(2, U.canBuild("Workshop", 4, { Workshop = 3, HQ = 5 }, 1e9))).toBe("Maxed")
		t.expect(select(2, U.canBuild("Nope", 1, {}, 1e9))).toBe("Unknown")
	end)

	t.test("the HQ needs every row the current HQ offers built first", function()
		local hq1 = { Harbour = 1, HQ = 1, Depot = 1, Workshop = 1, Bunkhouse = 1, FishShed = 1 }
		t.expect(U.nextHqNeed({ Harbour = 1, HQ = 1 })).toEqual({
			"Depot",
			"Workshop",
			"Bunkhouse",
			"FishShed",
		})
		t.expect(U.nextHqNeed(hq1)).toEqual({})
		local ok, reason, _, need = U.canBuild("HQ", 2, { Harbour = 1, HQ = 1 }, 1e9)
		t.expect({ ok, reason, need }).toEqual({ false, "Needs", "Depot" })
		t.expect(U.canBuild("HQ", 2, hq1, 2999)).toBe(false)
		t.expect(U.canBuild("HQ", 2, hq1, 3000)).toBe(true)
		local hq2 = {
			Harbour = 1,
			HQ = 2,
			Depot = 1,
			Workshop = 1,
			Bunkhouse = 1,
			FishShed = 1,
			Boathouse = 1,
		}
		ok, reason, _, need = U.canBuild("HQ", 3, hq2, 1e9)
		t.expect({ ok, reason, need }).toEqual({ false, "Needs", "BoatYard" })
		t.expect(U.nextHqNeed({ HQ = 5, Harbour = 3 })).toBeNil()
	end)

	t.test("Robux skips the Cash, never the order or the HQ gate", function()
		t.expect(U.canRobux("Workshop", 1, { Harbour = 1, HQ = 0 })).toBe(false)
		t.expect(U.canRobux("Workshop", 1, { Harbour = 1, HQ = 1 })).toBe(true)
		t.expect(U.canRobux("Harbour", 2, { Harbour = 1, HQ = 1 })).toBe(false)
		t.expect(U.canRobux("Harbour", 2, { Harbour = 1, HQ = 2 })).toBe(true)
		t.expect(U.canRobux("Workshop", 1, { Workshop = 1, HQ = 2 })).toBe(false)
		t.expect(U.canRobux("Harbour", 3, { Harbour = 2, HQ = 2 })).toBe(false)
		t.expect(U.canRobux("Harbour", 3, { Harbour = 2, HQ = 3 })).toBe(true)
		t.expect(U.canRobux("Nope", 1, {})).toBe(false)
	end)

	t.test("Bunkhouse caps the crew", function()
		t.expect(U.bunkCap({})).toBe(0)
		t.expect(U.bunkCap({ Bunkhouse = 1 })).toBe(10)
		t.expect(U.bunkCap({ Bunkhouse = 3 })).toBe(30)
		t.expect(U.bunkCap({ Bunkhouse = 9 })).toBe(60)
	end)

	t.test("craft unlock through their building or its old alias", function()
		local want = {
			RIB = "Boathouse",
			Lifeboat = "LifeboatSlip",
			Submarine = "SubPen",
			RescueHelicopter = "Hangar",
			StormRunner = "Boathouse",
			Tidewalker = "Boathouse",
			RiptideX = "Boathouse",
			GildedGull = "Boathouse",
		}
		for id, v in Progression.Vehicles do
			t.expect(v.needs).toBe(want[id])
			if v.needs then
				t.expect(U.craftMissing(id, {})).toBe(v.needs)
				t.expect(U.craftMissing(id, { [v.needs] = true })).toBeNil()
			end
		end
		t.expect(U.craftMissing("JetSki", {})).toBeNil()
		t.expect(U.craftMissing("Lifeboat", U.ownedSet({ Boathouse = 2 }))).toBeNil()
		t.expect(U.craftMissing("RescueHelicopter", U.ownedSet({ AirStation = 1 }))).toBeNil()
	end)

	t.test("legacy targets", function()
		t.expect(U.legacyTarget("Pontoon")).toEqual("Harbour", 2)
		t.expect(U.legacyTarget("Crane")).toEqual("Harbour", 3)
		t.expect(U.legacyTarget("LifeboatSlip")).toEqual("Boathouse", 2)
		t.expect(U.legacyTarget("Hangar")).toEqual("AirStation", 1)
		t.expect(U.legacyTarget("Station")).toEqual("HQ", 3)
		t.expect(U.legacyTarget("Workshop")).toEqual("Workshop", 1)
		t.expect(U.legacyTarget("Nope")).toBe(nil)
	end)

	t.test("old saves migrate to levels, keep the jetty and refund merged Cash", function()
		local levels, refund = U.migrateLegacy({
			Workshop = true,
			Boathouse = true,
			LifeboatSlip = true,
		}, 1, 12)
		t.expect(levels).toEqual({
			Harbour = 1,
			Workshop = 1,
			Boathouse = 2,
			Bunkhouse = 2,
			HQ = 2,
		})
		t.expect(refund).toBe(7350)
		local again, refund2 = U.migrateLegacy({ Workshop = true }, 1, 0)
		t.expect(again.Harbour).toBe(1)
		t.expect(refund2).toBe(0)

		local five, paid = U.migrateLegacy({}, 5, 0)
		t.expect(five.Harbour).toBe(3)
		t.expect(five.HQ).toBe(5)
		t.expect(five.Boathouse).toBe(1)
		t.expect(five.TrophyHall).toBe(1)
		t.expect(paid).toBe(37600)

		local strays, none = U.migrateLegacy({ Pontoon = true }, 1, 0)
		t.expect(strays.Harbour).toBe(2)
		t.expect(none).toBe(0)
	end)
end
