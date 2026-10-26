--!strict
-- Heli/Flight (docs/23 h, WP-6): arcade flight model for the rescue helicopter. Pure, Lune-tested in
-- tests/Heli.spec.luau. HeliController feeds the result to the Builder's LinearVelocity "Lift" and
-- AlignOrientation "Attitude" on HeliRoot.
-- Kid-friendly: inputs set a target velocity and yaw rate, the craft eases toward them, and hands
-- off means a level, stable hover. Tilt only shows the motion (auto-level: no motion, no tilt).
-- It never sinks below the floor (ground + skids, or the sea + WATER_CLEARANCE) and never climbs
-- past the ceiling. Heading 0 looks along -Z (Roblox CFrame.Angles(0, heading, 0)).
local Flight = {}

export type Spec = {
	forwardSpeed: number, -- studs/s
	strafeSpeed: number, -- studs/s
	climbSpeed: number, -- studs/s
	yawRate: number, -- rad/s at full stick
	accel: number, -- studs/s^2 toward the target velocity
	yawAccel: number, -- rad/s^2 toward the target yaw rate
	maxTilt: number, -- rad of nose-down at full forward speed
	skid: number, -- studs from HeliRoot's centre down to the skids
	ceiling: number, -- world Y
}

export type Input = { forward: number, strafe: number, yaw: number, lift: number } -- each -1..1

export type State = { velocity: Vector3, heading: number, yawRate: number }

Flight.WATER_CLEARANCE = 8 -- studs from the sea to the skids: a piloted heli never ditches
Flight.FLOAT_DRAFT = 1 -- studs the skids sit under the sea when an empty heli settles onto it (Craft.idle)
Flight.ALTITUDE_GAIN = 2 -- 1/s: how hard the floor and ceiling push back
Flight.WIND = 1.5 -- studs/s of drift in a full storm; under Board.STEADY_SPEED, so a hover still winches

-- Flight specs by VehicleId (VehicleConfig gets the entry in WP-10). 1 m = 3 studs.
Flight.SPECS = {
	RescueHelicopter = { -- ProgressionConfig id
		forwardSpeed = 90, -- ~60 knots: a game-speed rescue heli, quicker than the RIB
		strafeSpeed = 30,
		climbSpeed = 30,
		yawRate = math.rad(80),
		accel = 30,
		yawAccel = math.rad(240),
		maxTilt = math.rad(14),
		skid = 4.5,
		ceiling = 300,
	} :: Spec,
}

function Flight.spec(vehicleId: any): Spec?
	return if type(vehicleId) == "string" then Flight.SPECS[vehicleId] else nil
end

function Flight.new(heading: number, velocity: Vector3?): State
	return { velocity = velocity or Vector3.zero, heading = heading, yawRate = 0 }
end

-- Heading of a look vector (inverse of CFrame.Angles(0, heading, 0).LookVector).
function Flight.headingOf(look: Vector3): number
	return math.atan2(-look.X, -look.Z)
end

-- Lowest the root may sit: on its skids over land (and decks), WATER_CLEARANCE above open sea.
-- groundY: the first solid hit straight down (nil = none); waterY: the sea surface there.
-- landing (an empty heli setting itself down): over open sea it settles onto the water and floats.
function Flight.floor(groundY: number?, waterY: number, spec: Spec, landing: boolean?): number
	if groundY and groundY >= waterY then
		return groundY + spec.skid
	end
	return waterY + spec.skid + (if landing then -Flight.FLOAT_DRAFT else Flight.WATER_CLEARANCE)
end

-- Gentle drift from Weather (wind angle in radians, direction (cos a, sin a); intensity 0..1).
function Flight.wind(angle: number, intensity: number): Vector3
	local w = Flight.WIND * math.clamp(intensity, 0, 1)
	return Vector3.new(math.cos(angle) * w, 0, math.sin(angle) * w)
end

local function toward(current: number, target: number, maxStep: number): number
	return current + math.clamp(target - current, -maxStep, maxStep)
end

-- Advances `s` by dt (mutates and returns it). y is the root's height; floorY from Flight.floor.
function Flight.step(
	s: State,
	input: Input,
	spec: Spec,
	y: number,
	floorY: number,
	wind: Vector3,
	dt: number
): State
	local yawIn = math.clamp(input.yaw, -1, 1)
	s.yawRate = toward(s.yawRate, -yawIn * spec.yawRate, spec.yawAccel * dt) -- right stick = turn right
	s.heading += s.yawRate * dt

	local h = s.heading
	local look = Vector3.new(-math.sin(h), 0, -math.cos(h))
	local right = Vector3.new(math.cos(h), 0, -math.sin(h))
	local flat = look * math.clamp(input.forward, -1, 1) * spec.forwardSpeed
		+ right * math.clamp(input.strafe, -1, 1) * spec.strafeSpeed
		+ wind
	local vy = math.clamp(input.lift, -1, 1) * spec.climbSpeed
	-- the floor wins over the ceiling (a peak above the ceiling still lifts it clear)
	vy = math.max(
		math.min(vy, (spec.ceiling - y) * Flight.ALTITUDE_GAIN),
		(floorY - y) * Flight.ALTITUDE_GAIN
	)
	local target = Vector3.new(flat.X, vy, flat.Z)

	local delta = target - s.velocity
	local maxStep = spec.accel * dt
	s.velocity = if delta.Magnitude > maxStep then s.velocity + delta.Unit * maxStep else target
	return s
end

-- The pose for AlignOrientation: heading, nose down with forward speed, banked into strafe and turns.
function Flight.attitude(s: State, spec: Spec): CFrame
	local yawOnly = CFrame.Angles(0, s.heading, 0)
	local fwd = s.velocity:Dot(yawOnly.LookVector) / spec.forwardSpeed
	local side = s.velocity:Dot(yawOnly.RightVector) / spec.strafeSpeed
	local turn = s.yawRate / spec.yawRate
	local pitch = -math.clamp(fwd, -1, 1) * spec.maxTilt
	local roll = -math.clamp(side * 0.6 - turn * 0.4, -1, 1) * spec.maxTilt
	return yawOnly * CFrame.Angles(pitch, 0, roll)
end

return Flight
