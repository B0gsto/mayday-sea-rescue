-- Lighthouses: the docs/03 section 7 catalogue, gates, mission steps and profile flags.
return function(t)
	local Lighthouses = t.load("src/shared/Lighthouses.luau")
	local Rules = t.load("src/shared/ProgressionRules.luau")
	local NextGoal = t.load("src/shared/NextGoal.luau")

	local NOW = 1792800000 + 10 * 86400

	local function snap(rep: number, certs: { string }, flags: any?): any
		local d = Rules.defaultData()
		d.rep = rep
		d.flags = flags or {}
		for _, id in certs do
			d.certs[id] = true
		end
		return Rules.snapshot(d)
	end

	t.test("only the lights on the current map are listed", function()
		local ids = {}
		for _, light in Lighthouses.List do
			table.insert(ids, light.id)
			-- both towers stand inside the 2,500-stud playable map
			t.expect(light.position.Magnitude < 2500).toBe(true)
			t.expect(light.approach.Magnitude < 2500).toBe(true)
		end
		t.expect(ids).toEqual({ "HarbourLight", "SkerryLight" })
		t.expect(Lighthouses.get("GannetRockLight")).toBeNil()
		t.expect(Lighthouses.get("TempestPointLight")).toBeNil()
	end)

	t.test("the relit radio line is six words or fewer", function()
		for _, light in Lighthouses.List do
			local words = 0
			for _ in string.gmatch(light.radio, "%S+") do
				words += 1
			end
			t.expect(words <= 6).toBe(true)
		end
	end)

	t.test("gates follow docs 03: rank, certification, Rep, then the previous light", function()
		local recruit = snap(0, {})
		local ok, why = Lighthouses.canStart(recruit, "HarbourLight")
		t.expect(ok).toBe(false)
		t.expect(why).toBe("Needs Lifeguard")

		-- the Rep alone is not enough: the Helm certification is the rank's other half
		local noHelm = snap(400, {})
		t.expect(Lighthouses.canStart(noHelm, "HarbourLight")).toBe(false)

		local lifeguard = snap(400, { "Helm" })
		t.expect(Lighthouses.canStart(lifeguard, "HarbourLight")).toBe(true)
		local lit = { lighthouses = { HarbourLight = true } }

		-- Skerry Light needs Rescue Swimmer rank, its certification, and the Harbor Light lit
		local swimmer = snap(900, { "Helm", "CasualtyCare", "RescueSwimmer" })
		local skerryOk, skerryWhy = Lighthouses.canStart(swimmer, "SkerryLight")
		t.expect(skerryOk).toBe(false)
		t.expect(skerryWhy).toBe("Light Harbor Light first")
		t.expect(Lighthouses.canStart(
			snap(900, {
				"Helm",
				"CasualtyCare",
				"RescueSwimmer",
			}, lit),
			"SkerryLight"
		)).toBe(true)
	end)

	t.test("relit lights persist and open their zone for calls", function()
		local flags = {}
		t.expect(Lighthouses.isLit(flags, "HarbourLight")).toBe(false)
		t.expect(Lighthouses.zoneOpen(flags, "Outer")).toBe(false)
		local after = Lighthouses.withLit(flags, "HarbourLight")
		t.expect(after.HarbourLight).toBe(true)
		t.expect(Lighthouses.isLit(after, "HarbourLight")).toBe(true)
		t.expect(Lighthouses.zoneOpen(after, "Outer")).toBe(true)
		t.expect(Lighthouses.zoneOpen(after, "Near")).toBe(true)
		-- withLit returns only the lighthouses sub-table, ready for ProgressionService.SetFlag
		local saved = Rules.migrate({ flags = { lighthouses = after } })
		t.expect(saved.flags.lighthouses).toEqual({ HarbourLight = true })
		t.expect(Lighthouses.next(after).id).toBe("SkerryLight")
		t.expect(Lighthouses.next(Lighthouses.withLit(after, "SkerryLight"))).toBeNil()
	end)

	t.test("every mission is an Ops definition built from live mechanics", function()
		for _, light in Lighthouses.List do
			local def = light.mission
			t.expect(def.id).toBe(light.mission.id)
			t.expect(def.weight).toBe(0) -- story, not a rescue
			t.expect(def.states.Vessel).toBe(1)
			t.expect(def.steps[1].mechanicId).toBe("radio_ack")
			t.expect(def.steps[#def.steps].mechanicId).toBe("lighthouse_crank")
			local seen = {}
			for _, step in def.steps do
				t.expect(seen[step.id]).toBeNil()
				seen[step.id] = true
				t.expect(step.weight > 0).toBe(true)
				t.expect(#step.gradeBands >= 1).toBe(true)
			end
			t.expect(seen.kit_launch).toBe(true)
			t.expect(seen.passage).toBe(true)
			t.expect(Lighthouses.missionLight(def.id)).toBe(light)
		end
	end)

	t.test("NextGoal offers the next ready, unlit light", function()
		local goals = NextGoal.goals(snap(400, { "Helm" }), NOW)
		local lightGoal
		for _, goal in goals do
			if goal.kind == "Light" then
				lightGoal = goal
			end
		end
		t.expect(lightGoal).toBeTruthy()
		t.expect(lightGoal.key).toBe("Light:HarbourLight")
		t.expect(lightGoal.label).toBe("Harbor Light")
	end)
end
