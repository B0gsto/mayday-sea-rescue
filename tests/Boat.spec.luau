-- Boat: buoyancy, drag, thrust and steering math must float, glide and turn sensibly.
return function(t)
	local Buoyancy = t.load("src/shared/Boat/Buoyancy.luau")
	local Waves = t.load("src/shared/Waves.luau")
	local VehicleConfig = t.load("src/shared/Config/VehicleConfig.luau")
	local G = 196.2
	local T0 = 1760000000.25

	-- Vertical-only rigid hull: every float point shares the root's height and vertical speed.
	-- Returns the mean float point depth over the last 2 s of a run.
	local function settle(spec, waterAt: (number, number, number) -> number, seconds: number)
		local mass = spec.massHint
		local n = #spec.floatPoints
		local y = 3 -- root centre starts above the water
		local vy = 0
		local dt = 1 / 240
		local steps = math.floor(seconds / dt)
		local depthSum, depthCount = 0, 0
		for step = 1, steps do
			local time = T0 + step * dt
			local force = -mass * G
			local meanDepth = 0
			for _, p in spec.floatPoints do
				local depth = waterAt(p.X, p.Z, time) - (y + p.Y)
				force += Buoyancy.pointForce(depth, vy, spec.draft, mass, G, n)
				meanDepth += depth / n
			end
			vy += force / mass * dt
			y += vy * dt
			if step * dt > seconds - 2 then
				depthSum += meanDepth
				depthCount += 1
			end
		end
		return depthSum / depthCount
	end

	t.test("hulls float at rest at their draft on flat water", function()
		for _, id in VehicleConfig.Order do
			local spec = VehicleConfig.get(id)
			local depth = settle(spec, function()
				return 0
			end, 8)
			t.expect(depth).toBeCloseTo(spec.draft, 0.02)
		end
	end)

	t.test("hulls stay afloat near the draft in calm waves and storms", function()
		for _, params in { Waves.paramsFor(0, 0, 0), Waves.paramsFor(1, 0, 0.7) } do
			local spec = VehicleConfig.RIB
			local depth = settle(spec, function(x, z, time)
				return Waves.heightAt(x, z, time, params)
			end, 10)
			t.expect(depth > 0).toBeTruthy()
			t.expect(depth < spec.draft * Buoyancy.DEPTH_RANGE).toBeTruthy()
		end
	end)

	t.test("rest root height puts the float points one draft under", function()
		local spec = VehicleConfig.JetSki
		local y = Buoyancy.restRootY(0.5, spec.draft, spec.floatPoints[1].Y)
		t.expect(0.5 - (y + spec.floatPoints[1].Y)).toBeCloseTo(spec.draft, 1e-9)
	end)

	t.test("lift balances weight at the draft and is clamped", function()
		local w = 100
		t.expect(Buoyancy.pointLift(0.6, 0.6, w)).toBeCloseTo(w, 1e-9)
		t.expect(Buoyancy.pointLift(-1, 0.6, w)).toBe(0)
		local cap = w * Buoyancy.DEPTH_RANGE
		t.expect(Buoyancy.pointLift(50, 0.6, w)).toBeCloseTo(cap, 1e-9)
		t.expect(Buoyancy.pointLift(1e6, 0.6, w)).toBeCloseTo(cap, 1e-9)
		-- the full point force (lift + damping) is bounded too, even at absurd speeds
		local f = Buoyancy.pointForce(1e6, -1e6, 0.6, 60, G, 4)
		t.expect(f <= 2 * (60 * G / 4) * Buoyancy.DEPTH_RANGE + 1e-6).toBeTruthy()
	end)

	t.test("damping opposes vertical motion and is zero out of the water", function()
		t.expect(Buoyancy.pointDamping(0.5, 3, 0.6, 100, 1) < 0).toBeTruthy()
		t.expect(Buoyancy.pointDamping(0.5, -3, 0.6, 100, 1) > 0).toBeTruthy()
		t.expect(Buoyancy.pointDamping(-0.2, 5, 0.6, 100, 1)).toBe(0)
	end)

	t.test("lateral drag exceeds forward drag at the same speed", function()
		for _, id in VehicleConfig.Order do
			local spec = VehicleConfig.get(id)
			local fwd = Vector3.new(0, 0, -1)
			local speed = 20
			local dF = Buoyancy.drag(fwd * speed, fwd, spec.massHint, spec, 1, 1)
			local dL = Buoyancy.drag(Buoyancy.rightOf(fwd) * speed, fwd, spec.massHint, spec, 1, 1)
			t.expect(dL.Magnitude > dF.Magnitude * 3).toBeTruthy()
			-- drag opposes the motion
			t.expect(dF:Dot(fwd) < 0).toBeTruthy()
		end
	end)

	t.test("right vector is +X for a -Z forward", function()
		local r = Buoyancy.rightOf(Vector3.new(0, 0, -1))
		t.expect(r.X).toBeCloseTo(1, 1e-9)
		t.expect(r.Z).toBeCloseTo(0, 1e-9)
	end)

	-- 1D forward run: returns the speed after `seconds` at a fixed throttle.
	local function run(spec, throttle: number, v0: number, seconds: number, mult: number)
		local mass = spec.massHint
		local fwd = Vector3.new(0, 0, -1)
		local v = v0
		local dt = 1 / 60
		for _ = 1, math.floor(seconds / dt) do
			local thrust = Buoyancy.thrust(throttle, v, mass, spec, 1, mult)
			local drag = Buoyancy.drag(fwd * v, fwd, mass, spec, 1, mult):Dot(fwd)
			v += (thrust + drag) / mass * dt
		end
		return v
	end

	t.test("full throttle reaches top speed, and the gear bonus raises it", function()
		for _, id in VehicleConfig.Order do
			local spec = VehicleConfig.get(id)
			t.expect(run(spec, 1, 0, 30, 1)).toBeCloseTo(spec.topSpeed, spec.topSpeed * 0.02)
			t.expect(run(spec, 1, 0, 30, 1.2))
				.toBeCloseTo(spec.topSpeed * 1.2, spec.topSpeed * 0.03)
		end
	end)

	t.test("coasting slows down; reverse throttle brakes then backs up slowly", function()
		local spec = VehicleConfig.JetSki
		t.expect(run(spec, 0, 40, 10, 1) < 10).toBeTruthy()
		t.expect(Buoyancy.thrust(-1, 20, 60, spec, 1, 1)).toBe(-60 * spec.brakeDecel)
		local back = run(spec, -1, 0, 20, 1)
		t.expect(back < 0).toBeTruthy()
		t.expect(-back <= spec.topSpeed * Buoyancy.REVERSE_SPEED_FRACTION + 1).toBeTruthy()
	end)

	t.test("no thrust or steering out of the water", function()
		local spec = VehicleConfig.RIB
		t.expect(Buoyancy.thrust(1, 10, 160, spec, 0, 1)).toBe(0)
		t.expect(Buoyancy.steerTorque(1, 10, 0, 500, spec, 0, 1)).toBe(0)
	end)

	t.test("steering right gives a negative yaw torque; no steer damps spin", function()
		local spec = VehicleConfig.JetSki
		t.expect(Buoyancy.steerTorque(1, 30, 0, 100, spec, 1, 1) < 0).toBeTruthy()
		t.expect(Buoyancy.steerTorque(-1, 30, 0, 100, spec, 1, 1) > 0).toBeTruthy()
		t.expect(Buoyancy.steerTorque(0, 30, 2, 100, spec, 1, 1) < 0).toBeTruthy()
		-- weaker at a standstill than at speed
		local slow = math.abs(Buoyancy.steerTorque(1, 0, 0, 100, spec, 1, 1))
		local fast = math.abs(Buoyancy.steerTorque(1, 40, 0, 100, spec, 1, 1))
		t.expect(slow < fast).toBeTruthy()
	end)

	t.test("upright torque rolls a tilted hull back toward level", function()
		local a = math.rad(30)
		local up = Vector3.new(math.sin(a), math.cos(a), 0) -- rolled toward +X
		local torque = Buoyancy.uprightTorque(up, Vector3.zero, 10)
		-- a positive Z torque rotates +X toward +Y, i.e. brings `up` back toward +Y
		t.expect(torque.Z > 0).toBeTruthy()
		t.expect(Buoyancy.uprightTorque(Vector3.yAxis, Vector3.zero, 10).Magnitude)
			.toBeCloseTo(0, 1e-9)
	end)

	t.test("buoyancy math is fast", function()
		local spec = VehicleConfig.RIB
		local params = Waves.paramsFor(1, 0, 0)
		local start = os.clock()
		local acc = 0
		for i = 1, 20000 do
			local h = Buoyancy.waterHeight(i * 0.3, i * 0.1, T0, params)
			acc += Buoyancy.pointForce(h + 0.5, 1, spec.draft, 160, G, 6)
		end
		t.expect(acc == acc).toBeTruthy()
		t.expectFast(os.clock() - start, 0.1, "20k float point updates")
	end)
end
