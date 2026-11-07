-- Fuel (docs/31 C): the tank, the rating, the burn, and the reach table straight from the doc.
return function(t)
	local Fuel = t.load("src/shared/Boat/Fuel.luau")
	local BoatLevels = t.load("src/shared/BoatLevels.luau")
	local SeaZones = t.load("src/shared/Calls/SeaZones.luau")
	local RingLayout = t.load("src/shared/Config/RingLayout.luau")
	local WorldConfig = t.load("src/shared/Config/WorldConfig.luau")
	local BERTH = RingLayout.Ring + 255 -- r ~1,115, as tests/Pacing
	local function line(zone: number): number
		return SeaZones.Zones[zone].outer
	end
	local function near(a: number, b: number, tol: number)
		if math.abs(a - b) > tol then
			error(string.format("%.2f is not within %g of %.2f", a, tol, b), 2)
		end
	end

	t.test("tank and rating per level", function()
		for _, row in
			{
				{ 1, 24, 2 },
				{ 5, 25.6, 2 },
				{ 10, 27.6, 2 },
				{ 11, 28, 3 },
				{ 20, 31.6, 3 },
				{ 21, 32, 4 },
				{ 30, 35.6, 4 },
				{ 31, 36, 5 },
				{ 50, 43.6, 5 },
			}
		do
			near(Fuel.tank(row[1]), row[2], 1e-6)
			t.expect(Fuel.rating(row[1])).toBe(row[3])
		end
		t.expect(Fuel.tank("junk")).toBe(24) -- a corrupt level reads as L1
	end)

	t.test("factor: free Shallows, x1 to the rating, x5 one past, x25 beyond", function()
		t.expect(Fuel.factor(1, 1)).toBe(0)
		t.expect(Fuel.factor(2, 1)).toBe(1)
		t.expect(Fuel.factor(3, 1)).toBe(5)
		t.expect(Fuel.factor(4, 1)).toBe(25)
		t.expect(Fuel.factor(5, 1)).toBe(25)
		t.expect(Fuel.factor(5, 21)).toBe(5)
		t.expect(Fuel.factor(5, 50)).toBe(1)
	end)

	t.test("burn: idle is free, a boost costs no more than full throttle", function()
		t.expect(Fuel.burn(1, 0, 2, 1)).toBe(0)
		t.expect(Fuel.burn(2, 0.5, 2, 1)).toBe(1)
		t.expect(Fuel.burn(1, 1.6, 3, 1)).toBe(5)
		t.expect(Fuel.burn(1, 1, 1, 1)).toBe(0)
		t.expect(Fuel.burn(1, -1, 4, 1)).toBe(0)
	end)

	t.test("docs/31 C reach table (straight dash from the berth on a full tank)", function()
		near(Fuel.reach(1, BERTH), line(2) + 140, 10) -- Coral line + 140
		near(Fuel.reach(5, BERTH), line(3), 10) -- Storm line, then empty
		near(Fuel.reach(10, BERTH), line(3) + 190, 10) -- 190 into Storm
		near(Fuel.reach(11, BERTH), line(4) + 170, 10) -- 170 into Abyss
		near(Fuel.reach(20, BERTH), line(4) + 450, 10) -- 450 into Abyss
		for _, level in { 21, 31, 50 } do -- to the map edge and anywhere
			t.expect(Fuel.reach(level, BERTH) >= WorldConfig.MapRadius).toBe(true)
		end
		-- a new player sees the Storm line at most; the Abyss opens at L11 (a dash) and L21 (the edge)
		for level = 1, 10 do
			t.expect(Fuel.reach(level, BERTH) < line(4)).toBe(true)
		end
		-- inside the Shallows nothing burns: the tank still covers the whole band out
		t.expect(Fuel.reach(1, 0) > line(1)).toBe(true)
	end)

	t.test("every row has a tank that grows with the level", function()
		for level = 2, BoatLevels.MAX do
			t.expect(BoatLevels.Rows[level].tank > BoatLevels.Rows[level - 1].tank).toBe(true)
		end
	end)
end
