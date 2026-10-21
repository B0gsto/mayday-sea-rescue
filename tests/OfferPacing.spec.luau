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

	t.test("the seasonal call starts only when free, due and someone is on", function()
		local cooldown = 20 * 60
		t.expect(P.eventCallDue(0, false, cooldown, cooldown)).toBe(false)
		t.expect(P.eventCallDue(1, true, cooldown, cooldown)).toBe(false) -- a storm ferry is up
		t.expect(P.eventCallDue(1, false, cooldown - 1, cooldown)).toBe(false)
		t.expect(P.eventCallDue(1, false, cooldown, cooldown)).toBe(true)
		-- a blocked start retries on EventRetry, not the whole cooldown
		t.expect(P.EventRetry > 0 and P.EventRetry < cooldown).toBeTruthy()
		t.expect(P.eventCallDue(1, false, P.EventRetry, cooldown)).toBe(false)
	end)

	t.test("the running event call re-offers on its own interval", function()
		t.expect(P.EventOffer > 0).toBeTruthy()
		t.expect(P.eventOfferDue(P.EventOffer - 1, true)).toBe(false)
		t.expect(P.eventOfferDue(P.EventOffer, true)).toBe(true)
		t.expect(P.eventOfferDue(P.EventOffer, false)).toBe(false) -- busy on an op
		t.expect(P.eventOfferDue(0, true)).toBe(false) -- first tick: one interval later
	end)
end
