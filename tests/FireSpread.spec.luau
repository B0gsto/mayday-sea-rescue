-- FireSpread: the vessel fire's growth, dousing and smoke plume (docs/09 section 8.2).
return function(t)
	local F = t.load("src/shared/Ops/FireSpread.luau")
	local DT = 0.25

	t.test("a fresh fire is small, and an ignored one grows and spreads forward", function()
		local s = F.new()
		t.expect(s.heat > 0.2 and s.spread).toBe(0)
		t.expect(s.doused).toBe(false)
		local start = s.spread
		for _ = 1, math.floor(60 / DT) do
			F.tick(s, DT)
		end
		t.expect(s.heat > 0.6).toBe(true)
		t.expect(s.spread > start).toBe(true)
		for _ = 1, math.floor(240 / DT) do
			F.tick(s, DT)
		end
		t.expect(s.spread > 0.8).toBe(true)
		t.expect(F.flameRate(s) > 20).toBe(true)
		t.expect(F.smokeRate(s) > 15).toBe(true)
	end)

	t.test("a good jet on the base and the boundary knocks it down", function()
		local s = F.new()
		for _ = 1, math.floor(180 / DT) do
			F.tick(s, DT)
		end
		local spread = s.spread
		t.expect(spread > 0.5).toBe(true)
		local left = F.douse(s, 1, 1)
		t.expect(left < spread * 0.3).toBe(true)
		t.expect(s.doused).toBe(true)
		t.expect(F.flameRate(s)).toBe(0)
		t.expect(F.smokeRate(s) < 5).toBe(true)
	end)

	t.test("a poor attack leaves it burning", function()
		local s = F.new()
		for _ = 1, math.floor(120 / DT) do
			F.tick(s, DT)
		end
		local spread = s.spread
		F.douse(s, 0.3, 0.2)
		t.expect(s.spread > spread * 0.5).toBe(true)
		t.expect(s.doused).toBe(false)
	end)

	t.test("a doused fire stops growing", function()
		local s = F.new()
		s.heat = 0.2
		s.spread = 0.1
		s.doused = true
		local spread = s.spread
		for _ = 1, math.floor(60 / DT) do
			F.tick(s, DT)
		end
		t.expect(s.spread).toBe(spread)
	end)

	t.test("wind carries the smoke downwind; the upwind side is clear", function()
		local fire = Vector3.new(0, 0, 0)
		local down = F.downwind(0)
		t.expect(down.X).toBeCloseTo(1, 1e-6)
		t.expect(down.Z).toBeCloseTo(0, 1e-6)
		local inSmoke, angle = F.inPlume(0, fire, Vector3.new(60, 0, 6), 25, 140)
		t.expect(inSmoke).toBe(true)
		t.expect(angle < 10).toBe(true)
		t.expect(F.inPlume(0, fire, Vector3.new(60, 0, 60), 25, 140)).toBe(false)
		t.expect(F.inPlume(0, fire, Vector3.new(200, 0, 0), 25, 140)).toBe(false)
		t.expect(F.inPlume(0, fire, Vector3.new(-30, 0, 0), 25, 140)).toBe(false)
		t.expect(F.upwind(0, fire, Vector3.new(-40, 0, 0))).toBe(true)
		t.expect(F.upwind(0, fire, Vector3.new(40, 0, 0))).toBe(false)
	end)
end
