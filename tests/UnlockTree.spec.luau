-- UnlockTree (docs/23 (q), WP-28): no ranks; each building needs the ones before it, Cash buys it once they
-- stand, Robux skips the Cash but never the order, and craft unlock through their building.
return function(t)
	local U = t.load("src/shared/UnlockTree.luau")
	local D = t.load("src/shared/Config/DockConfig.luau")
	local Progression = t.load("src/shared/Config/ProgressionConfig.luau")

	t.test(
		"the first tree: every prerequisite is a real building, no cycles, at most 4 steps deep",
		function()
			local depth: { [string]: number } = {}
			local function deep(key: string, seen: { [string]: boolean }): number
				t.expect(seen[key]).toBeNil() -- a cycle
				if depth[key] then
					return depth[key]
				end
				seen[key] = true
				local d = 0
				for _, need in D.Buildings[key].needs do
					t.expect(D.Buildings[need] ~= nil).toBe(true)
					d = math.max(d, deep(need, seen) + 1)
				end
				seen[key] = nil
				depth[key] = d
				return d
			end
			for key in D.Buildings do
				t.expect(deep(key, {}) <= 4).toBe(true)
			end
			t.expect(D.Buildings.Pontoon.needs).toEqual({})
			t.expect(D.Buildings.Workshop.needs).toEqual({})
			t.expect(D.Buildings.FishShed.needs).toEqual({})
			t.expect(D.Buildings.Boathouse.needs).toEqual({ "Workshop" })
			t.expect(D.Buildings.Station.needs).toEqual({ "Boathouse", "LookoutTower" })
			t.expect(D.Buildings.Hangar.needs).toEqual({ "Helipad" })
			t.expect(D.Buildings.SubPen.needs).toEqual({ "Crane" })
			t.expect(depth.Hangar).toBe(3) -- jetty, Pontoon, Lookout tower, Helipad, Hangar
		end
	)

	t.test("Cash buys a building once its prerequisites stand, then once", function()
		local ok, reason, price, need = U.canBuy("Boathouse", {}, 1e9)
		t.expect({ ok, reason, price, need }).toEqual({ false, "Needs", 2500, "Workshop" })
		ok, reason, price = U.canBuy("Boathouse", { Workshop = true }, 2499)
		t.expect({ ok, reason, price }).toEqual({ false, "Cash", 2500 })
		t.expect((U.canBuy("Boathouse", { Workshop = true }, 2500))).toBe(true)
		t.expect(select(2, U.canBuy("Boathouse", { Workshop = true, Boathouse = true }, 1e9)))
			.toBe("Owned")
		t.expect(select(2, U.canBuy("Nope", {}, 1e9))).toBe("Owned")
		-- the station needs both: the first missing one is named
		t.expect(U.missing("Station", { Boathouse = true })).toBe("LookoutTower")
		t.expect(U.missing("Station", { LookoutTower = true })).toBe("Boathouse")
		t.expect(U.missing("Station", { Boathouse = true, LookoutTower = true })).toBeNil()
	end)

	t.test("Robux skips the Cash, never the order", function()
		t.expect(U.canRobux("Boathouse", {})).toBe(false)
		t.expect(U.canRobux("Boathouse", { Workshop = true })).toBe(true)
		t.expect(U.canRobux("Boathouse", { Workshop = true, Boathouse = true })).toBe(false)
		t.expect(U.canRobux("Workshop", {})).toBe(true) -- a root: only the jetty
		t.expect(U.canRobux("Nope", {})).toBe(false) -- no such building
		t.expect(U.canRobux("Pontoon", {})).toBe(true)
	end)

	t.test("craft unlock through their building", function()
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
	end)

	t.test("old dock levels migrate to tree items, idempotently", function()
		local owned = { SubPen = true }
		U.migrate(4, owned)
		t.expect(owned).toEqual({
			SubPen = true,
			Pontoon = true,
			Workshop = true,
			Boathouse = true,
			LookoutTower = true,
			Crane = true,
		})
		U.migrate(4, owned)
		t.expect(owned.Station).toBeNil()
		local hangar = { Hangar = true }
		U.migrate(1, hangar)
		t.expect(hangar).toEqual({ Hangar = true, Helipad = true })
	end)
end
