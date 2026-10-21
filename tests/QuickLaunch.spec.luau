-- Quick Launch use card (BoatDesk): owners get one "Launch now" page per launchable boat, non-owners
-- keep the product card (src/shared/QuickLaunchCard.luau, ProductShelves, MonetizationEffects).
return function(t)
	local Card = t.load("src/shared/QuickLaunchCard.luau")
	local Shelves = t.load("src/shared/ProductShelves.luau")
	local Config = t.load("src/shared/Config/MonetizationConfig.luau")
	local Effects = t.load("src/shared/MonetizationEffects.luau")

	local function ctx(over)
		local c = { boats = { "JetSki", "RIB" }, busy = nil, coldOpenDone = true, failure = nil }
		for k, v in over or {} do
			c[k] = v
		end
		return c
	end

	t.test("owners may launch only usable sea boats, in order", function()
		local usable = { JetSki = true, RIB = false, Car = true }
		local list = Card.boats({ "JetSki", "RIB", "Car" }, function(id)
			return usable[id] == true
		end, function(id)
			return id == "Car"
		end)
		t.expect(#list).toBe(1)
		t.expect(list[1]).toBe("JetSki")
	end)

	t.test("a launchable boat offers Launch now; busy and cold open block it", function()
		local st = Card.state(ctx(), "RIB")
		t.expect(st.canLaunch).toBe(true)
		t.expect(st.buttonText).toBe("Launch now")
		t.expect(st.note).toBe(nil)
		st = Card.state(ctx({ busy = "RIB" }), "RIB")
		t.expect(st.canLaunch).toBe(false)
		t.expect(st.buttonText).toBe("Launching...")
		st = Card.state(ctx({ coldOpenDone = false }), "RIB")
		t.expect(st.canLaunch).toBe(false)
		t.expect(st.note).toBe(Card.reasonText("ColdOpen"))
	end)

	t.test("no boat, or one not on the list, cannot launch", function()
		t.expect(Card.state(ctx({ boats = {} }), nil).canLaunch).toBe(false)
		t.expect(Card.state(ctx({ boats = { "JetSki" } }), "RIB").canLaunch).toBe(false)
	end)

	t.test("a server refusal shows as a note and the player may retry", function()
		local st = Card.state(ctx({ failure = "NoBay" }), "JetSki")
		t.expect(st.canLaunch).toBe(true)
		t.expect(st.note).toBe(Card.reasonText("NoBay"))
		-- every quickLaunchAllowed refusal has its own copy
		for _, why in { "NotOwned", "ColdOpen" } do
			t.expect(Card.reasonText(why) ~= Card.reasonText(nil)).toBe(true)
		end
		local ok, why = Effects.quickLaunchAllowed(true, false)
		t.expect(ok).toBe(false)
		t.expect(Card.reasonText(why) ~= Card.reasonText(nil)).toBe(true)
		t.expect(Card.reasonText("Weird")).toBe("Can't launch right now.")
	end)

	t.test("owners see the desk prompt before the priced shelves open; others do not", function()
		t.expect(Card.promptVisible(true, true, false)).toBe(true)
		t.expect(Card.promptVisible(true, false, false)).toBe(false)
		t.expect(Card.promptVisible(false, true, false)).toBe(false)
		t.expect(Card.promptVisible(true, false, true)).toBe(true)
	end)

	t.test(
		"the card and config agree: Quick Launch is a pass on the BoatDesk shelf, and ready",
		function()
			local shelf = Shelves.Shelves[Card.SHELF]
			t.expect(shelf ~= nil).toBe(true)
			t.expect(shelf.items[1].kind).toBe("GamePasses")
			t.expect(shelf.items[1].key).toBe(Card.PASS)
			local item = Config.GamePasses[Card.PASS]
			t.expect(item.ready).toBe(true)
			-- non-owners keep the purchase card: listed outside Studio, "Coming soon" until RP-M4's id
			t.expect(Shelves.listed(item, false)).toBe(true)
			local st = Shelves.cardState(Config, shelf.items[1], { offered = false })
			t.expect(st.status).toBe("comingSoon")
		end
	)
end
