-- SpinRules (docs/24 D): the wheel's odds, the Epic+ / Legendary+ pity guarantees over seeded
-- rolls, duplicate prizes becoming Cash, the owned-prize bits and the free-spin accrual.
return function(t)
	local SpinRules = t.load("src/shared/SpinRules.luau")

	-- a deterministic little LCG: rng() in [0, 1)
	local function seeded(seed: number): () -> number
		local state = seed % 2147483647
		return function(): number
			state = (state * 48271) % 2147483647
			return state / 2147483647
		end
	end

	local function rank(rarity: string): number
		return SpinRules.rank(rarity)
	end

	t.test("odds are in percent and sum to 100; every prize has a known rarity", function()
		t.expect(SpinRules.oddsSum()).toBe(100)
		for _, rarity in SpinRules.RARITY_ORDER do
			t.expect(SpinRules.RARITIES[rarity].odds > 0).toBe(true)
			t.expect(#SpinRules.prizesOf(rarity) > 0).toBe(true)
		end
		local kinds = { cash = true, petVariant = true, finish = true, trail = true, boat = true }
		for _, prize in SpinRules.PRIZES do
			t.expect(SpinRules.RARITIES[prize.rarity] ~= nil).toBe(true)
			t.expect(kinds[prize.kind] == true).toBe(true)
			t.expect(SpinRules.prize(prize.id) == prize).toBe(true)
		end
	end)

	t.test("the wheel segments name known rarities and cover every rarity", function()
		local seen = {}
		for i, rarity in SpinRules.SEGMENTS do
			t.expect(SpinRules.RARITIES[rarity] ~= nil).toBe(true)
			seen[rarity] = true
			local rng = seeded(1000 + i)
			t.expect(SpinRules.SEGMENTS[SpinRules.segment(rng, rarity)]).toBe(rarity)
		end
		for _, rarity in SpinRules.RARITY_ORDER do
			t.expect(seen[rarity]).toBe(true)
		end
	end)

	t.test("pity: Epic+ at least every 10 spins and Legendary+ at least every 50", function()
		local rng = seeded(20261026)
		local pity = { epic = 0, legendary = 0 }
		local epicGap, legendGap = 0, 0
		local epics, legends = 0, 0
		for _ = 1, 10000 do
			local result = SpinRules.roll(rng, pity)
			pity = result.pity
			epicGap += 1
			legendGap += 1
			if rank(result.prize.rarity) >= rank("Epic") then
				epicGap = 0
				epics += 1
			end
			if rank(result.prize.rarity) >= rank("Legendary") then
				legendGap = 0
				legends += 1
			end
			t.expect(epicGap <= SpinRules.PITY_EPIC).toBe(true)
			t.expect(legendGap <= SpinRules.PITY_LEGENDARY).toBe(true)
			t.expect(pity.epic).toBe(epicGap)
			t.expect(pity.legendary).toBe(legendGap)
		end
		t.expect(epics > 900).toBe(true) -- at least the 10 % pity plus the natural odds
		t.expect(legends > 190).toBe(true) -- at least the 2 % pity plus the natural odds
	end)

	t.test("duplicates: an owned finish / trail is known and pays Cash by rarity", function()
		local state = SpinRules.newState()
		local prize = SpinRules.prize("GoldFinish") :: any
		t.expect(SpinRules.owns(state, prize)).toBe(false)
		state = SpinRules.claim(state, prize)
		t.expect(SpinRules.owns(state, prize)).toBe(true)
		local saved = SpinRules.decode(SpinRules.encode(state))
		t.expect(SpinRules.owns(saved, prize)).toBe(true)
		t.expect(SpinRules.duplicateCash(prize)).toBe(1200)
		local keys = SpinRules.ownedKeys(saved.owned)
		t.expect(table.find(keys, "spin:GoldFinish") ~= nil).toBe(true)
		t.expect(#keys).toBe(1)
		for _, rarity in SpinRules.RARITY_ORDER do
			t.expect(SpinRules.cashFor(rarity) > 0).toBe(true)
		end
		-- a cash prize is never "owned"
		t.expect(SpinRules.bit("CashSmall")).toBeNil()
	end)

	t.test("free spins: 1 a day and 1 per 10 rescued, capped", function()
		local state = SpinRules.newState()
		local day = 20000
		local now = day * 86400 + 100
		state = SpinRules.accrue(state, 9, now)
		t.expect(state.free).toBe(0)
		state, _ = SpinRules.accrue(state, 10, now)
		t.expect(state.free).toBe(1)
		state, _ = SpinRules.accrue(state, 25, now)
		t.expect(state.free).toBe(2) -- 1 for people 10..19, 1 for 20..24
		state, _ = SpinRules.accrue(state, 30, now)
		t.expect(state.free).toBe(3)
		local tomorrow = now + 86400
		local added = 0
		state, added = SpinRules.accrue(state, 30, tomorrow)
		t.expect(added).toBe(1)
		t.expect(state.free).toBe(4)
		state.free = SpinRules.MAX_FREE
		state, _ = SpinRules.accrue(state, 300, tomorrow + 86400 * 3)
		t.expect(state.free).toBe(SpinRules.MAX_FREE)
	end)

	t.test("decode ignores junk and encode round-trips", function()
		local junk = SpinRules.decode({ d = "x", f = -4, e = 0 / 0, o = 3.7 })
		t.expect(junk.free).toBe(0)
		t.expect(junk.pity.epic).toBe(0)
		t.expect(junk.owned).toBe(3)
		local state = SpinRules.newState()
		state.free = 7
		state.pity = { epic = 3, legendary = 12 }
		state.rescued = 40
		state.owned = 5
		local back = SpinRules.decode(SpinRules.encode(state))
		t.expect(back.free).toBe(7)
		t.expect(back.pity).toEqual({ epic = 3, legendary = 12 })
		t.expect(back.rescued).toBe(40)
		t.expect(back.owned).toBe(5)
	end)
end
