--!strict
-- LandVehicleService: the station's pool vehicles on land (docs 10 section 3, docs 02 section 4.3).
-- One land vehicle per player (a boat is separate, VehicleService). Raycast chassis in
-- src/shared/Car; the driver's client simulates (CarController), the server owns spawning, rank
-- checks, sanity checks, lights, horn, trailer launches and despawning.
--
--   Land_Request  (RemoteFunction, ReplicatedStorage.Net) (vehicleId, pointId?, withTrailer?)
--                 -> (ok, reason | Model)
--   Land_Control  (RemoteEvent C->S) (action, value): "Horn" bool, "Siren" bool, "LightBar" bool,
--                 "Headlights" bool, "Launch"
--   Land_Spawned  (RemoteEvent S->C) (model)
--   Spawn point ProximityPrompts are the temporary UI ("Take Lifeguard 4x4").
--
-- States: Parked (anchored, nobody driving), Driven (owner in DriverSeat: unanchored, network
-- owner = driver), Coast (left while moving: the server runs the chassis with the handbrake on
-- until it stops, then parks). Model attributes: VehicleId, Owner, LandVehicle, CameraMode
-- ("Chase"), CockpitView, Headlights, LightBar, Siren, Horn, CanLaunch, Towing, ExtraMassKg.
-- A towing car holds an ObjectValue "Trailer"; the trailer is a separate model on a
-- BallSocketConstraint (TowHitch -> Coupler) with its own raycast wheels.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarFolder = Shared:WaitForChild("Car")
local Builder = require(CarFolder:WaitForChild("Builder"))
local LandVehicleConfig = require(Shared:WaitForChild("Config"):WaitForChild("LandVehicleConfig"))
local Physics = require(CarFolder:WaitForChild("Physics"))
local Trailer = require(CarFolder:WaitForChild("Trailer"))
local Tyre = require(CarFolder:WaitForChild("Tyre"))
local VehicleConfig = require(Shared:WaitForChild("Config"):WaitForChild("VehicleConfig"))
local Weather = require(Shared:WaitForChild("Weather"))

type Spec = LandVehicleConfig.Spec
type SpawnPoint = LandVehicleConfig.SpawnPoint

type Record = {
	model: Model,
	owner: Player,
	spec: Spec,
	root: BasePart,
	seat: VehicleSeat,
	sim: Physics.Sim,
	mode: "Parked" | "Driven" | "Coast",
	trailer: Model?,
	trailerSim: Physics.Sim?,
	boatId: string?,
	emptySince: number,
	stillFor: number,
	lastGood: CFrame,
	strikes: number,
	resetting: boolean,
}

local GROUP = "LandVehicle"
local SPAWN_COOLDOWN = 3
local CHECK_INTERVAL = 0.5
local SPEED_TOLERANCE = 1.3 -- x top speed -- tune
local SPEED_SLACK = 10 -- studs/s (downhill, airborne off a dune) -- tune
local TELEPORT_SLACK = 14
local STRIKES_TO_RESET = 2
local MAX_Y, MIN_Y = 400, -45
local DROWN_DEPTH = 4.5 -- studs of water over the floor (1.5 m) before a reset to dry land
local HORN_MAX = 4 -- seconds a horn press can last
local CONTROL_GAP = 0.08 -- seconds between control messages per player
local BYPASS_ATTRIBUTE = "StudioBypassChecks"
local IS_STUDIO = RunService:IsStudio()

local LandVehicleService = {}
LandVehicleService.Priority = 110

local spawnedEvent = Instance.new("BindableEvent")
LandVehicleService.VehicleSpawned = spawnedEvent.Event -- (player, model)

local records: { [Model]: Record } = {}
local byPlayer: { [Player]: Record } = {}
local lastSpawn: { [Player]: number } = {}
local lastControl: { [Player]: number } = {}
local folder: Folder
local spawnPoints: { SpawnPoint } = LandVehicleConfig.SpawnPoints
local spawnedRemote: RemoteEvent

-- Optional sibling services ---------------------------------------------------------------------

local function sibling(name: string): any
	local m = script.Parent:FindFirstChild(name)
	if not (m and m:IsA("ModuleScript")) then
		return nil
	end
	local ok, result = pcall(require, m)
	return if ok then result else nil
end

-- Rank gate (docs 10 section 3.1). ProgressionService.CanUseVehicle answers "Unknown vehicle" for
-- the land fleet until ProgressionConfig.Vehicles lists it (CONTRACT for stream E); meanwhile the
-- spec's unlockRank is checked against GetData().rankIndex.
local function canUse(player: Player, vehicleId: string, unlockRank: number): (boolean, string)
	local p = sibling("ProgressionService")
	if not p then
		return true, "ok"
	end
	if type(p.CanUseVehicle) == "function" then
		local ok, allowed, reason = pcall(p.CanUseVehicle, player, vehicleId)
		if ok and allowed == true then
			return true, "ok"
		end
		if ok and reason ~= "Unknown vehicle" then
			return false, if type(reason) == "string" then reason else "Locked"
		end
	end
	if type(p.GetData) == "function" then
		local ok, data = pcall(p.GetData, player)
		if ok and type(data) == "table" and type(data.rankIndex) == "number" then
			return data.rankIndex >= unlockRank, "Needs a higher rank"
		end
	end
	return unlockRank <= 1, "Locked"
end

local function canUseBoat(player: Player, boatId: string): boolean
	local p = sibling("ProgressionService")
	if not (p and type(p.CanUseVehicle) == "function") then
		return true
	end
	local ok, allowed = pcall(p.CanUseVehicle, player, boatId)
	return not ok or allowed == true
end

-- Helpers ---------------------------------------------------------------------------------------

local function setOwner(part: BasePart?, player: Player?)
	if not part or part.Anchored or not part:IsDescendantOf(Workspace) then
		return
	end
	local ok, err = pcall(part.SetNetworkOwner, part, player)
	if not ok then
		warn(`[LandVehicleService] SetNetworkOwner failed: {err}`)
	end
end

local function setAnchored(record: Record, anchored: boolean)
	record.root.Anchored = anchored
	local trailerRoot = record.trailer and record.trailer.PrimaryPart
	if trailerRoot then
		trailerRoot.Anchored = anchored
	end
	if anchored then
		Physics.idle(record.sim)
		if record.trailerSim then
			Physics.idle(record.trailerSim)
		end
	end
end

local function characters(): { Instance }
	local list = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	return list
end

local function groundY(position: Vector3, ignore: { Instance }): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	local hit = Workspace:Raycast(position + Vector3.new(0, 60, 0), Vector3.new(0, -160, 0), params)
	return if hit then hit.Position.Y else position.Y
end

local function waterAt(position: Vector3): number
	local ok, h = pcall(Weather.heightAt, position)
	return if ok and type(h) == "number" then h else 0
end

local function flat(v: Vector3): number
	return Vector2.new(v.X, v.Z).Magnitude
end

local function setHeadlights(model: Model, on: boolean)
	model:SetAttribute("Headlights", on)
	for _, d in model:GetDescendants() do
		if
			d:IsA("SpotLight")
			and d.Name ~= "Floodlight"
			and d.Parent
			and d.Parent.Name == "Headlamp"
		then
			d.Enabled = on
		end
	end
end

local function setFloodlights(model: Model, on: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("SpotLight") and d.Name == "Floodlight" then
			d.Enabled = on
		end
	end
end

local function darkOrWet(): boolean
	local t = Lighting.ClockTime
	local ok, intensity = pcall(Weather.getIntensity)
	return t < 7
		or t > 19.5
		or (ok and type(intensity) == "number" and Tyre.wetness(intensity) > 0.4)
end

-- Spawning --------------------------------------------------------------------------------------

local function loadWorldSpawns()
	-- TODO(WorldConfig): the terrain stream's WorldConfig.LandVehicleSpawns, when it exists,
	-- replaces the placeholder points (same SpawnPoint shape as LandVehicleConfig.SpawnPoints).
	local configFolder = Shared:FindFirstChild("Config")
	local module = configFolder and configFolder:FindFirstChild("WorldConfig")
	if module and module:IsA("ModuleScript") then
		local ok, world = pcall(require, module)
		if ok and type(world) == "table" and type((world :: any).LandVehicleSpawns) == "table" then
			spawnPoints = (world :: any).LandVehicleSpawns
		end
	end
end

local function pointById(id: string): SpawnPoint?
	for _, p in spawnPoints do
		if p.id == id then
			return p
		end
	end
	return nil
end

local function pointAllows(point: SpawnPoint, vehicleId: string): boolean
	return table.find(point.vehicles, vehicleId) ~= nil
end

-- docs 10 section 3.2: the nearest open point to the player that holds the vehicle.
local function nearestPoint(player: Player, vehicleId: string, withTrailer: boolean): SpawnPoint?
	local character = player.Character
	local at = if character then character:GetPivot().Position else Vector3.zero
	local best, bestDist = nil, math.huge
	for _, p in spawnPoints do
		if pointAllows(p, vehicleId) and (not withTrailer or p.trailers) then
			local dist = (p.cframe.Position - at).Magnitude
			if dist < bestDist then
				best, bestDist = p, dist
			end
		end
	end
	return best
end

local function freeBay(point: SpawnPoint, player: Player): CFrame?
	for i = 0, point.bays - 1 do
		local cf = point.cframe * CFrame.new(point.step * i)
		local busy = false
		for model, record in records do
			if
				record.owner ~= player
				and (model:GetPivot().Position - cf.Position).Magnitude < 8
			then
				busy = true
				break
			end
		end
		if not busy then
			return cf
		end
	end
	return nil
end

local onSeatChanged: (Record) -> () -- set below

local function despawn(record: Record)
	records[record.model] = nil
	if byPlayer[record.owner] == record then
		byPlayer[record.owner] = nil
	end
	if record.trailer then
		record.trailer:Destroy()
	end
	record.model:Destroy()
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

-- Seated riders are massless: the spec mass already includes the crew (as VehicleService).
local riderParts: { [Instance]: { BasePart } } = {}
local function setRiderMassless(seat: Seat | VehicleSeat)
	local previous = riderParts[seat]
	if previous then
		for _, p in previous do
			if p.Parent then
				p.Massless = false
			end
		end
		riderParts[seat] = nil
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
	riderParts[seat] = parts
end

local function buildTrailer(record: Record, player: Player, cf: CFrame): boolean
	local boatId = Trailer.pickBoat(function(id)
		return canUseBoat(player, id)
	end)
	local boatSpec = boatId and VehicleConfig.get(boatId)
	-- VehicleConfig.massHint includes the crew; a boat on its trailer is about 85 % of it
	local boatKg = if boatSpec then boatSpec.massHint * 37 * 0.85 else 0
	local trailer = Builder.build(LandVehicleConfig.BoatTrailer, boatKg)
	trailer.Name = `{player.Name}_BoatTrailer`
	trailer:SetAttribute("Owner", player.UserId)
	trailer:SetAttribute("ExtraMassKg", boatKg)
	if boatId then
		Builder.boatOnTrailer(trailer, boatId)
	end
	local troot = trailer.PrimaryPart :: BasePart
	local hitch = record.root:FindFirstChild("TowHitch") :: Attachment?
	local coupler = troot:FindFirstChild("Coupler") :: Attachment?
	if not (hitch and coupler) then
		trailer:Destroy()
		return false
	end
	trailer:PivotTo(cf * CFrame.new(hitch.Position - coupler.Position))
	troot.Anchored = true
	trailer.Parent = folder
	local joint = Instance.new("BallSocketConstraint")
	joint.Name = "Hitch"
	joint.Attachment0 = hitch
	joint.Attachment1 = coupler
	joint.LimitsEnabled = true
	joint.UpperAngle = 80
	joint.Parent = troot
	local link = Instance.new("ObjectValue")
	link.Name = "Trailer"
	link.Value = trailer
	link.Parent = record.model
	record.trailer = trailer
	record.trailerSim = Physics.new(trailer, LandVehicleConfig.BoatTrailer, boatKg)
	record.boatId = boatId
	record.model:SetAttribute("Towing", true)
	record.model:SetAttribute("TrailerBoat", boatId)
	return true
end

local function spawnVehicle(
	player: Player,
	vehicleId: string,
	pointId: string?,
	withTrailer: boolean?
): (boolean, string | Model)
	local spec = LandVehicleConfig.get(vehicleId)
	if not spec or not spec.driveable then
		return false, "UnknownVehicle"
	end
	local now = os.clock()
	if lastSpawn[player] and now - lastSpawn[player] < SPAWN_COOLDOWN then
		return false, "Cooldown"
	end
	local allowed, reason = canUse(player, vehicleId, spec.unlockRank)
	if not allowed then
		return false, reason
	end
	local towing = withTrailer == true and spec.canTow
	local point = if pointId then pointById(pointId) else nearestPoint(player, vehicleId, towing)
	if not point or not pointAllows(point, vehicleId) or (towing and not point.trailers) then
		return false, "NoSpawnPoint"
	end
	local bay = freeBay(point, player)
	if not bay then
		return false, "BayBusy"
	end
	lastSpawn[player] = now
	local old = byPlayer[player]
	if old then
		despawn(old)
	end

	local model = Builder.build(spec)
	model.Name = `{player.Name}_{spec.id}`
	model:SetAttribute("Owner", player.UserId)
	local ignore: { Instance } = characters()
	table.insert(ignore, folder)
	local y = groundY(bay.Position, ignore)
	local cf = CFrame.new(bay.Position.X, y + Builder.rideHeight(spec) + 0.15, bay.Position.Z)
		* bay.Rotation
	model:PivotTo(cf)
	local root = model.PrimaryPart :: BasePart
	root.Anchored = true
	model.Parent = folder
	CollectionService:AddTag(model, "LandVehicle")
	local seat = model:FindFirstChild("DriverSeat") :: VehicleSeat
	local record: Record = {
		model = model,
		owner = player,
		spec = spec,
		root = root,
		seat = seat,
		sim = Physics.new(model, spec),
		mode = "Parked",
		trailer = nil,
		trailerSim = nil,
		boatId = nil,
		emptySince = os.clock(),
		stillFor = 0,
		lastGood = cf,
		strikes = 0,
		resetting = false,
	}
	records[model] = record
	byPlayer[player] = record
	if towing then
		buildTrailer(record, player, cf)
	end
	setHeadlights(model, darkOrWet())
	model:SetAttribute("LightBar", false)
	model:SetAttribute("Siren", false)
	model:SetAttribute("Horn", false)
	model:SetAttribute("CanLaunch", false)

	for _, d in model:GetDescendants() do
		if d:IsA("Seat") or d:IsA("VehicleSeat") then
			local s = d :: Seat | VehicleSeat
			s:GetPropertyChangedSignal("Occupant"):Connect(function()
				setRiderMassless(s)
			end)
			s.Destroying:Connect(function()
				riderParts[s] = nil
			end)
		end
	end
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if records[model] == record then
			onSeatChanged(record)
		end
	end)
	sitDriver(player, seat)
	spawnedEvent:Fire(player, model)
	spawnedRemote:FireAllClients(model)
	return true, model
end

-- Seat changes ----------------------------------------------------------------------------------

onSeatChanged = function(record: Record)
	local humanoid = record.seat.Occupant
	local driver = humanoid and Players:GetPlayerFromCharacter(humanoid.Parent)
	if humanoid and driver ~= record.owner then
		-- only the vehicle's owner drives it; crew ride in the other seats
		task.defer(function()
			if record.seat.Occupant == humanoid then
				humanoid.Sit = false
				local weld = record.seat:FindFirstChild("SeatWeld")
				if weld then
					weld:Destroy()
				end
			end
		end)
		return
	end
	if driver then
		record.mode = "Driven"
		setAnchored(record, false)
		Physics.idle(record.sim)
		setOwner(record.root, driver)
		setOwner(record.trailer and record.trailer.PrimaryPart, driver)
		record.lastGood = record.root.CFrame
		record.strikes = 0
	else
		record.emptySince = os.clock()
		record.stillFor = 0
		record.model:SetAttribute("Horn", false)
		record.model:SetAttribute("CanLaunch", false)
		if record.root.AssemblyLinearVelocity.Magnitude < 2 then
			record.mode = "Parked"
			setAnchored(record, true)
		else
			record.mode = "Coast"
			setOwner(record.root, nil)
			setOwner(record.trailer and record.trailer.PrimaryPart, nil)
		end
	end
end

-- Trailer launch (docs 10 section 3.2) --------------------------------------------------------

local function launchDepth(record: Record): number
	local trailer = record.trailer
	local troot = trailer and trailer.PrimaryPart
	local cradle = troot and troot:FindFirstChild("Cradle") :: Attachment?
	if not cradle then
		return 0
	end
	local p = cradle.WorldPosition
	return waterAt(p) - p.Y
end

local function launch(record: Record, player: Player): boolean
	local trailer = record.trailer
	local troot = trailer and trailer.PrimaryPart
	local boatId = record.boatId
	if not (trailer and troot and boatId) then
		return false
	end
	local speed = flat(record.root.AssemblyLinearVelocity)
	if not Trailer.canLaunch(launchDepth(record), speed) then
		return false
	end
	local vehicles = sibling("VehicleService")
	if not (vehicles and type(vehicles.SpawnSeated) == "function") then
		warn("[LandVehicleService] VehicleService.SpawnSeated missing: cannot launch")
		return false
	end
	-- the boat floats off the stern of the trailer, bow to seaward
	local look = troot.CFrame.LookVector
	local boatSpec = VehicleConfig.get(boatId)
	local length = if boatSpec then boatSpec.hullSize.Z else 25
	local cradle = troot:FindFirstChild("Cradle") :: Attachment
	local pos = cradle.WorldPosition - look * (length * 0.5 + 4)
	local cf = CFrame.lookAt(pos, pos - Vector3.new(look.X, 0, look.Z))
	local boat = trailer:FindFirstChild("TrailerBoat")
	if boat then
		boat:Destroy()
	end
	record.boatId = nil
	trailer:SetAttribute("ExtraMassKg", 0)
	record.model:SetAttribute("TrailerBoat", nil)
	record.model:SetAttribute("CanLaunch", false)
	-- the empty trailer is lighter: its chassis mass back to 650 kg
	local empty = Builder.build(LandVehicleConfig.BoatTrailer)
	local emptyRoot = empty.PrimaryPart :: BasePart
	troot.CustomPhysicalProperties = emptyRoot.CustomPhysicalProperties
	empty:Destroy()
	record.trailerSim = Physics.new(trailer, LandVehicleConfig.BoatTrailer, 0)
	local ok, result = pcall(vehicles.SpawnSeated, player, boatId, cf, 0)
	if not ok or not result then
		warn(`[LandVehicleService] launch failed: {result}`)
		return false
	end
	return true
end

-- Sanity checks (as the boats) -----------------------------------------------------------------

local function resetTo(record: Record, cf: CFrame, reason: string)
	warn(`[LandVehicleService] reset {record.model.Name}: {reason}`)
	record.resetting = true
	record.strikes = 0
	setOwner(record.root, nil)
	setOwner(record.trailer and record.trailer.PrimaryPart, nil)
	record.root.AssemblyLinearVelocity = Vector3.zero
	record.root.AssemblyAngularVelocity = Vector3.zero
	local upright = CFrame.new(cf.Position + Vector3.new(0, 1, 0))
		* CFrame.fromAxisAngle(Vector3.yAxis, math.atan2(-cf.LookVector.X, -cf.LookVector.Z))
	local trailer = record.trailer
	local offset = if trailer then record.root.CFrame:ToObjectSpace(trailer:GetPivot()) else nil
	record.model:PivotTo(upright)
	if trailer and offset then
		trailer:PivotTo(upright * offset)
	end
	task.delay(0.5, function()
		record.resetting = false
		if records[record.model] == record and record.mode == "Driven" then
			local humanoid = record.seat.Occupant
			local driver = humanoid and Players:GetPlayerFromCharacter(humanoid.Parent)
			setOwner(record.root, driver)
			setOwner(record.trailer and record.trailer.PrimaryPart, driver)
		end
	end)
end

local function check(record: Record, dt: number)
	local model = record.model
	local root = record.root
	-- launch readiness, shown to the driver (CarController)
	if record.trailer and record.boatId and record.mode == "Driven" then
		model:SetAttribute(
			"CanLaunch",
			Trailer.canLaunch(launchDepth(record), flat(root.AssemblyLinearVelocity))
		)
	end
	if record.mode ~= "Driven" or record.resetting then
		return
	end
	if
		IS_STUDIO
		and (
			model:GetAttribute(BYPASS_ATTRIBUTE) == true
			or Workspace:GetAttribute(BYPASS_ATTRIBUTE) == true
		)
	then
		record.lastGood = root.CFrame
		return
	end
	local pos = root.Position
	local speed = flat(root.AssemblyLinearVelocity)
	local top = if record.trailer and record.spec.topSpeedTowing
		then record.spec.topSpeedTowing
		else record.spec.topSpeed
	local limit = top * SPEED_TOLERANCE + SPEED_SLACK
	local moved = flat(pos - record.lastGood.Position)
	local floor = pos.Y - record.spec.cgHeight * 3
	local drowned = waterAt(pos) - floor > DROWN_DEPTH
	if pos.Y > MAX_Y or pos.Y < MIN_Y then
		resetTo(record, record.lastGood, "out of bounds")
	elseif drowned then
		-- nothing breaks (docs 02 section 4.1): back to the last dry spot
		resetTo(record, record.lastGood, "too deep")
	elseif speed > limit or moved > limit * dt + TELEPORT_SLACK then
		record.strikes += 1
		if record.strikes >= STRIKES_TO_RESET then
			resetTo(record, record.lastGood, `speed {math.floor(speed)} moved {math.floor(moved)}`)
		end
	else
		record.strikes = 0
		if waterAt(pos) < floor and root.CFrame.UpVector.Y > 0.7 then
			record.lastGood = root.CFrame
		end
	end
end

local function checkDespawn(record: Record)
	if record.mode == "Driven" then
		return
	end
	local character = record.owner.Character
	local far = not character
		or (character:GetPivot().Position - record.root.Position).Magnitude
			> LandVehicleConfig.Despawn.distance
	if far and os.clock() - record.emptySince > LandVehicleConfig.Despawn.emptySeconds then
		despawn(record)
	elseif not far then
		record.emptySince = os.clock()
	end
end

-- Server-side coasting: an empty car rolling away gets the handbrake until it stops.
local function coast(record: Record, dt: number)
	if record.mode ~= "Coast" then
		return
	end
	local controls = { throttle = 0, steer = 0, handbrake = true, lowRange = false, assists = true }
	Physics.step(record.sim, controls, dt)
	if record.trailerSim then
		Physics.step(record.trailerSim, {
			throttle = 0,
			steer = 0,
			handbrake = true,
			lowRange = false,
			assists = true,
			brakeOverride = 1,
		}, dt)
	end
	if record.root.AssemblyLinearVelocity.Magnitude < 0.5 then
		record.stillFor += dt
		if record.stillFor > 1 then
			record.mode = "Parked"
			setAnchored(record, true)
		end
	else
		record.stillFor = 0
	end
end

-- Controls from the driver ------------------------------------------------------------------------

local function onControl(player: Player, action: any, value: any)
	local now = os.clock()
	if lastControl[player] and now - lastControl[player] < CONTROL_GAP then
		return
	end
	lastControl[player] = now
	local record = byPlayer[player]
	if not record or type(action) ~= "string" then
		return
	end
	local humanoid = record.seat.Occupant
	local isDriver = humanoid ~= nil and Players:GetPlayerFromCharacter(humanoid.Parent) == player
	if not isDriver then
		return
	end
	local model = record.model
	local on = value == true
	if action == "Horn" then
		model:SetAttribute("Horn", on)
		local prev = model:GetAttribute("HornSeq")
		local seq = (if type(prev) == "number" then prev else 0) + 1
		model:SetAttribute("HornSeq", seq)
		if on then
			task.delay(HORN_MAX, function()
				if model.Parent and model:GetAttribute("HornSeq") == seq then
					model:SetAttribute("Horn", false)
				end
			end)
		end
	elseif action == "LightBar" and record.spec.lightBar then
		model:SetAttribute("LightBar", on)
		setFloodlights(model, on and record.spec.class == "Response")
	elseif action == "Siren" and record.spec.lightBar then
		-- TODO(Ops): blue lights and siren only on a tasking (docs 10 section 3.3); free for now
		model:SetAttribute("Siren", on)
	elseif action == "Headlights" then
		setHeadlights(model, on)
	elseif action == "Launch" then
		launch(record, player)
	end
end

-- The parked ambulance handover points (docs 10 section 3.1, MVP).
local function placeAmbulances()
	for _, point in LandVehicleConfig.AmbulancePoints do
		local spec = LandVehicleConfig.Ambulance
		local model = Builder.build(spec)
		model.Name = `Ambulance_{point.id}`
		local y = groundY(point.cframe.Position, { folder })
		model:PivotTo(
			CFrame.new(
				point.cframe.Position.X,
				y + Builder.rideHeight(spec) + 0.1,
				point.cframe.Position.Z
			) * point.cframe.Rotation
		)
		local root = model.PrimaryPart :: BasePart
		root.Anchored = true
		model:SetAttribute("HandoverPoint", point.id)
		model:SetAttribute("Ambulance", true)
		model:SetAttribute("LightBar", false)
		local handover = Instance.new("Attachment")
		handover.Name = "HandoverPoint" -- behind the rear doors, at standing height
		handover.Position = Vector3.new(0, 0, spec.length * 1.5 + 4.5)
		handover.Parent = root
		CollectionService:AddTag(model, "AmbulanceHandover")
		model.Parent = folder
	end
end

-- Temporary UI: a post with prompts at every spawn point (until the HUD has a vehicle menu).
local function placeSigns()
	local signs = Instance.new("Folder")
	signs.Name = "LandVehiclePoints"
	for _, point in spawnPoints do
		local post = Instance.new("Part")
		post.Name = point.id
		post.Anchored = true
		post.Size = Vector3.new(0.6, 6, 0.6)
		post.Color = Color3.fromRGB(250, 205, 20)
		post.Material = Enum.Material.Metal
		post.CFrame = point.cframe * CFrame.new(-8, 3, 4)
		post:SetAttribute("SpawnPoint", point.id)
		post.Parent = signs
		local function prompt(vehicleId: string, withTrailer: boolean)
			local spec = LandVehicleConfig.get(vehicleId)
			if not spec then
				return
			end
			local p = Instance.new("ProximityPrompt")
			p.ActionText = if withTrailer
				then `Take {spec.displayName} + boat trailer`
				else `Take {spec.displayName}`
			p.ObjectText = point.displayName
			p.HoldDuration = 0.3
			p.MaxActivationDistance = 12
			p.RequiresLineOfSight = false
			p.Parent = post
			p.Triggered:Connect(function(player)
				local ok, reason = spawnVehicle(player, vehicleId, point.id, withTrailer)
				if not ok then
					warn(`[LandVehicleService] {player.Name} {vehicleId}: {reason}`)
				end
			end)
		end
		for _, id in point.vehicles do
			local spec = LandVehicleConfig.get(id)
			if spec and spec.driveable then
				if not point.trailers or not spec.canTow then
					prompt(id, false)
				end
				if point.trailers and spec.canTow then
					prompt(id, true)
				end
			end
		end
	end
	signs.Parent = Workspace
end

-- Module ----------------------------------------------------------------------------------------

function LandVehicleService.Init()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(GROUP)
	end)
	-- land vehicles pass through each other (docs 02 section 10)
	PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)
	loadWorldSpawns()

	folder = Instance.new("Folder")
	folder.Name = "LandVehicles"
	folder.Parent = Workspace

	local net = ReplicatedStorage:WaitForChild("Net")
	local request = Instance.new("RemoteFunction")
	request.Name = "Land_Request"
	request.Parent = net
	local control = Instance.new("RemoteEvent")
	control.Name = "Land_Control"
	control.Parent = net
	spawnedRemote = Instance.new("RemoteEvent")
	spawnedRemote.Name = "Land_Spawned"
	spawnedRemote.Parent = net

	request.OnServerInvoke = function(
		player: Player,
		vehicleId: any,
		pointId: any,
		withTrailer: any
	)
		if type(vehicleId) ~= "string" or #vehicleId > 40 then
			return false, "BadRequest"
		end
		local point = if type(pointId) == "string" and #pointId <= 40 then pointId else nil
		local ok, result = spawnVehicle(player, vehicleId, point, withTrailer == true)
		return ok, result
	end
	control.OnServerEvent:Connect(onControl)
end

function LandVehicleService.Start()
	placeAmbulances()
	placeSigns()
	Players.PlayerRemoving:Connect(function(player)
		local record = byPlayer[player]
		if record then
			despawn(record)
		end
		lastSpawn[player] = nil
		lastControl[player] = nil
	end)
	RunService.Heartbeat:Connect(function(dt)
		for _, record in records do
			coast(record, dt)
		end
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(CHECK_INTERVAL)
			local now = os.clock()
			local dt = now - last
			last = now
			local list = {}
			for _, record in records do
				table.insert(list, record)
			end
			for _, record in list do
				if records[record.model] == record then
					check(record, dt)
					checkDespawn(record)
				end
			end
		end
	end)
end

-- API (CONTRACT.md, Land vehicles) -------------------------------------------------------------

function LandVehicleService.GetVehicle(player: Player): Model?
	local record = byPlayer[player]
	return if record then record.model else nil
end

function LandVehicleService.GetTrailer(model: Model): Model?
	local record = records[model]
	return if record then record.trailer else nil
end

function LandVehicleService.GetDriver(model: Model): Player?
	local record = records[model]
	local humanoid = record and record.seat.Occupant
	return if humanoid then Players:GetPlayerFromCharacter(humanoid.Parent) else nil
end

function LandVehicleService.Spawn(
	player: Player,
	vehicleId: string,
	pointId: string?,
	withTrailer: boolean?
): (boolean, string | Model)
	return spawnVehicle(player, vehicleId, pointId, withTrailer)
end

function LandVehicleService.Despawn(player: Player)
	local record = byPlayer[player]
	if record then
		despawn(record)
	end
end

function LandVehicleService.SetLightBar(model: Model, on: boolean)
	local record = records[model]
	if record and record.spec.lightBar then
		model:SetAttribute("LightBar", on)
	end
end

return LandVehicleService
