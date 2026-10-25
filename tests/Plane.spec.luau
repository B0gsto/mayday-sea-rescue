-- Seaplane (docs/23 h, WP-7): taxi, take off, bank to turn, stall-safe glide, land or bounce, pick-up.
return function(t)
	local Flight = t.load("src/shared/Plane/Flight.luau")
	local VehicleConfig = t.load("src/shared/Config/VehicleConfig.luau")
	local Board = t.load("src/shared/Ops/Board.luau")
	local spec = Flight.get("Seaplane")
	local DT = 1 / 60

	-- runs n seconds, integrating altitude from the plane's climb; returns the events seen
	local function fly(s, input, altitude, seconds)
		local events = {}
		for _ = 1, math.floor(seconds / DT) do
			local e = Flight.step(s, input, altitude, DT, spec)
			if e then
				table.insert(events, e)
			end
			altitude = math.max(altitude + s.climb * DT, if s.airborne then -1 else 0)
		end
		return events, altitude
	end

	local function newState(airborne, speed)
		local s = Flight.fromCFrame(CFrame.identity, speed)
		s.airborne = airborne
		return s
	end

	t.test("only planes have a flight spec", function()
		t.expect(spec ~= nil).toBe(true)
		t.expect(Flight.get("RIB")).toBeNil()
		t.expect(Flight.get(nil)).toBeNil()
	end)

	t.test("the fastest vehicle: about 1.5x the fastest boat", function()
		local fastest = 0
		for _, id in VehicleConfig.Order do
			fastest = math.max(fastest, VehicleConfig.get(id).topSpeed)
		end
		t.expect(spec.topSpeed > fastest * 1.4).toBe(true)
		t.expect(spec.topSpeed < fastest * 1.7).toBe(true)
	end)

	t.test("taxis on the water like a slow boat; no pull, no flight", function()
		local s = newState(false, 0)
		local events = fly(s, { throttle = 0.3, steer = 1, pitch = 0 }, 0, 5)
		t.expect(#events).toBe(0)
		t.expect(s.airborne).toBe(false)
		t.expect(s.speed).toBeCloseTo(0.3 * spec.waterTopSpeed, 0.1)
		t.expect(s.yaw < 0).toBe(true) -- steer right turns right
		t.expect(s.bank).toBe(0)
	end)

	t.test("pulling up below take-off speed stays on the water; at speed it flies", function()
		local s = newState(false, spec.takeOffSpeed - 10)
		Flight.step(s, { throttle = 0, steer = 0, pitch = 1 }, 0, DT, spec)
		t.expect(s.airborne).toBe(false)
		s = newState(false, 0)
		local events = fly(s, { throttle = 1, steer = 0, pitch = 1 }, 0, 6)
		t.expect(events[1]).toBe("takeoff")
		t.expect(s.airborne).toBe(true)
		t.expect(s.climb > 0).toBe(true)
	end)

	t.test("bank to turn; hands off levels the wings and nose and holds height", function()
		local s = newState(true, spec.topSpeed)
		local _, alt = fly(s, { throttle = 1, steer = 1, pitch = 1 }, 200, 1)
		t.expect(s.bank > 0).toBe(true)
		t.expect(s.yaw < 0).toBe(true)
		t.expect(alt > 200).toBe(true)
		local yaw = s.yaw
		local level = fly(s, { throttle = 1, steer = 0, pitch = 0 }, alt, 2)
		t.expect(#level).toBe(0)
		t.expect(s.bank).toBe(0)
		t.expect(s.pitch).toBe(0)
		t.expect(s.climb).toBeCloseTo(0, 1e-6)
		t.expect(math.abs(s.yaw - yaw) < math.rad(spec.turnRate)).toBe(true) -- stopped turning
	end)

	t.test("stall-safe: throttle off and pulling up just glides down gently", function()
		local s = newState(true, spec.topSpeed)
		for _ = 1, 30 * 60 do
			Flight.step(s, { throttle = 0, steer = 0, pitch = 1 }, 300, DT, spec)
			t.expect(s.speed >= spec.glideSpeed).toBe(true)
		end
		t.expect(s.speed).toBe(spec.glideSpeed)
		t.expect(s.climb).toBeCloseTo(-spec.glideSink, 1e-6)
		t.expect(s.airborne).toBe(true)
	end)

	t.test("a slow, level glide lands on the water", function()
		local s = newState(true, spec.glideSpeed)
		local events = fly(s, { throttle = 0, steer = 0, pitch = 0 }, 40, 10)
		t.expect(events[#events]).toBe("landed")
		t.expect(s.airborne).toBe(false)
	end)

	t.test("too steep or too fast bounces (no damage) and bleeds speed until it lands", function()
		local s = newState(true, spec.topSpeed)
		s.pitch = -math.rad(spec.maxPitch)
		local e = Flight.step(s, { throttle = 1, steer = 0, pitch = -1 }, 0, DT, spec)
		t.expect(e).toBe("bounce")
		t.expect(s.airborne).toBe(true)
		t.expect(s.climb > 0).toBe(true)
		s = newState(true, spec.topSpeed)
		local events = fly(s, { throttle = 0, steer = 0, pitch = -1 }, 30, 30)
		t.expect(events[1]).toBe("bounce")
		t.expect(events[#events]).toBe("landed")
	end)

	t.test("banked touch-down bounces", function()
		local s = newState(true, spec.glideSpeed)
		s.bank = math.rad(spec.maxBank)
		s.climb = -5
		t.expect(Flight.step(s, { throttle = 0, steer = 1, pitch = 0 }, -0.1, DT, spec))
			.toBe("bounce")
	end)

	t.test("pick-up only on the water, with the boats' hold-steady rule", function()
		local floating = Flight.altitude(10 + spec.hullSize.Y / 2 - spec.draft, 10, spec)
		t.expect(floating).toBeCloseTo(0, 1e-6)
		t.expect(Flight.mayBoard(floating, 3, 2, 5, true)).toBe(true)
		t.expect(Flight.mayBoard(20, 3, 2, 5, true)).toBe(false) -- flying over them
		t.expect(Flight.mayBoard(floating, 3, Board.STEADY_SPEED + 1, 5, true)).toBe(false)
		t.expect(Flight.mayBoard(floating, 3, 2, 5, false)).toBe(false) -- full
		t.expect(spec.seats).toBe(4)
	end)

	t.test("attitude and velocity agree with the heading", function()
		local s = Flight.fromCFrame(CFrame.lookAt(Vector3.zero, Vector3.new(1, 0, 0)), 50)
		t.expect(Flight.attitude(s).LookVector.X).toBeCloseTo(1, 1e-6)
		t.expect(Flight.velocity(s).X).toBeCloseTo(50, 1e-6)
		s.bank = math.rad(30)
		t.expect(Flight.attitude(s).RightVector.Y < 0).toBe(true) -- right wing down
		s.pitch = math.rad(10)
		t.expect(Flight.attitude(s).LookVector.Y > 0).toBe(true)
	end)

	t.test("placeholder model: 4 seats, 4 survivor slots, movers off until flown", function()
		local m = t.load("src/shared/Plane/Builder.luau").build(spec)
		local root = m.PrimaryPart
		local seats = 0
		for _, d in m:GetChildren() do
			if d:IsA("Seat") or d:IsA("VehicleSeat") then
				seats += 1
			end
		end
		t.expect(seats).toBe(spec.seats)
		t.expect(root:FindFirstChild("SurvivorSlot4") ~= nil).toBe(true)
		t.expect(root:FindFirstChild("FloatForce4") ~= nil).toBe(true)
		t.expect(root:FindFirstChild("FlyVelocity").Enabled).toBe(false)
		t.expect(m:FindFirstChild("Body"):FindFirstChild("PropJoint") ~= nil).toBe(true)
		t.expect(m:GetAttribute("Capacity")).toBe(spec.survivorCapacity)
	end)
end
