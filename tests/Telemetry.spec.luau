-- Telemetry (RP-A1, G64, 2026-10-24 funnels): the onboarding funnel numbering, recurring funnel steps,
-- client guards, buckets, economy mapping and the custom events one call sends
-- (src/server/Services/Telemetry/Events.luau, pure).
return function(t)
	local Events = t.load("src/server/Services/Telemetry/Events.luau")

	local function facts(over)
		local f = {
			kind = "PersonInWater",
			grade = "Gold",
			reason = "Complete",
			helped = true,
			coldOpen = false,
			storm = false,
			big = false,
			rarity = "Common",
			saved = 1,
		}
		for k, v in over or {} do
			f[k] = v
		end
		return f
	end

	t.test("the onboarding funnel is numbered 1..n in order with unique names", function()
		local seen = {}
		for i, s in Events.Funnel do
			t.expect(s.step).toBe(i)
			t.expect(seen[s.name]).toBe(nil)
			seen[s.name] = true
			t.expect(Events.funnelStep(s.name).step).toBe(i)
		end
		t.expect(Events.funnelStep("Joined").step).toBe(1)
		t.expect(Events.funnelStep("AtSea").step).toBe(2)
		t.expect(Events.funnelStep("FirstBoard").step).toBe(3)
		t.expect(Events.funnelStep("FirstDelivery").step).toBe(4)
		t.expect(Events.funnelStep("Call2Accepted").step).toBe(6)
		t.expect(Events.funnelStep("PhoneOpened").step).toBe(9)
		t.expect(Events.funnelStep("FirstUpgrade").step).toBe(10)
		t.expect(Events.funnelStep("FirstRank").step).toBe(11)
		t.expect(Events.funnelStep("Day2Return").step).toBe(#Events.Funnel)
		t.expect(Events.funnelStep("FirstDailyCrate")).toBe(nil) -- a custom event, not in order
		-- every cold open step id maps onto an onboarding step
		for _, name in Events.ColdOpenSteps do
			t.expect(Events.funnelStep(name) ~= nil).toBe(true)
		end
	end)

	t.test("recurring funnel steps are numbered by their list position", function()
		local steps = { "Offered", "Accepted", "Seated" }
		t.expect(Events.stepOf(steps, "Offered")).toBe(1)
		t.expect(Events.stepOf(steps, "Seated")).toBe(3)
		t.expect(Events.stepOf(steps, "Nope")).toBe(nil)
		t.expect(Events.stepOf(nil, "Offered")).toBe(nil)
	end)

	t.test("the session tracker lets each key through once", function()
		local tr = Events.newTracker()
		t.expect(Events.first(tr, "Funnel:Joined")).toBe(true)
		t.expect(Events.first(tr, "Funnel:Joined")).toBe(false)
		t.expect(Events.first(tr, "Call:abc:O1:2")).toBe(true)
		t.expect(Events.first(tr, "Call:abc:O2:2")).toBe(true)
	end)

	t.test("custom events clip their three fields and default to a counter", function()
		local e = Events.custom("DailyCrate", nil, "Daily", string.rep("x", 200), "3")
		t.expect(e.name).toBe("DailyCrate")
		t.expect(e.value).toBe(1)
		t.expect(e.fields.CustomField01).toBe("Daily")
		t.expect(#e.fields.CustomField02).toBe(Events.MAX_FIELD)
		t.expect(e.fields.CustomField03).toBe("3")
		t.expect(e.fields.CustomField04).toBe(nil)
		t.expect(Events.custom("LiveEvent", 2.5).value).toBe(2.5)
		t.expect(Events.custom("LiveEvent", 0 / 0).value).toBe(1)
	end)

	t.test("the client bucket allows a burst, then one per refill", function()
		local b = Events.newBucket(0)
		for _ = 1, Events.CLIENT_BURST do
			t.expect(Events.allow(b, 0)).toBe(true)
		end
		t.expect(Events.allow(b, 0)).toBe(false)
		t.expect(Events.allow(b, Events.CLIENT_REFILL)).toBe(true)
		t.expect(Events.allow(b, Events.CLIENT_REFILL)).toBe(false)
		t.expect(Events.allow(b, 1000)).toBe(true) -- refills, capped at the burst
		t.expect(b.tokens <= Events.CLIENT_BURST).toBe(true)
	end)

	t.test("a shop visit starts at PhoneOpened, on the first step, or after going idle", function()
		t.expect(Events.shopFresh(nil, 3, 10)).toBe(true)
		t.expect(Events.shopFresh(5, 1, 10)).toBe(true)
		t.expect(Events.shopFresh(5, 3, 10)).toBe(false)
		t.expect(Events.shopFresh(5, 5, 5 + Events.SHOP_IDLE + 1)).toBe(true)
	end)

	t.test("client shop items must be known config keys", function()
		local known = { RIB = true, Engine = true, QuickLaunch = true }
		t.expect(Events.knownItem("RIB", known)).toBe(true)
		t.expect(Events.knownItem("RIB:Engine", known)).toBe(true)
		t.expect(Events.knownItem("QuickLaunch", known)).toBe(true)
		t.expect(Events.knownItem("RIB:Hull", known)).toBe(false)
		t.expect(Events.knownItem("RIB:Engine:RIB", known)).toBe(false)
		t.expect(Events.knownItem("", known)).toBe(false)
		t.expect(Events.knownItem(5, known)).toBe(false)
		t.expect(Events.knownItem(string.rep("RIB:", 30), known)).toBe(false)
		t.expect(Events.Devices.Touch).toBe(true)
		t.expect(Events.Devices.Toaster).toBe(nil)
	end)

	t.test("Day2Return only fires on a later UTC day with a previous session", function()
		t.expect(Events.utcDay(0)).toBe(0)
		t.expect(Events.utcDay(86400 * 3 + 10)).toBe(3)
		t.expect(Events.day2Return(2, 3)).toBe(true)
		t.expect(Events.day2Return(2, 2)).toBe(false)
		t.expect(Events.day2Return(3, 2)).toBe(false)
		t.expect(Events.day2Return(nil, 3)).toBe(false)
		t.expect(Events.day2Return("2", 3)).toBe(false)
	end)

	t.test("session buckets cover day N, the gap and the session length", function()
		t.expect(Events.dayBucket(0)).toBe("D0")
		t.expect(Events.dayBucket(1)).toBe("D1")
		t.expect(Events.dayBucket(3)).toBe("D2-3")
		t.expect(Events.dayBucket(7)).toBe("D4-7")
		t.expect(Events.dayBucket(30)).toBe("D15-30")
		t.expect(Events.dayBucket(400)).toBe("D31+")
		t.expect(Events.gapBucket(nil)).toBe("New")
		t.expect(Events.gapBucket(0)).toBe("Same")
		t.expect(Events.gapBucket(1)).toBe("1d")
		t.expect(Events.gapBucket(9)).toBe("8d+")
		t.expect(Events.lengthBucket(30)).toBe("<1m")
		t.expect(Events.lengthBucket(60)).toBe("1-5m")
		t.expect(Events.lengthBucket(599)).toBe("5-10m")
		t.expect(Events.lengthBucket(9999)).toBe("60m+")
	end)

	t.test("Cash sources map to Roblox transaction types with low-cardinality SKUs", function()
		local tx, sku = Events.cashSource("Purchase:CrewPayroll")
		t.expect(tx).toBe("IAP")
		t.expect(sku).toBe("CrewPayroll")
		tx, sku = Events.cashSource("Op:PersonInWater")
		t.expect(tx).toBe("Gameplay")
		t.expect(sku).toBe("Op:PersonInWater")
		tx, sku = Events.cashSource("Streak:Day3")
		t.expect(tx).toBe("TimedReward")
		t.expect(sku).toBe("Streak:Day3")
		t.expect(select(2, Events.cashSource("Streak:Day45"))).toBe("Streak:Day8+")
		t.expect(select(2, Events.cashSource("Streak:Welcome"))).toBe("Streak:Welcome")
		t.expect((Events.cashSource("Group:Crew"))).toBe("TimedReward")
		tx, sku = Events.cashSource(nil)
		t.expect(tx).toBe("Gameplay")
		t.expect(sku).toBe("Unknown")
		t.expect(#select(2, Events.cashSource("Op:" .. string.rep("x", 200))) <= Events.MAX_FIELD)
			.toBe(true)
		tx, sku = Events.cashSink("Upgrade", "RIB:Engine")
		t.expect(tx).toBe("Shop")
		t.expect(sku).toBe("Upgrade:RIB:Engine")
	end)

	t.test("economy amounts are whole and positive", function()
		t.expect(Events.amount(149.6)).toBe(150)
		t.expect(Events.amount(0)).toBe(nil)
		t.expect(Events.amount(-20)).toBe(nil)
		t.expect(Events.amount(0 / 0)).toBe(nil)
		t.expect(Events.amount("12")).toBe(nil)
	end)

	t.test("finish reasons map to call results", function()
		t.expect(Events.callResult("Complete")).toBe("Delivered")
		t.expect(Events.callResult("Timer")).toBe("Timer")
		t.expect(Events.callResult("LeftCraft")).toBe("Abandoned")
		t.expect(Events.callContext(true, true, true)).toBe("ColdOpen")
		t.expect(Events.callContext(false, true, true)).toBe("Big")
		t.expect(Events.callContext(false, false, true)).toBe("Storm")
		t.expect(Events.callContext(false, false, false)).toBe("Calm")
	end)

	t.test("a delivered call sends CallEnded and OpGrade, and counts as delivered", function()
		local out =
			Events.opEvents(facts({ grade = "Silver", storm = true, rarity = "Rare", saved = 3 }))
		t.expect(#out).toBe(2)
		t.expect(out[1].name).toBe("CallEnded")
		t.expect(out[1].value).toBe(3)
		t.expect(out[1].fields.CustomField01).toBe("PersonInWater")
		t.expect(out[1].fields.CustomField02).toBe("Delivered")
		t.expect(out[1].fields.CustomField03).toBe("Storm")
		t.expect(out[2].name).toBe("OpGrade")
		t.expect(out[2].value).toBe(2)
		t.expect(out[2].fields.CustomField02).toBe("Silver")
		t.expect(out[2].fields.CustomField03).toBe("Rare")
		t.expect(Events.delivered(facts())).toBe(true)
		t.expect(Events.countsAsFirstOp(facts())).toBe(true)
	end)

	t.test("timeouts and bystanders", function()
		-- someone on the call who never helped: only CallEnded
		local out = Events.opEvents(facts({ reason = "Timer", helped = false }))
		t.expect(#out).toBe(1)
		t.expect(out[1].fields.CustomField02).toBe("Timer")
		t.expect(Events.delivered(facts({ reason = "Timer" }))).toBe(false)
		t.expect(Events.delivered(facts({ helped = false }))).toBe(false)
		local noSaved = facts()
		noSaved.saved = nil
		t.expect(Events.opEvents(noSaved)[1].value).toBe(0)
	end)

	t.test("the cold open is delivered but never the first station call", function()
		local out = Events.opEvents(facts({ coldOpen = true }))
		t.expect(out[1].fields.CustomField03).toBe("ColdOpen")
		t.expect(Events.delivered(facts({ coldOpen = true }))).toBe(true)
		t.expect(Events.countsAsFirstOp(facts({ coldOpen = true }))).toBe(false)
		local noRarity = facts()
		noRarity.rarity = nil
		t.expect(Events.opEvents(noRarity)[2].fields.CustomField03).toBe("None")
	end)

	t.test("StormJoined carries the storm type and whether the player arrived mid-storm", function()
		local e = Events.stormJoined(true, false)
		t.expect(e.name).toBe("StormJoined")
		t.expect(e.fields.CustomField01).toBe("Great")
		t.expect(e.fields.CustomField02).toBe("Start")
		t.expect(Events.stormJoined(false, true).fields.CustomField02).toBe("MidStorm")
		t.expect(Events.stormKey(7)).toBe("Storm:7")
	end)
end
