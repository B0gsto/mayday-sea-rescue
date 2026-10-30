-- SeaPlates (docs/27 section 1): the sea plates' hard limits. Every plate (and the ramp) stays inside its island's
-- 60 deg wedge (>= 40 studs from the bisectors), <= 900 from the ring centre, >= 120 from every outer island, wreck
-- and fixed call site, off the island plate's trim and beach step, over open water, and leaves the berth channel
-- >= 70 wide; the moved quest pontoon, its boats and the second barge stay clear; no call spawns on them.
return function(t)
	local L = t.load("src/shared/Config/RingLayout.luau")
	local WorldConfig = t.load("src/shared/Config/WorldConfig.luau")
	local CallTypes = t.load("src/shared/Calls/CallTypes.luau")
	local CallLogic = t.load("src/shared/Calls/CallLogic.luau")
	local DockConfig = t.load("src/shared/Config/DockConfig.luau")
	local fs = t.lune("fs")
	local meta = t.lune("serde")
		.decode("json", fs.readFile(`{t.gameDir}/map/generated/terrain.json`))
	local raw = fs.readFile(`{t.gameDir}/map/generated/{meta.height}`)
	local function ground(
		p: Vector3
	): number -- the baked surface Y (nearest sample) + the render bias
		local ix = math.floor((p.X - meta.originX) / meta.cell + 0.5)
		local iz = math.floor((p.Z - meta.originZ) / meta.cell + 0.5)
		return string.unpack("<i2", raw, (iz * meta.nx + ix) * 2 + 1) / meta.heightScale + 2
	end

	local R = L.Ring
	local function corners(r: { number }): { Vector2 }
		return {
			Vector2.new(r[1], r[3]),
			Vector2.new(r[2], r[3]),
			Vector2.new(r[1], r[4]),
			Vector2.new(r[2], r[4]),
		}
	end
	local function world(isl: any, c: Vector2): Vector3
		local p = (isl.frame * CFrame.new(c.X, 0, -c.Y)).Position
		return Vector3.new(p.X, 0, p.Z)
	end
	local function flat(a: Vector3, b: Vector3): number
		return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
	end
	-- flat distance from a point to an island-frame rect
	local function rectDist(isl: any, r: { number }, p: Vector3): number
		local l = isl.frame:PointToObjectSpace(Vector3.new(p.X, L.PlateauY, p.Z))
		local x, f = l.X, -l.Z
		local dx = math.max(r[1] - x, 0, x - r[2])
		local df = math.max(r[3] - f, 0, f - r[4])
		return math.sqrt(dx * dx + df * df)
	end

	t.test(
		"every plate and the ramp: inside the wedge, within 900, far from fixed sites",
		function()
			local sites = {} -- { centre, radius }
			for _, o in WorldConfig.Islands do
				table.insert(sites, { o.center, o.radius })
			end
			for _, s in CallTypes.DiveSites do
				table.insert(sites, { s.wreck, 0 })
			end
			for _, z in CallTypes.SpawnZones do
				if z.fallback then
					table.insert(sites, { z.fallback, z.maxRadius })
				end
			end
			for _, isl in L.Islands do
				for _, r in L.SEA_KEEP_OUT do
					for _, c in corners(r) do
						local along = c.Y + R -- the corner's distance out along the island's facing
						t.expect(along * 0.5 - math.abs(c.X) * math.sqrt(3) / 2 >= 40).toBe(true)
						t.expect(Vector2.new(c.X, along).Magnitude <= 900).toBe(true)
					end
					for _, s in sites do
						local d = rectDist(isl, r, s[1]) - s[2]
						if d < 120 then
							error(`{isl.id} plate rect within {math.floor(d)} of a site at {s[1]}`)
						end
					end
				end
			end
		end
	)

	t.test("plates sit past the trim and beach step, over water, with a 70+ channel", function()
		local p1, p2 = L.SeaPlates.SeaPlate1.rect, L.SeaPlates.SeaPlate2.rect
		t.expect(p2[1] - p1[2] >= 70).toBe(true)
		t.expect(p1[2] <= -L.Notch.island.halfWidth + 5 and p2[1] >= L.Notch.island.halfWidth - 5)
			.toBe(true)
		for key, sp in L.SeaPlates do
			t.expect(sp.rect[3] >= L.IslandPlate.edge + 8).toBe(true) -- trim 2 + beach step 6
			t.expect(DockConfig.Buildings[key] ~= nil).toBe(true)
			for _, isl in L.Islands do
				for u = 0, 4 do
					for v = 0, 4 do
						local r = sp.rect
						local c =
							Vector2.new(r[1] + (r[2] - r[1]) * u / 4, r[3] + (r[4] - r[3]) * v / 4)
						if ground(world(isl, c)) > -6 then
							error(`{isl.id} {key} over land at {c}`)
						end
					end
				end
			end
		end
	end)

	t.test("the moved quest pontoon and its boats, and the second barge, stay clear", function()
		local S = L.QUEST_SHIFT
		for _, isl in L.Islands do
			local shift = isl.frame.RightVector * S.X + isl.frame.LookVector * S.Y
			for _, slot in isl.quest.slots do
				local p = slot.Position + shift
				t.expect(L.nearSeaPlate(p.X, p.Z, 4)).toBe(false)
			end
			local tablet = isl.lots.QuestTablet.cframe.Position + shift
			local l = isl.frame:PointToObjectSpace(tablet)
			local r = L.SeaPlates.SeaPlate1.rect
			-- the tablet stands on P1's deck
			t.expect(l.X > r[1] + 2 and l.X < r[2] - 2 and -l.Z > r[3] + 2 and -l.Z < r[4] - 2)
				.toBe(true)
			local pontoon = isl.quest.pontoon.Position + shift
			local pl = isl.frame:PointToObjectSpace(pontoon)
			t.expect(-pl.Z - L.QUEST_PONTOON.Y / 2 >= r[4] - 0.01).toBe(true) -- runs out from P1's outer edge
		end
	end)

	t.test("no call spawns on a plate or the ramp", function()
		local seed = 7
		local function rng(): number
			seed = (seed * 1103515245 + 12345) % 2147483648
			return seed / 2147483648
		end
		for _, isl in L.Islands do
			local home = Vector3.new(isl.berths.Boat.Position.X, 0, isl.berths.Boat.Position.Z)
			for _, zone in { "Near", "CalmBay", "HarbourMouth" } do
				for _ = 1, 40 do
					local p = CallLogic.pickSpawnPoint(zone, rng, nil, home)
					t.expect(L.nearSeaPlate(p.X, p.Z, CallTypes.Areas.PlateClear - 1)).toBe(false)
					t.expect(flat(p, home) < 1000).toBe(true) -- never the far fallback
				end
			end
		end
	end)

	t.test("a sea route from the cove out past the plates goes round them", function()
		for _, isl in L.Islands do
			local berth = isl.berths.Boat.Position
			local out = (isl.frame * CFrame.new(-170, 0, -300)).Position -- out beyond P1's outer corner
			local leg = L.seaRoute(berth, Vector3.new(out.X, 0, out.Z))
			t.expect(L.nearSeaPlate(leg.X, leg.Z, 10)).toBe(false)
		end
	end)
end
