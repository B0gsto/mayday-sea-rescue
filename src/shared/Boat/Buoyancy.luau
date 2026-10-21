--!strict
-- Buoyancy: pure boat physics math (docs 06 section 3.2). No Instances: every function takes
-- numbers / Vector3s and returns forces, so tests/Boat.spec.luau runs it under Lune.
-- Boat/Simulator.luau applies the results to VectorForce / Torque constraints each frame.
--
-- Units are Roblox units at our scale (docs 05 section 4.1, 1 m = 3 studs): studs, seconds,
-- mass in RMU (1 RMU = 1 stud^3 of water = 37 kg), force = mass * studs/s^2. Gravity is
-- Workspace.Gravity = 29.43 studs/s^2 (9.81 m/s^2 x 3, docs 02 section 4.2).
--
-- Float points (VehicleConfig.floatPoints, at the hull bottom):
--   depth = waterY - point.Y
--   lift  = clamp((depth + offset) / (draft * DEPTH_RANGE), 0, 1) * weightPerPoint * DEPTH_RANGE
-- so with offset 0 the lift equals the boat's weight exactly when every point sits `draft` below
-- the water (the rest pose). The lift is a spring with stiffness weightPerPoint / draft, natural
-- heave frequency sqrt(g / draft) (about 1.4 s period on the RIB, close to a real 8 m boat).
-- The damping is the hull's dampingRatio of critical, scaled by how wet the point is; hulls slamming
-- down into the water get SLAM_GAIN x more (the hard landing), rising hulls get less (the bounce).
--
-- Hydrodynamic effects ride on `offset` (wetted points only, so they vanish when a point leaves the
-- water and can never hold a hull up in the air or flip it):
--   planing lift   every wet point lifts as if planingLift * draft deeper: the hull rises on plane
--   trim           -z * tan(trim): bow points lift more, stern points less (bow rise, squat)
--   lean           -x * tan(lean): the inside of a turn lifts less, so the hull banks into it
--
-- Hull frame: -Z is forward, +Y up, +X right (starboard). "forward" vectors passed in are unit and
-- horizontal. Positive trim = bow up, positive lean = starboard side down.

local Waves = require(script.Parent.Parent.Waves)

export type Handling = {
	topSpeed: number, -- studs/s
	accel: number, -- studs/s^2 of thrust at full throttle, from rest
	brakeDecel: number, -- studs/s^2 of reverse thrust while still moving ahead
	turnRate: number, -- degrees/s cap on the yaw rate
	lateralGrip: number, -- 0..1
	turnRadiusSlow: number, -- studs, tightest turn radius at low speed
	maxLateralG: number, -- g, the turn radius grows as v^2 / (maxLateralG * g) at speed
	pivotSpeed: number, -- studs/s of "virtual speed" the jet / prop gives steering at standstill
	offThrottleSteer: number, -- 0..1 steering left with the throttle closed (jets have little)
	humpSpeed: number, -- fraction of topSpeed where the bow rises most (resistance hump)
	planingSpeed: number, -- fraction of topSpeed where the hull is fully on the plane
	humpTrim: number, -- degrees bow up at the hump
	runningTrim: number, -- degrees bow up when planing
	squatTrim: number, -- degrees of extra stern squat at full throttle below the plane
	planingLift: number, -- 0..1 of the weight carried by dynamic lift on the plane
	leanFactor: number, -- 0..1 of the coordinated bank angle atan(a_lat / g) the hull takes
	maxLean: number, -- degrees
	dampingRatio: number, -- heave damping, fraction of critical (low = bouncy)
	idleCreep: number, -- studs/s an idling engine pushes the hull (jet skis creep; 0 = neutral gear)
	approachSpeed: number, -- studs/s cap in approach mode (under 5 knots)
}

local Buoyancy = {}

Buoyancy.KNOT = 1.543 -- studs/s (0.514 m/s x 3)
Buoyancy.STUDS_PER_METRE = 3
Buoyancy.GRAVITY = 29.43 -- studs/s^2, the Workspace.Gravity we design for

Buoyancy.DEPTH_RANGE = 2 -- lift saturates at this many drafts deep -- tune
Buoyancy.SLAM_GAIN = 2.2 -- x damping for a hull dropping into the water -- tune
Buoyancy.RISE_DAMPING = 0.6 -- x damping for a hull rising out of it (bounce) -- tune
Buoyancy.SLAM_SPEED = 6 -- studs/s downward entry speed where a landing counts as a slam -- tune
Buoyancy.FORWARD_LINEAR_DRAG = 0.08 -- 1/s, low-speed skin friction -- tune
Buoyancy.HUMP_DRAG = 0.3 -- of accel, extra wave-making resistance at the hump -- tune
Buoyancy.LATERAL_DRAG_RATE = 6 -- 1/s at lateralGrip 1 (keel effect) -- tune
Buoyancy.AIR_DRAG_FRACTION = 0.05 -- drag left when the hull is out of the water -- tune
Buoyancy.REVERSE_ACCEL_FRACTION = 0.4 -- of accel -- tune
Buoyancy.REVERSE_SPEED_FRACTION = 0.2 -- of topSpeed -- tune
Buoyancy.TURN_GAIN = 4 -- 1/s, how fast the yaw rate reaches the steering target -- tune
Buoyancy.UPRIGHT_FREQUENCY = 1.2 -- rad/s, gentle self-righting on top of buoyancy -- tune
Buoyancy.UPRIGHT_DAMPING = 0.5 -- 1/s, pitch/roll angular drag in the air -- tune
Buoyancy.WATER_PITCH_DAMPING = 4 -- 1/s more with the hull in the water (planing surfaces) -- tune
Buoyancy.GRIP_CONTACT = 0.3 -- mean wetness at which jet, prop, keel and drag have full effect -- tune
Buoyancy.HEAD_SEA_DRAG = 0.08 -- 1/s of drag per rad/s of pitch + heave motion (added resistance) -- tune
Buoyancy.SLAM_DRAG = 0.015 -- 1/s of drag per stud/s of slam (slams bleed speed) -- tune
Buoyancy.WAKE_LAG = 1.2 -- s, how far behind the hull its stern wave runs -- tune
Buoyancy.WAKE_TRIM = 4 -- degrees bow down when the stern wave catches up -- tune
Buoyancy.WAKE_PUSH = 0.25 -- of accel, the following stern wave's push -- tune
Buoyancy.APPROACH_GAIN = 1.5 -- 1/s speed governor gain in approach mode -- tune
Buoyancy.APPROACH_ACCEL = 0.35 -- of accel / brakeDecel the governor may use -- tune
Buoyancy.STATION_KEEP_SPEED = 1.5 -- studs/s: an idling hull below this holds station -- tune
Buoyancy.STATION_KEEP_GAIN = 3 -- 1/s damping toward rest while holding station -- tune
Buoyancy.IDLE_GAIN = 0.6 -- 1/s -- tune

local function smoothstep(a: number, b: number, x: number): number
	local u = math.clamp((x - a) / (b - a), 0, 1)
	return u * u * (3 - 2 * u)
end

-- Water surface height at a world XZ (params from Weather.getWaveParams for that spot).
function Buoyancy.waterHeight(x: number, z: number, t: number, params: Waves.WaveParams): number
	return Waves.heightAt(x, z, t, params)
end

-- Root part centre Y for a hull floating at rest on water at waterY, given the float points' local Y.
function Buoyancy.restRootY(waterY: number, draft: number, floatPointY: number): number
	return waterY - draft - floatPointY
end

-- 0..1: how wet one float point is (1 once it is a full draft under).
function Buoyancy.wetness(depth: number, draft: number): number
	return math.clamp(depth / draft, 0, 1)
end

-- Upward lift for one float point (no damping). weightPerPoint = mass * gravity / pointCount.
-- offset (studs, hydrodynamic: planing, trim, lean) only applies while the point is wet.
function Buoyancy.pointLift(
	depth: number,
	draft: number,
	weightPerPoint: number,
	offset: number?
): number
	local range = Buoyancy.DEPTH_RANGE
	local d = if depth > 0 then depth + (offset or 0) else depth
	return math.clamp(d / (draft * range), 0, 1) * weightPerPoint * range
end

-- Vertical damping force for one float point, against its vertical velocity. Asymmetric: a hull
-- slamming down meets SLAM_GAIN x the damping, a rising hull RISE_DAMPING x (so it bounces).
function Buoyancy.pointDamping(
	depth: number,
	verticalVelocity: number,
	draft: number,
	weightPerPoint: number,
	massPerPoint: number,
	dampingRatio: number?
): number
	local wet = Buoyancy.wetness(depth, draft)
	if wet <= 0 then
		return 0
	end
	local stiffness = weightPerPoint / draft
	local c = 2 * (dampingRatio or 0.5) * math.sqrt(stiffness * massPerPoint)
	c *= if verticalVelocity < 0 then Buoyancy.SLAM_GAIN else Buoyancy.RISE_DAMPING
	local maxForce = weightPerPoint * Buoyancy.DEPTH_RANGE
	return math.clamp(-c * verticalVelocity * wet, -maxForce, maxForce)
end

-- Slam strength (studs/s over SLAM_SPEED) of a point hitting the water: entering (less than one
-- draft under) and dropping faster than SLAM_SPEED. 0 otherwise.
function Buoyancy.slam(depth: number, verticalVelocity: number, draft: number): number
	if depth <= 0 or depth > draft then
		return 0
	end
	return math.max(-verticalVelocity - Buoyancy.SLAM_SPEED, 0)
end

-- Total vertical force for one float point, plus its wetness (0..1) and slam strength.
function Buoyancy.pointForce(
	depth: number,
	verticalVelocity: number,
	draft: number,
	mass: number,
	gravity: number,
	pointCount: number,
	offset: number?,
	dampingRatio: number?
): (number, number, number)
	local massPerPoint = mass / pointCount
	local weightPerPoint = massPerPoint * gravity
	local lift = Buoyancy.pointLift(depth, draft, weightPerPoint, offset)
	local damping = Buoyancy.pointDamping(
		depth,
		verticalVelocity,
		draft,
		weightPerPoint,
		massPerPoint,
		dampingRatio
	)
	return lift + damping,
		Buoyancy.wetness(depth, draft),
		Buoyancy.slam(depth, verticalVelocity, draft)
end

-- Horizontal right vector for a horizontal forward vector (forward -Z gives right +X).
function Buoyancy.rightOf(forward: Vector3): Vector3
	return Vector3.new(-forward.Z, 0, forward.X)
end

-- 0..1: how far onto the plane the hull is at this forward speed.
function Buoyancy.planingFraction(speed: number, h: Handling, speedMult: number?): number
	local top = h.topSpeed * (speedMult or 1)
	return smoothstep(h.humpSpeed * top, h.planingSpeed * top, math.abs(speed))
end

-- 0..1 bump that peaks at the hump speed and is gone once on the plane.
function Buoyancy.humpFraction(speed: number, h: Handling, speedMult: number?): number
	local top = h.topSpeed * (speedMult or 1)
	local v = math.abs(speed)
	local hump = h.humpSpeed * top
	if v <= hump then
		local u = v / hump
		return u * u
	end
	return 1 - smoothstep(hump, h.planingSpeed * top, v)
end

-- Dynamic trim target (radians, bow up): the bow climbs its own bow wave at the hump, then levels
-- to the running trim on the plane; throttle squats the stern below the plane; the stern wave
-- catching up after a throttle chop (catchUp 0..1) pushes the bow down.
function Buoyancy.trimTarget(
	speed: number,
	throttle: number,
	h: Handling,
	speedMult: number?,
	catchUp: number?
): number
	local plane = Buoyancy.planingFraction(speed, h, speedMult)
	local hump = Buoyancy.humpFraction(speed, h, speedMult)
	local squat = h.squatTrim * math.max(throttle, 0) * (1 - plane)
	if speed < 0 then
		return 0
	end
	local deg = h.humpTrim * hump
		+ h.runningTrim * plane
		+ squat
		- Buoyancy.WAKE_TRIM * (catchUp or 0)
	return math.rad(deg)
end

-- Bank angle target (radians, positive = starboard down) for a turn: a hull leans into the turn
-- by leanFactor of the coordinated bank atan(v * yawRate / g). yawRate is about world +Y, so a
-- right turn is a negative yaw rate and leans starboard down.
function Buoyancy.leanTarget(speed: number, yawRate: number, h: Handling, gravity: number?): number
	local g = gravity or Buoyancy.GRAVITY
	local bank = math.atan(math.abs(speed) * -yawRate / g) * h.leanFactor
	local cap = math.rad(h.maxLean)
	return math.clamp(bank, -cap, cap)
end

-- Hydrodynamic lift offset (studs) for one float point at local (x, z): planing lift plus the
-- trim and lean targets, see the header.
function Buoyancy.liftOffset(
	pointLocal: Vector3,
	draft: number,
	planeLift: number,
	trim: number,
	lean: number
): number
	return planeLift * draft - pointLocal.Z * math.tan(trim) - pointLocal.X * math.tan(lean)
end

-- Quadratic forward drag coefficient (per unit mass) so thrust balances drag at top speed.
function Buoyancy.forwardQuadDrag(handling: Handling, speedMult: number): number
	local top = handling.topSpeed * speedMult
	local accel = handling.accel * speedMult
	return math.max(accel - Buoyancy.FORWARD_LINEAR_DRAG * top, 0) / (top * top)
end

-- Calm-water forward resistance per unit mass (studs/s^2, signed like v) at forward speed v.
function Buoyancy.forwardDecel(
	v: number,
	handling: Handling,
	speedMult: number,
	addedRate: number?
): number
	local quad = Buoyancy.forwardQuadDrag(handling, speedMult)
	local hump = Buoyancy.HUMP_DRAG
		* handling.accel
		* speedMult
		* Buoyancy.humpFraction(v, handling, speedMult)
		* math.sign(v)
	return (Buoyancy.FORWARD_LINEAR_DRAG + (addedRate or 0)) * v + quad * v * math.abs(v) + hump
end

-- Water drag on the hull (world-space horizontal force). Sideways drag is much stronger than
-- forward drag (keel / grip). contact is the average float point wetness (0..1).
-- Forward drag = skin friction + quadratic resistance (balancing thrust at top speed) + the hump
-- (wave-making resistance before the plane) + addedRate (1/s: head seas and slamming).
function Buoyancy.drag(
	velocity: Vector3,
	forward: Vector3,
	mass: number,
	handling: Handling,
	contact: number,
	speedMult: number,
	addedRate: number?
): Vector3
	local right = Buoyancy.rightOf(forward)
	local vF = velocity:Dot(forward)
	local vR = velocity:Dot(right)
	local forwardDecel = Buoyancy.forwardDecel(vF, handling, speedMult, addedRate)
	local lateralDecel = Buoyancy.LATERAL_DRAG_RATE * handling.lateralGrip * vR
	local scale = mass * math.max(contact, Buoyancy.AIR_DRAG_FRACTION)
	return -(forward * forwardDecel + right * lateralDecel) * scale
end

-- Thrust along the hull's forward axis (a signed number; multiply by forward). throttle -1..1.
-- Reverse throttle brakes while moving forward, then reverses slowly. No thrust out of the water.
-- approach: a speed governor holds throttle * approachSpeed with gentle force (fine throttle);
-- throttle 0 is neutral and the hull glides. engineRunning false (kill cord pulled): no thrust.
-- With the engine running and the throttle closed, an idling jet holds station at rest (a low
-- speed damper instead of creep) and only pushes at idleCreep when already moving faster.
function Buoyancy.thrust(
	throttle: number,
	forwardSpeed: number,
	mass: number,
	handling: Handling,
	contact: number,
	speedMult: number,
	approach: boolean?,
	engineRunning: boolean?
): number
	if engineRunning == false then
		return 0
	end
	throttle = math.clamp(throttle, -1, 1)
	local force = 0
	if approach then
		if math.abs(throttle) > 0.02 then
			local target = throttle * handling.approachSpeed
			if throttle < 0 then
				target *= 0.5
			end
			local a = Buoyancy.APPROACH_ACCEL
			-- feed-forward the calm-water resistance at the target speed, plus a P term
			force = mass
				* math.clamp(
					Buoyancy.forwardDecel(target, handling, 1)
						+ (target - forwardSpeed) * Buoyancy.APPROACH_GAIN,
					-handling.brakeDecel * a,
					handling.accel * a
				)
		end
	elseif throttle > 0 then
		force = mass * handling.accel * speedMult * throttle
	elseif throttle < 0 then
		if forwardSpeed > 0.5 then
			force = mass * handling.brakeDecel * throttle
		elseif forwardSpeed > -handling.topSpeed * Buoyancy.REVERSE_SPEED_FRACTION then
			force = mass * handling.accel * Buoyancy.REVERSE_ACCEL_FRACTION * throttle
		end
	end
	if not approach and math.abs(throttle) < 0.02 then
		if math.abs(forwardSpeed) < Buoyancy.STATION_KEEP_SPEED then
			-- station keeping: hold the hull still instead of creeping into the breakwater
			force = -mass * Buoyancy.STATION_KEEP_GAIN * forwardSpeed
		elseif handling.idleCreep > 0 then
			force = mass
				* math.clamp(
					Buoyancy.forwardDecel(handling.idleCreep, handling, 1)
						+ (handling.idleCreep - forwardSpeed) * Buoyancy.IDLE_GAIN,
					0,
					handling.accel * 0.1
				)
		end
	end
	return force * math.clamp(contact, 0, 1)
end

-- Highest yaw rate (rad/s) the hull can hold at this speed and throttle: v / radius, where the
-- radius is turnRadiusSlow at low speed and grows as v^2 / (maxLateralG * g) at speed (a real
-- turning circle), capped by turnRate. At a standstill the jet or prop gives pivotSpeed of
-- "virtual speed" in proportion to the throttle.
function Buoyancy.maxYawRate(speed: number, throttle: number, h: Handling, gravity: number?): number
	local g = gravity or Buoyancy.GRAVITY
	local v = math.abs(speed)
	local vEff = math.max(v, h.pivotSpeed * math.abs(throttle))
	local radius = math.max(h.turnRadiusSlow, v * v / (h.maxLateralG * g))
	return math.min(math.rad(h.turnRate), vEff / radius)
end

-- Yaw torque about world +Y. steer -1 (left) .. 1 (right); right is a negative yaw rate.
-- It drives the yaw rate toward a steering target, so with steer 0 it acts as yaw drag.
-- Steering needs water flow: jets lose most of it with the throttle closed (offThrottleSteer),
-- it flips in reverse, and vanishes out of the water.
function Buoyancy.steerTorque(
	steer: number,
	forwardSpeed: number,
	yawRate: number,
	inertiaYaw: number,
	handling: Handling,
	contact: number,
	_speedMult: number, -- unused: the turning circle follows the real speed
	throttle: number?,
	gravity: number?
): number
	steer = math.clamp(steer, -1, 1)
	local th = math.clamp(math.abs(throttle or 1), 0, 1)
	local authority = handling.offThrottleSteer + (1 - handling.offThrottleSteer) * th
	local direction = if forwardSpeed < -1 then -1 else 1
	local target = -steer
		* Buoyancy.maxYawRate(forwardSpeed, th, handling, gravity)
		* authority
		* direction
	return inertiaYaw * Buoyancy.TURN_GAIN * (target - yawRate) * math.clamp(contact, 0, 1)
end

-- Gentle self-righting toward targetUp (level by default) plus pitch/roll angular drag
-- (world-space torque). inertia is a representative pitch/roll moment of inertia. Buoyancy does
-- most of the righting; this stops slow capsizes and settles the trim.
function Buoyancy.uprightTorque(
	up: Vector3,
	angularVelocity: Vector3,
	inertia: number,
	targetUp: Vector3?,
	grip: number?
): Vector3
	local w = Buoyancy.UPRIGHT_FREQUENCY
	local restoring = up:Cross(targetUp or Vector3.yAxis) * (w * w)
	local tiltRate = Vector3.new(angularVelocity.X, 0, angularVelocity.Z)
	local damping = Buoyancy.UPRIGHT_DAMPING + Buoyancy.WATER_PITCH_DAMPING * (grip or 0)
	return (restoring - tiltRate * damping) * inertia
end

-- Added resistance (1/s) from the hull's own pitching and slamming in a seaway: head seas make a
-- hull pitch hard and slam, both of which bleed speed.
function Buoyancy.addedResistance(pitchRate: number, slam: number): number
	return Buoyancy.HEAD_SEA_DRAG * math.abs(pitchRate) + Buoyancy.SLAM_DRAG * slam
end

-- The stern wave runs WAKE_LAG behind the hull's speed. When the hull slows faster than that (a
-- throttle chop off the plane) the wave catches up: returns catchUp 0..1 (for trimTarget) and the
-- forward push it gives (studs/s^2).
function Buoyancy.wakeCatchUp(wakeSpeed: number, speed: number, h: Handling): (number, number)
	local excess = wakeSpeed - speed
	if excess <= 0 or speed <= 0 then
		return 0, 0
	end
	local u = math.clamp(excess / (h.topSpeed * 0.3), 0, 1)
	u *= 1 - Buoyancy.planingFraction(speed, h) -- only off the plane
	return u, u * Buoyancy.WAKE_PUSH * h.accel
end

-- 0..1 effect of the water on jet, prop, keel and drag from the mean float point wetness. A
-- planing hull rides high (low wetness) but its jet and running surface are fully in the water.
function Buoyancy.grip(contact: number): number
	return math.clamp(contact / Buoyancy.GRIP_CONTACT, 0, 1)
end

-- Solid box moments of inertia (about local X, Y, Z) for a hull of this size and mass.
function Buoyancy.boxInertia(mass: number, size: Vector3): (number, number, number)
	local x2, y2, z2 = size.X * size.X, size.Y * size.Y, size.Z * size.Z
	return mass * (y2 + z2) / 12, mass * (x2 + z2) / 12, mass * (x2 + y2) / 12
end

-- Flattened unit forward (-Z) of a hull CFrame's look vector; nil-safe for a vertical hull.
function Buoyancy.flatForward(look: Vector3): Vector3
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		return Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

return Buoyancy
