--!strict
-- CameraMath: the pure maths behind the camera rigs (no services, Lune-tested in
-- tests/CameraMath.spec.luau). Scale: 1 m = 3 studs (VehicleConfig).
--
--   damp(current, target, halfLife, dt)            frame-rate independent exponential smoothing
--   dampAngle(current, target, halfLife, dt)       damp along the shortest arc
--   horizonFrame(cf)                               yaw-only rotation of cf (horizon locked)
--   speedFov(base, speed, topSpeed, kick)          FOV with the speed kick
--   armDistance(desired, hit, padding, minDist)    spring-arm length after a collision probe
--   relaxArm(current, target, halfLife, dt)        snap in on a hit, ease back out
--   lookAhead(velocity, seconds, maxAhead)         flat look-ahead offset for the chase focus
--   aboveSwell(position, waveHeight, clearance)    keep the camera above the water surface
--   chaseOffset(heading, yaw, pitch, distance)     spring-arm end point relative to the focus
--   deadzone(x, dz)                                rescaled stick deadzone
local CameraMath = {}

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

function CameraMath.smoothstep(x: number): number
	local t = clamp01(x)
	return t * t * (3 - 2 * t)
end

-- Exponential smoothing that behaves the same at any frame rate. Works on numbers, Vector3s.
function CameraMath.damp<T>(current: T, target: T, halfLife: number, dt: number): T
	if halfLife <= 0 then
		return target
	end
	local k = 2 ^ (-dt / halfLife)
	return (target :: any) + ((current :: any) - (target :: any)) * k
end

-- Wraps an angle to (-pi, pi].
function CameraMath.wrap(angle: number): number
	local a = (angle + math.pi) % (2 * math.pi) - math.pi
	if a <= -math.pi then
		a += 2 * math.pi
	end
	return a
end

function CameraMath.dampAngle(current: number, target: number, halfLife: number, dt: number): number
	local delta = CameraMath.wrap(target - current)
	return CameraMath.wrap(target - CameraMath.damp(delta, 0, halfLife, dt))
end

-- The yaw-only rotation of `cf` (its heading, with the horizon level).
function CameraMath.horizonFrame(cf: CFrame): CFrame
	local look = cf.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-4 then
		-- looking straight up or down: take the heading from the up vector instead
		local up = cf.UpVector
		flat = Vector3.new(-up.X, 0, -up.Z) * math.sign(look.Y)
		if flat.Magnitude < 1e-4 then
			flat = Vector3.new(0, 0, -1)
		end
	end
	return CFrame.lookAt(Vector3.zero, flat.Unit)
end

-- Field of view with a speed kick (degrees): the kick eases in over the top half of the speed.
function CameraMath.speedFov(base: number, speed: number, topSpeed: number, kick: number): number
	if topSpeed <= 0 then
		return base
	end
	local f = CameraMath.smoothstep((math.abs(speed) / topSpeed - 0.25) / 0.75)
	return math.min(base + kick * f, 110)
end

-- Spring-arm length: the desired length, or just short of the first hit.
function CameraMath.armDistance(
	desired: number,
	hitDistance: number?,
	padding: number,
	minDist: number
): number
	if hitDistance == nil or hitDistance >= desired then
		return desired
	end
	return math.max(minDist, math.min(desired, hitDistance - padding))
end

-- Snap the arm in at once (never clip through geometry) and ease it back out.
function CameraMath.relaxArm(current: number, target: number, halfLife: number, dt: number): number
	if target <= current then
		return target
	end
	return CameraMath.damp(current, target, halfLife, dt)
end

-- Flat look-ahead from the hull velocity, so the frame leads the boat into the swell.
function CameraMath.lookAhead(velocity: Vector3, seconds: number, maxAhead: number): Vector3
	local flat = Vector3.new(velocity.X, 0, velocity.Z) * seconds
	local m = flat.Magnitude
	if m > maxAhead then
		flat = flat * (maxAhead / m)
	end
	return flat
end

function CameraMath.aboveSwell(position: Vector3, waveHeight: number, clearance: number): Vector3
	local floor = waveHeight + clearance
	if position.Y >= floor then
		return position
	end
	return Vector3.new(position.X, floor, position.Z)
end

-- Arm end point relative to the focus: behind the heading (radians, 0 = looking along -Z),
-- orbited by yaw and raised by pitch (radians above the horizon).
function CameraMath.chaseOffset(
	heading: number,
	yaw: number,
	pitch: number,
	distance: number
): Vector3
	local a = heading + yaw
	local back = Vector3.new(math.sin(a), 0, math.cos(a)) -- -look of a heading-a frame
	return back * (math.cos(pitch) * distance) + Vector3.new(0, math.sin(pitch) * distance, 0)
end

-- Heading (radians) of a CFrame's look vector, in the convention chaseOffset uses.
function CameraMath.heading(cf: CFrame): number
	local look = cf.LookVector
	return math.atan2(-look.X, -look.Z)
end

function CameraMath.deadzone(x: number, dz: number): number
	local m = math.abs(x)
	if m <= dz then
		return 0
	end
	return math.sign(x) * (m - dz) / (1 - dz)
end

-- Camera shake from trauma (0..1): rotation offsets (radians) from smooth noise, scaled by
-- trauma squared (small knocks stay subtle), `intensity` the comfort setting.
function CameraMath.shake(
	trauma: number,
	intensity: number,
	t: number,
	noise: (number, number, number) -> number
): Vector3
	local k = clamp01(trauma) ^ 2 * clamp01(intensity) * math.rad(2.5)
	if k <= 0 then
		return Vector3.zero
	end
	return Vector3.new(noise(t * 17, 1.3, 0), noise(t * 17, 7.9, 0), noise(t * 17, 13.1, 0) * 0.5)
		* k
end

return CameraMath
