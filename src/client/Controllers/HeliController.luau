--!strict
-- HeliController (docs/23 h, WP-6): flies the rescue helicopter (Heli/Flight) and spins every
-- helicopter's rotors (Heli/Builder). Inert until the local player sits in the DriverSeat of a model
-- tagged "Heli" whose VehicleId has a Flight spec.
--
-- 1. Flying. Like BoatController, the server hands the pilot network ownership; every PreSimulation
--    we step Heli/Flight and set HullRoot's LinearVelocity "Lift" and AlignOrientation "Attitude".
--    Forward and yaw come from the PlayerModule move vector (W/S + A/D, arrows, left stick, touch
--    thumbstick), not the seat's ThrottleFloat, because the default vehicle controls put the
--    gamepad triggers on the throttle and here they climb and descend:
--      up      E / R2 / touch up chevron          down     Q / L2 / touch down chevron
--      strafe  Z, C / D-pad left, right           (Space / A gets out: VehicleExitController)
--    On a touch device the drive pad (TouchDriveController) flies it instead: GO / BRAKE forward and back, LEFT /
--    RIGHT yaw, the teal arrows climb and descend (the stick and the chevron buttons are gone then).
--    Hands off = a level hover with a slow sway. The floor is the ground under the skids, or the sea plus
--    Flight.WATER_CLEARANCE; gentle wind drift comes from Weather. A parked heli spins its rotors up before
--    the controls bite (Flight.power). Winch: hands off near a survivor with room, the idle axes ease it over
--    them and down into the winch band (Heli/Winch.assist; the boats' helm nudge).
-- 2. Rotors. Every heli's RotorJoint / TailRotorJoint Transform spins up while its DriverSeat is
--    taken or its engine runs (EngineRunning: landing itself) and spools down after (visual, per client).
--    The rotor loop (Heli_Rotor) follows the spool in pitch and volume; low over the sea the rotor wash
--    plays VFX `heli_downwash` under it with a water bed (Hull_Wake) that swells as it comes down.
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioConfig = require(Shared:WaitForChild("Config"):WaitForChild("AudioConfig"))
local AudioController = require(script.Parent.AudioController)
local Board = require(Shared:WaitForChild("Ops"):WaitForChild("Board"))
local Flight = require(Shared:WaitForChild("Heli"):WaitForChild("Flight"))
local Glyph = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Glyph"))
local RescueRun = require(Shared:WaitForChild("RescueRun"))
local Simulator = require(Shared:WaitForChild("Boat"):WaitForChild("Simulator"))
local TouchDriveController = require(script.Parent.TouchDriveController)
local VFXKit = require(script.Parent.Parent:WaitForChild("VFX"):WaitForChild("VFXKit"))
local Weather = require(Shared:WaitForChild("Weather"))
local Winch = require(Shared:WaitForChild("Heli"):WaitForChild("Winch"))

local TAG = "Heli"
local ROTOR_SPEED = math.pi * 2 * 5 -- rad/s at full spool (visual; any faster strobes)
local SPOOL_TIME = 2 -- s from still to full
local RAY_DEPTH = 600 -- studs
local AIRBORNE_GAP = 4 -- studs over the floor (ground, or the sea's hover height) that count as mid-air
local SOUND_RANGE = 320 -- studs: the rotor loop's roll-off
local WASH_HEIGHT = 40 -- studs from the skids to the sea under which the rotor wash shows -- tune
local WASH_EVERY = 0.25 -- s between downwash bursts

-- action -> keys; Up and Down also get a touch button
local AXES: { [string]: { Enum.KeyCode } } = {
	HeliUp = { Enum.KeyCode.E, Enum.KeyCode.ButtonR2 },
	HeliDown = { Enum.KeyCode.Q, Enum.KeyCode.ButtonL2 },
	HeliLeft = { Enum.KeyCode.Z, Enum.KeyCode.DPadLeft },
	HeliRight = { Enum.KeyCode.C, Enum.KeyCode.DPadRight },
}

local HeliController = {}

local localPlayer = Players.LocalPlayer
local held: { [string]: number } = { HeliUp = 0, HeliDown = 0, HeliLeft = 0, HeliRight = 0 }
local flying: Model? = nil
local state: Flight.State? = nil
local spool: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local angle: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local rotorSound: { [Model]: Sound } = setmetatable({}, { __mode = "k" }) :: any
local washSound: { [Model]: Sound } = setmetatable({}, { __mode = "k" }) :: any
local washAt: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local controlModule: any = nil
local function moveVector(): Vector3
	if controlModule == nil then
		local ps = localPlayer:FindFirstChild("PlayerScripts")
		local pm = ps and ps:FindFirstChild("PlayerModule")
		local cmod = pm and pm:FindFirstChild("ControlModule")
		if not cmod then
			return Vector3.zero -- not loaded yet: try again next frame
		end
		local ok, cm = pcall(require :: any, cmod)
		controlModule = if ok and type(cm) == "table" then cm else false
	end
	return if controlModule then controlModule:GetMoveVector() else Vector3.zero
end

-- The heli whose DriverSeat we sit in, with its spec.
local function piloted(): (Model?, Flight.Spec?)
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local model = seat and seat.Name == "DriverSeat" and seat.Parent
	if model and model:IsA("Model") and model:HasTag(TAG) then
		local spec = Flight.spec(model:GetAttribute("VehicleId"))
		if spec then
			return model, spec
		end
	end
	return nil, nil
end

local function onAxis(name: string, inputState: Enum.UserInputState, input: InputObject)
	local on = inputState == Enum.UserInputState.Begin or inputState == Enum.UserInputState.Change
	local trigger = input.KeyCode == Enum.KeyCode.ButtonR2 or input.KeyCode == Enum.KeyCode.ButtonL2
	held[name] = if not on then 0 elseif trigger then input.Position.Z else 1
	return Enum.ContextActionResult.Sink
end

-- A chevron of two pills on the touch button (no text, docs: show, don't tell).
local function chevron(button: Instance, up: boolean)
	local box = Instance.new("Frame")
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.Size = UDim2.fromScale(0.6, 0.6)
	box.BackgroundTransparency = 1
	box.Parent = button
	local tilt = if up then 45 else -45
	local white = Color3.new(1, 1, 1)
	Glyph.bar(box, Vector2.new(0.5, 0.16), Vector2.new(0.36, 0.5), -tilt, white)
	Glyph.bar(box, Vector2.new(0.5, 0.16), Vector2.new(0.64, 0.5), tilt, white)
end

local function bindControls(on: boolean)
	for name, keys in AXES do
		held[name] = 0
		if on then
			local touch = (name == "HeliUp" or name == "HeliDown") and not TouchDriveController.on()
			ContextActionService:BindAction(name, onAxis, touch, table.unpack(keys))
			local button = touch and ContextActionService:GetButton(name)
			if button then
				ContextActionService:SetPosition(
					name,
					UDim2.new(1, -170, 1, if name == "HeliUp" then -230 else -150)
				)
				chevron(button, name == "HeliUp")
			end
		else
			ContextActionService:UnbindAction(name)
		end
	end
end

local function setFlying(root: BasePart, on: boolean)
	local lift = root:FindFirstChild("Lift")
	local attitude = root:FindFirstChild("Attitude")
	if lift and lift:IsA("LinearVelocity") and attitude and attitude:IsA("AlignOrientation") then
		lift.Enabled = on
		attitude.Enabled = on
	end
end

-- On leaving the seat the constraints switch off here; the server takes the empty heli over and
-- lands it (VehicleService).
local function stopFlying()
	local model = flying :: Model
	model:SetAttribute("Airborne", nil)
	if model.PrimaryPart then
		setFlying(model.PrimaryPart, false)
	end
	flying, state = nil, nil
	bindControls(false)
end

-- The first solid thing straight down from p (not a heli, not people), else nil.
local function groundY(model: Model, p: Vector3): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { model }
	for _, plr in Players:GetPlayers() do
		if plr.Character then
			table.insert(ignore, plr.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local hit = Workspace:Raycast(p, Vector3.new(0, -RAY_DEPTH, 0), params)
	return hit and hit.Position.Y
end

local function floorY(model: Model, root: BasePart, spec: Flight.Spec, now: number): number
	local p = root.Position
	return Flight.floor(groundY(model, p), Simulator.waterHeight(p.X, p.Z, now), spec)
end

-- The nearest survivor still in the water (PickupRingController's rule) inside Winch.ASSIST, else nil.
local function survivorNear(from: Vector3): Vector3?
	local props = Workspace:FindFirstChild("CallProps")
	local best, bestD = nil, Winch.ASSIST
	for _, m in if props then props:GetChildren() else {} do
		local part = m:IsA("Model") and m.PrimaryPart
		if
			part
			and m.Name == "Victim"
			and m:GetAttribute("Survivor") == true
			and m:GetAttribute("OnVehicle") == nil
		then
			local d = Vector2.new(part.Position.X - from.X, part.Position.Z - from.Z).Magnitude
			if d <= bestD then
				best, bestD = part.Position, d
			end
		end
	end
	return best
end

local function fly(model: Model, spec: Flight.Spec, dt: number)
	local root = model.PrimaryPart
	if not root then
		return
	end
	if flying ~= model then
		if flying then
			stopFlying()
		end
		flying = model
		state = Flight.new(Flight.headingOf(root.CFrame.LookVector), root.AssemblyLinearVelocity)
		setFlying(root, true)
		bindControls(true)
	end
	local s = state :: Flight.State
	local move = moveVector()
	local now = Workspace:GetServerTimeNow()
	local floor = floorY(model, root, spec, now)
	-- local only: no stepping out mid-air (VehicleExitController, OpsController)
	local airborne = root.Position.Y > floor + AIRBORNE_GAP
	model:SetAttribute("Airborne", airborne)
	local input: Flight.Input = {
		forward = math.clamp(-move.Z + TouchDriveController.throttle(), -1, 1),
		strafe = held.HeliRight - held.HeliLeft,
		yaw = math.clamp(move.X + TouchDriveController.steer(), -1, 1),
		lift = math.clamp(held.HeliUp - held.HeliDown + TouchDriveController.lift(), -1, 1),
	}
	local survivor = if airborne and Board.hasRoom(model) then survivorNear(root.Position) else nil
	if survivor then
		local f, st, l = Winch.assist(survivor - root.Position, s.heading, spec)
		local function idle(v: number): boolean
			return math.abs(v) < 0.05
		end
		input.forward = if idle(input.forward) then f else input.forward
		input.strafe = if idle(input.strafe) then st else input.strafe
		input.lift = if idle(input.lift) then l else input.lift
	end
	local power = Flight.power(spool[model] or 0)
	input.forward *= power
	input.strafe *= power
	input.yaw *= power
	input.lift *= power
	input.boost =
		RescueRun.boostAt(model:GetAttribute("PickupBoostUntil"), Workspace:GetServerTimeNow())
	Flight.step(
		s,
		input,
		spec,
		root.Position.Y,
		floor,
		Flight.wind(Weather.getWindDirection(), Weather.getIntensity(now)),
		dt
	)
	local lift = root:FindFirstChild("Lift") :: LinearVelocity?
	local attitude = root:FindFirstChild("Attitude") :: AlignOrientation?
	if lift and attitude then
		lift.MaxForce = root.AssemblyMass * (Workspace.Gravity + spec.accel * 2)
		lift.VectorVelocity = s.velocity + Vector3.yAxis * (if airborne then Flight.bob(now) else 0)
		attitude.CFrame = Flight.attitude(s, spec)
	end
end

local function loop(name: string, parent: Instance): Sound
	local snd = AudioController.newSound(name, parent, true)
	snd.RollOffMinDistance = 15
	snd.RollOffMaxDistance = SOUND_RANGE
	snd:Play()
	return snd
end

local function base(name: string): number
	local clip = AudioConfig.Clips[name]
	return if clip then clip.volume else 0.5
end

-- The rotor loop rides the spool (a rising whine on spin-up, a falling one on spool-down); a climb leans on it.
-- Low over the sea: a downwash burst every WASH_EVERY and a water bed, stronger the lower it hovers.
local function rotorFx(model: Model, root: BasePart, s: number, now: number)
	local snd = rotorSound[model]
	if s <= 0 then
		for _, t in { rotorSound, washSound } do
			if t[model] then
				t[model]:Destroy()
				t[model] = nil
			end
		end
		return
	end
	snd = snd or loop("Heli_Rotor", root)
	rotorSound[model] = snd
	local spec = Flight.spec(model:GetAttribute("VehicleId"))
	local climb = if model == flying
			and state
			and spec
		then math.clamp(state.velocity.Y / spec.climbSpeed, 0, 1)
		else 0
	snd.Volume = base("Heli_Rotor") * s ^ 0.6 * (0.85 + 0.25 * climb)
	snd.PlaybackSpeed = 0.5 + 0.5 * s + 0.06 * climb

	if not spec or now < (washAt[model] or 0) then
		return
	end
	washAt[model] = now + WASH_EVERY
	local p = root.Position
	local waterY = Simulator.waterHeight(p.X, p.Z, Workspace:GetServerTimeNow())
	local ground = groundY(model, p)
	local h = p.Y - spec.skid - waterY
	local k = if ground and ground > waterY then 0 else s * math.clamp(1 - h / WASH_HEIGHT, 0, 1)
	if k > 0.05 then
		VFXKit.play(
			"heli_downwash",
			CFrame.new(p.X, waterY + 0.1, p.Z),
			{ scale = 0.4 + 0.6 * k, radius = 4 + 5 * k, still = true }
		)
	end
	if k > 0.05 and not washSound[model] then
		washSound[model] = loop("Hull_Wake", root)
	end
	local wash = washSound[model]
	if wash then
		wash.Volume = base("Hull_Wake") * k
	end
end

local function spinRotors(dt: number)
	for _, model in CollectionService:GetTagged(TAG) do
		local seat = model:FindFirstChild("DriverSeat")
		-- an empty heli keeps its rotors turning while it lands itself (Craft.idle stops the engine once down)
		local on = seat and seat:IsA("VehicleSeat") and seat.Occupant ~= nil
			or model:GetAttribute("EngineRunning") == true
		local s = spool[model] or 0
		s = math.clamp(s + (if on then dt else -dt) / SPOOL_TIME, 0, 1)
		spool[model] = s
		if model.PrimaryPart then
			rotorFx(model, model.PrimaryPart, s, os.clock())
		end
		if s > 0 then
			local a = ((angle[model] or 0) + s * ROTOR_SPEED * dt) % (math.pi * 2)
			angle[model] = a
			local body = model:FindFirstChild("Body")
			local main = body and body:FindFirstChild("RotorJoint")
			local tail = body and body:FindFirstChild("TailRotorJoint")
			if main and main:IsA("Motor6D") then
				main.Transform = CFrame.Angles(0, a, 0)
			end
			if tail and tail:IsA("Motor6D") then
				tail.Transform = CFrame.Angles(0, -a * 3, 0)
			end
		end
	end
end

local function step(dt: number)
	local model, spec = piloted()
	if model and spec then
		fly(model, spec, dt)
	elseif flying then
		stopFlying()
	end
	spinRotors(dt)
end

-- The craft jumped (Go back): fly on from the new pose, not the old heading and speed.
function HeliController.Landed()
	local root = flying and flying.PrimaryPart
	if root then
		state = Flight.new(Flight.headingOf(root.CFrame.LookVector), Vector3.zero)
	end
end

function HeliController.Start()
	RunService.PreSimulation:Connect(step)
end

return HeliController
