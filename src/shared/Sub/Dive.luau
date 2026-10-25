--!strict
-- Sub/Dive: the submarine's dive model (docs/23 (h), WP-8). Pure, Lune-tested (tests/Sub.spec.luau);
-- Sub/Rig applies it to a model. Slow and calm: it floats at the surface like a slow boat, dives and
-- rises at a steady rate, holds its depth when hands-off (neutral buoyancy), turns on the spot, and
-- never leaves the band between the seabed (+ CLEARANCE) and the surface (floating at DRAFT).
-- Studs, seconds, radians; yaw follows Roblox (positive = turning left).
local Board = require(script.Parent.Parent.Ops.Board)

local Dive = {}

Dive.TOP_SPEED = 40 -- studs/s ahead at the surface, like a slow boat (jet ski 75) -- tune
Dive.SUBMERGED_SPEED = 22 -- studs/s ahead under water: calm near the seabed -- tune
Dive.REVERSE_SPEED = 5 -- tune
Dive.ACCEL = 5 -- studs/s^2 under throttle, also easing down to SUBMERGED_SPEED on a dive -- tune
Dive.DECEL = 3 -- studs/s^2 coasting -- tune
Dive.TURN_RATE = math.rad(40) -- rad/s at full steer -- tune
Dive.TURN_EASE = 2.5 -- rad/s^2 -- tune
Dive.DIVE_SPEED = 6 -- studs/s up or down -- tune
Dive.VERTICAL_ACCEL = 4 -- studs/s^2 -- tune
Dive.DRAFT = 1.2 -- root centre below the surface when floating
Dive.CLEARANCE = 4 -- root centre above the seabed, at least
Dive.SURFACE_SNAP = 1.5 -- hands-off this close under the float line: pop up and float
Dive.SPRING = 3 -- 1/s, pull back into the band and onto the waves
Dive.SUBMERGED = 2 -- studs under the float line counts as submerged (camera, lights)
Dive.MAX_PITCH = math.rad(12)
Dive.MAX_ROLL = math.rad(6)
-- pick-up of a diver on the seabed: hover steady inside the ring (Board's speed and hold)
Dive.SEATS = 2
Dive.RING_RADIUS = 12 -- studs, flat distance to the diver
Dive.RING_HEIGHT = 8 -- studs above or below the diver

export type State = {
	speed: number, -- forward, studs/s
	climb: number, -- the pilot's eased vertical speed, before the seabed / surface limits
	vy: number, -- vertical, studs/s
	yawRate: number, -- rad/s
	yaw: number,
	pitch: number, -- target attitude: bow up +
	roll: number, -- starboard down -
	submerged: boolean,
}

function Dive.new(yaw: number): State
	return {
		speed = 0,
		climb = 0,
		vy = 0,
		yawRate = 0,
		yaw = yaw,
		pitch = 0,
		roll = 0,
		submerged = false,
	}
end

local function approach(x: number, target: number, rate: number, dt: number): number
	local d = target - x
	local stepMax = rate * dt
	return if math.abs(d) <= stepMax then target else x + math.sign(d) * stepMax
end

-- throttle, steer, dive: -1..1 (dive +1 = rise). y: root centre; surfaceY: water at the sub; floorY:
-- the seabed under it. Mutates and returns s.
function Dive.step(
	s: State,
	throttle: number,
	steer: number,
	dive: number,
	y: number,
	surfaceY: number,
	floorY: number,
	dt: number
): State
	local top = if s.submerged then Dive.SUBMERGED_SPEED else Dive.TOP_SPEED
	local want = if throttle >= 0 then throttle * top else throttle * Dive.REVERSE_SPEED
	s.speed = approach(s.speed, want, if throttle ~= 0 then Dive.ACCEL else Dive.DECEL, dt)
	s.yawRate = approach(s.yawRate, -steer * Dive.TURN_RATE, Dive.TURN_EASE, dt)
	s.yaw += s.yawRate * dt

	local ceiling = surfaceY - Dive.DRAFT
	local floor = math.min(floorY + Dive.CLEARANCE, ceiling) -- too shallow to dive: float
	s.climb = approach(s.climb, dive * Dive.DIVE_SPEED, Dive.VERTICAL_ACCEL, dt)
	local vy = s.climb
	if dive >= 0 and y >= ceiling - Dive.SURFACE_SNAP then
		vy = (ceiling - y) * Dive.SPRING -- floating: ride the waves like a boat
	else
		vy = math.max(math.min(vy, (ceiling - y) * Dive.SPRING), (floor - y) * Dive.SPRING)
	end
	s.vy = math.clamp(vy, -Dive.DIVE_SPEED * 1.5, Dive.DIVE_SPEED * 1.5)
	s.climb = math.clamp(s.climb, math.min(s.vy, 0), math.max(s.vy, 0)) -- no wind-up against a limit

	-- auto-level: only a small bow-down on a dive and a lean into turns
	s.pitch = math.clamp(s.vy / Dive.DIVE_SPEED, -1, 1) * Dive.MAX_PITCH
	s.roll = s.yawRate
		/ Dive.TURN_RATE
		* Dive.MAX_ROLL
		* math.clamp(math.abs(s.speed) / Dive.TOP_SPEED, 0, 1)
	s.submerged = y < ceiling - Dive.SUBMERGED
	return s
end

-- May the diver climb aboard? dx, dy, dz: diver minus sub; room: a free seat (Board.hasRoom).
function Dive.pickupReady(dx: number, dy: number, dz: number, speed: number, room: boolean): boolean
	return room
		and dx * dx + dz * dz <= Dive.RING_RADIUS * Dive.RING_RADIUS
		and math.abs(dy) <= Dive.RING_HEIGHT
		and speed <= Board.STEADY_SPEED
end

-- Hold-steady timer: (held seconds, done). Leaving the ring or speeding up resets it.
function Dive.hold(held: number, ready: boolean, dt: number): (number, boolean)
	held = if ready then held + dt else 0
	return held, held >= Board.HOLD
end

return Dive
