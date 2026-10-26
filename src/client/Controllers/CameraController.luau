--!strict
-- CameraController: owns the camera. Third person only. Modes:
--   Foot       standard third person on foot (Roblox Classic camera, zoom clamped to third person)
--   Chase      third-person spring-arm chase camera in any vehicle seat
--   Cinematic  a film-style shot list (Camera/Cinematic), letterboxed
-- Entering a vehicle seat goes to Chase; leaving it goes back to Foot.
--
-- API (client):
--   CameraController.GetMode(): string
--   CameraController.Comfort     (Camera/Comfort: get/set settings)
--   CameraController.PlayCinematic(shots, opts?) -> handle  (Camera/Cinematic.play)
--   CameraController.Shake(amount 0..1)
--   CameraController.SetOverride(cf, fov?) / ClearOverride()  a Scriptable camera (the build tablet)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local VehicleConfig = require(Shared:WaitForChild("Config"):WaitForChild("VehicleConfig"))

local CameraFolder = script.Parent.Parent:WaitForChild("Camera")
local CameraMath = require(CameraFolder:WaitForChild("CameraMath"))
local Chase = require(CameraFolder:WaitForChild("Chase"))
local Cinematic = require(CameraFolder:WaitForChild("Cinematic"))
local Comfort = require(CameraFolder:WaitForChild("Comfort"))

local CameraController = {}
CameraController.Priority = 60
CameraController.Comfort = Comfort

type Mode = "Foot" | "Chase" | "Cinematic" | "None"

-- On foot: Roblox's third-person camera, never zoomed into the head.
local MIN_ZOOM = 6
local MAX_ZOOM = 30
local START_ZOOM = 19 -- Roblox starts at 12.5: the avatar filled a third of the frame (r2 art review)
local LIFT = 1.5 -- studs the view frames above the head
local freshSpawn = true -- the first Foot entry after a spawn pulls the zoom out to START_ZOOM

local player = Players.LocalPlayer
local mode: Mode = "None"
local override: CFrame? = nil
local overrideFov: number? = nil
local current: {
	seat: BasePart,
	model: Model?,
	root: BasePart,
	spec: any,
	driver: boolean,
}? =
	nil

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

-- The default camera's Popper only stops at visible, colliding parts, but the world's assets collide through
-- invisible _COL hulls and their visual meshes do not collide: nothing pulled the third-person camera out of a
-- quay wall or a rock. Cast from the focus against what collides and pull the camera in front of it.
local occludeParams = RaycastParams.new()
occludeParams.FilterType = Enum.RaycastFilterType.Exclude
occludeParams.RespectCanCollide = true
local function popOccluders(camera: Camera, char: Model)
	local focus = camera.Focus.Position
	local offset = camera.CFrame.Position - focus
	if offset.Magnitude < 1 then
		return
	end
	occludeParams.FilterDescendantsInstances =
		{ char, Workspace:FindFirstChild("Vehicles") :: Instance }
	local hit = Workspace:Spherecast(focus, 0.4, offset, occludeParams)
	local who = hit and hit.Instance:FindFirstAncestorOfClass("Model")
	if hit and not (who and who:FindFirstChildOfClass("Humanoid")) then
		camera.CFrame -= offset.Unit * (offset.Magnitude - hit.Distance)
	end
end

-- A wall pop or a short chase arm can put the lens inside the avatar's head (the near plane shows
-- its insides): fade the own body out as the camera closes in, hidden at 1.5 studs from the head.
local bodyFaded = false
local function fadeNearBody(char: Model, camPos: Vector3)
	local head = char:FindFirstChild("Head")
	local d = if head and head:IsA("BasePart")
		then (head.Position - camPos).Magnitude
		else math.huge
	local t = math.clamp((3.5 - d) / 2, 0, 1)
	if t <= 0 and not bodyFaded then
		return
	end
	bodyFaded = t > 0
	for _, x in char:GetDescendants() do
		if x:IsA("BasePart") or x:IsA("Decal") then
			(x :: any).LocalTransparencyModifier = t
		end
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
	local model = if seat then vehicleOf(seat) else nil
	if not seat or not (model or seat:IsA("VehicleSeat")) then
		current = nil -- on foot, or a plain seat (a bench): the on-foot camera follows the humanoid
		return "Foot"
	end
	if not current or current.seat ~= seat then
		local spec = if model
			then VehicleConfig.get(model:GetAttribute("VehicleId") :: any)
			else nil
		local root = (if model then model.PrimaryPart else nil) or seat.AssemblyRootPart or seat
		current = {
			seat = seat :: BasePart,
			model = model,
			root = root :: BasePart,
			spec = spec :: any,
			driver = seat.Name == "DriverSeat" or seat:IsA("VehicleSeat"),
		}
	end
	return "Chase"
end

local function enterFoot(hum: Humanoid)
	local camera = Workspace.CurrentCamera
	player.CameraMode = Enum.CameraMode.Classic
	player.CameraMinZoomDistance = MIN_ZOOM
	player.CameraMaxZoomDistance = MAX_ZOOM
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = hum
	hum.CameraOffset = Vector3.zero
end

local function exitMode(old: Mode)
	local char, hum = character()
	if old == "Foot" and hum then
		hum.CameraOffset = Vector3.zero
	elseif old == "Chase" then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
	if char then
		fadeNearBody(char, Vector3.one * 1e6) -- a far lens: unfades a body the last mode left faded
	end
end

local function enterMode(new: Mode)
	local _, hum = character()
	if new == "Foot" and hum then
		enterFoot(hum)
		if freshSpawn then
			freshSpawn = false
			-- holding the min zoom up for a few frames is how Roblox's zoom distance gets moved
			player.CameraMinZoomDistance = START_ZOOM
			task.delay(0.1, function()
				if math.abs(player.CameraMinZoomDistance - START_ZOOM) < 0.01 then
					player.CameraMinZoomDistance = MIN_ZOOM
				end
			end)
		end
	elseif new == "Chase" and current then
		player.CameraMode = Enum.CameraMode.Classic
		Chase.enter(current.model or (current.seat.Parent :: any), current.root)
	end
end

---------------------------------------------------------------- input

local function mouseSensitivity(): number
	local ok, s = pcall(function()
		return UserSettings():GetService("UserGameSettings").MouseSensitivity
	end)
	return 0.0032 * (if ok and type(s) == "number" then s else 1) * Comfort.get("sensitivity")
end

-- Chase look: right-drag on mouse, the right stick, a touch drag.
local function gatherLook(dt: number): Vector2
	local look = Vector2.zero
	local dragging = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
	UserInputService.MouseBehavior = if dragging
		then Enum.MouseBehavior.LockCurrentPosition
		else Enum.MouseBehavior.Default
	if dragging then
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
	local camera = Workspace.CurrentCamera
	if player:GetAttribute("LoadingScreenActive") == true then
		return -- src/first/LoadingScreen flies the camera; it hands back a Custom camera when done
	end
	if override then
		if mode ~= "None" then
			exitMode(mode)
			mode = "None"
			player:SetAttribute("CameraMode", mode)
		end
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = override
		if overrideFov then
			camera.FieldOfView = overrideFov
		end
		return
	end
	local want = wantedMode()
	if want ~= mode then
		exitMode(mode)
		mode = want :: Mode
		enterMode(mode)
		player:SetAttribute("CameraMode", mode) -- play tests read it
	end
	local char, hum, root = character()
	if mode == "Cinematic" then
		Cinematic.update(dt)
		return
	end
	Cinematic.update(dt) -- fades the letterbox out
	if mode == "Foot" and char and hum and root then
		-- on foot the camera is Custom; a stray Scriptable one (Studio's execute_luau restores it) strands
		-- the view and hides every ProximityPrompt, so take it back
		if camera.CameraType ~= Enum.CameraType.Custom then
			enterFoot(hum)
		end
		-- frame a little higher than the head (more world, less back)
		local lift = Vector3.new(0, LIFT, 0)
		if (hum.CameraOffset - lift).Magnitude > 0.01 then
			hum.CameraOffset = lift
		end
		camera.FieldOfView = CameraMath.damp(camera.FieldOfView, Comfort.get("fov"), 0.15, dt)
		popOccluders(camera, char)
		fadeNearBody(char, camera.CFrame.Position)
	elseif mode == "Chase" and current then
		local c = current
		local look = gatherLook(dt)
		local craft = c.model or (c.seat.Parent :: any)
		-- the own craft is not an occluder: its console snapped the arm in to the rider's head
		local exclude = excludeList(c.model)
		table.insert(exclude, craft)
		Chase.update(dt, {
			model = craft,
			root = c.root,
			topSpeed = if c.spec then c.spec.topSpeed else 60,
			exclude = exclude,
			-- a dived sub's camera follows it under the surface (Ocean/Underwater draws the view)
			waveHeight = if craft:GetAttribute("Submerged") == true then nil else waveHeight,
			telemetry = telemetry(),
		}, look)
		if char then
			fadeNearBody(char, camera.CFrame.Position)
		end
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

local STORM_GAP = 120 -- seconds between storm-warning shots -- tune
local lastStormShot = -math.huge

local function connectTriggers()
	task.spawn(function()
		local net = ReplicatedStorage:WaitForChild("Net", 30)
		local spawned = net and net:WaitForChild("VehicleSpawned", 30)
		if spawned and spawned:IsA("RemoteEvent") then
			spawned.OnClientEvent:Connect(function(model: any, reason: any)
				if typeof(model) ~= "Instance" or not model:IsA("Model") then
					return
				end
				if model:GetAttribute("Owner") ~= player.UserId then
					return
				end
				if player:GetAttribute("LoadingScreenActive") == true then
					return -- the loading flyover already ends behind this craft
				end
				if reason == "ColdOpen" then
					-- where am I, what is going on: the island, then the casualty, then control
					Cinematic.play(
						Cinematic.Lists.coldOpen(model),
						{ id = "coldopen", skippable = true }
					)
					return
				end
				-- the first launch gets the full shot; later launches go straight to the helm
				if
					not Comfort.hasSeen("launch")
					and not Cinematic.hasPlayed("launch")
					and not busy()
				then
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
			-- once per Warning transition, never over another cinematic, at most every STORM_GAP s
			if Cinematic.isPlaying() or os.clock() - lastStormShot < STORM_GAP then
				return
			end
			local _, _, root = character()
			-- never take the camera from someone at speed
			if current and current.root.AssemblyLinearVelocity.Magnitude > 8 then
				return
			end
			local subject: Instance? = if current and current.model then current.model else root
			lastStormShot = os.clock()
			Cinematic.play(Cinematic.Lists.storm(subject), { id = "storm", repeatable = true })
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
	Chase.addTrauma(amount)
end

-- Scriptable override (DockController's build mode): set every frame while it lasts. Clearing it lets the
-- normal mode (Foot / Chase) take the camera back on the next render step.
function CameraController.SetOverride(cf: CFrame, fov: number?)
	override = cf
	overrideFov = fov
end

function CameraController.ClearOverride()
	override = nil
	overrideFov = nil
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
	RunService:BindToRenderStep("MaydayCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local ok, err = pcall(update :: any, dt)
		if not ok then
			warn(`[CameraController] {err}`)
		end
	end)
	player.CharacterAdded:Connect(function()
		freshSpawn = true
		exitMode(mode)
		mode = "None"
		current = nil
	end)
end

return CameraController
