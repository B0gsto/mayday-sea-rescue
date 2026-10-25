--!strict
-- PlaneController (docs/23 h, WP-7): flies the seaplane on the pilot's client. Inert unless the local
-- player sits in the DriverSeat of a Workspace.Vehicles model whose VehicleId has a Plane/Flight spec.
-- Every PreSimulation it steps Plane/Flight and writes the result into the model's FlyVelocity
-- (LinearVelocity) and FlyAttitude (AlignOrientation), switched on locally while flying (this client
-- owns the assembly) and off again when the pilot leaves, so the parked plane floats on Boat/Simulator.
--
-- Controls (Space / gamepad A gets out: VehicleExitController):
--   keyboard  W / S throttle, A / D bank (turn), Up / Down arrows pull up / dive
--   gamepad   R2 / L2 throttle, left stick X bank, left stick Y pull up / dive
--   touch     thumbstick (up = throttle, sideways = bank), two chevron buttons pull up / dive
-- Up / Down are bound above the default movement so on a keyboard they never move the throttle.
-- The local model attribute Airborne mirrors the flight state (client-local: auto_board reads it).
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BoatController = require(script.Parent.BoatController)
local Flight = require(Shared:WaitForChild("Plane"):WaitForChild("Flight"))
local Glyph = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Glyph"))
local Simulator = require(Shared:WaitForChild("Boat"):WaitForChild("Simulator"))

local RAY_LENGTH = 400 -- studs: ground under the plane farther than this is ignored
local PAD_DEADZONE = 0.2
local SPEED_SLACK = 15 -- studs/s the flight speed may run ahead of the real one (hit a cliff: it stops)
local PROP_IDLE = 8 -- rad/s with someone at the controls
local PROP_PER_SPEED = 0.6 -- rad/s per stud/s
local ACTIONS: { [string]: { key: Enum.KeyCode, at: UDim2, up: boolean } } = {
	PlaneClimb = { key = Enum.KeyCode.Up, at = UDim2.new(1, -170, 1, -300), up = true },
	PlaneDive = { key = Enum.KeyCode.Down, at = UDim2.new(1, -170, 1, -225), up = false },
}

local PlaneController = {}

local player = Players.LocalPlayer
local vehicles: Folder? = nil
local flying: Model? = nil
local state: Flight.State? = nil
local held = { PlaneClimb = false, PlaneDive = false }
local propAngle: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function onAction(name: string, input: Enum.UserInputState): Enum.ContextActionResult
	if not flying then
		return Enum.ContextActionResult.Pass
	end
	held[name] = input == Enum.UserInputState.Begin
	return Enum.ContextActionResult.Sink
end

local function bindInputs(bind: boolean)
	for name, a in ACTIONS do
		held[name] = false
		if not bind then
			ContextActionService:UnbindAction(name)
			continue
		end
		ContextActionService:BindActionAtPriority(
			name,
			onAction,
			true,
			Enum.ContextActionPriority.High.Value,
			a.key
		)
		ContextActionService:SetTitle(name, "")
		ContextActionService:SetPosition(name, a.at)
		local button = ContextActionService:GetButton(name)
		if button then
			-- a chevron: up = pull up, down = dive (no words)
			local s = if a.up then 1 else -1
			local w = Color3.new(1, 1, 1)
			Glyph.bar(button, Vector2.new(0.42, 0.13), Vector2.new(0.38, 0.5), -40 * s, w)
			Glyph.bar(button, Vector2.new(0.42, 0.13), Vector2.new(0.62, 0.5), 40 * s, w)
		end
	end
end

local function pilotSeat(model: Model): VehicleSeat?
	local seat = model:FindFirstChild("DriverSeat")
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if seat and seat:IsA("VehicleSeat") and humanoid and humanoid.SeatPart == seat then
		return seat
	end
	return nil
end

local function movers(model: Model): (LinearVelocity?, AlignOrientation?)
	local root = model.PrimaryPart
	local v = root and root:FindFirstChild("FlyVelocity")
	local a = root and root:FindFirstChild("FlyAttitude")
	return if v and v:IsA("LinearVelocity") then v else nil,
		if a and a:IsA("AlignOrientation") then a else nil
end

local function setMovers(model: Model, on: boolean)
	local v, a = movers(model)
	if v and a then
		v.Enabled = on
		a.Enabled = on
	end
end

local function readInput(seat: VehicleSeat): Flight.Input
	local throttle, pitch = seat.ThrottleFloat, 0
	if UserInputService:GetLastInputType() == Enum.UserInputType.Gamepad1 then
		-- the seat mixes the left stick into the throttle: take the triggers alone, the stick pitches
		local r2, l2 = 0, 0
		for _, io in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
			if io.KeyCode == Enum.KeyCode.ButtonR2 then
				r2 = io.Position.Z
			elseif io.KeyCode == Enum.KeyCode.ButtonL2 then
				l2 = io.Position.Z
			elseif
				io.KeyCode == Enum.KeyCode.Thumbstick1
				and math.abs(io.Position.Y) > PAD_DEADZONE
			then
				pitch = io.Position.Y
			end
		end
		throttle = r2 - l2
	end
	pitch += (if held.PlaneClimb then 1 else 0) - (if held.PlaneDive then 1 else 0)
	return { throttle = throttle, steer = seat.SteerFloat, pitch = math.clamp(pitch, -1, 1) }
end

-- Altitude over the surface below: the water, or the ground where an island stands above it.
local function altitudeOf(root: BasePart, spec: Flight.Spec, now: number): number
	local pos = root.Position
	local alt = Flight.altitude(pos.Y, Simulator.waterHeight(pos.X, pos.Z, now), spec)
	rayParams.FilterDescendantsInstances = { vehicles :: Folder, player.Character } :: { Instance }
	local hit = Workspace:Raycast(pos, Vector3.new(0, -RAY_LENGTH, 0), rayParams)
	if hit then
		alt = math.min(alt, pos.Y - spec.hullSize.Y / 2 - hit.Position.Y)
	end
	return alt
end

local function stopFlying()
	local model = flying
	if model then
		setMovers(model, false)
		model:SetAttribute("Airborne", nil)
	end
	flying = nil
	state = nil
	bindInputs(false)
end

local function step(dt: number)
	local model = flying
	if model and not (model.Parent and pilotSeat(model)) then
		stopFlying()
		model = nil
	end
	if not model and vehicles then
		for _, child in vehicles:GetChildren() do
			if
				child:IsA("Model")
				and Flight.get(child:GetAttribute("VehicleId"))
				and pilotSeat(child)
			then
				model = child
				break
			end
		end
		if not model then
			return
		end
		local root = model.PrimaryPart
		if not root then
			return
		end
		flying = model
		state =
			Flight.fromCFrame(root.CFrame, root.AssemblyLinearVelocity:Dot(root.CFrame.LookVector))
		setMovers(model, true)
		bindInputs(true)
	end
	local m = model :: Model
	local s = state :: Flight.State
	local spec = Flight.get(m:GetAttribute("VehicleId")) :: Flight.Spec
	local seat = pilotSeat(m) :: VehicleSeat
	BoatController.EngageControls(seat) -- the default vehicle controls drive the seat's throttle
	local root = m.PrimaryPart :: BasePart
	local v, a = movers(m)
	if not (v and a) then
		return
	end
	local real = root.AssemblyLinearVelocity:Dot(root.CFrame.LookVector)
	s.speed = math.min(s.speed, math.max(real, 0) + SPEED_SLACK)
	local now = Workspace:GetServerTimeNow()
	Flight.step(s, readInput(seat), altitudeOf(root, spec, now), dt, spec)
	local force = root.AssemblyMass * Workspace.Gravity * 4
	v.MaxForce = force
	v.VectorVelocity = Flight.velocity(s)
	a.MaxTorque = force * spec.hullSize.Z
	a.CFrame = Flight.attitude(s)
	m:SetAttribute("Airborne", s.airborne)
end

-- Props spin with speed on every plane with someone at the controls (visual only, local).
local function spinProps(dt: number)
	if not vehicles then
		return
	end
	for _, child in vehicles:GetChildren() do
		local body = child:FindFirstChild("Body")
		local joint = body and body:FindFirstChild("PropJoint")
		local root = if child:IsA("Model") then child.PrimaryPart else nil
		if joint and joint:IsA("Motor6D") and root then
			local seat = child:FindFirstChild("DriverSeat")
			local manned = seat and seat:IsA("VehicleSeat") and seat.Occupant ~= nil
			local rate = if manned
				then PROP_IDLE + root.AssemblyLinearVelocity.Magnitude * PROP_PER_SPEED
				else 0
			local model = child :: Model
			local angle = ((propAngle[model] or 0) + rate * dt) % (2 * math.pi)
			propAngle[model] = angle
			joint.Transform = CFrame.Angles(0, 0, angle)
		end
	end
end

-- The plane the local player flies, if any.
function PlaneController.GetDriving(): Model?
	return flying
end

-- The flight state (speed, attitude, airborne) of the plane being flown.
function PlaneController.GetState(): Flight.State?
	return state
end

function PlaneController.IsAirborne(): boolean
	return state ~= nil and state.airborne
end

function PlaneController.Init() end

function PlaneController.Start()
	local folder = Workspace:WaitForChild("Vehicles", 30)
	if folder and folder:IsA("Folder") then
		vehicles = folder
	end
	RunService.PreSimulation:Connect(step)
	RunService.RenderStepped:Connect(spinProps)
end

return PlaneController
