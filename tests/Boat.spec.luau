-- Boat: buoyancy, drag, thrust and steering math must float, glide and turn sensibly.
return function(t)
	local Buoyancy = t.load("src/shared/Boat/Buoyancy.luau")
	local Waves = t.load("src/shared/Waves.luau")
	local VehicleConfig = t.load("src/shared/Config/VehicleConfig.luau")
	local Wake = t.load("src/shared/Boat/Wake.luau")
	local NavLights = t.load("src/shared/Boat/NavLights.luau")
	local G = 29.43 -- Workspace.Gravity at 1 m = 3 studs
	local KNOT = 1.543
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
				force += Buoyancy.pointForce(
					depth,
					vy,
					spec.draft,
					mass,
					G,
					n,
					0,
					spec.dampingRatio
				)
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
		-- hydrodynamic offsets only act on wet points
		t.expect(Buoyancy.pointLift(-0.1, 0.6, w, 0.5)).toBe(0)
		t.expect(Buoyancy.pointLift(0.3, 0.6, w, 0.3)).toBeCloseTo(w, 1e-9)
	end)

	t.test("damping opposes vertical motion and is zero out of the water", function()
		t.expect(Buoyancy.pointDamping(0.5, 3, 0.6, 100, 1) < 0).toBeTruthy()
		t.expect(Buoyancy.pointDamping(0.5, -3, 0.6, 100, 1) > 0).toBeTruthy()
		t.expect(Buoyancy.pointDamping(-0.2, 5, 0.6, 100, 1)).toBe(0)
		-- slamming down meets more damping than rising (the bounce), and counts as a slam
		local down = Buoyancy.pointDamping(0.3, -3, 0.6, 100, 1)
		local up = -Buoyancy.pointDamping(0.3, 3, 0.6, 100, 1)
		t.expect(down > up * 2).toBeTruthy()
		t.expect(Buoyancy.slam(0.2, -20, 0.6) > 0).toBeTruthy()
		t.expect(Buoyancy.slam(0.2, -2, 0.6)).toBe(0)
		t.expect(Buoyancy.slam(-0.2, -20, 0.6)).toBe(0)
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
	local function run(
		spec,
		throttle: number,
		v0: number,
		seconds: number,
		mult: number,
		approach: boolean?,
		engine: boolean?,
		added: number?
	)
		local mass = spec.massHint
		local fwd = Vector3.new(0, 0, -1)
		local v = v0
		local dt = 1 / 60
		for _ = 1, math.floor(seconds / dt) do
			local thrust = Buoyancy.thrust(throttle, v, mass, spec, 1, mult, approach, engine)
			local drag = Buoyancy.drag(fwd * v, fwd, mass, spec, 1, mult, added):Dot(fwd)
			v += (thrust + drag) / mass * dt
		end
		return v
	end

	t.test("full throttle reaches top speed, and the gear bonus raises it", function()
		for _, id in VehicleConfig.Order do
			local spec = VehicleConfig.get(id)
			t.expect(run(spec, 1, 0, 60, 1)).toBeCloseTo(spec.topSpeed, spec.topSpeed * 0.02)
			t.expect(run(spec, 1, 0, 60, 1.2))
				.toBeCloseTo(spec.topSpeed * 1.2, spec.topSpeed * 0.03)
		end
	end)

	t.test("coasting slows down; reverse throttle brakes then backs up slowly", function()
		local spec = VehicleConfig.RIB -- in neutral (the jet ski idles forward, see below)
		t.expect(run(spec, 0, 40, 10, 1) < 10).toBeTruthy()
		t.expect(Buoyancy.thrust(-1, 20, 60, spec, 1, 1)).toBe(-60 * spec.brakeDecel)
		local back = run(spec, -1, 0, 20, 1)
		t.expect(back < 0).toBeTruthy()
		t.expect(-back <= spec.topSpeed * Buoyancy.REVERSE_SPEED_FRACTION + 1).toBeTruthy()
	end)

	t.test("no thrust or steering out of the water", function()
		local spec = VehicleConfig.RIB
		t.expect(Buoyancy.thrust(1, 10, 160, spec, 0, 1)).toBe(0)
		t.expect(Buoyancy.thrust(1, 10, 160, spec, 0, 1, true)).toBe(0)
		t.expect(Buoyancy.steerTorque(1, 10, 0, 500, spec, 0, 1)).toBe(0)
	end)

	t.test("steering right gives a negative yaw torque; no steer damps spin", function()
		local spec = VehicleConfig.JetSki
		t.expect(Buoyancy.steerTorque(1, 30, 0, 100, spec, 1, 1) < 0).toBeTruthy()
		t.expect(Buoyancy.steerTorque(-1, 30, 0, 100, spec, 1, 1) > 0).toBeTruthy()
		t.expect(Buoyancy.steerTorque(0, 30, 2, 100, spec, 1, 1) < 0).toBeTruthy()
		-- weaker at a standstill than at speed, and a jet barely steers off the throttle
		local slow = math.abs(Buoyancy.steerTorque(1, 0, 0, 100, spec, 1, 1, 1, G))
		local fast = math.abs(Buoyancy.steerTorque(1, 30, 0, 100, spec, 1, 1, 1, G))
		local coasting = math.abs(Buoyancy.steerTorque(1, 30, 0, 100, spec, 1, 1, 0, G))
		t.expect(slow < fast).toBeTruthy()
		t.expect(coasting < fast * 0.3).toBeTruthy()
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

	t.test("real dimensions, masses and speeds at 1 m = 3 studs", function()
		local ski, rib = VehicleConfig.JetSki, VehicleConfig.RIB
		t.expect(ski.hullSize.Z / 3).toBeCloseTo(3.3, 3.3 * 0.05)
		t.expect(rib.hullSize.Z / 3).toBeCloseTo(8.44, 8.44 * 0.05)
		t.expect(rib.hullSize.X / 3).toBeCloseTo(2.85, 2.85 * 0.05)
		t.expect(ski.topSpeed / KNOT).toBeCloseTo(45, 0.5)
		t.expect(rib.topSpeed / KNOT).toBeCloseTo(35, 0.5)
		-- 1 RMU = 37 kg: the jet ski with rider about 430 kg, the RIB with crew about 2.1 t
		t.expect(ski.massHint * 37).toBeCloseTo(430, 20)
		t.expect(rib.massHint * 37).toBeCloseTo(2100, 100)
		-- the hull floats at its displacement: mass / (waterplane x draft) is a sane block coefficient
		for _, spec in { ski, rib } do
			local cb = spec.massHint / (spec.hullSize.X * spec.hullSize.Z * spec.draft)
			t.expect(cb > 0.12 and cb < 0.75).toBeTruthy() -- a RIB's tubes make it low
		end
		-- approach mode is under 5 knots
		t.expect(ski.approachSpeed < 5 * KNOT and rib.approachSpeed < 5 * KNOT).toBeTruthy()
	end)

	t.test("accelerates like the real boats", function()
		-- PWC: 0 to 30 mph (40 studs/s) in about 2 to 4 s; RIB: 0 to 25 knots in about 8 to 14 s
		local function timeTo(spec, target)
			local v, time, dt = 0, 0, 1 / 60
			while v < target and time < 60 do
				v += (Buoyancy.thrust(1, v, 1, spec, 1, 1) + Buoyancy.drag(
					Vector3.new(0, 0, -v),
					Vector3.new(0, 0, -1),
					1,
					spec,
					1,
					1
				).Z * -1) * dt
				time += dt
			end
			return time
		end
		local ski = timeTo(VehicleConfig.JetSki, 40)
		local rib = timeTo(VehicleConfig.RIB, 25 * KNOT)
		t.expect(ski > 1.5 and ski < 4.5).toBeTruthy()
		t.expect(rib > 6 and rib < 16).toBeTruthy()
	end)

	t.test("turning circle grows with speed like a real hull", function()
		for _, spec in { VehicleConfig.JetSki, VehicleConfig.RIB } do
			local slowRadius = 6 / Buoyancy.maxYawRate(6, 1, spec, G)
			local fastRadius = spec.topSpeed / Buoyancy.maxYawRate(spec.topSpeed, 1, spec, G)
			t.expect(slowRadius < spec.hullSize.Z * 2).toBeTruthy() -- tight at low speed
			t.expect(fastRadius).toBeCloseTo(spec.topSpeed ^ 2 / (spec.maxLateralG * G), 1)
			t.expect(fastRadius > 90 and fastRadius < 150).toBeTruthy() -- 30 to 50 m at full speed
			-- it can pivot from a standstill on the throttle, not with it closed
			t.expect(Buoyancy.maxYawRate(0, 1, spec, G) > 0).toBeTruthy()
			t.expect(Buoyancy.maxYawRate(0, 0, spec, G)).toBe(0)
		end
	end)

	t.test("planing: the bow rises at the hump, then levels to the running trim", function()
		for _, spec in { VehicleConfig.JetSki, VehicleConfig.RIB } do
			t.expect(Buoyancy.planingFraction(0, spec)).toBe(0)
			t.expect(Buoyancy.planingFraction(spec.topSpeed, spec)).toBe(1)
			local hump = math.deg(Buoyancy.trimTarget(spec.humpSpeed * spec.topSpeed, 1, spec))
			local planed = math.deg(Buoyancy.trimTarget(spec.topSpeed, 1, spec))
			t.expect(hump > planed + 2).toBeTruthy()
			t.expect(planed).toBeCloseTo(spec.runningTrim, 0.01)
			-- stern squat: throttle at low speed trims the bow up; level with no way on
			t.expect(Buoyancy.trimTarget(2, 1, spec) > Buoyancy.trimTarget(2, 0, spec)).toBeTruthy()
			t.expect(Buoyancy.trimTarget(0, 0, spec)).toBe(0)
			-- the hump costs extra resistance; on the plane it is gone
			t.expect(Buoyancy.humpFraction(spec.topSpeed, spec)).toBe(0)
		end
	end)

	-- Heave + pitch of a rigid hull on flat water while accelerating from rest; returns the max
	-- and final pitch (degrees) and the final mean float point depth.
	local function planeRun(spec, seconds: number)
		local mass = spec.massHint
		local n = #spec.floatPoints
		local ix = mass * (spec.hullSize.Y ^ 2 + spec.hullSize.Z ^ 2) / 12
		local y = -spec.draft - spec.floatPoints[1].Y
		local vy, theta, omega, v = 0, 0, 0, 0
		local wake = 0
		local dt = 1 / 240
		local maxPitch, meanDepth = 0, 0
		for _ = 1, math.floor(seconds / dt) do
			v += (Buoyancy.thrust(1, v, 1, spec, 1, 1) + Buoyancy.drag(
				Vector3.new(0, 0, -v),
				Vector3.new(0, 0, -1),
				1,
				spec,
				1,
				1
			).Z * -1) * dt
			wake += (v - wake) * dt / Buoyancy.WAKE_LAG
			local catchUp = Buoyancy.wakeCatchUp(wake, v, spec)
			local plane = Buoyancy.planingFraction(v, spec)
			local trim = Buoyancy.trimTarget(v, 1, spec, 1, catchUp)
			local fy, torque = -mass * G, 0
			meanDepth = 0
			for _, p in spec.floatPoints do
				local py = y + p.Y - p.Z * math.sin(theta)
				local pvy = vy - p.Z * omega
				local depth = -py
				local offset = Buoyancy.liftOffset(p, spec.draft, spec.planingLift * plane, trim, 0)
				local f = Buoyancy.pointForce(
					depth,
					pvy,
					spec.draft,
					mass,
					G,
					n,
					offset,
					spec.dampingRatio
				)
				fy += f
				torque += f * -p.Z
				meanDepth += depth / n
			end
			local w = Buoyancy.UPRIGHT_FREQUENCY
			torque += ix * (w * w * (trim - theta) - Buoyancy.UPRIGHT_DAMPING * omega)
			vy += fy / mass * dt
			y += vy * dt
			omega += torque / ix * dt
			theta += omega * dt
			maxPitch = math.max(maxPitch, theta)
		end
		return math.deg(maxPitch), math.deg(theta), meanDepth
	end

	t.test(
		"a hull accelerating from rest pitches up at the hump and settles on the plane",
		function()
			for _, spec in { VehicleConfig.JetSki, VehicleConfig.RIB } do
				local maxPitch, finalPitch, depth = planeRun(spec, 40)
				t.expect(maxPitch > finalPitch + 1.5).toBeTruthy()
				t.expect(maxPitch < 15).toBeTruthy()
				t.expect(finalPitch).toBeCloseTo(spec.runningTrim, 1.5)
				-- dynamic lift: it rides higher on the plane than its rest draft
				t.expect(depth < spec.draft * 0.85).toBeTruthy()
				t.expect(depth > 0).toBeTruthy()
			end
		end
	)

	t.test("leans into the turn: a right turn puts the starboard side down", function()
		local spec = VehicleConfig.JetSki
		local lean = Buoyancy.leanTarget(40, -1, spec, G) -- right turn = negative yaw rate
		t.expect(lean > 0).toBeTruthy()
		t.expect(lean <= math.rad(spec.maxLean) + 1e-9).toBeTruthy()
		t.expect(Buoyancy.leanTarget(40, 1, spec, G) < 0).toBeTruthy()
		-- the starboard float points lift less, so the hull banks
		local stbd = Buoyancy.liftOffset(Vector3.new(1.4, 0, 0), spec.draft, 0, 0, lean)
		local port = Buoyancy.liftOffset(Vector3.new(-1.4, 0, 0), spec.draft, 0, 0, lean)
		t.expect(stbd < port).toBeTruthy()
		t.expect(math.deg(Buoyancy.leanTarget(40, -1, VehicleConfig.RIB, G)) <= 10 + 1e-9)
			.toBeTruthy()
	end)

	t.test("head seas and slamming cost speed", function()
		local spec = VehicleConfig.RIB
		local calm = run(spec, 1, 0, 60, 1, false, true, 0)
		local rough = run(spec, 1, 0, 60, 1, false, true, Buoyancy.addedResistance(0.4, 2)) -- a typical storm
		t.expect(rough < calm * 0.92).toBeTruthy() -- docs 02: storms cut cruise about 20%
		t.expect(rough > calm * 0.65).toBeTruthy()
	end)

	t.test("approach mode holds under 5 knots with fine throttle; neutral glides", function()
		for _, spec in { VehicleConfig.JetSki, VehicleConfig.RIB } do
			local full = run(spec, 1, 0, 20, 1, true)
			t.expect(full).toBeCloseTo(spec.approachSpeed, 0.6)
			t.expect(full < 5 * KNOT).toBeTruthy()
			t.expect(run(spec, 0.4, 0, 20, 1, true)).toBeCloseTo(spec.approachSpeed * 0.4, 0.4)
			-- from a fast run in, approach mode slows the hull down to the cap
			t.expect(run(spec, 1, 30, 20, 1, true) < 5 * KNOT).toBeTruthy()
			t.expect(Buoyancy.thrust(0, 3, 1, spec, 1, 1, true)).toBe(0)
		end
	end)

	t.test(
		"kill cord: no engine, no thrust; an idling jet ski creeps, the RIB sits in neutral",
		function()
			local ski, rib = VehicleConfig.JetSki, VehicleConfig.RIB
			t.expect(Buoyancy.thrust(1, 0, 10, ski, 1, 1, false, false)).toBe(0)
			t.expect(run(ski, 0, 0, 30, 1)).toBeCloseTo(ski.idleCreep, 0.6)
			t.expect(run(ski, 0, 0, 30, 1, false, false)).toBe(0)
			t.expect(run(rib, 0, 0, 30, 1)).toBe(0)
		end
	)

	t.test("chopping the throttle: the stern wave catches up and pushes the bow down", function()
		local spec = VehicleConfig.RIB
		local catchUp, push = Buoyancy.wakeCatchUp(30, 8, spec)
		t.expect(catchUp > 0 and push > 0).toBeTruthy()
		t.expect(Buoyancy.trimTarget(8, 0, spec, 1, catchUp) < Buoyancy.trimTarget(8, 0, spec))
			.toBeTruthy()
		t.expect(Buoyancy.wakeCatchUp(8, 30, spec)).toBe(0)
	end)

	t.test("wake pushes casualties astern and alongside, outward and fading", function()
		local hull = {
			position = Vector3.zero,
			velocity = Vector3.new(0, 0, -20),
			forward = Vector3.new(0, 0, -1),
			length = 25,
			beam = 8.5,
		}
		local push, height = Wake.at(Vector3.new(15, 0, 60), hull) -- astern, to starboard
		t.expect(height > 0).toBeTruthy()
		t.expect(push.X > 0).toBeTruthy() -- outward (starboard)
		local _, near = Wake.at(Vector3.new(8, 0, 40), hull)
		local _, far = Wake.at(Vector3.new(80, 0, 400), hull)
		t.expect(far < near).toBeTruthy()
		-- alongside: straight out from the hull
		local side = Wake.at(Vector3.new(-6, 0, 0), hull)
		t.expect(side.X < 0).toBeTruthy()
		-- well ahead or with no way on: nothing
		local ahead, aheadH = Wake.at(Vector3.new(0, 0, -200), hull)
		t.expect(ahead.Magnitude).toBe(0)
		t.expect(aheadH).toBe(0)
		local still = Wake.at(Vector3.new(15, 0, 60), {
			position = Vector3.zero,
			velocity = Vector3.zero,
			forward = hull.forward,
			length = 25,
			beam = 8.5,
		})
		t.expect(still.Magnitude).toBe(0)
		-- the biggest wake is near hull speed (Fr 0.5), smaller on the plane; wedge narrows at speed
		t.expect(Wake.heightFactor(0.5)).toBeCloseTo(1, 1e-9)
		t.expect(Wake.heightFactor(3) < 0.5).toBeTruthy()
		t.expect(Wake.halfAngle(0.3)).toBeCloseTo(math.asin(1 / 3), 1e-9)
		t.expect(Wake.halfAngle(3) < Wake.halfAngle(0.3)).toBeTruthy()
	end)

	t.test("nav lights at night and in storms only", function()
		t.expect(NavLights.shouldBeOn(13, 0)).toBe(false)
		t.expect(NavLights.shouldBeOn(22, 0)).toBe(true)
		t.expect(NavLights.shouldBeOn(4, 0)).toBe(true)
		t.expect(NavLights.shouldBeOn(13, 1)).toBe(true)
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
