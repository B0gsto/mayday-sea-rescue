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
			end
		end
		t.expect(table.find(Medical.kitNeeded("Alert", false, false), "lifejacket") ~= nil)
			.toBeTruthy()
	end)

	t.test("survey: every card has its answer among 2 to 4 options; jet ski has three", function()
		for _, st in STATES do
			local p = Medical.profile("id" .. st, st, st ~= "Unresponsive")
			local cards = Medical.surveyCards(p, false, false)
			t.expect(#cards).toBe(7)
			t.expect(#Medical.surveyCards(p, true, false)).toBe(3)
			for _, c in cards do
				t.expect(#c.options >= 2 and #c.options <= 4).toBeTruthy()
				t.expect(c.answer >= 1 and c.answer <= #c.options).toBeTruthy()
			end
		end
		local cold = Medical.surveyCards(Medical.profile("q", "VeryCold", true), false, false)
		for _, c in cold do
			if c.letter == "Disability" then
				t.expect(c.options[c.answer]).toBe("Not shivering, drowsy")
			end
		end
	end)

	t.test("treatment: the plan follows the state; CPR first only when not breathing", function()
		for _, st in STATES do
			for _, lj in { true, false } do
				local need = Medical.treatmentPlan(Medical.profile("t" .. st, st, lj), nil)
				t.expect(#need >= 2).toBeTruthy()
			end
		end
		t.expect(Medical.treatmentPlan(Medical.profile("d", "VeryCold", true), nil)[1])
			.toBe("horizontal")
		t.expect(Medical.treatmentPlan(Medical.profile("c", "Unresponsive", false), nil)[1])
			.toBe("cpr")
		local p = Medical.profile("g", "Alert", true)
		p.scrape = true
		local need = Medical.treatmentPlan(p, nil)
		t.expect(need[#need]).toBe("dressing") -- after the cold is dealt with
	end)

	t.test("survey: every Breathing answer has a breath rate, none when not breathing", function()
		t.expect(#Medical.BREATHS).toBe(4)
		t.expect(Medical.BREATHS[4]).toBe(0)
	end)

	t.test("treatment: kit not carried drops out of the plan", function()
		local p = Medical.profile("o", "Unresponsive", true)
		local need =
			Medical.treatmentPlan(p, { oxygen = false, casualtyBag = true, firstAid = true })
		t.expect(table.find(need, "oxygen")).toBeNil()
	end)

	t.test("atmist: six lines read back the truth and the treatment", function()
		local p = Medical.profile("h", "Exhausted", true)
		local lines =
			Medical.atmist(p, { applied = { "shelter", "casualtyBag" }, minutesOnScene = 8 })
		t.expect(#lines).toBe(6)
		t.expect(lines[1].text).toBe(p.ageBand)
		t.expect(lines[2].text).toBe("In the water about 20 min")
		t.expect(lines[6].text).toBe("Shelter from the wind, Casualty bag")
	end)

	-- 2026-10-21: the PIW plan is tasking, launch, recovery (auto_board), transport; kit, approach,
	-- care and handover moved out of it (their mechanics stay for the other calls)
	t.test("bands: a quick, smooth Person in the Water grades Gold on every step", function()
		t.expect(Grading.stepGrade(step("tasking"), { elapsed = 10 })).toBe("Gold")
		t.expect(Grading.stepGrade(step("launch"), { elapsed = 20 })).toBe("Gold")
		t.expect(Grading.stepGrade(step("recovery"), { elapsed = 50 })).toBe("Gold")
		t.expect(Grading.stepGrade(step("recovery"), { elapsed = 200 })).toBe("Bronze")
		t.expect(
			Grading.stepGrade(step("transport"), { conditionAtEnd = 80, destinationRight = true })
		)
			.toBe("Gold")
	end)
end
