--!strict
-- Plane/Flight (docs/23 h, WP-7): arcade seaplane flight for kids. Pure (no Instances); Lune-tested in
-- tests/Plane.spec.luau. PlaneController steps it on the pilot's client and writes velocity() and
-- attitude() into the model's movers (Plane/Builder: LinearVelocity FlyVelocity, AlignOrientation
-- FlyAttitude).
--
-- On water it taxis like a slow boat. Throttle up past takeOffSpeed and pull up: it flies. In the air the
-- stick banks and the nose follows the bank; hands off levels the wings and the nose and holds height.
-- Stall-safe: airspeed never drops under glideSpeed, and slow the nose will not rise, so with the
-- throttle closed it glides down gently. Touching the water slow and level lands; too steep, too fast or
-- banked bounces (no damage) and bleeds speed, so a later touch lands.
-- Pick-up: only on the water, the same hold-steady rule as boats (Ops/Board).
local Board = require(script.Parent.Parent.Ops.Board)

local KNOT = 1.543 -- studs/s (VehicleConfig.KNOT)
local KG = 1 / 37 -- RMU per kg (VehicleConfig)

export type Spec = {
	id: string,
	displayName: string,
	cameraMode: string,
	eyePoint: Vector3, -- driver's eye, offset from the DriverSeat centre
	seats: number, -- player seats including the pilot
	survivorCapacity: number,
	hullSize: Vector3, -- collision box over the floats (studs)
	massHint: number, -- RMU
	draft: number, -- studs of float under the water at rest
	floatPoints: { Vector3 }, -- buoyancy points for a parked plane (Boat/Simulator)
	topSpeed: number, -- studs/s, full throttle in the air
	waterTopSpeed: number, -- studs/s, full throttle on the water (the take-off run)
	takeOffSpeed: number, -- studs/s: pull up at or over this to fly
	glideSpeed: number, -- studs/s: never slower in the air
	reverseSpeed: number, -- studs/s backing on the water
	accel: number, -- studs/s^2
	decel: number, -- studs/s^2 (throttle closed or reversed)
	waterTurnRate: number, -- degrees/s at full steer on the water
	turnRate: number, -- degrees/s of heading at full bank
	maxBank: number, -- degrees
	rollRate: number, -- degrees/s
	maxPitch: number, -- degrees nose up or down
	pitchRate: number, -- degrees/s
	glideSink: number, -- studs/s down at glideSpeed
	landSink: number, -- studs/s: touching down faster than this bounces
	landSpeed: number, -- studs/s: touching down faster than this bounces
	landBank: number, -- degrees: touching down banked more than this bounces
	bounceUp: number, -- studs/s upward kick of a bounce
	bounceKeep: number, -- share of the speed kept after a bounce
	ceiling: number, -- studs above the surface: the nose will not rise higher
}

export type State = {
	speed: number, -- studs/s along the nose (negative = backing on the water)
	yaw: number, -- radians, heading (0 = -Z, positive turns left)
	pitch: number, -- radians, nose up
	bank: number, -- radians, right wing down
	climb: number, -- studs/s vertical (the last step's)
	bounce: number, -- studs/s of a bounce's kick still acting
	airborne: boolean,
}

export type Input = {
	throttle: number, -- -1..1
	steer: number, -- -1..1, right positive
	pitch: number, -- -1..1, pull up positive
}

export type Event = "takeoff" | "landed" | "bounce"

local Flight = {}

Flight.WATER_CONTACT = 1.5 -- studs: float bottom this close to its rest depth = on the water
Flight.LIFT_OFF = 6 -- studs above the surface while taxiing = airborne (rolled off a ledge, spawned high)
Flight.SURFACE_SPRING = 8 -- 1/s: how hard the floats follow the water while taxiing
Flight.GRAVITY = 30 -- studs/s^2 on a bounce's kick

Flight.SPECS = {
	-- Single-engine floatplane (Cessna 208 Caravan amphibian class): 12.7 m long, 15.9 m span, about
	-- 3,000 kg loaded. 94 knots top: 1.5x the fastest boat (RiptideX, 95.7 studs/s). Handling -- tune.
	Seaplane = {
		id = "Seaplane",
		displayName = "Seaplane",
		cameraMode = "Chase",
		eyePoint = Vector3.new(0, 2.4, 0),
		seats = 4,
		survivorCapacity = 4,
		hullSize = Vector3.new(12, 3, 22),
		massHint = 3000 * KG,
		draft = 1,
		floatPoints = {
			Vector3.new(-4.5, -1.5, -8),
			Vector3.new(4.5, -1.5, -8),
			Vector3.new(-4.5, -1.5, 8),
			Vector3.new(4.5, -1.5, 8),
		},
		topSpeed = 94 * KNOT, -- 145 studs/s
		waterTopSpeed = 48 * KNOT, -- 74 studs/s
		takeOffSpeed = 40 * KNOT, -- 62 studs/s
		glideSpeed = 32 * KNOT, -- 49 studs/s
		reverseSpeed = 6,
		accel = 22,
		decel = 14,
		waterTurnRate = 40,
		turnRate = 50,
		maxBank = 40,
		rollRate = 90,
		maxPitch = 25,
		pitchRate = 45,
		glideSink = 10,
		landSink = 16,
		landSpeed = 76,
		landBank = 15,
		bounceUp = 14,
		bounceKeep = 0.75,
		ceiling = 900,
	} :: Spec,
}

-- The flight spec for a VehicleId, nil if it is not a plane.
function Flight.get(id: any): Spec?
	return if type(id) == "string" then Flight.SPECS[id] else nil
end

local function approach(value: number, target: number, rate: number, dt: number): number
	local d = target - value
	local stepSize = rate * dt
	return if math.abs(d) <= stepSize then target else value + math.sign(d) * stepSize
end

-- State for a plane at this CFrame, moving `speed` along its nose (the pilot just sat in).
function Flight.fromCFrame(cf: CFrame, speed: number): State
	local look = cf.LookVector
	return {
		speed = speed,
		yaw = math.atan2(-look.X, -look.Z),
		pitch = 0,
		bank = 0,
		climb = 0,
		bounce = 0,
		airborne = false,
	}
end

-- Height of the float bottoms over their rest depth in water at waterY (0 = floating at rest).
function Flight.altitude(rootY: number, waterY: number, spec: Spec): number
	return rootY - spec.hullSize.Y / 2 - (waterY - spec.draft)
end

function Flight.onWater(altitude: number): boolean
	return altitude <= Flight.WATER_CONTACT
end

-- Ops/Board's hold-steady rule, only while sitting on the water.
function Flight.mayBoard(
	altitude: number,
	gap: number,
	speed: number,
	tiltDeg: number,
	room: boolean
): boolean
	return Flight.onWater(altitude) and Board.ready(gap, speed, tiltDeg, room)
end

local function stepWater(s: State, input: Input, altitude: number, dt: number, spec: Spec): Event?
	local target = if input.throttle >= 0
		then input.throttle * spec.waterTopSpeed
		else input.throttle * spec.reverseSpeed
	s.speed = approach(
		s.speed,
		target,
		if math.abs(target) > math.abs(s.speed) then spec.accel else spec.decel,
		dt
	)
	-- like a boat: a little turn at a standstill (prop wash on the rudders), full turn once moving
	local turnShare = math.clamp(0.3 + math.abs(s.speed) / 20, 0, 1)
	s.yaw -= math.rad(input.steer * spec.waterTurnRate * turnShare) * dt
	s.bank = approach(s.bank, 0, math.rad(spec.rollRate), dt)
	-- the nose lifts a touch when pulled near take-off speed: "almost"
	local lifting = input.pitch > 0 and s.speed >= spec.takeOffSpeed * 0.7
	s.pitch = approach(s.pitch, if lifting then math.rad(4) else 0, math.rad(spec.pitchRate), dt)
	s.bounce = 0
	s.climb = math.clamp(-altitude * Flight.SURFACE_SPRING, -25, 25)
	if input.pitch > 0 and s.speed >= spec.takeOffSpeed then
		s.airborne = true
		s.pitch = math.max(s.pitch, math.rad(6))
		s.climb = s.speed * math.sin(s.pitch)
		return "takeoff"
	end
	if altitude > Flight.LIFT_OFF then
		s.airborne = true
		s.speed = math.max(s.speed, spec.glideSpeed)
	end
	return nil
end

local function stepAir(s: State, input: Input, altitude: number, dt: number, spec: Spec): Event?
	local throttle = math.max(input.throttle, 0)
	s.speed = approach(
		s.speed,
		spec.glideSpeed + (spec.topSpeed - spec.glideSpeed) * throttle,
		if throttle > 0 then spec.accel else spec.decel,
		dt
	)
	s.speed = math.max(s.speed, spec.glideSpeed) -- stall-safe
	-- 0 at glide speed (no climbing, a gentle sink), 1 from take-off speed (hands off holds height)
	local lift =
		math.clamp((s.speed - spec.glideSpeed) / (spec.takeOffSpeed - spec.glideSpeed), 0, 1)
	local pull = math.clamp(input.pitch, -1, 1)
	local pitchTarget = math.rad(spec.maxPitch) * (if pull > 0 then pull * lift else pull)
	if altitude >= spec.ceiling then
		pitchTarget = math.min(pitchTarget, 0)
	end
	s.pitch = approach(s.pitch, pitchTarget, math.rad(spec.pitchRate), dt)
	s.bank = approach(
		s.bank,
		math.rad(spec.maxBank) * math.clamp(input.steer, -1, 1),
		math.rad(spec.rollRate),
		dt
	)
	s.yaw -= math.rad(spec.turnRate) * (s.bank / math.rad(spec.maxBank)) * dt
	s.bounce = math.max(0, s.bounce - Flight.GRAVITY * dt)
	s.climb = s.speed * math.sin(s.pitch) - spec.glideSink * (1 - lift) + s.bounce
	if altitude > 0 or s.climb >= 0 then
		return nil
	end
	-- touchdown
	if
		-s.climb > spec.landSink
		or s.speed > spec.landSpeed
		or math.abs(s.bank) > math.rad(spec.landBank)
	then
		s.speed *= spec.bounceKeep
		s.pitch = 0
		s.bank *= 0.5
		s.bounce = spec.bounceUp
		s.climb = spec.bounceUp
		return "bounce"
	end
	s.airborne = false
	s.pitch = 0
	s.bank = 0
	s.climb = 0
	return "landed"
end

-- One step. altitude: Flight.altitude over the surface below (water, or ground over land), studs.
-- Mutates the state; returns an event on take-off, landing or a bounce.
function Flight.step(s: State, input: Input, altitude: number, dt: number, spec: Spec): Event?
	if s.airborne then
		return stepAir(s, input, altitude, dt, spec)
	end
	return stepWater(s, input, altitude, dt, spec)
end

-- World velocity for the state (studs/s).
function Flight.velocity(s: State): Vector3
	local flat = s.speed * math.cos(s.pitch)
	return Vector3.new(-math.sin(s.yaw) * flat, s.climb, -math.cos(s.yaw) * flat)
end

-- World rotation for the state (no position).
function Flight.attitude(s: State): CFrame
	return CFrame.Angles(0, s.yaw, 0) * CFrame.Angles(s.pitch, 0, 0) * CFrame.Angles(0, 0, -s.bank)
end

return Flight
