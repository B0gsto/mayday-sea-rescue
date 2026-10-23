-- NotifyDue: the "come back" timing (G49). UTC crate due times, the entry round trip,
-- which message wins and the one-per-24 h cap the sender and the game agree on.
return function(t)
	local Notify = t.load("src/shared/NotifyDue.luau")
	local Rules = t.load("src/shared/StreakRules.luau")

	local DAY = 86400
	local NOW = 1790000000 -- 2026-09-21, mid-morning UTC
	local TODAY = Rules.dayIndex(NOW)

	t.test(
		"an unclaimed crate is ready now; a claimed one waits for the next UTC midnight",
		function()
			t.expect(Notify.nextCrateAt(nil, NOW)).toBe(NOW)
			local claimed = Rules.claim(Rules.newState(), NOW)
			t.expect(Notify.nextCrateAt(Rules.flagTable(claimed.state), NOW))
				.toBe((TODAY + 1) * DAY)
		end
	)

	t.test("an entry keeps the previous last-notified time and floors the times", function()
		local claimed = Rules.claim(Rules.newState(), NOW)
		local e = Notify.entry(Rules.flagTable(claimed.state), NOW + 0.9, 1234.8)
		t.expect(e.c).toBe((TODAY + 1) * DAY)
		t.expect(e.l).toBe(1234)
		t.expect(Notify.entry(nil, NOW, nil).l).toBe(0)
	end)

	t.test("only a ready crate is due", function()
		t.expect(Notify.kindFor({ c = NOW, l = 0 }, NOW)).toBe("crate_ready")
		t.expect(Notify.kindFor({ c = NOW + 1, l = 0 }, NOW)).toBeNil()
	end)

	t.test("one send per player per 24 h, and a future clock never sends", function()
		t.expect(Notify.canSend({ c = NOW, l = 0 }, NOW)).toBe(true)
		t.expect(Notify.canSend({ c = NOW, l = NOW - DAY }, NOW)).toBe(true)
		t.expect(Notify.canSend({ c = NOW, l = NOW - DAY + 1 }, NOW)).toBe(false)
		t.expect(Notify.canSend({ c = NOW + 60, l = 0 }, NOW)).toBe(false)
		t.expect(Notify.canSend({ c = NOW, l = NOW + 60 }, NOW)).toBe(false)
	end)
end
