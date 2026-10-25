-- MonetizationEffects (RP-M2): Cash packs, boosts, Storm Tickets, the storm summon schedule and the
-- Quick Launch gate (docs/04 sections 3, 4 and 5). Every effect is Cash or a shared storm.
return function(t)
	local Effects = t.load("src/shared/MonetizationEffects.luau")
	local Config = t.load("src/shared/Config/MonetizationConfig.luau")
	local Shelves = t.load("src/shared/ProductShelves.luau")
	local STORM = {
		WarningSeconds = 60,
		StormSeconds = 180,
		GreatStormSeconds = 240,
		ClearingSeconds = 60,
		CalmSeconds = 600,
	}

	t.test("Cash packs pay docs/04 4.1 at the top live zone, matching the card", function()
		local cpm = Effects.cashPerMinute(Config.CashPackZones, 1)
		t.expect(cpm).toBe(100) -- Calm Bay ~6,000 Cash per hour
		t.expect(Effects.packCash(Config.Products.SmallBonus, cpm)).toBe(1500)
		t.expect(Effects.packCash(Config.Products.CrewPayroll, cpm)).toBe(4500)
		t.expect(Effects.packCash(Config.Products.StationBudget, cpm)).toBe(16500)
		t.expect(Effects.packCash(Config.Products.HarborFund, cpm)).toBe(50400)
		for _, key in Config.CashPacks do
			t.expect(Effects.packCash(Config.Products[key], cpm))
				.toBe(Shelves.packCash(Config.Products[key], cpm))
		end
		-- zones that have not shipped do not raise the rate; ones that have do
		t.expect(Effects.cashPerMinute(Config.CashPackZones)).toBe(100)
		local zones = {
			{ id = "CalmBay", cashPerHour = 6000, live = true },
			{ id = "StormFront", cashPerHour = 17300, live = true },
		}
		t.expect(Effects.packCash(Config.Products.SmallBonus, Effects.cashPerMinute(zones)))
			.toBe(4325)
		t.expect(Effects.cashPerMinute({})).toBe(0)
		t.expect(Effects.packCash(Config.Products.SmallBonus, 0)).toBe(0)
	end)

	t.test("the daily pack count resets each UTC day", function()
		local shop = {}
		local day = Effects.dayOf(1_800_000_000)
		t.expect(Effects.packsToday(shop, day)).toBe(0)
		Effects.countPack(shop, day)
		Effects.countPack(shop, day)
		t.expect(Effects.packsToday(shop, day)).toBe(2)
		t.expect(Effects.packsToday(shop, day + 1)).toBe(0)
		Effects.countPack(shop, day + 1)
		t.expect(shop.packs).toBe(1)
		t.expect(Effects.packsToday(nil, day)).toBe(0)
	end)

	t.test("2x Cash and Cash Boost do not stack; Crew Boost adds +50% of the base", function()
		t.expect(Effects.cashMultiplier(false, 0, false)).toBe(1)
		t.expect(Effects.cashMultiplier(true, 0, false)).toBe(2)
		t.expect(Effects.cashMultiplier(false, 30, false)).toBe(2)
		t.expect(Effects.cashMultiplier(true, 30, false)).toBe(2)
		t.expect(Effects.cashMultiplier(false, 0, true)).toBe(1.5)
		t.expect(Effects.cashMultiplier(true, 0, true)).toBe(2.5)
	end)

	t.test("boost time adds up, caps at a day and only ticks down while playing", function()
		local shop = {}
		Effects.addBoost(shop, "cashBoost", 1800)
		Effects.addBoost(shop, "cashBoost", 1800)
		t.expect(shop.cashBoost).toBe(3600)
		Effects.addBoost(shop, "crewBoost", 1e9)
		t.expect(shop.crewBoost).toBe(Effects.BOOST_CAP_SECONDS)
		t.expect(Effects.tickBoosts(shop, 5)).toBe(true)
		t.expect(shop.cashBoost).toBe(3595)
		Effects.tickBoosts(shop, 1e9)
		t.expect(shop.cashBoost).toBeNil()
		t.expect(shop.crewBoost).toBeNil()
		t.expect(Effects.tickBoosts(shop, 5)).toBe(false)
	end)

	t.test("Storm Tickets are added on purchase and taken only when the storm runs", function()
		local shop = {}
		t.expect(Effects.addTicket(shop, "Storm")).toBe(true)
		t.expect(Effects.addTicket(shop, "GreatStorm")).toBe(true)
		t.expect(Effects.addTicket(shop, "Hurricane")).toBe(false)
		t.expect(Effects.tickets(shop, "Storm")).toBe(1)
		t.expect(Effects.takeTicket(shop, "Storm")).toBe(true)
		t.expect(Effects.takeTicket(shop, "Storm")).toBe(false)
		t.expect(shop.ticketStorm).toBeNil()
		t.expect(Effects.tickets(shop, "GreatStorm")).toBe(1)
	end)

	t.test(
		"summoned storms keep the 2-minute natural buffer, the 8-minute gap and the natural clock",
		function()
			local function decide(now, extra)
				local ctx = {
					state = "Calm",
					now = now,
					naturalEnd = 0, -- the natural storm cleared at 0
					naturalWarningAt = 600, -- the next one is due at 600
					lastSummonEnd = -math.huge,
					total = Effects.summonSeconds("Storm", STORM),
				}
				for k, v in extra or {} do
					ctx[k] = v
				end
				return Effects.summonDecision(ctx)
			end
			t.expect(Effects.summonSeconds("Storm", STORM)).toBe(300)
			t.expect(Effects.summonSeconds("GreatStorm", STORM)).toBe(360)
			t.expect(decide(60)).toBe("Wait") -- within 2 minutes after the natural storm
			t.expect(decide(120)).toBe("Start")
			t.expect(decide(180)).toBe("Start") -- 180 + 300 + 120 = 600: just fits
			t.expect(decide(200)).toBe("Wait") -- would end within 2 minutes of the natural storm
			t.expect(decide(120.25, { total = 360 })).toBe("Start") -- the Great Storm's exact window, one tick late
			t.expect(decide(130, { total = 360 })).toBe("Wait")
			t.expect(decide(150, { state = "Storm" })).toBe("Wait")
			t.expect(decide(150, { state = "Warning" })).toBe("Wait")
			-- 8 minutes after the last summoned storm
			t.expect(decide(150, { lastSummonEnd = -320 })).toBe("Wait")
			t.expect(decide(160, { lastSummonEnd = -320 })).toBe("Start")
			-- a calm too short to ever fit it: run it rather than strand a paid storm
			t.expect(decide(120, { naturalWarningAt = 300 })).toBe("StartPushNatural")
			t.expect(Effects.Summon.QueueMax).toBe(Shelves.STORM_QUEUE_MAX)
		end
	)

	t.test("Quick Launch needs the pass and a finished cold open, from anywhere", function()
		t.expect(Effects.quickLaunchAllowed(true, true)).toBe(true)
		t.expect(select(2, Effects.quickLaunchAllowed(false, true))).toBe("NotOwned")
		t.expect(select(2, Effects.quickLaunchAllowed(true, false))).toBe("ColdOpen")
	end)

	t.test("Boat to me waits out its cooldown unless you own Quick Launch", function()
		local cd = Effects.BOAT_TO_ME_COOLDOWN
		t.expect(Effects.boatToMeWait(false, nil, 100)).toBe(0)
		t.expect(Effects.boatToMeWait(false, 100, 110)).toBe(cd - 10)
		t.expect(Effects.boatToMeWait(false, 100, 100 + cd + 1)).toBe(0)
		t.expect(Effects.boatToMeWait(true, 100, 101)).toBe(0)
		-- a hired Mechanic passes the shortened wait (x0.7 = 42 s); almost all of it still to run
		t.expect(Effects.boatToMeWait(false, 100, 110, 42)).toBe(32)
		t.expect(Effects.boatToMeWait(false, 100, 100 + 42, 42)).toBe(0)
	end)

	t.test("a pass counts while owned or while its day pass runs", function()
		t.expect(Effects.passActive(true, nil, 100)).toBe(true)
		t.expect(Effects.passActive(false, nil, 100)).toBe(false)
		t.expect(Effects.passActive(false, 200, 100)).toBe(true)
		t.expect(Effects.passActive(false, 100, 100)).toBe(false)
	end)

	t.test("only items with a built effect are ready; cosmetics wait for their art", function()
		local ready = {
			Products = {
				SmallBonus = true,
				CrewPayroll = true,
				StationBudget = true,
				HarborFund = true,
				CashBoost = true,
				CrewBoost = true,
				DayDoubleCash = true, -- OwnsPass accepts a running day pass
				DayQuickLaunch = true,
				DockLevel2 = true, -- DockService grants dock levels (docs/23 WP-4)
				DockLevel3 = true,
				DockLevel4 = true,
				DockLevel5 = true,
				DockHangar = true,
				DockSubPen = true,
			},
			GamePasses = { DoubleCash = true, StarterKit = true, QuickLaunch = true }, -- QuickLaunch: RP-A1 use card
		}
		-- cut 2026-10-25 (pre-hub-cut): the cars, the car garage and the seaplane stay recorded but are never sold
		local cut = {
			DockGarage = true,
			BeachATVPass = true,
			CoastguardResponsePass = true,
			HarbourGTPass = true,
			LighthouseCruiserPass = true,
			SeaplanePass = true,
		}
		for kind, items in { Products = Config.Products, GamePasses = Config.GamePasses } do
			for key, item in items do
				local want = not cut[key] and (ready[kind][key] == true or item.vehicle ~= nil) -- vehicle passes: ProgressionRules.vehiclePass
				t.expect(`{kind}.{key}={item.ready == true}`).toBe(`{kind}.{key}={want}`)
				t.expect(item.id >= 0 and item.id % 1 == 0).toBe(true) -- 0 = off; RP-M4 (deploy.py) writes the real ids
			end
		end
		-- the Starter Kit's card states only what it gives today (docs/04 rule 4)
		t.expect(
			string.find(Config.GamePasses.StarterKit.description, "later update", 1, true) ~= nil
		)
			.toBe(true)
	end)

	t.test("day passes run 24 h of real time, stack, and end", function()
		local shop = {}
		local now = 1_800_000_000
		t.expect(Effects.dayPassEnds(nil, "DoubleCash")).toBe(0)
		local ends = Effects.addDayPass(shop, "DoubleCash", 24, now)
		t.expect(ends >= now + 24 * 3600 and ends < now + 25 * 3600).toBe(true)
		t.expect(shop.dayDoubleCash < 1e6).toBe(true) -- the flag limit
		t.expect(Effects.dayPassEnds(shop, "DoubleCash")).toBe(ends)
		t.expect(Effects.dayPassEnds(shop, "QuickLaunch")).toBe(0)
		t.expect(Effects.addDayPass(shop, "DoubleCash", 24, now + 3600)).toBe(ends + 24 * 3600)
		local later = ends + 24 * 3600 + 10 -- long expired: a new day starts from now
		t.expect(Effects.addDayPass(shop, "DoubleCash", 24, later) >= later + 24 * 3600).toBe(true)
		for _, item in Config.Products do
			if item.dayPassFor then
				t.expect(Config.GamePasses[item.dayPassFor] ~= nil).toBe(true)
				t.expect(item.dayPassHours).toBe(24)
			end
		end
	end)
end
