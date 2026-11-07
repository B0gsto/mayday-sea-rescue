--!strict
-- UpgradeService (docs/30 section 2): the boat ladder's server. Owns data.boatLevel, sells the next level for Cash at an
-- Upgrade Station or at the helm of your boat anywhere (never for Robux), builds the stations on every island and plays the level-up on the boat.
-- Old data.vehicleUpgrades masks stay in the save, unread. Save floors: ProgressionRules.migrate (owned boats) and
-- applyPassFloor here (pass ownership is not in the save, so data.boatPassFloor marks a pre-ladder save until read).
-- Also the tutorial's trip (docs/30 section 4): after L2 a trip out and home earns the free spin; one more ends the beat.
-- Remotes: Boat_LevelUp C->S function -> ok, reason. BoatLevelMoment S->C all ("Start" | "Swap", userId, model?, level).
-- Player attribute: BoatReach (extra pick-up studs, Ops/Board's reachAdd).
-- API: UpgradeService.Landing(player) -> CFrame? (or UpgradeStation.landing(island) directly).
-- Studio: ServerStorage.UpgradeDev:Invoke("set", level) | ("buy").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BoatLevels = require(Shared:WaitForChild("BoatLevels"))
local GoBack = require(Shared:WaitForChild("Boat"):WaitForChild("GoBack"))
local Net = require(Shared:WaitForChild("Net"))
local Onboarding = require(Shared:WaitForChild("Onboarding"))
local ProgressionConfig = require(Shared:WaitForChild("Config"):WaitForChild("ProgressionConfig"))
local RingLayout = require(Shared:WaitForChild("Config"):WaitForChild("RingLayout"))
local UpgradeStation = require(Shared:WaitForChild("UpgradeStation"))
local VehicleConfig = require(Shared:WaitForChild("Config"):WaitForChild("VehicleConfig"))
local VehicleUpgrades = require(Shared:WaitForChild("VehicleUpgrades"))

local AssetLoader = require(script.Parent.Parent:WaitForChild("Assets"):WaitForChild("AssetLoader"))
local BadgeService = require(script.Parent.BadgeService)
local DataService = require(script.Parent.DataService)
local DockService = require(script.Parent.DockService)
local Events = require(script.Parent:WaitForChild("Telemetry"):WaitForChild("Events"))
local MonetizationService = require(script.Parent.MonetizationService)
local ProgressionService = require(script.Parent.ProgressionService)
local SpinService = require(script.Parent.SpinService)
local Telemetry = require(script.Parent.TelemetryService)
local VehicleService = require(script.Parent.VehicleService)

local UpgradeService = {}
UpgradeService.Priority = 93

-- one moment at a time: it runs UpgradeStation.MOMENT s; a held key can't stack them
local COOLDOWN = UpgradeStation.MOMENT + 0.2
local PASS_WAIT = 30 -- s for the join's pass check
local MESH = "M_Bld_UpgradeStation"

local lastUse: { [Player]: number } = {}
local buttons: { BasePart } = {}
local tripOut: { [Player]: boolean } = {} -- the tutorial's trip: out at sea this session

function UpgradeService.Landing(player: Player): CFrame?
	local plot = DockService.GetPlot(player)
	return if plot then UpgradeStation.landing(plot) else nil
end

local function publish(player: Player, level: number)
	player:SetAttribute("BoatLevel", level)
	player:SetAttribute("BoatReach", BoatLevels.row(level).reach - BoatLevels.row(1).reach)
end

-- The station this player stands or floats at: the island index, or nil when out of range of them all.
local function stationNear(player: Player): number?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return nil
	end
	for index, button in buttons do
		if (button.Position - root.Position).Magnitude <= UpgradeStation.USE_RANGE + 20 then
			return index
		end
	end
	return nil
end

-- At the helm of your own boat anywhere (owner 2026-11-07: upgrade while on the boat): your island's index, for
-- LevelUpBoat's no-boat fallback it never takes then. nil off the helm or in a heli / sub.
local function atHelm(player: Player): number?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local model = VehicleService.GetVehicle(player)
	local id = model and model:GetAttribute("VehicleId")
	local spec = if type(id) == "string" then VehicleConfig.get(id) else nil
	if
		not (seat and seat.Name == "DriverSeat" and model and seat:IsDescendantOf(model))
		or VehicleService.GetDriver(model) ~= player
		or model:GetAttribute("Owner") ~= player.UserId
		or not spec
		or spec.craft
	then
		return nil
	end
	local plot = player:GetAttribute("DockPlot")
	return if type(plot) == "number" then plot else UpgradeStation.nearest(seat.Position)
end

-- The level goes on the boat at the top of the lift, with the stage's new hull if it was wearing the old one.
local function playMoment(player: Player, data: any, level: number, index: number)
	local before = BoatLevels.row(level - 1).hull
	local after = BoatLevels.row(level).hull
	local last = data.flags.lastVehicle
	local promote = if before ~= after and (last == nil or last == before) then after else nil
	if promote then
		ProgressionService.SetFlag(player, "lastVehicle", promote)
	end
	local moment = Net.event("BoatLevelMoment")
	local boat = VehicleService.LevelUpBoat(player, index)
	moment:FireAllClients("Start", player.UserId, boat, level)
	task.delay(UpgradeStation.BLAST_AT, function()
		if player.Parent then
			moment:FireAllClients(
				"Swap",
				player.UserId,
				VehicleService.Refit(player, promote),
				level
			)
		end
	end)
	task.delay(UpgradeStation.MOMENT, function()
		if player.Parent then
			VehicleService.ReleaseBoat(player)
		end
	end)
end

local function buy(player: Player, index: number): (boolean, string)
	local data = DataService.Get(player)
	if not data then
		return false, "Data not loaded"
	end
	local ok, reason, price = BoatLevels.canBuy(data.boatLevel, data.cash)
	if not ok then
		return false, reason
	end
	data.cash -= price
	data.boatLevel += 1
	Telemetry.CashSpent(player, price, data.cash, "Upgrade", "BoatLevel")
	Telemetry.Shop(player, "Bought", nil, "BoatLevel", "Cash")
	local step = Events.levelStep(data.boatLevel) -- FirstUpgrade (L2), BoatL3, BoatL5, BoatL11
	if step then
		Telemetry.Funnel(player, step)
	end
	if data.boatLevel == ProgressionConfig.Vehicles.Lifeboat.level then
		BadgeService.Count(player, "LifeboatBought") -- the hull comes with the ladder now (docs/30)
	end
	DataService.MarkDirty(player)
	publish(player, data.boatLevel)
	ProgressionService.Refresh(player)
	playMoment(player, data, data.boatLevel, index)
	task.spawn(DataService.Save, player, false)
	return true, "ok"
end

-- A pre-ladder RIB or Lifeboat pass (or a paid boat worth more than the level) lifts the level once, on the first join
-- after the ladder. A pass bought later is a look only: levels are never sold.
local function applyPassFloor(player: Player)
	local data = DataService.Get(player)
	if
		not (data and data.boatPassFloor)
		or not MonetizationService.WaitForPasses(player, PASS_WAIT)
	then
		publish(player, BoatLevels.level(data and data.boatLevel))
		return
	end
	data = DataService.Get(player)
	if not (data and player.Parent) then
		return
	end
	local level = data.boatLevel
	for id in ProgressionConfig.Vehicles do
		local spec = VehicleConfig.get(id)
		if spec and ProgressionService.OwnsVehiclePass(player, id) then
			level = math.max(
				level,
				BoatLevels.legacyFloor(id, VehicleUpgrades.apply(spec, data.vehicleUpgrades[id]))
			)
		end
	end
	local raised = level > data.boatLevel
	data.boatLevel = level
	data.boatPassFloor = nil
	if BoatLevels.isStageHull(data.flags.lastVehicle) then
		data.flags.lastVehicle = BoatLevels.row(level).hull
	end
	DataService.MarkDirty(player)
	publish(player, level)
	ProgressionService.Refresh(player)
	if raised then
		VehicleService.Refit(player)
	end
end

-- One poll: OutAgain's trip home hands over the free spin; Spin's next trip home ends the tutorial with it unspun (it
-- stays in the wallet), so a player who skips the optional island still reaches the Next chip and the join card.
local function stepTrip(player: Player)
	local data = DataService.Get(player)
	local beat = if data then Onboarding.beat(Onboarding.factsOf(data)) else nil
	if not data or (beat ~= "OutAgain" and beat ~= "Spin") then
		tripOut[player] = nil
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (root and root:IsA("BasePart") and humanoid) then
		return
	end
	local seat = humanoid.SeatPart
	local was = tripOut[player] == true
	local out, finished = Onboarding.trip(
		was,
		seat ~= nil and seat.Name == "DriverSeat",
		GoBack.isHome(root.Position, player:GetAttribute("BayCFrame"))
	)
	tripOut[player] = out
	if out and not was and beat == "OutAgain" then
		Telemetry.Funnel(player, "BackOut")
	end
	if finished and beat == "OutAgain" then
		SpinService.Tutorial(player, true)
	elseif finished then
		data.tutorialStep = Onboarding.STEP_DONE
		DataService.MarkDirty(player)
		ProgressionService.Refresh(player)
	end
end

local function buildPart(spec: UpgradeStation.StationPart, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = spec.name
	part.Size = spec.size
	part.CFrame = spec.cframe
	part.Color = spec.color
	part.Material = spec.material
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- The mesh in place of the fallback Parts: the whole model scaled so the biggest boat fits the bay. No mesh: quay Parts.
local GLOW = { -- the mesh's lamps: flat palette cells, lit here
	_GlowBulb = Color3.fromRGB(255, 226, 170),
	_GlowPort = Color3.fromRGB(226, 52, 44),
	_GlowStbd = Color3.fromRGB(60, 214, 96),
} :: { [string]: Color3 }
local function dressStation(model: Model, index: number)
	local mesh = AssetLoader.cloneStatic(MESH, "LOD0")
	if not mesh then
		for _, spec in UpgradeStation.fallback(index) do
			buildPart(spec, model)
		end
		return
	end
	mesh:ScaleTo(UpgradeStation.SCALE)
	mesh:PivotTo(UpgradeStation.frame(index))
	for _, d in mesh:GetDescendants() do
		if d:IsA("MeshPart") then
			for suffix, color in GLOW do
				if string.find(d.Name, suffix, 1, true) then
					local look = d:FindFirstChildOfClass("SurfaceAppearance")
					if look then
						look:Destroy() -- Neon can't glow through a SurfaceAppearance
					end
					d.Material = Enum.Material.Neon
					d.Color = color
				end
			end
		end
	end
	mesh.Parent = model
	local board = model:FindFirstChild("Board")
	if board and board:IsA("BasePart") then
		board.Transparency = 1 -- the mesh has its own screen behind the SurfaceGui
		board.CanCollide = false
	end
end

local function buildStations()
	local folder = Instance.new("Folder")
	folder.Name = "UpgradeStations"
	for index in RingLayout.Islands do
		local model = Instance.new("Model")
		model.Name = `Station{index}`
		model:SetAttribute("Island", index)
		for _, spec in UpgradeStation.parts(index) do
			local part = buildPart(spec, model)
			if spec.name == "Button" then
				part.CanCollide = false
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "UpgradeBoat"
				prompt.ActionText = "Upgrade"
				prompt.MaxActivationDistance = UpgradeStation.USE_RANGE
				prompt.RequiresLineOfSight = false
				-- one E per key: on foot the boat's seat prompt is also E, and AlwaysShow fired both (a free seat, a paid level)
				prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
				prompt.Parent = part
				buttons[index] = part
			end
		end
		model.Parent = folder
		task.spawn(dressStation, model, index) -- the first load yields; the board works meanwhile
	end
	folder.Parent = Workspace
end

function UpgradeService.Init()
	Net.func("Boat_LevelUp").OnServerInvoke = function(player: Player): (boolean, string)
		local now = os.clock()
		if lastUse[player] and now - lastUse[player] < COOLDOWN then
			return false, "Too fast"
		end
		local index = stationNear(player) or atHelm(player)
		if not index then
			return false, "Too far"
		end
		local data = DataService.Get(player)
		if data and BoatLevels.canBuy(data.boatLevel, data.cash) then
			lastUse[player] = now -- a refused tap can retry at once
		end
		return buy(player, index)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		lastUse[player] = nil
		tripOut[player] = nil
	end)
	if RunService:IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "UpgradeDev"
		dev.OnInvoke = function(cmd: string, level: any): any
			local player = Players:GetPlayers()[1]
			local data = player and DataService.Get(player)
			if not data then
				return nil
			end
			if cmd == "set" then
				data.boatLevel = BoatLevels.level(level)
				DataService.MarkDirty(player)
				publish(player, data.boatLevel)
				ProgressionService.Refresh(player)
				VehicleService.Refit(player, BoatLevels.row(data.boatLevel).hull)
			elseif cmd == "buy" then
				return buy(player, stationNear(player) or DockService.GetPlot(player) or 1)
			end
			return ProgressionService.GetData(player)
		end
		dev.Parent = game:GetService("ServerStorage")
	end
end

function UpgradeService.Start()
	buildStations()
	DataService.OnLoaded(function(player: Player)
		task.spawn(applyPassFloor, player)
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				stepTrip(player)
			end
		end
	end)
end

return UpgradeService
