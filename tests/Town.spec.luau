-- Town: the city-block rules (TownLayout) on the generated Port Haven grid.
return function(t)
	local TownLayout = t.load("src/server/World/TownLayout.luau")
	local WorldConfig = t.load("src/shared/Config/WorldConfig.luau")
	local RoadNet = t.load("src/shared/RoadNet.luau")
	local town = WorldConfig.Towns[1]

	local function overlaps(a, b)
		return a[1] < b[3] and b[1] < a[3] and a[2] < b[4] and b[2] < a[4]
	end

	t.test(
		"Port Haven lots fill the blocks, never overlap each other, a keep rect or a carriageway",
		function()
			local lots = TownLayout.lots(town, nil, TownLayout.southZ(town, WorldConfig.Roads))
			t.expect(#lots > 40).toBe(true)
			for i, a in lots do
				for j = i + 1, #lots do
					t.expect(overlaps(a.rect, lots[j].rect)).toBe(false)
				end
				for _, k in town.keep do
					t.expect(overlaps(a.rect, k)).toBe(false)
				end
				for _, r in WorldConfig.Roads do
					for _, c in { { a.rect[1], a.rect[2] }, { a.rect[3], a.rect[4] } } do
						local p = Vector3.new(c[1], 0, c[2])
						local near = false
						for s = 1, #r.points - 1 do
							local u, v =
								r.points[s] * Vector3.new(1, 0, 1),
								r.points[s + 1] * Vector3.new(1, 0, 1)
							local tt = math.clamp((p - u):Dot(v - u) / (v - u):Dot(v - u), 0, 1)
							near = near or (p - (u + (v - u) * tt)).Magnitude < r.width / 2
						end
						t.expect(near).toBe(false)
					end
				end
			end
		end
	)

	t.test("every lot faces its street (front = asset -Z toward the nearest grid line)", function()
		for _, lot in TownLayout.lots(town) do
			local front = lot.cf.Position + lot.cf.LookVector * (town.width / 2 + town.footway + 1) -- the setback less D / 2
			local xs, zs = TownLayout.lines(town)
			local best = math.huge
			for _, x in xs do
				best = math.min(best, math.abs(front.X - x))
			end
			for _, z in zs do
				best = math.min(best, math.abs(front.Z - z))
			end
			t.expect(best < 12).toBe(true)
		end
	end)

	t.test("the grid gives RoadNet signalled junctions", function()
		local n = 0
		for _, j in RoadNet.junctions(WorldConfig.Roads) do
			if j.signals then
				n += 1
			end
		end
		t.expect(n >= 10).toBe(true)
	end)

	t.test(
		"back gardens sit inside the blocks, clear of every lot, keep rect and other garden",
		function()
			local lots = TownLayout.lots(town)
			local gardens = TownLayout.gardens(town, lots)
			local _, zs = TownLayout.lines(town)
			local inner = 0 -- lots inside the grid (the last street's far side has no block behind it)
			for _, l in lots do
				inner += if l.cf.Z > zs[#zs] then 1 else 0
			end
			t.expect(#gardens > inner / 2).toBe(true)
			for i, g in gardens do
				for _, l in lots do
					t.expect(overlaps(g.rect, l.rect)).toBe(false)
				end
				for _, k in town.keep do
					t.expect(overlaps(g.rect, k)).toBe(false)
				end
				for j = i + 1, #gardens do
					t.expect(overlaps(g.rect, gardens[j].rect)).toBe(false)
				end
			end
		end
	)

	t.test("Fore Street rows are shopfronts", function()
		local _, zs = TownLayout.lines(town)
		local n = 0
		for _, l in TownLayout.lots(town) do
			if l.shop then
				n += 1
				t.expect(
					math.abs(l.cf.Z - zs[2]) < town.width / 2 + town.footway + TownLayout.DEPTH
				)
					.toBe(true)
			end
		end
		t.expect(n >= 12).toBe(true)
	end)

	t.test(
		"heights step down from Fore Street; landmarks keep lots and gardens out; Church Street has two sides",
		function()
			local _, zs = TownLayout.lines(town)
			local lots = TownLayout.lots(town)
			local four, cottages, northSide = 0, 0, 0
			for _, l in lots do
				if l.shop then
					t.expect((l.floors or 0) >= 3).toBe(true)
				end
				four += if l.floors == 4 then 1 else 0
				cottages += if l.floors == nil then 1 else 0
				northSide += if l.cf.Z < zs[#zs] then 1 else 0
				for _, lm in TownLayout.LANDMARKS[town.id] do
					t.expect(overlaps(l.rect, lm.rect)).toBe(false)
				end
			end
			t.expect(four > 10 and cottages > 10 and northSide > 10).toBe(true)
			for _, g in TownLayout.gardens(town, lots) do
				for _, lm in TownLayout.LANDMARKS[town.id] do
					t.expect(overlaps(g.rect, lm.rect)).toBe(false)
				end
			end
		end
	)
end
