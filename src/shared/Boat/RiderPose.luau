--!strict
-- RiderPose: the jet ski rider's procedural body language on top of the stock VehicleSeat sit (pure logic,
-- tests/RiderPose.spec.luau). RiderController feeds it the craft's own motion (yaw rate, forward speed,
-- vertical velocity), so every client poses every rider from replicated physics, no remotes:
--   lean    the body banks into the turn (Root roll), the head stays nearer level (Neck);
--   crouch  the rider tucks forward on the throttle and when planing (Waist pitch, Root dip);
--   bounce  a slam on a wave crest compresses the legs and springs back (Root dip, Waist nod).
-- Plus the hull bank (RiderPose.bank: BoatController rolls the visual hull on its VisualJoint, never the physics
-- root, so it can't trip the capsize eject) and the spray strengths (RiderPose.spray: RiderController's
-- rooster tail and carve spray). The rider leans a further MAX_LEAN on top of the bank.
-- Transforms are in the R15 joints' C0 axes (+Z roll leans left, -X pitch leans forward).
local RiderPose = {}

RiderPose.MAX_LEAN = math.rad(9) -- the rider's own lean, on top of the hull bank
RiderPose.LEAN_GAIN = 0.25 -- lean (rad) per rad/s of yaw at speed -- tune
RiderPose.MAX_BANK = math.rad(16) -- the visual hull's bank (docs/24 carve: reads on a phone)
RiderPose.BANK_GAIN = 0.4 -- bank (rad) per rad/s of yaw: full at ~0.7 rad/s, a planing carve -- tune
RiderPose.BANK_RATE = 1 / 0.15 -- eases in ~0.15 s
RiderPose.SPRAY_MIN = 8 -- studs/s: no rooster tail below this
RiderPose.SPRAY_FULL = 0.6 -- share of top speed for the full rooster tail -- tune
RiderPose.CARVE_MIN, RiderPose.CARVE_FULL = 10, 40 -- studs/s^2 of lateral accel (speed x yaw) for side spray -- tune
RiderPose.LEAN_SPEED = 14 -- studs/s for the full lean (no lean while idling round)
RiderPose.MAX_CROUCH = math.rad(24) -- forward tuck at full crouch
RiderPose.CROUCH_ACCEL = 14 -- studs/s^2 of forward acceleration for a full crouch -- tune
RiderPose.CROUCH_PLANE = 0.35 -- crouch held at top speed
RiderPose.DIP = 0.35 -- studs the hips sink at full crouch
RiderPose.SLAM_ACCEL = 250 -- studs/s^2 upward jolt before a bump registers (replication steps stay under it) -- tune
RiderPose.SPRING_K = 180
RiderPose.SPRING_C = 14 -- ~2 Hz, half damped: one compress, one small rebound
RiderPose.MAX_BOUNCE = 0.6

export type State = {
	lean: number,
	crouch: number,
	accel: number,
	lastSpeed: number?,
	lastVert: number?,
	y: number,
	vy: number,
	slam: boolean, -- this step's input was a wave slam (RiderController's splash)
}
export type Input = {
	dt: number,
	yawRate: number, -- rad/s, + turning left (seen from above)
	speed: number, -- forward studs/s
	topSpeed: number,
	vertical: number, -- studs/s, + up
	scale: number, -- 1 normal; Reduce motion passes less (and no bounce at 0.5 or under)
	bank: number?, -- the hull's visual bank (rad, + left): the head counters it too
}
export type Pose = { Root: CFrame, Waist: CFrame, Neck: CFrame }

function RiderPose.new(): State
	return { lean = 0, crouch = 0, accel = 0, y = 0, vy = 0, slam = false }
end

local function ease(from: number, to: number, rate: number, dt: number): number
	return from + (to - from) * math.min(1, dt * rate)
end

function RiderPose.step(s: State, i: Input): Pose
	local dt = math.clamp(i.dt, 0, 0.1)
	if dt <= 0 then
		dt = 1 / 60
	end
	local speedK = math.clamp(math.abs(i.speed) / RiderPose.LEAN_SPEED, 0, 1)
	local lean = math.clamp(
		i.yawRate * RiderPose.LEAN_GAIN,
		-RiderPose.MAX_LEAN,
		RiderPose.MAX_LEAN
	) * speedK
	s.lean = ease(s.lean, lean, 6, dt)

	local raw = if s.lastSpeed then (i.speed - s.lastSpeed) / dt else 0
	s.lastSpeed = i.speed
	s.accel = ease(s.accel, raw, 4, dt)
	local plane = math.clamp(i.speed / math.max(1, i.topSpeed), 0, 1) * RiderPose.CROUCH_PLANE
	local crouch = math.clamp(math.max(s.accel / RiderPose.CROUCH_ACCEL, plane), 0, 1)
	s.crouch = ease(s.crouch, crouch, 5, dt)

	-- a bump: the hull's vertical velocity jumps up in one step (it hit a crest or landed a jump)
	local dv = if s.lastVert then i.vertical - s.lastVert else 0
	s.lastVert = i.vertical
	s.slam = dv / dt > RiderPose.SLAM_ACCEL
	if s.slam and i.scale > 0.5 then
		s.vy -= math.min(dv, 30) * 0.25
	end
	s.vy += (-RiderPose.SPRING_K * s.y - RiderPose.SPRING_C * s.vy) * dt
	s.y = math.clamp(s.y + s.vy * dt, -RiderPose.MAX_BOUNCE, RiderPose.MAX_BOUNCE * 0.5)

	local k = math.clamp(i.scale, 0, 1)
	local tuck = s.crouch * RiderPose.MAX_CROUCH * k
	local nod = math.min(0, s.y) * 0.5 * k -- compressing folds the waist a touch
	local leanK = s.lean * k
	return {
		Root = CFrame.new(0, (s.y - s.crouch * RiderPose.DIP) * k, 0) * CFrame.Angles(0, 0, leanK),
		Waist = CFrame.Angles(-tuck + nod, 0, 0),
		Neck = CFrame.Angles(tuck * 0.7, 0, -(leanK + (i.bank or 0)) * 0.6),
	}
end

-- The visual hull's bank (rad, + = left side down, the VisualJoint's +Z roll) eased from `current` toward the
-- turn: none while idling round, MAX_BANK * scale at most (Reduce motion passes less).
function RiderPose.bank(
	current: number,
	yawRate: number,
	speed: number,
	scale: number,
	dt: number
): number
	local speedK = math.clamp(math.abs(speed) / RiderPose.LEAN_SPEED, 0, 1)
	local cap = RiderPose.MAX_BANK * math.clamp(scale, 0, 1)
	local target = math.clamp(yawRate * RiderPose.BANK_GAIN * speedK, -cap, cap)
	return ease(current, target, RiderPose.BANK_RATE, math.clamp(dt, 0, 0.1))
end

-- Spray strengths 0..1: the stern rooster tail (forward speed) and the side spray thrown off the outside of a
-- carve (lateral accel = speed x yaw rate). Moving astern throws neither.
function RiderPose.spray(speed: number, topSpeed: number, yawRate: number): (number, number)
	if speed < RiderPose.SPRAY_MIN then
		return 0, 0
	end
	local full = math.max(RiderPose.SPRAY_MIN + 1, topSpeed * RiderPose.SPRAY_FULL)
	local tail = math.clamp((speed - RiderPose.SPRAY_MIN) / (full - RiderPose.SPRAY_MIN), 0, 1)
	local lat = math.abs(speed * yawRate)
	local side =
		math.clamp((lat - RiderPose.CARVE_MIN) / (RiderPose.CARVE_FULL - RiderPose.CARVE_MIN), 0, 1)
	return tail, side
end

return RiderPose
