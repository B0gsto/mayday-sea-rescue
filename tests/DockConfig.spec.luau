-- DockConfig (docs/23 WP-4): levels 2..5, two prices, Cash purchase validation, the Robux products.
return function(t)
	local D = t.load("src/shared/Config/DockConfig.luau")
	local Monetization = t.load("src/shared/Config/MonetizationConfig.luau")
	local Marina = t.load("src/shared/Marina.luau")

	t.test("levels 2..5 match docs/23 d.2 and rise in price and rank", function()
		local cash = { 2500, 10000, 30000, 100000 }
		local robux = { 49, 99, 149, 249 }
		for n = 2, D.MAX do
			local lv = D.Levels[n]
			t.expect(lv.cash).toBe(cash[n - 1])
			t.expect(lv.robux).toBe(robux[n - 1])
			if n > 2 then
				t.expect(D.rankIndex(lv.rank) > D.rankIndex(D.Levels[n - 1].rank)).toBe(true)
			end
		end
		t.expect(D.Levels[1]).toBe(nil)
	end)

	t.test("every level has a Robux product at its price, hidden by dockLevel", function()
		for n = 2, D.MAX do
			local item = Monetization.Products[D.Levels[n].product]
			t.expect(item ~= nil).toBe(true)
			t.expect(item.price).toBe(D.Levels[n].robux)
			t.expect(item.dockLevel).toBe(n)
			t.expect(D.levelFor(D.Levels[n].product)).toBe(n)
		end
		t.expect(D.levelFor("SmallBonus")).toBe(nil)
	end)

	t.test("Cash purchase: next level only, rank then Cash", function()
		local lifeguard = D.rankIndex("Lifeguard")
		t.expect(D.canBuy(1, 2, 2500, lifeguard)).toBe(true)
		local ok, reason = D.canBuy(1, 3, 1e9, 99)
		t.expect(ok).toBe(false)
		t.expect(reason).toBe("Level")
		ok, reason = D.canBuy(2, 2, 1e9, 99)
		t.expect(reason).toBe("Level")
		ok, reason = D.canBuy(5, 6, 1e9, 99)
		t.expect(reason).toBe("Level")
		ok, reason = D.canBuy(1, 2, 1e9, lifeguard - 1)
		t.expect(ok).toBe(false)
		t.expect(reason).toBe("Rank")
		local price
		ok, reason, price = D.canBuy(1, 2, 2499, lifeguard)
		t.expect(reason).toBe("Cash")
		t.expect(price).toBe(2500)
	end)

	t.test("the boat board slot sits on the deck, inside the plot", function()
		local p = D.BOARD_SLOT.Position
		local half = D.BOARD_SIZE / 2
		t.expect(p.Y).toBe(Marina.DECK_TOP)
		t.expect(p.X - half >= Marina.PLOT_X[1]).toBe(true)
		t.expect(p.X + half <= Marina.PLOT_X[2]).toBe(true)
		t.expect(p.Z - half >= Marina.BERTH / 2).toBe(true)
		t.expect(p.Z + half <= Marina.BERTH / 2 + Marina.DECK).toBe(true)
	end)
end
