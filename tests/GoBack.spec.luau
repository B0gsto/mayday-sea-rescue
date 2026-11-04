-- GoBack (docs/30 section 1): who may press Go back, and the rate limit.
return function(t)
	local GoBack = t.load("src/shared/Boat/GoBack.luau")
	local ColdOpen = t.load("src/shared/Boat/ColdOpen.luau")

	local bay = CFrame.new(1000, 0, 0)
	local function state(patch)
		local s = {
			driving = true,
			coldOpenDone = true,
			survivors = 0,
			testRide = false,
			at = Vector3.new(0, 0, 0),
			bay = bay,
		}
		for k, v in patch or {} do
			s[k] = v
		end
		return s
	end

	t.test("driving away from home goes, with or without survivors", function()
		t.expect(GoBack.refusal(state())).toBe(nil)
		t.expect(GoBack.refusal(state({ survivors = 3 }))).toBe(nil)
	end)

	t.test("never out of the driver's seat or on a test ride", function()
		t.expect(GoBack.refusal(state({ driving = false }))).toBe("NotDriving")
		t.expect(GoBack.refusal(state({ testRide = true, survivors = 1 }))).toBe("TestRide")
	end)

	t.test("the cold open: only once a survivor is aboard", function()
		t.expect(GoBack.refusal(state({ coldOpenDone = false }))).toBe("ColdOpen")
		t.expect(GoBack.refusal(state({ coldOpenDone = false, survivors = 1 }))).toBe(nil)
	end)

	t.test("refused while the prize wheel's sequence runs", function()
		t.expect(GoBack.refusal(state({ spinning = true }))).toBe("Spinning")
		t.expect(GoBack.refusal(state({ spinning = false }))).toBeNil()
	end)

	t.test("nothing to do at home, and no home without a berth", function()
		local near = Vector3.new(1000 - ColdOpen.DROP_RADIUS + 1, 0, 0)
		t.expect(GoBack.refusal(state({ at = near }))).toBe("Home")
		t.expect(GoBack.refusal(state({ bay = false }))).toBe("NoHome")
	end)

	t.test("in the Upgrade Station's bay it is home too, past the drop-off zone", function()
		local Station = t.load("src/shared/UpgradeStation.luau")
		t.expect(Station.LANDING_OUT > ColdOpen.DROP_RADIUS).toBe(true)
		local landing = (bay * CFrame.new(0, 0, -Station.LANDING_OUT)).Position
		t.expect(GoBack.refusal(state({ at = landing }))).toBe("Home")
		local past = (bay * CFrame.new(0, 0, -Station.LANDING_OUT - GoBack.BAY_RADIUS - 1)).Position
		t.expect(GoBack.refusal(state({ at = past }))).toBe(nil)
	end)

	t.test("rate limit: a press outlasts the charge and the landing", function()
		t.expect(GoBack.ready(nil, 5)).toBe(true)
		t.expect(GoBack.ready(5, 5 + GoBack.COOLDOWN - 0.01)).toBe(false)
		t.expect(GoBack.ready(5, 5 + GoBack.COOLDOWN)).toBe(true)
		t.expect(GoBack.COOLDOWN > GoBack.CHARGE + GoBack.LAND_HOLD).toBe(true)
	end)

	t.test("the boat's long reach never boards the cove mouth from home", function()
		local RingLayout = t.load("src/shared/Config/RingLayout.luau")
		local AmbientMix = t.load("src/shared/Calls/AmbientMix.luau")
		local BoatLevels = t.load("src/shared/BoatLevels.luau")
		local UpgradeStation = t.load("src/shared/UpgradeStation.luau")
		t.expect(GoBack.REACH_HOME).toBe(AmbientMix.HOME_CLEAR)
		local top = BoatLevels.row(BoatLevels.MAX).reach
		t.expect(top > 100).toBe(true)
		for _, island in RingLayout.Islands do
			local berth = island.berths.Boat
			local landing = (berth * CFrame.new(0, 0, -UpgradeStation.LANDING_OUT)).Position
			t.expect(GoBack.reachAt(landing, berth, top)).toBe(0)
			t.expect(GoBack.reachAt(berth.Position, berth, top)).toBe(0)
			local out = (berth * CFrame.new(0, 0, -(GoBack.REACH_HOME + 1))).Position
			t.expect(GoBack.reachAt(out, berth, top)).toBe(top)
		end
		t.expect(GoBack.reachAt(Vector3.zero, nil, top)).toBe(top) -- no berth, no home
	end)
end
