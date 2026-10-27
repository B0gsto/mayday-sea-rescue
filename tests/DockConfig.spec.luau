-- DockConfig (docs/23 (q), WP-28; docs/25 K2): leveled rows, HQ gates, prices, products and map spots.
return function(t)
	local D = t.load("src/shared/Config/DockConfig.luau")
	local Monetization = t.load("src/shared/Config/MonetizationConfig.luau")
	local Marina = t.load("src/shared/Marina.luau")

	t.test("every building is listed once, with levels, a name, a short desc and a spot", function()
		local seen = {}
		for _, key in D.BUILDINGS do
			t.expect(seen[key]).toBeNil()
			seen[key] = true
			local b = D.Buildings[key]
			t.expect(b ~= nil).toBe(true)
			t.expect(#b.name > 0 and #string.split(b.name, " ") <= 3).toBe(true)
			t.expect(#string.split(b.desc, " ") <= 10).toBe(true)
			t.expect(#b.levels >= 3).toBe(true)
			t.expect(b.unlockAt >= 1 and b.unlockAt <= 5).toBe(true)
			t.expect(b.size.X > 0 and b.size.Y > 0).toBe(true)
			for n, lvl in b.levels do
				t.expect(lvl.cash >= 0).toBe(true)
				t.expect(lvl.hq >= 0 and lvl.hq <= 5).toBe(true)
				if n > 1 then
					t.expect(lvl.cash >= b.levels[n - 1].cash).toBe(true)
				end
			end
			t.expect(b.cash).toBe(b.levels[1].cash)
			t.expect(b.product).toBe(b.levels[1].product)
		end
		for key in D.Buildings do
			t.expect(seen[key]).toBe(true)
		end
		t.expect(#D.Buildings.HQ.levels).toBe(5)
		t.expect(#D.Buildings.Bunkhouse.levels).toBe(5)
		t.expect(D.BunkhouseCaps).toEqual({ 10, 20, 30, 45, 60 })
	end)

	t.test(
		"HQ gates: HQ levels chain, rows follow max(unlockAt, level), the tutorial roots stay open",
		function()
			for n, lvl in D.Buildings.HQ.levels do
				t.expect(lvl.hq).toBe(n - 1)
			end
			for _, key in D.BUILDINGS do
				local b = D.Buildings[key]
				if key == "HQ" then
					continue
				end
				for n, lvl in b.levels do
					local want = math.max(b.unlockAt, n)
					if n == 1 and key == "Harbour" then
						want = 0
					end
					t.expect(lvl.hq).toBe(want)
				end
			end
			t.expect(D.Buildings.Harbour.levels[1].hq).toBe(0)
			t.expect(D.Buildings.Workshop.levels[1].hq).toBe(1)
		end
	)

	t.test(
		"Robux products: each level sells at its config price, never cheaper than packs",
		function()
			local CASH_PER_ROBUX = 50400 / 149 -- the best Cash pack (docs/23 (i))
			for _, key in D.BUILDINGS do
				for n, lvl in D.Buildings[key].levels do
					if lvl.product then
						local item = Monetization.Products[lvl.product]
						t.expect(item ~= nil).toBe(true)
						t.expect(item.price).toBe(lvl.robux)
						t.expect(item.dockBuilding).toBe(key)
						t.expect(item.dockLevel or 1).toBe(n)
						t.expect(lvl.robux >= 1.3 * lvl.cash / CASH_PER_ROBUX).toBe(true)
					end
				end
			end
			t.expect(D.buildingFor("DockLevel2")).toEqual("Harbour", 2)
			t.expect(D.buildingFor("DockCrane")).toEqual("Harbour", 3)
			t.expect(D.buildingFor("DockHangar")).toEqual("AirStation", 1)
			t.expect(D.buildingFor("DockLevel5")).toEqual("HQ", 3)
			t.expect(D.buildingFor("SmallBonus")).toBe(nil)
		end
	)

	t.test("vehicle boards: the air station and the sub pen hold their craft", function()
		t.expect(D.buildingOf("RescueHelicopter")).toBe("AirStation")
		t.expect(D.buildingOf("Submarine")).toBe("SubPen")
		t.expect(D.buildingOf("RIB")).toBe(nil)
	end)

	t.test("old dock levels still cover every piece they used to build", function()
		t.expect(D.LEVEL_ITEMS[2]).toEqual({ "Pontoon" })
		t.expect(D.LEVEL_ITEMS[3]).toEqual({ "Workshop", "Boathouse" })
		t.expect(D.LEVEL_ITEMS[4]).toEqual({ "LookoutTower", "Crane" })
		t.expect(D.LEVEL_ITEMS[5]).toEqual({ "Station", "TrophyHall" })
	end)

	t.test("the boat board slot sits at quay height by the new boathouse", function()
		t.expect(math.abs(D.BOARD_SLOT.Y - Marina.DECK_TOP) < 1e-3).toBe(true)
		local p = D.Buildings.Boathouse.spot:PointToObjectSpace(D.BOARD_SLOT.Position)
		t.expect(math.abs(p.X) < D.Buildings.Boathouse.size.X / 2).toBe(true)
	end)

	t.test("land buildings stay on the plate and clear of each other", function()
		local RingLayout = t.load("src/shared/Config/RingLayout.luau")
		local boxes = {}
		for _, key in D.BUILDINGS do
			local b = D.Buildings[key]
			if key == "Harbour" then
				continue -- on the water
			end
			local l = Marina.ISLAND:ToObjectSpace(b.spot)
			local hx = (math.abs(l.XVector.X) * b.size.X + math.abs(l.ZVector.X) * b.size.Y) / 2
				+ 1.5 -- + plinth
			local hz = (math.abs(l.XVector.Z) * b.size.X + math.abs(l.ZVector.Z) * b.size.Y) / 2
				+ 1.5
			local r, f = l.X, -l.Z
			for _, c in { { -hx, -hz }, { hx, -hz }, { -hx, hz }, { hx, hz } } do
				if not RingLayout.plateContains(r + c[1], f + c[2]) then
					error(key .. " is off the plate")
				end
			end
			for other, o in boxes do
				local apart = math.abs(r - o[1]) >= hx + o[3] or math.abs(f - o[2]) >= hz + o[4]
				if not apart then
					error(key .. " overlaps " .. other)
				end
			end
			boxes[key] = { r, f, hx, hz }
		end
	end)
end
