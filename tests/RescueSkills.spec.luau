-- Rescue-side skills (docs/25 B, E, F): golden call chance maths (Lookout Tower levels, Golden Mayday), the
-- golden survivor lift, the Nitro double-tap and the effect totals SkillService publishes for these readers.
return function(t)
	local G = t.load("src/shared/Calls/GoldenCalls.luau")
	local N = t.load("src/shared/Boat/Nitro.luau")
	local S = t.load("src/shared/SkillRules.luau")
	local D = t.load("src/shared/Config/DockConfig.luau")

	t.test("golden chance: 1 in 40, Lookout Lv2 x1.5, Lv3 x2, Golden Mayday x2, capped", function()
		t.expect(G.chance(0, 0)).toBeCloseTo(1 / 40, 1e-12)
		t.expect(G.chance(1, 0)).toBeCloseTo(1 / 40, 1e-12) -- Lv1 only spots calls farther
		t.expect(G.chance(2, 0)).toBeCloseTo(1.5 / 40, 1e-12)
		t.expect(G.chance(3, 0)).toBeCloseTo(2 / 40, 1e-12)
		t.expect(G.chance(9, 0)).toBeCloseTo(2 / 40, 1e-12) -- past the last level
		local mayday = S.effects({ GoldenMayday = true }).goldenCalls
		t.expect(G.chance(0, mayday)).toBeCloseTo(2 / 40, 1e-12)
		t.expect(G.chance(3, mayday)).toBeCloseTo(4 / 40, 1e-12)
		t.expect(G.chance(3, 100)).toBe(G.MAX_CHANCE)
		-- the multipliers come from the Lookout Tower's own level effects
		local levels = D.Buildings.LookoutTower.levels
		t.expect(G.LOOKOUT[levels[2].effect]).toBe(1.5)
		t.expect(G.LOOKOUT[levels[3].effect]).toBe(2)
	end)

	t.test(
		"golden survivor: lifted to Epic with a trait, Epic+ kept, pity's Epic counter reset",
		function()
			local traits = { "Speedy", "Strong" }
			local common = { rarity = 1, trait = "" }
			local pity = { epic = 17, legendary = 30 }
			G.lift(common, traits, 0.6, pity)
			t.expect(common.rarity).toBe(G.MIN_RARITY)
			t.expect(common.trait).toBe("Strong")
			t.expect(pity.epic).toBe(0)
			t.expect(pity.legendary).toBe(30)
			local rare = { rarity = 3, trait = "Lucky" }
			G.lift(rare, traits, 0, nil)
			t.expect(rare.rarity).toBe(G.MIN_RARITY)
			t.expect(rare.trait).toBe("Lucky")
			local mythic = { rarity = 6, trait = "Cheerful" }
			G.lift(mythic, traits, 0, nil)
			t.expect(mythic.rarity).toBe(6)
		end
	)

	t.test(
		"nitro: a double-tap bursts, a slow double or no skill does not, then a cooldown",
		function()
			local function tap(st, at: number, owned: boolean)
				N.step(st, 1, at, owned)
				return N.step(st, 0, at + 0.05, owned)
			end
			local st = N.new()
			tap(st, 0, true)
			t.expect(N.step(st, 1, 0.2, true)).toBe(N.MULT)
			t.expect(N.step(st, 1, 0.2 + N.BURST - 0.01, true)).toBe(N.MULT) -- holding keeps the burst
			t.expect(N.step(st, 1, 0.2 + N.BURST + 0.01, true)).toBe(1)
			-- a new double-tap inside the cooldown does nothing
			tap(st, 4, true)
			tap(st, 4.2, true)
			t.expect(N.step(st, 0, 4.3, true)).toBe(1)
			-- after it, it works again
			tap(st, 10, true)
			t.expect(N.step(st, 1, 10.2, true)).toBe(N.MULT)

			local slow = N.new()
			tap(slow, 0, true)
			t.expect(N.step(slow, 1, N.TAP_WINDOW + 0.1, true)).toBe(1)
			local none = N.new()
			tap(none, 0, false)
			t.expect(N.step(none, 1, 0.2, false)).toBe(1)
		end
	)

	t.test(
		"effect totals: Nitro, Golden Eye, Golden Mayday, Big Boat, Lifeguard, Air Patrol",
		function()
			local e = S.effects({
				Nitro = true,
				GoldenEye = true,
				GoldenMayday = true,
				BigBoat = true,
				Lifeguard = true,
				AirPatrol = true,
			})
			t.expect(e.nitro).toBe(1)
			t.expect(e.goldenEye).toBe(1)
			t.expect(e.goldenCalls).toBe(2)
			t.expect(e.boatSeats).toBe(2) -- the NPC rescue boat only
			t.expect(e.craftSeats).toBe(1) -- your own craft only
			t.expect(e.pilots).toBe(1)
			t.expect(S.effects({}).craftSeats).toBe(0)
		end
	)
end
