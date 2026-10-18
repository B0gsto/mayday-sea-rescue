--!strict
-- VehicleService (stream B): launches boats from the dock bays, one vehicle per player.
--
--   RequestVehicle (RemoteFunction, Net)  client asks for a vehicleId -> (ok, reasonOrVehicle)
--   Bay ProximityPrompts                 temporary launch UI until the HUD exists ("Launch Jet Ski")
--   Vehicle_ArrivalHandoff (RemoteEvent) after the arrival cinematic: unseat, dock, stand on the slipway
--
-- Vehicle states:
--   Dock    nobody driving and the hull is at a bay: HullRoot anchored (clients bob it visually)
--   Driven  the owner is in DriverSeat: unanchored, network owner = driver, whose client
--           (BoatController) runs buoyancy and controls. The server only sanity-checks speed and
--           position every CHECK_INTERVAL and pulls cheaters back to the last good spot.
--   Drift   nobody driving, away from the dock: unanchored, server-owned, the server runs buoyancy.
-- Tows: AttachTow ropes TowHitch to the target's BowPoint. An anchored non-vehicle target is a
-- scripted tow (TowScripted attribute): it stays anchored and its own script moves it, the rope is
-- a slack visual and nobody gets ownership. Otherwise the target's ownership goes to the
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
local AssetLoader = require(script.Parent.Parent:WaitForChild("Assets"):WaitForChild("AssetLoader"))
local Builder = require(Shared:WaitForChild("Boat"):WaitForChild("Builder"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local Net = require(Shared:WaitForChild("Net"))
local RespawnPolicy = require(Shared:WaitForChild("Boat"):WaitForChild("RespawnPolicy"))
local Simulator = require(Shared:WaitForChild("Boat"):WaitForChild("Simulator"))
local VehicleConfig = require(Shared:WaitForChild("Config"):WaitForChild("VehicleConfig"))
local Weather = require(Shared:WaitForChild("Weather"))

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
	tow: { rope: RopeConstraint, target: Model, scripted: boolean }?,
	lastGood: CFrame,
	strikes: number,
	resetting: boolean,
	wetUntil: number,
	spawnedAt: number, -- os.clock()
	lastOccupiedAt: number?, -- os.clock() when the last rider left (RespawnPolicy)
}

local TOW_TAG = "VehicleTowed"
local SPAWN_COOLDOWN = 2 -- seconds between launches per player
local DOCK_RADIUS = 14 -- an emptied hull this close to a bay centre docks (anchors) -- tune
local CHECK_INTERVAL = 0.5 -- seconds between sanity checks
local SWEEP_INTERVAL = 5 -- seconds between idle / wreck sweeps (RespawnPolicy)
-- Real models per vehicle id (AssetIds names, LOD0; the first is required, the rest optional). A
-- vehicle whose first model fails to load is built as the greybox.
local VISUAL_ASSETS: { [string]: { string } } = {
	RIB = { "M_Veh_RIB", "M_Veh_RIB_Helm" },
	-- the close-up (first-person) set is built in hidden; the rider's client shows it (FirstPerson)
	JetSki = { "M_Veh_JetSki", "M_Veh_JetSki_CloseUp" },
}
-- Wet look (SurfaceAppearance _Wet, attribute Wet on the model): rain/storm at or over this
-- intensity, spray while running at planing speed, or a SprayHit attribute set by any system;
-- dries DRY_TIME seconds after the last of them.
local WET_INTENSITY = 0.3 -- Weather.getIntensity -- tune
local DRY_TIME = 20 -- tune
-- Anti-teleport: the limit is speed-based, relative to the vehicle's own top speed (x gear bonus).
-- A check fails when the hull's speed, or its distance from the last good spot divided by the time
-- since, beats topSpeed * SPEED_TOLERANCE + SPEED_SLACK (surfing a wave face and wake pushes add
-- speed), plus TELEPORT_SLACK studs for a replication burst. STRIKES_TO_RESET failures in a row
-- reset the hull. At 0.5 s checks a jet ski may move about 63 studs per check, a RIB about 51.
-- Studio only: attribute StudioBypassChecks = true on the vehicle model or on Workspace skips the
-- check (test scripts that PivotTo a boat); ignored in live servers.
local SPEED_TOLERANCE = 1.3 -- x top speed -- tune
local SPEED_SLACK = 8 -- studs/s -- tune
local TELEPORT_SLACK = 12 -- studs per check -- tune
local BYPASS_ATTRIBUTE = "StudioBypassChecks"
local IS_STUDIO = RunService:IsStudio()
local STRIKES_TO_RESET = 2
local MAX_Y, MIN_Y = 40, -20
local RESET_HOLD = 0.5 -- seconds the server keeps ownership after a reset
local TOW_MIN_LENGTH = 12
local SCRIPTED_TOW_SLACK = 10 -- extra rope on scripted tows so latency never makes it bind

local VehicleService = {}
VehicleService.Priority = 50

local spawnedEvent = Instance.new("BindableEvent")
-- Fires (player: Player, model: Model) after a vehicle is launched.
VehicleService.VehicleSpawned = spawnedEvent.Event

local records: { [Model]: Record } = {}
local byPlayer: { [Player]: Record } = {} -- the player's current vehicle (GetVehicle)
local owned: { [Player]: { [string]: Record } } = {} -- one record per player per vehicle class
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
	if not tow or tow.scripted then
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
		byPlayer[player] = record -- riding an older craft of theirs makes it current again
		record.model:SetAttribute("EngineRunning", true)
		record.mode = "Driven"
		record.root.Anchored = false
		setOwner(record.root, player)
		record.lastGood = record.root.CFrame
		record.strikes = 0
	else
		record.driver = nil
		if record.spec.killCord then
			-- The helm's kill cord pulls out with them: the engine stops (Buoyancy.thrust).
			record.model:SetAttribute("EngineRunning", false)
			record.model:SetAttribute("KillCordPulledAt", Workspace:GetServerTimeNow())
		end
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
	local function place()
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") then
				d.AssemblyLinearVelocity = Vector3.zero
				d.AssemblyAngularVelocity = Vector3.zero
			end
		end
		character:PivotTo(seat.CFrame * CFrame.new(0, 3, 0))
		seat:Sit(humanoid)
	end
	place()
	-- a character just taken off another seat can miss the first Sit: check and retry once
	task.delay(0.5, function()
		if seat.Parent and humanoid.Parent and humanoid.Health > 0 and seat.Occupant == nil then
			place()
		end
	end)
end

-- Seated players ride massless: VehicleConfig.massHint already includes the crew at real weight
-- (a Roblox avatar weighs as much as the whole jet ski at our 37 kg/RMU scale). Restored on exit.
local masslessParts: { [Seat | VehicleSeat]: { BasePart } } = {}

local function setRiderMassless(seat: Seat | VehicleSeat)
	local previous = masslessParts[seat]
	if previous then
		for _, part in previous do
			if part.Parent then
				part.Massless = false
			end
		end
		masslessParts[seat] = nil
	end
	local humanoid = seat.Occupant
	local character = humanoid and humanoid.Parent
	if not character then
		return
	end
	local parts = {}
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") and not d.Massless then
			d.Massless = true
			table.insert(parts, d)
		end
	end
	masslessParts[seat] = parts
end

local function watchSeats(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("Seat") or d:IsA("VehicleSeat") then
			local seatPart = d :: Seat | VehicleSeat
			seatPart:GetPropertyChangedSignal("Occupant"):Connect(function()
				setRiderMassless(seatPart)
				local record = records[model]
				if record then
					record.lastOccupiedAt = os.clock() -- someone sat down or just left
				end
			end)
			seatPart.Destroying:Connect(function()
				masslessParts[seatPart] = nil
			end)
		end
	end
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
	local classes = owned[record.owner]
	if classes and classes[record.spec.id] == record then
		classes[record.spec.id] = nil
	end
	model:Destroy()
end

-- Respawn rules (shared/Boat/RespawnPolicy) -----------------------------------------------------

-- Anyone seated anywhere on the craft. The owner's own SeatPart counts too: it can still point at
-- the seat while a weld drop (hull pitching over a wave) has briefly cleared seat.Occupant.
local function isOccupied(record: Record): boolean
	for _, d in record.model:GetDescendants() do
		if (d:IsA("Seat") or d:IsA("VehicleSeat")) and (d :: any).Occupant then
			return true
		end
	end
	local character = record.owner.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	return seat ~= nil and seat:IsDescendantOf(record.model)
end

local function policyState(record: Record): RespawnPolicy.State
	local occupied = isOccupied(record)
	if occupied then
		record.lastOccupiedAt = os.clock()
	end
	local pos = record.root.Position
	local character = record.owner.Character
	local ownerPos = character and character.PrimaryPart and character.PrimaryPart.Position
	return {
		occupied = occupied,
		carrying = next(record.survivors) ~= nil
			or record.tow ~= nil
			or towTargets[record.model] ~= nil,
		lastOccupiedAt = record.lastOccupiedAt,
		spawnedAt = record.spawnedAt,
		docked = record.mode == "Dock",
		current = byPlayer[record.owner] == record,
		wrecked = record.model:GetAttribute("Wrecked") == true
			or pos.Y < MIN_Y
			or Vector2.new(pos.X, pos.Z).Magnitude > GameConfig.MapRadius + 200,
		ownerDistance = if ownerPos then (ownerPos - pos).Magnitude else nil,
	}
end

-- Periodic sweep: clears idle, superseded or wrecked vehicles nobody is (or just was) aboard.
local function sweepVehicles()
	local now = os.clock()
	for model, record in table.clone(records) do
		local state = policyState(record)
		local idle = RespawnPolicy.mayRemove("Idle", state, now)
		local wrecked = RespawnPolicy.mayRemove("Wrecked", state, now)
		if idle or wrecked then
			print(`[VehicleService] clearing {model.Name}: {if idle then "idle" else "wrecked"}`)
			despawnModel(model)
		end
	end
end

-- Builds the player's vehicle floating at rest at `at` (X, Z and heading; Y from the waves),
-- replacing their old one, and registers it. The caller seats the driver.
-- Clones of the vehicle's real models (yields on the first load), or nil for the greybox.
local function visualsFor(spec: VehicleSpec): { Model }?
	local names = VISUAL_ASSETS[spec.id]
	if not names then
		return nil
	end
	local visuals = {}
	for i, name in names do
		local clone = AssetLoader.clone(name)
		if clone then
			table.insert(visuals, clone)
		elseif i == 1 then
			warn(`[VehicleService] {spec.id}: {name} did not load; building the greybox`)
			for _, v in visuals do
				v:Destroy()
			end
			return nil
		else
			warn(`[VehicleService] {spec.id}: optional model {name} did not load`)
		end
	end
	return visuals
end

-- Rain, storm or spray wets the real model (see WET_INTENSITY); the attribute drives the swap.
local function updateWet(record: Record)
	local model = record.model
	if model:GetAttribute("Visual") == "Greybox" then
		return
	end
	local now = os.clock()
	local speed = record.root.AssemblyLinearVelocity.Magnitude
	local planing = record.spec.planingSpeed * record.spec.topSpeed
	-- SprayHit: any system (spray FX, green water over the bow) sets it true to wet the boat now
	local sprayHit = model:GetAttribute("SprayHit") == true
	if sprayHit then
		model:SetAttribute("SprayHit", nil)
	end
	if
		sprayHit
		or Weather.getIntensity() >= WET_INTENSITY
		or (record.mode == "Driven" and speed >= planing)
	then
		record.wetUntil = now + DRY_TIME
	end
	local wet = now < record.wetUntil
	if model:GetAttribute("Wet") ~= wet then
		model:SetAttribute("Wet", wet)
	end
end

-- What a spawn of `spec` should do with the player's vehicles (RespawnPolicy.planSpawn on the
-- same class). Other classes they own go too unless someone is (or just was) aboard.
local function planSpawn(
	player: Player,
	spec: VehicleSpec,
	reason: RespawnPolicy.Reason
): (RespawnPolicy.Plan, Record?, string)
	local classes = owned[player]
	local existing: Record? = classes and classes[spec.id]
	if existing and not existing.model.Parent then
		despawnModel(existing.model)
		existing = nil
	end
	local now = os.clock()
	local plan, why =
		RespawnPolicy.planSpawn(reason, if existing then policyState(existing) else nil, now)
	return plan :: any, existing, why
end

local function clearOtherClasses(player: Player, spec: VehicleSpec, reason: RespawnPolicy.Reason)
	local classes = owned[player]
	if not classes then
		return
	end
	local now = os.clock()
	for id, record in table.clone(classes) do
		if id ~= spec.id and RespawnPolicy.mayRemove(reason, policyState(record), now) then
			despawnModel(record.model)
		end
	end
end

-- Call only after planSpawn said Build or Replace.
local function createVehicle(
	player: Player,
	spec: VehicleSpec,
	at: CFrame,
	reason: RespawnPolicy.Reason
): (Model, VehicleSeat)
	local visuals = visualsFor(spec)
	clearOtherClasses(player, spec, reason)
	local classes = owned[player]
	local old = classes and classes[spec.id]
	if old then
		-- unseat the driver first: destroying the craft under a seated character leaves the client
		-- holding a stale seat weld, and the replacement's seat:Sit fails (rider flung, camera in
		-- the sea, a runaway speed reading)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seatPart = humanoid and humanoid.SeatPart
		if humanoid and seatPart and seatPart:IsDescendantOf(old.model) then
			local weld = seatPart:FindFirstChild("SeatWeld")
			if weld then
				weld:Destroy()
			end
			humanoid.Sit = false
		end
		despawnModel(old.model)
	end

	local model = Builder.build(spec, visuals)
	if visuals then
		model:GetAttributeChangedSignal("Wet"):Connect(function()
			AssetLoader.setWet(model, model:GetAttribute("Wet") == true)
		end)
	end
	model.Name = `{player.Name}_{spec.id}`
	model:SetAttribute("Owner", player.UserId)
	model:SetAttribute("SpeedMultiplier", speedBonus(player))
	model:SetAttribute("EngineRunning", false)
	model:PivotTo(Simulator.restCFrame(model, at.X, at.Z, at.LookVector))
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
		wetUntil = 0,
		spawnedAt = os.clock(),
		lastOccupiedAt = nil,
	}
	records[model] = record
	byPlayer[player] = record
	owned[player] = owned[player] or {}
	owned[player][spec.id] = record
	watchSeats(model)
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if records[model] == record then
			onDriverChanged(record)
		end
	end)
	return model, seat
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
	local plan, _, why = planSpawn(player, spec, "Request")
	if plan == "Refuse" then
		return false, why -- "Occupied": someone is aboard their current one
	end
	lastSpawn[player] = now

	local model, seat = createVehicle(player, spec, at.CFrame, "Request")
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
	if
		IS_STUDIO
		and (
			record.model:GetAttribute(BYPASS_ATTRIBUTE) == true
			or Workspace:GetAttribute(BYPASS_ATTRIBUTE) == true
		)
	then
		record.strikes = 0
		record.lastGood = root.CFrame
		return
	end
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
		-- dt is the time since the last check, and lastGood was taken at that check
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
		elseif
			not records[target]
			and not tower.driver
			and not (tower.tow and tower.tow.scripted)
		then
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

-- Arrival handoff (after the cold open's arrival cinematic) -----------------------------------
-- Vehicle_ArrivalHandoff (RemoteEvent, ReplicatedStorage.Net):
--   C->S ()                            the arrival cinematic ended (or was skipped)
--   S->C { stand: CFrame, look: Vector3, vehicle: string }   where the player now stands
-- Once per cold open (SpawnColdOpen arms it, ColdOpenDone must be true): the server unseats the
-- player, docks the jet ski at their bay (despawns it when the bay is busy or missing), and
-- pivots the character onto the station slipway facing Chief Aggie's spot. Player attribute
-- ArrivalHandoff = "Docked:<bay>" / "Despawned" / "NoVehicle" for Studio tests.
local HANDOFF_REMOTE = "Vehicle_ArrivalHandoff"
local SLIPWAY_STAND = 10 -- studs down the ramp from its top edge (dry, above the waterline) -- tune
local AGGIE_POINT_NAMES = { "ChiefAggie", "AggieSpot", "Aggie" }
local coldOpenRiders: { [Player]: Model } = {} -- the cold-open vehicle, until the handoff
local handoffRemote: RemoteEvent? = nil

local function worldPoint(names: { string }, kind: string?): BasePart?
	local map = Workspace:FindFirstChild("Map")
	local points = map and map:FindFirstChild("WorldPoints")
	if not points then
		return nil
	end
	for _, name in names do
		local p = points:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			return p
		end
	end
	if kind then
		for _, p in points:GetChildren() do
			if p:IsA("BasePart") and p:GetAttribute("PointKind") == kind then
				return p
			end
		end
	end
	return nil
end

-- (stand position on the ramp, Aggie's spot) from the slipway geometry in map/Build.luau, the
-- WorldPoints "StationSlipway" marker (WorldConfig.Points) as a fallback.
local function slipwaySpots(): (Vector3?, Vector3?)
	local map = Workspace:FindFirstChild("Map")
	local slips = map and map:FindFirstChild("Slipways")
	local ramp = slips and slips:FindFirstChild("StationSlipway")
	local stand: Vector3?, top: Vector3? = nil, nil
	if ramp and ramp:IsA("BasePart") then
		local half = ramp.Size / 2
		-- the ramp's local -Z end is the top, at the quay
		top = (ramp.CFrame * CFrame.new(0, half.Y, -half.Z)).Position
		stand = (ramp.CFrame * CFrame.new(0, half.Y, -half.Z + SLIPWAY_STAND)).Position
	else
		local marker = worldPoint({ "StationSlipway" }, nil)
		if marker then
			stand = marker.Position
			top = marker.Position + Vector3.new(0, 0, -SLIPWAY_STAND * 2)
		end
	end
	local aggie = worldPoint(AGGIE_POINT_NAMES, "Aggie")
	local look: Vector3? = if aggie then aggie.Position else nil
	if not look and top and stand then
		look = top + (top - stand) * Vector3.new(0.6, 0, 0.6) -- just onto the quay
	end
	return stand, look
end

local function standOnGround(character: Model, at: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { folder }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	local hit = Workspace:Raycast(at + Vector3.new(0, 12, 0), Vector3.new(0, -30, 0), params)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local lift = (if humanoid then humanoid.HipHeight else 2)
		+ (if root then root.Size.Y / 2 else 1)
		+ 0.2
	return (if hit then hit.Position else at) + Vector3.new(0, lift, 0)
end

local function unseat(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local seat = humanoid.SeatPart
	if seat then
		local weld = seat:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
	end
	humanoid.Sit = false
end

-- Docks the player's vehicle at their bay; despawns it when that is not possible.
local function stowVehicle(player: Player): string
	local record = byPlayer[player]
	if not record then
		return "NoVehicle"
	end
	VehicleService.DetachTow(record.model)
	local bay = bayFor(player)
	if bay and bayAllows(bay, record.spec.id) and not bayBusy(bay, player) then
		record.model:PivotTo(
			Simulator.restCFrame(
				record.model,
				bay.Position.X,
				bay.Position.Z,
				bay.CFrame.LookVector
			)
		)
		dock(record)
		record.model:SetAttribute("EngineRunning", false)
		return `Docked:{bay.Name}`
	end
	despawnModel(record.model)
	return "Despawned"
end

local function arrivalHandoff(player: Player)
	if not coldOpenRiders[player] or player:GetAttribute("ColdOpenDone") ~= true then
		return
	end
	local character = player.Character
	if not character or not character.PrimaryPart then
		return
	end
	local coldOpenModel = coldOpenRiders[player]
	coldOpenRiders[player] = nil
	-- only while still in (or just off) the cold-open craft: a player already in another boat
	-- (collected at the desk) or a car is never yanked out by a late handoff (integration-D)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if seat and not seat:IsDescendantOf(coldOpenModel) then
		player:SetAttribute("ArrivalHandoff", "Skipped")
		return
	end
	unseat(character)
	local vehicle = stowVehicle(player)
	local stand, look = slipwaySpots()
	if not stand then
		warn("[VehicleService] arrival handoff: no StationSlipway found, player left in place")
		player:SetAttribute("ArrivalHandoff", vehicle)
		return
	end
	local pos = standOnGround(character, stand)
	local face = look or (pos + Vector3.new(0, 0, -1))
	local cf = CFrame.lookAt(pos, Vector3.new(face.X, pos.Y, face.Z))
	local root = character.PrimaryPart :: BasePart
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	character:PivotTo(cf)
	player:SetAttribute("ArrivalHandoff", vehicle)
	print(`[VehicleService] arrival handoff: {player.Name} on foot at slipway, vehicle {vehicle}`)
	if handoffRemote then
		handoffRemote:FireClient(player, { stand = cf, look = face, vehicle = vehicle })
	end
end

function VehicleService.Init()
	local f = Instance.new("Folder")
	f.Name = "Vehicles"
	f.Parent = Workspace
	folder = f

	local net = ReplicatedStorage:WaitForChild("Net")
	local remote = Instance.new("RemoteEvent")
	remote.Name = HANDOFF_REMOTE
	remote.Parent = net
	handoffRemote = remote
	remote.OnServerEvent:Connect(arrivalHandoff)

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
		local classes: { [string]: Record } = owned[player] or {}
		for _, record in table.clone(classes) do
			despawnModel(record.model)
		end
		owned[player] = nil
		byPlayer[player] = nil
		playerBay[player] = nil
		lastSpawn[player] = nil
		coldOpenRiders[player] = nil
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
			updateWet(record)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(SWEEP_INTERVAL)
			local ok, err = pcall(sweepVehicles :: any)
			if not ok then
				warn(`[VehicleService] sweep failed: {err}`)
			end
		end
	end)
	findBays()
	addPrompts()
	local preload = {}
	for _, names in VISUAL_ASSETS do
		for _, name in names do
			table.insert(preload, name)
		end
	end
	AssetLoader.preload(preload)
end

-- API (CONTRACT.md, B) ---------------------------------------------------------------------------

-- Cold open: spawns the player's vehicle at `cframe` (X, Z and heading; it floats on the waves),
-- seats them at the helm and gives it initialSpeed studs/s ahead. Skips bays, cooldown and
-- progression checks (the cold-open jet ski is free). The owning client applies the speed too
-- (LaunchSpeed attribute, BoatController), since it simulates the hull once seated.
-- `reason` (RespawnPolicy.Reason, default "Request": the trailer launch is the player's own act)
-- decides what happens to a craft of that class they already own: "Scripted" spawns (the cold
-- open) reuse it in place, seating the player if needed, when someone is or just was aboard.
-- Never destroys a vehicle with a rider: returns nil when a Request meets an occupied one.
function VehicleService.SpawnSeated(
	player: Player,
	vehicleId: string,
	cframe: CFrame,
	initialSpeed: number?,
	reason: RespawnPolicy.Reason?
): Model?
	local spec = VehicleConfig.get(vehicleId)
	if not spec then
		warn(`[VehicleService] SpawnSeated: unknown vehicle {vehicleId}`)
		return nil
	end
	local why: RespawnPolicy.Reason = reason or "Request"
	local plan, existing, detail = planSpawn(player, spec, why)
	if plan == "Refuse" then
		warn(`[VehicleService] SpawnSeated: {player.Name}'s {vehicleId} kept ({detail})`)
		return nil
	elseif plan == "Reuse" and existing then
		byPlayer[player] = existing
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seatPart = humanoid and humanoid.SeatPart
		if not (seatPart and seatPart:IsDescendantOf(existing.model)) then
			sitDriver(player, existing.seat)
		end
		print(`[VehicleService] SpawnSeated: reusing {existing.model.Name} ({detail})`)
		return existing.model
	end
	local model, seat = createVehicle(player, spec, cframe, why)
	local speed = math.clamp(initialSpeed or 0, 0, spec.topSpeed)
	local root = model.PrimaryPart :: BasePart
	if speed > 0 then
		model:SetAttribute("LaunchSpeed", speed)
		root.Anchored = false
		local look = root.CFrame.LookVector
		root.AssemblyLinearVelocity = Vector3.new(look.X, 0, look.Z).Unit * speed
		task.delay(3, function()
			if model.Parent then
				model:SetAttribute("LaunchSpeed", nil)
			end
		end)
	end
	sitDriver(player, seat)
	spawnedEvent:Fire(player, model)
	Net.event("VehicleSpawned"):FireAllClients(model, "ColdOpen")
	return model
end

-- Cold open (CONTRACT: Operations v2): a jet ski at `cframe`, the player seated, already running
-- at about 20 knots, the speed BoatController's cold-open auto-throttle then holds until it hands
-- over (shared/Boat/ColdOpen.AUTO_SPEED). A thin wrapper over SpawnSeated; OperationService calls
-- it through pcall and then marks the jet ski (ColdOpen* attributes).
VehicleService.ColdOpenVehicle = "JetSki"
VehicleService.ColdOpenSpeed = 20 * VehicleConfig.KNOT -- 30.9 studs/s

function VehicleService.SpawnColdOpen(player: Player, cframe: CFrame): Model?
	local model = VehicleService.SpawnSeated(
		player,
		VehicleService.ColdOpenVehicle,
		cframe,
		VehicleService.ColdOpenSpeed,
		"Scripted" -- a re-run cold open never rebuilds the jet ski the player is riding
	)
	if model then
		coldOpenRiders[player] = model -- arms the arrival handoff (Vehicle_ArrivalHandoff)
		model:SetAttribute("ColdOpen", true) -- the client's arrival shot keys on this craft
		player:SetAttribute("ArrivalHandoff", nil)
	end
	return model
end

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
-- BasePart) and should be welded into one assembly. Anchored non-vehicle targets are scripted tows.
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
	-- Scripted tow: an anchored non-vehicle target (RescueService's NPC boats) stays anchored and is
	-- moved by its own script along the line. The rope is only a visual with slack (ScriptedLength
	-- is the nominal length the script keeps), and there is no ownership handoff.
	local scripted = targetRecord == nil and targetRoot.Anchored
	if not scripted then
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
	end

	local nominal =
		math.max(TOW_MIN_LENGTH, (hitch.WorldPosition - bow.WorldPosition).Magnitude + 0.5)
	local rope = Instance.new("RopeConstraint")
	rope.Name = "TowRope"
	rope.Attachment0 = hitch
	rope.Attachment1 = bow
	rope.Length = if scripted then nominal + SCRIPTED_TOW_SLACK else nominal
	if scripted then
		rope:SetAttribute("ScriptedLength", nominal)
	end
	rope.Visible = true
	rope.Thickness = 0.25
	rope.Color = BrickColor.new("Institutional white")
	rope.Parent = record.root

	record.tow = { rope = rope, target = targetModel, scripted = scripted }
	towTargets[targetModel] = record
	targetModel:SetAttribute("TowVehicle", model.Name)
	targetModel:SetAttribute("TowScripted", if scripted then true else nil)
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
	target:SetAttribute("TowScripted", nil)
	CollectionService:RemoveTag(target, TOW_TAG)
	if not target.Parent or tow.scripted then
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
