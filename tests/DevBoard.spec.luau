-- Dev board (DevConfig): the access gate, the argument validation and the rate limit.
return function(t)
	local DevConfig = t.load("src/shared/Config/DevConfig.luau")

	t.test("Studio, the listed user and group rank 254+ are allowed", function()
		t.expect(DevConfig.isAllowed(1, 0, true)).toBe(true)
		t.expect(DevConfig.isAllowed(11718681576, 0, false)).toBe(true)
		t.expect(DevConfig.isAllowed(2, 254, false)).toBe(true)
		t.expect(DevConfig.isAllowed(2, 255, false)).toBe(true)
	end)

	t.test("everyone else is denied", function()
		t.expect(DevConfig.isAllowed(2, 253, false)).toBe(false)
		t.expect(DevConfig.isAllowed(2, 0, false)).toBe(false)
		t.expect(DevConfig.isAllowed(2, nil, false)).toBe(false)
		t.expect(DevConfig.isAllowed("11718681576", "255", false)).toBe(false)
		t.expect(DevConfig.isAllowed(nil, nil, false)).toBe(false)
	end)

	t.test("good arguments pass and come back clean", function()
		local ok, args = DevConfig.validate("vehicle", { 42, "JetSki" })
		t.expect(ok).toBe(true)
		t.expect(args[2]).toBe("JetSki")
		t.expect((DevConfig.validate("stats", {}))).toBe(true)
		t.expect((DevConfig.validate("clock", { 13.5 }))).toBe(true)
		t.expect((DevConfig.validate("opEnd", { 7, false }))).toBe(true)
		t.expect((DevConfig.validate("op", { 7, "PersonInWater" }))).toBe(true)
		t.expect((DevConfig.validate("op", { 7, "ColdOpen" }))).toBe(true)
		t.expect((DevConfig.validate("tpSpot", { "Station" }))).toBe(true)
		t.expect((DevConfig.validate("tpPos", { Vector3.new(10, 5, -20) }))).toBe(true)
	end)

	t.test("bad arguments are refused", function()
		local cases = {
			{ "nope", {} },
			{ 5, {} },
			{ "stats", "x" },
			{ "vehicle", { 42 } },
			{ "vehicle", { 42, "JetSki", 1 } },
			{ "vehicle", { 42, "Tank" } },
			{ "vehicle", { "42", "JetSki" } },
			{ "vehicle", { 1.5, "JetSki" } },
			{ "vehicle", { -3, "JetSki" } },
			{ "clock", { 25 } },
			{ "clock", { 2 } }, -- night is off
			{ "clock", { 0 / 0 } },
			{ "award", { 7, -1 } },
			{ "award", { 7, math.huge } },
			{ "build", { 7, "Castle" } },
			{ "god", { "true" } },
			{ "tpSpot", { "Narnia" } },
			{ "tpPos", { { 1, 2, 3 } } },
			{ "tpPos", { Vector3.new(0, 0, 1e9) } },
			{ "tpPos", { Vector3.new(0 / 0, 0, 0) } },
		}
		for _, case in cases do
			t.expect((DevConfig.validate(case[1], case[2]))).toBe(false)
		end
	end)

	t.test("every list the panel shows has ids", function()
		t.expect(#DevConfig.SpotOrder > 10).toBe(true)
		t.expect(table.find(DevConfig.Vehicles, "RIB") ~= nil).toBe(true)
		t.expect(table.find(DevConfig.Ops, "CapsizedFerry") ~= nil).toBe(true)
		t.expect(table.find(DevConfig.Ops, "ColdOpen") ~= nil).toBe(true)
		t.expect(table.find(DevConfig.Events, "GoldenHour") ~= nil).toBe(true)
		for _, id in DevConfig.SpotOrder do
			t.expect(typeof(DevConfig.Spots[id].position)).toBe("Vector3")
		end
	end)

	t.test("the rate limit caps a burst and recovers", function()
		local stamps = {}
		for _ = 1, DevConfig.RateMax do
			t.expect(DevConfig.rateOk(stamps, 100)).toBe(true)
		end
		t.expect(DevConfig.rateOk(stamps, 100.5)).toBe(false)
		t.expect(DevConfig.rateOk(stamps, 100 + DevConfig.RateWindow + 0.1)).toBe(true)
	end)
end
