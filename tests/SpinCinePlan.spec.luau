-- SpinCinePlan: the spin cinematic's rarity ladder and tier timings.
return function(t)
	local P = t.load("src/shared/SpinCinePlan.luau")
	local ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

	t.test("the ladder climbs Common up to the won rarity, never faster than 3 Hz", function()
		for rank, rarity in ORDER do
			local plan = P.plan(rarity)
			t.expect(#plan.steps).toBe(rank)
			t.expect(plan.steps[#plan.steps].rarity).toBe(rarity)
			for i, step in plan.steps do
				t.expect(step.rarity).toBe(ORDER[i])
				if i > 1 then
					t.expect(step.at - plan.steps[i - 1].at >= 1 / 3).toBe(true)
				end
			end
			t.expect(plan.reveal > plan.payoff).toBe(true)
			t.expect(plan.done > plan.reveal).toBe(true)
		end
	end)

	t.test("Epic and up fake out once before the last step; lower tiers never do", function()
		for rank, rarity in ORDER do
			local plan = P.plan(rarity)
			if rank >= 4 then
				t.expect(plan.fake ~= nil).toBe(true)
				t.expect(plan.fake > plan.steps[rank - 1].at).toBe(true)
				t.expect(plan.fake < plan.steps[rank].at).toBe(true)
			else
				t.expect(plan.fake).toBe(nil)
			end
		end
	end)

	t.test("low tiers stay short, the show grows with rarity", function()
		t.expect(P.plan("Common").done <= 1.6).toBe(true)
		t.expect(P.plan("Uncommon").done <= 1.8).toBe(true)
		local last = 0
		for _, rarity in ORDER do
			local reveal = P.plan(rarity).reveal
			t.expect(reveal > last).toBe(true)
			last = reveal
		end
		t.expect(P.plan("Mythic").reveal - P.plan("Mythic").payoff).toBeCloseTo(8)
	end)

	t.test("back-to-back spins skip the climb up to Rare", function()
		local rare = P.plan("Rare", true)
		t.expect(#rare.steps).toBe(1)
		t.expect(rare.steps[1].rarity).toBe("Rare")
		t.expect(#P.plan("Epic", true).steps).toBe(4)
		t.expect(P.plan("Nope").rarity).toBe("Common")
	end)
end
