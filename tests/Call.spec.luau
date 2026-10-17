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
		local choice = CallLogic.chooseCall(0, "Calm", true, makeRng(1))
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

	t.test("tow falls back when the player cannot tow; storm uses the harbour mouth", function()
		t.expect(CallLogic.chooseCall(1, "Calm", false).kind).toBe("DriftingCraft")
		t.expect(CallLogic.chooseCall(1, "Calm", true).kind).toBe("Tow")
		local rng = makeRng(5)
		local mouth = 0
		for _ = 1, 300 do
			local c = CallLogic.chooseCall(10, "Storm", false, rng)
			t.expect(c.kind ~= "Tow").toBeTruthy()
			if c.zone == "HarbourMouth" then
				mouth += 1
			end
		end
		t.expect(mouth > 50).toBeTruthy()
	end)

	t.test("grades and rewards follow docs 03", function()
		t.expect(CallLogic.grade(50, 100)).toBe("Gold")
		t.expect(CallLogic.grade(70, 100)).toBe("Silver")
		t.expect(CallLogic.grade(95, 100)).toBe("Bronze")
		local silver = CallLogic.reward("Swimmer", 70, 100, 1, nil)
		t.expect(silver.cash).toBe(250)
		t.expect(silver.rep).toBe(60)
		t.expect(CallLogic.reward("Tow", 10, 100, 1, nil).cash)
			.toBe(math.floor(250 * 1.3 * 1.25 + 0.5))
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
end
