-- Car: raycast chassis maths (suspension, tyres, drivetrain, steering) must behave like real
-- vehicles at the project's scale (1 m = 3 studs, gravity 29.43 studs/s^2).
return function(t)
	local Chassis = t.load("src/shared/Car/Chassis.luau")
	local Tyre = t.load("src/shared/Car/Tyre.luau")
	local Suspension = t.load("src/shared/Car/Suspension.luau")
	local Drivetrain = t.load("src/shared/Car/Drivetrain.luau")
	local LightBar = t.load("src/shared/Car/LightBar.luau")
	local Trailer = t.load("src/shared/Car/Trailer.luau")
	local Units = t.load("src/shared/Car/Units.luau")
	local Config = t.load("src/shared/Config/LandVehicleConfig.luau")
	local G = 29.43

	-- Straight-line run: loads from the static split plus longitudinal weight transfer,
	-- contact speeds = body speed. Returns the final speed, distance, max gear, shift count and
	-- whether any wheel slid. control(time, speed) -> throttle, handbrake?
	local function run(spec, opts)
		local d = Chassis.prepare(spec)
		local state = Chassis.newState()
		local surface = Tyre.Surfaces[opts.surface or "Asphalt"]
		local grip = Tyre.grip(surface, opts.wetness or 0)
		local v = opts.v0 or 0
		local x, accel = 0, 0
		local dt = 1 / 60
		local maxGear, shifts, lastGear, slid = 1, 0, state.gear, false
		local h = spec.cgHeight * 3
		local timeTo = {}
		for step = 1, math.floor(opts.seconds / dt) do
			local time = step * dt
			local throttle = opts.control(time, v)
			local transfer = Suspension.loadTransfer(d.mass, accel, h, d.wheelbase)
			local contacts = {}
			for i, w in d.wheels do
				local load = w.cornerMass * G + (if w.front then -transfer / 2 else transfer / 2)
				contacts[i] = {
					contact = true,
					compression = math.max(0, load / w.k),
					compressionSpeed = 0,
					vLong = v,
					vLat = 0,
					grip = grip,
					rolling = surface.rolling,
				}
			end
			local results, tel = Chassis.step(d, state, {
				throttle = throttle,
				steer = 0,
				handbrake = false,
				lowRange = opts.lowRange == true,
				assists = opts.assists ~= false,
			}, contacts, v, dt)
			local f = -math.sign(v) * Chassis.drag(d, v)
			for _, r in results do
				f += r.fx
				slid = slid or r.sliding
			end
			accel = f / d.mass
			v += accel * dt
			x += v * dt
			if tel.gear > maxGear then
				maxGear = tel.gear
			end
			if tel.gear ~= lastGear then
				shifts += 1
				lastGear = tel.gear
			end
			for _, mark in { 50, 70 } do
				if not timeTo[mark] and v >= mark then
					timeTo[mark] = time
				end
			end
			if opts.stopAt and math.abs(v) < opts.stopAt then
				break
			end
		end
		return {
			v = v,
			x = x,
			maxGear = maxGear,
			shifts = shifts,
			slid = slid,
			timeTo = timeTo,
			state = state,
		}
	end

	local full = function()
		return 1
	end
	local brakeHard = function()
		return -1
	end

	t.test("units: a 2,200 kg pickup is 59.5 RMU; 90 km/h is 75 studs/s", function()
		t.expect(2200 * Units.KG).toBeCloseTo(59.46, 0.01)
		t.expect(90 * Units.KMH).toBeCloseTo(75, 1e-6)
		t.expect(Config.LifeguardPickup.topSpeed).toBe(75)
	end)

	t.test("suspension: rest sag sits mid-travel and the ride frequency is real", function()
		local d = Chassis.prepare(Config.LifeguardPickup)
		t.expect(#d.wheels).toBe(4)
		for _, w in d.wheels do
			local fraction = w.sag / w.travel
			t.expect(fraction > 0.25 and fraction < 0.75).toBe(true)
			local hz = math.sqrt(w.k / w.cornerMass) / (2 * math.pi)
			t.expect(hz > 1.2 and hz < 1.8).toBe(true)
		end
		-- the corner loads add up to the weight
		local total = 0
		for _, w in d.wheels do
			total += w.cornerMass * G
		end
		t.expect(total).toBeCloseTo(d.mass * G, 1e-6)
	end)

	t.test("suspension: a dropped corner settles at its sag without bouncing on and on", function()
		local d = Chassis.prepare(Config.LifeguardPickup)
		local w = d.wheels[1]
		local y, vy, dt = 0, 0, 1 / 240 -- compression and its rate
		local maxY = 0
		for _ = 1, 240 * 3 do
			local f = Suspension.force(y, vy, w.k, w.c, w.travel)
			local a = (w.cornerMass * G - f) / w.cornerMass
			vy += a * dt
			y += vy * dt
			maxY = math.max(maxY, y)
		end
		t.expect(y).toBeCloseTo(w.sag, 0.01)
		t.expect(maxY < w.sag * 2.1).toBe(true) -- under-damped (0.55) and not bouncy
	end)

	t.test("suspension: anti-roll bar and weight transfer formulas", function()
		local l, r = Suspension.antiRoll(0.5, 0.2, 100)
		t.expect(l).toBeCloseTo(30, 1e-6)
		t.expect(r).toBeCloseTo(-30, 1e-6)
		local f, rr = Suspension.staticAxleLoads(10, G, 0.6)
		t.expect(f + rr).toBeCloseTo(10 * G, 1e-6)
		t.expect(Suspension.loadTransfer(10, 5, 2, 4)).toBeCloseTo(25, 1e-6)
	end)

	t.test(
		"tyre: the curve peaks near 12 % slip and slides lower; ellipse caps combined force",
		function()
			local peakSlip = Tyre.peakSlip(11, 1.65)
			t.expect(peakSlip > 0.08 and peakSlip < 0.16).toBe(true)
			t.expect(Tyre.curve(peakSlip, 11, 1.65)).toBeCloseTo(1, 1e-6)
			t.expect(Tyre.curve(1, 11, 1.65) < 0.8).toBe(true)
			local f, slip, sliding = Tyre.longitudinal(50, 100, 11, 1.65, false)
			t.expect(f).toBe(50)
			t.expect(slip > 0 and slip < peakSlip).toBe(true)
			t.expect(sliding).toBe(false)
			local f2, _, sliding2 = Tyre.longitudinal(300, 100, 11, 1.65, false)
			t.expect(sliding2).toBe(true)
			t.expect(f2 < 100).toBe(true)
			local f3 = Tyre.longitudinal(-300, 100, 11, 1.65, true)
			t.expect(f3).toBeCloseTo(-97, 1e-6)
			local fx, fy = Tyre.combine(100, 100, 100, 100)
			t.expect(fx * fx + fy * fy).toBeCloseTo(100 * 100, 1e-3)
			-- lateral peaks at a realistic slip angle (6 to 12 degrees)
			local alphaPeak = math.deg(Tyre.peakSlip(13, 1.35))
			t.expect(alphaPeak > 6 and alphaPeak < 12).toBe(true)
			local fyl = Tyre.lateral(5, 30, 100, 13, 1.35)
			t.expect(fyl < 0).toBe(true)
		end
	)

	t.test("tyre: surface table and rain (docs 10 section 2.2)", function()
		t.expect(Tyre.grip(Tyre.Surfaces.Asphalt, 0)).toBe(1)
		t.expect(Tyre.grip(Tyre.Surfaces.Asphalt, 1)).toBeCloseTo(0.75, 1e-6)
		t.expect(Tyre.grip(Tyre.Surfaces.Mud, 0)).toBeCloseTo(0.35, 1e-6)
		t.expect(Tyre.surfaceFor("Sand", 20).id).toBe("Sand")
		t.expect(Tyre.surfaceFor("Sand", 1).id).toBe("WetSand")
		t.expect(Tyre.surfaceFor("Concrete", 0).id).toBe("Slipway")
		t.expect(Tyre.surfaceFor("Asphalt", 0).id).toBe("Asphalt")
		t.expect(Tyre.surfaceFor("SmoothPlastic", 20).id).toBe("Concrete")
		t.expect(Tyre.surfaceFor("LeafyGrass", 20).id).toBe("Grass")
		t.expect(Tyre.wetness(0)).toBe(0)
		t.expect(Tyre.wetness(1)).toBe(1)
	end)

	t.test("drivetrain: torque curve, redline cut, engine braking, no gear hunting", function()
		local e = Config.LifeguardPickup.engine
		local gb = Config.LifeguardPickup.gearbox
		t.expect(Drivetrain.torqueAt(e, 2000)).toBe(500)
		t.expect(Drivetrain.torqueAt(e, 1400)).toBeCloseTo(440, 1e-6)
		t.expect(Drivetrain.torqueAt(e, 3900)).toBe(0)
		t.expect(Drivetrain.crankTorque(e, 3000, 0) < 0).toBe(true)
		local rpm, mult = Drivetrain.engineState(e, 0, Drivetrain.ratio(gb, 1, false), 1)
		t.expect(rpm).toBe(e.stallRpm)
		t.expect(mult).toBeCloseTo(e.converterGain, 1e-6)
		t.expect(Drivetrain.ratio(gb, 1, true)).toBeCloseTo(3.6 * 3.909 * 2.566, 1e-6)
		-- at any wheel speed and throttle, an up-change is never followed straight by a down-change
		for omega = 1, 70, 0.5 do
			for _, thr in { 0, 0.3, 0.6, 1 } do
				for gear = 1, 5 do
					local up = Drivetrain.autoShift(gb, gear, omega, thr, false)
					if up > gear then
						t.expect(Drivetrain.autoShift(gb, up, omega, thr, false) >= up).toBe(true)
					end
				end
			end
		end
	end)

	t.test("pickup: governed at 90 km/h, 0-60 km/h in an arcade-quick time, six gears", function()
		local r = run(Config.LifeguardPickup, { seconds = 40, control = full })
		t.expect(r.v > 73 and r.v < 76.5).toBe(true)
		t.expect(r.timeTo[50] > 2.5 and r.timeTo[50] < 4).toBe(true)
		t.expect(r.maxGear >= 5).toBe(true)
		t.expect(r.shifts <= 8).toBe(true)
	end)

	t.test(
		"pickup: stops from 90 km/h in about 35 m dry, longer wet, longer without ABS",
		function()
			local stop = function(opts)
				opts.seconds = 20
				opts.control = brakeHard
				opts.v0 = 75
				opts.stopAt = 0.5
				return run(Config.LifeguardPickup, opts)
			end
			local dry = stop({})
			t.expect(dry.x > 85 and dry.x < 150).toBe(true) -- 28 to 50 m
			local wet = stop({ wetness = 1 })
			t.expect(wet.x > dry.x * 1.15).toBe(true)
			local noAbs = stop({ assists = false })
			t.expect(noAbs.slid).toBe(true)
			t.expect(noAbs.x > dry.x).toBe(true)
			local mud = stop({ surface = "Mud" })
			t.expect(mud.x > dry.x * 2).toBe(true)
		end
	)

	t.test("pickup: soft sand drags it down; low range climbs out", function()
		-- 4 s: before the road run reaches the governor
		local road = run(Config.LifeguardPickup, { seconds = 4, control = full })
		local sand = run(Config.LifeguardPickup, { seconds = 4, control = full, surface = "Sand" })
		t.expect(sand.v < road.v * 0.9).toBe(true)
		local low = run(Config.LifeguardPickup, { seconds = 30, control = full, lowRange = true })
		t.expect(low.v < 65).toBe(true) -- low range runs out of revs
	end)

	t.test("pickup: reverses from a stop under the reverse limit", function()
		local r = run(Config.LifeguardPickup, { seconds = 10, control = brakeHard })
		t.expect(r.state.gear).toBe(-1)
		t.expect(r.v < -10).toBe(true)
		t.expect(r.v > -(Config.LifeguardPickup.reverseSpeed + 1)).toBe(true)
	end)

	t.test("lateral grip: about 0.9 g on dry asphalt, under 0.4 g on mud", function()
		local d = Chassis.prepare(Config.LifeguardPickup)
		local function lateralG(surface)
			local state = Chassis.newState()
			local s = Tyre.Surfaces[surface]
			local contacts = {}
			for i, w in d.wheels do
				contacts[i] = {
					contact = true,
					compression = w.sag,
					compressionSpeed = 0,
					vLong = 50,
					vLat = 50 * math.tan(math.rad(9)),
					grip = Tyre.grip(s, 0),
					rolling = 0,
				}
			end
			local results = Chassis.step(d, state, {
				throttle = 0.3,
				steer = 0,
				handbrake = false,
				lowRange = false,
				assists = true,
			}, contacts, 50, 1 / 60)
			local fy = 0
			for _, r in results do
				fy += r.fy
			end
			return -fy / (d.mass * G)
		end
		local dry = lateralG("Asphalt")
		t.expect(dry > 0.8 and dry < 1.05).toBe(true)
		t.expect(lateralG("Mud") < 0.4).toBe(true)
	end)

	t.test("steering: speed-sensitive lock and Ackermann", function()
		local spec = Config.LifeguardPickup
		t.expect(Chassis.steerLock(spec, 0)).toBe(32)
		t.expect(Chassis.steerLock(spec, 75) < 6).toBe(true)
		local d = Chassis.prepare(spec)
		local inner, outer = Chassis.ackermann(math.rad(30), d.wheelbase, d.track)
		t.expect(inner > outer).toBe(true)
		t.expect(outer > 0).toBe(true)
		-- turning circle: kerb to kerb about 12.6 m for the pickup
		local radius = d.wheelbase / math.sin(math.rad(spec.steerLock)) + d.track / 2
		t.expect(radius / 3 > 5.5 and radius / 3 < 7).toBe(true)
		-- steering is rate limited and comes back
		local state = Chassis.newState()
		Chassis.updateSteer(d, state, 1, 0, 0.1)
		t.expect(state.steerAngle).toBeCloseTo(11, 1e-6)
	end)

	t.test("ATV and response vehicle reach their doc 02 top speeds", function()
		local atv = run(Config.BeachATV, { seconds = 30, control = full })
		t.expect(atv.v > 43 and atv.v < 46.5).toBe(true)
		local resp = run(Config.CoastguardResponse, { seconds = 40, control = full })
		t.expect(resp.v > 68 and resp.v < 71.5).toBe(true)
	end)

	t.test("trailer: four undriven wheels behind its centre of mass; launch rule", function()
		local d = Chassis.prepare(Config.BoatTrailer, 1800)
		t.expect(#d.wheels).toBe(4)
		t.expect(d.mass).toBeCloseTo(2450 / 37, 1e-6)
		for _, w in d.wheels do
			t.expect(w.driven).toBe(false)
			t.expect(w.steered).toBe(false)
		end
		t.expect(Trailer.canLaunch(2, 0.5)).toBe(true)
		t.expect(Trailer.canLaunch(0.5, 0.5)).toBe(false)
		t.expect(Trailer.canLaunch(2, 6)).toBe(false)
		t.expect(Trailer.hitchAngle(Vector3.new(0, 0, -1), Vector3.new(0, 0, -1)))
			.toBeCloseTo(0, 1e-6)
		t.expect(math.abs(Trailer.hitchAngle(Vector3.new(0, 0, -1), Vector3.new(-1, 0, 0))))
			.toBeCloseTo(90, 1e-6)
		t.expect(Trailer.pickBoat(function(id)
			return id == "JetSki"
		end)).toBe("JetSki")
	end)

	t.test("light bar: double flash alternates sides, rotator sweeps", function()
		local leftOn, rightOn, both = 0, 0, 0
		for i = 0, 599 do
			local time = i / 600
			local l = LightBar.isOn("DoubleFlash", time, 1, 4)
			local r = LightBar.isOn("DoubleFlash", time, 4, 4)
			leftOn += if l then 1 else 0
			rightOn += if r then 1 else 0
			both += if l and r then 1 else 0
		end
		t.expect(both).toBe(0)
		t.expect(leftOn > 50 and rightOn > 50).toBe(true)
		t.expect(LightBar.isOn("Steady", 0.3, 2, 4)).toBe(true)
		local b = LightBar.brightness("Rotator", 0, 1, 4)
		t.expect(b).toBeCloseTo(1, 1e-6)
	end)

	t.test("config: every driveable spec is chase-camera with an eye point", function()
		for _, id in Config.Order do
			local spec = Config.get(id)
			t.expect(spec ~= nil).toBe(true)
			t.expect(spec.cameraMode).toBe("Chase")
			t.expect(spec.driveable).toBe(true)
			t.expect(spec.engine ~= nil and spec.gearbox ~= nil).toBe(true)
		end
		t.expect(Config.get("Nope")).toBeNil()
	end)
end
