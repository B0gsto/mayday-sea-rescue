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
--    Hands off = a level hover. The floor is the ground under the skids, or the sea plus
--    Flight.WATER_CLEARANCE; gentle wind drift comes from Weather.
-- 2. Rotors. Every heli's RotorJoint / TailRotorJoint Transform spins up while its DriverSeat is
--    taken and spools down when it is empty (visual, each client for itself).
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Flight = require(Shared:WaitForChild("Heli"):WaitForChild("Flight"))
local Glyph = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Glyph"))
local Simulator = require(Shared:WaitForChild("Boat"):WaitForChild("Simulator"))
local Weather = require(Shared:WaitForChild("Weather"))

local TAG = "Heli"
local ROTOR_SPEED = math.pi * 2 * 5 -- rad/s at full spool (visual; any faster strobes)
local SPOOL_TIME = 2 -- s from still to full
local RAY_DEPTH = 600 -- studs
local AIRBORNE_GAP = 4 -- studs over the floor (ground, or the sea's hover height) that count as mid-air

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
			local touch = name == "HeliUp" or name == "HeliDown"
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

local function floorY(model: Model, root: BasePart, spec: Flight.Spec, now: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { model }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local p = root.Position
	local hit = Workspace:Raycast(p, Vector3.new(0, -RAY_DEPTH, 0), params)
	return Flight.floor(hit and hit.Position.Y, Simulator.waterHeight(p.X, p.Z, now), spec)
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
	model:SetAttribute("Airborne", root.Position.Y > floor + AIRBORNE_GAP)
	Flight.step(
		s,
		{
			forward = -move.Z,
			strafe = held.HeliRight - held.HeliLeft,
			yaw = move.X,
			lift = held.HeliUp - held.HeliDown,
		},
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
		lift.VectorVelocity = s.velocity
		attitude.CFrame = Flight.attitude(s, spec)
	end
end

local function spinRotors(dt: number)
	for _, model in CollectionService:GetTagged(TAG) do
		local seat = model:FindFirstChild("DriverSeat")
		local on = seat and seat:IsA("VehicleSeat") and seat.Occupant ~= nil
		local s = spool[model] or 0
		s = math.clamp(s + (if on then dt else -dt) / SPOOL_TIME, 0, 1)
		spool[model] = s
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

function HeliController.Start()
	RunService.PreSimulation:Connect(step)
end

return HeliController
