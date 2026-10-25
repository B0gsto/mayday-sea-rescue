-- Calls: spawn rings, travel budget, rewards, grades and big-call scaling.
return function(t)
	local CallLogic = t.load("src/shared/Calls/CallLogic.luau")
	local CallTypes = t.load("src/shared/Calls/CallTypes.luau")
	local GameConfig = t.load("src/shared/Config/GameConfig.luau")

	-- deterministic LCG so the spec never flakes
	local function makeRng(seed: number)
		local s = seed
		return function()
			s = (s * 1103515245 + 12345) % 2147483648
			return s / 2147483648
		end
	end

	t.test("every spawn zone yields open-water points inside its ring", function()
		local rng = makeRng(7)
		for id, zone in CallTypes.SpawnZones do
			for _ = 1, 200 do
				local p = CallLogic.pickSpawnPoint(id, rng)
				t.expect(CallLogic.isWater(p, zone.area)).toBeTruthy()
				if p ~= zone.fallback then
					local d = CallLogic.flatDistance(p, zone.center)
					t.expect(d >= zone.minRadius - 0.01 and d <= zone.maxRadius + 0.01).toBeTruthy()
				end
				t.expect(p.Y).toBe(0)
			end
		end
	end)

	t.test("the first call is a Swimmer close to the harbour", function()
		local choice = CallLogic.chooseCall(0, "Calm", makeRng(1))
		t.expect(choice.kind).toBe("Swimmer")
		t.expect(choice.zone).toBe("Near")
		local rng = makeRng(3)
		for _ = 1, 100 do
			local p = CallLogic.pickSpawnPoint("Near", rng)
			t.expect(CallLogic.flatDistance(p, CallTypes.STATION) <= 220.01).toBeTruthy()
			t.expect(CallLogic.zoneIdAt(p) ~= "OpenSea").toBeTruthy()
		end
	end)

	t.test("outer calls sit about 45 s out at jet ski cruise speed", function()
		local rng = makeRng(11)
		for _ = 1, 200 do
			local p = CallLogic.pickSpawnPoint("Outer", rng)
			local s = CallLogic.travelSeconds(CallLogic.flatDistance(p, CallTypes.STATION), 75)
			t.expect(s >= 20 and s <= 46).toBeTruthy()
			t.expect(math.sqrt(p.X * p.X + p.Z * p.Z) <= GameConfig.MapRadius).toBeTruthy()
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
		t.expect(silver.rep).toBe(60)
		t.expect(CallLogic.reward("Cliff", 10, 100, 1, nil).cash)
			.toBe(math.floor(250 * 1.4 * 1.25 + 0.5))
		local first = CallLogic.reward("Swimmer", 90, 100, 1, 0)
		t.expect(first.cash).toBe(500)
		t.expect(first.rep).toBe(150)
		t.expect(CallLogic.reward("Swimmer", 90, 100, 1, 2).cash).toBe(300)
		t.expect(CallLogic.failSafeCash("Swimmer")).toBe(25)
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
		local cash, rep = CallLogic.bigCompletionBonus(3, 6)
		t.expect(cash).toBe(625)
		t.expect(rep).toBe(90)
		local vc = CallLogic.bigVictimPay()
		t.expect(vc).toBe(150)
		local pts =
			CallLogic.scatterPoints(Vector3.new(60, 0, 500), 9, 14, 34, "Outside", makeRng(9))
		t.expect(#pts).toBe(9)
	end)

	t.test("drop-off pad test uses the pad footprint plus margin", function()
		local cf = CFrame.new(-125, 0.2, 92)
		local size = Vector3.new(12, 0.4, 20)
		t.expect(CallLogic.insidePad(cf, size, Vector3.new(-125, 1, 92), 0)).toBeTruthy()
		t.expect(CallLogic.insidePad(cf, size, Vector3.new(-134, 1, 92), 5)).toBeTruthy()
		t.expect(CallLogic.insidePad(cf, size, Vector3.new(-150, 1, 92), 5)).toBeFalsy()
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

	-- docs/23 e.2 distance tiers
	local function dist(p: Vector3): number
		return CallLogic.flatDistance(p, CallTypes.STATION)
	end

	t.test("calls 1-2 stay in the harbour; call 3 on is at least 600 studs out", function()
		local rng = makeRng(21)
		for completed = 0, 1 do
			local c = CallLogic.chooseCall(completed, "Calm", rng)
			for _ = 1, 50 do
				t.expect(dist(CallLogic.pickSpawnPoint(c.zone, rng)) <= 420.01).toBeTruthy()
			end
		end
		local jetSki = CallLogic.craftReach({ "JetSki" })
		for completed = 2, 40 do
			local c = CallLogic.chooseCall(completed, "Calm", rng, jetSki)
			local zone = CallTypes.SpawnZones[c.zone]
			if #CallTypes.Kinds[c.kind].zones > 1 then -- not a fixed-site scene
				t.expect(zone.reach ~= nil and zone.reach <= 2000).toBeTruthy()
				for _ = 1, 20 do
					local d = dist(CallLogic.pickSpawnPoint(c.zone, rng))
					t.expect(d >= 600 and d <= 3400).toBeTruthy() -- Skerry's far side, unroutable in game
				end
			end
		end
	end)

	t.test("the zone pool widens with the best owned craft", function()
		t.expect(CallLogic.craftReach({})).toBe(2000)
		t.expect(CallLogic.craftReach({ "JetSki", "RIB" })).toBe(3500)
		t.expect(CallLogic.craftReach({ "RIB", "Lifeboat" })).toBe(5500)
		t.expect(CallLogic.craftReach({ "RiptideX" })).toBe(5500)
		local function zones(reach: number): { [string]: boolean }
			local seen, rng = {}, makeRng(9)
			for _ = 1, 400 do
				seen[CallLogic.distanceZone(reach, rng)] = true
			end
			return seen
		end
		local ski, rib, big = zones(2000), zones(3500), zones(5500)
		t.expect(ski.Offshore and ski.SkerryIsle and not ski.FarSea and not ski.DeepSea)
			.toBeTruthy()
		t.expect(rib.FarSea and rib.PuffinIsle and rib.Offshore and not rib.DeepSea).toBeTruthy()
		t.expect(big.DeepSea and big.MermaidLagoon and big.WreckReef and big.Offshore).toBeTruthy()
	end)

	t.test("island zones come from the map data, and sit off the island", function()
		local WorldConfig = t.load("src/shared/Config/WorldConfig.luau")
		local ids = {}
		for _, island in WorldConfig.Islands do
			ids[island.id] = island
		end
		for id in CallTypes.IslandReach do
			local zone, island = CallTypes.SpawnZones[id], ids[id]
			t.expect(zone ~= nil and island ~= nil and zone.fallback ~= nil).toBeTruthy()
			t.expect(zone.minRadius > island.radius).toBeTruthy()
		end
		t.expect(
			CallTypes.SpawnZones.StElowensMount == nil and CallTypes.SpawnZones.TheArches == nil
		)
			.toBeTruthy()
	end)

	t.test("pay scales with distance", function()
		t.expect(CallLogic.distancePay(300)).toBe(1)
		t.expect(CallLogic.distancePay(1200)).toBe(1)
		t.expect(CallLogic.distancePay(2400)).toBeCloseTo(2, 1e-6)
		t.expect(CallLogic.distancePay(20000)).toBe(4)
	end)

	t.test("drop-off is the nearest of your dock and the harbour pads", function()
		local pads = { Vector3.new(130, 0, 12), Vector3.new(-125, 0, 92) }
		local from = Vector3.new(-300, 0, 500)
		t.expect(CallLogic.nearestDropOff(from, pads)).toBe(pads[2])
		local dock = Vector3.new(-280, 0, 400)
		table.insert(pads, dock)
		t.expect(CallLogic.nearestDropOff(from, pads)).toBe(dock)
		t.expect(CallLogic.nearestDropOff(from, {})).toBe(nil)
	end)
end
