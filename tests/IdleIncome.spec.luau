-- IdleIncome: the station crew's capped Cash pot (docs/15 H6). Rates and caps rise with the
-- workshop level, accrual is real time from a timestamp (online and offline), a full pot stops
-- filling, a backwards clock never pays or goes negative, and the profile flag round-trips.
return function(t)
	local Idle = t.load("src/shared/IdleIncome.luau")
	local Config = t.load("src/shared/Config/StationConfig.luau")

	local NOW = 1790000000 -- 2026-09-21, mid-morning UTC
	local HOUR = 3600

	local function levels(workshop: number, radio: number?, kennel: number?): any
		return { workshop = workshop, radio = radio or 0, kennel = kennel or 0 }
	end

	t.test("the ladder is level 0..3, rate and cap both rise, costs rise", function()
		t.expect(#Config.Crew).toBe(Config.MaxLevel + 1)
		t.expect(#Config.UpgradeCost).toBe(Config.MaxLevel)
		for i = 2, #Config.Crew do
			t.expect(Config.Crew[i].rate > Config.Crew[i - 1].rate).toBe(true)
			t.expect(Config.Crew[i].capHours > Config.Crew[i - 1].capHours).toBe(true)
		end
		for i = 2, #Config.UpgradeCost do
			t.expect(Config.UpgradeCost[i] > Config.UpgradeCost[i - 1]).toBe(true)
		end
		t.expect(Idle.cost(levels(0))).toBe(Config.UpgradeCost[1])
		t.expect(Idle.cost(levels(Config.MaxLevel))).toBeNil()
	end)

	t.test("level 0 earns about 10-15% of early active operations", function()
		local rates = Idle.rates(levels(0))
		t.expect(rates.rate >= 870 and rates.rate <= 1300).toBe(true)
		t.expect(rates.capCash).toBe(rates.rate * rates.capHours)
	end)

	t.test("a fresh pot starts empty at now and a new player is level 0", function()
		local l, pot = Idle.fromFlag(nil)
		t.expect(l).toEqual(Idle.newLevels())
		t.expect(pot.lastAt).toBe(0)
		t.expect(pot.cash).toBe(0)
		local accrued = Idle.accrue(pot, l, NOW)
		t.expect(accrued.lastAt).toBe(NOW)
		t.expect(accrued.cash).toBe(0)
	end)

	t.test("accrues at the level's rate from the timestamp (offline and online)", function()
		local l = levels(0)
		local rates = Idle.rates(l)
		local pot = { lastAt = NOW - HOUR / 2, cash = 0 }
		local after = Idle.accrue(pot, l, NOW)
		t.expect(after.cash).toBeCloseTo(rates.rate * 0.5, 1e-6)
		t.expect(after.lastAt).toBe(NOW)

		local preview = Idle.preview(pot, l, NOW)
		t.expect(preview.cash).toBeCloseTo(rates.rate * 0.5, 1e-6)
		t.expect(preview.fill).toBeCloseTo(0.5, 1e-6)
		t.expect(preview.full).toBe(false)
		t.expect(preview.secondsToFull).toBeCloseTo(HOUR / 2, 1e-6)
	end)

	t.test("a full pot stops filling and nothing is lost", function()
		local l = levels(0)
		local cap = Idle.rates(l).capCash
		local full = { lastAt = NOW - 1000 * HOUR, cash = 0 }
		local after = Idle.accrue(full, l, NOW)
		t.expect(after.cash).toBeCloseTo(cap, 1e-6)
		t.expect(Idle.preview(full, l, NOW).full).toBe(true)
		t.expect(Idle.preview(full, l, NOW).secondsToFull).toBe(0)

		local later = Idle.accrue(after, l, NOW + 50 * HOUR)
		t.expect(later.cash).toBeCloseTo(cap, 1e-6)
	end)

	t.test("clock skew never pays backwards and never goes negative", function()
		local l = levels(1)
		local pot = { lastAt = NOW, cash = 500 }
		local after = Idle.accrue(pot, l, NOW - HOUR)
		t.expect(after.cash).toBe(500)
		t.expect(after.lastAt).toBe(NOW - HOUR)

		local corrupt = Idle.accrue({ lastAt = NOW, cash = -900 }, l, NOW)
		t.expect(corrupt.cash).toBe(0)
	end)

	t.test("collecting pays whole Cash and restarts the pot", function()
		local l = levels(0)
		local pot = { lastAt = NOW - HOUR, cash = 0.6 }
		local claim = Idle.claim(pot, l, NOW)
		t.expect(claim.cash).toBe(math.floor(Idle.rates(l).rate + 0.6))
		t.expect(claim.pot.cash).toBe(0)
		t.expect(claim.pot.lastAt).toBe(NOW)
		t.expect(Idle.claim(claim.pot, l, NOW).cash).toBe(0)
	end)

	t.test("the profile flag round-trips levels, anchor and pot", function()
		local l = levels(3, 2, 1)
		local pot = { lastAt = NOW, cash = 1234 }
		local raw = Idle.toFlag(l, pot)
		t.expect(raw.d * 86400 + raw.s).toBe(NOW)
		t.expect(raw.d <= 1e6).toBe(true) -- flag numbers are clamped to +-1e6
		local back, backPot = Idle.fromFlag(raw)
		t.expect(back).toEqual(l)
		t.expect(backPot.lastAt).toBe(NOW)
		t.expect(backPot.cash).toBe(1234)
	end)

	t.test("corrupt flags are sanitized to level 0 and a zero pot", function()
		local l, pot = Idle.fromFlag({ w = 99, r = -4, k = 2.7, d = -5, s = 1e9, c = -3 })
		t.expect(l.workshop).toBe(Config.MaxLevel)
		t.expect(l.radio).toBe(0)
		t.expect(l.kennel).toBe(2)
		t.expect(pot.lastAt).toBe(0)
		t.expect(pot.cash).toBe(0)
	end)

	t.test("Radio Room raises the rate and Kennel raises the cap", function()
		local base = Idle.rates(levels(1))
		local radio = Idle.rates(levels(1, 2))
		local kennel = Idle.rates(levels(1, 0, 2))
		t.expect(radio.rate).toBeCloseTo(base.rate * 1.1, 1e-6)
		t.expect(kennel.capHours).toBeCloseTo(base.capHours + 1, 1e-6)
	end)

	t.test("the time until full reads `2:14`, hours above one", function()
		t.expect(Idle.formatTime(134)).toBe("2:14")
		t.expect(Idle.formatTime(0)).toBe("0:00")
		t.expect(Idle.formatTime(59.2)).toBe("0:59")
		t.expect(Idle.formatTime(-3)).toBe("0:00")
		t.expect(Idle.formatTime(14399)).toBe("3:59:59")
	end)
end
