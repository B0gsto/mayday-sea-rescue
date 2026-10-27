-- DepotRules (docs/25 D, K4): caps, the barge drop, loads per build, carry, and one advance for ticks and time away.
return function(t)
	local D = t.load("src/shared/DepotRules.luau")
	local B = t.load("src/shared/BuildTimer.luau")
	local W = t.load("src/shared/WorkerRules.luau")

	local function worker(category, rarity, trait, special)
		return {
			category = category,
			rarity = rarity or 1,
			name = "A",
			trait = trait or "",
			special = special or "",
		}
	end

	-- a site of `work` s from `stock`, for a crew at `rate` and a Depot at `level` with `haul` Hauler units
	local function build(work, rate, level, haul, stock)
		local p = {
			cap = D.cap(level),
			drop = D.bargeLoads(level, haul),
			carry = D.carrySpeed(rate, work),
			loads = D.loadsFor(work),
		}
		return D.timeLeft({ stock = stock or D.cap(level), progress = 0, next = D.BARGE_PERIOD }, p)
	end

	t.test("K4 numbers: caps, the crew's drop, Lv2 doubles, loads = ceil(T / 10)", function()
		t.expect(D.cap(0)).toBe(0)
		t.expect(D.cap(1)).toBe(20)
		t.expect(D.cap(2)).toBe(40)
		t.expect(D.cap(3)).toBe(80)
		t.expect(D.BARGE_PERIOD).toBe(60)
		t.expect(D.bargeLoads(0, 0)).toBe(2)
		t.expect(D.bargeLoads(1, 0)).toBe(2)
		t.expect(D.bargeLoads(2, 0)).toBe(4)
		t.expect(D.bargeLoads(1, 3)).toBe(2 + 3 * D.HAUL_PER)
		t.expect(D.bargeLoads(1, 0, 0.5)).toBe(3) -- Hand Carts
		t.expect(D.loadsFor(20)).toBe(2)
		t.expect(D.loadsFor(21)).toBe(3)
		t.expect(D.loadsFor(600)).toBe(60)
	end)

	t.test("Haulers at the Depot: rarity value x carry; none before the Depot stands", function()
		local crew = { worker("Hauler", 1), worker("Hauler", 3, "Strong"), worker("Builder", 5) }
		t.expect(D.haulUnits(crew, {})).toBe(0)
		t.expect(D.haulUnits(crew, { Depot = true })).toBeCloseTo(1 + W.RARITY_MULT[3] * 2, 1e-9)
		t.expect(D.haulUnits({ worker("Hauler", 5, "", "BigLou") }, { Depot = true }))
			.toBeCloseTo(W.RARITY_MULT[5] * W.SPECIAL_CARRY, 1e-9)
	end)

	t.test(
		"carry: plain crews are BuildTimer's rate; Strong and Strong Backs carry more",
		function()
			local crew = { worker("Builder", 1), worker("Builder", 2) }
			t.expect(D.crewRate(crew)).toBeCloseTo(B.rateOf(crew), 1e-9)
			t.expect(D.crewRate({ worker("Builder", 1, "Strong") })).toBeCloseTo(B.rate(2), 1e-9)
			t.expect(D.crewRate(crew, { carry = 2 })).toBeCloseTo(B.rate(2 * B.units(crew)), 1e-9)
			t.expect(D.crewRate({}, { carry = 2, crew = 1 })).toBeCloseTo(B.rate(0, 1, 2), 1e-9)
		end
	)

	t.test("a full Depot builds at the crew's speed; an empty one waits on the barge", function()
		local work, rate = 300, 2
		local fast, waited = build(work, rate, 2, 0)
		t.expect(fast).toBeCloseTo(work / rate, 1e-6) -- 30 loads, 40 in stock
		t.expect(waited).toBe(0)
		local slow, starved = build(work, rate, 1, 0, 0)
		t.expect(slow > 10 * 60).toBe(true) -- 30 loads at 2 a minute
		t.expect(starved > 0).toBe(true)
	end)

	t.test("no Depot: the barge crew's drop alone, never blocked forever", function()
		local secs, waited, after = build(600, 1, 0, 0, 0)
		t.expect(secs < math.huge).toBe(true)
		t.expect(after.progress).toBe(1)
		t.expect(secs >= 29 * D.BARGE_PERIOD).toBe(true) -- 60 loads, 2 a mooring
		t.expect(waited > 0).toBe(true)
		-- the new save's quay crates build the first small sites without a wait
		local first, firstWait = build(B.work(0), 1, 0, 0, D.START)
		t.expect(first).toBeCloseTo(B.work(0), 1e-6)
		t.expect(firstWait).toBe(0)
	end)

	t.test("mid-game: Depot upgrades and Haulers clearly speed a 20k build", function()
		local work, rate = B.work(20000), 2.5
		local bare = build(work, rate, 1, 0)
		local upgraded = build(work, rate, 2, 3)
		local full = build(work, rate, 3, 3)
		t.expect(bare > 2 * upgraded).toBe(true)
		t.expect(upgraded >= full).toBe(true)
		t.expect(full).toBeCloseTo(work / rate, 1e-6)
	end)

	t.test("advance: one call over time away equals many one-second ticks", function()
		local p = {
			cap = D.cap(1),
			drop = D.bargeLoads(1, 2),
			carry = D.carrySpeed(1.5, 400),
			loads = D.loadsFor(400),
		}
		local s = { stock = 5, progress = 0.1, next = 17 }
		local once, onceWait = D.advance(s, p, 3600)
		local ticked, tickWait = s, 0
		for _ = 1, 3600 do
			local w
			ticked, w = D.advance(ticked, p, 1)
			tickWait += w
		end
		t.expect(once.progress).toBe(1)
		t.expect(ticked.progress).toBe(1)
		t.expect(once.stock).toBeCloseTo(ticked.stock, 1e-6)
		t.expect(once.stock).toBe(D.cap(1)) -- refilled after the site
		t.expect(once.next).toBeCloseTo(ticked.next, 1e-6)
		t.expect(onceWait).toBeCloseTo(tickWait, 1e-6)
		-- no site: only moorings fill it, capped
		local idle = D.advance({ stock = 0, next = 10 }, { cap = 20, drop = 4 }, 10 + 60 * 2)
		t.expect(idle.stock).toBe(12)
		t.expect(idle.next).toBe(D.BARGE_PERIOD)
		t.expect(D.advance({ stock = 18, next = 1 }, { cap = 20, drop = 4 }, 5000).stock).toBe(20)
	end)

	t.test("the barge clock is per island", function()
		t.expect(D.nextAt(120)).toBe(60)
		t.expect(D.nextAt(125)).toBe(55)
		t.expect(D.nextAt(125, 10)).toBe(5)
	end)
end
