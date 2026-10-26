-- Ops: definitions, the condition meter, step and operation grading, payouts, NPC cap.
return function(t)
	local Types = t.load("src/shared/Ops/Types.luau")
	local Condition = t.load("src/shared/Ops/Condition.luau")
	local Grading = t.load("src/shared/Ops/Grading.luau")
	local Operations = t.load("src/shared/Ops/Operations.luau")

	local ROLES = { Helm = true, Navigator = true, Crew = true, Medic = true }
	local ONFAIL = { retry = true, npc = true, skip = true, continue = true }
	local SIMPLE = { answer = true, launch = true, auto_board = true, transport = true }

	t.test("every definition is well formed", function()
		for id, def in Operations.Defs do
			t.expect(def.id).toBe(id)
			t.expect(#def.steps >= 3).toBeTruthy()
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
			-- docs/16 K1: answer the call, get aboard, they climb on, bring them home; nothing else
			t.expect(def.steps[1].mechanicId).toBe("answer")
			t.expect(def.steps[#def.steps].mechanicId).toBe("transport")
			for _, s in def.steps do
				t.expect(SIMPLE[s.mechanicId]).toBeTruthy()
			end
		end
	end)

	t.test("every single-crew plan: answer, get aboard, pick them up, bring them home", function()
		for _, def in Operations.Defs do
			if def.isBig then
				continue
			end
			local ids = {}
			for _, s in def.steps do
				table.insert(ids, s.id)
			end
			t.expect(table.concat(ids, ",")).toBe("tasking,launch,recovery,transport")
			local rec = def.steps[3]
			t.expect(rec.mechanicId).toBe("auto_board")
			t.expect(rec.effect).toBe("board")
			t.expect(rec.onFail).toBe("continue") -- a slow pick-up still boards them, at Bronze
			-- one survivor at a time: a full craft goes home and comes back for the rest
			t.expect(rec.perCasualty and def.steps[4].perCasualty).toBe(true)
		end
	end)

	t.test("a picked-up casualty is safe from the slow grade", function()
		local out = Condition.new("a", "Alert", true, 5)
		local safe = Condition.new("b", "Alert", true, 5)
		safe.aboard = true
		t.expect(#Operations.atRisk({ out, safe })).toBe(1)
		t.expect(Condition.overdue(Operations.atRisk({ safe }), 0, 720)).toBe(false)
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

	t.test("condition bands, events and the slow grade", function()
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
		t.expect(Condition.overdue({ c }, 10, 720)).toBe(false)
		c.condition = 19
		t.expect(Condition.overdue({ c }, 10, 720)).toBe(true)
		t.expect(Condition.overdue({ warm }, 721, 720)).toBe(true)
		local v = Condition.new("v", "Vessel", true, 90)
		t.expect(Condition.rate(v) < 0).toBeTruthy()
		v.towed = true
		t.expect(Condition.rate(v)).toBe(0)
	end)

	t.test("step grade is the worst band; missing metrics grade Bronze", function()
		local step = Operations.get("PersonInWater").steps[4] -- transport
		t.expect(step.id).toBe("transport")
		t.expect(Grading.stepGrade(step, { conditionAtEnd = 80 })).toBe("Gold")
		t.expect(Grading.stepGrade(step, { conditionAtEnd = 50 })).toBe("Silver")
		t.expect(Grading.stepGrade(step, { conditionAtEnd = 10 })).toBe("Fail")
		t.expect(Grading.stepGrade(step, {})).toBe("Bronze")
	end)

	t.test("NPC and stub caps", function()
		local tasking = Operations.get("PersonInWater").steps[1]
		t.expect(Grading.resolveStep(tasking, { elapsed = 3 }, { npc = true })).toBe("Silver")
		t.expect(Grading.resolveStep(tasking, { elapsed = 3 }, { stub = true })).toBe("Silver")
		t.expect(Grading.resolveStep(tasking, { elapsed = 30 }, { stub = true })).toBe("Bronze")
		-- push-to-talk: graded on elapsed alone, half weight
		t.expect(Grading.resolveStep(tasking, { elapsed = 3 })).toBe("Gold")
		t.expect(tasking.weight).toBe(0.5)
		local recovery = Operations.get("RipCurrent").steps[3]
		t.expect(recovery.id).toBe("recovery")
		-- stub: graded on server metrics only (elapsed)
		t.expect(Grading.resolveStep(recovery, { elapsed = 5 }, { stub = true })).toBe("Silver")
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
		local gold = Grading.payout(1.3, "Gold", 3)
		t.expect(gold.cash).toBe(math.floor(550 * 1.3 * 1.25 * 1.2 + 0.5))
		t.expect(Grading.payout(1, "Gold", 9).cash).toBe(math.floor(550 * 1.25 * 1.3 + 0.5))
		t.expect(Grading.payout(1, "Bronze", 1, 0).cash).toBe(500) -- tutorial chain
		t.expect(Grading.payout(1, "Bronze", 1, 2).cash).toBe(600)
		t.expect(Grading.payout(1, "Bronze", 1, 3).cash).toBe(math.floor(550 * 0.75 + 0.5))
		t.expect(Grading.shareWithoutStep(1).cash).toBe(55)
		t.expect(Grading.bigCasualtyPay().cash).toBe(165)
		t.expect(Grading.bigCompletionBonus(5, 10).cash).toBe(688)
	end)

	t.test("rolls", function()
		t.expect(Operations.roll({ A = 1, B = 1 }, 0)).toBe("A")
		t.expect(Operations.roll({ A = 1, B = 1 }, 0.99)).toBe("B")
		t.expect(Operations.FromCallKind.Tow).toBeNil() -- the tow op is gone (docs/16 C2)
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

	t.test("debrief mastery: stars, time and the three masteries", function()
		local steps = {
			{ id = "tasking", grade = "Gold", at = 2 },
			{ id = "recovery", grade = "Gold", at = 50 },
			{ id = "transport", grade = "Silver", at = 95 },
			{ id = "recovery", grade = "Gold", at = 130 },
			{ id = "transport", grade = "Gold", at = 170 },
		}
		local m = Grading.mastery("Silver", steps, 2, 2)
		t.expect(m.stars).toBe(2)
		t.expect(m.seconds).toBe(170)
		t.expect(m.fast).toBe(true)
		t.expect(m.smooth).toBe(false) -- one bumpy ride
		t.expect(m.all).toBe(true)
		t.expect(Grading.mastery("Gold", steps, 1, 2).all).toBe(false)
		local lost = Grading.mastery("Fail", steps, 2, 2)
		t.expect(lost.stars).toBe(0)
		t.expect(lost.fast or lost.all or lost.smooth).toBe(false)
		local bare = Grading.mastery("Gold", { { id = "tasking", grade = "Gold" } }, 0, 1)
		t.expect(bare.fast).toBe(false)
	end)

	t.test("every step label is at most two words (docs/16 K4)", function()
		for id, def in Operations.Defs do
			for _, s in def.steps do
				local n = select(2, string.gsub(s.label, "%S+", ""))
				t.expect(n <= 2).toBe(true)
				if n > 2 then
					error(`{id}.{s.id}: "{s.label}"`)
				end
			end
		end
	end)
end
