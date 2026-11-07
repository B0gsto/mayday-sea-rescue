-- SeaZones (docs/29 B): the five circles, the crossing rule, the buoy line.
return function(t)
	local SeaZones = t.load("src/shared/Calls/SeaZones.luau")
	local RingLayout = t.load("src/shared/Config/RingLayout.luau")

	local function at(r: number): Vector3
		return RingLayout.Center + Vector3.new(r, 0, 0)
	end

	t.test("zoneAt reads the radius table", function()
		for _, row in
			{
				{ 0, 1 },
				{ 1599, 1 },
				{ 1600, 2 },
				{ 2799, 2 },
				{ 2800, 3 },
				{ 4000, 4 },
				{ 5200, 5 },
				{ 7000, 5 },
			}
		do
			local i, zone = SeaZones.zoneAt(at(row[1]))
			t.expect(i).toBe(row[2])
			t.expect(zone).toBe(SeaZones.Zones[row[2]])
		end
	end)

	t.test("every rarity table sums to 100 and further is better", function()
		local lastAvg, lastPay = 0, 0
		for _, zone in SeaZones.Zones do
			local sum, avg = 0, 0
			for r, weight in zone.weights do
				sum += weight
				avg += r * weight
			end
			t.expect(#zone.weights).toBe(6)
			t.expect(sum).toBeCloseTo(100, 1e-9)
			t.expect(avg > lastAvg and zone.pay > lastPay).toBe(true)
			lastAvg, lastPay = avg, zone.pay
		end
		t.expect(SeaZones.weightsAt(at(6000))).toBe(SeaZones.Zones[5].weights)
	end)

	t.test("the banner gem is the zone's best rarity", function()
		local Rarity = t.load("src/shared/Rarity.luau")
		for _, zone in SeaZones.Zones do
			local best = 1
			for r, weight in zone.weights do
				best = if weight > 0 then r else best
			end
			t.expect(zone.gem).toBe("gem_" .. string.lower(Rarity.TIERS[best].name))
		end
	end)

	t.test("a crossing needs HYSTERESIS past the line, both ways, once", function()
		local h = SeaZones.HYSTERESIS
		t.expect(SeaZones.step(1, at(1600 + h - 1))).toBe(1)
		t.expect(SeaZones.step(1, at(1600 + h + 1))).toBe(2)
		t.expect(SeaZones.step(2, at(1600 - h + 1))).toBe(2)
		t.expect(SeaZones.step(2, at(1600 - h - 1))).toBe(1)
		t.expect(SeaZones.step(1, at(6000))).toBe(5) -- a jump (respawn) lands straight in the zone
		t.expect(SeaZones.step(5, at(100))).toBe(1)
	end)

	t.test("the look eases to the target in about 2 s, from neutral", function()
		local look = table.clone(SeaZones.NEUTRAL)
		for _ = 1, 20 do
			SeaZones.ease(look, SeaZones.Zones[5], 0.1)
		end
		t.expect(
			math.abs(look.density - SeaZones.Zones[5].density) < 0.05 * SeaZones.Zones[5].density
		)
			.toBe(true)
		t.expect(look.waterMix > 0.95).toBe(true)
		for _ = 1, 40 do
			SeaZones.ease(look, SeaZones.NEUTRAL, 0.1)
		end
		t.expect(look.waterMix < 0.01 and look.overcast < 0.01).toBe(true)
	end)

	t.test(
		"the look blends by distance across a line: no pop, pure mid-band, further is foggier and darker",
		function()
			local b = SeaZones.BLEND
			for i = 1, 4 do
				local line = SeaZones.Zones[i].outer
				t.expect(SeaZones.lookAt(at(line - b)).density)
					.toBeCloseTo(SeaZones.Zones[i].density, 1e-9)
				t.expect(SeaZones.lookAt(at(line + b)).density)
					.toBeCloseTo(SeaZones.Zones[i + 1].density, 1e-9)
				local mid = (SeaZones.Zones[i].density + SeaZones.Zones[i + 1].density) / 2
				t.expect(SeaZones.lookAt(at(line - 1e-3)).density).toBeCloseTo(mid, 1e-4)
				t.expect(SeaZones.lookAt(at(line + 1e-3)).density).toBeCloseTo(mid, 1e-4)
				-- 10-stud steps never jump: at most 10 / (2 BLEND) * 1.5 (smoothstep's peak slope) of the gap
				local prev = SeaZones.lookAt(at(line - b - 20)).hazeAdd
				for r = line - b - 10, line + b + 20, 10 do
					local now = SeaZones.lookAt(at(r)).hazeAdd
					t.expect(
						math.abs(now - prev)
							<= 1e-9
								+ 10 / (2 * b) * 1.5 * math.abs(
									SeaZones.Zones[i + 1].hazeAdd - SeaZones.Zones[i].hazeAdd
								)
					).toBe(true)
					prev = now
				end
				t.expect(SeaZones.Zones[i + 1].density > SeaZones.Zones[i].density).toBe(true)
				t.expect(SeaZones.Zones[i + 1].exposure <= SeaZones.Zones[i].exposure).toBe(true)
			end
			t.expect(SeaZones.lookAt(at(6000)).waterMix).toBe(1)
		end
	)

	t.test("buoy slots: a multiple of the pool, about SPACING apart, on the line", function()
		for line = 1, 4 do
			local n = SeaZones.slotCount(line)
			t.expect(n % SeaZones.POOL).toBe(0)
			local gap = (SeaZones.slotPoint(line, 1) - SeaZones.slotPoint(line, 0)).Magnitude
			t.expect(gap > 0.8 * SeaZones.SPACING and gap < 1.2 * SeaZones.SPACING).toBe(true)
			local p = SeaZones.slotPoint(line, n // 3)
			t.expect(p.Y).toBe(0)
			local c = RingLayout.Center
			t.expect(Vector3.new(p.X - c.X, 0, p.Z - c.Z).Magnitude)
				.toBeCloseTo(SeaZones.Zones[line].outer, 1e-6)
		end
	end)

	t.test("the line near you is the nearest slot, one line at most, none mid-band", function()
		local line, k = SeaZones.lineNear(at(1500).X, at(1500).Z)
		t.expect(line).toBe(1)
		t.expect(k % SeaZones.slotCount(1)).toBe(0) -- straight out along +X: slot 0
		t.expect((SeaZones.lineNear(at(2200).X, at(2200).Z))).toBe(nil) -- 600 from both lines
		t.expect((SeaZones.lineNear(at(6000).X, at(6000).Z))).toBe(nil)
		-- a window of POOL slots takes each buoy once, across the wrap too
		local n = SeaZones.slotCount(1)
		local used = {}
		for i = -SeaZones.POOL // 2, SeaZones.POOL // 2 - 1 do
			local index = ((0 + i) % n) % SeaZones.POOL
			t.expect(used[index]).toBe(nil)
			used[index] = true
		end
	end)

	t.test("no buoys on an outer island", function()
		local WorldConfig = t.load("src/shared/Config/WorldConfig.luau")
		t.expect(SeaZones.onLand(WorldConfig.Islands[1].center)).toBe(true)
		t.expect(SeaZones.onLand(at(1600))).toBe(false)
	end)
end
