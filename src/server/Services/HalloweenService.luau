--!strict
-- HalloweenService: the seasonal "Ghost Ship" event (docs/15 hook H7). The window and Candy
-- Lantern prices live in Config/SeasonalEvents; the pure maths live in SeasonalRules. While the
-- event is live (or Workspace.SeasonalEventForce is true in Studio):
--   * every few minutes a server-wide Ghost Ship big call starts on the existing Capsized Ferry
--     flow (OperationService.ForceBigCall(true)): friendly ferry passengers to take off;
--   * every rescue pays Candy Lanterns (the Ghost Ship call pays more);
--   * the pumpkin stall on the quay sells the lantern livery, the ghost-dog collar and the bay
--     pumpkin for Candy only (docs/15 section 1: nothing for Robux).
-- The lantern livery and the collar are data.flags.halloween cosmetics with a live green glow on
-- the player's boat and Bosun. The client builds the pumpkins, the spectral ferry and the stall
-- (World/HalloweenWorld); this service owns the calls, the money and the decorations.
-- Replicated state: ReplicatedStorage.HalloweenState attributes Active, Now, EndsAt, DaysLeft,
-- GhostShipOp. Remotes under ReplicatedStorage.Net: Halloween_State S->C view, Halloween_Get and
-- Halloween_Buy C->S functions. Studio: ServerStorage.HalloweenDev (BindableFunction) "award" n,
-- "buy" id, "call", "state".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rules = require(Shared:WaitForChild("SeasonalRules"))
local SeasonalEvents = require(Shared:WaitForChild("Config"):WaitForChild("SeasonalEvents"))

local BadgeService = require(script.Parent.BadgeService)
local DataService = require(script.Parent.DataService)
local DogService = require(script.Parent.DogService)
local OperationService = require(script.Parent.OperationService)
local ProgressionService = require(script.Parent.ProgressionService)
local VehicleService = require(script.Parent.VehicleService)

local EVENT = SeasonalEvents.Halloween
local FLAG = "halloween"
local FOLDER_NAME = "HalloweenState"
local TICK = 1
local DECORATE_TICK = 2
local BUY_COOLDOWN = 0.4
local CANDY_GREEN = Color3.fromRGB(120, 255, 150)

local HalloweenService = {}
HalloweenService.Priority = 92

local folder: Folder
local stateRemote: RemoteEvent? = nil
local lastCallAt = 0
local lastBuy: { [Player]: number } = {}
local lastOffer: { [Player]: number } = {}

local function offset(): number
	local value = Workspace:GetAttribute("EventClockOffset")
	return if type(value) == "number"
			and (RunService:IsStudio() or Workspace:GetAttribute("DevBoard"))
		then value
		else 0
end

local function now(): number
	return os.time() + offset()
end

local function forced(): boolean
	return RunService:IsStudio() and Workspace:GetAttribute(SeasonalEvents.DevAttribute) == true
end

local function active(): boolean
	return Rules.live(EVENT, now(), forced())
end

local function stateOf(player: Player): Rules.State
	local data = DataService.Get(player)
	return Rules.fromFlag(if data then data.flags[FLAG] else nil)
end

local function owned(player: Player, flag: string): boolean
	return stateOf(player).owned[flag] == true
end

local function viewOf(player: Player): { [string]: any }
	local state = stateOf(player)
	local t = now()
	return {
		active = Rules.live(EVENT, t, forced()),
		now = t,
		endsAt = EVENT.endUtc,
		daysLeft = math.max(if forced() then 1 else 0, Rules.daysLeft(EVENT, t)),
		candy = state.candy,
		owned = state.owned,
	}
end

local function push(player: Player)
	local remote = stateRemote
	if remote and player.Parent then
		remote:FireClient(player, viewOf(player))
	end
end

local function save(player: Player, state: Rules.State): boolean
	return ProgressionService.SetFlag(player, FLAG, Rules.flagTable(state))
end

-- LiveOps DoubleCandy (G60): the seasonal currency pays x2 while the event runs. Lazy: the service
-- loads after this one; a missing schedule means x1.
local function liveOpsCandyMultiplier(): number
	local module = script.Parent:FindFirstChild("LiveOpsService")
	if not module then
		return 1
	end
	local ok, liveOps = pcall(require, module)
	if not ok or type(liveOps) ~= "table" then
		return 1
	end
	local fine, multipliers = pcall((liveOps :: any).Multipliers)
	if not fine or type(multipliers) ~= "table" then
		return 1
	end
	return tonumber(multipliers.candy) or 1
end

local function awardCandy(player: Player, amount: number)
	local data = DataService.Get(player)
	if not data or amount <= 0 then
		return
	end
	if active() then
		amount = math.floor(amount * liveOpsCandyMultiplier() + 0.5)
	end
	local state = stateOf(player)
	if save(player, Rules.reward(state, amount)) then
		push(player)
	end
end

---------------------------------------------------------------- decorations

local function weldTo(parent: BasePart, part: BasePart, cf: CFrame)
	part.CFrame = cf
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.Parent = parent.Parent
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = parent
	weld.Part1 = part
	weld.Parent = part
end

local function decorateBoat(model: Model)
	if model:GetAttribute("HalloweenLantern") then
		return
	end
	local bow = model:FindFirstChild("BowPoint", true)
	local hull = model.PrimaryPart
	if bow and bow:IsA("Attachment") and bow.Parent and bow.Parent:IsA("BasePart") then
		hull = bow.Parent
	end
	if not hull or not hull:IsA("BasePart") then
		return
	end
	local at = if bow and bow:IsA("Attachment")
		then bow.WorldCFrame * CFrame.new(0, 2.2, 0)
		else hull.CFrame * CFrame.new(0, 4, 0)
	local pole = Instance.new("Part")
	pole.Name = "HalloweenLanternPole"
	pole.Size = Vector3.new(0.16, 1.6, 0.16)
	pole.Color = Color3.fromRGB(74, 58, 40)
	pole.Material = Enum.Material.Wood
	weldTo(hull, pole, at * CFrame.new(0, 0.8, 0))
	local lamp = Instance.new("Part")
	lamp.Name = "HalloweenLantern"
	lamp.Shape = Enum.PartType.Ball
	lamp.Size = Vector3.new(0.9, 0.9, 0.9)
	lamp.Color = CANDY_GREEN
	lamp.Material = Enum.Material.Neon
	weldTo(hull, lamp, at * CFrame.new(0, 1.75, 0))
	local light = Instance.new("PointLight")
	light.Color = CANDY_GREEN
	light.Brightness = 2
	light.Range = 18
	light.Shadows = false
	light.Parent = lamp
	model:SetAttribute("HalloweenLantern", true)
end

local function decorateDog(player: Player)
	local dog = DogService.GetDog(player)
	if not dog or dog:GetAttribute("HalloweenCollar") then
		return
	end
	local neck = dog:FindFirstChild("Neck")
	if not neck or not neck:IsA("BasePart") then
		return
	end
	local collar = Instance.new("Part")
	collar.Name = "HalloweenCollar"
	collar.Shape = Enum.PartType.Ball
	collar.Size = Vector3.new(0.85, 0.3, 0.85)
	collar.Color = CANDY_GREEN
	collar.Material = Enum.Material.Neon
	collar.Transparency = 0.2
	weldTo(neck, collar, neck.CFrame * CFrame.new(0, 0.12, 0))
	local light = Instance.new("PointLight")
	light.Color = CANDY_GREEN
	light.Brightness = 1.2
	light.Range = 12
	light.Shadows = false
	light.Parent = collar
	dog:SetAttribute("HalloweenCollar", true)
end

local function decorate(player: Player)
	if not owned(player, "livery") then
		return
	end
	local boat = VehicleService.GetVehicle(player)
	if boat then
		decorateBoat(boat)
	end
end

---------------------------------------------------------------- the Ghost Ship call

local function ghostCallRunning(): boolean
	for _, info in OperationService.GetActiveOperations() do
		if info.isBig then
			return true
		end
	end
	return false
end

local function publishGhostOp()
	local opId = ""
	for _, info in OperationService.GetActiveOperations() do
		if info.isBig and info.variant == "GhostShip" then
			opId = info.id
			break
		end
	end
	folder:SetAttribute("GhostShipOp", opId)
end

local function startGhostCall()
	lastCallAt = now()
	local ok = pcall(OperationService.ForceBigCall, true)
	if not ok then
		warn("[HalloweenService] Ghost Ship call could not start")
	end
	publishGhostOp()
end

---------------------------------------------------------------- stall

local function nearStall(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	local dx = root.Position.X - EVENT.stallPosition.X
	local dz = root.Position.Z - EVENT.stallPosition.Z
	return dx * dx + dz * dz <= EVENT.stallRange * EVENT.stallRange
end

local function buy(player: Player, id: any, skipRange: boolean?): (boolean, string)
	if type(id) ~= "string" then
		return false, "Unknown"
	end
	if not active() then
		return false, "Closed"
	end
	local t = os.clock()
	if t - (lastBuy[player] or 0) < BUY_COOLDOWN then
		return false, "Wait"
	end
	lastBuy[player] = t
	if not skipRange and not nearStall(player) then
		return false, "Too far"
	end
	local state = stateOf(player)
	local after, reason = Rules.buy(EVENT, state, id)
	if not after then
		return false, reason or "No"
	end
	if not save(player, after) then
		return false, "Save failed"
	end
	local item = Rules.item(EVENT, id)
	if item and item.flag == "livery" then
		local boat = VehicleService.GetVehicle(player)
		if boat then
			decorateBoat(boat)
		end
	end
	push(player)
	return true, "ok"
end

local function ensureRemoteEvent(parent: Instance, name: string): RemoteEvent
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local created = Instance.new("RemoteEvent")
	created.Name = name
	created.Parent = parent
	return created
end

local function ensureRemoteFunction(parent: Instance, name: string): RemoteFunction
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("RemoteFunction") then
		return existing
	end
	local created = Instance.new("RemoteFunction")
	created.Name = name
	created.Parent = parent
	return created
end

local function refresh()
	local t = now()
	local live = Rules.live(EVENT, t, forced())
	folder:SetAttribute("Active", live)
	folder:SetAttribute("Now", t)
	folder:SetAttribute("EndsAt", EVENT.endUtc)
	folder:SetAttribute("DaysLeft", Rules.daysLeft(EVENT, t))
	if live then
		publishGhostOp()
		local ghostOp = folder:GetAttribute("GhostShipOp")
		if ghostOp ~= "" then
			-- the server-wide call keeps offering itself to players who are free
			for _, player in Players:GetPlayers() do
				if
					t - (lastOffer[player] or 0) >= 30
					and not OperationService.GetOperationOf(player)
				then
					lastOffer[player] = t
					pcall(OperationService.OfferBigCall, player)
				end
			end
		end
		local players = #Players:GetPlayers()
		if players > 0 and not ghostCallRunning() and t - lastCallAt >= EVENT.callCooldown then
			startGhostCall()
		end
	else
		folder:SetAttribute("GhostShipOp", "")
	end
end

function HalloweenService.Init()
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	folder:SetAttribute("Active", false)
	folder:SetAttribute("Now", os.time())
	folder:SetAttribute("EndsAt", EVENT.endUtc)
	folder:SetAttribute("DaysLeft", 0)
	folder:SetAttribute("GhostShipOp", "")

	local net = ReplicatedStorage:WaitForChild("Net")
	stateRemote = ensureRemoteEvent(net, "Halloween_State")
	ensureRemoteFunction(net, "Halloween_Get").OnServerInvoke = function(player: Player)
		return viewOf(player)
	end
	ensureRemoteFunction(net, "Halloween_Buy").OnServerInvoke = function(player: Player, id: any)
		return buy(player, id)
	end

	OperationService.OperationCompleted:Connect(function(info, helpers)
		if not active() then
			return
		end
		local amount = Rules.candyFor(EVENT, info.variant == "GhostShip")
		for _, player in helpers do
			awardCandy(player, amount)
			if info.variant == "GhostShip" then
				BadgeService.Count(player, "GhostShip")
			end
		end
	end)
	VehicleService.VehicleSpawned:Connect(function(player, model)
		if owned(player, "livery") then
			decorateBoat(model)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastBuy[player] = nil
		lastOffer[player] = nil
	end)
	if RunService:IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "HalloweenDev"
		dev.OnInvoke = function(cmd: string, value: any): any
			local player = Players:GetPlayers()[1]
			if cmd == "award" and player then
				awardCandy(player, tonumber(value) or 5)
				return viewOf(player)
			elseif cmd == "buy" and player then
				return buy(player, value, true)
			elseif cmd == "call" then
				startGhostCall()
				return viewOf(player)
			elseif cmd == "state" and player then
				return viewOf(player)
			end
			return nil
		end
		dev.Parent = ServerStorage
	end
end

function HalloweenService.Start()
	DataService.OnLoaded(function(player: Player, _data)
		-- the join push and the first decorate happen once the profile is in
		task.defer(function()
			if player.Parent then
				push(player)
				decorate(player)
			end
		end)
	end)
	Players.PlayerAdded:Connect(function(player)
		task.delay(3, function()
			if player.Parent then
				push(player)
			end
		end)
	end)
	refresh()
	local elapsed = 0
	while true do
		task.wait(TICK)
		refresh()
		elapsed += TICK
		if elapsed >= DECORATE_TICK then
			elapsed = 0
			for _, player in Players:GetPlayers() do
				decorate(player)
				if owned(player, "collar") then
					decorateDog(player)
				end
			end
		end
	end
end

return HalloweenService
