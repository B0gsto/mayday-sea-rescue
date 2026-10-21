-- Seasonal: the Halloween "Ghost Ship" window (UTC dates), Candy Lanterns, the pumpkin stall and the
-- profile flag encoding (docs/15 H7). Every reward is earnable; nothing costs Robux.
return function(t)
	local Rules = t.load("src/shared/SeasonalRules.luau")
	local Config = t.load("src/shared/Config/SeasonalEvents.luau")
	local Clock = t.load("src/shared/EventClock.luau")

	local EVENT = Config.Halloween
	local START = EVENT.startUtc
	local END = EVENT.endUtc
	local WINTER = Config.Winter
	local WSTART = WINTER.startUtc
	local WEND = WINTER.endUtc

	t.test("the window runs 2026-10-24 00:00 UTC to 2026-11-02 23:59:59 UTC", function()
		t.expect(START).toBe(1792800000)
		t.expect(END).toBe(1793663999)
		t.expect(Rules.live(EVENT, START - 1)).toBe(false)
		t.expect(Rules.live(EVENT, START)).toBe(true)
		t.expect(Rules.live(EVENT, END)).toBe(true)
		t.expect(Rules.live(EVENT, END + 1)).toBe(false)
	end)

	t.test("a Studio dev attribute forces the event outside its dates", function()
		t.expect(Rules.live(EVENT, START - 86400, true)).toBe(true)
		t.expect(Rules.live(EVENT, END + 86400, true)).toBe(true)
		t.expect(Rules.live(EVENT, END + 86400, false)).toBe(false)
	end)

	t.test("Frost Fleet activates on its dates and when dev-forced", function()
		-- the store-art path: Winter forced months before its window
		t.expect(Rules.live(WINTER, 1767225600, true)).toBe(true) -- 2026-01-01, no window
		t.expect(Rules.live(WINTER, 1767225600, false)).toBe(false)
		t.expect(Rules.live(WINTER, WSTART - 1, true)).toBe(true)
		t.expect(Rules.live(WINTER, WEND + 1, true)).toBe(true)
		-- and the live window alone is enough, no force needed
		t.expect(Rules.live(WINTER, WSTART, false)).toBe(true)
		t.expect(Rules.live(WINTER, WEND, false)).toBe(true)
	end)

	t.test("night runs only in the witching hour or during a Ghost Ship call", function()
		t.expect(EVENT.night.witchingMinute).toBe(45)
		t.expect(EVENT.night.witchingMinutes).toBe(15)
		local hour = START + 3 * 3600 -- 03:00 UTC
		t.expect(Rules.witching(EVENT, hour + 44 * 60)).toBe(false)
		t.expect(Rules.witching(EVENT, hour + 45 * 60)).toBe(true)
		t.expect(Rules.witching(EVENT, hour + 59 * 60)).toBe(true)
		t.expect(Rules.witching(EVENT, hour + 60 * 60)).toBe(false)
		t.expect(Rules.night(EVENT, hour + 44 * 60, false, false)).toBe(false)
		t.expect(Rules.night(EVENT, hour + 45 * 60, false, false)).toBe(true)
		t.expect(Rules.night(EVENT, hour + 10 * 60, true, false)).toBe(true)
		-- onboarding players never get the forced night
		t.expect(Rules.night(EVENT, hour + 45 * 60, false, true)).toBe(false)
		t.expect(Rules.night(EVENT, hour + 10 * 60, true, true)).toBe(false)
	end)

	t.test("the stall clock counts whole days left, 10 down to 1", function()
		t.expect(Rules.daysLeft(EVENT, START)).toBe(10)
		t.expect(Rules.daysLeft(EVENT, START + 86400)).toBe(9)
		t.expect(Rules.daysLeft(EVENT, END)).toBe(1)
		t.expect(Rules.daysLeft(EVENT, END + 1)).toBe(0)
	end)

	t.test("the window uses EventClock's inclusive season maths", function()
		local season = { id = EVENT.id, startAt = START, endsAt = END }
		t.expect(Clock.inSeason(season, START)).toBe(true)
		t.expect(Clock.inSeason(season, END)).toBe(true)
		t.expect(Clock.inSeason(season, START - 1)).toBe(false)
		t.expect(Clock.seasonEndsIn(season, START)).toBe(END - START)
		t.expect(Clock.seasonEndsIn(season, END + 10)).toBe(0)
	end)

	t.test("rescues pay Candy Lanterns, the Ghost Ship call pays more", function()
		t.expect(Rules.candyFor(EVENT, true)).toBe(5)
		t.expect(Rules.candyFor(EVENT, false)).toBe(1)
		local state = Rules.newState()
		t.expect(state.candy).toBe(0)
		state = Rules.reward(state, Rules.candyFor(EVENT, true))
		t.expect(state.candy).toBe(5)
		state = Rules.reward(state, Rules.candyFor(EVENT, false))
		t.expect(state.candy).toBe(6)
		t.expect(Rules.reward(state, -50).candy).toBe(6)
		t.expect(Rules.reward({ candy = Rules.MAX_CANDY, owned = {} }, 5).candy)
			.toBe(Rules.MAX_CANDY)
	end)

	t.test("every stall item is earned with candy, never Robux", function()
		t.expect(#EVENT.items).toBe(3)
		local ids = {}
		for _, item in EVENT.items do
			t.expect(ids[item.id]).toBeNil()
			ids[item.id] = true
			t.expect(item.price > 0).toBe(true)
			t.expect(item.flag).toBeTruthy()
			t.expect((item :: any).robux).toBeNil()
		end
	end)

	t.test("a purchase costs candy once and needs the full price", function()
		local item = EVENT.items[1]
		local poor = Rules.newState()
		local ok, reason = Rules.buy(EVENT, poor, item.id)
		t.expect(ok).toBeNil()
		t.expect(reason).toBe("Need candy")

		local rich = Rules.reward(Rules.newState(), item.price)
		local after, why = Rules.buy(EVENT, rich, item.id)
		t.expect(why).toBeNil()
		t.expect(after.candy).toBe(0)
		t.expect(after.owned[item.flag]).toBe(true)
		t.expect(rich.owned[item.flag]).toBeNil() -- the input is not mutated

		local again, ownedReason = Rules.buy(EVENT, after :: any, item.id)
		t.expect(again).toBeNil()
		t.expect(ownedReason).toBe("Owned")
		t.expect(Rules.buy(EVENT, rich, "Nope")).toBeNil()
	end)

	t.test("Frost Fleet runs 2026-12-12 00:00 UTC to 2027-01-04 23:59:59 UTC", function()
		t.expect(WSTART).toBe(1797033600)
		t.expect(WEND).toBe(1799107199)
		t.expect(Rules.live(WINTER, WSTART - 1)).toBe(false)
		t.expect(Rules.live(WINTER, WSTART)).toBe(true)
		t.expect(Rules.live(WINTER, WEND)).toBe(true)
		t.expect(Rules.live(WINTER, WEND + 1)).toBe(false)
		t.expect(Rules.daysLeft(WINTER, WSTART)).toBe(24)
		t.expect(WINTER.currency).toBe("Snowflakes")
		t.expect(WINTER.currencyFlag).toBe("winter")
		t.expect(WINTER.callVariant).toBe("FrostFleet")
		t.expect(WINTER.night).toBeNil()
		t.expect(WINTER.snow).toBe(true)
		t.expect(WINTER.tree).toBeTruthy()
		t.expect(#WINTER.lightRuns).toBe(2)
	end)

	t.test("Frost Fleet rescues pay Snowflakes and its stall is free to earn", function()
		t.expect(Rules.candyFor(WINTER, true)).toBe(5)
		t.expect(Rules.candyFor(WINTER, false)).toBe(1)
		t.expect(#WINTER.items).toBe(3)
		local flags = {}
		for _, item in WINTER.items do
			t.expect(flags[item.flag]).toBeNil()
			flags[item.flag] = true
			t.expect(item.price > 0).toBe(true)
			t.expect((item :: any).robux).toBeNil()
		end
		t.expect(flags.livery).toBe(true)
		t.expect(flags.scarf).toBe(true)
		t.expect(flags.decor).toBe(true)
	end)

	t.test("the winter flag round-trips with its own event and stays separate", function()
		local state = Rules.reward(Rules.newState(), 20)
		state.owned.livery = true
		state.owned.scarf = true
		local back = Rules.fromFlag(Rules.flagTable(state), WINTER)
		t.expect(back.candy).toBe(20)
		t.expect(back.owned.livery).toBe(true)
		t.expect(back.owned.scarf).toBe(true)
		-- the default stays the Halloween shape: a scarf is not a Halloween item
		t.expect(Rules.fromFlag({ candy = 1, scarf = true }).owned.scarf).toBeNil()
		t.expect(Rules.fromFlag({ candy = 1, scarf = true }, WINTER).owned.scarf).toBe(true)
	end)

	t.test("the flag round-trips candy and owned cosmetics, and ignores junk", function()
		local state = Rules.reward(Rules.newState(), 27)
		for _, item in EVENT.items do
			state.owned[item.flag] = true
		end
		local back = Rules.fromFlag(Rules.flagTable(state))
		t.expect(back.candy).toBe(27)
		for _, item in EVENT.items do
			t.expect(back.owned[item.flag]).toBe(true)
		end
		t.expect(Rules.fromFlag(nil).candy).toBe(0)
		t.expect(Rules.fromFlag({ candy = "lots" }).candy).toBe(0)
		t.expect(Rules.fromFlag({ candy = -4 }).candy).toBe(0)
		t.expect(Rules.fromFlag({ candy = 1e9 }).candy).toBe(Rules.MAX_CANDY)
		t.expect(Rules.fromFlag({ candy = 3.9, livery = "yes" }).owned.livery).toBeNil()
	end)
end
