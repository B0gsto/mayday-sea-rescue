--!strict
-- CameraController: owns the camera. Modes:
--   Foot       locked first person on foot (Roblox's camera + FirstPerson head bob and body)
--   VehicleFP  locked first person at the seat's EyePoint (jet ski; helm view of a chase vehicle)
--   Chase      third-person spring-arm chase camera (RIB, larger boats, cars)
--   Cinematic  a film-style shot list (Camera/Cinematic), letterboxed
-- Entering a seat picks the vehicle's VehicleConfig cameraMode; leaving it goes back to Foot.
-- In a chase vehicle, V / R3 / the mobile "Helm" button toggles the helm view.
-- Land vehicles (model attribute LandVehicle, CONTRACT Land vehicles): the DriverSeat (or any seat
-- of a CameraMode = "Chase" model) gets the chase camera; the player attribute CarCockpit (set by
-- CarController on V / R3, so no helm binding here) switches the driver to DriverSeat.EyePoint.
--
-- API (client):
--   CameraController.GetMode(): string
--   CameraController.Viewmodel   (Camera/Viewmodel: playAction(name, opts?) etc.)
--   CameraController.Comfort     (Camera/Comfort: get/set settings)
--   CameraController.PlayCinematic(shots, opts?) -> handle  (Camera/Cinematic.play)
--   CameraController.Shake(amount 0..1)
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LandVehicleConfig = require(Shared:WaitForChild("Config"):WaitForChild("LandVehicleConfig"))
local VehicleConfig = require(Shared:WaitForChild("Config"):WaitForChild("VehicleConfig"))

local CameraFolder = script.Parent.Parent:WaitForChild("Camera")
local CameraMath = require(CameraFolder:WaitForChild("CameraMath"))
local Chase = require(CameraFolder:WaitForChild("Chase"))
local Cinematic = require(CameraFolder:WaitForChild("Cinematic"))
local Comfort = require(CameraFolder:WaitForChild("Comfort"))
local FirstPerson = require(CameraFolder:WaitForChild("FirstPerson"))
local Viewmodel = require(CameraFolder:WaitForChild("Viewmodel"))

local CameraController = {}
CameraController.Priority = 60
CameraController.Viewmodel = Viewmodel
CameraController.Comfort = Comfort

type Mode = "Foot" | "VehicleFP" | "Chase" | "Cinematic" | "None"

local player = Players.LocalPlayer
local mode: Mode = "None"
local helmView = false
local helmBound = false
local current: {
	seat: BasePart,
	model: Model?,
	root: BasePart,
	spec: any,
	driver: boolean,
	land: boolean,
}? =
	nil

local STATION = Vector3.new(-95, 0, 50)
local arrivalPending = false
local rodeColdOpen = false -- seated in a vehicle before the cold open finished

-- look input gathered between frames
local gamepadLook = Vector2.zero
local touchLook = Vector2.zero
local touches: { [InputObject]: boolean } = {}

local function lazy(name: string): any
	local module = script.Parent:FindFirstChild(name)
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require :: any, module)
		if ok then
			return result
		end
	end
	return nil
end

local boatController: any = nil
local oceanController: any = nil
local opsController: any = nil
local weather: any = nil

local function waveHeight(pos: Vector3): number
	if oceanController and type(oceanController.GetVisualHeight) == "function" then
		local ok, h = pcall(oceanController.GetVisualHeight, pos.X, pos.Z)
		if ok and type(h) == "number" then
			return h
		end
	end
	if weather then
		local ok, h = pcall(weather.heightAt, pos)
		if ok and type(h) == "number" then
			return h
		end
	end
	return 0
end

local function vehicleOf(seat: BasePart): Model?
	local node: Instance? = seat.Parent
	while node and node ~= Workspace do
		if node:IsA("Model") and node:GetAttribute("VehicleId") ~= nil then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function character(): (Model?, Humanoid?, BasePart?)
	local char = player.Character
	if not char then
		return nil, nil, nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return char, hum, root
end

local function excludeList(model: Model?): { Instance }
	local list: { Instance } = { Workspace.CurrentCamera }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	if model then
		-- survivors and riders welded on board are not hull
		for _, d in model:GetChildren() do
			if d:IsA("Model") and d:FindFirstChildOfClass("Humanoid") then
				table.insert(list, d)
			end
		end
	end
	return list
end

---------------------------------------------------------------- helm toggle

local function onHelm(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		helmView = not helmView
	end
	return Enum.ContextActionResult.Sink
end

local function setHelmBinding(on: boolean)
	if on == helmBound then
		return
	end
	helmBound = on
	if on then
		ContextActionService:BindAction(
			"MaydayHelmView",
			onHelm,
			true,
			Enum.KeyCode.V,
			Enum.KeyCode.ButtonR3
		)
		ContextActionService:SetTitle("MaydayHelmView", "Helm")
		ContextActionService:SetPosition("MaydayHelmView", UDim2.new(1, -170, 1, -150))
	else
		ContextActionService:UnbindAction("MaydayHelmView")
		helmView = false
	end
end

---------------------------------------------------------------- mode switching

local function wantedMode(): Mode
	if Cinematic.isPlaying() then
		return "Cinematic"
	end
	local _, hum = character()
	if not hum then
		return "None"
	end
	local seat = hum.SeatPart :: BasePart?
	if not seat then
		current = nil
		return "Foot"
	end
	if not current or current.seat ~= seat then
		local model = vehicleOf(seat)
		local spec = if model
			then VehicleConfig.get(model:GetAttribute("VehicleId") :: any)
			else nil
		local land = model ~= nil and model:GetAttribute("LandVehicle") == true
		if land and model then
			local landSpec = (LandVehicleConfig :: any)[model:GetAttribute("VehicleId")]
			spec = if type(landSpec) == "table" then landSpec else nil
		end
		local root = (if model then model.PrimaryPart else nil) or seat.AssemblyRootPart or seat
		current = {
			seat = seat,
			model = model,
			root = root :: BasePart,
			spec = spec,
			driver = seat.Name == "DriverSeat" or seat:IsA("VehicleSeat"),
			land = land,
		}
		helmView = false
	end
	local c = current :: any
	if c.land then
		local chase = c.driver or (c.model and c.model:GetAttribute("CameraMode") == "Chase")
		if not chase then
			return "VehicleFP"
		end
		local cockpitAllowed = not (c.spec and c.spec.cockpitView == false)
		local eye = c.seat:FindFirstChild("EyePoint")
		if
			c.driver
			and cockpitAllowed
			and eye ~= nil
			and player:GetAttribute("CarCockpit") == true
		then
			return "VehicleFP"
		end
		return "Chase"
	end
	local cameraMode = if c.spec
		then c.spec.cameraMode
		elseif c.seat:IsA("VehicleSeat") then "Chase" -- cars and unknown craft
		else "FirstPerson"
	if cameraMode == "Chase" then
		return if helmView then "VehicleFP" else "Chase"
	end
	return "VehicleFP"
end

-- The helm toggle is for boats; in a land vehicle V / R3 belong to CarController (CarCockpit).
local function helmWanted(m: Mode): boolean
	return current ~= nil and not current.land and (m == "Chase" or (m == "VehicleFP" and helmView))
end

local function exitMode(old: Mode)
	local char, hum = character()
	if old == "Foot" then
		FirstPerson.exitFoot(hum)
	elseif old == "VehicleFP" then
		FirstPerson.exitVehicle()
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	elseif old == "Chase" then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
	if char then
		FirstPerson.resetBodyVisibility(char)
	end
	Viewmodel.setBasePose(nil)
end

local function enterMode(new: Mode)
	local _, hum = character()
	if new == "Foot" and hum then
		FirstPerson.enterFoot(hum)
	elseif new == "VehicleFP" then
		player.CameraMode = Enum.CameraMode.Classic
		FirstPerson.enterVehicle()
		FirstPerson.setSprayEnabled(
			Comfort.get("lensSpray") == true and not (current ~= nil and current.land)
		)
		if current and current.driver then
			Viewmodel.setBasePose("steer")
		end
	elseif new == "Chase" and current then
		player.CameraMode = Enum.CameraMode.Classic
		Chase.enter(current.model or (current.seat.Parent :: any), current.root)
	end
	Viewmodel.setEnabled(new == "Foot" or new == "VehicleFP")
	setHelmBinding(helmWanted(new))
end

---------------------------------------------------------------- input

local function mouseSensitivity(): number
	local ok, s = pcall(function()
		return UserSettings():GetService("UserGameSettings").MouseSensitivity
	end)
	return 0.0032 * (if ok and type(s) == "number" then s else 1) * Comfort.get("sensitivity")
end

local function gatherLook(dt: number, lockMouse: boolean, dragOnly: boolean): Vector2
	local look = Vector2.zero
	local dragging = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
	if lockMouse then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	elseif dragOnly then
		UserInputService.MouseBehavior = if dragging
			then Enum.MouseBehavior.LockCurrentPosition
			else Enum.MouseBehavior.Default
	end
	if lockMouse or dragging then
		local d = UserInputService:GetMouseDelta()
		look += Vector2.new(-d.X, -d.Y) * mouseSensitivity()
	end
	local stick = Vector2.new(
		CameraMath.deadzone(gamepadLook.X, 0.15),
		CameraMath.deadzone(gamepadLook.Y, 0.15)
	)
	look += Vector2.new(-stick.X, stick.Y) * (3.2 * dt * Comfort.get("sensitivity"))
	look += touchLook * (0.006 * Comfort.get("sensitivity"))
	touchLook = Vector2.zero
	return look
end

local function connectInput()
	UserInputService.InputChanged:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.Thumbstick2 then
			gamepadLook = Vector2.new(input.Position.X, input.Position.Y)
		elseif input.UserInputType == Enum.UserInputType.Touch and touches[input] then
			touchLook += Vector2.new(-input.Delta.X, -input.Delta.Y)
		elseif
			input.UserInputType == Enum.UserInputType.MouseWheel
			and not processed
			and mode == "Chase"
		then
			Chase.zoom(-input.Position.Z * 0.1)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.Touch and not processed then
			touches[input] = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		touches[input] = nil
		if input.KeyCode == Enum.KeyCode.Thumbstick2 then
			gamepadLook = Vector2.zero
		end
	end)
end

---------------------------------------------------------------- per frame

local function telemetry(): any
	if
		current
		and current.driver
		and not current.land
		and boatController
		and type(boatController.GetTelemetry) == "function"
	then
		local ok, t = pcall(boatController.GetTelemetry)
		if ok then
			return t
		end
	end
	return nil
end

local function update(dt: number)
	local want = wantedMode()
	if want ~= mode then
		exitMode(mode)
		mode = want :: Mode
		enterMode(mode)
	end
	local camera = Workspace.CurrentCamera
	local char, hum, root = character()
	if mode == "Cinematic" then
		Cinematic.update(dt)
		return
	end
	Cinematic.update(dt) -- fades the letterbox out
	if mode == "Foot" and char and hum and root then
		FirstPerson.foot(dt, hum, root)
		FirstPerson.applyBodyVisibility(char, Viewmodel.isPlaying())
	elseif mode == "VehicleFP" and current then
		local c = current
		local look = gatherLook(dt, true, false)
		local eye = c.seat:FindFirstChild("EyePoint")
		FirstPerson.vehicle(dt, {
			root = c.root,
			seat = c.seat,
			eye = if eye and eye:IsA("Attachment") then eye else nil,
			topSpeed = if c.spec then c.spec.topSpeed else 60,
			telemetry = telemetry(),
		}, look)
		if char then
			FirstPerson.applyBodyVisibility(char, true)
		end
		if c.seat:IsA("VehicleSeat") then
			Viewmodel.setSteer((c.seat :: VehicleSeat).SteerFloat)
		end
	elseif mode == "Chase" and current then
		local c = current
		local look = gatherLook(dt, false, true)
		Chase.update(dt, {
			model = c.model or (c.seat.Parent :: any),
			root = c.root,
			topSpeed = if c.spec then c.spec.topSpeed else 60,
			exclude = excludeList(c.model),
			waveHeight = waveHeight,
			telemetry = telemetry(),
		}, look)
	end
	-- the helm toggle stays bound while in a chase vehicle, also from the helm view
	setHelmBinding(helmWanted(mode))
	Viewmodel.update(dt, camera.CFrame)

	-- remember riding before ColdOpenDone: the server may reseat or reset the jet ski at the very
	-- moment the cold open ends, so `current` can be nil when the attribute flips
	if current and player:GetAttribute("ColdOpenDone") ~= true then
		rodeColdOpen = true
	end
	if arrivalPending and root and (root.Position - STATION).Magnitude < 230 then
		arrivalPending = false
		Cinematic.play(Cinematic.Lists.arrival(), { id = "arrival" })
	end
end

---------------------------------------------------------------- cinematic triggers

local function busy(): boolean
	if opsController and type(opsController.GetState) == "function" then
		local ok, s = pcall(opsController.GetState)
		if ok and type(s) == "table" and s.state == "Active" then
			return true
		end
	end
	return false
end

local function connectTriggers()
	player:GetAttributeChangedSignal("ColdOpenDone"):Connect(function()
		-- only when it flips at the end of the cold open (still riding), not on a profile load
		if
			player:GetAttribute("ColdOpenDone") == true
			and (current ~= nil or rodeColdOpen)
			and not Comfort.hasSeen("arrival")
		then
			arrivalPending = true
		end
	end)
	task.spawn(function()
		local net = ReplicatedStorage:WaitForChild("Net", 30)
		local spawned = net and net:WaitForChild("VehicleSpawned", 30)
		if spawned and spawned:IsA("RemoteEvent") then
			spawned.OnClientEvent:Connect(function(model: any, reason: any)
				if typeof(model) ~= "Instance" or not model:IsA("Model") then
					return
				end
				if model:GetAttribute("Owner") ~= player.UserId or reason == "ColdOpen" then
					return
				end
				-- the first launch gets the full shot; later launches go straight to the helm
				if not Comfort.hasSeen("launch") and not busy() then
					task.wait(0.4)
					Cinematic.play(Cinematic.Lists.launch(model), { id = "launch" })
				end
			end)
		end
	end)
	if weather and weather.changed then
		weather.changed:Connect(function(state: string)
			if state ~= "Warning" or busy() then
				return
			end
			local _, _, root = character()
			-- never take the camera from someone at speed
			if current and current.root.AssemblyLinearVelocity.Magnitude > 8 then
				return
			end
			local subject: Instance? = if current and current.model then current.model else root
			Cinematic.play(Cinematic.Lists.storm(subject), { id = "storm" })
		end)
	end
end

---------------------------------------------------------------- API

function CameraController.GetMode(): string
	return mode
end

function CameraController.PlayCinematic(shots: { Cinematic.Shot }, opts: any?): Cinematic.Handle
	return Cinematic.play(shots, opts)
end

function CameraController.Shake(amount: number)
	FirstPerson.addTrauma(amount)
	Chase.addTrauma(amount)
end

function CameraController.Init()
	local ok, w = pcall(function()
		return require(Shared:WaitForChild("Weather") :: ModuleScript) :: any
	end)
	weather = if ok then w else nil
end

function CameraController.Start()
	boatController = lazy("BoatController")
	oceanController = lazy("OceanController")
	opsController = lazy("OpsController")
	task.spawn(Comfort.load)
	connectInput()
	connectTriggers()
	RunService:BindToRenderStep("MaydayCameraPre", Enum.RenderPriority.Camera.Value - 1, function()
		if mode == "Foot" then
			FirstPerson.preFoot()
		end
	end)
	RunService:BindToRenderStep("MaydayCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local ok, err = pcall(update :: any, dt)
		if not ok then
			warn(`[CameraController] {err}`)
		end
	end)
	player.CharacterAdded:Connect(function()
		exitMode(mode)
		mode = "None"
		current = nil
	end)
end

return CameraController
