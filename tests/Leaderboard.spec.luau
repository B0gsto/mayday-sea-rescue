-- Leaderboard: week numbering, store names, rescue credit, batching and the station board's rows.
return function(t)
	local BadgeConfig = t.require("Config/BadgeConfig")
	local L = t.require("LeaderboardRules")

	t.test("weeks start Monday 00:00 UTC", function()
		local monday = 1760918400 -- 2025-10-20 00:00:00 UTC, a Monday
		t.expect(L.weekIndex(monday)).toBe(L.weekIndex(monday - 1) + 1)
		t.expect(L.weekIndex(monday + 7 * 86400 - 1)).toBe(L.weekIndex(monday))
		t.expect(L.secondsToReset(monday)).toBe(7 * 86400)
		t.expect(L.secondsToReset(monday - 1)).toBe(1)
		t.expect(L.weekIndex(4 * 86400)).toBe(0) -- Monday 1970-01-05
	end)

	t.test("weekly boards get a store per week, all-time boards one store", function()
		local names = {}
		for _, b in BadgeConfig.Boards do
			local a, c = L.storeName(b, 2911), L.storeName(b, 2912)
			t.expect(#a <= 50).toBe(true)
			t.expect(a == c).toBe(not b.weekly)
			t.expect(names[a]).toBeNil()
			names[a] = true
		end
		t.expect(L.storeName(BadgeConfig.Boards[1], 7)).toBe("Lb1_Rescued_W7")
	end)

	t.test("credit counts rescues only, for helpers, storms on their own board", function()
		t.expect(L.credit(3, false, true)).toEqual({ Rescued = 3, RescuedAllTime = 3 })
		t.expect(L.credit(2, true, true))
			.toEqual({ Rescued = 2, RescuedAllTime = 2, StormRescued = 2 })
		t.expect(next(L.credit(2, true, false))).toBeNil()
		t.expect(next(L.credit(0, true, true))).toBeNil()
		for _, b in BadgeConfig.Boards do
			t.expect(b.key == "Rescued" or b.key == "StormRescued" or b.key == "RescuedAllTime")
				.toBe(true)
		end
	end)

	t.test("merge batches pending increments", function()
		local p = {}
		L.merge(p, { Rescued = 1, RescuedAllTime = 1 })
		L.merge(p, { Rescued = 2, StormRescued = 2 })
		t.expect(p).toEqual({ Rescued = 3, RescuedAllTime = 1, StormRescued = 2 })
	end)

	t.test("rows pad to the board size and format numbers", function()
		local rows = L.rows(
			{ { userId = 1, value = 12345 }, { userId = 2, value = 7 } },
			{ [1] = "Aggie" },
			4
		)
		t.expect(#rows).toBe(4)
		t.expect(rows[1]).toEqual({ place = "1.", name = "Aggie", value = "12,345" })
		t.expect(rows[2].name).toBe("Crew member")
		t.expect(rows[4]).toEqual({ place = "4.", name = "", value = "" })
		t.expect(L.thousands(999)).toBe("999")
		t.expect(L.thousands(1000000)).toBe("1,000,000")
	end)

	t.test("reset text counts days, then hours", function()
		local monday = 1760918400
		t.expect(L.resetText(monday - 3 * 86400)).toBe("Resets in 3 days")
		t.expect(L.resetText(monday - 86400)).toBe("Resets in 1 day")
		t.expect(L.resetText(monday - 5 * 3600)).toBe("Resets in 5 hours")
		t.expect(L.resetText(monday - 60)).toBe("Resets within the hour")
	end)
end
