--!strict
-- RiderPose: the jet ski rider's procedural body language on top of the stock VehicleSeat sit (pure logic,
-- tests/RiderPose.spec.luau). RiderController feeds it the craft's own motion (yaw rate, forward speed,
-- vertical velocity), so every client poses every rider from replicated physics, no remotes:
--   lean    the body banks into the turn (Root roll), the head stays nearer level (Neck);
--   crouch  the rider tucks forward on the throttle and when planing (Waist pitch, Root dip);
--   bounce  a slam on a wave crest compresses the legs and springs back (Root dip, Waist nod).
-- Transforms are in the R15 joints' C0 axes (+Z roll leans left, -X pitch leans forward).
local RiderPose = {}

RiderPose.MAX_LEAN = math.rad(22)
RiderPose.LEAN_GAIN = 0.55 -- lean (rad) per rad/s of yaw at speed -- tune
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
}
export type Input = {
	dt: number,
	yawRate: number, -- rad/s, + turning left (seen from above)
	speed: number, -- forward studs/s
	topSpeed: number,
	vertical: number, -- studs/s, + up
	scale: number, -- 1 normal; Reduce motion passes less (and no bounce at 0.5 or under)
}
export type Pose = { Root: CFrame, Waist: CFrame, Neck: CFrame }

function RiderPose.new(): State
	return { lean = 0, crouch = 0, accel = 0, y = 0, vy = 0 }
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
	if dv / dt > RiderPose.SLAM_ACCEL and i.scale > 0.5 then
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
		Neck = CFrame.Angles(tuck * 0.7, 0, -leanK * 0.6),
	}
end

return RiderPose
