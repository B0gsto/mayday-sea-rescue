-- OSC scene board (src/shared/Ferry/SceneBoard.luau): sectors and the automatic task cover.
return function(t)
	local SceneBoard = t.load("src/shared/Ferry/SceneBoard.luau")
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

	t.test("tasks covered and the automatic board", function()
		t.expect(SceneBoard.tasksCovered({})).toBe(0)
		t.expect(SceneBoard.tasksCovered({ u1 = "sectorA", u2 = "standby" })).toBeCloseTo(0.2, 1e-6)
		local auto = SceneBoard.autoAssign({ "a", "b", "c", "d", "e", "f" })
		t.expect(SceneBoard.tasksCovered(auto)).toBe(1)
		t.expect(auto.f).toBe("standby")
	end)
end
