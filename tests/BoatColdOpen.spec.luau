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
		t.expect(ColdOpen.updateEase(false, true, 59, ColdOpen.EASE_TRIGGER + 1)).toBe(true)
		t.expect(ColdOpen.updateEase(false, true, 59, ColdOpen.EASE_TRIGGER - 0.1)).toBe(false)
		t.expect(ColdOpen.updateEase(false, true, 61, ColdOpen.EASE_TRIGGER + 1)).toBe(false)
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
		t.expect(ColdOpen.serverSawEase(true, 50, 20, jet.brakeDecel)).toBe(true)
		t.expect(ColdOpen.serverSawEase(true, 50, ColdOpen.EASE_TARGET, jet.brakeDecel)).toBe(false)
		t.expect(ColdOpen.serverSawEase(true, 120, 20, jet.brakeDecel)).toBe(false)
		t.expect(ColdOpen.serverSawEase(false, 50, 20, jet.brakeDecel)).toBe(false)
	end)

	t.test("an eased approach is Silver at best", function()
		t.expect(ColdOpen.capGrade("Gold", true)).toBe("Silver")
		t.expect(ColdOpen.capGrade("Silver", true)).toBe("Silver")
		t.expect(ColdOpen.capGrade("Bronze", true)).toBe("Bronze")
		t.expect(ColdOpen.capGrade("Fail", true)).toBe("Fail")
		t.expect(ColdOpen.capGrade("Gold", false)).toBe("Gold")
	end)
end
