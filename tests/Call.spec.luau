-- Calls: spawn rings, travel budget, rewards, grades and big-call scaling.
return function(t)
	local CallLogic = t.load("src/shared/Calls/CallLogic.luau")
	local CallTypes = t.load("src/shared/Calls/CallTypes.luau")

	-- deterministic LCG so the spec never flakes
	local function makeRng(seed: number)
		local s = seed
		return function()
			s = (s * 1103515245 + 12345) % 2147483648
			return s / 2147483648
		end
	end

	local RingLayout = t.load("src/shared/Config/RingLayout.luau")
	-- every player island's berth (BayCFrame), and no berth (Plot1's berth)
	local homes = { CallLogic.homeOf(nil) }
	for _, island in RingLayout.Islands do
		table.insert(homes, CallLogic.homeOf(island.berths.Boat))
	end

	t.test("every spawn zone yields open-water points in its ring, from every home", function()
		local rng = makeRng(7)
		for _, home in homes do
			for id, zone in CallTypes.SpawnZones do
				if id == "BeachRip" then
					continue -- a fixed, bake-sampled site inside Puffin Isle's zone circle (tests/RipCurrent.spec)
				end
				local fallback = zone.fallback or CallLogic.homeFallback(home)
				t.expect(CallLogic.isWater(fallback, zone.area)).toBeTruthy()
				for _ = 1, 40 do
					local p = CallLogic.pickSpawnPoint(id, rng, nil, home)
					t.expect(CallLogic.isWater(p, zone.area)).toBeTruthy()
					t.expect(p.Y).toBe(0)
					if p ~= fallback then
						local c = if zone.cove or zone.fromHome then home else zone.center
						local d = CallLogic.flatDistance(p, c)
						t.expect(d >= zone.minRadius - 0.01 and d <= zone.maxRadius + 0.01)
							.toBeTruthy()
					end
				end
			end
		end
	end)

	t.test(
		"open water: never in the lagoon, on an island, under a bridge or past the map",
		function()
			t.expect(CallLogic.isWater(Vector3.new(0, 0, 0), "Open")).toBe(false) -- the lagoon
			t.expect(CallLogic.isWater(Vector3.new(0, 0, 300), "Open")).toBe(false)
			t.expect(CallLogic.isWater(RingLayout.Islands[1].center, "Open")).toBe(false)
			local mid = RingLayout.deckAt(RingLayout.Bridges[2], 0.5)
			t.expect(CallLogic.isWater(Vector3.new(mid.X, 0, mid.Z), "Open")).toBe(false)
			t.expect(CallLogic.isWater(Vector3.new(1800, 0, 1750), "Open")).toBe(false) -- Skerry Isle
			t.expect(CallLogic.isWater(Vector3.new(0, 0, 7000), "Open")).toBe(false)
			t.expect(CallLogic.isWater(Vector3.new(0, 0, 500), "Open")).toBe(true) -- past the Plot2-Plot3 bridge
			t.expect(CallLogic.isWater(Vector3.new(0, 0, 500), "Outer")).toBe(false) -- inside the ring
			t.expect(CallLogic.isWater(Vector3.new(0, 0, 1300), "Outer")).toBe(true)
		end
	)

	t.test("calls 1-2 spawn just off your own cove, straight out to sea", function()
		local choice = CallLogic.chooseCall(0, "Calm", makeRng(1))
		t.expect(choice.kind).toBe("Swimmer")
		t.expect(choice.zone).toBe("Near")
		t.expect(CallLogic.chooseCall(1, "Calm").zone).toBe("CalmBay")
		local rng = makeRng(3)
		for i, island in RingLayout.Islands do
			local home = homes[i + 1]
			for _, zone in { "Near", "CalmBay" } do
				for _ = 1, 50 do
					local p = CallLogic.pickSpawnPoint(zone, rng, nil, home)
					local d = CallLogic.flatDistance(p, home)
					t.expect(d >= 150 and d <= 300).toBeTruthy()
					-- out past the island's rim, on its sea side
					t.expect(
						CallLogic.flatDistance(p, island.center) > RingLayout.IslandRadius + 40
					)
						.toBeTruthy()
					t.expect((p - island.center):Dot(island.facing) > 150).toBeTruthy()
				end
			end
		end
	end)

	t.test("free-roam water lies between the six islands and the outer ring", function()
		local rng = makeRng(11)
		for _ = 1, 200 do
			local p = CallLogic.pickSpawnPoint("Outer", rng)
			local d = CallLogic.flatDistance(p, CallTypes.STATION)
			t.expect(d >= 1200 and d <= 1900).toBeTruthy()
		end
	end)
	t.test("storm triples the call rate; first offer is quick", function()
		local calm = CallLogic.offerDelay("Calm")
		t.expect(calm <= 10).toBeTruthy()
		t.expect(CallLogic.offerDelay("Storm")).toBeCloseTo(calm / 3, 1e-6)
		t.expect(CallLogic.offerDelay("Calm", true) <= 5).toBeTruthy()
	end)

	t.test(
		"the first calls follow the chain (docs/16 B3, B9); storm uses the harbour mouth",
		function()
			local second = CallLogic.chooseCall(1, "Calm")
			t.expect(second.kind).toBe("DriftingCraft")
			t.expect(second.victims).toBe(1)
			t.expect(CallLogic.chooseCall(2, "Calm").victims).toBe(2)
			t.expect(CallLogic.chooseCall(4, "Calm").kind).toBe("WildlifeRescue")
			local rng = makeRng(5)
			local mouth = 0
			for _ = 1, 300 do
				local c = CallLogic.chooseCall(10, "Storm", rng)
				t.expect(CallTypes.Kinds[c.kind]).toBeTruthy()
				if c.zone == "HarbourMouth" then
					mouth += 1
				end
			end
			t.expect(mouth > 50).toBeTruthy()
		end
	)

	t.test("grades and rewards follow docs 03", function()
		t.expect(CallLogic.grade(50, 100)).toBe("Gold")
		t.expect(CallLogic.grade(70, 100)).toBe("Silver")
		t.expect(CallLogic.grade(95, 100)).toBe("Bronze")
		local silver = CallLogic.reward("Swimmer", 70, 100, 1, nil)
		t.expect(silver.cash).toBe(250)
		t.expect(CallLogic.reward("Diver", 10, 100, 1, nil).cash)
			.toBe(math.floor(250 * 1.4 * 1.25 + 0.5))
		local first = CallLogic.reward("Swimmer", 90, 100, 1, 0)
		t.expect(first.cash).toBe(500)
		t.expect(CallLogic.reward("Swimmer", 90, 100, 1, 2).cash).toBe(300)
	end)

	t.test("crew bonus is +10% per extra member, capped at +30%", function()
		t.expect(CallLogic.crewMultiplier(1)).toBeCloseTo(1, 1e-9)
		t.expect(CallLogic.crewMultiplier(2)).toBeCloseTo(1.1, 1e-9)
		t.expect(CallLogic.crewMultiplier(4)).toBeCloseTo(1.3, 1e-9)
		t.expect(CallLogic.crewMultiplier(8)).toBeCloseTo(1.3, 1e-9)
	end)

	t.test("big call victims: at least one per player and at least four", function()
		t.expect(CallLogic.bigCallVictimCount(1)).toBe(4)
		t.expect(CallLogic.bigCallVictimCount(4)).toBe(4)
		t.expect(CallLogic.bigCallVictimCount(9)).toBe(9)
		t.expect(CallLogic.bigCallVictimCount(0, 2)).toBe(4)
		t.expect(CallLogic.bigCompletionBonus(3, 6)).toBe(625)
		local vc = CallLogic.bigVictimPay()
		t.expect(vc).toBe(150)
		local pts = CallLogic.scatterPoints(Vector3.new(60, 0, 500), 9, 14, 34, "Open", makeRng(9))
		t.expect(#pts).toBe(9)
	end)

	t.test("heading toward a call: fast enough and inside the cone", function()
		local from, target = Vector3.new(0, 0, 0), Vector3.new(0, 0, -200)
		local h = CallLogic.headingToward
		t.expect(h(from, Vector3.new(0, 0, -20), target, 8, 35)).toBe(true)
		t.expect(h(from, Vector3.new(10, 3, -20), target, 8, 35)).toBe(true) -- ~27 deg off
		t.expect(h(from, Vector3.new(20, 0, -10), target, 8, 35)).toBe(false) -- ~63 deg off
		t.expect(h(from, Vector3.new(0, 0, 20), target, 8, 35)).toBe(false) -- away
		t.expect(h(from, Vector3.new(0, 0, -4), target, 8, 35)).toBe(false) -- drifting
		t.expect(h(target, Vector3.new(0, 0, -20), target, 8, 35)).toBe(false) -- already there
	end)

	-- docs/23 e.2 distance tiers, counted from your berth (docs/23 (k))
	t.test(
		"from call 3 on, calls sit out past the six islands, within reach of your berth",
		function()
			local rng = makeRng(21)
			local jetSki = CallLogic.craftReach({ "JetSki" })
			for i = 2, #homes do
				local home = homes[i]
				for completed = 2, 30 do
					local c = CallLogic.chooseCall(completed, "Calm", rng, jetSki, false, home)
					local zone = CallTypes.SpawnZones[c.zone]
					if #CallTypes.Kinds[c.kind].zones > 1 then -- not the fixed rip
						t.expect(
							(zone.reach ~= nil and zone.reach <= 2000)
								or (
									zone.island
									and CallLogic.flatDistance(home, zone.center) <= 2000
								)
						).toBeTruthy()
						for _ = 1, 10 do
							local p = CallLogic.pickSpawnPoint(c.zone, rng, nil, home)
							t.expect(CallLogic.flatDistance(p, CallTypes.STATION) >= 1200)
								.toBeTruthy()
						end
					end
				end
			end
		end
	)

	t.test("the zone pool widens with the best owned craft", function()
		t.expect(CallLogic.craftReach({})).toBe(2000)
		t.expect(CallLogic.craftReach({ "JetSki", "RIB" })).toBe(3500)
		t.expect(CallLogic.craftReach({ "RIB", "Lifeboat" })).toBe(5500)
		-- a Robux boat sits on the RIB's tier (it needs the same boathouse): speed, not the far calls
		t.expect(CallLogic.craftReach({ "RiptideX" })).toBe(3500)
		t.expect(CallLogic.craftReach({ "Submarine" })).toBe(5500)
		t.expect(CallLogic.craftReach({ "RescueHelicopter" })).toBe(5500)
		local plot1 = homes[3] -- Plot2, the south-east island: Skerry Isle is the near outer island
		local function zones(reach: number, home: Vector3): { [string]: boolean }
			local seen, rng = {}, makeRng(9)
			for _ = 1, 400 do
				seen[CallLogic.distanceZone(reach, rng, home)] = true
			end
			return seen
		end
		local ski, rib, big = zones(2000, plot1), zones(3500, plot1), zones(5500, plot1)
		t.expect(ski.Offshore and ski.SkerryIsle and not ski.FarSea and not ski.DeepSea)
			.toBeTruthy()
		t.expect(rib.FarSea and rib.Offshore and not rib.DeepSea and not rib.GannetRock)
			.toBeTruthy()
		t.expect(big.DeepSea and big.TheArches and big.GannetRock and big.Offshore).toBeTruthy()
		-- from the west island Skerry is a RIB trip
		t.expect(zones(2000, homes[5]).SkerryIsle).toBeFalsy()
	end)

	t.test("every outer island has a zone, off its shore", function()
		local WorldConfig = t.load("src/shared/Config/WorldConfig.luau")
		for _, island in WorldConfig.Islands do
			local zone = CallTypes.SpawnZones[island.id]
			t.expect(zone ~= nil and zone.island == true).toBeTruthy()
			t.expect(zone.minRadius > island.radius).toBeTruthy()
		end
	end)

	t.test("pay scales with distance", function()
		t.expect(CallLogic.distancePay(300)).toBe(1)
		t.expect(CallLogic.distancePay(1500)).toBe(1)
		t.expect(CallLogic.distancePay(3000)).toBeCloseTo(2, 1e-6)
		t.expect(CallLogic.distancePay(20000)).toBe(4)
	end)

	t.test("landed away from your berth, a far call pays for the trip sailed", function()
		local home, hub = homes[2], homes[5] -- the east island; the west island's berth
		-- a call far west: landed at your berth it pays its full x2, at another island half the trip sailed
		local west = home + Vector3.new(-3000, 0, 0)
		t.expect(CallLogic.deliveredPay(west, home + Vector3.new(0, 0, 40), home))
			.toBeCloseTo(2, 1e-6)
		local half = (3000 + CallLogic.flatDistance(west, hub)) / 2
		t.expect(CallLogic.deliveredPay(west, hub, home)).toBeCloseTo(half / 1500, 1e-6)
		t.expect(CallLogic.deliveredPay(west, hub, home) < 1.8).toBeTruthy()
		-- never more than the scene's own pay
		local east = home + Vector3.new(3000, 0, 0)
		t.expect(CallLogic.deliveredPay(east, hub, home)).toBeCloseTo(2, 1e-6)
	end)
end
