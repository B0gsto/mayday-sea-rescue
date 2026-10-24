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
--   Spawn point ProximityPrompts are the temporary UI ("Take Lifeguard 4x4").
--
-- States: Parked (anchored, nobody driving), Driven (owner in DriverSeat: unanchored, network
-- owner = driver), Coast (left while moving: the server runs the chassis with the handbrake on
-- until it stops, then parks). Model attributes: VehicleId, Owner, LandVehicle, CameraMode
-- ("Chase"), CockpitView, Headlights, LightBar, Siren, Horn, CanLaunch, Towing, ExtraMassKg,
-- WaterDepth (studs over the tyres, 0.1 steps), Flooded, FloodedUntil (server time; Car/Wading).
-- Spawns face along the nearest WorldConfig road, away from the water (Car/RoadHeading).
-- A towing car holds an ObjectValue "Trailer"; the trailer is a separate model on a
-- BallSocketConstraint (TowHitch -> Coupler) with its own raycast wheels.
-- Recovery (VehicleRecovery): a car on its side or roof, wedged with the throttle held, or sunk
-- into terrain glides (lift-and-settle) upright onto the nearest road, driver still seated.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarFolder = Shared:WaitForChild("Car")
local Art = require(CarFolder:WaitForChild("Art"))
local ArtLayout = require(CarFolder:WaitForChild("ArtLayout"))
local AssetLoader = require(script.Parent.Parent:WaitForChild("Assets"):WaitForChild("AssetLoader"))
local Builder = require(CarFolder:WaitForChild("Builder"))
local LandVehicleConfig = require(Shared:WaitForChild("Config"):WaitForChild("LandVehicleConfig"))
local Physics = require(CarFolder:WaitForChild("Physics"))
local RoadHeading = require(CarFolder:WaitForChild("RoadHeading"))
local Trailer = require(CarFolder:WaitForChild("Trailer"))
local Tyre = require(CarFolder:WaitForChild("Tyre"))
local VehicleConfig = require(Shared:WaitForChild("Config"):WaitForChild("VehicleConfig"))
local VehicleRecovery = require(Shared:WaitForChild("VehicleRecovery"))
local Wading = require(CarFolder:WaitForChild("Wading"))
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
	wade: Wading.State,
	recovery: VehicleRecovery.State,
}

local GROUP = "LandVehicle"
local CHARACTER_GROUP = "Characters" -- players on foot: never hit (or flung) by land vehicles
local SPAWN_COOLDOWN = 3
local CHECK_INTERVAL = 0.5
local SPEED_TOLERANCE = 1.3 -- x top speed -- tune
local SPEED_SLACK = 10 -- studs/s (downhill, airborne off a dune) -- tune
local TELEPORT_SLACK = 14
local STRIKES_TO_RESET = 2
local MAX_Y, MIN_Y = 400, -45
local RESCUE_BACKOFF = 8 -- studs further inland than the last dry spot when a flooded car is recovered
local RECOVER_BACKOFF = 6 -- studs behind the last upright spot when no road is near -- tune
local ROAD_SNAP = 40 -- studs: a recovered car goes onto a road centreline this close -- tune
local GROUND_REACH = 4 -- studs under the ride height that still count as touching down -- tune
local SUNK_DEPTH = 2 -- studs of the root under the terrain surface that count as sunk -- tune
local GLIDE_RANGE = 80 -- studs: further resets (out of bounds) snap instead of gliding
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

-- Blue lights and siren need an active operation (docs 10 section 3.3).
local function onOperation(player: Player): boolean
	local ops = sibling("OperationService")
	if not (ops and type(ops.GetOperationOf) == "function") then
		return false
	end
	local ok, op = pcall(ops.GetOperationOf, player)
	return ok and op ~= nil
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

-- WorldConfig.LandVehicleSpawns (terrain stream, same SpawnPoint shape) wins when it holds valid
-- points. Otherwise the LandVehicleConfig.SpawnPoints keep their vehicles / bays, take their
-- position from the WorldConfig point with the same id, and face along the nearest road toward
-- HEAD_TOWARD (so W drives up the road, not into the harbour; Studio play test, integration-B 6).
local HEAD_TOWARD: { [string]: string } = {
	StationYard = "HavenSandsCarPark", -- east along Harbour Road, toward Haven Sands
	Boatyard = "HavenSandsCarPark", -- east along Harbour Road
	HavenSandsCarPark = "StationYard", -- west back up the Coast Road, away from the beach
	HavenSandsTower = "HavenSandsCarPark", -- up the Haven Sands slipway, away from the sea
	HavenSands = "StationYard", -- the parked ambulance (HavenSandsAmbulance)
}
local WORLD_POINT: { [string]: string } = { HavenSands = "HavenSandsAmbulance" }
local TOWER_CLEARANCE = 16 -- studs landward of a lifeguard tower (its hut would catch the raycast)

local world: any = nil -- WorldConfig, when present

local function worldPoint(id: string): any
	if not world or type(world.Points) ~= "table" then
		return nil
	end
	for _, p in world.Points do
		if type(p) == "table" and p.id == id and typeof(p.position) == "Vector3" then
			return p
		end
	end
	return nil
end

-- The placeholder point `id` moved onto the world map and turned along its road.
local function alignedCFrame(id: string, cframe: CFrame): CFrame
	if not world or type(world.Roads) ~= "table" then
		return cframe
	end
	local wp = worldPoint(WORLD_POINT[id] or id)
	local target = HEAD_TOWARD[id] and worldPoint(HEAD_TOWARD[id])
	local toward: Vector3? = if target then target.position else nil
	local pos = if wp then wp.position :: Vector3 else cframe.Position
	if wp and wp.kind == "LifeguardTower" and toward then
		local away = Vector3.new(toward.X - pos.X, 0, toward.Z - pos.Z)
		if away.Magnitude > 1 then
			pos += away.Unit * TOWER_CLEARANCE
		end
	end
	local cf, hit = RoadHeading.spawnCFrame(world.Roads, pos, toward, { seaLevel = world.SeaLevel })
	local look = cf.LookVector
	print(
		`[LandVehicleService] point {id} at ({math.floor(pos.X)}, {math.floor(pos.Z)}) faces ({string.format(
			"%.2f, %.2f",
			look.X,
			look.Z
		)}) along {if hit then hit.roadId else "no road"}`
	)
	return cf
end
local function validPoint(point: any): boolean
	return type(point) == "table"
		and type(point.id) == "string"
		and typeof(point.cframe) == "CFrame"
		and type(point.vehicles) == "table"
end

local function loadWorldSpawns()
	local configFolder = Shared:FindFirstChild("Config")
	local module = configFolder and configFolder:FindFirstChild("WorldConfig")
	if not (module and module:IsA("ModuleScript")) then
		return
	end
	local ok, loaded = pcall(require, module)
	world = if ok and type(loaded) == "table" then loaded else nil
	local list = if world then world.LandVehicleSpawns else nil
	if type(list) ~= "table" then
		local aligned: { SpawnPoint } = {}
		for _, point in LandVehicleConfig.SpawnPoints do
			local copy = table.clone(point)
			copy.cframe = alignedCFrame(point.id, point.cframe)
			table.insert(aligned, copy)
		end
		spawnPoints = aligned
		return
	end
	local valid: { SpawnPoint } = {}
	for _, point in list do
		if validPoint(point) then
			table.insert(valid, point :: SpawnPoint)
		else
			warn("[LandVehicleService] skipping a malformed WorldConfig.LandVehicleSpawns entry")
		end
	end
	if #valid > 0 then
		spawnPoints = valid
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

-- Puts the uploaded body on a freshly built greybox model (Car/Art). No asset or a failed load
-- keeps the greybox exactly as built.
local function withArt(model: Model, spec: Spec, asset: string?): Model
	if not asset then
		return model
	end
	local visual = AssetLoader.clone(asset)
	if not visual then
		warn(`[LandVehicleService] {spec.id}: {asset} did not load; keeping the greybox`)
		return model
	end
	local ok, applied = pcall(Art.apply, model, spec, visual)
	if not ok or not applied then
		warn(`[LandVehicleService] {spec.id}: art {asset} failed: {applied}`)
		visual:Destroy()
	end
	return model
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
	local trailer = withArt(
		Builder.build(LandVehicleConfig.BoatTrailer, boatKg),
		LandVehicleConfig.BoatTrailer,
		ArtLayout.assetFor("BoatTrailer", boatId)
	)
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

	local model = withArt(Builder.build(spec), spec, ArtLayout.assetFor(vehicleId))
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
		wade = Wading.newState(),
		recovery = VehicleRecovery.new(),
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
	model:SetAttribute("Flooded", false)
	model:SetAttribute("WaterDepth", 0)

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

local function yawOnly(cf: CFrame): CFrame
	return CFrame.new(cf.Position)
		* CFrame.fromAxisAngle(Vector3.yAxis, math.atan2(-cf.LookVector.X, -cf.LookVector.Z))
end

-- Puts the car (and trailer) upright at cf: a short lift-and-settle glide, anchored and
-- server-owned, then velocities zeroed and the driver (still seated) gets ownership back.
local function resetTo(record: Record, cf: CFrame, reason: string)
	warn(`[LandVehicleService] reset {record.model.Name}: {reason}`)
	record.resetting = true
	record.strikes = 0
	record.recovery.lastAt = os.clock()
	setOwner(record.root, nil)
	setOwner(record.trailer and record.trailer.PrimaryPart, nil)
	local upright = yawOnly(cf) + Vector3.new(0, 1, 0)
	local trailer = record.trailer
	local offset = if trailer
		then yawOnly(record.root.CFrame):ToObjectSpace(yawOnly(trailer:GetPivot()))
		else nil
	local function place(at: CFrame)
		record.model:PivotTo(at)
		if trailer and offset then
			trailer:PivotTo(at * offset)
		end
	end
	local function settle()
		place(upright)
		if record.mode ~= "Parked" then
			setAnchored(record, false)
		end
		local trailerRoot = trailer and trailer.PrimaryPart
		local parts: { BasePart } = if trailerRoot
			then { record.root, trailerRoot }
			else { record.root }
		for _, part in parts do
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
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
	local from = record.root.CFrame
	if (from.Position - upright.Position).Magnitude > GLIDE_RANGE then
		settle()
	else
		setAnchored(record, true)
		VehicleRecovery.glide(from, upright, place, settle)
	end
end

-- Where a flipped / wedged / sunk car goes: the nearest road centreline within ROAD_SNAP, facing
-- the way it was heading, else its last upright dry spot backed off whatever it hit; stepped back
-- a car length at a time until no other land vehicle is in the way.
local function recoverySpot(record: Record): CFrame
	local good = record.lastGood
	local look = Vector3.new(good.LookVector.X, 0, good.LookVector.Z)
	look = if look.Magnitude > 1e-3 then look.Unit else RoadHeading.INLAND
	local at = good.Position - look * RECOVER_BACKOFF
	local roads = world and world.Roads
	local hit = if type(roads) == "table"
		then RoadHeading.nearest(roads, record.root.Position, false, world.SeaLevel)
		else nil
	if hit and hit.distance < ROAD_SNAP then
		at = hit.point
		look = if hit.tangent:Dot(look) >= 0 then hit.tangent else -hit.tangent
	end
	local ignore: { Instance } = characters()
	table.insert(ignore, folder)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { folder }
	local size = record.model:GetExtentsSize()
	local lift = Builder.rideHeight(record.spec) + 0.15
	local first: CFrame? = nil
	for i = 0, 3 do
		local p = at - look * (i * size.Z)
		local y = groundY(p, ignore) + lift
		local cf =
			CFrame.lookAt(Vector3.new(p.X, y, p.Z), Vector3.new(p.X + look.X, y, p.Z + look.Z))
		first = first or cf
		local blocked = false
		for _, part in Workspace:GetPartBoundsInBox(cf, size, params) do
			if
				not part:IsDescendantOf(record.model)
				and not (record.trailer and part:IsDescendantOf(record.trailer))
			then
				blocked = true
				break
			end
		end
		if not blocked then
			return cf
		end
	end
	return first :: CFrame
end

-- shortcut: terrain overhanging a road (a cave or arch) would read as sunk; none on the map yet.
local function terrainTop(position: Vector3): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	params.IgnoreWater = true
	local hit = Workspace:Raycast(position + Vector3.new(0, 60, 0), Vector3.new(0, -160, 0), params)
	return if hit then hit.Position.Y else -math.huge
end

-- Flipped, wedged or sunk for long enough (VehicleRecovery): back onto the road. True on a reset.
local function recover(record: Record, dt: number): boolean
	local root = record.root
	local pos = root.Position
	local ignore: { Instance } = characters()
	table.insert(ignore, folder)
	local reason = VehicleRecovery.step(record.recovery, dt, os.clock(), {
		up = root.CFrame.UpVector.Y,
		speed = root.AssemblyLinearVelocity.Magnitude,
		throttle = if record.mode == "Driven" then record.seat.ThrottleFloat else 0,
		grounded = pos.Y - groundY(pos, ignore) < Builder.rideHeight(record.spec) + GROUND_REACH,
		off = terrainTop(pos) - pos.Y > SUNK_DEPTH,
	})
	if not reason then
		return false
	end
	resetTo(record, recoverySpot(record), reason)
	return true
end

-- Shoreline guard (Car/Wading): warn past half the wading depth (CarController), flood the engine
-- at the rated depth (the driver's throttle is cut), then after a short wait restart or recover
-- once to dry land. One "reset ... too deep" line per flood, never a reset per check.
local function setFlooded(record: Record, on: boolean, depth: number?)
	local model = record.model
	model:SetAttribute("Flooded", on)
	model:SetAttribute(
		"FloodedUntil",
		if on then Workspace:GetServerTimeNow() + Wading.FLOOD_SECONDS else nil
	)
	if on then
		print(
			`[LandVehicleService] {model.Name}: engine flooded at {string.format("%.1f", depth or 0)} studs of water`
		)
	end
end

local function rescue(record: Record, from: Vector3)
	local good = record.lastGood
	local away = Vector3.new(good.Position.X - from.X, 0, good.Position.Z - from.Z)
	if away.Magnitude < 1 then
		away = Vector3.new(-good.LookVector.X, 0, -good.LookVector.Z)
	end
	away = if away.Magnitude > 1e-3 then away.Unit else RoadHeading.INLAND
	local rideHeight = Builder.rideHeight(record.spec)
	local target = good.Position
	local ignore: { Instance } = characters()
	table.insert(ignore, folder)
	local back = good.Position + away * RESCUE_BACKOFF
	local y = groundY(back, ignore)
	local backRoot = y + rideHeight + 0.15
	if
		Wading.depth(waterAt(back), backRoot, rideHeight) < 0
		and math.abs(backRoot - good.Position.Y) < 4
	then
		target = Vector3.new(back.X, backRoot, back.Z)
	end
	-- facing away from the water, so W drives back up the shore
	resetTo(record, CFrame.lookAt(target, target + away), "too deep (engine flooded)")
end

local function setDepth(model: Model, depth: number)
	local shown = math.max(0, math.floor(depth * 10 + 0.5) / 10)
	if model:GetAttribute("WaterDepth") ~= shown then
		model:SetAttribute("WaterDepth", shown)
	end
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
	local pos = root.Position
	local depth = Wading.depth(waterAt(pos), pos.Y, Builder.rideHeight(record.spec))
	setDepth(model, depth)
	if record.resetting then
		return
	end
	if record.wade.flooded then
		-- stalled: wait out FLOOD_SECONDS (also if the driver got out), then restart or recover
		local action = Wading.step(record.wade, depth, record.spec.id, os.clock())
		if action then
			setFlooded(record, false)
			if action == "Rescue" then
				rescue(record, pos)
			end
		end
		return
	end
	local bypass = IS_STUDIO
		and (
			model:GetAttribute(BYPASS_ATTRIBUTE) == true
			or Workspace:GetAttribute(BYPASS_ATTRIBUTE) == true
		)
	if not bypass and recover(record, dt) then
		return
	end
	if record.mode ~= "Driven" then
		return
	end
	if bypass then
		record.lastGood = root.CFrame
		return
	end
	local speed = flat(root.AssemblyLinearVelocity)
	local top = if record.trailer and record.spec.topSpeedTowing
		then record.spec.topSpeedTowing
		else record.spec.topSpeed
	local limit = top * SPEED_TOLERANCE + SPEED_SLACK
	local moved = flat(pos - record.lastGood.Position)
	if pos.Y > MAX_Y or pos.Y < MIN_Y then
		resetTo(record, record.lastGood, "out of bounds")
	elseif Wading.step(record.wade, depth, record.spec.id, os.clock()) == "Flood" then
		-- nothing breaks (docs 02 section 4.1): the engine stalls, then the car is recovered
		setFlooded(record, true, depth)
		record.strikes = 0
	elseif speed > limit or moved > limit * dt + TELEPORT_SLACK then
		record.strikes += 1
		if record.strikes >= STRIKES_TO_RESET then
			resetTo(record, record.lastGood, `speed {math.floor(speed)} moved {math.floor(moved)}`)
		end
	else
		record.strikes = 0
		if depth < 0 and root.CFrame.UpVector.Y > 0.7 then
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
		on = on and onOperation(player) -- blue lights only on a tasking (docs 10 section 3.3)
		model:SetAttribute("LightBar", on)
		setFloodlights(model, on and record.spec.class == "Response")
	elseif action == "Siren" and record.spec.lightBar then
		model:SetAttribute("Siren", on and onOperation(player))
	elseif action == "Headlights" then
		setHeadlights(model, on)
	elseif action == "Launch" then
		launch(record, player)
	end
end

-- Blue lights and siren go off once the owner's operation is over.
local function emergencyOff(record: Record)
	local model = record.model
	if model:GetAttribute("LightBar") == true or model:GetAttribute("Siren") == true then
		model:SetAttribute("LightBar", false)
		model:SetAttribute("Siren", false)
		setFloodlights(model, false)
	end
end

local function checkEmergency(record: Record)
	local model = record.model
	if model:GetAttribute("LightBar") ~= true and model:GetAttribute("Siren") ~= true then
		return
	end
	if not onOperation(record.owner) then
		emergencyOff(record)
	end
end

-- Characters on foot don't collide with land vehicles (no flinging); boats stay Default.
local function setCharacterGroup(part: Instance)
	if part:IsA("BasePart") then
		part.CollisionGroup = CHARACTER_GROUP
	end
end

local function watchCharacter(character: Model)
	for _, d in character:GetDescendants() do
		setCharacterGroup(d)
	end
	character.DescendantAdded:Connect(setCharacterGroup)
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end
end

-- The parked ambulance handover points (docs 10 section 3.1, MVP).
-- The phone's Vehicles app previews exactly what the spawner builds: ReplicatedStorage.VehiclePreviews.<id>
-- (VehicleService adds the boats).
local function publishPreviews()
	local previews = ReplicatedStorage:FindFirstChild("VehiclePreviews")
	if not previews then
		previews = Instance.new("Folder")
		previews.Name = "VehiclePreviews"
		previews.Parent = ReplicatedStorage
	end
	for _, id in LandVehicleConfig.Order do
		local spec = (LandVehicleConfig :: any)[id]
		local ok, model = pcall(function()
			return withArt(Builder.build(spec), spec, ArtLayout.assetFor(id))
		end)
		if ok then
			model.Name = id
			model.Parent = previews
		else
			warn(`[LandVehicleService] preview {id} failed: {model}`)
		end
	end
end

local function placeAmbulances()
	for _, point in LandVehicleConfig.AmbulancePoints do
		local spec = LandVehicleConfig.Ambulance
		local model = withArt(Builder.build(spec), spec, ArtLayout.assetFor(spec.id))
		model.Name = `Ambulance_{point.id}`
		local at = alignedCFrame(point.id, point.cframe)
		local y = groundY(at.Position, { folder })
		model:PivotTo(
			CFrame.new(at.Position.X, y + Builder.rideHeight(spec) + 0.1, at.Position.Z)
				* at.Rotation
		)
		local root = model.PrimaryPart :: BasePart
		root.Anchored = true
		model:SetAttribute("HandoverPoint", point.id)
		model:SetAttribute("Ambulance", true)
		model:SetAttribute("LightBar", false)
		local handover = root:FindFirstChild("HandoverPoint")
		if not (handover and handover:IsA("Attachment")) then
			local a = Instance.new("Attachment")
			a.Name = "HandoverPoint" -- behind the rear doors, at standing height
			a.Position = Vector3.new(0, 0, spec.length * 1.5 + 4.5)
			a.Parent = root
		end
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
		post:SetAttribute("SpawnFacing", point.cframe.LookVector) -- Studio check: along the road
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
			p:SetAttribute("FootOnly", true)
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
	pcall(function()
		PhysicsService:RegisterCollisionGroup(CHARACTER_GROUP)
	end)
	-- land vehicles pass through each other (docs 02 section 10)
	PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)
	-- pedestrians are never hit (docs 10 section 3); characters still collide with Default (boats)
	PhysicsService:CollisionGroupSetCollidable(GROUP, CHARACTER_GROUP, false)
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
	local preload = {}
	for _, asset in ArtLayout.ASSETS do
		table.insert(preload, asset)
	end
	for _, id in LandVehicleConfig.Order do
		local asset = ArtLayout.assetFor(id)
		if asset and not table.find(preload, asset) then
			table.insert(preload, asset)
		end
	end
	for _, asset in ArtLayout.TRAILER_ASSETS do
		table.insert(preload, asset)
	end
	AssetLoader.preload(preload)
	placeAmbulances()
	placeSigns()
	task.spawn(publishPreviews)
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	local ops = sibling("OperationService")
	local completed = ops and ops.OperationCompleted
	if type(completed) == "table" and type(completed.Connect) == "function" then
		pcall(function()
			completed:Connect(function()
				-- the op may still read as Active this frame; re-check next frame
				task.defer(function()
					for _, record in records do
						checkEmergency(record)
					end
				end)
			end)
		end)
	end
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
					checkEmergency(record)
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
