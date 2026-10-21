-- Streak: the UTC day maths, day 1..7 payouts, forgiveness (calm day, drop back 3, never zero),
-- the welcome-back crate, the day-7 cosmetic flag and the profile flag encoding (docs/15 H5).
return function(t)
	local Rules = t.load("src/shared/StreakRules.luau")
	local Config = t.load("src/shared/Config/StreakConfig.luau")

	local DAY = 86400
	local NOW = 1790000000 -- 2026-09-21, mid-morning UTC
	local TODAY = Rules.dayIndex(NOW)

	t.test("UTC day index and the countdown to the next crate", function()
		t.expect(TODAY).toBe(math.floor(NOW / DAY))
		t.expect(Rules.secondsToDay(NOW)).toBe((TODAY + 1) * DAY - NOW)
		t.expect(Rules.secondsToDay(TODAY * DAY)).toBe(DAY)
	end)

	t.test("the day-1 to day-7 Cash rises", function()
		t.expect(#Config.DayCash).toBe(Config.WeekDays)
		for i = 2, #Config.DayCash do
			t.expect(Config.DayCash[i] > Config.DayCash[i - 1]).toBe(true)
		end
	end)

	t.test("a new player gets day 1, never a welcome-back crate", function()
		local s = Rules.newState()
		t.expect(Rules.available(s, NOW)).toBe(true)
		local p = Rules.preview(s, NOW)
		t.expect(p.streak).toBe(1)
		t.expect(p.cash).toBe(Config.DayCash[1])
		t.expect(p.welcome).toBe(false)
		t.expect(p.calm).toBe(false)

		local claim = Rules.claim(s, NOW)
		t.expect(claim.streak).toBe(1)
		t.expect(claim.day).toBe(TODAY)
		t.expect(claim.state.lastDay).toBe(TODAY)
		t.expect(claim.state.streak).toBe(1)
		t.expect(claim.cosmeticDay).toBeNil()
	end)

	t.test("one crate per UTC day, then day 2 tomorrow", function()
		local first = Rules.claim(Rules.newState(), NOW)
		t.expect(Rules.available(first.state, NOW)).toBe(false)
		t.expect(Rules.claim(first.state, NOW)).toBeNil()
		t.expect(Rules.preview(first.state, NOW)).toBeNil()

		local tomorrow = Rules.claim(first.state, NOW + DAY)
		t.expect(tomorrow.streak).toBe(2)
		t.expect(tomorrow.cash).toBe(Config.DayCash[2])
		t.expect(tomorrow.calm).toBe(false)
	end)

	t.test("one missed day is free (a calm day), the streak keeps climbing", function()
		local s = { lastDay = TODAY - 2, streak = 3, cosmeticDay = 0 }
		local p = Rules.preview(s, NOW)
		t.expect(p.calm).toBe(true)
		t.expect(p.welcome).toBe(false)
		t.expect(p.streak).toBe(4)
		t.expect(p.cash).toBe(Config.DayCash[4])
		t.expect(Rules.claim(s, NOW).state.streak).toBe(4)
	end)

	t.test("a longer break drops the streak back 3, never to zero", function()
		local s = { lastDay = TODAY - 3, streak = 5, cosmeticDay = 0 } -- 2 missed days
		local p = Rules.preview(s, NOW)
		t.expect(p.streak).toBe(2)
		t.expect(p.calm).toBe(false)
		t.expect(p.welcome).toBe(false)

		local low = Rules.preview({ lastDay = TODAY - 8, streak = 2, cosmeticDay = 0 }, NOW)
		t.expect(low.streak).toBe(1)
		t.expect(low.welcome).toBe(true)
	end)

	t.test("away more than 3 days: one bigger welcome-back crate", function()
		local s = { lastDay = TODAY - 4, streak = 5, cosmeticDay = 0 }
		local p = Rules.preview(s, NOW)
		t.expect(p.welcome).toBe(true)
		t.expect(p.streak).toBe(2)
		t.expect(p.cash).toBe(Config.DayCash[2] + Config.WelcomeCash)
		local claim = Rules.claim(s, NOW)
		t.expect(claim.welcome).toBe(true)
		-- the next day is an ordinary crate again
		t.expect(Rules.preview(claim.state, NOW + DAY).welcome).toBe(false)
	end)

	t.test(
		"day 7 pays the top Cash and grants the weekly cosmetic flag, then wraps to day 1",
		function()
			local s = { lastDay = TODAY - 1, streak = 6, cosmeticDay = 0 }
			local claim = Rules.claim(s, NOW)
			t.expect(claim.streak).toBe(7)
			t.expect(claim.cash).toBe(Config.DayCash[7])
			t.expect(claim.cosmeticDay).toBe(TODAY)
			t.expect(claim.state.cosmeticDay).toBe(TODAY)

			local nextClaim = Rules.claim(claim.state, NOW + DAY)
			t.expect(nextClaim.streak).toBe(1)
			t.expect(nextClaim.cosmeticDay).toBeNil()
			t.expect(nextClaim.state.cosmeticDay).toBe(TODAY)
		end
	)

	t.test("the flag table round-trips and accepts corrupt saves", function()
		local s = { lastDay = 12345, streak = 4, cosmeticDay = 12340 }
		t.expect(Rules.fromFlagTable(Rules.flagTable(s))).toEqual(s)
		t.expect(Rules.fromFlagTable(nil)).toEqual(Rules.newState())
		t.expect(Rules.fromFlagTable({ d = "x", s = 42, c = -3 })).toEqual({
			lastDay = 0,
			streak = Config.WeekDays,
			cosmeticDay = 0,
		})
		t.expect(Rules.fromFlagTable({ d = 99.7, s = -1, c = 3.2 })).toEqual({
			lastDay = 99,
			streak = 0,
			cosmeticDay = 3,
		})
	end)
end
