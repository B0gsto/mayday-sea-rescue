--!strict
-- ProgressionService: Cash, Rep, rank, gear and vehicle ownership on top of DataService.
--
-- API (server, see CONTRACT.md):
--   ProgressionService.Award(player, cash, rep, reason)   applies the storm Cash multiplier
--   ProgressionService.GetData(player) -> { cash, rep, rank, rankIndex, gear, vehicles, ... }?
--   ProgressionService.CanUseVehicle(player, vehicleId) -> boolean (and a reason)
--   ProgressionService.GetGearBonus(player, stat) -> multiplier (1 by default)
--   ProgressionService.SetFlag(player, name, value) -> boolean   persisted flag or setting
--     ("coldOpenDone" is the profile's cold-open flag; anything else lands in data.flags)
--   ProgressionService.RankChanged  BindableEvent.Event (player, newRankIndex, oldRankIndex)
-- Remotes: BuyGear (Net, function: itemId = gear id or vehicle id -> ok, reason),
--   PlayerDataChanged (Net, S->C full snapshot plus optional rankUp / award fields),
--   Progression_GetData (own RemoteFunction under ReplicatedStorage.Net: pull the snapshot).
--   Camera_SaveSettings (own RemoteEvent under ReplicatedStorage.Net, C->S: the camera stream's
--     comfort settings table, sanitised, stored as flags.cameraSettings; rate limited).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local ProgressionConfig = require(Shared:WaitForChild("Config"):WaitForChild("ProgressionConfig"))
local Rules = require(Shared:WaitForChild("ProgressionRules"))

local DataService = require(script.Parent.DataService)

local ProgressionService = {}
ProgressionService.Priority = 30

local rankChanged = Instance.new("BindableEvent")
ProgressionService.RankChanged = rankChanged.Event

local lastBuy: { [Player]: number } = {}
local BUY_COOLDOWN = 0.25
local lastSettings: { [Player]: number } = {}

-- Weather (stream D) is required lazily; until it exists, read the folder attributes directly.
local weatherModule: any = nil
local function weatherState(): (string, boolean)
	if weatherModule == nil then
		local module = Shared:FindFirstChild("Weather")
		if module and module:IsA("ModuleScript") then
			local ok, result = pcall(require, module)
			weatherModule = if ok then result else false
		end
	end
	local folder = ReplicatedStorage:FindFirstChild("Weather")
	local state: any = nil
	if weatherModule then
		local ok, result = pcall(weatherModule.getState)
		if ok then
			state = result
		end
	end
	if type(state) ~= "string" and folder then
		state = folder:GetAttribute("State")
	end
	local isGreat = folder ~= nil and folder:GetAttribute("IsGreatStorm") == true
	return if type(state) == "string" then state else "Calm", isGreat
end

local function updateLeaderstats(player: Player, data: Rules.PlayerData)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		local folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		local cash = Instance.new("IntValue")
		cash.Name = "Cash"
		cash.Parent = folder
		local rank = Instance.new("StringValue")
		rank.Name = "Rank"
		rank.Parent = folder
		folder.Parent = player
		stats = folder
	end
	assert(stats, "unreachable")
	local cash = stats:FindFirstChild("Cash") :: IntValue?
	local rank = stats:FindFirstChild("Rank") :: StringValue?
	if cash then
		cash.Value = data.cash
	end
	if rank then
		rank.Value = Rules.rankForRep(data.rep).displayName
	end
	player:SetAttribute("RankIndex", Rules.rankIndexForRep(data.rep))
end

local function push(player: Player, data: Rules.PlayerData, extra: { [string]: any }?)
	updateLeaderstats(player, data)
	local snapshot = Rules.snapshot(data)
	if extra then
		for k, v in extra do
			snapshot[k] = v
		end
	end
	Net.event("PlayerDataChanged"):FireClient(player, snapshot)
end

function ProgressionService.Award(player: Player, cash: number, rep: number, reason: string)
	local data = DataService.Get(player)
	if not data then
		warn(`[ProgressionService] Award to {player.Name} before data loaded ({reason}); dropped`)
		return
	end
	local state, isGreat = weatherState()
	local finalCash, finalRep, mult = Rules.applyAward(cash, rep, state, isGreat)
	local oldRank = Rules.rankIndexForRep(data.rep)
	data.cash += finalCash
	data.rep += finalRep
	local newRank = Rules.rankIndexForRep(data.rep)
	DataService.MarkDirty(player)
	local extra: { [string]: any } = {
		award = { cash = finalCash, rep = finalRep, multiplier = mult, reason = reason },
	}
	if newRank > oldRank then
		local rankDef = ProgressionConfig.Ranks[newRank]
		extra.rankUp =
			{ rankIndex = newRank, rank = rankDef.displayName, unlocks = rankDef.unlocks }
	end
	push(player, data, extra)
	if newRank ~= oldRank then
		rankChanged:Fire(player, newRank, oldRank)
	end
end

function ProgressionService.GetData(player: Player): { [string]: any }?
	local data = DataService.Get(player)
	return if data then Rules.snapshot(data) else nil
end

-- Persists a small flag or setting on the profile (CONTRACT: Operations v2, cold open).
function ProgressionService.SetFlag(player: Player, name: string, value: any): boolean
	local data = DataService.Get(player)
	if not data or not Rules.validFlagName(name) then
		return false
	end
	if name == "coldOpenDone" then
		data.coldOpenDone = value == true
		DataService.MarkDirty(player)
		task.spawn(DataService.Save, player, false) -- a milestone: save it right away
		return true
	else
		local clean = if value == nil then nil else Rules.sanitizeFlag(value)
		if value ~= nil and clean == nil then
			return false
		end
		local count = 0
		for _ in data.flags do
			count += 1
		end
		if data.flags[name] == nil and clean ~= nil and count >= Rules.MAX_FLAGS then
			return false
		end
		data.flags[name] = clean
	end
	DataService.MarkDirty(player)
	return true
end

function ProgressionService.CanUseVehicle(player: Player, vehicleId: string): (boolean, string)
	local data = DataService.Get(player)
	if not data then
		return false, "Data not loaded"
	end
	return Rules.canUseVehicle(data, vehicleId)
end

function ProgressionService.GetGearBonus(player: Player, stat: string): number
	local data = DataService.Get(player)
	return if data then Rules.gearBonus(data.gear, stat) else 1
end

local function buy(player: Player, itemId: any): (boolean, string)
	if type(itemId) ~= "string" or #itemId > 40 then
		return false, "Bad item"
	end
	local now = os.clock()
	if lastBuy[player] and now - lastBuy[player] < BUY_COOLDOWN then
		return false, "Too fast"
	end
	lastBuy[player] = now
	local data = DataService.Get(player)
	if not data then
		return false, "Data not loaded"
	end
	if ProgressionConfig.Gear[itemId] then
		local ok, reason, price = Rules.canBuyGear(data, itemId)
		if not ok then
			return false, reason
		end
		data.cash -= price
		data.gear[itemId] = (data.gear[itemId] or 0) + 1
	elseif ProgressionConfig.Vehicles[itemId] then
		local ok, reason, price = Rules.canBuyVehicle(data, itemId)
		if not ok then
			return false, reason
		end
		data.cash -= price
		data.vehicles[itemId] = true
	else
		return false, "Unknown item"
	end
	DataService.MarkDirty(player)
	push(player, data, { bought = itemId })
	task.spawn(DataService.Save, player, false) -- purchases are saved right away
	return true, "ok"
end

function ProgressionService.Init()
	if game:GetService("RunService"):IsStudio() then
		-- Studio dev hook for play tests: ServerStorage.ProgressionDev:Invoke("award", cash, rep)
		-- or ("data") (execute_luau's own require gets a separate module instance).
		local dev = Instance.new("BindableFunction")
		dev.Name = "ProgressionDev"
		dev.OnInvoke = function(cmd: string, cash: any, rep: any): any
			local p = Players:GetPlayers()[1]
			if not p then
				return nil
			end
			if cmd == "award" then
				ProgressionService.Award(
					p,
					tonumber(cash) or 0,
					tonumber(rep) or 0,
					"Studio dev grant"
				)
			end
			return ProgressionService.GetData(p)
		end
		dev.Parent = game:GetService("ServerStorage")
	end
	Net.event("PlayerDataChanged")
	Net.func("BuyGear").OnServerInvoke = function(player: Player, itemId: any)
		return buy(player, itemId)
	end
	local netFolder = Net.init()
	local getData = netFolder:FindFirstChild("Progression_GetData") :: RemoteFunction?
	if not getData then
		local created = Instance.new("RemoteFunction")
		created.Name = "Progression_GetData"
		created.Parent = netFolder
		getData = created
	end
	assert(getData, "unreachable");
	(getData :: RemoteFunction).OnServerInvoke = function(player: Player)
		return ProgressionService.GetData(player)
	end
	local saveSettings = netFolder:FindFirstChild("Camera_SaveSettings") :: RemoteEvent?
	if not saveSettings then
		local created = Instance.new("RemoteEvent")
		created.Name = "Camera_SaveSettings"
		created.Parent = netFolder
		saveSettings = created
	end
	assert(saveSettings, "unreachable");
	(saveSettings :: RemoteEvent).OnServerEvent:Connect(function(player: Player, settings: any)
		local t = os.clock()
		if type(settings) ~= "table" or t - (lastSettings[player] or -math.huge) < 2 then
			return
		end
		lastSettings[player] = t
		ProgressionService.SetFlag(player, "cameraSettings", settings)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastBuy[player] = nil
		lastSettings[player] = nil
	end)
	DataService.OnLoaded(function(player, data)
		if data.coldOpenDone then
			player:SetAttribute("ColdOpenDone", true) -- OperationService and the client read it
		end
		push(player, data)
	end)
end

return ProgressionService
