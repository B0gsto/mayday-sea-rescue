-- Ferry triage sieve (src/shared/Ferry/Triage.luau): the sieve agrees with the server's tag.
return function(t)
	local Triage = t.load("src/shared/Ferry/Triage.luau")
	local Operations = t.load("src/shared/Ops/Operations.luau")

	t.test("the sieve on generated cues matches Operations.triageTag for every state", function()
		for _, state in { "Alert", "Exhausted", "Panicking", "VeryCold", "Unresponsive" } do
			for seed = 1, 60 do
				local o = Triage.observe(state, seed)
				t.expect(o.breathing).toBe(true)
				t.expect(Triage.sieve(o)).toBe(Operations.triageTag(state))
			end
		end
	end)

	t.test("sieve thresholds", function()
		local base = {
			walks = false,
			breathing = true,
			airwayOpened = true,
			avpu = "Alert",
			rate = 16,
			refill = 1.2,
			cue = "",
		}
		t.expect(Triage.sieve(base)).toBe("Yellow")
		local w = table.clone(base)
		w.walks = true
		t.expect(Triage.sieve(w)).toBe("Green")
		local slow = table.clone(base)
		slow.rate = 9
		t.expect(Triage.sieve(slow)).toBe("Red")
		local fast = table.clone(base)
		fast.rate = 30
		t.expect(Triage.sieve(fast)).toBe("Red")
		local refill = table.clone(base)
		refill.refill = 2.5
		t.expect(Triage.sieve(refill)).toBe("Red")
		local u = table.clone(base)
		u.avpu = "Unresponsive"
		t.expect(Triage.sieve(u)).toBe("Red")
	end)

	t.test("no black or expectant tag is ever shown", function()
		t.expect(#Triage.Tags).toBe(3)
		for _, tag in Triage.Tags do
			local name = string.lower(Triage.Display[tag].name)
			t.expect(string.find(name, "dead") == nil and string.find(name, "black") == nil)
				.toBeTruthy()
		end
		t.expect(Triage.Display.Red.code).toBe("P1")
	end)

	t.test("checks needed, in sieve order", function()
		t.expect(#Triage.checksNeeded(Triage.observe("Alert", 3))).toBe(1)
		local need = Triage.checksNeeded(Triage.observe("Exhausted", 3))
		t.expect(need[#need]).toBe("refill")
		t.expect(need).toEqual({ "walk", "airway", "responsive", "rate", "refill" })
	end)

	t.test("breath counting", function()
		t.expect(Triage.risesIn15(8)).toBe(2)
		t.expect(Triage.estimateRate(5)).toBe(20)
		t.expect(Triage.countError(20, 20)).toBe(0)
		t.expect(Triage.countError(20, 16)).toBeCloseTo(0.2, 1e-6)
	end)

	t.test("drift and evacuation order", function()
		t.expect(Triage.driftFactor("Green", "Red")).toBeCloseTo(1.7, 1e-6)
		t.expect(Triage.driftFactor("Red", "Green")).toBe(1)
		t.expect(Triage.driftFactor(nil, "Red")).toBe(1)
		local order = Triage.evacuationOrder({
			{ index = 1, tag = "Green", condition = 30 },
			{ index = 2, tag = "Red", condition = 60 },
			{ index = 3, tag = "Yellow", condition = 50 },
			{ index = 4, tag = "Red", condition = 40 },
		})
		t.expect(order).toEqual({ 4, 2, 3, 1 })
	end)
end
