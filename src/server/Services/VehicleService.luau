--!strict
-- VehicleService (stream B): launches boats from the dock bays, one vehicle per player.
--
--   RequestVehicle (RemoteFunction, Net)  client asks for a vehicleId -> (ok, reasonOrVehicle)
--   Bay ProximityPrompts                 temporary launch UI until the HUD exists ("Launch Jet Ski")
--
-- Vehicle states:
--   Dock    nobody driving and the hull is at a bay: HullRoot anchored (clients bob it visually)
--   Driven  the owner is in DriverSeat: unanchored, network owner = driver, whose client
--           (BoatController) runs buoyancy and controls. The server only sanity-checks speed and
--           position every CHECK_INTERVAL and pulls cheaters back to the last good spot.
--   Drift   nobody driving, away from the dock: unanchored, server-owned, the server runs buoyancy.
-- Tows: AttachTow ropes TowHitch to the target's BowPoint and hands the target's ownership to the
-- tower's driver (attribute TowedBy = that UserId, tag VehicleTowed) so the same client simulates
-- both hulls. With no driver, the server simulates the tow.
--
-- Shared APIs: see CONTRACT.md (B: VehicleService). ProgressionService (stream E) is optional:
-- if it is missing or errors, every vehicle is allowed and the gear speed bonus is 1.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Builder = require(Shared:WaitForChild("Boat"):WaitForChild("Builder"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local Net = require(Shared:WaitForChild("Net"))
local Simulator = require(Shared:WaitForChild("Boat"):WaitForChild("Simulator"))
local VehicleConfig = require(Shared:WaitForChild("Config"):WaitForChild("VehicleConfig"))

type VehicleSpec = VehicleConfig.VehicleSpec
type Mode = "Dock" | "Driven" | "Drift"
type Survivor = { model: Model, weld: WeldConstraint }
type Record = {
	model: Model,
	owner: Player,
	spec: VehicleSpec,
	root: BasePart,
	seat: VehicleSeat,
	slots: { Attachment },
	survivors: { [number]: Survivor },
	mode: Mode,
	driver: Player?,
	tow: { rope: RopeConstraint, target: Model }?,
	lastGood: CFrame,
	strikes: number,
	resetting: boolean,
}

local TOW_TAG = "VehicleTowed"
local SPAWN_COOLDOWN = 2 -- seconds between launches per player
local DOCK_RADIUS = 14 -- an emptied hull this close to a bay centre docks (anchors) -- tune
local CHECK_INTERVAL = 0.5 -- seconds between sanity checks
local SPEED_TOLERANCE = 1.35 -- x top speed (waves and surfing add speed) -- tune
local SPEED_SLACK = 15 -- studs/s -- tune
local TELEPORT_SLACK = 25 -- studs per check, for replication bursts -- tune
local STRIKES_TO_RESET = 2
local MAX_Y, MIN_Y = 40, -20
local RESET_HOLD = 0.5 -- seconds the server keeps ownership after a reset
local TOW_MIN_LENGTH = 12

local VehicleService = {}
VehicleService.Priority = 50

local spawnedEvent = Instance.new("BindableEvent")
-- Fires (player: Player, model: Model) after a vehicle is launched.
VehicleService.VehicleSpawned = spawnedEvent.Event

local records: { [Model]: Record } = {}
local byPlayer: { [Player]: Record } = {}
local towTargets: { [Model]: Record } = {} -- towed model -> tower record
local playerBay: { [Player]: number } = {}
local lastSpawn: { [Player]: number } = {}
local bays: { BasePart } = {}
local folder: Folder

-- ProgressionService (stream E), loaded lazily; false once a load failed.
local progression: any = nil
local function getProgression(): any
	if progression == nil then
		progression = false
		local module = script.Parent:FindFirstChild("ProgressionService")
		if module and module:IsA("ModuleScript") then
			local ok, result = pcall(require :: any, module)
			if ok and type(result) == "table" then
				progression = result
			else
				warn(
					`[VehicleService] ProgressionService failed to load, allowing all vehicles: {result}`
				)
			end
		end
	end
	return if progression then progression else nil
end

local function canUse(player: Player, vehicleId: string): boolean
	local p = getProgression()
	if not p or type(p.CanUseVehicle) ~= "function" then
		return true
	end
	local ok, result = pcall(p.CanUseVehicle, player, vehicleId)
	if not ok then
		warn(`[VehicleService] CanUseVehicle errored, allowing: {result}`)
		return true
	end
	return result == true
end

local function speedBonus(player: Player): number
	local p = getProgression()
	if not p or type(p.GetGearBonus) ~= "function" then
		return 1
	end
	local ok, result = pcall(p.GetGearBonus, player, "speed")
	return if ok and type(result) == "number" then math.clamp(result, 1, 3) else 1
end

local function setOwner(part: BasePart, player: Player?)
	if part.Anchored or not part:IsDescendantOf(Workspace) then
		return
	end
	local ok, err = pcall(part.SetNetworkOwner, part, player)
	if not ok then
		warn(`[VehicleService] SetNetworkOwner failed: {err}`)
	end
end

local function rootOf(model: Model): BasePart?
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	local part = model:FindFirstChildWhichIsA("BasePart", true)
	if part then
		model.PrimaryPart = part
	end
	return part
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

local function nearestBay(position: Vector3, radius: number): BasePart?
	local best, bestDist = nil, radius
	for _, bay in bays do
		local d = flatDistance(position, bay.Position)
		if d <= bestDist then
			best, bestDist = bay, d
		end
	end
	return best
end

local function speedLimit(record: Record): number
	local mult = record.model:GetAttribute("SpeedMultiplier")
	local m = if type(mult) == "number" then mult else 1
	return record.spec.topSpeed * m * SPEED_TOLERANCE + SPEED_SLACK
end

-- Network ownership of a tow target follows the tower's driver (nil = server).
local function updateTowOwnership(record: Record)
	local tow = record.tow
	if not tow then
		return
	end
	local targetRoot = rootOf(tow.target)
	if targetRoot then
		setOwner(targetRoot, record.driver)
	end
	tow.target:SetAttribute("TowedBy", if record.driver then record.driver.UserId else 0)
end

local function dock(record: Record)
	record.mode = "Dock"
	local root = record.root
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.Anchored = true
	local p = root.Position
	record.model:PivotTo(Simulator.restCFrame(record.model, p.X, p.Z, root.CFrame.LookVector))
	Simulator.clear(record.model)
end

local function drift(record: Record)
	record.mode = "Drift"
	record.root.Anchored = false
	setOwner(record.root, nil)
end

local function onDriverChanged(record: Record)
	local humanoid = record.seat.Occupant
	local player = if humanoid then Players:GetPlayerFromCharacter(humanoid.Parent) else nil
	if humanoid and player ~= record.owner then
		-- Owner-only driving for now. CONTRACT: CrewService.GetCrew could let crew take the helm.
		local weld = record.seat:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
		return
	end
	if player then
		record.driver = player
		record.mode = "Driven"
		record.root.Anchored = false
		setOwner(record.root, player)
		record.lastGood = record.root.CFrame
		record.strikes = 0
	else
		record.driver = nil
		if nearestBay(record.root.Position, DOCK_RADIUS) and not towTargets[record.model] then
			dock(record)
		else
			drift(record)
		end
	end
	updateTowOwnership(record)
end

local function bayBusy(bay: BasePart, player: Player): boolean
	for _, record in records do
		if record.owner ~= player and record.mode == "Dock" then
			if flatDistance(record.root.Position, bay.Position) < DOCK_RADIUS then
				return true
			end
		end
	end
	return false
end

local function bayFor(player: Player): BasePart?
	local index = playerBay[player]
	return if index then bays[(index - 1) % math.max(#bays, 1) + 1] else bays[1]
end

local function assignBay(player: Player)
	local used = {}
	for _, index in playerBay do
		used[index] = true
	end
	local count = math.max(#bays, GameConfig.LaunchBayCount)
	for i = 1, count do
		if not used[i] then
			playerBay[player] = i
			return
		end
	end
	playerBay[player] = (#Players:GetPlayers() - 1) % count + 1
end

local function bayAllows(bay: BasePart, vehicleId: string): boolean
	local allowed = bay:GetAttribute("AllowedVehicles")
	if type(allowed) ~= "string" or allowed == "" then
		return true
	end
	return table.find(string.split(allowed, ","), vehicleId) ~= nil
end

local function sitDriver(player: Player, seat: VehicleSeat)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (character and humanoid) or humanoid.Health <= 0 then
		return
	end
	if humanoid.SeatPart then
		humanoid.Sit = false
		local weld = humanoid.SeatPart:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
	end
	character:PivotTo(seat.CFrame * CFrame.new(0, 3, 0))
	seat:Sit(humanoid)
end

local function despawnModel(model: Model)
	local record = records[model]
	if not record then
		return
	end
	VehicleService.DetachTow(model)
	local tower = towTargets[model]
	if tower then
		VehicleService.DetachTow(tower.model)
	end
	VehicleService.RemoveSurvivors(model)
	records[model] = nil
	if byPlayer[record.owner] == record then
		byPlayer[record.owner] = nil
	end
	model:Destroy()
end

local function spawnVehicle(
	player: Player,
	vehicleId: string,
	bay: BasePart?
): (boolean, string | Model)
	local spec = VehicleConfig.get(vehicleId)
	if not spec then
		return false, "UnknownVehicle"
	end
	local now = os.clock()
	if lastSpawn[player] and now - lastSpawn[player] < SPAWN_COOLDOWN then
		return false, "Cooldown"
	end
	if not canUse(player, vehicleId) then
		return false, "Locked"
	end
	local at = bay or bayFor(player)
	if not at then
		return false, "NoBay"
	end
	if not bayAllows(at, vehicleId) then
		return false, "BayNotAllowed"
	end
	if bayBusy(at, player) then
		return false, "BayBusy"
	end
	lastSpawn[player] = now

	local old = byPlayer[player]
	if old then
		despawnModel(old.model)
	end

	local model = Builder.build(spec)
	model.Name = `{player.Name}_{spec.id}`
	model:SetAttribute("Owner", player.UserId)
	model:SetAttribute("SpeedMultiplier", speedBonus(player))
	model:PivotTo(Simulator.restCFrame(model, at.Position.X, at.Position.Z, at.CFrame.LookVector))
	model.Parent = folder

	local root = model.PrimaryPart :: BasePart
	local seat = model:FindFirstChild("DriverSeat") :: VehicleSeat
	local slots = {}
	for i = 1, spec.survivorCapacity do
		local slot = root:FindFirstChild(`SurvivorSlot{i}`)
		if slot and slot:IsA("Attachment") then
			table.insert(slots, slot)
		end
	end
	local record: Record = {
		model = model,
		owner = player,
		spec = spec,
		root = root,
		seat = seat,
		slots = slots,
		survivors = {},
		mode = "Dock",
		driver = nil,
		tow = nil,
		lastGood = root.CFrame,
		strikes = 0,
		resetting = false,
	}
	records[model] = record
	byPlayer[player] = record
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if records[model] == record then
			onDriverChanged(record)
		end
	end)
	sitDriver(player, seat)

	spawnedEvent:Fire(player, model)
	Net.event("VehicleSpawned"):FireAllClients(model, at.Name)
	return true, model
end

-- Pulls a cheating or broken boat back to its last good spot, server-owned for RESET_HOLD.
local function resetVehicle(record: Record, reason: string)
	warn(`[VehicleService] reset {record.model.Name}: {reason}`)
	record.resetting = true
	record.strikes = 0
	local root = record.root
	setOwner(root, nil)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	local good = record.lastGood
	record.model:PivotTo(Simulator.restCFrame(record.model, good.X, good.Z, good.LookVector))
	task.delay(RESET_HOLD, function()
		record.resetting = false
		if records[record.model] == record and record.driver then
			setOwner(root, record.driver)
			record.lastGood = root.CFrame
		end
	end)
end

local function checkVehicle(record: Record, dt: number)
	if record.mode ~= "Driven" or record.resetting then
		return
	end
	local root = record.root
	local pos = root.Position
	local v = root.AssemblyLinearVelocity
	local limit = speedLimit(record)
	local speed = Vector2.new(v.X, v.Z).Magnitude
	local moved = flatDistance(pos, record.lastGood.Position)
	local outOfBounds = pos.Y > MAX_Y
		or pos.Y < MIN_Y
		or Vector2.new(pos.X, pos.Z).Magnitude > GameConfig.MapRadius + 200
	if outOfBounds then
		resetVehicle(record, "out of bounds")
	elseif speed > limit or moved > limit * dt + TELEPORT_SLACK then
		record.strikes += 1
		if record.strikes >= STRIKES_TO_RESET then
			resetVehicle(record, `speed {math.floor(speed)} moved {math.floor(moved)}`)
		end
	else
		record.strikes = 0
		record.lastGood = root.CFrame
	end
end

local function towerDriven(model: Model): boolean
	local tower = towTargets[model]
	return tower ~= nil and tower.driver ~= nil
end

local function simulateServerOwned()
	local now = Workspace:GetServerTimeNow()
	for model, record in records do
		if not model.Parent then
			records[model] = nil
		elseif (record.mode == "Drift" and not towerDriven(model)) or record.resetting then
			Simulator.step(model, 0, 0, now)
		end
	end
	for target, tower in towTargets do
		if not target.Parent then
			VehicleService.DetachTow(tower.model)
		elseif not records[target] and not tower.driver then
			Simulator.step(target, 0, 0, now)
		end
	end
end

local function findBays()
	local map = Workspace:WaitForChild("Map", 10)
	if not map then
		warn("[VehicleService] Workspace.Map not found: no launch bays")
		return
	end
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("LaunchBay") then
			table.insert(bays, d)
		end
	end
	table.sort(bays, function(a, b)
		return (tonumber(a:GetAttribute("BayIndex")) or 0)
			< (tonumber(b:GetAttribute("BayIndex")) or 0)
	end)
end

-- Temporary launch UI: one ProximityPrompt per allowed vehicle on every bay.
local function addPrompts()
	local keys = { Enum.KeyCode.E, Enum.KeyCode.F, Enum.KeyCode.G }
	for _, bay in bays do
		local index = 0
		for _, id in VehicleConfig.Order do
			local spec = VehicleConfig.get(id)
			if spec and bayAllows(bay, id) then
				index += 1
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = `Launch_{id}`
				prompt.ActionText = `Launch {spec.displayName}`
				prompt.ObjectText = bay.Name
				prompt.KeyboardKeyCode = keys[index] or Enum.KeyCode.E
				prompt.HoldDuration = 0.3
				prompt.MaxActivationDistance = 16
				prompt.RequiresLineOfSight = false
				prompt.UIOffset = Vector2.new(0, (index - 1) * 72)
				prompt.Parent = bay
				prompt.Triggered:Connect(function(player)
					local ok, reason = spawnVehicle(player, id, bay)
					if not ok then
						warn(`[VehicleService] {player.Name} could not launch {id}: {reason}`)
					end
				end)
			end
		end
	end
end

function VehicleService.Init()
	local f = Instance.new("Folder")
	f.Name = "Vehicles"
	f.Parent = Workspace
	folder = f

	Net.func("RequestVehicle").OnServerInvoke = function(player: Player, vehicleId: unknown)
		if type(vehicleId) ~= "string" then
			return false, "BadRequest"
		end
		return spawnVehicle(player, vehicleId, nil)
	end

	Players.PlayerAdded:Connect(assignBay)
	for _, player in Players:GetPlayers() do
		assignBay(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local record = byPlayer[player]
		if record then
			despawnModel(record.model)
		end
		playerBay[player] = nil
		lastSpawn[player] = nil
	end)
end

function VehicleService.Start()
	RunService.PreSimulation:Connect(simulateServerOwned)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < CHECK_INTERVAL then
			return
		end
		local interval = acc
		acc = 0
		for _, record in records do
			checkVehicle(record, interval)
		end
	end)
	findBays()
	addPrompts()
end

-- API (CONTRACT.md, B) ---------------------------------------------------------------------------

function VehicleService.GetVehicle(player: Player): Model?
	local record = byPlayer[player]
	return if record then record.model else nil
end

function VehicleService.GetDriver(model: Model): Player?
	local record = records[model]
	return if record then record.driver else nil
end

-- Every player seated in the vehicle, driver first.
function VehicleService.GetOccupants(model: Model): { Player }
	local out = {}
	local record = records[model]
	if not record then
		return out
	end
	if record.driver then
		table.insert(out, record.driver)
	end
	for _, d in model:GetDescendants() do
		if d:IsA("Seat") and d.Occupant then
			local player = Players:GetPlayerFromCharacter(d.Occupant.Parent)
			if player and not table.find(out, player) then
				table.insert(out, player)
			end
		end
	end
	return out
end

-- Welds the survivor to the next free SurvivorSlot. False when the boat is full.
-- CONTRACT: CallService/RescueService stop moving a survivor by script while its
-- "OnVehicle" attribute is set (it holds the vehicle model's name).
function VehicleService.AddSurvivor(model: Model, survivorModel: Model): boolean
	local record = records[model]
	if not record then
		return false
	end
	local slotIndex = nil
	for i = 1, #record.slots do
		if not record.survivors[i] then
			slotIndex = i
			break
		end
	end
	local part = rootOf(survivorModel)
	if not slotIndex or not part then
		return false
	end
	for _, d in survivorModel:GetDescendants() do
		if d:IsA("BasePart") then
			d.Massless = true
			d.CanCollide = false
			d.Anchored = false
		end
	end
	local bbCF, size = survivorModel:GetBoundingBox()
	local pivotOffset = bbCF:ToObjectSpace(survivorModel:GetPivot())
	local slotCF = record.slots[slotIndex].WorldCFrame
	survivorModel:PivotTo(slotCF * CFrame.new(0, size.Y / 2, 0) * pivotOffset)
	local weld = Instance.new("WeldConstraint")
	weld.Name = "VehicleSurvivorWeld"
	weld.Part0 = record.root
	weld.Part1 = part
	weld.Parent = part
	local humanoid = survivorModel:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Sit = true
	end
	survivorModel:SetAttribute("OnVehicle", model.Name)
	record.survivors[slotIndex] = { model = survivorModel, weld = weld }
	local count = 0
	for _ in record.survivors do
		count += 1
	end
	model:SetAttribute("SurvivorCount", count)
	return true
end

-- Unwelds every survivor and returns them (anchored where they are; the caller moves them on).
function VehicleService.RemoveSurvivors(model: Model): { Model }
	local out = {}
	local record = records[model]
	if not record then
		return out
	end
	for i, survivor in record.survivors do
		survivor.weld:Destroy()
		for _, d in survivor.model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		survivor.model:SetAttribute("OnVehicle", nil)
		table.insert(out, survivor.model)
		record.survivors[i] = nil
	end
	model:SetAttribute("SurvivorCount", 0)
	return out
end

-- Ropes the target's BowPoint to this vehicle's TowHitch. Targets need a PrimaryPart (or any
-- BasePart) and should be welded into one assembly; anchored parts are unanchored.
-- CONTRACT: CallService stops moving a towed NPC boat by script while it has the VehicleTowed tag;
-- DetachTow re-anchors non-vehicle targets so script motion can resume.
function VehicleService.AttachTow(model: Model, targetModel: Model): boolean
	local record = records[model]
	if not record or not record.spec.canTow or record.tow then
		return false
	end
	if targetModel == model or towTargets[targetModel] or not targetModel:IsA("Model") then
		return false
	end
	local targetRecord = records[targetModel]
	if targetRecord and (targetRecord.driver or targetRecord.tow) then
		return false
	end
	local targetRoot = rootOf(targetModel)
	local hitch = record.root:FindFirstChild("TowHitch")
	if not targetRoot or not (hitch and hitch:IsA("Attachment")) then
		return false
	end
	local bow = targetModel:FindFirstChild("BowPoint", true)
	if not (bow and bow:IsA("Attachment")) then
		local created = Instance.new("Attachment")
		created.Name = "BowPoint"
		created.Position = Vector3.new(0, 0, -targetRoot.Size.Z / 2)
		created.Parent = targetRoot
		bow = created
	end
	assert(bow and bow:IsA("Attachment"), "unreachable")
	if not targetRecord then
		Simulator.ensureRig(targetModel)
	end
	for _, d in targetModel:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
		end
	end
	if targetRecord then
		targetRecord.mode = "Drift"
	end

	local rope = Instance.new("RopeConstraint")
	rope.Name = "TowRope"
	rope.Attachment0 = hitch
	rope.Attachment1 = bow
	rope.Length =
		math.max(TOW_MIN_LENGTH, (hitch.WorldPosition - bow.WorldPosition).Magnitude + 0.5)
	rope.Visible = true
	rope.Thickness = 0.25
	rope.Color = BrickColor.new("Institutional white")
	rope.Parent = record.root

	record.tow = { rope = rope, target = targetModel }
	towTargets[targetModel] = record
	targetModel:SetAttribute("TowVehicle", model.Name)
	CollectionService:AddTag(targetModel, TOW_TAG)
	updateTowOwnership(record)
	return true
end

function VehicleService.DetachTow(model: Model)
	local record = records[model]
	local tow = record and record.tow
	if not (record and tow) then
		return
	end
	record.tow = nil
	tow.rope:Destroy()
	local target = tow.target
	towTargets[target] = nil
	target:SetAttribute("TowedBy", nil)
	target:SetAttribute("TowVehicle", nil)
	CollectionService:RemoveTag(target, TOW_TAG)
	if not target.Parent then
		return
	end
	local targetRoot = rootOf(target)
	if not targetRoot then
		return
	end
	if records[target] then
		setOwner(targetRoot, nil) -- an empty vehicle keeps drifting, server-simulated
	else
		Simulator.clear(target)
		targetRoot.AssemblyLinearVelocity = Vector3.zero
		targetRoot.Anchored = true -- hand the NPC boat back to its script motion
	end
end

return VehicleService
