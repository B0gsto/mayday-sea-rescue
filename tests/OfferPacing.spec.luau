-- Offer pacing (G69): the breather after a rescue, the longer big-call one, storm/live-event
-- speed-up, the wait after an ignored offer and the idle nudge by the station.
return function(t)
	local P = t.load("src/shared/Calls/OfferPacing.luau")

	t.test("a finished rescue earns a breather before the next pager", function()
		local calm = P.afterOp(false, "Calm")
		t.expect(calm).toBe(P.AfterOp)
		t.expect(calm >= 20 and calm <= 40).toBeTruthy()
		-- a big call gives a longer one
		t.expect(P.afterOp(true, "Calm")).toBe(P.AfterBig)
		t.expect(P.AfterBig > P.AfterOp).toBeTruthy()
		t.expect(P.AfterBig <= 60).toBeTruthy()
	end)

	t.test("a Great Storm or a live event shortens the breather", function()
		t.expect(P.afterOp(false, "Storm")).toBeCloseTo(P.AfterOp * P.Rush, 1e-6)
		t.expect(P.afterOp(false, "Calm", true)).toBeCloseTo(P.AfterOp * P.Rush, 1e-6)
		t.expect(P.afterOp(true, "Storm")).toBeCloseTo(P.AfterBig * P.Rush, 1e-6)
		t.expect(P.afterOp(false, "Storm") > 0).toBeTruthy()
	end)

	t.test("an ignored offer waits a bit before the next", function()
		t.expect(P.afterDecline("Calm")).toBe(P.AfterDecline)
		t.expect(P.AfterDecline > 0 and P.AfterDecline < P.AfterOp).toBeTruthy()
		t.expect(P.afterDecline("Storm")).toBeCloseTo(P.AfterDecline * P.Rush, 1e-6)
		t.expect(P.afterDecline("Calm", true)).toBeCloseTo(P.AfterDecline * P.Rush, 1e-6)
	end)

	t.test("the idle nudge needs two minutes on foot by the station", function()
		t.expect(P.nudgesIdle(P.IdleAfter - 1, true, 10)).toBe(false)
		t.expect(P.nudgesIdle(P.IdleAfter, true, P.NudgeRadius)).toBe(true)
		t.expect(P.nudgesIdle(P.IdleAfter, false, 10)).toBe(false) -- seated or aboard
		t.expect(P.nudgesIdle(P.IdleAfter, true, P.NudgeRadius + 1)).toBe(false)
	end)

	t.test("the big call runs on its own clock, once someone is past the tutorial", function()
		t.expect(P.nextBigCallAt(0, nil)).toBeNil() -- nobody ready: no big call
		t.expect(P.nextBigCallAt(100, 0)).toBe(100 + P.BigCallEvery)
		-- the first ready player waits the warm-up, even long after the last big call
		t.expect(P.nextBigCallAt(0, 5000)).toBe(5000 + P.BigCallWarmup)
		t.expect(P.BigCallEvery >= 12 * 60 and P.BigCallEvery <= 15 * 60).toBe(true)
		t.expect(P.bigCallReady(nil)).toBe(false)
		t.expect(P.bigCallReady(P.BigCallAfterCalls - 1)).toBe(false) -- still in the tutorial chain
		t.expect(P.bigCallReady(P.BigCallAfterCalls)).toBe(true)
		t.expect(P.BigCallAfterCalls > 3).toBe(true) -- never during a new player's first 3 calls
	end)
end
