-- EventCalendar: the one "what's coming" list (docs/15 section 2): Season 1, the Chandlery restock, the daily crate and the strongbox,
-- soonest first, icons + numbers only (no prices).
return function(t)
	local Calendar = t.load("src/shared/EventCalendar.luau")
	local SeasonRules = t.load("src/shared/SeasonRules.luau")
	local StockRotation = t.load("src/shared/StockRotation.luau")
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

	t.test("Season 1 shows its days left from SeasonRules", function()
		local now = at(9, 17, 50)
		local season = row(Calendar.rows(now), "Season")
		t.expect(season.kind).toBe("days")
		t.expect(season.days).toBe(SeasonRules.daysLeft(now))
	end)

	t.test("the Chandlery restock uses the shared 10-minute clock", function()
		local now = at(9, 17, 50)
		local bell = row(Calendar.rows(now), "Restock")
		t.expect(bell.seconds).toBe(StockRotation.secondsToRestock(now))
		t.expect((Calendar.text(bell))).toBe("2:10")
		local fresh = row(Calendar.rows(BASE), "Restock")
		t.expect((Calendar.text(fresh))).toBe("10:00")
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
		t.expect(rows[1].id).toBe("Restock") -- 2:10 is the closest
		for _, r in rows do
			t.expect(r.price).toBeNil()
			t.expect(r.robux).toBeNil()
			t.expect(type(r.label)).toBe("string")
			t.expect(#string.split(r.label, " ") <= 3).toBe(true)
		end
	end)
end
