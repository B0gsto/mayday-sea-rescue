--!strict
-- BoatController (stream B): client side of the boats.
--
-- 1. Driving. When the local player sits in a vehicle's DriverSeat, the server hands this client
--    network ownership, and every PreSimulation we run Boat/Simulator on it: per float point lift
--    and damping (VectorForce), drag + thrust (DriveForce) and yaw steering (DriveTorque Torque).
--    Throttle and steer come from VehicleSeat.ThrottleFloat / SteerFloat, which Roblox fills from
--    keyboard (WASD / arrows), gamepad and the mobile thumbstick alike. The boat's SpeedMultiplier
--    attribute (the server sets it from ProgressionService.GetGearBonus "speed") scales thrust and
--    top speed inside Simulator. A model tagged VehicleTowed with TowedBy = our UserId is ours to
--    simulate too (no input), since the server gave us its ownership.
--
-- 1b. Helm modes and safety. Z (or the on-screen "Approach" button) toggles approach mode: a
--    speed governor under 5 knots with fine throttle (Buoyancy.thrust), for the final run to a
--    casualty; throttle released = neutral, the hull glides. On a vehicle with ejectOnCapsize (the
--    jet ski) the rider is thrown off past CAPSIZE_ANGLE; leaving the seat pulls the kill cord and
--    the server stops the engine (EngineRunning = false, see VehicleService).
--    Telemetry from Simulator.step is kept for the HUD and test scripts (GetTelemetry).
--
-- 1b2. Cold open (docs 09 9.1, shared/Boat/ColdOpen). OperationService marks the cold-open jet
--    ski: ColdOpenOpId, ColdOpenTarget (Vector3, the datum), ColdOpenStart (server time) and
--    ColdOpenAutoThrottle = true. Here the auto-throttle holds about 20 knots until AUTO_HOLD s,
--    HANDOVER_DISTANCE studs from the casualty or the player's first throttle input, then sets
--    ColdOpenAutoThrottle = false (locally) and the throttle is the player's (W released coasts).
--    While ColdOpenApproach is true (server: the approach step is current) and the player is in
--    Assist (OpsPro ~= true), a hull still fast near the casualty is braked to approach speed;
--    AssistEase (bool) is true while that ease acts and AssistEaseCount counts its engagements
--    (Mechanics/approach reports it; the server caps the grade at Silver).
--
-- 1c. Nav lights. Every NAV_INTERVAL each vehicle's lights follow NavLights.shouldBeOn (night or
--    storm). Visual only, so each client decides for itself.
--
-- 2. Remote hulls. Boats we do not simulate arrive by replication from their owner, who floats
--    them on the same deterministic Waves field, so they already ride the waves; only latency and
--    the ocean mesh's interpolation between grid vertices make them look a little high or low,
--    and anchored docked boats do not bob at all. To fix that without fighting physics we never
--    touch the replicated HullRoot: the visible hull (Body and everything welded to it) hangs off
--    HullRoot by the Motor6D "VisualJoint", and we set its Transform (local-only, not replicated,
--    ignored by the owner's simulation) to a small, smoothed vertical offset that puts the hull at
--    its rest draft on the locally drawn wave. Height comes from OceanController.GetVisualHeight
--    when stream A provides it, else from the shared wave field.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Buoyancy = require(Shared:WaitForChild("Boat"):WaitForChild("Buoyancy"))
local ColdOpen = require(Shared:WaitForChild("Boat"):WaitForChild("ColdOpen"))
local NavLights = require(Shared:WaitForChild("Boat"):WaitForChild("NavLights"))
local Simulator = require(Shared:WaitForChild("Boat"):WaitForChild("Simulator"))
local Unstick = require(Shared:WaitForChild("Boat"):WaitForChild("Unstick"))
local VehicleConfig = require(Shared:WaitForChild("Config"):WaitForChild("VehicleConfig"))

local TOW_TAG = "VehicleTowed"
local MAX_VISUAL_OFFSET = 1.5 -- studs; larger errors are left to replication -- tune
local VISUAL_SMOOTHING = 10 -- 1/s -- tune
local CAPSIZE_ANGLE = math.rad(70) -- the rider falls off past this heel -- tune
local CAPSIZE_HOLD = 0.3 -- seconds past it -- tune
local NAV_INTERVAL = 1 -- seconds
local APPROACH_ACTION = "BoatApproachMode"

local BoatController = {}

local localPlayer = Players.LocalPlayer
local vehicles: Folder? = nil
local driving: Model? = nil -- the vehicle whose DriverSeat we sit in
local simulated: { [Model]: boolean } = {} -- models this client applied forces to last frame
local visualOffset: { [Model]: number } = {}
local telemetry: Simulator.Telemetry? = nil
local lastThrottle = 0 -- the throttle the driven hull got last step (after the cold-open helm)
local tiltTime = 0
local navTimer = NAV_INTERVAL
local launched: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
-- cold open helm state per jet ski: auto-throttle still holding, Assist ease acting
type ColdOpenState = { auto: boolean, easing: boolean }
local coldOpens: { [Model]: ColdOpenState } = setmetatable({}, { __mode = "k" }) :: any
local unstick: { [Model]: Unstick.State } = setmetatable({}, { __mode = "k" }) :: any

-- CONTRACT: OceanController.GetVisualHeight(x, z) from stream A, if it exists.
local ocean: any = nil

local function visualHeight(x: number, z: number, now: number): number
	if ocean and type(ocean.GetVisualHeight) == "function" then
		local ok, h = pcall(ocean.GetVisualHeight, x, z)
		if ok and type(h) == "number" then
			return h
		end
	end
	return Simulator.waterHeight(x, z, now)
end

local function seatOf(model: Model): VehicleSeat?
	local seat = model:FindFirstChild("DriverSeat")
	return if seat and seat:IsA("VehicleSeat") then seat else nil
end

local function isLocalDriver(model: Model): boolean
	local seat = seatOf(model)
	local occupant = seat and seat.Occupant
	return occupant ~= nil and occupant.Parent == localPlayer.Character
end

local function isLocalTow(model: Model): boolean
	return model:GetAttribute("TowedBy") == localPlayer.UserId
end

local function setVisualOffset(model: Model, offset: number)
	local root = model.PrimaryPart
	local joint = root and root:FindFirstChild("VisualJoint")
	if root and joint and joint:IsA("Motor6D") then
		-- Transform is in Part0 (HullRoot) space: turn the world-vertical offset into it.
		joint.Transform = CFrame.new(root.CFrame:VectorToObjectSpace(Vector3.new(0, offset, 0)))
	end
end

local function snapRemote(model: Model, dt: number, now: number)
	local root = model.PrimaryPart
	local float1 = root and root:FindFirstChild("Float1")
	local draft = model:GetAttribute("Draft")
	if not (root and float1 and float1:IsA("Attachment") and type(draft) == "number") then
		return
	end
	local p = root.Position
	local wantY = Buoyancy.restRootY(visualHeight(p.X, p.Z, now), draft, float1.Position.Y)
	local target = math.clamp(wantY - p.Y, -MAX_VISUAL_OFFSET, MAX_VISUAL_OFFSET)
	local current = visualOffset[model] or 0
	current += (target - current) * math.min(1, dt * VISUAL_SMOOTHING)
	visualOffset[model] = current
	setVisualOffset(model, current)
end

-- A hull pinned on a quay or breakwater: four short horizontal rays from the root find the
-- contact and return the normal pointing out of the wall.
local function dockContact(model: Model): (boolean, Vector3?)
	local root = model.PrimaryPart
	if not root then
		return false, nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	local size = root.Size
	local reach = math.max(size.X, size.Z) * 0.5 + 2
	local forward = Buoyancy.flatForward(root.CFrame.LookVector)
	local dirs = {
		forward,
		-forward,
		root.CFrame.RightVector,
		-root.CFrame.RightVector,
	}
	for _, raw in dirs do
		local dir = Vector3.new(raw.X, 0, raw.Z)
		if dir.Magnitude > 1e-3 then
			dir = dir.Unit
			local hit = Workspace:Raycast(root.Position, dir * reach, params)
			local part = hit and hit.Instance
			if part and part:IsA("BasePart") then
				local node: Instance? = part
				while node do
					local name = node.Name
					if
						string.find(name, "Breakwater", 1, true)
						or string.find(name, "Quay", 1, true)
					then
						return true, -dir
					end
					node = node.Parent
				end
			end
		end
	end
	return false, nil
end

local function unstickBoat(model: Model, throttle: number, speed: number, dt: number)
	local state = unstick[model]
	if not state then
		state = Unstick.new()
		unstick[model] = state
	end
	if throttle > 0.05 and math.abs(speed) < Unstick.SPEED then
		local wedged, normal = dockContact(model)
		if Unstick.step(state, dt, wedged, speed, throttle) and normal then
			local root = model.PrimaryPart
			if root then
				root.AssemblyLinearVelocity += normal * Unstick.NUDGE
			end
		end
	else
		Unstick.step(state, dt, false, speed, throttle) -- not pinned: reset the timer
	end
end

-- Throws the rider off a capsizing sit-on hull (the kill cord then stops the engine).
local function checkCapsize(model: Model, seat: VehicleSeat, dt: number)
	local id = model:GetAttribute("VehicleId")
	local spec = if type(id) == "string" then VehicleConfig.get(id) else nil
	local root = model.PrimaryPart
	if not (spec and spec.ejectOnCapsize and root) then
		return
	end
	if root.CFrame.UpVector.Y < math.cos(CAPSIZE_ANGLE) then
		tiltTime += dt
	else
		tiltTime = 0
	end
	local humanoid = seat.Occupant
	if tiltTime > CAPSIZE_HOLD and humanoid then
		tiltTime = 0
		humanoid.Sit = false
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end

local function updateNavLights(dt: number, now: number)
	navTimer += dt
	if navTimer < NAV_INTERVAL or not vehicles then
		return
	end
	navTimer = 0
	local on = NavLights.shouldBeOn(Lighting.ClockTime, Simulator.stormIntensity(now))
	for _, child in vehicles:GetChildren() do
		if child:IsA("Model") then
			NavLights.apply(child, on)
		end
	end
end

local function toggleApproach(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local model = driving
	if not model then
		return Enum.ContextActionResult.Pass
	end
	-- Local attribute: this client simulates the hull, so the governor runs here.
	model:SetAttribute("ApproachMode", not (model:GetAttribute("ApproachMode") == true))
	ContextActionService:SetTitle(
		APPROACH_ACTION,
		if model:GetAttribute("ApproachMode") then "Slow" else "Approach"
	)
	return Enum.ContextActionResult.Sink
end

local function setApproachBinding(on: boolean)
	if on then
		ContextActionService:BindAction(
			APPROACH_ACTION,
			toggleApproach,
			true,
			Enum.KeyCode.Z,
			Enum.KeyCode.ButtonY
		)
		ContextActionService:SetTitle(APPROACH_ACTION, "Approach")
		ContextActionService:SetPosition(APPROACH_ACTION, UDim2.new(1, -170, 1, -150))
	else
		ContextActionService:UnbindAction(APPROACH_ACTION)
	end
end

-- The cold-open casualty: its Victim model (it drifts and gets pushed), else the datum.
local function coldOpenCasualty(model: Model): Vector3?
	local opId = model:GetAttribute("ColdOpenOpId")
	local props = Workspace:FindFirstChild("CallProps")
	if opId ~= nil and props then
		for _, m in props:GetChildren() do
			if m:IsA("Model") and m.Name == "Victim" and m:GetAttribute("CallId") == opId then
				local part = m.PrimaryPart
				if part then
					return part.Position
				end
			end
		end
	end
	local target = model:GetAttribute("ColdOpenTarget")
	return if typeof(target) == "Vector3" then target else nil
end

-- True once the cold-open casualty holds on: the approach ease must let go for the tow in.
local function coldOpenHeld(model: Model): boolean
	local opId = model:GetAttribute("ColdOpenOpId")
	local props = Workspace:FindFirstChild("CallProps")
	if opId ~= nil and props then
		for _, m in props:GetChildren() do
			if
				m:IsA("Model")
				and m.Name == "Victim"
				and m:GetAttribute("CallId") == opId
				and m:GetAttribute("PiwMode") == "held"
			then
				return true
			end
		end
	end
	return false
end

-- The throttle the cold-open jet ski really gets (auto-throttle, then the player's, eased).
local function coldOpenThrottle(model: Model, input: number, now: number): number
	local root = model.PrimaryPart
	if not root then
		return input
	end
	local st = coldOpens[model]
	if not st then
		if model:GetAttribute("ColdOpenAutoThrottle") ~= true then
			return input
		end
		st = { auto = true, easing = false }
		coldOpens[model] = st
	end
	local cas = coldOpenCasualty(model)
	local flat = Vector3.new(1, 0, 1)
	local distance = if cas then ((cas - root.Position) * flat).Magnitude else math.huge
	local forward = Buoyancy.flatForward(root.CFrame.LookVector)
	local forwardSpeed = root.AssemblyLinearVelocity:Dot(forward)
	local id = model:GetAttribute("VehicleId")
	local spec: any = if type(id) == "string" then VehicleConfig.get(id) else nil
	local throttle = input
	if st.auto then
		local started = model:GetAttribute("ColdOpenStart")
		local elapsed = if type(started) == "number" then now - started else 0
		st.auto = model:GetAttribute("ColdOpenAutoThrottle") == true
			and spec ~= nil
			and ColdOpen.autoActive(elapsed, distance, input)
		if st.auto then
			throttle = ColdOpen.autoThrottle(spec, forwardSpeed)
		else
			model:SetAttribute("ColdOpenAutoThrottle", false) -- handed over (verification hook)
		end
	end
	local assist = localPlayer:GetAttribute("OpsPro") ~= true
	local onApproach = model:GetAttribute("ColdOpenApproach") == true and not coldOpenHeld(model)
	local wasEasing = st.easing
	st.easing = onApproach
		and ColdOpen.updateEase(
			st.easing,
			assist,
			distance,
			forwardSpeed,
			if spec then spec.brakeDecel else nil
		)
	if st.easing then
		throttle = ColdOpen.easeThrottle(forwardSpeed, throttle)
		if not wasEasing then
			local n = model:GetAttribute("AssistEaseCount")
			model:SetAttribute("AssistEaseCount", (if type(n) == "number" then n else 0) + 1)
		end
	end
	if model:GetAttribute("AssistEase") ~= st.easing then
		model:SetAttribute("AssistEase", st.easing)
	end
	return throttle
end

-- The server can seat us before the PlayerModule hooks Humanoid.Seated (the cold open seats on
-- spawn, a re-seat can reorder Seated true/false): then Roblox never fills ThrottleFloat /
-- SteerFloat and W/S/A/D, the stick and the triggers do nothing. Hand the seat over ourselves.
local controlModule: any = nil
local function engageControls(seat: VehicleSeat)
	if controlModule == nil then
		local ps = localPlayer:FindFirstChild("PlayerScripts")
		local pm = ps and ps:FindFirstChild("PlayerModule")
		local cmod = pm and pm:FindFirstChild("ControlModule")
		if not cmod then
			return -- not loaded yet: try again next frame
		end
		local ok, cm = pcall(require :: any, cmod)
		controlModule = if ok and type(cm) == "table" then cm else false
	end
	local cm = controlModule
	local vc = cm and cm.vehicleController
	if cm and not (vc and vc.enabled and vc.vehicleSeat == seat) then
		pcall(cm.OnHumanoidSeated, cm, true, seat)
	end
end

local function stopSimulating(model: Model)
	simulated[model] = nil
	if model.Parent then
		Simulator.clear(model)
	end
end

local function step(dt: number)
	local now = Workspace:GetServerTimeNow()
	local nowSimulated: { [Model]: boolean } = {}

	local wasDriving = driving
	if driving and (not driving.Parent or not isLocalDriver(driving)) then
		driving:SetAttribute("ApproachMode", nil)
		driving = nil
		telemetry = nil
	end
	if vehicles then
		for _, child in vehicles:GetChildren() do
			if child:IsA("Model") then
				if isLocalDriver(child) then
					driving = child
					local seat = seatOf(child) :: VehicleSeat
					local launchSpeed = child:GetAttribute("LaunchSpeed")
					if
						type(launchSpeed) == "number"
						and not launched[child]
						and child.PrimaryPart
					then
						-- VehicleService.SpawnSeated (cold open): start already under way
						launched[child] = true
						local look = child.PrimaryPart.CFrame.LookVector
						child.PrimaryPart.AssemblyLinearVelocity = Vector3.new(look.X, 0, look.Z).Unit
							* launchSpeed
					end
					engageControls(seat)
					local throttle = coldOpenThrottle(child, seat.ThrottleFloat, now)
					telemetry = Simulator.step(child, throttle, seat.SteerFloat, now)
					lastThrottle = throttle
					nowSimulated[child] = true
					checkCapsize(child, seat, dt)
					unstickBoat(child, seat.ThrottleFloat, telemetry and telemetry.speed or 0, dt)
				elseif isLocalTow(child) then
					Simulator.step(child, 0, 0, now)
					nowSimulated[child] = true
				else
					snapRemote(child, dt, now)
				end
			end
		end
	end
	-- towed non-vehicle hulls (NPC boats) that the server handed to us
	for _, tagged in CollectionService:GetTagged(TOW_TAG) do
		if tagged:IsA("Model") and not nowSimulated[tagged] and isLocalTow(tagged) then
			Simulator.step(tagged, 0, 0, now)
			nowSimulated[tagged] = true
		end
	end

	for model in simulated do
		if not nowSimulated[model] then
			stopSimulating(model)
		end
	end
	for model in nowSimulated do
		if visualOffset[model] then
			visualOffset[model] = nil
			setVisualOffset(model, 0) -- our own hull shows its true physics pose
		end
	end
	simulated = nowSimulated
	if (driving ~= nil) ~= (wasDriving ~= nil) then
		setApproachBinding(driving ~= nil)
	end
	updateNavLights(dt, now)
end

-- Last Simulator telemetry of the driven hull (speed, contact, slam, trim, pitch, roll, planing).
function BoatController.GetTelemetry(): Simulator.Telemetry?
	return telemetry
end

-- The throttle (-1..1) the driven hull got last step; AudioController ties the engine RPM to it.
function BoatController.GetThrottle(): number
	return if driving then lastThrottle else 0
end

-- The vehicle the local player is driving, if any.
function BoatController.GetDrivenVehicle(): Model?
	return driving
end

function BoatController.Init()
	local module = script.Parent:FindFirstChild("OceanController")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require :: any, module)
		if ok and type(result) == "table" then
			ocean = result
		end
	end
end

-- 3. Board (E / tap / X): a local prompt on the player's own craft while its helm is free. It
--    stands them on the seat, whose touch seats them server-side like walking onto it (VehicleService
--    checks the owner). Scenery boats get none: only Workspace.Vehicles craft owned by us.
local function addBoardPrompt(model: Instance)
	if not model:IsA("Model") or model:GetAttribute("Owner") ~= localPlayer.UserId then
		return
	end
	local found = model:WaitForChild("DriverSeat", 10) -- may stream in after the model
	if not (found and found:IsA("VehicleSeat")) then
		return
	end
	local seat: VehicleSeat = found
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Board"
	prompt.ActionText = "Board"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = seat
	local function refresh()
		prompt.Enabled = seat.Occupant == nil
	end
	seat:GetPropertyChangedSignal("Occupant"):Connect(refresh)
	refresh()
	prompt.Triggered:Connect(function()
		local character = localPlayer.Character
		if character and seat.Occupant == nil then
			character:PivotTo(seat.CFrame * CFrame.new(0, 2.5, 0))
		end
	end)
end

function BoatController.Start()
	local folder = Workspace:WaitForChild("Vehicles", 30)
	if folder and folder:IsA("Folder") then
		vehicles = folder
		folder.ChildAdded:Connect(function(child)
			task.spawn(addBoardPrompt, child)
		end)
		for _, child in folder:GetChildren() do
			task.spawn(addBoardPrompt, child)
		end
		folder.ChildRemoved:Connect(function(child)
			if child:IsA("Model") then
				visualOffset[child] = nil
				simulated[child] = nil
				unstick[child] = nil
			end
		end)
	else
		warn("[BoatController] Workspace.Vehicles not found")
	end
	RunService.PreSimulation:Connect(step)
end

return BoatController
