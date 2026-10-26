-- DockConfig (docs/23 (q), WP-28): the unlock tree's rows, their prices, the Robux products, the board slot.
return function(t)
	local D = t.load("src/shared/Config/DockConfig.luau")
	local Monetization = t.load("src/shared/Config/MonetizationConfig.luau")
	local Marina = t.load("src/shared/Marina.luau")

	t.test(
		"every building is listed once, with a name, a short desc, a price and a spot",
		function()
			local seen = {}
			for _, key in D.BUILDINGS do
				t.expect(seen[key]).toBeNil()
				seen[key] = true
				local b = D.Buildings[key]
				t.expect(b ~= nil).toBe(true)
				t.expect(#b.name > 0 and #string.split(b.name, " ") <= 3).toBe(true)
				t.expect(#string.split(b.desc, " ") <= 10).toBe(true)
				t.expect(b.cash > 0).toBe(true)
				t.expect(b.size.X > 0 and b.size.Y > 0).toBe(true)
			end
			for key in D.Buildings do
				t.expect(seen[key]).toBe(true)
			end
		end
	)

	t.test(
		"Robux products: each sells its own building at the config price, never cheaper than packs",
		function()
			local CASH_PER_ROBUX = 50400 / 149 -- the best Cash pack (docs/23 (i))
			for _, rows: { [string]: any } in { D.Buildings :: any, D.Decorations } do
				for key, b in rows do
					t.expect(b.product ~= nil).toBe(true) -- every Cash item has its Robux skip
					local item = Monetization.Products[b.product]
					t.expect(item ~= nil).toBe(true)
					t.expect(item.price).toBe(b.robux)
					t.expect(item.dockBuilding).toBe(key)
					t.expect(b.robux >= 1.3 * b.cash / CASH_PER_ROBUX).toBe(true)
				end
			end
			for key, b in D.Buildings do
				t.expect(D.buildingFor(b.product)).toBe(key)
			end
			t.expect(D.buildingFor("SmallBonus")).toBe(nil)
			t.expect(D.Buildings.Pontoon.product).toBe("DockLevel2")
			t.expect(D.Buildings.Boathouse.product).toBe("DockLevel3")
		end
	)

	t.test("vehicle boards: the hangar and the sub pen hold their craft", function()
		t.expect(D.buildingOf("RescueHelicopter")).toBe("Hangar")
		t.expect(D.buildingOf("Submarine")).toBe("SubPen")
		t.expect(D.buildingOf("RIB")).toBe(nil)
	end)

	t.test("old dock levels cover every piece they used to build", function()
		t.expect(D.LEVEL_ITEMS[2]).toEqual({ "Pontoon" })
		t.expect(D.LEVEL_ITEMS[3]).toEqual({ "Workshop", "Boathouse" })
		t.expect(D.LEVEL_ITEMS[4]).toEqual({ "LookoutTower", "Crane" })
		t.expect(D.LEVEL_ITEMS[5]).toEqual({ "Station", "TrophyHall" })
	end)

	t.test("the boat board slot sits on the boathouse lot, at quay height", function()
		local lot = Marina.LOTS.Boathouse
		local p = lot.cf:PointToObjectSpace(D.BOARD_SLOT.Position)
		local half = D.BOARD_SIZE / 2
		t.expect(math.abs(D.BOARD_SLOT.Y - Marina.DECK_TOP) < 1e-3).toBe(true)
		t.expect(math.abs(p.X) + half <= lot.size.X / 2).toBe(true)
		t.expect(math.abs(p.Z) + half <= lot.size.Y / 2).toBe(true)
	end)

	t.test("land buildings (WP-25 r8 scaled) stay on the plate and clear of each other", function()
		local RingLayout = t.load("src/shared/Config/RingLayout.luau")
		local boxes = {}
		for key, b in D.Buildings do
			if key == "Pontoon" or key == "Crane" or key == "SubPen" or key == "TrophyHall" then
				continue -- on the water, or on the station's wall
			end
			local l = Marina.ISLAND:ToObjectSpace(b.spot)
			local hx = (math.abs(l.XVector.X) * b.size.X + math.abs(l.ZVector.X) * b.size.Y) / 2
				+ 1.5 -- + plinth
			local hz = (math.abs(l.XVector.Z) * b.size.X + math.abs(l.ZVector.Z) * b.size.Y) / 2
				+ 1.5
			local r, f = l.X, -l.Z
			for _, c in { { -hx, -hz }, { hx, -hz }, { -hx, hz }, { hx, hz } } do
				t.expect(RingLayout.plateContains(r + c[1], f + c[2])).toBe(true)
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
