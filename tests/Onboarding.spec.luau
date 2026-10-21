-- Onboarding (docs/15 section 3): the one-goal-at-a-time sequence, the fail-safe calls, the
-- throw assist and the touch targets.
return function(t)
	local O = t.load("src/shared/Onboarding.luau")

	local function facts(over)
		local f = {
			coldOpenDone = true,
			stationReached = false,
			boardReached = false,
			callsCompleted = 0,
			offerReady = false,
			gearOwned = false,
			certEarned = false,
			seconds = 0,
		}
		for k, v in over or {} do
			f[k] = v
		end
		return f
	end

	t.test("nothing to show before the cold open ends", function()
		t.expect(O.goal(facts({ coldOpenDone = false }))).toBe(nil)
	end)

	t.test("new taskings wait while a beacon goal is up", function()
		t.expect(O.holdsOffers("Gear")).toBe(true)
		t.expect(O.holdsOffers("Cert")).toBe(true)
		t.expect(O.holdsOffers("Station")).toBe(true)
		t.expect(O.holdsOffers("CallBoard")).toBe(true)
		t.expect(O.holdsOffers("Rescue")).toBe(false) -- the offer already is the goal
		t.expect(O.holdsOffers(nil)).toBe(false) -- the first session's goals are done
	end)

	t.test("the first session's goals arrive one at a time, in order", function()
		t.expect(O.goal(facts())).toBe("Station")
		t.expect(O.goal(facts({ stationReached = true }))).toBe("CallBoard")
		local board = facts({ stationReached = true, boardReached = true })
		t.expect(O.goal(board)).toBe("Rescue")
		-- back to the station until the 5-minute gear unlock is due
		local after = facts({ stationReached = true, boardReached = true, callsCompleted = 1 })
		t.expect(O.goal(after)).toBe("Station")
		t.expect(O.goal(facts({
			stationReached = true,
			boardReached = true,
			callsCompleted = 1,
			seconds = O.GEAR_AT,
		}))).toBe("Gear")
		t.expect(O.goal(facts({
			stationReached = true,
			boardReached = true,
			callsCompleted = 1,
			seconds = O.CERT_AT,
			gearOwned = true,
		}))).toBe("Cert")
	end)

	t.test("the cert goal ends on an earned cert or a passed exercise (snapshot certs)", function()
		local none = { Helm = { earned = false, exercisePassed = false } }
		t.expect(O.certDone(none)).toBe(false)
		t.expect(O.certDone({ Helm = { earned = false, exercisePassed = true } })).toBe(true)
		t.expect(O.certDone({ Helm = { earned = true, exercisePassed = true } })).toBe(true)
		t.expect(O.certDone(nil)).toBe(false)
	end)

	t.test("offers become the rescue goal; after certification only calls remain", function()
		local ready = facts({
			stationReached = true,
			boardReached = true,
			callsCompleted = 1,
			gearOwned = true,
			offerReady = true,
		})
		t.expect(O.goal(ready)).toBe("Rescue")
		t.expect(O.goal(facts({
			stationReached = true,
			boardReached = true,
			callsCompleted = 1,
			gearOwned = true,
			certEarned = true,
		}))).toBe(nil)
	end)

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

	t.test("the throw aims itself after two misses, only in Assist", function()
		t.expect(O.throwAssist(1, true)).toBe(false)
		t.expect(O.throwAssist(2, true)).toBe(true)
		t.expect(O.throwAssist(3, true)).toBe(true)
		t.expect(O.throwAssist(9, false)).toBe(false)
	end)

	t.test("touch targets are bigger than the old 130 px pads", function()
		t.expect(O.TOUCH.throw > 130).toBe(true)
		t.expect(O.TOUCH.grab > 130).toBe(true)
		t.expect(O.TOUCH.throw).toBe(O.TOUCH.grab)
	end)

	t.test("only a rescued cold open gets the reward burst", function()
		t.expect(O.rewarded("Complete")).toBe(true)
		for _, reason in { "Timer", "Takeover", "LeftCraft", "Died", "Lost", nil } do
			t.expect(O.rewarded(reason)).toBe(false)
		end
	end)
end
