-- LiveOps: message rules (known events, nonce, 3 h / 7 day bounds), the pending/active window,
-- the multiplier caps and the duplicate/old-schedule rule (docs/15 section 1; marketing/liveops.md).
return function(t)
	local L = t.load("src/shared/LiveOps.luau")

	local NOW = 1792800000 -- 2026-10-24 00:00:00 UTC
	local HOUR = 3600
	local function message(event, startsAt, duration, nonce)
		return { event = event, startsAt = startsAt, duration = duration, nonce = nonce or "n1" }
	end
	local function ok(msg, now)
		return (L.validate(msg, now or NOW))
	end

	t.test("all four events exist with a label, a tint and a sane default length", function()
		t.expect(#L.Order).toBe(4)
		for _, id in L.Order do
			local def = L.Events[id]
			t.expect(def.id).toBe(id)
			t.expect(#def.label > 0).toBe(true)
			t.expect(def.duration >= L.MinDuration and def.duration <= L.MaxDuration).toBe(true)
			t.expect(def.tint.R > 0).toBe(true)
		end
		t.expect(L.Events.GoldenHour.label).toBe("Golden hour")
		t.expect(L.Events.LegendaryRush.label).toBe("Legendary rush")
	end)

	t.test("a valid message needs a known event, a nonce and 1 min to 3 h", function()
		t.expect(ok(message("GoldenHour", NOW + HOUR, 3600))).toBe(true)
		t.expect(ok(message("GoldenHour", NOW, 60))).toBe(true)
		t.expect(ok(message("GoldenHour", NOW, 3 * HOUR))).toBe(true)

		t.expect(ok(message("Nope", NOW, 60))).toBe(false)
		t.expect(ok(message("GoldenHour", NOW, 60, ""))).toBe(false)
		t.expect(ok(message("GoldenHour", NOW, 59))).toBe(false)
		t.expect(ok(message("GoldenHour", NOW, 3 * HOUR + 1))).toBe(false)
		t.expect(ok(message("GoldenHour", NOW, 60.5))).toBe(false)
		t.expect(ok(message("GoldenHour", NOW, 0))).toBe(false)
		t.expect(ok(nil)).toBe(false)
	end)

	t.test("7 days ahead at most, and an already finished event is ignored", function()
		t.expect(ok(message("CalmSeas", NOW + 7 * 86400, 3600))).toBe(true)
		t.expect(ok(message("CalmSeas", NOW + 7 * 86400 + 1, 3600))).toBe(false)
		-- a server booting mid-event still adopts it
		t.expect(ok(message("DoubleCandy", NOW - 2 * HOUR, 3 * HOUR))).toBe(true)
		t.expect(ok(message("DoubleCandy", NOW - 3 * HOUR, 3 * HOUR))).toBe(false)
	end)

	t.test("Cancel is a control message and only needs a nonce", function()
		t.expect(ok({ event = "Cancel", nonce = "c1" })).toBe(true)
		t.expect(ok({ event = "Cancel" })).toBe(false)
	end)

	t.test("phase: Pending before the start, Active in the window, Idle after", function()
		local state = L.fromMessage(message("GoldenHour", NOW + 600, 1800))
		t.expect(L.phase(state, NOW)).toBe("Pending")
		t.expect(L.phase(state, NOW + 600)).toBe("Active")
		t.expect(L.phase(state, NOW + 600 + 1799)).toBe("Active")
		t.expect(L.phase(state, NOW + 600 + 1800)).toBe("Idle")
		t.expect(L.phase(L.empty(), NOW)).toBe("Idle")
		t.expect(L.phase(nil, NOW)).toBe("Idle")
		t.expect(L.countdown(state, NOW)).toBe(600)
		t.expect(L.countdown(state, NOW + 900)).toBe(1500)
		t.expect(L.countdown(state, NOW + 5000)).toBeNil()
	end)

	t.test("GoldenHour doubles Cash and Rep; DoubleCandy doubles candy only", function()
		local gold = L.fromMessage(message("GoldenHour", NOW, 3600))
		local m = L.multipliers(gold, NOW + 10)
		t.expect(m.cash).toBe(2)
		t.expect(m.rep).toBe(2)
		t.expect(m.candy).toBe(1)

		local candy = L.fromMessage(message("DoubleCandy", NOW, 3600))
		local c = L.multipliers(candy, NOW + 10)
		t.expect(c.cash).toBe(1)
		t.expect(c.rep).toBe(1)
		t.expect(c.candy).toBe(2)

		for _, id in { "LegendaryRush", "CalmSeas" } do
			local state = L.fromMessage(message(id, NOW, 3600))
			local x = L.multipliers(state, NOW + 10)
			t.expect(x.cash).toBe(1)
			t.expect(x.rep).toBe(1)
			t.expect(x.candy).toBe(1)
		end

		-- pending or over: nothing applies yet, and the caps hold
		t.expect(L.multipliers(gold, NOW - 1).cash).toBe(1)
		t.expect(L.multipliers(gold, NOW + 3600).rep).toBe(1)
		t.expect(L.multipliers(gold, NOW).cash <= L.MaxCash).toBe(true)
		t.expect(L.multipliers(candy, NOW).candy <= L.MaxCandy).toBe(true)
	end)

	t.test("isActive names one event and only while it runs", function()
		local state = L.fromMessage(message("CalmSeas", NOW, 3600))
		t.expect(L.isActive(state, "CalmSeas", NOW)).toBe(true)
		t.expect(L.isActive(state, "CalmSeas", NOW - 1)).toBe(false)
		t.expect(L.isActive(state, "GoldenHour", NOW)).toBe(false)
		t.expect(L.isActive(nil, "CalmSeas", NOW)).toBe(false)
	end)

	t.test("an old schedule never replaces a newer one; Cancel always wins", function()
		local current = L.fromMessage(message("GoldenHour", NOW + HOUR, 3600, "a"))
		local older = message("CalmSeas", NOW + 30 * 60, 3600, "b")
		local newer = message("CalmSeas", NOW + 2 * HOUR, 3600, "c")
		t.expect(L.supersedes(nil, older, NOW)).toBe(true)
		t.expect(L.supersedes(current, older, NOW)).toBe(false)
		t.expect(L.supersedes(current, newer, NOW)).toBe(true)
		t.expect(L.supersedes(current, message("Cancel", 0, 0, "d"), NOW)).toBe(true)
		-- an ended event is idle: the next schedule is accepted whenever it starts
		t.expect(L.supersedes(current, older, NOW + 2 * HOUR)).toBe(true)
	end)

	t.test("the events board shows one LiveOps row: pending clock, then NOW", function()
		local Calendar = t.load("src/shared/EventCalendar.luau")
		local function live(now, startsAt, endsAt)
			for _, row in
				Calendar.rows(now, {
					liveOps = { event = "GoldenHour", startsAt = startsAt, endsAt = endsAt },
				})
			do
				if row.id == "LiveOps" then
					return row
				end
			end
			return nil
		end
		local soon = live(NOW, NOW + 300, NOW + 3900)
		t.expect(soon.kind).toBe("clock")
		t.expect(soon.seconds).toBe(300)
		t.expect(soon.label).toBe("Golden hour")
		t.expect(soon.icon).toBe("spark")
		t.expect(Calendar.text(soon)).toBe("0:05:00")
		t.expect(live(NOW, NOW, NOW + 3600).kind).toBe("now")
		t.expect(live(NOW, NOW + 2 * 86400, NOW + 2 * 86400 + 3600).kind).toBe("days")
		t.expect(live(NOW, NOW - 7200, NOW - 1)).toBeNil()
		t.expect(live(NOW, NOW + 300, NOW + 1200)).toBeTruthy()
	end)
end
