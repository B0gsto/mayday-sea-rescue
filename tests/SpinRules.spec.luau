-- SpinRules (docs/24 D): the wheel's odds, the Epic+ / Legendary+ pity guarantees over seeded
-- rolls, duplicate prizes becoming Cash, the owned-prize bits and the free-spin accrual.
return function(t)
	local SpinRules = t.load("src/shared/SpinRules.luau")
	local PetRules = t.load("src/shared/PetRules.luau")
	local Wildlife = t.load("src/shared/Config/Wildlife.luau")

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
		local kinds =
			{ cash = true, pet = true, petVariant = true, finish = true, trail = true, boat = true }
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

	t.test(
		"the board's next-spin odds are the roll's distribution, guaranteed spins included",
		function()
			-- sweep the rarity draw evenly over [0, 1) (the prize draw gets 0): counts / N = the roll's odds
			local N = 100000
			local function distribution(pity)
				local counts: { [string]: number } = {}
				for k = 0, N - 1 do
					local calls = 0
					local result = SpinRules.roll(function()
						calls += 1
						return if calls == 1 then (k + 0.5) / N else 0
					end, pity)
					counts[result.prize.rarity] = (counts[result.prize.rarity] or 0) + 1
				end
				return counts
			end
			local cases = {
				{ pity = { epic = 0, legendary = 0 }, floor = "Common" },
				{ pity = { epic = 8, legendary = 48 }, floor = "Common" },
				{ pity = { epic = 9, legendary = 20 }, floor = "Epic" },
				{ pity = { epic = 3, legendary = 49 }, floor = "Legendary" },
			}
			for _, case in cases do
				local odds = SpinRules.nextOdds(case.pity)
				local counts = distribution(case.pity)
				local sum = 0
				for _, rarity in SpinRules.RARITY_ORDER do
					sum += odds[rarity]
					t.expect((counts[rarity] or 0) * 100 / N).toBeCloseTo(odds[rarity], 0.01)
					if rank(rarity) < rank(case.floor) then
						t.expect(odds[rarity]).toBe(0)
					elseif case.floor == "Common" then
						t.expect(odds[rarity]).toBeCloseTo(SpinRules.RARITIES[rarity].odds, 1e-9)
					end
				end
				t.expect(sum).toBeCloseTo(100, 1e-9)
			end
			-- the renormalised guaranteed odds: Epic+ 70 / 25 / 5, Legendary+ 83.3333 / 16.6667
			local epic = SpinRules.nextOdds({ epic = 9, legendary = 0 })
			t.expect(SpinRules.percent(epic.Epic)).toBe("70")
			t.expect(SpinRules.percent(epic.Mythic)).toBe("5")
			local legend = SpinRules.nextOdds({ epic = 0, legendary = 49 })
			t.expect(SpinRules.percent(legend.Legendary)).toBe("83.3333")
			t.expect(SpinRules.percent(legend.Mythic)).toBe("16.6667")
			t.expect(SpinRules.percent(SpinRules.nextOdds(nil).Legendary)).toBe("2.5")
			t.expect(SpinRules.percent(7 / 3)).toBe("2.3333")
			-- each prize of a rarity is equally likely (the board's "each" line)
			for _, rarity in SpinRules.RARITY_ORDER do
				local pool = SpinRules.prizesOf(rarity)
				local hits: { [string]: number } = {}
				for k = 0, 999 do
					local prize = SpinRules.prizeOfRarity(function()
						return (k + 0.5) / 1000
					end, rarity)
					hits[prize.id] = (hits[prize.id] or 0) + 1
				end
				for _, prize in pool do
					t.expect(hits[prize.id]).toBeCloseTo(1000 / #pool, 1)
				end
			end
		end
	)

	t.test("duplicates: an owned finish / trail is known and pays Cash by rarity", function()
		local state = SpinRules.newState()
		local prize = SpinRules.prize("GoldFinish") :: any
		t.expect(SpinRules.owns(state, prize)).toBe(false)
		state = SpinRules.claim(state, prize)
		t.expect(SpinRules.owns(state, prize)).toBe(true)
		local saved = SpinRules.decode(SpinRules.encode(state))
		t.expect(SpinRules.owns(saved, prize)).toBe(true)
		t.expect(SpinRules.duplicateCash(prize)).toBe(600)
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
		t.expect(state.free).toBe(1) -- the first day's spin
		state, _ = SpinRules.accrue(state, 10, now)
		t.expect(state.free).toBe(2)
		state, _ = SpinRules.accrue(state, 25, now)
		t.expect(state.free).toBe(3) -- +1 for people 10..19, +1 for 20..24
		state, _ = SpinRules.accrue(state, 30, now)
		t.expect(state.free).toBe(4)
		local tomorrow = now + 86400
		local added = 0
		state, added = SpinRules.accrue(state, 30, tomorrow)
		t.expect(added).toBe(1)
		t.expect(state.free).toBe(5)
		state.free = SpinRules.MAX_FREE
		state, _ = SpinRules.accrue(state, 300, tomorrow + 86400 * 3)
		t.expect(state.free).toBe(SpinRules.MAX_FREE)
	end)

	t.test("bought spins are spent last and never without a clear policy", function()
		local state = SpinRules.decode(SpinRules.addPaid(nil, 2))
		state.free += 1 -- one earned
		t.expect(SpinRules.usable(state, false)).toBe(1)
		t.expect(SpinRules.spendOne(state, false)).toBe(true) -- the earned one
		t.expect(state.paid).toBe(2)
		t.expect(SpinRules.spendOne(state, false)).toBe(false)
		t.expect(state.free).toBe(2)
		t.expect(SpinRules.spendOne(state, true)).toBe(true)
		t.expect(state.free).toBe(1)
		t.expect(state.paid).toBe(1)
		local saved = SpinRules.decode(SpinRules.encode(state))
		t.expect(saved.paid).toBe(1)
		t.expect(SpinRules.decode({ f = 1, p = 9 }).paid).toBe(1) -- never more than held
		t.expect(SpinRules.decode({ f = 3 }).paid).toBe(0) -- an old save
		local claimed = SpinRules.claim(state, SpinRules.prize("GalaxyFinish"))
		t.expect(claimed.paid).toBe(1)
		t.expect((SpinRules.accrue(state, 0, 1790000000)).paid).toBe(1)
	end)

	t.test("the odds board names every prize", function()
		t.expect(SpinRules.prizeNames("Common")).toBe("150 Cash")
		t.expect(SpinRules.prizeNames("Rare")).toBe("Otter, Gold Chrome")
		for _, id in SpinRules.WEDGES do
			local prize = SpinRules.prize(id) :: any
			t.expect(string.find(SpinRules.prizeNames(prize.rarity), prize.name, 1, true) ~= nil)
				.toBe(true)
		end
	end)

	t.test("free spins can't be farmed: no back-pay, no banked days, no clock rewind", function()
		local now = 20000 * 86400 + 100
		local vet = SpinRules.accrue(SpinRules.newState(), 500, now)
		t.expect(vet.free).toBe(1) -- the day's spin only, not 50 for old rescues
		local away = SpinRules.accrue(vet, 500, now + 86400 * 30)
		t.expect(away.free).toBe(2) -- a month away is still one day's spin
		local rewound = SpinRules.accrue(away, 500, now)
		t.expect(rewound.day).toBe(away.day)
		local back = SpinRules.accrue(rewound, 500, now + 86400 * 30)
		t.expect(back.free).toBe(2) -- the rewind didn't re-open today
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

	t.test("a paid spin receipt always adds its spins (no policy check, no cap)", function()
		local raw = SpinRules.encode({
			day = 5,
			free = 98,
			paid = 0,
			pity = { epic = 2, legendary = 7 },
			rescued = 30,
			owned = 1,
		})
		local back = SpinRules.decode(SpinRules.addPaid(raw, 15))
		t.expect(back.free).toBe(113) -- past MAX_FREE: paid spins are never capped
		t.expect(back.pity).toEqual({ epic = 2, legendary = 7 })
		t.expect(back.owned).toBe(1)
		t.expect(SpinRules.decode(SpinRules.addPaid(nil, 1)).free).toBe(1) -- a fresh profile
	end)

	t.test("the wheel is these 12 wedges, and each one matches its segment's rarity", function()
		t.expect(SpinRules.WEDGES).toEqual({
			"CashSmall",
			"GullPet",
			"CashSmall",
			"OtterPet",
			"CashSmall",
			"PuffinPet",
			"NeonFinish",
			"CashSmall",
			"StripesFinish",
			"GoldFinish",
			"RiptideBoat",
			"GrandBoat",
		})
		for i, id in SpinRules.WEDGES do
			local prize = SpinRules.prize(id)
			t.expect(prize.rarity).toBe(SpinRules.SEGMENTS[i])
			t.expect(prize.retired).toBeNil()
		end
		t.expect(SpinRules.prize("GrandBoat").vehicle).toBe("StormRunner")
		t.expect(SpinRules.prize("RiptideBoat").vehicle).toBe("RiptideX")
		t.expect(SpinRules.prize("StripesFinish").option).toBe("SpinStripes")
		for _, id in { "GullPet", "OtterPet", "PuffinPet" } do
			t.expect(Wildlife.Species[SpinRules.prize(id).pet] ~= nil).toBe(true)
		end
	end)

	t.test("wedge odds split each rarity evenly and sum to 100", function()
		local sum = 0
		for i = 1, #SpinRules.WEDGES do
			sum += SpinRules.wedgeOdds(i)
		end
		t.expect(sum).toBeCloseTo(100, 1e-9)
		t.expect(SpinRules.wedgeOdds(1)).toBe(12.5) -- Common / 4
		t.expect(SpinRules.wedgeOdds(2)).toBeCloseTo(25 / 3, 1e-9)
		t.expect(SpinRules.wedgeOdds(4)).toBe(7.5) -- Rare / 2
		t.expect(SpinRules.wedgeOdds(7)).toBe(7)
		t.expect(SpinRules.wedgeOdds(12)).toBe(0.5)
		t.expect(SpinRules.wedgeOdds(13)).toBe(0)
	end)

	t.test("each wedge pays its own prize: a roll's wedge lands with the wedge's odds", function()
		local N = 100000
		local hits: { [number]: number } = {}
		for k = 0, N - 1 do
			local calls = 0
			-- a stratified sweep: the rarity draw covers [0, 1), the wedge draw is decorrelated from it
			local result = SpinRules.roll(function()
				calls += 1
				return if calls == 1 then (k + 0.5) / N else ((k * 7919) % 1000 + 0.5) / 1000
			end, nil)
			t.expect(SpinRules.WEDGES[result.wedge]).toBe(result.prize.id)
			hits[result.wedge] = (hits[result.wedge] or 0) + 1
		end
		for i = 1, #SpinRules.WEDGES do
			t.expect((hits[i] or 0) * 100 / N).toBeCloseTo(SpinRules.wedgeOdds(i), 0.2)
		end
		local prize, wedge = SpinRules.prizeOfRarity(function()
			return 0.5
		end, "Mythic")
		t.expect(prize.id).toBe("GrandBoat")
		t.expect(wedge).toBe(12)
	end)

	t.test("old saves: PRIZES keeps its bits and retired wins stay owned", function()
		local old = {
			"CashSmall",
			"CashBig",
			"GoldenPet",
			"GoldFinish",
			"RainbowTrail",
			"NeonPet",
			"NeonFinish",
			"FireTrail",
			"RainbowPet",
			"LavaFinish",
			"StarTrail",
			"GalaxyPet",
			"GalaxyFinish",
			"GrandBoat",
		}
		for i, id in old do
			t.expect(SpinRules.PRIZES[i].id).toBe(id)
		end
		t.expect(#SpinRules.PRIZES <= 32).toBe(true)
		-- a save from the old wheel: Gold, Rainbow wake, Lava and Galaxy (bits 4, 5, 10, 13)
		local saved = SpinRules.decode({ o = 8 + 16 + 512 + 4096 })
		for _, id in { "GoldFinish", "RainbowTrail", "LavaFinish", "GalaxyFinish" } do
			t.expect(SpinRules.owns(saved, SpinRules.prize(id))).toBe(true)
		end
		t.expect(SpinRules.owns(saved, SpinRules.prize("NeonFinish"))).toBe(false)
		t.expect(SpinRules.ownedKeys(saved.owned)).toEqual({
			"spin:GoldFinish",
			"spin:RainbowTrail",
			"spin:LavaFinish",
			"spin:GalaxyFinish",
		})
		-- retired prizes never roll or count on the board
		for _, prize in SpinRules.PRIZES do
			t.expect(prize.retired == true).toBe(table.find(SpinRules.WEDGES, prize.id) == nil)
			if prize.retired then
				t.expect(table.find(SpinRules.prizesOf(prize.rarity), prize)).toBeNil()
			end
		end
		local none = function()
			return false
		end
		t.expect(SpinRules.ownedIds(saved, none, none)).toEqual({ "GoldFinish" })
		-- a new prize's bit sits past the old ones
		local stripes = SpinRules.claim(saved, SpinRules.prize("StripesFinish"))
		t.expect(SpinRules.owns(stripes, SpinRules.prize("GalaxyFinish"))).toBe(true)
		t.expect(SpinRules.bit("StripesFinish") >= 2 ^ #old).toBe(true)
	end)

	t.test("the spinBoat flag lists won boats and reads an old single-boat save", function()
		t.expect(SpinRules.wonBoat(nil, "StormRunner")).toBe(false)
		t.expect(SpinRules.wonBoat("StormRunner", "StormRunner")).toBe(true) -- an old save
		t.expect(SpinRules.wonBoat("StormRunner", "RiptideX")).toBe(false)
		local both = SpinRules.addWonBoat(SpinRules.addWonBoat(nil, "StormRunner"), "RiptideX")
		t.expect(SpinRules.wonBoat(both, "StormRunner")).toBe(true)
		t.expect(SpinRules.wonBoat(both, "RiptideX")).toBe(true)
		t.expect(#SpinRules.wonBoatLooks(both)).toBe(2)
		t.expect(#SpinRules.wonBoatLooks(nil)).toBe(0)
		t.expect(#SpinRules.wonBoatLooks("")).toBe(0)
	end)

	t.test("a pet owned by any route counts; a prize pet is ready at once", function()
		local state = PetRules.newState()
		t.expect(PetRules.ownsSpecies(state, "Gull")).toBe(false)
		-- a rescued rare gull is still a gull, even mid-recovery
		local rescued = PetRules.add(state, "Gull", true, 1000)
		t.expect(PetRules.ownsSpecies(rescued, "Gull")).toBe(true)
		t.expect(PetRules.ownsSpecies(rescued, "Otter")).toBe(false)
		local ids = SpinRules.ownedIds(SpinRules.newState(), function(species)
			return PetRules.ownsSpecies(rescued, species)
		end, function()
			return false
		end)
		t.expect(ids).toEqual({ "GullPet" })
		local now = 5000
		local _, prize = PetRules.add(state, "Otter", false, now - Wildlife.RecoverySeconds)
		t.expect(PetRules.ready(prize, now)).toBe(true)
	end)

	t.test("owned once-only prizes are listed for the odds board (they pay Cash)", function()
		local state = SpinRules.claim(SpinRules.newState(), SpinRules.prize("GoldFinish"))
		local function pets(species)
			return species == "Puffin"
		end
		local function boats(vehicle)
			return vehicle == "RiptideX" -- a bought pass counts
		end
		local ids = SpinRules.ownedIds(state, pets, boats)
		t.expect(ids).toEqual({ "GoldFinish", "PuffinPet", "RiptideBoat" })
		t.expect(SpinRules.ownedOf("Rare", ids)).toBe(1)
		t.expect(SpinRules.ownedOf("Uncommon", ids)).toBe(1)
		t.expect(SpinRules.ownedOf("Legendary", ids)).toBe(1)
		t.expect(SpinRules.ownedOf("Mythic", ids)).toBe(0)
		t.expect(SpinRules.ownedOf("Common", ids)).toBe(0) -- Cash prizes are never owned
		for _, id in ids do
			local prize = SpinRules.prize(id)
			t.expect(SpinRules.duplicateCash(prize)).toBe(SpinRules.RARITIES[prize.rarity].cash)
		end
	end)
end
