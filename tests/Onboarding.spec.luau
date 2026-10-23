-- Onboarding (docs/16 section 4): the tutorial call is the only goal, the fail-safe calls and the
-- stripped HUD.
return function(t)
	local O = t.load("src/shared/Onboarding.luau")
	local CallTypes = t.load("src/shared/Calls/CallTypes.luau")

	local function facts(over)
		local f = { coldOpenDone = true, callsCompleted = 0, offerReady = false }
		for k, v in over or {} do
			f[k] = v
		end
		return f
	end

	t.test("nothing to show before the cold open ends", function()
		t.expect(O.goal(facts({ coldOpenDone = false, offerReady = true }))).toBe(nil)
	end)

	t.test("each tutorial call's offer is the goal; no station or board walk (B2)", function()
		t.expect(O.goal(facts())).toBe(nil) -- between calls: nothing to chase
		for done = 0, O.TUTORIAL_CALLS - 1 do
			t.expect(O.goal(facts({ callsCompleted = done, offerReady = true }))).toBe("Rescue")
		end
	end)

	t.test("after the last tutorial call the normal mix runs (B9)", function()
		t.expect(O.TUTORIAL_CALLS).toBe(#CallTypes.TutorialChain - 1)
		local after = facts({ callsCompleted = O.TUTORIAL_CALLS, offerReady = true })
		t.expect(O.goal(after)).toBe(nil)
	end)

	t.test("nothing holds offers back any more (B2, B7)", function()
		t.expect(O.holdsOffers).toBe(nil)
		t.expect(O.certDone).toBe(nil)
	end)

	t.test(
		"the tutorial chain: drifting craft with 1, then 2, then the seal pup (B3, B4, B9)",
		function()
			local chain = CallTypes.TutorialChain
			t.expect(chain[2].kind).toBe("DriftingCraft")
			t.expect(chain[2].victims).toBe(1)
			t.expect(chain[3].kind).toBe("DriftingCraft")
			t.expect(chain[3].victims).toBe(2)
			t.expect(chain[5].kind).toBe("WildlifeRescue")
		end
	)

	t.test("the cold open and three calls are fail-safe; later calls are not", function()
		for completed = 0, O.FAILSAFE_CALLS do
			t.expect(O.failsafeCall(completed)).toBe(true)
			local cas = { { condition = 4 }, { condition = 55 } }
			t.expect(O.protect(cas, completed)).toBe(true)
			t.expect(cas[1].condition).toBe(O.FAILSAFE_FLOOR)
			t.expect(cas[2].condition).toBe(55)
		end
		t.expect(O.failsafeCall(O.FAILSAFE_CALLS + 1)).toBe(false)
		local cas = { { condition = 4 } }
		t.expect(O.protect(cas, O.FAILSAFE_CALLS + 1)).toBe(false)
		t.expect(cas[1].condition).toBe(4)
	end)

	t.test("the HUD stays stripped through the cold open and three calls", function()
		t.expect(O.newPlayerHud(false, nil)).toBe(true)
		for done = 0, O.FAILSAFE_CALLS do
			t.expect(O.newPlayerHud(true, done)).toBe(true)
		end
		t.expect(O.newPlayerHud(true, O.FAILSAFE_CALLS + 1)).toBe(false)
		t.expect(O.newPlayerHud(true, 40)).toBe(false)
	end)

	t.test("only a rescued cold open gets the reward burst", function()
		t.expect(O.rewarded("Complete")).toBe(true)
		for _, reason in { "Timer", "Takeover", "LeftCraft", "Died", "Lost", nil } do
			t.expect(O.rewarded(reason)).toBe(false)
		end
	end)
end
