--!strict
-- Buoyancy: pure boat physics math (docs 06 section 3.2). No Instances: every function takes
-- numbers / Vector3s and returns forces, so tests/Boat.spec.luau runs it under Lune.
-- Boat/Simulator.luau applies the results to VectorForce / Torque constraints each frame.
--
-- Units are Roblox units: mass (RMU), studs, seconds, force = mass * studs/s^2 (gravity 196.2).
--
-- Float points (VehicleConfig.floatPoints, at the hull bottom):
--   depth = waterY - point.Y
--   lift  = clamp(depth / (draft * DEPTH_RANGE), 0, 1) * weightPerPoint * DEPTH_RANGE
-- so the lift equals the boat's weight exactly when every point sits `draft` below the water
-- (the rest pose), and is clamped at DEPTH_RANGE x the weight when fully dunked. The lift is a
-- spring with stiffness weightPerPoint / draft; the damping is DAMPING_RATIO of critical for that
-- spring, scaled by how wet the point is, and never larger than the max lift.
--
-- Hull frame: -Z is forward, +Y up. "forward" vectors passed in are unit and horizontal.

local Waves = require(script.Parent.Parent.Waves)

export type Handling = {
	topSpeed: number,
	accel: number,
	brakeDecel: number,
	turnRate: number, -- degrees/s
	lateralGrip: number, -- 0..1
}

local Buoyancy = {}

Buoyancy.DEPTH_RANGE = 2 -- lift saturates at this many drafts deep -- tune
Buoyancy.DAMPING_RATIO = 0.6 -- of critical, per float point -- tune
Buoyancy.FORWARD_LINEAR_DRAG = 0.2 -- 1/s, coasting slowdown -- tune
Buoyancy.LATERAL_DRAG_RATE = 6 -- 1/s at lateralGrip 1 (keel effect) -- tune
Buoyancy.AIR_DRAG_FRACTION = 0.1 -- drag left when the hull is out of the water -- tune
Buoyancy.REVERSE_ACCEL_FRACTION = 0.4 -- of accel -- tune
Buoyancy.REVERSE_SPEED_FRACTION = 0.3 -- of topSpeed -- tune
Buoyancy.TURN_GAIN = 5 -- 1/s, how fast the yaw rate reaches the steering target -- tune
Buoyancy.MIN_STEER_AUTHORITY = 0.35 -- steering at standstill -- tune
Buoyancy.FULL_STEER_SPEED_FRACTION = 0.25 -- of topSpeed for full steering -- tune
Buoyancy.UPRIGHT_FREQUENCY = 2 -- rad/s, gentle self-righting on top of buoyancy -- tune
Buoyancy.UPRIGHT_DAMPING = 1.5 -- 1/s, pitch/roll angular drag -- tune

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
function Buoyancy.pointLift(depth: number, draft: number, weightPerPoint: number): number
	local range = Buoyancy.DEPTH_RANGE
	return math.clamp(depth / (draft * range), 0, 1) * weightPerPoint * range
end

-- Vertical damping force for one float point, against its vertical velocity.
function Buoyancy.pointDamping(
	depth: number,
	verticalVelocity: number,
	draft: number,
	weightPerPoint: number,
	massPerPoint: number
): number
	local wet = Buoyancy.wetness(depth, draft)
	if wet <= 0 then
		return 0
	end
	local stiffness = weightPerPoint / draft
	local c = 2 * Buoyancy.DAMPING_RATIO * math.sqrt(stiffness * massPerPoint)
	local maxForce = weightPerPoint * Buoyancy.DEPTH_RANGE
	return math.clamp(-c * verticalVelocity * wet, -maxForce, maxForce)
end

-- Total vertical force for one float point, plus its wetness (0..1).
function Buoyancy.pointForce(
	depth: number,
	verticalVelocity: number,
	draft: number,
	mass: number,
	gravity: number,
	pointCount: number
): (number, number)
	local massPerPoint = mass / pointCount
	local weightPerPoint = massPerPoint * gravity
	local lift = Buoyancy.pointLift(depth, draft, weightPerPoint)
	local damping =
		Buoyancy.pointDamping(depth, verticalVelocity, draft, weightPerPoint, massPerPoint)
	return lift + damping, Buoyancy.wetness(depth, draft)
end

-- Horizontal right vector for a horizontal forward vector (forward -Z gives right +X).
function Buoyancy.rightOf(forward: Vector3): Vector3
	return Vector3.new(-forward.Z, 0, forward.X)
end

-- Quadratic forward drag coefficient (per unit mass) so thrust balances drag at top speed.
function Buoyancy.forwardQuadDrag(handling: Handling, speedMult: number): number
	local top = handling.topSpeed * speedMult
	local accel = handling.accel * speedMult
	return math.max(accel - Buoyancy.FORWARD_LINEAR_DRAG * top, 0) / (top * top)
end

-- Water drag on the hull (world-space horizontal force). Sideways drag is much stronger than
-- forward drag (keel / grip). contact is the average float point wetness (0..1).
function Buoyancy.drag(
	velocity: Vector3,
	forward: Vector3,
	mass: number,
	handling: Handling,
	contact: number,
	speedMult: number
): Vector3
	local right = Buoyancy.rightOf(forward)
	local vF = velocity:Dot(forward)
	local vR = velocity:Dot(right)
	local quad = Buoyancy.forwardQuadDrag(handling, speedMult)
	local forwardDecel = Buoyancy.FORWARD_LINEAR_DRAG * vF + quad * vF * math.abs(vF)
	local lateralDecel = Buoyancy.LATERAL_DRAG_RATE * handling.lateralGrip * vR
	local scale = mass * math.max(contact, Buoyancy.AIR_DRAG_FRACTION)
	return -(forward * forwardDecel + right * lateralDecel) * scale
end

-- Thrust along the hull's forward axis (a signed number; multiply by forward). throttle -1..1.
-- Reverse throttle brakes while moving forward, then reverses slowly. No thrust out of the water.
function Buoyancy.thrust(
	throttle: number,
	forwardSpeed: number,
	mass: number,
	handling: Handling,
	contact: number,
	speedMult: number
): number
	throttle = math.clamp(throttle, -1, 1)
	local force = 0
	if throttle > 0 then
		force = mass * handling.accel * speedMult * throttle
	elseif throttle < 0 then
		if forwardSpeed > 0.5 then
			force = mass * handling.brakeDecel * throttle
		elseif forwardSpeed > -handling.topSpeed * Buoyancy.REVERSE_SPEED_FRACTION then
			force = mass * handling.accel * Buoyancy.REVERSE_ACCEL_FRACTION * throttle
		end
	end
	return force * math.clamp(contact, 0, 1)
end

-- Yaw torque about world +Y. steer -1 (left) .. 1 (right); right is a negative yaw rate.
-- It drives the yaw rate toward a steering target, so with steer 0 it acts as yaw drag.
-- Steering is weaker at low speed, flips in reverse, and vanishes out of the water.
function Buoyancy.steerTorque(
	steer: number,
	forwardSpeed: number,
	yawRate: number,
	inertiaYaw: number,
	handling: Handling,
	contact: number,
	speedMult: number
): number
	steer = math.clamp(steer, -1, 1)
	local fullSpeed = handling.topSpeed * speedMult * Buoyancy.FULL_STEER_SPEED_FRACTION
	local authority = Buoyancy.MIN_STEER_AUTHORITY
		+ (1 - Buoyancy.MIN_STEER_AUTHORITY)
			* math.clamp(math.abs(forwardSpeed) / fullSpeed, 0, 1)
	local direction = if forwardSpeed < -1 then -1 else 1
	local target = -steer * math.rad(handling.turnRate) * authority * direction
	return inertiaYaw * Buoyancy.TURN_GAIN * (target - yawRate) * math.clamp(contact, 0, 1)
end

-- Gentle self-righting plus pitch/roll angular drag (world-space torque). up is the hull's up
-- vector; inertia a representative pitch/roll moment of inertia. Buoyancy does most of the
-- righting; this stops slow capsizes from character mass on deck.
function Buoyancy.uprightTorque(up: Vector3, angularVelocity: Vector3, inertia: number): Vector3
	local w = Buoyancy.UPRIGHT_FREQUENCY
	local restoring = up:Cross(Vector3.yAxis) * (w * w)
	local tiltRate = Vector3.new(angularVelocity.X, 0, angularVelocity.Z)
	return (restoring - tiltRate * Buoyancy.UPRIGHT_DAMPING) * inertia
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
