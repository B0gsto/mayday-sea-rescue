-- CasualtyCare: the world-action rules behind survey, treatment, triage and calming (docs 14
-- section 2: no choice UI).
return function(t)
	local Care = t.load("src/shared/Ops/CasualtyCare.luau")
	local Medical = t.load("src/client/Mechanics/PIW/Medical.luau")

	t.test("survey: every letter but Danger has a body area; jet ski needs three", function()
		local full = Care.surveyAreas(Medical.FullSurvey)
		t.expect(table.concat(full, ",")).toBe("head,chest,arm,body")
		t.expect(#Care.surveyAreas(Medical.JetSkiSurvey)).toBe(3)
		t.expect(table.concat(Care.lettersAt("head", Medical.FullSurvey), ","))
			.toBe("Response,Airway")
		t.expect(Care.share(3, 4)).toBe(0.75)
		t.expect(Care.share(0, 0)).toBe(1)
	end)

	t.test("treatment: needed items stick where they belong, in any order", function()
		local plan = { "shelter", "casualtyBag", "hat", "dressing" }
		t.expect(Care.fits("hat", "head", plan, {})).toBe(true)
		t.expect(Care.fits("hat", "arm", plan, {})).toBe(false) -- wrong place
		t.expect(Care.fits("oxygen", "head", plan, {})).toBe(false) -- not needed
		t.expect(Care.fits("hat", "head", plan, { "hat" })).toBe(false) -- already on
		t.expect(Care.fits("dressing", "arm", plan, { "hat" })).toBe(true)
		t.expect(Care.fits("casualtyBag", "body", plan, {})).toBe(true)
		t.expect(Care.nextHands(plan, {})).toBe("shelter")
		t.expect(Care.nextHands(plan, { "shelter" })).toBeNil()
		t.expect(#Care.remaining(plan, { "hat", "shelter" })).toBe(2)
	end)

	t.test("treatment: the box holds every carried item, never one not carried", function()
		t.expect(#Care.tray(nil)).toBe(#Care.ITEM_ORDER)
		local tray = Care.tray({ casualtyBag = true, firstAid = true })
		t.expect(table.find(tray, "oxygen")).toBeNil()
		t.expect(table.find(tray, "hat") ~= nil).toBeTruthy()
		t.expect(table.find(Care.tray({}, { "dressing" }), "dressing") ~= nil).toBeTruthy()
		-- every item any plan can need is placeable or done by hand
		for _, st in { "Alert", "Panicking", "Exhausted", "VeryCold", "Unresponsive" } do
			for _, id in Medical.treatmentPlan(Medical.profile("x" .. st, st, true), nil) do
				t.expect(Care.ITEMS[id] ~= nil or Care.HANDS[id] == true or id == "cpr")
					.toBeTruthy()
			end
		end
	end)

	t.test(
		"calm: still and facing calms; the calm hand and the tube in reach calm faster",
		function()
			local function secondsToCalm(dist: number, holding: boolean): number
				local level, tt = Care.START, 0
				while level >= Care.ACCEPT and tt < 120 do
					level = Care.step(level, Care.calmRate(dist, 0, 10, holding), 0.1)
					tt += 0.1
				end
				return tt
			end
			local still = secondsToCalm(20, false)
			local hand = secondsToCalm(20, true)
			local tube = secondsToCalm(10, true)
			t.expect(still < 30).toBeTruthy() -- nobody gets stuck
			t.expect(hand < still).toBeTruthy()
			t.expect(tube < hand).toBeTruthy()
			t.expect(tube < 10).toBeTruthy()
			t.expect(Care.calmRate(10, 12, 0, true) > 0).toBeTruthy() -- rushing in
			t.expect(Care.calmRate(10, 0, 90, true) > 0).toBeTruthy() -- looking away
			t.expect(Care.calmRate(80, 0, 0, true) > 0).toBeTruthy() -- too far
		end
	)

	t.test("calm: grabs inside arm's length, takes the tube when calm", function()
		t.expect(Care.grabs(90, 3)).toBe(true)
		t.expect(Care.grabs(20, 3)).toBe(false)
		t.expect(Care.grabs(90, 8)).toBe(false)
		t.expect(Care.accepts(20, 10, 0)).toBe(true)
		t.expect(Care.accepts(20, 30, 0)).toBe(false)
		t.expect(Care.accepts(20, 30, Care.SETTLE)).toBe(true)
		t.expect(Care.accepts(50, 10, 9)).toBe(false)
		t.expect(Care.pose(90)).toBe("Panic")
		t.expect(Care.pose(10)).toBe("TreadWater")
	end)

	t.test("triage: each sieve check has an area on the body", function()
		local checks = { "walk", "airway", "responsive", "rate", "refill" }
		t.expect(table.concat(Care.triageAreas(checks), ",")).toBe("head,chest,hand,legs")
		t.expect(table.concat(Care.triageChecks("head", checks), ",")).toBe("airway,responsive")
	end)
	t.test(
		"cpr: off-beat pushes still progress, slower; nothing resets; breaths at the head",
		function()
			local Rhythm = t.load("src/client/Mechanics/PIW/Rhythm.luau")
			local plan = Rhythm.cprPlan("Child")
			local c = Care.cpr(Rhythm.cprSequence(plan))
			t.expect(Care.cprWants(c)).toBe("B")
			t.expect(Care.cprPush(c, true)).toBe(false) -- a push while a breath is wanted does nothing
			for _ = 1, plan.initialBreaths do
				t.expect(Care.cprBreath(c)).toBe(true)
			end
			t.expect(Care.cprWants(c)).toBe("C")
			t.expect(Care.cprBreath(c)).toBe(false)
			-- all off the beat: twice the pushes, but it gets there
			local pushes = 0
			while Care.cprWants(c) == "C" do
				local before = c.i + c.credit
				Care.cprPush(c, false)
				t.expect(c.i + c.credit > before).toBeTruthy()
				pushes += 1
			end
			t.expect(pushes).toBe(plan.compressions * 2)
			t.expect(Care.cprWants(c)).toBe("B")
			t.expect(c.credit).toBe(0)
			-- run to the end on the beat
			local guard = 0
			while Care.cprWants(c) and guard < 500 do
				if not Care.cprPush(c, true) then
					Care.cprBreath(c)
				end
				guard += 1
			end
			t.expect(Care.cprWants(c)).toBeNil()
			local q = Rhythm.cprQuality(c.onBeat, c.compressions, c.breathsRight, c.breaths)
			t.expect(q > 0.4 and q < 1).toBeTruthy()
			local c2 = Care.cpr({ "C", "C", "C", "C" })
			Care.cprPush(c2, true)
			t.expect(Care.cprCycle(c2)).toBe(0.25)
			Care.cprPush(c2, false)
			t.expect(Care.cprCycle(c2)).toBe(0.375)
		end
	)
end
