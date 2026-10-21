--!strict
-- BosunMotion: Bosun's procedural body language on the code-built placeholder dog (Shared.Dog.BosunRig),
-- pure logic (tests/BosunMotion.spec.luau). DogService joins the rig's Parts with Motor6Ds named after the
-- Pose keys and DogController writes the Transforms this module returns, every frame, client side.
-- The server owns where he is (AlignPosition, the ride weld); this is only how he holds himself:
--   Root   Body -> Torso, pivot on the ground under the front legs: walk bob, rocking and rolling,
--          breathing, the sit (pitched nose up about the hips, rear lowered), the swim's float, the lean
--          on a moving deck, the shake;
--   Neck   Torso -> Head (neck and head), pivot at the neck base: the head turns toward the look target;
--   Jaw    Head -> Jaw: panting after a run;
--   Tail1, Tail2: the wag (the tip follows a beat late), carried high when excited or swimming, low and
--          still when he sits or is tired, tucked when he is cold or wet out of the water;
--   <Front|Back><Left|Right><Upper|Lower>: a trot (diagonal pairs), the sit (front legs kept upright,
--          hind legs folded under), the swim's paddle.
-- Transforms are in the authored frame's axes (+X pitch swings a hanging leg forward and lowers the tail).
local BosunMotion = {}

BosunMotion.LEGS = { "FrontLeft", "FrontRight", "BackLeft", "BackRight" }
-- the hips relative to the Root pivot (BosunRig: hip (0, 1.5, 0.92), Root pivot (0, 0, -0.85))
BosunMotion.SIT_PIVOT = Vector3.new(0, 1.5, 1.77)
BosunMotion.SIT_PITCH = math.rad(35)
BosunMotion.SIT_DROP = 1.0 -- studs the hips drop (about the shoulder-hip span * sin SIT_PITCH)
BosunMotion.LEG_SWING = math.rad(26) -- trot swing either side at full gait
BosunMotion.KNEE_LIFT = math.rad(38) -- lower leg folds back while the paw swings forward

BosunMotion.MAX_YAW = math.rad(28) -- head turn either side
BosunMotion.MAX_PITCH_UP = math.rad(16)
BosunMotion.MAX_PITCH_DOWN = math.rad(-12)
BosunMotion.RUFF_FOLLOW = 0.5
BosunMotion.SIT_AFTER = 2.5 -- seconds standing still before he sits
BosunMotion.RIDE_SIT_AFTER = 4 -- seconds of a calm deck before he sits aboard
BosunMotion.STRIDE = 3.2 -- studs per stride
BosunMotion.MAX_STEP_HZ = 3.0
BosunMotion.SHAKE_SECONDS = 0.9
BosunMotion.MAX_LEAN = math.rad(9)
-- tail (Tail1 joint; +X pitch lowers it, the tail runs back along +Z)
BosunMotion.TAIL_WAG = math.rad(26) -- wag either side at full excitement
BosunMotion.TAIL_RAISE = math.rad(30) -- carried up at full excitement
BosunMotion.TAIL_SWIM_RAISE = math.rad(18) -- streamed out level behind him as a rudder
BosunMotion.TAIL_SIT_DROP = math.rad(14) -- resting low on the ground
BosunMotion.TAIL_TIRED_DROP = math.rad(16)
BosunMotion.TAIL_TUCK = math.rad(38) -- clamped down between the hind legs

export type Mode = "Follow" | "Wait" | "Ride" | "Swim"

export type Input = {
	dt: number,
	mode: string, -- Mode; anything else is treated as Follow
	speed: number, -- planar studs/s over the ground (0 aboard: he stands on the deck)
	look: Vector3?, -- where to look, in the body's frame (front -Z); nil: ahead
	excited: number, -- 0..1: tail wag (owner close, pointing out a casualty)
	accel: Vector3?, -- Ride: the deck's acceleration in the body's frame, studs/s^2
	deckRoll: number?, -- Ride: the deck's roll (radians, right side up +) and pitch (nose up +)
	deckPitch: number?,
	wetness: number?, -- 0..1 coat wetness (BosunWetness); wet out of the water tucks the tail
	cold: number?, -- 0..1 cold (no source yet): tucks the tail
}

export type State = {
	t: number,
	phase: number, -- stride
	gait: number, -- 0 standing .. 1 running
	still: number, -- seconds standing still (or calm aboard)
	sit: number,
	swim: number,
	exertion: number, -- panting after a run
	breath: number,
	wagPhase: number,
	wag: number,
	paddle: number,
	yaw: number,
	pitch: number,
	leanRoll: number,
	leanPitch: number,
	shake: number, -- seconds of shake left
	lastMode: string,
	tailLift: number, -- radians, + up
	tuck: number, -- 0..1
	tired: number, -- 0..1
}

export type Pose = { [string]: CFrame } -- Root, Neck, Jaw, Tail1, Tail2 and the eight leg joints

local TAU = 2 * math.pi

local function approach(current: number, target: number, rate: number, dt: number): number
	return target + (current - target) * math.exp(-rate * dt)
end

function BosunMotion.new(): State
	return {
		t = 0,
		phase = 0,
		gait = 0,
		still = 0,
		sit = 0,
		swim = 0,
		exertion = 0,
		breath = 0,
		wagPhase = 0,
		wag = 0,
		paddle = 0,
		yaw = 0,
		pitch = 0,
		leanRoll = 0,
		leanPitch = 0,
		shake = 0,
		lastMode = "Follow",
		tailLift = 0,
		tuck = 0,
		tired = 0,
	}
end

-- Head yaw and pitch (radians, clamped) to look along `look` (body frame, front -Z).
function BosunMotion.lookAngles(look: Vector3?): (number, number)
	if not look or look.Magnitude < 1e-4 then
		return 0, 0
	end
	local d = look.Unit
	local yaw = math.atan2(-d.X, -d.Z)
	local pitch = math.asin(math.clamp(d.Y, -1, 1))
	if math.abs(yaw) > math.rad(110) then
		pitch = 0 -- behind him: a sideways glance, not a stare into his back
	end
	return math.clamp(yaw, -BosunMotion.MAX_YAW, BosunMotion.MAX_YAW),
		math.clamp(pitch, BosunMotion.MAX_PITCH_DOWN, BosunMotion.MAX_PITCH_UP)
end

-- Target lean (roll, pitch) into the deck's motion: into the turn, forward when it surges ahead,
-- and partly levelled against the deck's own roll and pitch.
function BosunMotion.leanTarget(
	accel: Vector3?,
	deckRoll: number?,
	deckPitch: number?
): (number, number)
	local a = accel or Vector3.zero
	local m = BosunMotion.MAX_LEAN
	local roll = -a.X * math.rad(0.35) - 0.4 * (deckRoll or 0)
	local pitch = a.Z * math.rad(0.3) - 0.3 * (deckPitch or 0)
	return math.clamp(roll, -m, m), math.clamp(pitch, -m, m)
end

-- Advances `state` by input.dt and returns the Motor6D Transforms.
function BosunMotion.step(state: State, input: Input): Pose
	local dt = math.clamp(input.dt, 0, 0.1)
	local mode = input.mode
	if mode ~= "Wait" and mode ~= "Ride" and mode ~= "Swim" then
		mode = "Follow"
	end
	state.t += dt
	if state.lastMode == "Swim" and mode ~= "Swim" then
		state.shake = BosunMotion.SHAKE_SECONDS
	end
	state.lastMode = mode

	local speed = if mode == "Follow" then math.max(0, input.speed) else 0
	local accel = input.accel or Vector3.zero

	-- standing still -> sitting
	local calm = if mode == "Ride" then accel.Magnitude < 3 else speed < 0.6
	state.still = if calm then state.still + dt else 0
	local sits = mode == "Wait"
		or (mode == "Follow" and state.still > BosunMotion.SIT_AFTER)
		or (mode == "Ride" and state.still > BosunMotion.RIDE_SIT_AFTER)
	local sitTarget = if sits then 1 else 0
	-- he sits down slowly and gets up quickly
	state.sit = approach(state.sit, sitTarget, if sitTarget > state.sit then 2.2 else 7, dt)
	state.swim = approach(state.swim, if mode == "Swim" then 1 else 0, 3, dt)

	-- walk cycle
	state.gait = approach(state.gait, math.clamp(speed / 10, 0, 1), 6, dt)
	local stepHz = math.min(speed / BosunMotion.STRIDE, BosunMotion.MAX_STEP_HZ)
	state.phase = (state.phase + TAU * stepHz * dt) % TAU
	local g = state.gait * (1 - state.sit)

	-- breathing: slow at rest, panting after a run
	state.exertion =
		approach(state.exertion, state.gait, if state.gait > state.exertion then 0.15 else 0.05, dt)
	local breathHz = 0.3 + 1.4 * state.exertion
	state.breath = (state.breath + TAU * breathHz * dt) % TAU
	local breath = math.sin(state.breath)

	-- tail wag
	local excited = math.clamp(input.excited, 0, 1)
	state.wag = approach(state.wag, excited, 4, dt)
	state.wagPhase = (state.wagPhase + TAU * (1.8 + 1.2 * state.wag) * dt) % TAU
	-- swimming paddle
	state.paddle = (state.paddle + TAU * 1.3 * dt) % TAU
	local sw = state.swim

	-- head
	local yawTarget, pitchTarget = BosunMotion.lookAngles(input.look)
	state.yaw = approach(state.yaw, yawTarget, 6, dt)
	state.pitch = approach(state.pitch, pitchTarget, 6, dt)

	-- deck lean
	local rollTarget, leanPitchTarget = 0, 0
	if mode == "Ride" then
		rollTarget, leanPitchTarget = BosunMotion.leanTarget(accel, input.deckRoll, input.deckPitch)
	end
	state.leanRoll = approach(state.leanRoll, rollTarget, 4, dt)
	state.leanPitch = approach(state.leanPitch, leanPitchTarget, 4, dt)

	-- shake after a swim
	local shakeRoll, shakeHead = 0, 0
	if state.shake > 0 then
		state.shake = math.max(0, state.shake - dt)
		local p = 1 - state.shake / BosunMotion.SHAKE_SECONDS
		local envelope = math.sin(math.pi * p)
		shakeRoll = math.sin(state.t * TAU * 6.5) * math.rad(9) * envelope
		shakeHead = math.sin(state.t * TAU * 6.5 + 0.9) * math.rad(16) * envelope
	end

	local gaitPitch = g * math.rad(2.2) * math.sin(state.phase + 0.6)
	local rootPitch = gaitPitch
		+ sw * (math.rad(9) + math.rad(2.5) * math.sin(state.paddle))
		+ state.leanPitch
	local rootRoll = g * math.rad(1.6) * math.sin(state.phase) + state.leanRoll + shakeRoll
	local rootY = g * 0.08 * math.sin(2 * state.phase)
		+ breath * (0.012 + 0.01 * state.exertion)
		- state.sit * BosunMotion.SIT_DROP
		- sw * (0.85 - 0.05 * math.sin(2 * state.paddle))
	local sitPitch = state.sit * BosunMotion.SIT_PITCH
	local hip = BosunMotion.SIT_PIVOT
	local root = CFrame.new(0, rootY, 0)
		* CFrame.new(hip)
		* CFrame.Angles(sitPitch, 0, 0)
		* CFrame.new(-hip)
		* CFrame.fromEulerAnglesYXZ(rootPitch, 0, rootRoll)

	-- the head keeps the gaze level against the rocking, the sit's tilt and the swim's nose-up
	local headPitch = state.pitch - 0.6 * gaitPitch - sitPitch * 0.8 - sw * math.rad(5)
	local neck = CFrame.fromEulerAnglesYXZ(headPitch, state.yaw, shakeHead)
	-- panting after a run: the mouth opens with each breath
	local jawOpen = math.rad(3) + math.rad(12) * state.exertion * (0.5 + 0.5 * breath)
	local jaw = CFrame.Angles(-jawOpen, 0, 0)

	local pose: Pose = { Root = root, Neck = neck, Jaw = jaw }

	-- legs: a trot in diagonal pairs, the sit, the paddle
	local sit = state.sit
	for i, leg in BosunMotion.LEGS do
		local front = i <= 2
		local offset = if i == 1 or i == 4 then 0 else math.pi
		local p = state.phase + offset
		local swing = g * BosunMotion.LEG_SWING * math.sin(p)
		local knee = g * BosunMotion.KNEE_LIFT * math.max(0, math.cos(p))
		local q = state.paddle + offset
		local upper, lower
		if front then
			-- upright under the shoulders when he sits; a reaching paddle when he swims
			upper = swing * (1 - sw) - sitPitch + sw * math.rad(35) * math.sin(q)
			lower = -knee * (1 - sw) - sw * math.rad(30) * (0.5 + 0.5 * math.cos(q))
		else
			-- folded under him when he sits: thigh forward, shin back along the ground
			upper = (swing * (1 - sw) + sw * math.rad(20) * math.sin(q)) * (1 - sit)
				+ sit * math.rad(35)
			lower = (-knee * (1 - sw) - sw * math.rad(15) * (0.5 + 0.5 * math.cos(q))) * (1 - sit)
				- sit * math.rad(150)
		end
		pose[leg .. "Upper"] = CFrame.Angles(upper, 0, 0)
		pose[leg .. "Lower"] = CFrame.Angles(lower, 0, 0)
	end

	-- tail: moods set the carriage, the wag rides on top
	local tiredTarget = math.clamp((state.exertion - 0.25) / 0.5, 0, 1) * (1 - state.gait)
	state.tired = approach(state.tired, tiredTarget, 1.5, dt)
	local wetOut = math.clamp(((input.wetness or 0) - 0.3) / 0.4, 0, 1) * (1 - sw)
	local tuckTarget = math.max(wetOut, math.clamp(input.cold or 0, 0, 1)) * (1 - 0.6 * excited)
	state.tuck = approach(state.tuck, tuckTarget, 2, dt)
	local tuck, tired = state.tuck, state.tired
	local liftTarget = BosunMotion.TAIL_RAISE * state.wag * (1 - sit) * (1 - tuck)
		+ BosunMotion.TAIL_SWIM_RAISE * sw
		+ math.rad(6) * g -- carried a little higher on the move
		- BosunMotion.TAIL_SIT_DROP * sit
		- BosunMotion.TAIL_TIRED_DROP * tired * (1 - sw)
		- BosunMotion.TAIL_TUCK * tuck
	state.tailLift = approach(state.tailLift, liftTarget, 5, dt)
	-- still when he sits, is tired or tucked; a slow rudder sway when swimming; swings with the stride
	local wagAmp = BosunMotion.TAIL_WAG
		* state.wag
		* (1 - 0.85 * sit)
		* (1 - 0.8 * tired)
		* (1 - 0.9 * tuck)
		* (1 - 0.7 * sw)
	local tailYaw = math.sin(state.wagPhase) * wagAmp
		+ sw * math.rad(7) * math.sin(state.paddle + 1.2)
		+ g * math.rad(5) * math.sin(state.phase + 1.8) * (1 - tuck)
		- shakeRoll * 1.6 -- whips with the shake
	pose.Tail1 = CFrame.fromEulerAnglesYXZ(
		-state.tailLift,
		tailYaw,
		-tailYaw * 0.25 -- the sweep rolls the tip slightly
	)
	-- the tip follows the wag a beat late and curls up a little more when carried high
	local tipYaw = math.sin(state.wagPhase - 0.9) * wagAmp * 0.8
		+ sw * math.rad(5) * math.sin(state.paddle)
	pose.Tail2 = CFrame.fromEulerAnglesYXZ(-0.35 * state.tailLift, tipYaw, 0)
	return pose
end

return BosunMotion
