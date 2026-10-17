-- MechPIW medical: kit, DR ABCDE survey, treatment and ATMIST truth for the Person in the Water
-- mechanics, and their fit with the PersonInWater grade bands. docs/09 sections 5.5 to 5.8.
return function(t)
	local Medical = t.load("src/client/Mechanics/PIW/Medical.luau")
	local Grading = t.load("src/shared/Ops/Grading.luau")
	local Operations = t.load("src/shared/Ops/Operations.luau")

	local STATES = { "Alert", "Panicking", "Exhausted", "VeryCold", "Unresponsive" }
	local def = Operations.get("PersonInWater")
	local function step(id: string)
		for _, s in def.steps do
			if s.id == id then
				return s
			end
		end
		error(id)
	end

	t.test(
		"profile is deterministic and CPR only for an unresponsive casualty without a lifejacket",
		function()
			local a = Medical.profile("c1", "Alert", true)
			local b = Medical.profile("c1", "Alert", true)
			t.expect(a.ageBand).toBe(b.ageBand)
			t.expect(a.mechanism).toBe(b.mechanism)
			t.expect(Medical.profile("c1", "Unresponsive", false).notBreathing).toBe(true)
			t.expect(Medical.profile("c1", "Unresponsive", true).notBreathing).toBe(false)
			t.expect(Medical.profile("c1", "VeryCold", false).notBreathing).toBe(false)
			t.expect(Medical.profile("x", "Alert", true, "DriftingCraft").mechanism)
				.toBe("Fell off a paddleboard")
		end
	)

	t.test("kit: the right kit fits, the jet ski has no oxygen and fewer slots", function()
		for _, st in STATES do
			for _, lj in { true, false } do
				local rib = Medical.kitNeeded(st, lj, false)
				local jet = Medical.kitNeeded(st, lj, true)
				t.expect(#rib <= Medical.kitSlots(false)).toBeTruthy()
				t.expect(#jet <= Medical.kitSlots(true)).toBeTruthy()
				t.expect(table.find(jet, "oxygen")).toBeNil()
				t.expect(Medical.kitFit(rib, rib)).toBe(1)
			end
		end
		local need = Medical.kitNeeded("Alert", true, false)
		t.expect(Medical.kitFit({ "towline", "fenders" }, need)).toBe(0)
		t.expect(Medical.kitFit({ need[1] }, need) < 0.6).toBeTruthy()
		t.expect(table.find(Medical.kitNeeded("Alert", false, false), "lifejacket") ~= nil)
			.toBeTruthy()
	end)

	t.test("survey: every card has its answer among 2 to 4 options; jet ski has three", function()
		for _, st in STATES do
			local p = Medical.profile("id" .. st, st, st ~= "Unresponsive")
			local cards = Medical.surveyCards(p, false, false)
			t.expect(#cards).toBe(7)
			t.expect(#Medical.surveyCards(p, true, false)).toBe(3)
			local picks = {}
			for _, c in cards do
				t.expect(#c.options >= 2 and #c.options <= 4).toBeTruthy()
				t.expect(c.answer >= 1 and c.answer <= #c.options).toBeTruthy()
				picks[c.letter] = c.answer
			end
			t.expect(Medical.surveyCorrect(cards, picks)).toBe(1)
		end
		local cold = Medical.surveyCards(Medical.profile("q", "VeryCold", true), false, false)
		for _, c in cold do
			if c.letter == "Disability" then
				t.expect(c.options[c.answer]).toBe("Not shivering, drowsy")
			end
		end
	end)

	t.test(
		"treatment: the book scores 1 with nothing harmful; rubbing and drinks are harmful",
		function()
			for _, st in STATES do
				for _, lj in { true, false } do
					local p = Medical.profile("t" .. st, st, lj)
					local need, harmful = Medical.treatmentPlan(p, nil)
					t.expect(#need >= 2).toBeTruthy()
					local m, bad = Medical.treatmentScore(need, need, harmful)
					t.expect(m).toBe(1)
					t.expect(bad).toBe(0)
					t.expect(harmful.rub).toBe(true)
				end
			end
			local drowsy = Medical.profile("d", "VeryCold", true)
			local need, harmful = Medical.treatmentPlan(drowsy, nil)
			t.expect(harmful.drink).toBe(true)
			t.expect(need[1]).toBe("horizontal")
			local _, bad = Medical.treatmentScore({ "rub", "drink" }, need, harmful)
			t.expect(bad).toBe(2)
			local cpr = Medical.profile("c", "Unresponsive", false)
			local cneed = Medical.treatmentPlan(cpr, nil)
			t.expect(cneed[1]).toBe("cpr")
		end
	)

	t.test("treatment: dressing the graze before the cold costs order credit", function()
		local p = Medical.profile("g", "Alert", true)
		p.scrape = true
		local need, harmful = Medical.treatmentPlan(p, nil)
		local late = {}
		table.insert(late, "dressing")
		for _, id in need do
			if id ~= "dressing" then
				table.insert(late, id)
			end
		end
		local m = Medical.treatmentScore(late, need, harmful)
		t.expect(m < 1).toBeTruthy()
	end)

	t.test("treatment: kit not carried drops out of the plan", function()
		local p = Medical.profile("o", "Unresponsive", true)
		local need =
			Medical.treatmentPlan(p, { oxygen = false, casualtyBag = true, firstAid = true })
		t.expect(table.find(need, "oxygen")).toBeNil()
	end)

	t.test("atmist: six cards, the truth among the options, treatment read back", function()
		local p = Medical.profile("h", "Exhausted", true)
		local cards = Medical.atmistCards(
			p,
			"h",
			{ applied = { "shelter", "casualtyBag" }, minutesOnScene = 8 }
		)
		t.expect(#cards).toBe(6)
		for _, c in cards do
			t.expect(c.answer >= 1 and c.answer <= #c.options).toBeTruthy()
		end
		t.expect(cards[1].options[cards[1].answer]).toBe(p.ageBand)
		t.expect(cards[6].options[cards[6].answer]).toBe("Shelter from the wind, Casualty bag")
		t.expect(cards[2].options[cards[2].answer]).toBe("about 20 min")
	end)

	t.test("bands: the book play grades Gold on every PIW mechanic step", function()
		t.expect(Grading.stepGrade(step("kit_launch"), { kitFit = 1, elapsed = 20 })).toBe("Gold")
		t.expect(Grading.stepGrade(step("passage"), { routeRatio = 1.05, etaError = 0.1 }))
			.toBe("Gold")
		t.expect(Grading.stepGrade(step("search"), { startError = 30, lostSight = 0 })).toBe("Gold")
		t.expect(
			Grading.stepGrade(
				step("approach"),
				{ overSpeedSec = 0, neutralDistance = 6, fromDownwind = true }
			)
		).toBe("Gold")
		t.expect(Grading.stepGrade(step("calm"), { calmSeconds = 12, grabbed = 0 })).toBe("Gold")
		t.expect(Grading.stepGrade(step("recovery"), { rightMethod = true, score = 0.85 }))
			.toBe("Gold")
		t.expect(Grading.stepGrade(step("survey"), { correct = 1, elapsed = 24 })).toBe("Gold")
		t.expect(Grading.stepGrade(step("treatment"), { matches = 1, harmful = 0 })).toBe("Gold")
		t.expect(Grading.stepGrade(step("handover"), { correct = 6, elapsed = 18 })).toBe("Gold")
		-- an overrun neutral shift or a wake-chasing approach is not Gold
		t.expect(
			Grading.stepGrade(
				step("approach"),
				{ overSpeedSec = 0, neutralDistance = 15, fromDownwind = true }
			) ~= "Gold"
		).toBeTruthy()
	end)
end
