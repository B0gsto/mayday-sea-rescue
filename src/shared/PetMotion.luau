--!strict
-- PetMotion: the following pet's procedural body language (item 14, feel review 2026-10-31), pure logic
-- (tests/PetMotion.spec.luau). The pets are the rigid M_Ani_<species> meshes (no joints), so the pose is
-- a rig-space delta per part around a pivot, applied by WildlifeRig.setCFrame's pose callback:
--   root   the whole animal: the species gait (seal galumph, bird waddle, otter bound, turtle crawl),
--          idle breathing, the swim's roll, the rescue cheer's double hop;
--   head   Head and everything on it (eyes, beak, snout, ears), pivot at the neck: looks at the player,
--          bobs with the step, droops asleep;
--   flap   Wing / Flipper, pivot at the shoulder: flap, paddle, tucked;
--   step   Foot / Leg / Paw: lifted and swung with the stride, left and right in turn;
--   tail   Tail, pivot at its root: wag.
local PetMotion = {}

export type Mode = "walk" | "swim" | "ride" | "nap"
export type State = {
	species: string,
	phase: number,
	gait: number,
	look: number,
	swim: number,
	clock: number,
}
export type Input = {
	dt: number,
	speed: number, -- studs per second over the ground
	mode: Mode,
	lookYaw: number?, -- head turn wanted (rad, + = to the pet's left), nil = straight ahead
	cheer: number?, -- 0..1 through the rescue celebration
	greet: number?, -- 0..1 through the spawn hello
}
export type Pose = {
	root: CFrame,
	headYaw: number,
	headPitch: number,
	headTilt: number,
	flapL: number, -- + raises the wing / flipper
	flapR: number,
	stroke: number, -- paddle sweep (rad about Y), + = back
	stepL: number, -- -1..1 stride position (+ = forward), lift on the swing half
	stepR: number,
	tail: number,
}

-- hop/bob in studs at rig scale 1 (the pet rigs are ~2 studs tall); angles in radians
local GAIT = {
	SealPup = { stride = 2.2, hop = 0.16, pitch = 0.1, roll = 0.03, sway = 0.02, flap = 0.35 },
	Puffin = { stride = 1.1, hop = 0.07, pitch = 0.0, roll = 0.13, sway = 0.08, flap = 0.18 },
	Gull = { stride = 1.0, hop = 0.05, pitch = 0.0, roll = 0.09, sway = 0.06, flap = 0.08 },
	Otter = { stride = 2.6, hop = 0.3, pitch = 0.14, roll = 0.02, sway = 0.0, flap = 0.0 },
	Turtle = { stride = 1.6, hop = 0.0, pitch = 0.02, roll = 0.03, sway = 0.07, flap = 0.4 },
}
PetMotion.GAIT = GAIT
PetMotion.RUN_SPEED = 14 -- studs/s at full gait
PetMotion.MAX_LOOK = math.rad(45)
PetMotion.SINK = { Gull = 0.12 } -- swim depth as a share of the pet's height (else SWIM_SINK)
PetMotion.SWIM_SINK = 0.42

local HEAD = {
	Head = true,
	Snout = true,
	Nose = true,
	Eye = true,
	Glint = true,
	Beak = true,
	Face = true,
	Muzzle = true,
	Ear = true,
}
local FLAP = { Wing = true, Flipper = true }
local STEP = { Foot = true, Leg = true, Paw = true }

local function approach(current: number, target: number, rate: number, dt: number): number
	return current + (target - current) * (1 - math.exp(-rate * dt))
end

function PetMotion.new(species: string): State
	return { species = species, phase = 0, gait = 0, look = 0, swim = 0, clock = 0 }
end

function PetMotion.sink(species: string): number
	return PetMotion.SINK[species] or PetMotion.SWIM_SINK
end

function PetMotion.step(state: State, input: Input): Pose
	local dt = math.clamp(input.dt, 0, 0.1)
	local g = GAIT[state.species] or GAIT.SealPup
	local t = state.clock + dt
	state.clock = t
	local mode = input.mode
	local moving = if mode == "walk" then math.clamp(input.speed / PetMotion.RUN_SPEED, 0, 1) else 0
	state.gait = approach(state.gait, moving, 8, dt)
	state.swim = approach(state.swim, if mode == "swim" then 1 else 0, 5, dt)
	-- the stride follows the ground covered so feet don't skate; a floor keeps a slow walk stepping
	state.phase = (
		state.phase + math.max(input.speed, 3 * state.gait) * dt / g.stride * math.pi * 2
	) % (math.pi * 2)
	local lookWanted = math.clamp(input.lookYaw or 0, -PetMotion.MAX_LOOK, PetMotion.MAX_LOOK)
	state.look = approach(state.look, lookWanted * (1 - state.gait), 6, dt)

	local gait, swim, ph = state.gait, state.swim, state.phase
	local s = math.sin(ph)
	local beat = math.abs(s) -- two beats per stride (one per foot)
	local napping = mode == "nap"

	local breathe = math.sin(t * (if napping then 1.4 else 2.2))
		* (if napping then 0.025 else 0.018)
	local y = beat * g.hop * gait + breathe * (1 - gait)
	local pitch = math.cos(ph * 2) * g.pitch * gait
	local roll = s * g.roll * gait + math.sin(t * 1.6) * 0.06 * swim
	local yaw = s * g.sway * gait
	local headPitch = (if napping then -0.32 else 0) + 0.12 * swim - math.cos(ph * 2) * 0.06 * gait
	local headTilt = math.sin(t * 0.7) * 0.05 * (1 - gait)
	local paddle = math.sin(t * 5)
	local flap = g.flap * (beat * gait * 0.6 + paddle * 0.6 * swim)
	local stroke = paddle * 0.45 * swim
	local tail = math.sin(t * (if mode == "ride" then 3 else 4.5))
			* 0.18
			* (if napping then 0 else 1)
		+ s * 0.15 * gait

	local cheer = input.cheer
	if cheer then
		local env = math.sin(math.clamp(cheer, 0, 1) * math.pi)
		y += math.abs(math.sin(cheer * math.pi * 2)) * 0.6 -- two happy hops
		headPitch += 0.28 * env
		flap += math.sin(t * 22) * 0.55 * env + 0.35 * env
		tail += math.sin(t * 20) * 0.45 * env
		roll += math.sin(t * 14) * 0.08 * env
	end
	local greet = input.greet
	if greet then
		local env = math.sin(math.clamp(greet, 0, 1) * math.pi)
		y += env * 0.35
		headTilt += 0.3 * env
		tail += math.sin(t * 18) * 0.35 * env
	end

	return {
		root = CFrame.new(0, y, 0) * CFrame.Angles(pitch, yaw, roll),
		headYaw = state.look,
		headPitch = headPitch,
		headTilt = headTilt,
		flapL = flap,
		flapR = flap,
		stroke = stroke,
		stepL = s * gait,
		stepR = -s * gait,
		tail = tail,
	}
end

local function about(pivot: Vector3, rotation: CFrame): CFrame
	return CFrame.new(pivot) * rotation * CFrame.new(-pivot)
end

-- The rig-space delta for one part (name, rig-local offset, size), given the neck pivot.
-- k is the rig scale, so hops and steps grow with a bigger pet.
function PetMotion.partDelta(
	pose: Pose,
	name: string,
	offset: CFrame,
	size: Vector3,
	neck: Vector3,
	k: number
): CFrame
	local at = offset.Position
	local root = pose.root.Rotation + pose.root.Position * k
	if HEAD[name] then
		return root * about(neck, CFrame.Angles(pose.headPitch, pose.headYaw, pose.headTilt))
	end
	local side = if at.X < 0 then -1 else 1
	if FLAP[name] then
		local tall = size.Y > size.X
		local shoulder = at
			- Vector3.new(
				if tall then 0 else side * size.X * 0.45,
				if tall then -size.Y * 0.45 else 0,
				0
			)
		local up = if side < 0 then pose.flapL else pose.flapR
		local back = if at.Z > 0.3 * k then -1 else 1 -- turtle hind flippers row against the front pair
		return root * about(shoulder, CFrame.Angles(0, -side * pose.stroke * back, side * up))
	end
	if STEP[name] then
		local stride = if side < 0 then pose.stepL else pose.stepR
		local lift = math.max(0, stride) * 0.14 * k
		return root * CFrame.new(0, lift, -stride * 0.22 * k)
	end
	if name == "Tail" then
		return root * about(at + Vector3.new(0, 0, -size.Z * 0.45), CFrame.Angles(0, pose.tail, 0))
	end
	return root
end

return PetMotion
