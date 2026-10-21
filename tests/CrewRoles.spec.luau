-- CrewRoles (G30): roles come from what a crew member does, not from a menu (docs 09 4.1).
-- One helm seat and one of each kit item; taking it takes the role, another taker hands it over.
return function(t)
	local CrewRoles = t.load("src/shared/CrewRoles.luau")

	local function state(id: number, flags: { [string]: boolean }?): any
		local s: any = { id = id }
		for key, value in flags or {} do
			s[key] = value
		end
		return s
	end

	-- set-like compare of a role list
	local function sameRoles(got: { string }, want: { string }): boolean
		if #got ~= #want then
			return false
		end
		for _, role in want do
			if not table.find(got, role) then
				return false
			end
		end
		return true
	end

	t.test("doing nothing earns no role", function()
		t.expect(#CrewRoles.of(state(1))).toBe(0)
		t.expect(CrewRoles.primary({})).toBeNil()
	end)

	t.test("the helm seat is Helm", function()
		t.expect(sameRoles(CrewRoles.of(state(1, { helm = true })), { "Helm" })).toBe(true)
	end)

	t.test("the chart table and the tablet are Navigator", function()
		t.expect(sameRoles(CrewRoles.of(state(1, { chart = true })), { "Navigator" })).toBe(true)
		t.expect(sameRoles(CrewRoles.of(state(1, { tablet = true })), { "Navigator" })).toBe(true)
	end)

	t.test("water and the drysuit are Crew (shown as Swimmer)", function()
		t.expect(sameRoles(CrewRoles.of(state(1, { water = true })), { "Crew" })).toBe(true)
		t.expect(sameRoles(CrewRoles.of(state(1, { drysuit = true })), { "Crew" })).toBe(true)
		t.expect(CrewRoles.Labels.Crew).toBe("Swimmer")
	end)

	t.test("the med bag is Medic; a swimmer may also carry it", function()
		t.expect(sameRoles(CrewRoles.of(state(1, { medbag = true })), { "Medic" })).toBe(true)
		t.expect(
			sameRoles(CrewRoles.of(state(1, { water = true, medbag = true })), { "Crew", "Medic" })
		)
			.toBe(true)
	end)

	t.test("roles are in step order and the icon picks the first", function()
		local roles =
			CrewRoles.of(state(1, { medbag = true, water = true, tablet = true, helm = true }))
		t.expect(table.concat(roles, ",")).toBe("Helm,Navigator,Crew,Medic")
		t.expect(CrewRoles.primary(roles)).toBe("Helm")
		t.expect(CrewRoles.primary({ "Crew", "Medic" })).toBe("Crew")
		t.expect(CrewRoles.primary({ "Medic" })).toBe("Medic")
		t.expect(CrewRoles.has({ "Crew", "Medic" }, "Medic")).toBe(true)
		t.expect(CrewRoles.has({ "Crew" }, "Medic")).toBe(false)
	end)

	t.test("solo holds every role implicitly", function()
		t.expect(sameRoles(CrewRoles.implicit(), { "Helm", "Navigator", "Crew", "Medic" }))
			.toBe(true)
	end)

	t.test("one med bag: the first carrier keeps it, the second is only a swimmer", function()
		local roles = CrewRoles.resolve({
			state(10, { medbag = true, water = true }),
			state(20, { medbag = true }),
		})
		t.expect(sameRoles(roles[10], { "Crew", "Medic" })).toBe(true)
		t.expect(#roles[20]).toBe(0)
	end)

	t.test("handover: grabbing the bag takes Medic from the carrier", function()
		local before = { state(10, { medbag = true }), state(20) }
		local after = CrewRoles.takeTool(before, 20, "MedBag")
		t.expect(sameRoles(CrewRoles.of(after[1]), {})).toBe(true)
		t.expect(sameRoles(CrewRoles.of(after[2]), { "Medic" })).toBe(true)
		-- the input is pure: the old table is untouched
		t.expect(CrewRoles.of(before[1])[1]).toBe("Medic")
	end)

	t.test("putting the bag down drops the role", function()
		local before = { state(10, { medbag = true }), state(20) }
		local after = CrewRoles.releaseTool(before, 10, "MedBag")
		t.expect(#CrewRoles.of(after[1])).toBe(0)
	end)

	t.test("one drysuit: a second wearer does not gain Crew from it", function()
		local roles = CrewRoles.resolve({
			state(10, { drysuit = true }),
			state(20, { drysuit = true }),
		})
		t.expect(sameRoles(roles[10], { "Crew" })).toBe(true)
		t.expect(#roles[20]).toBe(0)
		-- ... but water still earns it, whatever the suit
		local wet = CrewRoles.resolve({
			state(10, { drysuit = true }),
			state(20, { drysuit = true, water = true }),
		})
		t.expect(sameRoles(wet[20], { "Crew" })).toBe(true)
	end)

	t.test("swapping seats at rest: only the new occupant is Helm", function()
		local before = { state(10, { helm = true }), state(20, { chart = true }) }
		local after = CrewRoles.takeHelm(before, 20)
		t.expect(#CrewRoles.of(after[1])).toBe(0)
		t.expect(sameRoles(CrewRoles.of(after[2]), { "Navigator", "Helm" })).toBe(true)
	end)
end
