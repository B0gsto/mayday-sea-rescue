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
		local landing = Station.fromBerth(bay).Position
		t.expect(GoBack.refusal(state({ at = landing }))).toBe("Home")
		local past = (Station.fromBerth(bay) * CFrame.new(0, 0, -GoBack.BAY_RADIUS - 1)).Position
		t.expect(GoBack.refusal(state({ at = past }))).toBe(nil)
	end)

	t.test("rate limit: a press outlasts the turn a ram can cancel", function()
		t.expect(GoBack.ready(nil, 5)).toBe(true)
		t.expect(GoBack.ready(5, 5 + GoBack.COOLDOWN - 0.01)).toBe(false)
		t.expect(GoBack.ready(5, 5 + GoBack.COOLDOWN)).toBe(true)
		t.expect(GoBack.COOLDOWN > GoBack.TURN).toBe(true)
	end)

	-- the ride (owner 2026-11-07): turn toward home, drive there fast, stopped in the bay about 5 s after the press
	local finish = CFrame.lookAt(Vector3.new(0, 1, 0), Vector3.new(0, 1, -10)) -- bow to sea along -Z
	local function open()
		return true
	end
	-- a round island of radius r at c: a leg is clear when it passes outside it
	local function rockAt(c: Vector3, r: number)
		return function(a: Vector3, b: Vector3): boolean
			local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
			local ac = Vector3.new(c.X - a.X, 0, c.Z - a.Z)
			local k = if ab.Magnitude > 0 then math.clamp(ac:Dot(ab) / ab:Dot(ab), 0, 1) else 0
			return (ac - ab * k).Magnitude > r
		end
	end
	local function flatDist(a: Vector3, b: Vector3): number
		return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
	end
	local function heading(cf: CFrame): Vector3
		return Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z).Unit
	end

	t.test("the ride stops in the bay about 5 s after the press, near or far", function()
		t.expect(GoBack.ARRIVE >= 4.5 and GoBack.ARRIVE <= 5.5).toBe(true)
		t.expect(GoBack.TURN <= 1).toBe(true)
		for _, far in { 300, 1500, 6000 } do
			local start = CFrame.lookAt(Vector3.new(far, 1, -far), Vector3.new(far + 10, 1, -far)) -- facing away
			local r = GoBack.plan(start, finish, open)
			t.expect(flatDist(GoBack.pose(r, 0).Position, start.Position) < 0.01).toBe(true)
			t.expect(GoBack.pose(r, GoBack.ARRIVE)).toBe(finish)
			t.expect(flatDist(GoBack.pose(r, GoBack.ARRIVE - 0.02).Position, finish.Position) < 2)
				.toBe(true)
			t.expect(flatDist(GoBack.pose(r, GoBack.ARRIVE - 1.5).Position, finish.Position) > 5)
				.toBe(true)
		end
		local near = GoBack.plan(CFrame.new(400, 1, -400), finish, open)
		local far = GoBack.plan(CFrame.new(4000, 1, -4000), finish, open)
		t.expect(GoBack.topSpeed(far) > GoBack.topSpeed(near) * 5).toBe(true) -- the speed scales, not the time
	end)

	t.test("it turns in place toward home first, then launches", function()
		local start = CFrame.lookAt(Vector3.new(0, 1, -2000), Vector3.new(0, 1, -2010)) -- bow away from home
		local r = GoBack.plan(start, finish, open)
		local mid = GoBack.pose(r, GoBack.TURN / 2)
		t.expect(flatDist(mid.Position, start.Position) < 0.01).toBe(true)
		local turned = GoBack.pose(r, GoBack.TURN)
		t.expect(flatDist(turned.Position, start.Position) < 0.01).toBe(true)
		local home = (GoBack.approach(finish) - start.Position)
		t.expect(heading(turned):Dot(Vector3.new(home.X, 0, home.Z).Unit) > 0.99).toBe(true)
		t.expect(flatDist(GoBack.pose(r, GoBack.TURN + 0.5).Position, start.Position) > 10)
			.toBe(true)
	end)

	t.test("it comes in from the sea and swings round, bow to sea, into the bay", function()
		local r = GoBack.plan(CFrame.new(0, 1, -3000), finish, open)
		t.expect(#r.points).toBe(3)
		t.expect(r.points[2]).toBe(GoBack.approach(finish))
		t.expect(heading(GoBack.pose(r, GoBack.ARRIVE - 0.2)):Dot(heading(finish)) > 0.99)
			.toBe(true)
		-- on the way in the bow pointed at the bay, not out to sea
		local seen = false
		for k = 0, 40 do
			local pose = GoBack.pose(r, GoBack.TURN + GoBack.RUN * k / 40)
			if
				heading(pose):Dot(heading(finish)) < -0.9
				and flatDist(pose.Position, finish.Position) < 2000
			then
				seen = true
			end
		end
		t.expect(seen).toBe(true)
	end)

	t.test(
		"never through an island: round it by a clear waypoint, or under the veil when boxed in",
		function()
			local start = CFrame.new(0, 1, -2500)
			local rock = rockAt(Vector3.new(0, 0, -1300), 300)
			local r = GoBack.plan(start, finish, rock)
			t.expect(r.jump).toBeNil()
			t.expect(#r.points).toBe(4)
			for i = 1, #r.points - 2 do -- the last leg is the bay's own mouth
				t.expect(rock(r.points[i], r.points[i + 1])).toBe(true)
			end
			t.expect(GoBack.jumpTime(r)).toBeNil()
			-- every pose of the seen ride stays off the island
			for k = 0, 100 do
				local p = GoBack.pose(r, GoBack.ARRIVE * k / 100).Position
				t.expect(flatDist(p, Vector3.new(0, 0, -1300)) > 300).toBe(true)
			end
			local boxed = GoBack.plan(start, finish, function()
				return false
			end)
			t.expect(boxed.jump ~= nil).toBe(true)
			local jt = GoBack.jumpTime(boxed) :: number
			t.expect(jt >= GoBack.TURN and jt < GoBack.ARRIVE - 1).toBe(true) -- the turn and the run-in are seen
			t.expect(GoBack.pose(boxed, GoBack.ARRIVE)).toBe(finish)
			t.expect(
				flatDist(GoBack.pose(boxed, jt + 0.05).Position, finish.Position)
					<= GoBack.APPROACH + GoBack.RUN_IN + 1
			).toBe(true)
		end
	)

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
			local landing = UpgradeStation.fromBerth(berth).Position
			t.expect(GoBack.reachAt(landing, berth, top)).toBe(0)
			t.expect(GoBack.reachAt(berth.Position, berth, top)).toBe(0)
			local out = (berth * CFrame.new(0, 0, -(GoBack.REACH_HOME + 1))).Position
			t.expect(GoBack.reachAt(out, berth, top)).toBe(top)
		end
		t.expect(GoBack.reachAt(Vector3.zero, nil, top)).toBe(top) -- no berth, no home
	end)
end
