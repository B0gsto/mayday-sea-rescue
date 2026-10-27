--!strict
-- BoatController (stream B): client side of the boats.
--
-- 1. Driving. When the local player sits in a vehicle's DriverSeat, the server hands this client
--    network ownership, and every PreSimulation we run Boat/Simulator on it: per float point lift
--    and damping (VectorForce), drag + thrust (DriveForce) and yaw steering (DriveTorque Torque).
--    Throttle and steer come from VehicleSeat.ThrottleFloat / SteerFloat, which Roblox fills from
--    keyboard (WASD / arrows), gamepad and the mobile thumbstick alike; steer goes through
--    Boat/Helm (ramps to full in 0.4 s, less lock at speed). The boat's SpeedMultiplier
--    attribute (the server sets it from ProgressionService.GetGearBonus "speed") scales thrust and
--    top speed inside Simulator.
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
--    There is no approach brake (docs/24 A): the boat takes them at speed, and the held casualty
--    rides along for the tow home.
--
-- 1c. Nav lights. Every NAV_INTERVAL each vehicle's lights follow NavLights.shouldBeOn (night or
--    storm). Visual only, so each client decides for itself.
--
-- 1d. Crowding (docs/20 WP-C addendum). Player boats ghost through each other (server collision
--    group PlayerBoat); the driven hull is eased apart from any other craft it overlaps
--    (Crowding.apart), so bumps never launch or flip anyone.
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

local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Buoyancy = require(Shared:WaitForChild("Boat"):WaitForChild("Buoyancy"))
local ColdOpen = require(Shared:WaitForChild("Boat"):WaitForChild("ColdOpen"))
local Crowding = require(Shared:WaitForChild("Crowding"))
local Glyph = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Glyph"))
local Helm = require(Shared:WaitForChild("Boat"):WaitForChild("Helm"))
local NavLights = require(Shared:WaitForChild("Boat"):WaitForChild("NavLights"))
local Nitro = require(Shared:WaitForChild("Boat"):WaitForChild("Nitro"))
local PickupRingController = require(script.Parent.PickupRingController)
local Simulator = require(Shared:WaitForChild("Boat"):WaitForChild("Simulator"))
local Telemetry = require(script.Parent.Parent:WaitForChild("Telemetry"))
local Unstick = require(Shared:WaitForChild("Boat"):WaitForChild("Unstick"))
local VehicleConfig = require(Shared:WaitForChild("Config"):WaitForChild("VehicleConfig"))

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
local helm = 0 -- the eased steer (Boat/Helm)
local nitro = Nitro.new() -- the Captain Nitro double-tap (Boat/Nitro)
local YAW_SLACK = 1.25 -- the driven hull's yaw rate cap, as a share of its spec turnRate -- tune
local tiltTime = 0
local navTimer = NAV_INTERVAL
local launched: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
-- cold open helm state per jet ski: auto-throttle still holding
type ColdOpenState = { auto: boolean }
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

-- A hull touching a wall (quay, breakwater, beach, a moored boat): four short horizontal rays from
-- the root, each just past the hull's side, find the contact and return the normal pointing out
-- of it. People and casualties don't count.
local function dockContact(model: Model): (boolean, Vector3?)
	local root = model.PrimaryPart
	if not root then
		return false, nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { model }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	local props = Workspace:FindFirstChild("CallProps")
	if props then
		table.insert(ignore, props)
	end
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	params.RespectCanCollide = true
	local size = root.Size
	local forward = Buoyancy.flatForward(root.CFrame.LookVector)
	local right = root.CFrame.RightVector
	for _, ray in
		{
			{ forward, size.Z },
			{ -forward, size.Z },
			{ right, size.X },
			{ -right, size.X },
		} :: { { any } }
	do
		local dir = Vector3.new(ray[1].X, 0, ray[1].Z)
		if dir.Magnitude > 1e-3 then
			dir = dir.Unit
			if Workspace:Raycast(root.Position, dir * (ray[2] * 0.5 + 2), params) then
				return true, -dir
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
			Telemetry.send("StuckReset", "Boat") -- analytics H14: the wall push-off fired
			local root = model.PrimaryPart
			if root then
				root.AssemblyLinearVelocity += normal * Unstick.NUDGE
				-- swing the bow off the wall too (head-on: toward the side being steered, else right)
				local side = normal:Dot(root.CFrame.RightVector)
				local seat = seatOf(model)
				if math.abs(side) < 0.2 and seat then
					side = if seat.SteerFloat ~= 0 then seat.SteerFloat else 1 -- no steer: bear right
				end
				local turn = if side > 0 then -Unstick.TURN elseif side < 0 then Unstick.TURN else 0
				root.AssemblyAngularVelocity += Vector3.new(0, turn, 0)
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

-- The throttle the cold-open jet ski really gets (auto-throttle until handover, then the player's own).
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
		st = { auto = true }
		coldOpens[model] = st
	end
	if not st.auto then
		return input
	end
	local cas = coldOpenCasualty(model)
	local flat = Vector3.new(1, 0, 1)
	local distance = if cas then ((cas - root.Position) * flat).Magnitude else math.huge
	local forward = Buoyancy.flatForward(root.CFrame.LookVector)
	local forwardSpeed = root.AssemblyLinearVelocity:Dot(forward)
	local id = model:GetAttribute("VehicleId")
	local spec: any = if type(id) == "string" then VehicleConfig.get(id) else nil
	local started = model:GetAttribute("ColdOpenStart")
	local elapsed = if type(started) == "number" then now - started else 0
	st.auto = model:GetAttribute("ColdOpenAutoThrottle") == true
		and spec ~= nil
		and ColdOpen.autoActive(elapsed, distance, input)
	if st.auto then
		return ColdOpen.autoThrottle(spec, forwardSpeed)
	end
	model:SetAttribute("ColdOpenAutoThrottle", false) -- handed over (verification hook)
	return input
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
	-- seat.Occupant lags a local exit (Space) by a few frames: never re-engage a seat we just left
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (humanoid and humanoid.SeatPart == seat) then
		return
	end
	local cm = controlModule
	local vc = cm and cm.vehicleController
	if cm and not (vc and vc.enabled and vc.vehicleSeat == seat) then
		pcall(cm.OnHumanoidSeated, cm, true, seat)
	end
end

-- Eases the driven hull out of any other craft it overlaps (they ghost: collision group PlayerBoat).
local function softApart(model: Model)
	local root = model.PrimaryPart
	if not (root and vehicles) then
		return
	end
	local mine = (root.Size.X + root.Size.Z) / 4
	for _, other in vehicles:GetChildren() do
		local o = if other:IsA("Model") and other ~= model then other.PrimaryPart else nil
		if o then
			local off = (root.Position - o.Position) * Vector3.new(1, 0, 1)
			local want = Crowding.apart(off.Magnitude, mine + (o.Size.X + o.Size.Z) / 4)
			if want > 0 then
				local n = if off.Magnitude > 0.1 then off.Unit else root.CFrame.RightVector
				local v = root.AssemblyLinearVelocity
				local away = v:Dot(n)
				if away < want then
					root.AssemblyLinearVelocity = v + n * (want - away)
				end
			end
		end
	end
end

local updateCraftPins: () -> () -- section 4, below

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
		helm = 0
	end
	if vehicles then
		for _, child in vehicles:GetChildren() do
			-- helis fly in HeliController, SubController drives subs
			if
				child:IsA("Model")
				and not child:HasTag("Heli")
				and child:GetAttribute("Sub") ~= true
			then
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
					local id = child:GetAttribute("VehicleId")
					local spec = if type(id) == "string" then VehicleConfig.get(id) else nil
					local throttle, steer =
						PickupRingController.Assist( -- the pick-up ring's helm nudge
							child,
							coldOpenThrottle(child, seat.ThrottleFloat, now),
							seat.SteerFloat
						)
					local root = child.PrimaryPart
					local speed = if root then root.AssemblyLinearVelocity.Magnitude else 0
					helm = Helm.step(helm, steer, speed / (if spec then spec.topSpeed else 60), dt)
					-- Captain Grip (SkillService's SkillGrip): the hull bites sooner; 1 = no change
					Simulator.setGrip(
						child,
						1 + (tonumber(localPlayer:GetAttribute("SkillGrip")) or 0)
					)
					-- Captain Nitro (SkillNitro): a double-tap of the throttle gives a short burst
					Simulator.setBoost(
						child,
						Nitro.step(
							nitro,
							seat.ThrottleFloat,
							now,
							(tonumber(localPlayer:GetAttribute("SkillNitro")) or 0) > 0
						)
					)
					telemetry = Simulator.step(child, throttle, helm, now)
					if root and spec then
						-- a quay corner deflects, never spins: no yaw past the helm's own top rate (and the
						-- unstick swing is trimmed to it a frame later). Playtest 2026-10-26: a RIB spun 180 deg.
						local w = root.AssemblyAngularVelocity
						local cap = math.rad(spec.turnRate) * YAW_SLACK
						if math.abs(w.Y) > cap then
							root.AssemblyAngularVelocity =
								Vector3.new(w.X, math.sign(w.Y) * cap, w.Z)
						end
					end
					softApart(child)
					lastThrottle = throttle
					nowSimulated[child] = true
					checkCapsize(child, seat, dt)
					unstickBoat(child, seat.ThrottleFloat, telemetry and telemetry.speed or 0, dt)
					Telemetry.stalled( -- analytics H15 (not the cold open's auto-throttle)
						"Boat",
						math.abs(seat.ThrottleFloat) > 0.5
							and speed < 1
							and child:GetAttribute("ColdOpenAutoThrottle") ~= true,
						dt
					)
				else
					snapRemote(child, dt, now)
				end
			end
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
	updateCraftPins()
end

-- Last Simulator telemetry of the driven hull (speed, contact, slam, trim, pitch, roll, planing).
-- The submarine reads seat.ThrottleFloat / SteerFloat too (SubController).
BoatController.EngageControls = engageControls

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

-- 3. Board (E / tap / X): a local prompt on the player's own craft while its helm is free, from up to
--    BOARD_RANGE studs (docs/20 rule 6: one obvious action gets you back on). It stands them on the
--    seat, whose touch seats them server-side like walking onto it (VehicleService checks the
--    owner). Scenery boats get none: only Workspace.Vehicles craft owned by us.
-- 4. Craft pin: while we're off our craft, an orange craft billboard (always on top) floats over it
--    with a pip per survivor place (filled = aboard, all red = full). Bay "Launch" prompts hide while
--    we have a craft out (docs/20 rule 6: no second boat by accident).
local BOARD_RANGE = 30 -- studs
local PIN_ORANGE = Color3.fromHex("D9682E") -- HudTheme.Colors.accent
local PIN_FULL = Color3.fromHex("E04A3A")
type CraftPin = { gui: BillboardGui, pips: { Frame }, count: number? }
local craftPins: { [Model]: CraftPin } = {}

local function buildCraftPin(model: Model, root: BasePart): CraftPin
	local capacity = math.clamp(tonumber(model:GetAttribute("Capacity")) or 1, 1, 8)
	local gui = Instance.new("BillboardGui")
	gui.Name = "CraftPin"
	gui.Size = UDim2.fromOffset(math.max(52, capacity * 14 + 12), 74)
	gui.StudsOffsetWorldSpace = Vector3.new(0, root.Size.Y / 2 + 6, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 3000
	gui.ResetOnSpawn = false
	gui.Enabled = false
	local disc = Instance.new("Frame")
	disc.Name = "Disc"
	disc.AnchorPoint = Vector2.new(0.5, 0)
	disc.Position = UDim2.fromScale(0.5, 0)
	disc.Size = UDim2.fromOffset(46, 46)
	disc.BackgroundColor3 = PIN_ORANGE
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = disc
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 2.5
	stroke.Parent = disc
	local icon = Instance.new("Frame")
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(0.66, 0.66)
	icon.Parent = disc
	Glyph.draw("boat", icon, Color3.new(1, 1, 1))
	disc.Parent = gui
	local row = Instance.new("Frame")
	row.Name = "Pips"
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0.5, 1)
	row.Position = UDim2.fromScale(0.5, 1)
	row.Size = UDim2.new(1, 0, 0, 14)
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, 4)
	list.Parent = row
	local pips = {}
	for _ = 1, capacity do
		local pip = Instance.new("Frame")
		pip.Size = UDim2.fromOffset(10, 10)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = pip
		local ps = Instance.new("UIStroke")
		ps.Thickness = 2
		ps.Parent = pip
		pip.Parent = row
		table.insert(pips, pip)
	end
	row.Parent = gui
	gui.Adornee = root
	gui.Parent = root
	return { gui = gui, pips = pips }
end

local function paintPips(pin: CraftPin, count: number)
	local full = count >= #pin.pips
	for i, pip in pin.pips do
		pip.BackgroundColor3 = if full then PIN_FULL else PIN_ORANGE
		pip.BackgroundTransparency = if i <= count then 0 else 1
		local stroke = pip:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if full then PIN_FULL else Color3.new(1, 1, 1)
		end
	end
	pin.count = count
end

local launchHidden: { [ProximityPrompt]: boolean } = {}

-- A berth's Launch hides while you have a craft out, and always on other players' berths (docs/23).
local function hideLaunch(prompt: ProximityPrompt)
	local bay = prompt.Parent
	if
		prompt.Name == "Launch"
		and bay
		and bay:GetAttribute("LaunchBay") ~= nil
		and prompt.Enabled
		and (next(craftPins) or bay:GetAttribute("Owner") ~= localPlayer.UserId)
	then
		prompt.Enabled = false
		launchHidden[prompt] = true
	end
end

-- Every frame: the pin shows over each craft of ours we're not seated on; Launch follows "craft out".
updateCraftPins = function()
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	for model, pin in craftPins do
		if not model.Parent then
			craftPins[model] = nil
		else
			pin.gui.Enabled = not (seat and seat:IsDescendantOf(model))
			local count = tonumber(model:GetAttribute("SurvivorCount")) or 0
			if pin.count ~= count then
				paintPips(pin, count)
			end
		end
	end
	if not next(craftPins) then
		for prompt in launchHidden do
			local bay = prompt.Parent
			if bay and bay:GetAttribute("Owner") == localPlayer.UserId then
				prompt.Enabled = true
				launchHidden[prompt] = nil
			end
		end
	end
end

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
	prompt.MaxActivationDistance = BOARD_RANGE
	prompt.RequiresLineOfSight = false
	prompt.Parent = seat
	local root = model.PrimaryPart
	if root then
		craftPins[model] = buildCraftPin(model, root)
	end
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
	-- bay Launch hides while a craft of ours is out (HudController may re-enable it on a seat change)
	ProximityPromptService.PromptShown:Connect(hideLaunch)
	RunService.PreSimulation:Connect(step)
end

return BoatController
