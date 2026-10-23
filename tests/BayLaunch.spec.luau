-- BayLaunch (K3): the bay's one Launch prompt spawns the last-used craft, else the first usable one.
-- BosunGuide (K14): he points after 8 s idle on a craft, then every REPEAT s.
return function(t)
	local B = t.load("src/shared/Boat/BayLaunch.luau")
	local G = t.load("src/shared/Dog/BosunGuide.luau")
	local order = { "JetSki", "RiptideX", "RIB", "Lifeboat" }
	local function owns(set)
		return function(id)
			return set[id] == true
		end
	end

	t.test("last-used craft wins while usable", function()
		t.expect(B.pick("RIB", order, owns({ JetSki = true, RIB = true }))).toBe("RIB")
	end)

	t.test("unusable or missing last craft falls back to shop order", function()
		t.expect(B.pick("Lifeboat", order, owns({ JetSki = true }))).toBe("JetSki")
		t.expect(B.pick(nil, order, owns({ RIB = true }))).toBe("RIB")
		t.expect(B.pick(42, order, owns({ JetSki = true }))).toBe("JetSki")
		t.expect(B.pick("RIB", order, owns({}))).toBe(nil)
	end)

	t.test("Bosun points at 8 s idle on a craft, then every REPEAT s", function()
		local s = G.new()
		t.expect(G.step(s, 7, true, 0)).toBe(false)
		t.expect(G.step(s, 1, true, 0)).toBe(true)
		t.expect(G.step(s, G.REPEAT - 0.5, true, 0)).toBe(false)
		t.expect(G.step(s, 0.5, true, 0)).toBe(true)
	end)

	t.test("moving or off the craft resets the idle timer", function()
		local s = G.new()
		t.expect(G.step(s, 7, true, 0)).toBe(false)
		t.expect(G.step(s, 1, true, G.SLOW + 1)).toBe(false)
		t.expect(G.step(s, 7, true, 0)).toBe(false)
		t.expect(G.step(s, 1, false, 0)).toBe(false)
		t.expect(G.step(s, 8, true, 0)).toBe(true)
	end)

	t.test("nearest is by flat distance", function()
		local from = Vector3.new(0, 50, 0)
		local near = Vector3.new(10, -40, 0)
		t.expect(G.nearest(from, { Vector3.new(0, 0, 30), near })).toBe(near)
		t.expect(G.nearest(from, {})).toBe(nil)
	end)
end
