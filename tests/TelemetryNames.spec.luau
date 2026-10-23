-- TelemetryNames (G64): the fixed analytics name list is unique and inside Roblox's limits.
return function(t)
	local Names = t.load("src/shared/TelemetryNames.luau")
	local Events = t.load("src/server/Services/Telemetry/Events.luau")

	t.test("every custom event name is unique, non-empty and under the name limit", function()
		local seen = {}
		for _, name in Names.Custom do
			t.expect(type(name)).toBe("string")
			t.expect(#name > 0).toBe(true)
			t.expect(#name <= Names.MAX_EVENT_NAME).toBe(true)
			t.expect(seen[name]).toBe(nil)
			seen[name] = true
			t.expect(Names.isCustom(name)).toBe(true)
		end
		t.expect(#Names.Custom <= Names.MAX_EVENTS).toBe(true)
		t.expect(Names.isCustom("NotAnEvent")).toBe(false)
	end)

	t.test("the funnel list is unique and matches Events.Funnel step order", function()
		t.expect(#Names.Funnel).toBe(#Events.Funnel)
		local seen = {}
		for i, name in Names.Funnel do
			t.expect(#name <= Names.MAX_EVENT_NAME).toBe(true)
			t.expect(seen[name]).toBe(nil)
			seen[name] = true
			t.expect(Names.isFunnel(name)).toBe(true)
			t.expect(Events.Funnel[i].name).toBe(name)
		end
		t.expect(Names.isFunnel("NotAStep")).toBe(false)
		t.expect(Names.valid()).toBe(true)
	end)

	t.test("every custom event Events can produce is on the list", function()
		local names = { "OpGrade", "OpFailed", "ColdOpenEnded", "StormJoined" }
		for _, f in
			Events.opEvents({
				kind = "PersonInWater",
				grade = "Fail",
				reason = "Timer",
				helped = true,
				coldOpen = false,
				storm = false,
				big = false,
				rarity = "Common",
			})
		do
			table.insert(names, f.name)
		end
		for _, name in names do
			t.expect(Names.isCustom(name)).toBe(true)
		end
	end)
end
