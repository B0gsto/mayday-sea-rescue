-- Boat cold open: the auto-throttle hands over in time, the Assist ease slows a fast jet ski
-- before the casualty, and an eased approach is Silver at best (docs 09 section 9.1).
return function(t)
	local ColdOpen = t.load("src/shared/Boat/ColdOpen.luau")
	local Buoyancy = t.load("src/shared/Boat/Buoyancy.luau")
	local VehicleConfig = t.load("src/shared/Config/VehicleConfig.luau")
	local jet = VehicleConfig.JetSki
	local KNOT = 1.543
	local DT = 1 / 120

	-- 1D straight run at the casualty, calm water, full grip: the same throttle pipeline as
	-- BoatController (auto-throttle, then the player's input, then the Assist ease).
	-- input(time, distance, speed) -> -1..1. Returns a trace of the run.
	local function run(
		startDistance: number,
		input: (number, number, number) -> number,
		assist: boolean
	)
		local v, d, time = ColdOpen.AUTO_SPEED, startDistance, 0
		local auto, easing, eased = true, false, false
		local trace = {
			handoverAt = nil :: number?,
			handoverTime = nil :: number?,
			speedAt60 = nil :: number?,
		}
		trace.minDistance = d
		trace.speedAtMin = v
		while time < 30 and d > 0 do
			local raw = input(time, d, v)
			local throttle = raw
			if auto then
				auto = ColdOpen.autoActive(time, d, raw)
				if auto then
					throttle = ColdOpen.autoThrottle(jet, v)
				else
					trace.handoverAt = d
					trace.handoverTime = time
				end
			end
			easing = ColdOpen.updateEase(easing, assist, d, v, jet.brakeDecel)
			if easing then
				eased = true
				throttle = ColdOpen.easeThrottle(v, throttle)
			end
			local a = Buoyancy.thrust(throttle, v, 1, jet, 1, 1, false, true)
				- Buoyancy.forwardDecel(v, jet, 1)
			v += a * DT
			d -= v * DT
			time += DT
			if d <= 60 and not trace.speedAt60 then
				trace.speedAt60 = v
			end
			if d <= 20 then
				trace.maxInside20 = math.max(trace.maxInside20 or 0, v)
			end
			if d < trace.minDistance then
				trace.minDistance = d
				trace.speedAtMin = v
			end
			if d < 8 then
				break
			end
		end
		trace.eased = eased
		trace.finalSpeed = v
		trace.finalDistance = d
		return trace
	end

	local function hands_off()
		return 0
	end

	t.test("the auto-throttle holds about the cold-open speed", function()
		local v = ColdOpen.AUTO_SPEED
		for _ = 1, 10 * 120 do
			local th = ColdOpen.autoThrottle(jet, v)
			t.expect(th >= 0 and th <= 1).toBeTruthy()
			v += (Buoyancy.thrust(th, v, 1, jet, 1, 1, false, true) - Buoyancy.forwardDecel(
				v,
				jet,
				1
			)) * DT
		end
		t.expect(math.abs(v - ColdOpen.AUTO_SPEED) < 1.5 * KNOT).toBeTruthy()
	end)

	t.test("the auto-throttle ends on time, distance or the player's input", function()
		t.expect(ColdOpen.autoActive(0, 250, 0)).toBe(true)
		t.expect(ColdOpen.autoActive(ColdOpen.AUTO_HOLD, 1000, 0)).toBe(false)
		t.expect(ColdOpen.autoActive(1, ColdOpen.HANDOVER_DISTANCE, 0)).toBe(false)
		t.expect(ColdOpen.autoActive(1, 250, 1)).toBe(false)
		t.expect(ColdOpen.autoActive(1, 250, -1)).toBe(false)
	end)

	t.test(
		"hands off: the throttle is handed over well before the casualty and the ski coasts",
		function()
			for _, start in { 220, 240, 260, 400 } do
				local r = run(start, hands_off, true)
				t.expect(r.handoverAt ~= nil).toBeTruthy()
				t.expect((r.handoverTime :: number) <= ColdOpen.AUTO_HOLD + DT).toBeTruthy()
				t.expect((r.handoverAt :: number) >= ColdOpen.HANDOVER_DISTANCE - 1).toBeTruthy()
				-- coasting alone gets under the ease trigger before the ease radius: no ease needed
				t.expect(r.speedAt60 ~= nil and r.speedAt60 < ColdOpen.EASE_TRIGGER).toBeTruthy()
				t.expect(r.eased).toBe(false)
				-- and it arrives creeping (an idling jet), not at 25 knots
				t.expect(r.speedAtMin < 3 * KNOT).toBeTruthy()
			end
		end
	)

	t.test("a far casualty: the auto-throttle lets go on time", function()
		local r = run(600, hands_off, true)
		t.expect(math.abs((r.handoverTime :: number) - ColdOpen.AUTO_HOLD) < 0.05).toBeTruthy()
		t.expect((r.handoverAt :: number) > ColdOpen.HANDOVER_DISTANCE).toBeTruthy()
		t.expect(r.speedAtMin < 3 * KNOT).toBeTruthy()
	end)

	t.test("releasing W after the handover coasts and slows", function()
		-- full throttle for 2 s (takes over at once), then hands off
		local r = run(400, function(time)
			return if time < 2 then 1 else 0
		end, false)
		t.expect(r.handoverTime < DT * 2).toBeTruthy()
		t.expect(r.speedAtMin < 3 * KNOT).toBeTruthy()
	end)

	t.test("Assist eases a full-throttle rider to approach speed before the casualty", function()
		for _, start in { 220, 260, 400 } do
			local r = run(start, function()
				return 1
			end, true)
			t.expect(r.eased).toBe(true)
			-- still holding W: held near approach speed (never past the trigger) into contact range
			t.expect(r.maxInside20 ~= nil and r.maxInside20 <= ColdOpen.EASE_TRIGGER + 0.5)
				.toBeTruthy()
		end
	end)

	t.test("Pro (no Assist) never eases", function()
		local r = run(300, function()
			return 1
		end, false)
		t.expect(r.eased).toBe(false)
		t.expect(r.finalSpeed > 10 * KNOT).toBeTruthy()
	end)

	t.test("the ease only engages fast and inside the radius, and holds until slow", function()
		t.expect(
			ColdOpen.updateEase(false, true, ColdOpen.EASE_RADIUS - 1, ColdOpen.EASE_TRIGGER + 1)
		)
			.toBe(true)
		t.expect(
			ColdOpen.updateEase(false, true, ColdOpen.EASE_RADIUS - 1, ColdOpen.EASE_TRIGGER - 0.1)
		)
			.toBe(false)
		t.expect(
			ColdOpen.updateEase(false, true, ColdOpen.EASE_RADIUS + 1, ColdOpen.EASE_TRIGGER + 1)
		)
			.toBe(false)
		t.expect(ColdOpen.updateEase(false, false, 20, 40)).toBe(false)
		-- faster hulls engage further out (stopping distance)
		t.expect(ColdOpen.easeRadius(45, jet.brakeDecel) > 100).toBeTruthy()
		t.expect(ColdOpen.updateEase(false, true, 100, 45, jet.brakeDecel)).toBe(true)
		-- engaged: holds until down to the target
		t.expect(ColdOpen.updateEase(true, true, 90, ColdOpen.EASE_TARGET + 1)).toBe(true)
		t.expect(ColdOpen.updateEase(true, true, 30, ColdOpen.EASE_TARGET - 0.1)).toBe(false)
		-- reversing (negative forward speed) is never eased
		t.expect(ColdOpen.updateEase(false, true, 20, -10)).toBe(false)
	end)

	t.test("the ease brakes, never adds thrust", function()
		t.expect(ColdOpen.easeThrottle(30, 1) < -0.9).toBeTruthy()
		t.expect(ColdOpen.easeThrottle(ColdOpen.EASE_TARGET + 0.5, 1) <= -ColdOpen.EASE_MIN_BRAKE)
			.toBeTruthy()
		t.expect(ColdOpen.easeThrottle(ColdOpen.EASE_TARGET - 0.5, 1)).toBe(0)
		t.expect(ColdOpen.easeThrottle(ColdOpen.EASE_TARGET - 0.5, -0.4)).toBe(-0.4)
	end)

	t.test("the server sees a clear ease but not a slow, careful approach", function()
		t.expect(ColdOpen.serverSawEase(true, 25, 20, jet.brakeDecel)).toBe(true)
		t.expect(ColdOpen.serverSawEase(true, 25, ColdOpen.EASE_TARGET, jet.brakeDecel)).toBe(false)
		t.expect(ColdOpen.serverSawEase(true, 120, 20, jet.brakeDecel)).toBe(false)
		t.expect(ColdOpen.serverSawEase(false, 25, 20, jet.brakeDecel)).toBe(false)
	end)

	t.test("an eased approach is Silver at best", function()
		t.expect(ColdOpen.capGrade("Gold", true)).toBe("Silver")
		t.expect(ColdOpen.capGrade("Silver", true)).toBe("Silver")
		t.expect(ColdOpen.capGrade("Bronze", true)).toBe("Bronze")
		t.expect(ColdOpen.capGrade("Fail", true)).toBe("Fail")
		t.expect(ColdOpen.capGrade("Gold", false)).toBe("Gold")
	end)

	t.test("show, don't tell: casualty close ahead, no graded approach", function()
		t.expect(ColdOpen.DISTANCE[2] < ColdOpen.HANDOVER_DISTANCE).toBe(true) -- creeps on in
		t.expect(ColdOpen.DISTANCE[1] > ColdOpen.NUDGE_NEAR).toBe(true) -- one move to make
		t.expect(table.find(ColdOpen.PLAN, "approach")).toBe(nil)
		t.expect(table.find(ColdOpen.PLAN, "recovery") ~= nil).toBe(true)
	end)

	t.test("the world helps after 10 s without headway, never while closing in or near", function()
		local n = ColdOpen.newNudge(0)
		t.expect(ColdOpen.nudge(n, 0, 80)).toBe(false)
		t.expect(ColdOpen.nudge(n, 9.9, 79)).toBe(false)
		t.expect(ColdOpen.nudge(n, 10, 79)).toBe(true) -- sat still: flare
		t.expect(ColdOpen.nudge(n, 15, 85)).toBe(false) -- clock restarted
		t.expect(ColdOpen.nudge(n, 20, 85)).toBe(true)
		-- closing in keeps resetting it
		local m = ColdOpen.newNudge(0)
		for i = 0, 30 do
			t.expect(ColdOpen.nudge(m, i, 200 - i * 7)).toBe(false)
		end
		-- near: the casualty comes on their own
		local k = ColdOpen.newNudge(0)
		t.expect(ColdOpen.nudge(k, 0, 40)).toBe(false)
		t.expect(ColdOpen.nudge(k, 30, 40)).toBe(false)
	end)

	t.test("the first mission ends at a drop-off: held and at a shore point, not before", function()
		local hub = ColdOpen.SHORE[1].water -- Plot1's berth
		t.expect(ColdOpen.landed("held", hub + Vector3.new(5, 3, 10))).toBe(true)
		t.expect(ColdOpen.landed("swim", hub)).toBe(false) -- not holding on
		t.expect(ColdOpen.landed("held", Vector3.new(0, 0, 420))).toBe(false) -- still out at sea
		t.expect(ColdOpen.landed("held", hub + Vector3.new(0, 0, ColdOpen.SHORE_RADIUS + 1)))
			.toBe(false)
		-- every island's berth is a shore point (the cold open starts at yours)
		local HubLayout = t.load("src/shared/Config/HubLayout.luau")
		for _, island in HubLayout.Islands do
			local berth = island.berths.Boat.Position
			t.expect(ColdOpen.nearestShore(berth).id).toBe(island.id)
			t.expect(ColdOpen.landed("held", berth + Vector3.new(10, 1, 10))).toBe(true)
		end
	end)

	t.test(
		"from a berth the casualty is just off the cove, dead ahead, and home is behind",
		function()
			local HubLayout = t.load("src/shared/Config/HubLayout.luau")
			for _, island in HubLayout.Islands do
				local berth = island.berths.Boat
				for _, d in ColdOpen.DISTANCE do
					local cas = berth.Position + berth.LookVector * d
					-- past the island's rim (the cove mouth), and its nearest shore is this berth
					t.expect((cas - island.center):Dot(island.facing) > HubLayout.IslandRadius)
						.toBe(true)
					t.expect(ColdOpen.nearestShore(cas).id).toBe(island.id)
				end
			end
			-- no berth: Plot1's berth, facing out, home behind
			t.expect(ColdOpen.nearestShore(ColdOpen.SPAWN).id).toBe("Plot1")
		end
	)

	t.test(
		"the way home goes round what blocks the straight line, through the via turns",
		function()
			local V = function(x, z)
				return Vector3.new(x, 0, z)
			end
			local me, goal, via = V(0, 0), V(100, 0), { V(50, 50), V(50, -80) }
			local open = function()
				return true
			end
			t.expect(ColdOpen.nextHop(me, goal, via, open)).toBe(goal)
			-- a wall across x = 50 between z -40 and 40: the nearer turn round it
			local wall = function(a: Vector3, b: Vector3)
				if (a.X - 50) * (b.X - 50) >= 0 then
					return true
				end
				local z = a.Z + (b.Z - a.Z) * (50 - a.X) / (b.X - a.X)
				return math.abs(z) > 40
			end
			t.expect(ColdOpen.nextHop(me, goal, via, wall)).toBe(via[1])
			-- nothing clear at all: straight at the goal
			t.expect(ColdOpen.nextHop(me, goal, via, function()
				return false
			end)).toBe(goal)
		end
	)
end
