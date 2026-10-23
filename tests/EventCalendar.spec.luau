-- EventCalendar: the one "what's coming" list (docs/15 section 2): the Great Storm and Ghost Light
-- clocks, the Ghost Ship window, the daily crate and the strongbox,
-- soonest first, icons + numbers only (no prices).
return function(t)
	local Calendar = t.load("src/shared/EventCalendar.luau")
	local EventClock = t.load("src/shared/EventClock.luau")
	local StreakRules = t.load("src/shared/StreakRules.luau")

	local BASE = 1789948800 -- 2026-09-21 00:00:00 UTC
	local HOUR = 3600
	local function at(h, m, s)
		return BASE + h * HOUR + (m or 0) * 60 + (s or 0)
	end
	local function row(rows, id)
		for _, r in rows do
			if r.id == id then
				return r
			end
		end
		return nil
	end
	local function keys(rows)
		local out = {}
		for _, r in rows do
			if r.kind == "now" then
				table.insert(out, 0)
			elseif r.seconds ~= nil then
				table.insert(out, r.seconds)
			else
				table.insert(out, (r.days or 0) * 86400)
			end
		end
		return out
	end

	t.test("the Great Storm counts to the next :00 in 0:42:10 style", function()
		local rows = Calendar.rows(at(9, 17, 50))
		local storm = row(rows, "GreatStorm")
		t.expect(storm.kind).toBe("clock")
		t.expect(storm.seconds).toBe(2530)
		t.expect((Calendar.text(storm))).toBe("0:42:10")
		t.expect((Calendar.text(Calendar.rows(at(8, 59))[1]))).toBe("0:01:00")
	end)

	t.test("the Great Storm pulses NOW while it runs", function()
		local storm = row(Calendar.rows(at(9, 1)), "GreatStorm")
		t.expect(storm.kind).toBe("now")
		t.expect(storm.seconds).toBeNil()
		t.expect((Calendar.text(storm))).toBe("NOW")
		t.expect(EventClock.isActive("GreatStorm", at(9, 1))).toBe(true)
	end)

	t.test("stormOff (always sunny) leaves the Great Storm out", function()
		t.expect(row(Calendar.rows(at(9, 1), { stormOff = true }), "GreatStorm")).toBeNil()
		t.expect(row(Calendar.rows(at(9, 1), { stormOff = true }), "GhostLight").id)
			.toBe("GhostLight")
	end)

	t.test("the Ghost Light counts to the next 3-hourly :30", function()
		local nextLight = row(Calendar.rows(at(9, 17, 50)), "GhostLight")
		t.expect(nextLight.seconds).toBe(12 * 60 + 10) -- 9:30
		t.expect((Calendar.text(nextLight))).toBe("12:10")
		local active = row(Calendar.rows(at(9, 31)), "GhostLight")
		t.expect(active.seconds).toBe(2 * HOUR + 59 * 60) -- 12:30, still counting during the event
		t.expect((Calendar.text(active))).toBe("2:59:00")
	end)

	t.test("the Ghost Ship appears a week out, then shows days and the witching clock", function()
		local START = 1792800000 -- 2026-10-24 00:00 UTC
		local before = row(Calendar.rows(START - 8 * 86400), "Halloween")
		t.expect(before).toBeNil()
		local near = row(Calendar.rows(START - 2 * 86400), "Halloween")
		t.expect(near.days).toBe(2)
		t.expect(near.seconds).toBeNil()
		t.expect((Calendar.text(near))).toBe("2d")

		local live = row(Calendar.rows(START + 86400 + 12 * HOUR + 20 * 60), "Halloween")
		t.expect(live.days).toBe(9)
		t.expect(live.seconds).toBe(25 * 60) -- the :45 witching hour
		local main, sub = Calendar.text(live)
		t.expect(main).toBe("9d")
		t.expect(sub).toBe("25:00")

		local witching = row(Calendar.rows(START + 86400 + 12 * HOUR + 50 * 60), "Halloween")
		t.expect(witching.seconds).toBe(0)
	end)

	t.test("the daily crate counts down, then reads ready for that player", function()
		local now = at(9, 17, 50)
		local waiting = row(Calendar.rows(now, { streak = { available = false } }), "Crate")
		t.expect(waiting.kind).toBe("clock")
		t.expect(waiting.seconds).toBe(StreakRules.secondsToDay(now))
		local ready = row(Calendar.rows(now, { streak = { available = true } }), "Crate")
		t.expect(ready.kind).toBe("now")
		t.expect(ready.ready).toBe(true)
		t.expect((Calendar.text(ready))).toBe("✓")
	end)

	t.test("the strongbox shows fill and time to full from IdleIncome", function()
		local now = at(9, 17, 50)
		local station = { cash = 500, level = 0, radio = 0, kennel = 0 }
		local box = row(Calendar.rows(now, { station = station }), "Strongbox")
		t.expect(box.kind).toBe("percent")
		t.expect(math.abs(box.fraction - 0.5) < 1e-9).toBe(true)
		t.expect(box.seconds).toBe(1800) -- 500 Cash at 1,000/h to a 1,000 cap
		local main, sub = Calendar.text(box)
		t.expect(main).toBe("50%")
		t.expect(sub).toBe("30:00")
		local full = row(Calendar.rows(now, { station = { cash = 1000, level = 0 } }), "Strongbox")
		t.expect((Calendar.text(full))).toBe("100%")
	end)

	t.test("rows are soonest first and carry no price", function()
		local rows = Calendar.rows(at(9, 17, 50), { station = { cash = 1, level = 0 } })
		local list = keys(rows)
		for i = 2, #list do
			t.expect(list[i] >= list[i - 1]).toBe(true)
		end
		t.expect(rows[1].id).toBe("GhostLight") -- 12:10 is the closest
		for _, r in rows do
			t.expect(r.price).toBeNil()
			t.expect(r.robux).toBeNil()
			t.expect(type(r.label)).toBe("string")
			t.expect(#string.split(r.label, " ") <= 3).toBe(true)
		end
	end)
end
