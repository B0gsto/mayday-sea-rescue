--!strict
-- CameraController: owns the camera. Modes:
--   Foot       standard third person on foot (Roblox Classic camera, zoom in to first person;
--              the character and accessories stay visible, FirstPerson adds a close-in head bob)
--   Close      close work (casualty care): a first-person view reached with an eased dolly
--              (Camera/Transition) and released back to the previous third-person view
--   VehicleFP  locked first person at the seat's EyePoint (helm view of a chase vehicle)
--   Chase      third-person spring-arm chase camera (jet ski, RIB, larger boats, cars)
--   Cinematic  a film-style shot list (Camera/Cinematic), letterboxed
-- Entering a seat picks the vehicle's VehicleConfig cameraMode; leaving it goes back to Foot.
-- In a chase vehicle, V / R3 / the mobile "Helm" button toggles the helm view.
-- Land vehicles (model attribute LandVehicle, CONTRACT Land vehicles): the DriverSeat (or any seat
-- of a CameraMode = "Chase" model) gets the chase camera; the player attribute CarCockpit (set by
-- CarController on V / R3, so no helm binding here) switches the driver to DriverSeat.EyePoint.
--
-- API (client):
--   CameraController.GetMode(): string
--   CameraController.HoldFirstPerson() -> release()   close work; refcounted, eased in and out
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
local Transition = require(CameraFolder:WaitForChild("Transition"))
local Viewmodel = require(CameraFolder:WaitForChild("Viewmodel"))

local CameraController = {}
CameraController.Priority = 60
CameraController.Viewmodel = Viewmodel
CameraController.Comfort = Comfort

type Mode = "Foot" | "Close" | "VehicleFP" | "Chase" | "Cinematic" | "None"

-- Close work (casualty care). Holds are refcounted so consecutive care steps do not bounce the
-- camera. Entering dollies from the current third-person view to the eye; leaving dollies back
-- to the saved third-person view (relative to the player, so it follows them if they turned).
local closeHolds = 0
local closePhase: "Done" | "In" | "Hold" | "Out" = "Done"
local closeFrom = CFrame.identity
local closeFromRel = CFrame.identity
local closePoseSet = false
local closeZoom = 12.5 -- the third-person zoom distance the close work started from
local closeFocus: (() -> Vector3?)? = nil -- the care area the dolly ends looking at (G81)

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
local arrivalPendingSince = 0
local coldOpenModel: Model? = nil
local ARRIVAL_WINDOW = 90 -- s after ColdOpenDone the arrival shot may still start -- tune
local rodeColdOpen = false -- seated in a vehicle before the cold open finished

-- Arrival handoff: when the arrival cinematic ends the server (VehicleService,
-- Vehicle_ArrivalHandoff) unseats the player, docks the jet ski and stands them on the station
-- slipway. The camera holds the last cinematic frame until the reply (or HANDOFF_HOLD seconds),
-- then enters Foot facing Chief Aggie's spot. LocalPlayer attribute ArrivalOnFoot = true and the
-- print "[CameraController] arrival handoff: on foot at slipway" mark it done.
local HANDOFF_REMOTE = "Vehicle_ArrivalHandoff"
local HANDOFF_HOLD = 2.5 -- seconds -- tune
local EYE_HEIGHT = 4.5 -- studs above Aggie's spot to look at -- tune
local handoffHoldUntil = 0
local handoffLook: Vector3? = nil
local handoffFrames = 0
local requestHandoff: () -> ()

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

---------------------------------------------------------------- close work

local function headPart(): BasePart?
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then head else nil
end

-- The eye point in the view's current orientation (the head is the anchor if it is missing).
local function eyeFrame(rotation: CFrame): CFrame
	local head = headPart()
	if not head then
		return Workspace.CurrentCamera.CFrame
	end
	return CFrame.new(head.Position + head.CFrame * Vector3.new(0, 0.1, -0.55)) * rotation
end

-- beginCloseOut reads the mode: a release before the mode has switched is a no-op.
local function currentMode(): Mode
	return mode
end

-- resume: the exit was reversed by a new hold, so keep the saved third-person frame
local function beginCloseIn(resume: boolean)
	local camera = Workspace.CurrentCamera
	if not resume then
		closeFrom = camera.CFrame
		local _, _, root = character()
		if root then
			closeFromRel = root.CFrame:ToObjectSpace(closeFrom)
		end
		local head = headPart()
		if head then
			closeZoom = (closeFrom.Position - head.Position).Magnitude
		end
	end
	local _, hum = character()
	if hum then
		hum.CameraOffset = Vector3.zero
	end
	closePhase = "In"
	closePoseSet = false
	player.CameraMode = Enum.CameraMode.Classic
	Viewmodel.setEnabled(true)
	Transition.begin({
		from = camera.CFrame,
		to = function()
			return eyeFrame(closeFrom.Rotation)
		end,
		fovFrom = camera.FieldOfView,
		fovTo = Comfort.get("fov"),
		bodyAtTarget = 1,
		waveHeight = waveHeight,
		focus = closeFocus,
		exclude = excludeList(current and current.model or nil),
	})
end

local function beginCloseOut()
	if closePhase ~= "In" and closePhase ~= "Hold" then
		return
	end
	if currentMode() ~= "Close" then
		closePhase = "Done"
		return
	end
	local camera = Workspace.CurrentCamera
	local char, hum, root = character()
	if not (char and hum and root) then
		closePhase = "Done"
		return
	end
	closePhase = "Out"
	closePoseSet = false
	FirstPerson.resetBodyVisibility(char) -- the fade owns the body on the way out
	Transition.begin({
		from = camera.CFrame,
		to = function()
			return root.CFrame * closeFromRel
		end,
		fovFrom = camera.FieldOfView,
		fovTo = Comfort.get("fov"),
		bodyAtTarget = 0,
		waveHeight = waveHeight,
		exclude = excludeList(current and current.model or nil),
	})
end

-- Drop every close-work hold and hand the camera back. Called when the character dies, respawns,
-- is removed or changes seat mid-dolly: the hold's owner (Care) may never run its release, and a
-- Scriptable camera left behind never returns to Custom (the body stays invisible with it).
local function cancelClose()
	if closeHolds == 0 and closePhase == "Done" and mode ~= "Close" then
		return
	end
	closeHolds = 0
	closeFocus = nil
	closePhase = "Done"
	closePoseSet = false
	Transition.stop()
	local camera = Workspace.CurrentCamera
	local char, hum = character()
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		if hum then
			camera.CameraSubject = hum
		end
	end
	if hum then
		hum.CameraOffset = Vector3.zero
		player.CameraMode = Enum.CameraMode.Classic
	end
	player.CameraMaxZoomDistance = FirstPerson.MAX_ZOOM
	-- the first-person lock clamped the zoom to 0.5 and raising the range does not undo it: hold the
	-- saved third-person distance for a few frames so the camera comes back out (as exitMode does)
	player.CameraMinZoomDistance = math.clamp(closeZoom, FirstPerson.MIN_ZOOM, FirstPerson.MAX_ZOOM)
	task.delay(0.1, function()
		if mode ~= "Close" then
			player.CameraMinZoomDistance = FirstPerson.MIN_ZOOM
		end
	end)
	if char then
		FirstPerson.resetBodyVisibility(char)
	end
	Viewmodel.setBasePose(nil)
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
	if Cinematic.isPlaying() or os.clock() < handoffHoldUntil then
		return "Cinematic"
	end
	local _, hum = character()
	if not hum then
		return "None"
	end
	local seat = hum.SeatPart :: BasePart?
	if not seat then
		-- close work pulls the camera into the eye; it stays Close until the exit settles
		if closeHolds > 0 or closePhase == "Out" then
			return "Close"
		end
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
	-- the cold-open jet ski rides in third person: the casualty, the craft and the shore all read
	local cameraMode = if c.model and c.model:GetAttribute("ColdOpen") == true
		then "Chase"
		elseif c.spec then c.spec.cameraMode
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
	elseif old == "Close" then
		Transition.stop()
		closePhase = "Done"
		Viewmodel.setBasePose(nil)
		player.CameraMode = Enum.CameraMode.Classic
		FirstPerson.exitFoot(hum)
		-- the lock clamped Roblox's zoom to 0.5 and raising the max later does not undo that: clamp it
		-- back out to the saved distance once enterFoot has reset the range (deferred, next frame)
		local z = math.clamp(closeZoom, FirstPerson.MIN_ZOOM, FirstPerson.MAX_ZOOM)
		task.defer(function()
			if mode ~= "Foot" then
				return
			end
			player.CameraMinZoomDistance = z
			task.delay(0.1, function()
				if math.abs(player.CameraMinZoomDistance - z) < 0.01 then
					player.CameraMinZoomDistance = FirstPerson.MIN_ZOOM
				end
			end)
		end)
	elseif old == "VehicleFP" then
		FirstPerson.setRider(nil)
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
	elseif new == "Close" then
		-- a release that landed before the mode switched has already begun the exit
		if closePhase ~= "Out" then
			beginCloseIn(false)
		end
	elseif new == "VehicleFP" then
		player.CameraMode = Enum.CameraMode.Classic
		FirstPerson.enterVehicle()
		FirstPerson.setSprayEnabled(
			Comfort.get("lensSpray") == true and not (current ~= nil and current.land)
		)
		if current and current.driver then
			Viewmodel.setBasePose("steer")
			FirstPerson.setRider(current.model)
		end
	elseif new == "Chase" and current then
		player.CameraMode = Enum.CameraMode.Classic
		Chase.enter(current.model or (current.seat.Parent :: any), current.root)
	end
	-- the viewmodel is first-person only: close work and a vehicle helm (third-person Foot hides it)
	Viewmodel.setEnabled(new == "Close" or new == "VehicleFP")
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

---------------------------------------------------------------- arrival handoff

local function handoffRemote(): RemoteEvent?
	local net = ReplicatedStorage:FindFirstChild("Net")
	local remote = net and net:FindFirstChild(HANDOFF_REMOTE)
	return if remote and remote:IsA("RemoteEvent") then remote else nil
end

-- The arrival cinematic ended (played out or skipped): ask the server to bring us ashore.
requestHandoff = function()
	local remote = handoffRemote()
	if not remote then
		warn("[CameraController] arrival handoff: no Vehicle_ArrivalHandoff remote")
		return
	end
	handoffHoldUntil = os.clock() + HANDOFF_HOLD
	remote:FireServer()
end

local function onHandoff(data: any)
	if type(data) ~= "table" or typeof(data.stand) ~= "CFrame" then
		return
	end
	local char, hum = character()
	if char and hum then
		hum.Sit = false
		-- the client owns its character: pivot here too so physics does not pull it back
		char:PivotTo(data.stand)
	end
	current = nil
	arrivalPending = false
	handoffLook = if typeof(data.look) == "Vector3" then data.look else nil
	handoffFrames = 3
	handoffHoldUntil = 0
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

local function updateClose(dt: number)
	local camera = Workspace.CurrentCamera
	local char, hum, root = character()
	if not (char and hum and root) then
		closePhase = "Done"
		return
	end
	if closePhase == "In" then
		-- no idle hands held up in front: they filled the bottom of the view and hid the casualty;
		-- the hands come in with each action (grab, wrap, CPR) and drop away after it
		if not Transition.update(dt) then
			closePhase = "Hold"
			FirstPerson.enterFirstPerson(hum)
			camera.CFrame = eyeFrame(camera.CFrame.Rotation)
			camera.FieldOfView = Comfort.get("fov")
		end
	elseif closePhase == "Hold" then
		FirstPerson.foot(dt, hum, root)
		FirstPerson.applyBodyVisibility(char)
		if closeHolds == 0 then
			beginCloseOut()
		end
	elseif closePhase == "Out" then
		local running = Transition.update(dt)
		-- the hands lower as the camera leaves the eye
		if running and not closePoseSet and Transition.progress() > 0.45 then
			closePoseSet = true
			Viewmodel.setBasePose(nil)
		end
		if not running then
			closePhase = "Done"
			FirstPerson.resetBodyVisibility(char)
			player.CameraMode = Enum.CameraMode.Classic
			FirstPerson.exitFoot(hum)
			Viewmodel.setBasePose(nil)
		end
	end
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
		return -- first person
	end
	occludeParams.FilterDescendantsInstances =
		{ char, Workspace:FindFirstChild("Vehicles") :: Instance }
	local hit = Workspace:Spherecast(focus, 0.4, offset, occludeParams)
	local who = hit and hit.Instance:FindFirstAncestorOfClass("Model")
	if hit and not (who and who:FindFirstChildOfClass("Humanoid")) then
		camera.CFrame -= offset.Unit * (offset.Magnitude - hit.Distance)
	end
end

local function update(dt: number)
	local want = wantedMode()
	if want ~= mode then
		exitMode(mode)
		mode = want :: Mode
		enterMode(mode)
		player:SetAttribute("CameraMode", mode) -- play tests read it
	end
	local camera = Workspace.CurrentCamera
	local char, hum, root = character()
	if mode == "Cinematic" then
		Cinematic.update(dt)
		return
	end
	Cinematic.update(dt) -- fades the letterbox out
	if mode == "Close" then
		updateClose(dt)
	elseif mode == "Foot" and char and hum and root then
		-- on foot the camera is Custom; a stray Scriptable one (Studio's execute_luau restores it) strands
		-- the view and hides every ProximityPrompt, so take it back
		if
			camera.CameraType ~= Enum.CameraType.Custom
			and player:GetAttribute("PhotoModeOpen") ~= true
		then
			FirstPerson.enterFoot(hum)
		end
		local look = handoffLook
		if look and handoffFrames > 0 then
			-- the default camera reads its look vector from camera.CFrame, so this sticks
			handoffFrames -= 1
			local head = camera.CFrame.Position
			camera.CFrame = CFrame.lookAt(head, look + Vector3.new(0, EYE_HEIGHT, 0))
			if handoffFrames == 0 then
				handoffLook = nil
				player:SetAttribute("ArrivalOnFoot", true)
				print("[CameraController] arrival handoff: on foot at slipway")
			end
		end
		FirstPerson.foot(dt, hum, root)
		popOccluders(camera, char)
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
			FirstPerson.applyBodyVisibility(char)
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
	-- the arrival shot plays once, only while still riding in (a teleport on foot into range, a
	-- late ColdOpenDone flip or a server-side handoff never replays it)
	if
		arrivalPending
		and (
			Cinematic.hasPlayed("arrival")
			or player:GetAttribute("ArrivalOnFoot") == true
			or os.clock() - arrivalPendingSince > ARRIVAL_WINDOW
		)
	then
		arrivalPending = false
	end
	if
		arrivalPending
		and root
		and current
		and current.model ~= nil
		and (current.model == coldOpenModel or current.model:GetAttribute("ColdOpen") == true)
		and (root.Position - STATION).Magnitude < 230
	then
		arrivalPending = false
		Cinematic.play(Cinematic.Lists.arrival(), { id = "arrival", onDone = requestHandoff })
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
		local remote = net and net:WaitForChild(HANDOFF_REMOTE, 30)
		if remote and remote:IsA("RemoteEvent") then
			remote.OnClientEvent:Connect(onHandoff)
		end
	end)
	player:GetAttributeChangedSignal("ColdOpenDone"):Connect(function()
		-- only when it flips at the end of the cold open (still riding), not on a profile load
		if
			player:GetAttribute("ColdOpenDone") == true
			and (current ~= nil or rodeColdOpen)
			and not Comfort.hasSeen("arrival")
			and not Cinematic.hasPlayed("arrival")
		then
			arrivalPending = true
			arrivalPendingSince = os.clock()
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
				if model:GetAttribute("Owner") ~= player.UserId then
					return
				end
				if reason == "ColdOpen" then
					coldOpenModel = model -- the arrival shot only plays while riding this craft
					-- where am I, what is going on: town and station, then the casualty, then control
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

-- Close work (casualty care): hold the first-person view for as long as a mechanic needs it.
-- The first hold dollies in from the current third-person view; the last release dollies back to
-- it. Calls are refcounted, so overlapping care steps keep the camera still. `focus` (optional)
-- names the care area the dolly should end looking at, so the body parts sit near the centre.
function CameraController.HoldFirstPerson(focus: (() -> Vector3?)?): () -> ()
	closeHolds += 1
	if focus then
		closeFocus = focus
	end
	if closePhase == "Out" then
		beginCloseIn(true) -- reversed mid-exit: dolly back in from where the camera is
	end
	local released = false
	return function()
		if released then
			return
		end
		released = true
		closeHolds = math.max(closeHolds - 1, 0)
		if closeHolds == 0 then
			closeFocus = nil
			beginCloseOut()
		end
	end
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
		if mode == "Foot" or mode == "Close" then
			FirstPerson.preFoot()
		end
	end)
	RunService:BindToRenderStep("MaydayCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local ok, err = pcall(update :: any, dt)
		if not ok then
			warn(`[CameraController] {err}`)
		end
	end)
	player.CharacterRemoving:Connect(cancelClose)
	local function watchCharacter(char: Model)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum then
			return
		end
		hum.Died:Connect(cancelClose)
		hum:GetPropertyChangedSignal("SeatPart"):Connect(cancelClose)
	end
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(function()
		cancelClose()
		exitMode(mode)
		mode = "None"
		current = nil
		handoffHoldUntil = 0
		handoffLook = nil
		closeHolds = 0
		closeFocus = nil
		closePhase = "Done"
		Transition.stop()
	end)
end

return CameraController
