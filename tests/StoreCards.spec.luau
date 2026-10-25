-- Store app cards (ProductShelves): rule 5 (only a real, offered item in a "buy" state may open a
-- prompt), the card copy, and every launch id listed in the phone Store.
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

	t.test("unfinished items are listed only in Studio; ready items show even with id 0", function()
		-- a config with everything ready = false (RP-M2 has since flipped the built effects)
		local unready = clone(Config)
		for _, kind in { "Products", "GamePasses" } do
			for _, it in unready[kind] do
				it.ready = false
			end
		end
		t.expect(#Shelves.storeItems(unready, "Items", false)).toBe(0)
		t.expect(#Shelves.storeItems(unready, "Items", true) > 0).toBe(true)
		local c = clone(Config)
		c.GamePasses.QuickLaunch.ready = true -- RP-M2 done, RP-M4 not yet: id 0
		c.GamePasses.QuickLaunch.id = 0
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

	t.test("storms: a full queue greys out Buy", function()
		local c = live({ product("CallTheStorm") })
		local ref = product("CallTheStorm")
		t.expect(Shelves.cardState(c, ref, ctx({ stormQueue = 1 })).status).toBe("buy")
		local st = Shelves.cardState(c, ref, ctx({ stormQueue = 2 }))
		t.expect(st.status).toBe("queueFull")
		t.expect(st.note).toBe("Storm queue full, try again soon.")
		t.expect(Shelves.mayPrompt(c, ref, ctx({ stormQueue = 2 }))).toBe(false)
	end)

	t.test("the Shop splits passes, packs, boosts and day passes, in order", function()
		local seen = {}
		for _, tab in { "Passes", "Packs", "Boosts", "DayPasses" } do
			local last = -math.huge
			for _, ref in Shelves.storeItems(Config, tab, true) do
				local item = Config[ref.kind][ref.key]
				t.expect(item.order >= last).toBe(true)
				last = item.order
				t.expect(item.dayPassFor ~= nil).toBe(tab == "DayPasses")
				t.expect(ref.kind == "GamePasses").toBe(tab == "Passes")
				if ref.kind == "Products" and tab ~= "DayPasses" then
					t.expect(item.cashMinutes ~= nil).toBe(tab == "Packs")
				end
				t.expect(seen[`{ref.kind}/{ref.key}`]).toBe(nil) -- every item on one tab only
				seen[`{ref.kind}/{ref.key}`] = true
			end
		end
		for _, kind in { "GamePasses", "Products" } do
			for key, item in Config[kind] do
				-- Studio lists everything once; dock levels sell only at the dock
				t.expect(seen[`{kind}/{key}`] == true)
					.toBe(item.dockLevel == nil and item.dockBuilding == nil)
			end
		end
		for _, ref in Shelves.storeItems(Config, "Passes", false) do
			t.expect(Config.GamePasses[ref.key].ready ~= false).toBe(true)
		end
	end)

	t.test("the live Store sells every launch id (no in-world shelf needed)", function()
		local listed = {}
		for _, tab in { "Passes", "Packs", "Boosts", "DayPasses" } do
			for _, ref in Shelves.storeItems(Config, tab, false) do
				listed[`{ref.kind}/{ref.key}`] = true
			end
		end
		for _, kind in { "GamePasses", "Products" } do
			for key, item in Config[kind] do
				-- dock levels and buildings sell at the dock's ghost, not in the Store (docs/23 c.3)
				local atDock = item.dockLevel ~= nil or item.dockBuilding ~= nil
				if
					type(item.id) == "number"
					and item.id > 0
					and item.ready ~= false
					and not atDock
				then
					t.expect(listed[`{kind}/{key}`]).toBe(true)
				end
			end
		end
	end)
end
