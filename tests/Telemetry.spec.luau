-- Telemetry (RP-A1): the onboarding funnel numbering, economy mapping and the custom events one
-- finished operation sends (src/server/Services/Telemetry/Events.luau, pure).
return function(t)
	local Events = t.load("src/server/Services/Telemetry/Events.luau")

	local function facts(over)
		local f = {
			kind = "PersonInWater",
			grade = "Gold",
			reason = "Complete",
			helped = true,
			coldOpen = false,
			exercise = false,
			storm = false,
			big = false,
		}
		for k, v in over or {} do
			f[k] = v
		end
		return f
	end

	t.test("the onboarding funnel is numbered 1..n in order with unique names", function()
		local seen = {}
		for i, s in Events.Funnel do
			t.expect(s.step).toBe(i)
			t.expect(seen[s.name]).toBe(nil)
			seen[s.name] = true
			t.expect(Events.funnelStep(s.name).step).toBe(i)
		end
		t.expect(Events.funnelStep("Joined").step).toBe(1)
		t.expect(Events.funnelStep("Nope")).toBe(nil)
		-- every cold open step id maps onto a funnel step, between started and ended
		for _, name in Events.ColdOpenSteps do
			local s = Events.funnelStep(name)
			t.expect(s ~= nil).toBe(true)
			t.expect(s.step > Events.funnelStep("ColdOpenStarted").step).toBe(true)
			t.expect(s.step < Events.funnelStep("ColdOpenEnded").step).toBe(true)
		end
	end)

	t.test("the session tracker lets each key through once", function()
		local tr = Events.newTracker()
		t.expect(Events.first(tr, "Funnel:Joined")).toBe(true)
		t.expect(Events.first(tr, "Funnel:Joined")).toBe(false)
		t.expect(Events.first(tr, "Storm:1")).toBe(true)
		t.expect(Events.first(tr, "Storm:2")).toBe(true)
	end)

	t.test("Cash sources map to Roblox transaction types with low-cardinality SKUs", function()
		local tx, sku = Events.cashSource("Purchase:CrewPayroll")
		t.expect(tx).toBe("IAP")
		t.expect(sku).toBe("CrewPayroll")
		tx, sku = Events.cashSource("Purchase:StarterKit")
		t.expect(tx).toBe("IAP")
		t.expect(sku).toBe("StarterKit")
		tx, sku = Events.cashSource("Op:PersonInWater")
		t.expect(tx).toBe("Gameplay")
		t.expect(sku).toBe("Op:PersonInWater")
		tx = Events.cashSource("Exercise:ExerciseSwimTest")
		t.expect(tx).toBe("Onboarding")
		tx, sku = Events.cashSource("Logbook: The Morwenna")
		t.expect(tx).toBe("Gameplay")
		t.expect(sku).toBe("Logbook")
		tx, sku = Events.cashSource(nil)
		t.expect(tx).toBe("Gameplay")
		t.expect(sku).toBe("Unknown")
		t.expect(#select(2, Events.cashSource("Op:" .. string.rep("x", 200))) <= Events.MAX_FIELD)
			.toBe(true)
		tx, sku = Events.cashSink("Vehicle", "Rib")
		t.expect(tx).toBe("Shop")
		t.expect(sku).toBe("Vehicle:Rib")
	end)

	t.test("economy amounts are whole and positive", function()
		t.expect(Events.amount(149.6)).toBe(150)
		t.expect(Events.amount(0)).toBe(nil)
		t.expect(Events.amount(-20)).toBe(nil)
		t.expect(Events.amount(0 / 0)).toBe(nil)
		t.expect(Events.amount("12")).toBe(nil)
	end)

	t.test("a graded rescue sends OpGrade only, and counts as the first op", function()
		local out = Events.opEvents(facts({ grade = "Silver", storm = true }))
		t.expect(#out).toBe(1)
		t.expect(out[1].name).toBe("OpGrade")
		t.expect(out[1].value).toBe(2)
		t.expect(out[1].fields.CustomField01).toBe("PersonInWater")
		t.expect(out[1].fields.CustomField02).toBe("Silver")
		t.expect(out[1].fields.CustomField03).toBe("Storm")
		t.expect(Events.countsAsFirstOp(facts())).toBe(true)
	end)

	t.test("timeouts, takeovers and Fail grades send OpFailed with the reason", function()
		local out = Events.opEvents(facts({ reason = "Timer", grade = "Bronze" }))
		t.expect(#out).toBe(2)
		t.expect(out[2].name).toBe("OpFailed")
		t.expect(out[2].fields.CustomField02).toBe("Timer")
		out = Events.opEvents(facts({ grade = "Fail" }))
		t.expect(out[1].value).toBe(0)
		t.expect(out[2].fields.CustomField02).toBe("GradeFail")
		-- someone on the op who never did a step: no grade, still the failure
		out = Events.opEvents(facts({ reason = "Takeover", grade = "Takeover", helped = false }))
		t.expect(#out).toBe(1)
		t.expect(out[1].name).toBe("OpFailed")
		t.expect(out[1].fields.CustomField02).toBe("Takeover")
		t.expect(Events.countsAsFirstOp(facts({ reason = "Timer" }))).toBe(false)
	end)

	t.test("the cold open and exercises are tagged and never the first op", function()
		local out = Events.opEvents(facts({ coldOpen = true }))
		t.expect(out[1].fields.CustomField03).toBe("ColdOpen")
		t.expect(Events.countsAsFirstOp(facts({ coldOpen = true }))).toBe(false)
		out = Events.opEvents(facts({ exercise = true }))
		t.expect(out[1].fields.CustomField03).toBe("Exercise")
		t.expect(Events.countsAsFirstOp(facts({ exercise = true }))).toBe(false)
		t.expect(Events.countsAsFirstOp(facts({ helped = false }))).toBe(false)
	end)

	t.test("StormJoined carries the storm type and whether the player arrived mid-storm", function()
		local e = Events.stormJoined(true, false)
		t.expect(e.name).toBe("StormJoined")
		t.expect(e.fields.CustomField01).toBe("Great")
		t.expect(e.fields.CustomField02).toBe("Start")
		t.expect(Events.stormJoined(false, true).fields.CustomField02).toBe("MidStorm")
		t.expect(Events.stormKey(7)).toBe("Storm:7")
	end)
end
