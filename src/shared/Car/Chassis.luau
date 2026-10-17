--!strict
-- Raycast car chassis, pure part (docs 10 section 3.3). Chassis.prepare turns a real-world
-- LandVehicleConfig spec into game units: wheel mounts, spring and damper rates, anti-roll bars,
-- drag. Chassis.step takes what the four (or more) wheel raycasts saw and returns each wheel's
-- forces: spring load, tyre longitudinal and lateral force. The rigid body does the rest: weight
-- transfer, roll, dive and squat come from applying those forces at the contact patches below the
-- centre of mass. Car/Physics.luau does the raycasts and applies the forces in Roblox.
--
-- Body frame (as Roblox): -Z forward, +X right, +Y up; the root part's centre is the centre of
-- mass. Wheels: FL, FR, RL, RR (a trailer: two axles, all "rear").
local Drivetrain = require(script.Parent.Drivetrain)
local LandVehicleConfig = require(script.Parent.Parent.Config.LandVehicleConfig)
local Suspension = require(script.Parent.Suspension)
local Tyre = require(script.Parent.Tyre)
local Units = require(script.Parent.Units)

type Spec = LandVehicleConfig.Spec

local Chassis = {}

export type WheelDef = {
	name: string,
	front: boolean,
	side: number, -- -1 left, 1 right
	steered: boolean,
	driven: boolean,
	mount: Vector3, -- ray origin in the body frame (studs)
	centreRest: Vector3, -- wheel centre at ride height
	travel: number, -- studs (spring free length)
	radius: number, -- studs
	rayLength: number,
	k: number, -- spring rate (force / stud)
	c: number, -- damper rate
	kBar: number, -- anti-roll bar rate on this axle
	cornerMass: number, -- RMU
	sag: number, -- studs at rest
}

export type Derived = {
	spec: Spec,
	mass: number, -- RMU
	radius: number, -- studs
	wheelbase: number,
	track: number,
	wheels: { WheelDef },
	dragK: number,
	brakeForce: number, -- whole-car brake force demand at full pedal
	handbrakeForce: number,
	topSpeed: number,
	g: number,
}

export type Controls = {
	throttle: number, -- -1..1 (seat ThrottleFloat: forward / brake / reverse)
	steer: number, -- -1..1, right positive
	handbrake: boolean,
	lowRange: boolean,
	assists: boolean, -- ABS, traction control (Pro can switch off)
	brakeOverride: number?, -- trailers: the tow car's brake pedal
	towing: boolean?,
}

export type State = {
	gear: number, -- -1 reverse, 1..n forward
	steerAngle: number, -- degrees, road wheel (centre)
	shiftTimer: number,
	rpm: number,
}

export type Contact = {
	contact: boolean,
	compression: number, -- studs
	compressionSpeed: number, -- studs/s, positive compressing
	vLong: number, -- contact patch velocity along the wheel's rolling direction (studs/s)
	vLat: number, -- across it, positive to the wheel's right
	grip: number, -- surface multiplier incl. wetness (Tyre.grip)
	rolling: number, -- rolling resistance coefficient
}

export type WheelResult = {
	fz: number,
	fx: number, -- along the rolling direction (forward +)
	fy: number, -- to the wheel's right +
	slip: number,
	slipAngle: number,
	sliding: boolean,
	steer: number, -- radians, right positive
	spinSpeed: number, -- studs/s of tread speed (for the visual wheel)
}

export type Telemetry = {
	rpm: number,
	gear: number,
	speed: number,
	drive: number,
	brake: number,
	sliding: number, -- count of sliding wheels
	grounded: number,
}

function Chassis.prepare(spec: Spec, extraMassKg: number?): Derived
	local M = Units.M
	local mass = (spec.mass + (extraMassKg or 0)) * Units.KG
	local g = Units.G
	local radius = spec.wheelRadius * M
	local travel = spec.travel * M
	local track = spec.track * M
	local wheelbase = spec.wheelbase * M
	local trailer = spec.class == "Trailer"
	local centreY = -(spec.cgHeight - spec.wheelRadius) * M
	local wheels: { WheelDef } = {}

	local function addAxle(
		z: number,
		front: boolean,
		axleMassFraction: number,
		frequency: number,
		bar: number
	)
		local cornerMass = mass * axleMassFraction / 2
		local k = Suspension.springRate(cornerMass, frequency)
		local c = Suspension.damperRate(k, cornerMass, spec.dampingRatio)
		local sag = Suspension.sag(cornerMass, k, g)
		for _, side in { -1, 1 } do
			local centre = Vector3.new(side * track / 2, centreY, z)
			local prefix = if trailer
				then (if front then "T1" else "T2")
				else (if front then "F" else "R")
			table.insert(wheels, {
				name = prefix .. (if side < 0 then "L" else "R"),
				front = front and not trailer,
				side = side,
				steered = front and not trailer,
				driven = spec.drive == "4WD"
					or (spec.drive == "RWD" and not front)
					or (spec.drive == "FWD" and front),
				mount = centre + Vector3.new(0, travel - sag, 0),
				centreRest = centre,
				travel = travel,
				radius = radius,
				rayLength = travel + radius,
				k = k,
				c = c,
				kBar = k * bar,
				cornerMass = cornerMass,
				sag = sag,
			})
		end
	end

	if trailer then
		-- The centre of mass sits a little ahead of the axles; the hitch carries the nose weight
		-- (the ball joint), the axles share the rest. Axles at +Z (behind).
		local hitchToAxles = spec.frontOverhang * M
		local noseFraction = 0.07
		local ahead = hitchToAxles * noseFraction
		local onAxles = 1 - noseFraction
		addAxle(ahead - wheelbase / 2, true, onAxles / 2, spec.frequencyFront, spec.antiRollFront)
		addAxle(ahead + wheelbase / 2, false, onAxles / 2, spec.frequencyRear, spec.antiRollRear)
		for _, w in wheels do
			w.driven = false
		end
	else
		-- the centre of mass is (1 - frontWeight) of the wheelbase behind the front axle
		local front = -wheelbase * (1 - spec.frontWeight)
		local rear = wheelbase * spec.frontWeight
		addAxle(front, true, spec.frontWeight, spec.frequencyFront, spec.antiRollFront)
		addAxle(rear, false, 1 - spec.frontWeight, spec.frequencyRear, spec.antiRollRear)
	end

	return {
		spec = spec,
		mass = mass,
		radius = radius,
		wheelbase = wheelbase,
		track = track,
		wheels = wheels,
		dragK = Units.dragK(spec.cdA),
		brakeForce = spec.brakeG * g * mass,
		handbrakeForce = spec.handbrakeG * g * mass,
		topSpeed = spec.topSpeed,
		g = g,
	}
end

function Chassis.newState(): State
	return { gear = 1, steerAngle = 0, shiftTimer = 0, rpm = 0 }
end

-- Speed-sensitive steering lock (degrees) at a forward speed (studs/s).
function Chassis.steerLock(spec: Spec, speed: number): number
	local x = math.abs(speed) / math.max(spec.steerFadeSpeed, 1e-3)
	return spec.steerLockHigh + (spec.steerLock - spec.steerLockHigh) / (1 + x * x)
end

-- Ackermann: inner and outer road wheel angles (radians, same sign) for a centre angle.
function Chassis.ackermann(angle: number, wheelbase: number, track: number): (number, number)
	if math.abs(angle) < 1e-4 then
		return angle, angle
	end
	local r = wheelbase / math.tan(math.abs(angle)) -- turn radius at the axle centre
	local inner = math.atan(wheelbase / math.max(r - track / 2, 1e-3))
	local outer = math.atan(wheelbase / (r + track / 2))
	local sign = if angle > 0 then 1 else -1
	return sign * inner, sign * outer
end

-- Moves the steering toward the input, faster back to centre (self-aligning torque).
function Chassis.updateSteer(d: Derived, state: State, steer: number, speed: number, dt: number)
	local spec = d.spec
	local target = math.clamp(steer, -1, 1) * Chassis.steerLock(spec, speed)
	local rate = spec.steerRate * (if math.abs(target) < math.abs(state.steerAngle) then 1.5 else 1)
	local delta = math.clamp(target - state.steerAngle, -rate * dt, rate * dt)
	state.steerAngle += delta
end

-- Road wheel angle (radians, right positive) of a wheel for the current steering.
function Chassis.wheelSteer(d: Derived, state: State, w: WheelDef): number
	if not w.steered then
		return 0
	end
	local angle = math.rad(state.steerAngle)
	local inner, outer = Chassis.ackermann(angle, d.wheelbase, d.track)
	-- turning right (angle > 0): the right wheel is the inner one
	local isInner = (angle > 0) == (w.side > 0)
	return if isInner then inner else outer
end

local function staticFriction(v: number, mass: number, limit: number, dt: number): number
	-- the force that would stop v this frame, capped at limit (a brake or rolling drag that
	-- holds a stopped car instead of pushing it backwards)
	return -math.clamp(v * mass / dt, -limit, limit)
end

-- One chassis step. speed: the body's forward speed (studs/s). Returns per-wheel forces in each
-- wheel's frame and telemetry; updates state (gear, steering, rpm).
function Chassis.step(
	d: Derived,
	state: State,
	controls: Controls,
	contacts: { Contact },
	speed: number,
	dt: number
): ({ WheelResult }, Telemetry)
	local spec = d.spec
	local engine, gearbox = spec.engine, spec.gearbox
	Chassis.updateSteer(d, state, controls.steer, speed, dt)

	-- pedals: an automatic that brakes before it changes direction
	local thr = math.clamp(controls.throttle, -1, 1)
	local drive, brake = 0, 0
	if engine and gearbox then
		if thr > 0.05 then
			if state.gear == -1 and speed < -0.8 then
				brake = thr
			else
				state.gear = math.max(state.gear, 1)
				drive = thr
			end
		elseif thr < -0.05 then
			if state.gear >= 1 and speed > 0.8 then
				brake = -thr
			else
				state.gear = -1
				drive = -thr
			end
		elseif math.abs(speed) < 0.6 then
			brake = 0.35 -- auto hold at a standstill
		end
	end
	if controls.brakeOverride then
		brake = math.max(brake, controls.brakeOverride)
	end

	-- engine and gearbox
	local driveForce = 0 -- whole-car tractive force along +forward
	local nDriven = 0
	local omegaSum = 0
	for i, w in d.wheels do
		if w.driven then
			nDriven += 1
			local cn = contacts[i]
			omegaSum += if cn and cn.contact then cn.vLong else speed
		end
	end
	local rpm = 0
	if engine and gearbox and nDriven > 0 then
		local wheelOmega = (omegaSum / nDriven) / d.radius
		-- governor (docs 02 top speeds) and reverse limiter: they lift the throttle, so the
		-- automatic sees a light foot at the limit and changes up
		local limit = if state.gear == -1
			then spec.reverseSpeed
			elseif controls.towing and spec.topSpeedTowing then spec.topSpeedTowing
			else d.topSpeed
		local over = math.abs(speed) - limit
		local pedal = drive * math.clamp(-over / (limit * 0.04), 0, 1)
		state.shiftTimer = math.max(0, state.shiftTimer - dt)
		if state.gear >= 1 and state.shiftTimer <= 0 then
			local nextGear =
				Drivetrain.autoShift(gearbox, state.gear, wheelOmega, pedal, controls.lowRange)
			if nextGear ~= state.gear then
				state.gear = nextGear
				state.shiftTimer = gearbox.shiftTime
			end
		end
		local ratio = Drivetrain.ratio(gearbox, state.gear, controls.lowRange)
		local mult
		rpm, mult = Drivetrain.engineState(engine, wheelOmega, ratio, drive)
		local crank = Drivetrain.crankTorque(engine, rpm, pedal)
		if pedal <= 0.02 and drive > 0.02 then
			crank = 0 -- at the governor: neither drive nor engine braking
		end
		-- rotating parts (engine, gearbox, wheels) soak up torque in the low gears: the classic
		-- effective-mass factor 1.04 + 0.0025 i^2
		local inertia = 1.04 + 0.0025 * ratio * ratio
		if crank > 0 then
			if state.shiftTimer > 0 then
				crank *= 0.45
			end
			local dir = if state.gear == -1 then -1 else 1
			driveForce = dir
				* crank
				* Units.NM
				* ratio
				* gearbox.efficiency
				* mult
				/ d.radius
				/ inertia
		elseif crank < 0 then
			-- engine braking opposes the motion
			local f = -crank * Units.NM * ratio * gearbox.efficiency / d.radius
			driveForce = -math.sign(speed) * math.min(f, math.abs(speed) * d.mass / dt)
		end
	end
	state.rpm = rpm

	local results: { WheelResult } = {}
	local sliding, grounded = 0, 0
	-- anti-roll bars act on the left / right pair of each axle (wheels are added in pairs)
	local barForce: { number } = {}
	for i = 1, #d.wheels, 2 do
		local l, r = contacts[i], contacts[i + 1]
		local cl = if l and l.contact then l.compression else 0
		local cr = if r and r.contact then r.compression else 0
		local fl, fr = Suspension.antiRoll(cl, cr, d.wheels[i].kBar)
		barForce[i], barForce[i + 1] = fl, fr
	end

	local frontBrake = d.brakeForce * spec.brakeFrontBias / 2
	local rearBrake = d.brakeForce * (1 - spec.brakeFrontBias) / 2
	for i, w in d.wheels do
		local cn = contacts[i]
		local steerAngle = Chassis.wheelSteer(d, state, w)
		if not (cn and cn.contact) then
			local spin = if w.driven and nDriven > 0
				then driveForce / math.max(d.mass, 1) * 0.5
				else 0
			results[i] = {
				fz = 0,
				fx = 0,
				fy = 0,
				slip = 0,
				slipAngle = 0,
				sliding = false,
				steer = steerAngle,
				spinSpeed = speed + spin,
			}
			continue
		end
		grounded += 1
		local fz = math.max(
			0,
			Suspension.force(cn.compression, cn.compressionSpeed, w.k, w.c, w.travel)
				+ (barForce[i] or 0)
		)
		local m = fz / d.g -- the mass this wheel is holding up right now
		local mu = spec.tyreMu * cn.grip
		local peak = mu * fz
		local locked = controls.handbrake and not w.front
		-- demanded longitudinal force at the contact patch
		local demand = 0
		if w.driven and nDriven > 0 then
			demand += driveForce / nDriven
		end
		local brakeLimit = brake * (if w.front then frontBrake else rearBrake)
		if locked then
			brakeLimit += d.handbrakeForce / 2
		end
		if brakeLimit > 0 then
			demand += staticFriction(cn.vLong, m, brakeLimit, dt)
		end
		demand += staticFriction(cn.vLong, m, cn.rolling * fz, dt)
		local assist = controls.assists and not locked
		local fx, slip, slides = Tyre.longitudinal(demand, peak, spec.longB, spec.longC, assist)
		if locked and math.abs(cn.vLong) > 1 and brakeLimit > peak * 0.5 then
			slides = true -- a pulled handbrake locks the rear wheels
			fx = -math.sign(cn.vLong) * peak * Tyre.curve(1, spec.longB, spec.longC)
			slip = -math.sign(cn.vLong)
		end
		-- a spinning or locked tyre has little side grip left
		local latPeak = peak * (if slides then 0.55 else 1)
		local fy, alpha = Tyre.lateral(cn.vLat, cn.vLong, latPeak, spec.latB, spec.latC)
		fy = math.clamp(fy, -m * math.abs(cn.vLat) / dt, m * math.abs(cn.vLat) / dt)
		if assist then
			-- ABS / TC keep steering: longitudinal force yields to cornering force
			local room = math.sqrt(math.max(0.05, 1 - (fy / math.max(latPeak, 1e-6)) ^ 2))
			fx = math.clamp(fx, -peak * room, peak * room)
		else
			fx, fy = Tyre.combine(fx, fy, peak, latPeak)
		end
		if slides then
			sliding += 1
		end
		results[i] = {
			fz = fz,
			fx = fx,
			fy = fy,
			slip = slip,
			slipAngle = alpha,
			sliding = slides,
			steer = steerAngle,
			spinSpeed = if locked and slides
				then 0
				else cn.vLong + slip * math.max(math.abs(cn.vLong), 12),
		}
	end

	return results,
		{
			rpm = rpm,
			gear = state.gear,
			speed = speed,
			drive = drive,
			brake = brake,
			sliding = sliding,
			grounded = grounded,
		}
end

-- Aerodynamic drag force magnitude at a speed (studs/s).
function Chassis.drag(d: Derived, speed: number): number
	return d.dragK * speed * speed
end

return Chassis
