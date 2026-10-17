--!strict
-- CarController: drives the player's land vehicle (LandVehicleService) on the raycast chassis in
-- src/shared/Car, and animates every nearby land vehicle (wheels, light bars, lamps, horn).
--
-- Driving: throttle and steer come from the DriverSeat's ThrottleFloat / SteerFloat, which Roblox
-- fills from WASD / arrows, the gamepad thumbstick and the touch thumbstick; gamepad triggers
-- (R2 throttle, L2 brake / reverse) override the throttle when pressed. The automatic brakes on
-- the opposite pedal and changes into reverse at a standstill.
--   Space / X button     handbrake            L / D-pad down    low range
--   H / L3               horn (hold)          J / D-pad up      headlights
--   K / D-pad right      blue lights + siren  B / Y button      launch the boat off the trailer
--   V / R3               cockpit view (player attribute CarCockpit, read by the camera stream)
-- Touch gets ContextActionService buttons for the same actions.
-- Assists (ABS, traction control) are on unless the player's CarAssistsOff attribute is true
-- (TODO(settings): a Pro toggle in the settings UI).
-- Camera: the model has CameraMode = "Chase" and DriverSeat.EyePoint; the camera stream
-- implements the chase cam and the cockpit view (CONTRACT, Land vehicles).
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarFolder = Shared:WaitForChild("Car")
local LandVehicleConfig = require(Shared:WaitForChild("Config"):WaitForChild("LandVehicleConfig"))
local LightBar = require(CarFolder:WaitForChild("LightBar"))
local Physics = require(CarFolder:WaitForChild("Physics"))

local player = Players.LocalPlayer

-- TODO(audio): our own recorded or licensed assets (never toolbox ids). Empty = silent.
local SOUNDS = {
	Engine = "", -- diesel idle loop, pitched by rpm
	Horn = "",
	Siren = "", -- UK two-tone / wail
	TyreRoar = "",
	Skid = "",
	Gravel = "",
}

local VISUAL_RANGE = 400 -- studs: wheels and lights animate for cars this close

local CarController = {}
CarController.Priority = 120

type Visual = {
	sim: Physics.Sim,
	beacons: { BasePart },
	sounds: { [string]: Sound },
}

local visuals: { [Model]: Visual } = {}
local driving: Model? = nil
local driveSim: Physics.Sim? = nil
local trailerSim: Physics.Sim? = nil
local trailerModel: Model? = nil
local controlRemote: RemoteEvent? = nil
local handbrake = false
local lowRange = false
local triggerThrottle, triggerBrake = 0, 0
local hud: TextLabel? = nil
local excludeAt = 0

local function send(action: string, value: any)
	if controlRemote then
		controlRemote:FireServer(action, value)
	end
end

local function specOf(model: Model): LandVehicleConfig.Spec?
	local id = model:GetAttribute("VehicleId")
	return if type(id) == "string" then LandVehicleConfig.get(id) else nil
end

local function extraMass(model: Model): number
	local v = model:GetAttribute("ExtraMassKg")
	return if type(v) == "number" then v else 0
end

local function makeSound(parent: Instance, name: string, looped: boolean): Sound?
	local id = (SOUNDS :: any)[name]
	if type(id) ~= "string" or id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = "Car" .. name
	s.SoundId = id
	s.Looped = looped
	s.RollOffMaxDistance = 250
	s.Parent = parent
	return s
end

local function visualFor(model: Model): Visual?
	local existing = visuals[model]
	if existing then
		return existing
	end
	local spec = specOf(model)
	if not (spec and model.PrimaryPart) then
		return nil
	end
	local beacons = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Beacon" then
			table.insert(beacons, d)
		end
	end
	local root = model.PrimaryPart :: BasePart
	local sounds: { [string]: Sound } = {}
	for _, name in { "Engine", "Horn", "Siren" } do
		local s = makeSound(root, name, true)
		if s then
			sounds[name] = s
		end
	end
	local v: Visual =
		{ sim = Physics.new(model, spec, extraMass(model)), beacons = beacons, sounds = sounds }
	visuals[model] = v
	model.Destroying:Connect(function()
		visuals[model] = nil
	end)
	return v
end

local function updateLights(model: Model, v: Visual, now: number)
	local spec = specOf(model)
	local pattern = spec and spec.lightBar
	local on = model:GetAttribute("LightBar") == true and pattern ~= nil
	for _, b in v.beacons do
		local index = b:GetAttribute("LampIndex")
		local count = b:GetAttribute("LampCount")
		local color = b:GetAttribute("LampColor")
		if typeof(color) ~= "Color3" or type(index) ~= "number" or type(count) ~= "number" then
			continue
		end
		local level = if on and pattern then LightBar.brightness(pattern, now, index, count) else 0
		b.Material = if level > 0.05 then Enum.Material.Neon else Enum.Material.Glass
		b.Color = (color :: Color3):Lerp(Color3.new(0, 0, 0), 0.5 * (1 - level))
		local light = b:FindFirstChildOfClass("PointLight")
		if light then
			light.Enabled = level > 0.05
			light.Brightness = 4 * level
		end
	end
	local horn = v.sounds.Horn
	if horn then
		local want = model:GetAttribute("Horn") == true
		if want and not horn.IsPlaying then
			horn:Play()
		elseif not want and horn.IsPlaying then
			horn:Stop()
		end
	end
	local siren = v.sounds.Siren
	if siren then
		local want = model:GetAttribute("Siren") == true
		if want and not siren.IsPlaying then
			siren:Play()
		elseif not want and siren.IsPlaying then
			siren:Stop()
		end
	end
end

local function setLamps(model: Model, name: string, lit: boolean, color: Color3)
	for _, d in model:GetChildren() do
		if d:IsA("BasePart") and d.Name == name then
			d.Material = if lit then Enum.Material.Neon else Enum.Material.Glass
			d.Color = color
		end
	end
end

-- Input -------------------------------------------------------------------------------------------

local ACTIONS = {
	CarHandbrake = { Enum.KeyCode.Space, Enum.KeyCode.ButtonX },
	CarHorn = { Enum.KeyCode.H, Enum.KeyCode.ButtonL3 },
	CarLights = { Enum.KeyCode.J, Enum.KeyCode.DPadUp },
	CarBlues = { Enum.KeyCode.K, Enum.KeyCode.DPadRight },
	CarLowRange = { Enum.KeyCode.L, Enum.KeyCode.DPadDown },
	CarLaunch = { Enum.KeyCode.B, Enum.KeyCode.ButtonY },
	CarView = { Enum.KeyCode.V, Enum.KeyCode.ButtonR3 },
}
local TITLES = {
	CarHandbrake = "Brake",
	CarHorn = "Horn",
	CarLights = "Lights",
	CarBlues = "Blues",
	CarLowRange = "Low",
	CarLaunch = "Launch",
	CarView = "View",
}

local function onAction(
	name: string,
	state: Enum.UserInputState,
	_input: InputObject
): Enum.ContextActionResult
	local model = driving
	if not model then
		return Enum.ContextActionResult.Pass
	end
	local began = state == Enum.UserInputState.Begin
	local ended = state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel
	if name == "CarHandbrake" then
		handbrake = began or (handbrake and not ended)
	elseif name == "CarHorn" then
		if began or ended then
			send("Horn", began)
		end
	elseif began then
		if name == "CarLights" then
			send("Headlights", model:GetAttribute("Headlights") ~= true)
		elseif name == "CarBlues" then
			local on = model:GetAttribute("LightBar") ~= true
			send("LightBar", on)
			task.delay(0.1, send, "Siren", on)
		elseif name == "CarLowRange" then
			lowRange = not lowRange
		elseif name == "CarLaunch" then
			send("Launch", true)
		elseif name == "CarView" then
			player:SetAttribute("CarCockpit", player:GetAttribute("CarCockpit") ~= true)
		end
	end
	return Enum.ContextActionResult.Sink
end

local function bindInputs(bind: boolean)
	for name, keys in ACTIONS do
		if bind then
			ContextActionService:BindAction(
				name,
				onAction,
				true,
				table.unpack(keys :: { Enum.KeyCode })
			)
			ContextActionService:SetTitle(name, TITLES[name])
		else
			ContextActionService:UnbindAction(name)
		end
	end
	if bind then
		ContextActionService:SetPosition("CarHandbrake", UDim2.new(1, -95, 1, -210))
		ContextActionService:SetPosition("CarHorn", UDim2.new(1, -170, 1, -210))
		ContextActionService:SetPosition("CarBlues", UDim2.new(1, -245, 1, -210))
		ContextActionService:SetPosition("CarLaunch", UDim2.new(1, -170, 1, -285))
	end
end

local function makeHud()
	local gui = Instance.new("ScreenGui")
	gui.Name = "CarHud"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -12)
	label.Size = UDim2.fromOffset(360, 30)
	label.BackgroundTransparency = 0.4
	label.BackgroundColor3 = Color3.fromRGB(15, 20, 25)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 18
	label.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	hud = label
end

-- Driving -----------------------------------------------------------------------------------------

local function currentDriverSeat(): VehicleSeat?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if seat and seat:IsA("VehicleSeat") and seat.Name == "DriverSeat" then
		local model = seat.Parent
		if model and model:IsA("Model") and model:GetAttribute("LandVehicle") == true then
			return seat
		end
	end
	return nil
end

local function stopDriving()
	if driveSim then
		Physics.idle(driveSim)
	end
	if trailerSim then
		Physics.idle(trailerSim)
	end
	driving, driveSim, trailerSim, trailerModel = nil, nil, nil, nil
	handbrake = false
	bindInputs(false)
	if hud and hud.Parent then
		(hud.Parent :: ScreenGui).Enabled = false
	end
	player:SetAttribute("CarCockpit", nil)
end

local function startDriving(model: Model)
	local spec = specOf(model)
	if not spec then
		return
	end
	driving = model
	driveSim = Physics.new(model, spec, extraMass(model))
	lowRange = false
	local link = model:FindFirstChild("Trailer")
	local trailer: Instance? = if link and link:IsA("ObjectValue") then link.Value else nil
	if trailer and trailer:IsA("Model") and trailer.PrimaryPart then
		trailerModel = trailer
		trailerSim = Physics.new(trailer, LandVehicleConfig.BoatTrailer, extraMass(trailer))
		trailer:GetAttributeChangedSignal("ExtraMassKg"):Connect(function()
			if trailerModel == trailer then
				trailerSim = Physics.new(trailer, LandVehicleConfig.BoatTrailer, extraMass(trailer))
			end
		end)
	end
	bindInputs(true)
	if hud and hud.Parent then
		(hud.Parent :: ScreenGui).Enabled = true
	end
end

local function refreshExcludes(now: number)
	if now - excludeAt < 1 then
		return
	end
	excludeAt = now
	local chars: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(chars, p.Character)
		end
	end
	if driveSim then
		local extra = table.clone(chars)
		if trailerModel then
			table.insert(extra, trailerModel)
		end
		Physics.setExclude(driveSim, extra)
	end
	if trailerSim and driving then
		local extra = table.clone(chars)
		table.insert(extra, driving)
		Physics.setExclude(trailerSim, extra)
	end
end

local function drive(dt: number)
	local seat = currentDriverSeat()
	local model = seat and seat.Parent :: Model?
	if model ~= driving then
		stopDriving()
		if model then
			startDriving(model)
		end
	end
	local sim = driveSim
	if not (seat and sim and driving) then
		return
	end
	if sim.root.Anchored then
		return -- the server hands over ownership a moment after we sit
	end
	refreshExcludes(os.clock())
	local throttle = seat.ThrottleFloat
	if triggerThrottle > 0.05 or triggerBrake > 0.05 then
		throttle = triggerThrottle - triggerBrake
	end
	local towing = trailerSim ~= nil
	local telemetry = Physics.step(sim, {
		throttle = throttle,
		steer = seat.SteerFloat,
		handbrake = handbrake,
		lowRange = lowRange,
		assists = player:GetAttribute("CarAssistsOff") ~= true,
		towing = towing,
	}, dt)
	if trailerSim then
		Physics.step(trailerSim, {
			throttle = 0,
			steer = 0,
			handbrake = false,
			lowRange = false,
			assists = true,
			brakeOverride = telemetry.brake,
		}, dt)
	end
	-- lamps (local to the driver; other clients see the parked state)
	setLamps(driving, "BrakeLamp", telemetry.brake > 0.05 or handbrake, Color3.fromRGB(255, 30, 30))
	setLamps(driving, "ReverseLamp", telemetry.gear == -1, Color3.fromRGB(240, 240, 240))
	local headlights = driving:GetAttribute("Headlights") == true
	setLamps(driving, "TailLamp", headlights, Color3.fromRGB(200, 25, 25))
	setLamps(driving, "Headlamp", headlights, Color3.fromRGB(245, 245, 230))
	local v = visuals[driving]
	local engine = v and v.sounds.Engine
	if engine then
		local redline = if sim.derived.spec.engine then sim.derived.spec.engine.redlineRpm else 4000
		engine.PlaybackSpeed = 0.55 + telemetry.rpm / redline
		engine.Volume = 0.35 + 0.4 * telemetry.drive
		if not engine.IsPlaying then
			engine:Play()
		end
	end
	if hud then
		local kmh = math.abs(telemetry.speed) / LandVehicleConfig.KMH
		local gear = if telemetry.gear == -1 then "R" else `D{telemetry.gear}`
		local extras = {}
		if lowRange then
			table.insert(extras, "LOW")
		end
		if handbrake then
			table.insert(extras, "P")
		end
		if driving:GetAttribute("CanLaunch") == true then
			table.insert(extras, "LAUNCH: B")
		end
		hud.Text =
			`{math.floor(kmh + 0.5)} km/h   {gear}   {math.floor(telemetry.rpm / 100) * 100} rpm   {table.concat(
				extras,
				"  "
			)}`
	end
end

local function animate(dt: number)
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	local folder = Workspace:FindFirstChild("LandVehicles")
	if not folder then
		return
	end
	local now = Workspace:GetServerTimeNow()
	for _, model in folder:GetChildren() do
		if not (model:IsA("Model") and model.PrimaryPart) then
			continue
		end
		if (model.PrimaryPart.Position - eye).Magnitude > VISUAL_RANGE then
			continue
		end
		local v = visualFor(model)
		if not v then
			continue
		end
		if model == driving and driveSim then
			-- our sim did the raycasts this frame
			v.sim.results = driveSim.results
			v.sim.compression = driveSim.compression
			Physics.updateVisuals(v.sim, dt, true)
		elseif model == trailerModel and trailerSim then
			v.sim.results = trailerSim.results
			v.sim.compression = trailerSim.compression
			Physics.updateVisuals(v.sim, dt, true)
		elseif not model.PrimaryPart.Anchored then
			local seat = model:FindFirstChild("DriverSeat")
			local steer = if seat and seat:IsA("VehicleSeat") then seat.SteerFloat else 0
			Physics.updateVisuals(v.sim, dt, false, steer)
		end
		updateLights(model, v, now)
	end
end

function CarController.Init()
	makeHud()
	task.spawn(function()
		local net = ReplicatedStorage:WaitForChild("Net")
		local remote = net:WaitForChild("Land_Control", 30)
		if remote and remote:IsA("RemoteEvent") then
			controlRemote = remote
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.ButtonR2 then
			triggerThrottle = input.Position.Z
		elseif input.KeyCode == Enum.KeyCode.ButtonL2 then
			triggerBrake = input.Position.Z
		end
	end)
end

function CarController.Start()
	RunService.PreSimulation:Connect(drive)
	RunService.RenderStepped:Connect(animate)
end

-- API ---------------------------------------------------------------------------------------------

function CarController.GetDriving(): Model?
	return driving
end

-- Requests a vehicle (the HUD's vehicle menu, when it exists). Returns (ok, reason | Model).
function CarController.Request(
	vehicleId: string,
	pointId: string?,
	withTrailer: boolean?
): (boolean, any)
	local net = ReplicatedStorage:FindFirstChild("Net")
	local fn = net and net:FindFirstChild("Land_Request")
	if not (fn and fn:IsA("RemoteFunction")) then
		return false, "NotReady"
	end
	return fn:InvokeServer(vehicleId, pointId, withTrailer)
end

return CarController
