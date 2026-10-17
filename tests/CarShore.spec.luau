-- Car shoreline: land spawns face along their road away from the water (Car/RoadHeading on the
-- real WorldConfig roads), and the wading guard warns, floods once and recovers (Car/Wading).
-- Studio play test integration-B item 6: the pickup at StationYard drove straight into the sea.
return function(t)
	local RoadHeading = t.load("src/shared/Car/RoadHeading.luau")
	local Wading = t.load("src/shared/Car/Wading.luau")
	local World = t.load("src/shared/Config/WorldConfig.luau")

	local function point(id)
		for _, p in World.Points do
			if p.id == id then
				return p.position
			end
		end
		error("no point " .. id)
	end

	-- the greybox harbour basin (map/Build.luau): water from the quay edge out to the breakwaters
	local function inHarbour(p)
		return p.X > -312 and p.X < 312 and p.Z > 4 and p.Z < 368
	end

	t.test("a straight east road gives an east or west tangent, picked by the target", function()
		local roads = { { id = "R", points = { Vector3.new(0, 4, 0), Vector3.new(100, 4, 0) } } }
		local look, hit =
			RoadHeading.heading(roads, Vector3.new(50, 4, -20), Vector3.new(500, 4, 0))
		t.expect(hit.roadId).toBe("R")
		t.expect(look.X).toBeCloseTo(1, 1e-6)
		t.expect(hit.distance).toBeCloseTo(20, 1e-6)
		local back = RoadHeading.heading(roads, Vector3.new(50, 4, -20), Vector3.new(-500, 4, 0))
		t.expect(back.X).toBeCloseTo(-1, 1e-6)
	end)

	t.test("with no target a north-south road faces inland (-Z)", function()
		local roads = { { id = "R", points = { Vector3.new(0, 4, 0), Vector3.new(0, 4, 100) } } }
		local look = RoadHeading.heading(roads, Vector3.new(5, 4, 50), nil)
		t.expect(look.Z).toBeCloseTo(-1, 1e-6)
	end)

	t.test("slipways are skipped while an ordinary road is near, and face up the ramp", function()
		local road = { id = "Road", points = { Vector3.new(0, 4, -50), Vector3.new(100, 4, -50) } }
		local slip = { id = "Slip", points = { Vector3.new(0, 4, 0), Vector3.new(0, -3, 60) } }
		t.expect(RoadHeading.isSlipway(slip, 0)).toBe(true)
		local _, near = RoadHeading.heading({ road, slip }, Vector3.new(5, 2, 0), nil)
		t.expect(near.roadId).toBe("Road")
		local far = { id = "Road", points = { Vector3.new(0, 4, -500), Vector3.new(100, 4, -500) } }
		local look, hit =
			RoadHeading.heading({ far, slip }, Vector3.new(5, 2, 30), Vector3.new(0, 0, 900))
		t.expect(hit.roadId).toBe("Slip")
		t.expect(look.Z < -0.9).toBe(true) -- uphill, even with a seaward target
	end)

	t.test("StationYard faces east along Harbour Road toward Haven Sands", function()
		local at = point("StationYard")
		local look, hit = RoadHeading.heading(World.Roads, at, point("HavenSandsCarPark"), {
			seaLevel = World.SeaLevel,
		})
		t.expect(hit.roadId).toBe("HarbourRoad")
		t.expect(look.X > 0.99).toBe(true)
		for d = 10, 200, 10 do
			t.expect(inHarbour(at + look * d)).toBe(false) -- W never reaches the water
		end
	end)

	t.test("every land spawn faces away from the sea", function()
		local opts = { seaLevel = World.SeaLevel }
		-- Boatyard (quay placeholder) -> east along Harbour Road, clear of the basin
		local quay = Vector3.new(-20, 4, -8)
		local look = RoadHeading.heading(World.Roads, quay, point("HavenSandsCarPark"), opts)
		t.expect(look.X > 0.99).toBe(true)
		for d = 10, 150, 10 do
			t.expect(inHarbour(quay + look * d)).toBe(false)
		end
		-- Haven Sands car park -> back along the Coast Road (west, inland), not onto the slipway
		local park = point("HavenSandsCarPark")
		local parkLook, parkHit = RoadHeading.heading(World.Roads, park, point("StationYard"), opts)
		t.expect(parkHit.slipway).toBe(false)
		t.expect(parkLook.X < -0.5).toBe(true)
		t.expect(parkLook.Z < 0).toBe(true)
		-- lifeguard tower ATV -> up the Haven Sands slipway, away from the beach (+Z is sea)
		local tower = point("HavenSandsTower")
		local towerLook, towerHit =
			RoadHeading.heading(World.Roads, tower, point("HavenSandsCarPark"), opts)
		t.expect(towerHit.roadId).toBe("SandsSlipway")
		t.expect(towerLook.Z < -0.5).toBe(true)
		t.expect(towerLook.X < 0).toBe(true)
	end)

	t.test("spawnCFrame looks along the heading from the spawn position", function()
		local at = point("StationYard")
		local cf = RoadHeading.spawnCFrame(World.Roads, at, point("HavenSandsCarPark"))
		t.expect((cf.Position - at).Magnitude).toBeCloseTo(0, 1e-6)
		t.expect(cf.LookVector.X > 0.99).toBe(true)
		t.expect(math.abs(cf.LookVector.Y) < 1e-6).toBe(true)
	end)

	t.test("wading thresholds: a pickup warns at 0.4 m and floods at 0.8 m", function()
		local warnAt, floodAt = Wading.thresholds("LifeguardPickup")
		t.expect(warnAt).toBeCloseTo(1.2, 1e-9)
		t.expect(floodAt).toBeCloseTo(2.4, 1e-9)
		local atvWarn, atvFlood = Wading.thresholds("BeachATV")
		t.expect(atvFlood < floodAt).toBe(true)
		t.expect(atvWarn < atvFlood).toBe(true)
		local _, other = Wading.thresholds("Unknown")
		t.expect(other).toBeCloseTo(Wading.DEFAULT_RATED * 3, 1e-9)
	end)

	t.test("depth is water over the tyres and maps to levels and notices", function()
		-- root 2.4 above the ground at ride height; ground at Y = -1, water at 0
		t.expect(Wading.depth(0, 1.4, 2.4)).toBeCloseTo(1, 1e-9)
		t.expect(Wading.level(-0.5, "LifeguardPickup")).toBe("Dry")
		t.expect(Wading.level(0.6, "LifeguardPickup")).toBe("Wading")
		t.expect(Wading.level(1.5, "LifeguardPickup")).toBe("Deep")
		t.expect(Wading.level(2.5, "LifeguardPickup")).toBe("Flood")
		t.expect(Wading.notice("Wading", false)).toBe("")
		t.expect(Wading.notice("Deep", false)).toBe("Water too deep - turn back")
		t.expect(Wading.notice("Dry", true, 2.2)).toBe("Engine flooded - recovering in 3s")
		t.expect(Wading.notice("Flood", false)).toBe("Engine flooded")
	end)

	t.test("driving on into deep water floods once, then one rescue (no reset spam)", function()
		local state = Wading.newState()
		local actions = {}
		for i = 0, 40 do -- 20 s of checks every 0.5 s, the car sitting 4 studs deep
			local a = Wading.step(state, 4, "LifeguardPickup", i * 0.5)
			if a then
				table.insert(actions, `{a}@{i * 0.5}`)
			end
			if a == "Rescue" then
				break
			end
		end
		t.expect(actions).toEqual({ "Flood@0", `Rescue@{Wading.FLOOD_SECONDS}` })
		t.expect(state.flooded).toBe(false)
	end)

	t.test("a flooded car that rolled back to the shallows restarts in place", function()
		local state = Wading.newState()
		t.expect(Wading.step(state, 1.0, "LifeguardPickup", 0)).toBeNil()
		t.expect(Wading.step(state, 2.5, "LifeguardPickup", 1)).toBe("Flood")
		t.expect(Wading.step(state, 0.5, "LifeguardPickup", 2)).toBeNil()
		t.expect(Wading.step(state, 0.5, "LifeguardPickup", 1 + Wading.FLOOD_SECONDS))
			.toBe("Restart")
	end)
end
