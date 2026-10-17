-- OSC scene board (src/shared/Ferry/SceneBoard.luau): METHANE cards and task cover.
return function(t)
	local SceneBoard = t.load("src/shared/Ferry/SceneBoard.luau")
	local facts = {
		zoneName = "Harbour Approaches",
		bearing = "south of the mouth",
		casualties = 16,
		storm = true,
	}

	t.test("METHANE has seven lines with one right answer each", function()
		local lines = SceneBoard.methane(facts, 5)
		t.expect(#lines).toBe(7)
		local letters = ""
		local answers = {}
		for i, l in lines do
			letters ..= l.letter
			t.expect(#l.options).toBe(3)
			t.expect(l.options[l.answer] ~= nil).toBeTruthy()
			answers[i] = l.answer
		end
		t.expect(letters).toBe("METHANE")
		t.expect(SceneBoard.reportScore(lines, answers)).toBe(1)
		t.expect(SceneBoard.reportScore(lines, {})).toBe(0)
	end)

	t.test("answers move between seeds", function()
		local a, b = SceneBoard.methane(facts, 0), SceneBoard.methane(facts, 1)
		local moved = false
		for i = 1, 7 do
			moved = moved or a[i].answer ~= b[i].answer
		end
		t.expect(moved).toBeTruthy()
	end)

	t.test("estimates and compass", function()
		t.expect(SceneBoard.estimate(7)).toBe("about 7")
		t.expect(SceneBoard.estimate(16)).toBe("about 15")
		t.expect(SceneBoard.compass(Vector3.new(10, 0, 0))).toBe("east")
		t.expect(SceneBoard.compass(Vector3.new(0, 0, 10))).toBe("south")
		t.expect(SceneBoard.compass(Vector3.new(0, 0, -10))).toBe("north")
	end)

	t.test("sectors lie downwind of the hull", function()
		local hull = Vector3.new(100, 0, 100)
		local wind = math.rad(30)
		local d = SceneBoard.downwind(wind)
		local c = SceneBoard.sectorCentres(hull, wind, 100)
		for _, id in { "sectorA", "sectorB", "sectorC", "reception" } do
			t.expect((c[id] - hull):Dot(d) > 0).toBeTruthy()
		end
		t.expect((c.standby - hull):Dot(d) < 0).toBeTruthy()
	end)

	t.test("tasks covered and the NPC fill-in", function()
		t.expect(SceneBoard.tasksCovered({})).toBe(0)
		t.expect(SceneBoard.tasksCovered({ u1 = "sectorA", u2 = "standby" })).toBeCloseTo(0.2, 1e-6)
		local auto = SceneBoard.autoAssign({ "a", "b", "c", "d", "e", "f" })
		t.expect(SceneBoard.tasksCovered(auto)).toBe(1)
		t.expect(auto.f).toBe("standby")
		local sitrep = SceneBoard.sitrep("Haven Rescue", SceneBoard.methane(facts, 2), {})
		t.expect(#sitrep).toBe(9)
	end)
end
