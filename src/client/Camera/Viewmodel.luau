--!strict
-- Viewmodel: the first-person arms (greybox, realistically proportioned: 1 m = 3 studs) in a
-- yellow drysuit with SOLAS tape at the cuffs, latex wrist seals and black neoprene gloves.
-- Both arms are solved by two-bone IK from the shoulders to the wrist targets of the current
-- action (ViewmodelActions). Only drawn in first person (CameraController calls setEnabled).
--
-- API (for mechanics: require(script.Parent.Parent.Camera.Viewmodel) from src/client/Mechanics):
--   Viewmodel.playAction(name, opts?) -> Handle
--       name: any key of ViewmodelActions.Defs (listed in Viewmodel.Actions), e.g. "throw",
--       "haul", "grab", "radio", "cpr", "point", "steer", "wave_off", "reach_casualty"
--       opts: { speed: number?, loop: boolean?, onDone: (() -> ())? }
--       Handle: { name, duration, stop: () -> (), isDone: () -> boolean, wait: () -> () }
--       Looping actions (haul, cpr, steer) run until stop() or another playAction.
--   Viewmodel.stopAction()                  back to the base pose
--   Viewmodel.setBasePose(name?)            "steer" on the jet ski; nil = arms down out of view
--   Viewmodel.setSteer(x)                   -1..1 turns the handlebars in the steer pose
--   Viewmodel.isPlaying(): boolean, Viewmodel.current(): string?
--   Viewmodel.setEnabled(on)  (CameraController: true only in a first-person mode)
--   Viewmodel.update(dt, cameraCFrame)      (CameraController, every frame)
local Workspace = game:GetService("Workspace")

local Actions = require(script.Parent.ViewmodelActions)
local CameraMath = require(script.Parent.CameraMath)

export type Handle = {
	name: string,
	duration: number,
	stop: () -> (),
	isDone: () -> boolean,
	wait: () -> (),
}

local Viewmodel = {}
Viewmodel.Actions = Actions.Names

-- proportions (studs): upper arm 0.31 m, forearm 0.27 m, hand 0.19 m, shoulders 0.2 m off centre
local UPPER, FORE = 0.93, 0.81
local SHOULDER_R = Vector3.new(0.6, -0.75, 0.15)
local SHOULDER_L = Vector3.new(-0.6, -0.75, 0.15)
local SLEEVE_W, FORE_W = 0.36, 0.3
local HAND_L, HAND_W, HAND_T = 0.57, 0.27, 0.12

local DRYSUIT = Color3.fromRGB(236, 190, 28)
local TAPE = Color3.fromRGB(200, 204, 208)
local SEAL = Color3.fromRGB(150, 110, 70)
local GLOVE = Color3.fromRGB(28, 30, 33)

type Arm = {
	upper: BasePart,
	fore: BasePart,
	tape: BasePart,
	seal: BasePart,
	palm: BasePart,
	fingers: BasePart,
	thumb: BasePart,
	shoulder: Vector3,
	side: number,
}

-- where each prop sits: which hand (1 right, 2 left) and its offset from that palm
local PROP_HOLD: { [string]: { arm: number, offset: CFrame } } = {
	throwbag = { arm = 1, offset = CFrame.new(0, -0.3, -0.1) },
	radio = {
		arm = 2,
		offset = CFrame.new(0.05, 0.05, -0.05) * CFrame.Angles(math.rad(80), 0, 0),
	},
	torch = { arm = 1, offset = CFrame.new(0, 0.02, -0.12) },
	tube = { arm = 1, offset = CFrame.new(0, -0.05, -0.1) * CFrame.Angles(0, math.rad(80), 0) },
	marker = { arm = 1, offset = CFrame.new(0, -0.2, -0.12) },
}

local rig: Model? = nil
local arms: { Arm } = {}
local props: { [string]: BasePart } = {}
local enabled = false
local blend = 0 -- 0 hidden (arms at rest) .. 1 posed

local active: {
	name: string,
	def: Actions.Action,
	t: number,
	speed: number,
	loop: boolean,
	onDone: (() -> ())?,
	done: boolean,
}? =
	nil
local basePose: string? = nil
local steer = 0
local smoothR, smoothL = Actions.REST_R, Actions.REST_L

local function part(name: string, size: Vector3, color: Color3, material: Enum.Material): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = rig
	return p
end

local function rounded(p: BasePart)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
end

local function build()
	if rig and rig.Parent then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Viewmodel"
	rig = model
	arms = {}
	for _, side in { 1, -1 } do
		local arm: Arm = {
			upper = part(
				"UpperSleeve",
				Vector3.new(SLEEVE_W, SLEEVE_W, UPPER),
				DRYSUIT,
				Enum.Material.Fabric
			),
			fore = part(
				"ForeSleeve",
				Vector3.new(FORE_W, FORE_W, FORE),
				DRYSUIT,
				Enum.Material.Fabric
			),
			tape = part(
				"SolasTape",
				Vector3.new(FORE_W + 0.02, FORE_W + 0.02, 0.1),
				TAPE,
				Enum.Material.Foil
			),
			seal = part(
				"WristSeal",
				Vector3.new(0.2, 0.2, 0.12),
				SEAL,
				Enum.Material.SmoothPlastic
			),
			palm = part(
				"Glove",
				Vector3.new(HAND_W, HAND_T, HAND_L * 0.55),
				GLOVE,
				Enum.Material.Fabric
			),
			fingers = part(
				"Fingers",
				Vector3.new(HAND_W * 0.95, HAND_T * 0.9, HAND_L * 0.45),
				GLOVE,
				Enum.Material.Fabric
			),
			thumb = part("Thumb", Vector3.new(0.08, 0.08, 0.2), GLOVE, Enum.Material.Fabric),
			shoulder = if side == 1 then SHOULDER_R else SHOULDER_L,
			side = side,
		}
		rounded(arm.upper)
		rounded(arm.fore)
		table.insert(arms, arm)
	end
	props.throwbag = part(
		"ThrowBag",
		Vector3.new(0.45, 0.6, 0.45),
		Color3.fromRGB(200, 30, 30),
		Enum.Material.Fabric
	)
	props.radio = part(
		"HandheldVHF",
		Vector3.new(0.2, 0.42, 0.11),
		Color3.fromRGB(35, 35, 38),
		Enum.Material.SmoothPlastic
	)
	-- waterproof torch (yellow body, lens forward) with a real beam for night searches
	local torch = part(
		"Torch",
		Vector3.new(0.17, 0.17, 0.62),
		Color3.fromRGB(240, 196, 20),
		Enum.Material.SmoothPlastic
	)
	local beam = Instance.new("SpotLight")
	beam.Face = Enum.NormalId.Front
	beam.Angle = 35
	beam.Range = 45
	beam.Brightness = 3
	beam.Color = Color3.fromRGB(255, 244, 220)
	beam.Enabled = false
	beam.Parent = torch
	props.torch = torch
	-- rescue tube (closed-cell foam, rescue orange), held across the hand
	props.tube = part(
		"RescueTube",
		Vector3.new(0.3, 0.3, 1.9),
		Color3.fromRGB(235, 70, 25),
		Enum.Material.SmoothPlastic
	)
	rounded(props.tube)
	-- orange smoke / marker canister
	props.marker = part(
		"Marker",
		Vector3.new(0.26, 0.5, 0.26),
		Color3.fromRGB(250, 120, 20),
		Enum.Material.SmoothPlastic
	)
	model.Parent = nil
end

local function segment(p: BasePart, a: Vector3, b: Vector3, up: Vector3)
	local len = (b - a).Magnitude
	p.Size = Vector3.new(p.Size.X, p.Size.Y, math.max(len, 0.05))
	p.CFrame = CFrame.lookAt((a + b) * 0.5, b, up)
end

local function poseArm(arm: Arm, cam: CFrame, wristLocal: Vector3, grip: number)
	local shoulder = cam:PointToWorldSpace(arm.shoulder)
	local target = cam:PointToWorldSpace(wristLocal)
	-- elbows point down and out, as a real arm hangs
	local pole = cam:PointToWorldSpace(arm.shoulder + Vector3.new(arm.side * 0.9, -1.6, 0.4))
	local elbow, wrist = CameraMath.twoBoneIK(shoulder, target, UPPER, FORE, pole)
	local up = cam.UpVector
	segment(arm.upper, shoulder, elbow, up)
	segment(arm.fore, elbow, wrist, up)
	local fdir = (wrist - elbow).Unit
	arm.tape.CFrame = CFrame.lookAt(wrist - fdir * 0.18, wrist, up)
	arm.seal.CFrame = CFrame.lookAt(wrist - fdir * 0.02, wrist + fdir, up)
	-- the hand continues the forearm, palm down, with the fingers curling by grip
	local hand = CFrame.lookAt(wrist, wrist + fdir, up)
	local palmLen = arm.palm.Size.Z
	arm.palm.CFrame = hand * CFrame.new(0, 0, -palmLen * 0.5)
	local curl = math.rad(10 + 80 * grip)
	arm.fingers.CFrame = hand
		* CFrame.new(0, 0, -palmLen)
		* CFrame.Angles(-curl, 0, 0)
		* CFrame.new(0, 0, -arm.fingers.Size.Z * 0.5)
	arm.thumb.CFrame = hand
		* CFrame.new(-arm.side * HAND_W * 0.5, -0.02, -palmLen * 0.35)
		* CFrame.Angles(-curl * 0.5, -arm.side * math.rad(35), 0)
		* CFrame.new(0, 0, -0.1)
end

function Viewmodel.setEnabled(on: boolean)
	if on == enabled then
		return
	end
	enabled = on
	build()
	if not on and rig then
		rig.Parent = nil
		blend = 0
	end
end

function Viewmodel.isEnabled(): boolean
	return enabled
end

function Viewmodel.playAction(
	name: string,
	opts: { speed: number?, loop: boolean?, onDone: (() -> ())? }?
): Handle
	local def = Actions.Defs[name]
	local o: { speed: number?, loop: boolean?, onDone: (() -> ())? } = opts or {}
	if not def then
		warn(`[Viewmodel] unknown action {name}`)
		def = Actions.Defs.point
	end
	if active and active.onDone and not active.done then
		active.done = true
		task.spawn(active.onDone :: () -> ())
	end
	local entry = {
		name = name,
		def = def,
		t = 0,
		speed = math.max(o.speed or 1, 0.05),
		loop = if o.loop ~= nil then o.loop else def.loop == true,
		onDone = o.onDone,
		done = false,
	}
	active = entry
	local handle: Handle = {
		name = name,
		duration = def.duration / entry.speed,
		stop = function()
			if active == entry then
				active = nil
			end
			if not entry.done then
				entry.done = true
				if entry.onDone then
					task.spawn(entry.onDone :: () -> ())
				end
			end
		end,
		isDone = function()
			return entry.done
		end,
		wait = function()
			while not entry.done do
				task.wait()
			end
		end,
	}
	return handle
end

function Viewmodel.stopAction()
	if active then
		local a = active
		active = nil
		if not a.done then
			a.done = true
			if a.onDone then
				task.spawn(a.onDone :: () -> ())
			end
		end
	end
end

function Viewmodel.setBasePose(name: string?)
	basePose = if name and Actions.Defs[name] then name else nil
end

function Viewmodel.setSteer(x: number)
	steer = math.clamp(x, -1, 1)
end

function Viewmodel.isPlaying(): boolean
	return active ~= nil
end

function Viewmodel.current(): string?
	return if active then active.name else basePose
end

-- Advances the current action and poses the rig in front of `cam`.
function Viewmodel.update(dt: number, cam: CFrame)
	local r, l, grip, prop = Actions.REST_R, Actions.REST_L, 0, ""
	local a = active
	if a then
		a.t += dt * a.speed
		r, l, grip, prop = Actions.sample(a.def, a.t)
		if not a.loop and a.t >= a.def.duration then
			active = nil
			if not a.done then
				a.done = true
				if a.onDone then
					task.spawn(a.onDone :: () -> ())
				end
			end
		end
	elseif basePose then
		r, l, grip = Actions.sample(Actions.Defs[basePose], os.clock())
		if basePose == "steer" then
			-- turning the bars: the outside hand pushes forward, the inside one pulls back
			local push = steer * 0.22
			r += Vector3.new(0, -steer * 0.05, push)
			l += Vector3.new(0, steer * 0.05, -push)
		end
	end
	local wantVisible = enabled and (a ~= nil or basePose ~= nil)
	blend = CameraMath.damp(blend, if wantVisible then 1 else 0, 0.08, dt)
	if not enabled or not rig then
		return
	end
	if blend < 0.02 and not wantVisible then
		rig.Parent = nil
		return
	end
	-- arms rise from below the frame; the smoothing stands in for muscle lag
	local tr = Actions.REST_R:Lerp(r, blend)
	local tl = Actions.REST_L:Lerp(l, blend)
	smoothR = CameraMath.damp(smoothR, tr, 0.035, dt)
	smoothL = CameraMath.damp(smoothL, tl, 0.035, dt)
	rig.Parent = Workspace.CurrentCamera
	poseArm(arms[1], cam, smoothR, grip)
	poseArm(arms[2], cam, smoothL, grip)
	for name, p in props do
		local hold = PROP_HOLD[name]
		local shown = prop == name and hold ~= nil
		p.Transparency = if shown then 0 else 1
		local light = p:FindFirstChildOfClass("SpotLight")
		if light then
			light.Enabled = shown
		end
		if shown and hold then
			p.CFrame = arms[hold.arm].palm.CFrame * hold.offset
		end
	end
end

return Viewmodel
