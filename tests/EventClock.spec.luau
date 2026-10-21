-- EventClock: the UTC server-clock events (docs/15 H1): hourly Great Storm at :00 with a
-- two-minute warning, Ghost Light every three hours at :30, phases and countdowns.
return function(t)
	local Clock = t.load("src/shared/EventClock.luau")

	local HOUR = 3600
	local BASE = 1789948800 -- 2026-09-21 00:00:00 UTC
	local function at(h, m, s)
		return BASE + h * HOUR + (m or 0) * 60 + (s or 0)
	end

	t.test("the Great Storm starts every hour at :00 UTC", function()
		t.expect(Clock.startAt("GreatStorm", at(9, 30))).toBe(at(9))
		t.expect(Clock.startAt("GreatStorm", at(9))).toBe(at(9))
		t.expect(Clock.nextStart("GreatStorm", at(9))).toBe(at(10))
		t.expect(Clock.nextStart("GreatStorm", at(9, 30))).toBe(at(10))
	end)

	t.test("the two-minute warning is Before, with the countdown to :00", function()
		t.expect(Clock.phase("GreatStorm", at(8, 57, 59))).toBe("Idle")
		t.expect(Clock.phase("GreatStorm", at(8, 58))).toBe("Before")
		t.expect(Clock.countdown("GreatStorm", at(8, 58))).toBe(120)
		t.expect(Clock.countdown("GreatStorm", at(8, 58, 2))).toBe(118)
		t.expect(Clock.phase("GreatStorm", at(8, 59, 59))).toBe("Before")
		t.expect(Clock.countdown("GreatStorm", at(8, 59, 59))).toBe(1)
	end)

	t.test("the Great Storm is active for four minutes from :00", function()
		t.expect(Clock.phase("GreatStorm", at(9))).toBe("Active")
		t.expect(Clock.countdown("GreatStorm", at(9))).toBe(240)
		t.expect(Clock.isActive("GreatStorm", at(9))).toBe(true)
		t.expect(Clock.isActive("GreatStorm", at(8, 59))).toBe(false) -- Before is not active
		t.expect(Clock.phase("GreatStorm", at(9, 3, 59))).toBe("Active")
		t.expect(Clock.phase("GreatStorm", at(9, 4))).toBe("Idle")
		t.expect(Clock.countdown("GreatStorm", at(9, 4))).toBeNil()
	end)

	t.test("the Ghost Light runs every three hours at :30 for ten minutes", function()
		t.expect(Clock.phase("GhostLight", at(0, 29, 59))).toBe("Idle")
		t.expect(Clock.phase("GhostLight", at(0, 30))).toBe("Active")
		t.expect(Clock.countdown("GhostLight", at(0, 30))).toBe(600)
		t.expect(Clock.phase("GhostLight", at(0, 40))).toBe("Idle")
		t.expect(Clock.phase("GhostLight", at(3, 30))).toBe("Active")
		t.expect(Clock.phase("GhostLight", at(6, 30))).toBe("Active")
		t.expect(Clock.phase("GhostLight", at(1, 30))).toBe("Idle")
		t.expect(Clock.phase("GhostLight", at(2, 30))).toBe("Idle")
		t.expect(Clock.nextStart("GhostLight", at(0, 30))).toBe(at(3, 30))
		t.expect(Clock.startAt("GhostLight", at(2))).toBe(at(0, 30))
	end)

	t.test("current picks the event in its window; the two never overlap", function()
		t.expect(Clock.current(at(8, 59))).toEqual({
			id = "GreatStorm",
			phase = "Before",
			startAt = at(9),
			endsAt = at(9),
		})
		t.expect(Clock.current(at(9, 1))).toEqual({
			id = "GreatStorm",
			phase = "Active",
			startAt = at(9),
			endsAt = at(9, 4),
		})
		t.expect(Clock.current(at(9, 20))).toBeNil()
		t.expect(Clock.current(at(0, 35))).toEqual({
			id = "GhostLight",
			phase = "Active",
			startAt = at(0, 30),
			endsAt = at(0, 40),
		})
		for minute = 0, 24 * 60 - 1 do
			local now = BASE + minute * 60
			local a = Clock.phase("GreatStorm", now)
			local b = Clock.phase("GhostLight", now)
			t.expect(a ~= "Idle" and b ~= "Idle").toBe(false)
		end
	end)

	t.test("every server sees the same window (UTC epoch, not local time)", function()
		local late = at(23, 58)
		t.expect(Clock.current(late).id).toBe("GreatStorm")
		t.expect(Clock.current(late).startAt).toBe(at(24))
	end)
end
