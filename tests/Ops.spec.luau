-- Ops: definitions, the condition meter, step and operation grading, payouts, NPC cap.
return function(t)
	local Types = t.load("src/shared/Ops/Types.luau")
	local Condition = t.load("src/shared/Ops/Condition.luau")
	local Grading = t.load("src/shared/Ops/Grading.luau")
	local Operations = t.load("src/shared/Ops/Operations.luau")

	local ROLES = { Helm = true, Navigator = true, Crew = true, Medic = true }
	local ONFAIL = { retry = true, npc = true, skip = true, takeover = true, continue = true }

	t.test("every definition is well formed", function()
		for id, def in Operations.Defs do
			t.expect(def.id).toBe(id)
			t.expect(#def.steps >= 6).toBeTruthy()
			local seen = {}
			for _, s in def.steps do
				t.expect(seen[s.id]).toBeNil()
				seen[s.id] = true
				t.expect(ROLES[s.role]).toBeTruthy()
				t.expect(ONFAIL[s.onFail]).toBeTruthy()
				t.expect(type(s.mechanicId) == "string" and #s.mechanicId > 0).toBeTruthy()
				t.expect(s.weight > 0 and s.timeoutSec > 0).toBeTruthy()
				t.expect(#s.gradeBands >= 1).toBeTruthy()
				for _, b in s.gradeBands do
					if b.higherIsBetter then
						t.expect(b.gold >= b.silver and b.silver >= b.bronze).toBeTruthy()
					else
						t.expect(b.gold <= b.silver and b.silver <= b.bronze).toBeTruthy()
					end
				end
				for _, m in s.serverMetrics or {} do
					local banded = false
					for _, b in s.gradeBands do
						banded = banded or b.metric == m
					end
					t.expect(banded).toBeTruthy()
				end
			end
			-- every operation starts with a tasking on the radio and ends with a close-out
			t.expect(def.steps[1].mechanicId).toBe("radio_ack")
			local last = def.steps[#def.steps].mechanicId
			t.expect(last == "handover" or last == "radio_closeout").toBeTruthy()
		end
	end)

	t.test("PIW plan follows the real order and adds the calm step only when panicking", function()
		local def = Operations.get("PersonInWater")
		local ids = {}
		for _, s in Operations.plan(def, "Alert") do
			table.insert(ids, s.id)
		end
		t.expect(table.concat(ids, ","))
			.toBe(
				"tasking,kit_launch,passage,search,approach,recovery,survey,treatment,transport,handover"
			)
		local panic = Operations.plan(def, "Panicking")
		t.expect(#panic).toBe(11)
		t.expect(panic[6].id).toBe("calm")
		local rec = panic[7]
		t.expect(Operations.mechanicFor(rec, "Alert")).toBe("recover_throwbag")
		t.expect(Operations.mechanicFor(rec, "VeryCold")).toBe("recover_swimmer")
	end)

	t.test("condition drifts by state, storm and treatment", function()
		local c = Condition.new("a", "Alert", true, 90)
		t.expect(Condition.rate(c)).toBeCloseTo(-0.2, 1e-9)
		c.lifejacket = false
		t.expect(Condition.rate(c)).toBeCloseTo(-1 / 3, 1e-9)
		c.panicking = true
		t.expect(Condition.rate(c, { storm = true })).toBeCloseTo(-1 / 3 * 1.5 * 1.5, 1e-9)
		c.panicking = false
		c.inWater = false
		t.expect(Condition.rate(c)).toBeCloseTo(-0.1, 1e-9)
		c.treated = true -- no survey: decline halves, never stops
		t.expect(Condition.rate(c)).toBeCloseTo(-0.05, 1e-9)
		c.surveyed = true
		t.expect(Condition.rate(c)).toBe(0)
		c.sheltered = true
		t.expect(Condition.rate(c)).toBeCloseTo(0.1, 1e-9)
		Condition.step(c, 1000)
		t.expect(c.condition).toBe(100)
	end)

	t.test("condition bands, events and the takeover", function()
		t.expect(Condition.band(70)).toBe("Stable")
		t.expect(Condition.band(69.9)).toBe("Concern")
		t.expect(Condition.band(20)).toBe("Serious")
		t.expect(Condition.band(19.9)).toBe("Critical")
		local c = Condition.new("a", "VeryCold", false, 50)
		t.expect(Condition.applyEvent(c, "wrongHandling", 3)).toBe(-10)
		t.expect(Condition.applyEvent(c, "wrongHandling")).toBe(0) -- once only
		t.expect(Condition.applyEvent(c, "slam", 2)).toBe(-6)
		local warm = Condition.new("b", "Alert", true, 90)
		t.expect(Condition.applyEvent(warm, "slam")).toBe(0)
		t.expect((Condition.shouldTakeover({ c }, 10, 720))).toBe(false)
		c.condition = 19
		local yes, why = Condition.shouldTakeover({ c }, 10, 720)
		t.expect(yes).toBe(true)
		t.expect(why).toBe("Critical")
		local _, why2 = Condition.shouldTakeover({ warm }, 721, 720)
		t.expect(why2).toBe("Cap")
		-- the meter reaches Critical in the water without help, in a few minutes
		local w = Condition.new("c", "Alert", true, 90)
		t.expect(Condition.secondsToCritical(w)).toBeCloseTo(350, 1e-6)
		local v = Condition.new("v", "Vessel", true, 90)
		t.expect(Condition.rate(v) < 0).toBeTruthy()
		v.towed = true
		t.expect(Condition.rate(v)).toBe(0)
	end)

	t.test("step grade is the worst band; missing metrics grade Bronze", function()
		local step = Operations.get("PersonInWater").steps[5] -- approach
		t.expect(step.id).toBe("approach")
		t.expect(
			Grading.stepGrade(step, { overSpeedSec = 0, neutralDistance = 5, fromDownwind = true })
		)
			.toBe("Gold")
		t.expect(
			Grading.stepGrade(step, { overSpeedSec = 1, neutralDistance = 5, fromDownwind = true })
		)
			.toBe("Silver")
		t.expect(
			Grading.stepGrade(step, { overSpeedSec = 9, neutralDistance = 5, fromDownwind = true })
		)
			.toBe("Fail")
		t.expect(Grading.stepGrade(step, { overSpeedSec = 0, neutralDistance = 5 })).toBe("Bronze")
	end)

	t.test("NPC and stub caps", function()
		local tasking = Operations.get("PersonInWater").steps[1]
		t.expect(Grading.resolveStep(tasking, { elapsed = 3 }, { npc = true })).toBe("Silver")
		t.expect(Grading.resolveStep(tasking, { elapsed = 3 }, { stub = true })).toBe("Silver")
		t.expect(Grading.resolveStep(tasking, { elapsed = 30 }, { stub = true })).toBe("Bronze")
		t.expect(Grading.resolveStep(tasking, { elapsed = 3, format = 1 })).toBe("Gold")
		-- voice procedure: one fault of three is Silver, no format sent is Bronze
		t.expect(Grading.resolveStep(tasking, { elapsed = 3, format = 0.67 })).toBe("Silver")
		t.expect(Grading.resolveStep(tasking, { elapsed = 3 })).toBe("Bronze")
		-- stub: format is the client's, so a stub is still graded on elapsed alone
		t.expect(Grading.resolveStep(tasking, { elapsed = 3, format = 0 }, { stub = true }))
			.toBe("Silver")
		local survey = Operations.get("PersonInWater").steps[8]
		-- stub: graded on server metrics only (elapsed), client "correct" ignored
		t.expect(Grading.resolveStep(survey, { elapsed = 5 }, { stub = true })).toBe("Silver")
		t.expect(Grading.cap("Gold", Types.Rules.NpcGradeCap)).toBe("Silver")
		t.expect(Grading.cap("Bronze", "Silver")).toBe("Bronze")
	end)

	t.test("operation grade thresholds and weights", function()
		t.expect(Grading.operationGrade({
			{ grade = "Gold", weight = 1 },
			{ grade = "Silver", weight = 1 },
		})).toBe("Gold")
		t.expect(Grading.operationGrade({
			{ grade = "Gold", weight = 1 },
			{ grade = "Bronze", weight = 1 },
		})).toBe("Silver")
		t.expect(Grading.operationGrade({
			{ grade = "Silver", weight = 1 },
			{ grade = "Bronze", weight = 2 },
		})).toBe("Bronze")
		-- weight 2 steps count double
		t.expect(Grading.weightedAverage({
			{ grade = "Gold", weight = 2 },
			{ grade = "Fail", weight = 1 },
		})).toBe(2)
		t.expect(Grading.conditionGrade(75)).toBe("Gold")
		t.expect(Grading.conditionGrade(10)).toBe("Fail")
		t.expect(Grading.weakest({
			{ grade = "Gold", weight = 1 },
			{ grade = "Bronze", weight = 1 },
			{ grade = "Bronze", weight = 2 },
		})).toBe(3)
		-- solo all-Silver (NPC-heavy) still lands Silver, never Gold
		local all = {}
		for _ = 1, 10 do
			table.insert(all, { grade = "Silver", weight = 1 })
		end
		t.expect(Grading.operationGrade(all)).toBe("Silver")
	end)

	t.test("payouts follow docs 03 section 2", function()
		local silver = Grading.payout(1.0, "Silver", 1)
		t.expect(silver.cash).toBe(550)
		t.expect(silver.rep).toBe(135)
		local gold = Grading.payout(1.3, "Gold", 3)
		t.expect(gold.cash).toBe(math.floor(550 * 1.3 * 1.25 * 1.2 + 0.5))
		t.expect(Grading.payout(1, "Gold", 9).cash).toBe(math.floor(550 * 1.25 * 1.3 + 0.5))
		t.expect(Grading.payout(1, "Bronze", 1, 0).cash).toBe(500) -- tutorial chain
		t.expect(Grading.payout(1, "Bronze", 1, 2).rep).toBe(160)
		t.expect(Grading.payout(1, "Bronze", 1, 3).cash).toBe(math.floor(550 * 0.75 + 0.5))
		-- takeover: half of each completed step's share, no completion share
		local tk = Grading.takeoverPayout(
			1,
			{ { grade = "Silver", weight = 1 }, { grade = "Fail", weight = 1 } },
			4,
			1
		)
		t.expect(tk.cash).toBe(math.floor(550 * 0.25 * 0.5 + 0.5))
		local tka = Grading.takeoverPayout(1, {}, 4, 1, true)
		t.expect(tka.cash).toBe(math.floor(550 * 0.25 + 0.5))
		t.expect(Grading.shareWithoutStep(1).cash).toBe(55)
		t.expect(Grading.bigCasualtyPay().cash).toBe(165)
		t.expect(Grading.bigCompletionBonus(5, 10).cash).toBe(688)
		t.expect(Grading.bigCompletionBonus(10, 10, true).rep)
			.toBe(math.floor(135 * 1.5 * 1.2 + 0.5))
	end)

	t.test("rolls and triage truth", function()
		t.expect(Operations.roll({ A = 1, B = 1 }, 0)).toBe("A")
		t.expect(Operations.roll({ A = 1, B = 1 }, 0.99)).toBe("B")
		t.expect(Operations.triageTag("Unresponsive")).toBe("Red")
		t.expect(Operations.triageTag("Alert")).toBe("Green")
		t.expect(Operations.FromCallKind.Tow).toBe("DisabledVessel")
	end)
	t.test("drift scale softens the decline (cold open)", function()
		local c = Condition.new("a", "Alert", true, 85)
		c.driftScale = 0.5
		t.expect(Condition.rate(c)).toBeCloseTo(-0.1, 1e-9)
		c.inWater = false
		c.treated = true
		c.surveyed = true
		c.sheltered = true
		t.expect(Condition.rate(c)).toBeCloseTo(0.1, 1e-9)
	end)
end
