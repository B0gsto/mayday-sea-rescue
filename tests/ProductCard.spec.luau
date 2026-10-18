-- RP-M3 product cards: every docs/04 item has a shelf, rule 6 (no prices before three operations),
-- rule 5 (only a real, offered item in a "buy" state may open a prompt), and the card copy.
return function(t)
	local Shelves = t.load("src/shared/ProductShelves.luau")
	local Config = t.load("src/shared/Config/MonetizationConfig.luau")

	local function clone(tbl)
		local out = {}
		for k, v in tbl do
			out[k] = if type(v) == "table" then clone(v) else v
		end
		return out
	end
	-- a config where `keys` are live (ready with an id)
	local function live(keys)
		local c = clone(Config)
		local n = 1000
		for _, ref in keys do
			n += 1
			c[ref.kind][ref.key].id = n
			c[ref.kind][ref.key].ready = true
		end
		return c
	end
	local function pass(key)
		return { kind = "GamePasses", key = key }
	end
	local function product(key)
		return { kind = "Products", key = key }
	end
	local function ctx(extra, noPrice)
		local c = { offered = true, price = 199 }
		for k, v in extra or {} do
			c[k] = v
		end
		if noPrice then
			c.price = nil
		end
		return c
	end

	t.test("every catalogue item sits on a shelf, and every shelf item exists", function()
		local onShelf = {}
		for _, id in Shelves.Order do
			local shelf = Shelves.Shelves[id]
			t.expect(shelf ~= nil).toBe(true)
			t.expect(shelf.id).toBe(id)
			for _, ref in shelf.items do
				t.expect(Config[ref.kind][ref.key] ~= nil).toBe(true)
				onShelf[`{ref.kind}/{ref.key}`] = true
			end
		end
		for _, kind in { "GamePasses", "Products" } do
			for key in Config[kind] do
				t.expect(onShelf[`{kind}/{key}`]).toBe(true)
			end
		end
		local count = 0
		for _ in Shelves.Shelves do
			count += 1
		end
		t.expect(count).toBe(#Shelves.Order)
	end)

	t.test("Chandlery shelves map to the H2 ATT_ markers", function()
		local map = Shelves.attachmentShelves()
		t.expect(map.ATT_Till).toBe("Till")
		t.expect(map.ATT_ServiceCards).toBe("ServiceCards")
		t.expect(map.ATT_RadioShelf).toBe("RadioShelf")
		t.expect(map.ATT_Counter).toBeNil() -- the Cash gear counter stays HudShop's
		t.expect(Shelves.Shelves.StormDesk.attachment).toBeNil() -- map/Build.luau marker
	end)

	t.test("rule 6: priced shelves stay shut until three operations", function()
		t.expect(Shelves.pricedOpen(nil, nil)).toBe(false)
		t.expect(Shelves.pricedOpen({ coldOpenDone = true, rankIndex = 1 }, 2)).toBe(false)
		t.expect(Shelves.pricedOpen({ coldOpenDone = true, rankIndex = 1 }, 3)).toBe(true)
		t.expect(Shelves.pricedOpen({ coldOpenDone = false, rankIndex = 3 }, 5)).toBe(false)
		-- a returning player (OpsCompleted is per session) passes on saved progress
		t.expect(Shelves.pricedOpen({ coldOpenDone = true, rankIndex = 2 }, 0)).toBe(true)
		t.expect(Shelves.pricedOpen({ certs = { Helm = { earned = true } } }, 0)).toBe(true)
		t.expect(Shelves.pricedOpen({ certs = { Helm = { live = 2 }, Care = { live = 1 } } }, 0))
			.toBe(true)
		t.expect(Shelves.pricedOpen({ certs = { Helm = { live = 2 } } }, 0)).toBe(false)
		local c = live({ pass("DoubleCash") })
		t.expect(Shelves.shelfVisible(c, "ServiceCards", false, false)).toBe(false)
		t.expect(Shelves.shelfVisible(c, "ServiceCards", false, true)).toBe(true)
	end)

	t.test("unfinished items are listed only in Studio; ready items show even with id 0", function()
		-- a config with everything ready = false (RP-M2 has since flipped the built effects)
		local unready = clone(Config)
		for _, kind in { "Products", "GamePasses" } do
			for _, it in unready[kind] do
				it.ready = false
			end
		end
		t.expect(Shelves.shelfVisible(unready, "Till", false, true)).toBe(false)
		t.expect(Shelves.shelfVisible(unready, "Till", true, true)).toBe(true)
		t.expect(#Shelves.shelfItems(unready, "Till", true)).toBe(7)
		local c = clone(Config)
		c.GamePasses.QuickLaunch.ready = true -- RP-M2 done, RP-M4 not yet: id 0
		t.expect(Shelves.shelfVisible(c, "BoatDeskQuickLaunch", false, true)).toBe(true)
		local st = Shelves.cardState(c, pass("QuickLaunch"), ctx({ offered = false }))
		t.expect(st.status).toBe("comingSoon")
		t.expect(st.canBuy).toBe(false)
		t.expect(Shelves.mayPrompt(c, pass("QuickLaunch"), ctx({ offered = true }))).toBe(false)
	end)

	t.test("rule 5: only an offered item with an id and a live price may prompt", function()
		local c = live({ pass("DoubleCash"), product("SmallBonus") })
		local ref = pass("DoubleCash")
		t.expect(Shelves.mayPrompt(c, ref, ctx())).toBe(true)
		t.expect(Shelves.mayPrompt(c, ref, ctx({ offered = false }))).toBe(false) -- server did not offer it
		t.expect(Shelves.mayPrompt(c, ref, ctx({}, true))).toBe(false) -- price still loading
		t.expect(Shelves.mayPrompt(c, ref, ctx({ priceFailed = true }, true))).toBe(false)
		t.expect(Shelves.mayPrompt(c, ref, ctx({ owned = true }))).toBe(false)
		t.expect(Shelves.mayPrompt(c, ref, ctx({ pending = true }))).toBe(false)
		c.GamePasses.DoubleCash.id = 0
		t.expect(Shelves.mayPrompt(c, ref, ctx())).toBe(false)
		t.expect(Shelves.mayPrompt(c, pass("NoSuchPass"), ctx())).toBe(false)
	end)

	t.test("the Buy button shows the live price, never the config price", function()
		local c = live({ pass("DoubleCash") })
		local st = Shelves.cardState(c, pass("DoubleCash"), ctx({ price = 1250 }))
		t.expect(st.status).toBe("buy")
		t.expect(st.buyText).toBe(`Buy  {Shelves.ROBUX} 1,250`)
		t.expect(Shelves.cardState(c, pass("DoubleCash"), ctx({ owned = true })).buyText)
			.toBe("Owned")
	end)

	t.test("Cash packs: exact Cash, daily limit; Cash Boost hides for 2x owners", function()
		local c = live({ product("SmallBonus"), product("HarborFund"), product("CashBoost") })
		t.expect(Shelves.packCash(c.Products.SmallBonus, 100)).toBe(1500) -- docs/04 4.1 Calm Bay
		t.expect(Shelves.packCash(c.Products.HarborFund, 100)).toBe(50400)
		t.expect(Shelves.packCash(c.Products.SmallBonus, nil)).toBeNil()
		local st = Shelves.cardState(c, product("SmallBonus"), ctx({ cashPerMinute = 100 }))
		t.expect(st.note).toBe("You get 1,500 Cash at your top open zone's rate.")
		st = Shelves.cardState(c, product("SmallBonus"), ctx({ cashPacksToday = 5 }))
		t.expect(st.status).toBe("limit")
		t.expect(st.canBuy).toBe(false)
		t.expect(Shelves.cardState(c, product("CashBoost"), ctx({ ownsDoubleCash = true })).status)
			.toBe("hidden")
		t.expect(Shelves.cardState(c, product("CashBoost"), ctx()).status).toBe("buy")
	end)

	t.test("storms: a full queue greys out Buy; the chalkboard reads the queue", function()
		local c = live({ product("CallTheStorm") })
		local ref = product("CallTheStorm")
		t.expect(Shelves.cardState(c, ref, ctx({ stormQueue = 1 })).status).toBe("buy")
		local st = Shelves.cardState(c, ref, ctx({ stormQueue = 2 }))
		t.expect(st.status).toBe("queueFull")
		t.expect(st.note).toBe("Storm queue full, try again soon.")
		t.expect(Shelves.mayPrompt(c, ref, ctx({ stormQueue = 2 }))).toBe(false)
		t.expect(Shelves.stormBoardText(0)).toBe("STORM QUEUE\nNone waiting")
		t.expect(Shelves.stormBoardText(1)).toBe("STORM QUEUE\n1 of 2 waiting")
		t.expect(Shelves.stormBoardText(2)).toBe("STORM QUEUE\nFull, try again soon")
	end)
end
