--!strict
-- ProgressionService: Cash, Rep, rank, gear and vehicle ownership on top of DataService.
--
-- API (server, see CONTRACT.md):
--   ProgressionService.Award(player, cash, rep, reason)   applies the storm and paid Cash multipliers
--     (2x Cash, Cash Boost, Crew Boost: Monetization/CashEffects, RP-M2; Rep is never multiplied)
--   ProgressionService.Refresh(player, extra?)  re-push the snapshot (after a purchase grant)
--   ProgressionService.GetData(player) -> { cash, rep, rank, rankIndex, gear, vehicles, ... }?
--   ProgressionService.CanUseVehicle(player, vehicleId) -> boolean (and a reason)
--   ProgressionService.GetGearBonus(player, stat) -> multiplier (1 by default)
--   ProgressionService.SetFlag(player, name, value) -> boolean   persisted flag or setting
--     ("coldOpenDone" is the profile's cold-open flag; anything else lands in data.flags)
--   ProgressionService.RankChanged  BindableEvent.Event (player, newRankIndex, oldRankIndex)
--   ProgressionService.RecordTraining(player, kind, grade, steps, isExercise, cannotFail?)
--     -> TrainingResult? (ProgressionRules): exercise passes and certification progress from a
--     finished operation; pays the exercise's first-pass reward; sets Cert<Id> attributes.
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

local CashEffects = require(script.Parent:WaitForChild("Monetization"):WaitForChild("CashEffects"))
local DataService = require(script.Parent.DataService)
local Telemetry = require(script.Parent:WaitForChild("TelemetryService")) -- RP-A1 analytics

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
	local rankIndex = Rules.rankIndex(data) -- Rep plus the rank's certification
	if rank then
		rank.Value = ProgressionConfig.Ranks[rankIndex].displayName
	end
	player:SetAttribute("RankIndex", rankIndex)
	-- CertHelm, CertCasualtyCare, CertRescueSwimmer: read by OperationService and the mechanics
	for _, id in ProgressionConfig.CertOrder do
		player:SetAttribute(`Cert{id}`, if data.certs[id] then true else nil)
	end
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
	Telemetry.CashFlow(player, extra, data.cash) -- every Cash source travels as extra.award
end

function ProgressionService.Award(player: Player, cash: number, rep: number, reason: string)
	local data = DataService.Get(player)
	if not data then
		warn(`[ProgressionService] Award to {player.Name} before data loaded ({reason}); dropped`)
		return
	end
	local state, isGreat = weatherState()
	local paid = CashEffects.multiplier(player) -- Cash only (docs/04 sections 3 and 4.2)
	local finalCash, finalRep, mult = Rules.applyAward(cash * paid, rep, state, isGreat)
	mult *= paid
	local oldRank = Rules.rankIndex(data)
	data.cash += finalCash
	data.rep += finalRep
	local newRank = Rules.rankIndex(data)
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

-- A finished operation or exercise: certification progress, exercise passes and their first-pass
-- reward (docs 03 sections 2 and 3.1). OperationService calls it once per player at the debrief
-- and puts result.badges in Ops_Debrief.
function ProgressionService.RecordTraining(
	player: Player,
	kind: string,
	grade: string,
	steps: { Rules.StepRecord },
	isExercise: boolean,
	cannotFail: boolean?
): Rules.TrainingResult?
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local result = if isExercise
		then Rules.recordExercise(data, kind, grade, steps, player.UserId, cannotFail)
		else Rules.recordOperation(data, kind, steps, player.UserId)
	if not isExercise and (grade == "Gold" or grade == "Silver" or grade == "Bronze") then
		-- saved count of finished operations (the Chandlery's priced shelves open after 3, docs/04 rule 6)
		local done = (
			if type(data.flags.opsCompleted) == "number" then data.flags.opsCompleted else 0
		) + 1
		data.flags.opsCompleted = math.min(done, 1e6)
		player:SetAttribute("OpsCompletedTotal", data.flags.opsCompleted)
		DataService.MarkDirty(player)
	end
	if #result.counted == 0 and #result.earned == 0 and not result.passed then
		return result
	end
	DataService.MarkDirty(player)
	local paid = result.reward.cash > 0 or result.reward.rep > 0
	if paid then
		-- Award pushes the snapshot and reports a rank-up the reward's Rep itself brings
		ProgressionService.Award(player, result.reward.cash, result.reward.rep, `Exercise:{kind}`)
	end
	-- a rank-up the certification brings (the Rep was already there): Award cannot see it
	if result.rankAfter > result.rankBefore then
		local rankDef = ProgressionConfig.Ranks[result.rankAfter]
		push(player, data, {
			certsEarned = result.earned,
			rankUp = {
				rankIndex = result.rankAfter,
				rank = rankDef.displayName,
				unlocks = rankDef.unlocks,
			},
		})
		rankChanged:Fire(player, result.rankAfter, result.rankBefore)
	elseif not paid then
		push(player, data, { certsEarned = result.earned })
	end
	if #result.earned > 0 then
		task.spawn(DataService.Save, player, false) -- a certification is a milestone
		-- one Roblox badge per certification (RP-B1's BadgeService; skipped until it exists)
		local module = script.Parent:FindFirstChild("BadgeService")
		if module and module:IsA("ModuleScript") then
			local ok, badges = pcall(require, module)
			if ok and type(badges) == "table" and type((badges :: any).Award) == "function" then
				for _, id in result.earned do
					task.spawn(
						(badges :: any).Award,
						player,
						ProgressionConfig.Certifications[id].badge
					)
				end
			end
		end
	end
	return result
end

function ProgressionService.Refresh(player: Player, extra: { [string]: any }?)
	local data = DataService.Get(player)
	if data then
		push(player, data, extra)
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
		Telemetry.CashSpent(player, price, data.cash, "Gear", itemId)
	elseif ProgressionConfig.Vehicles[itemId] then
		local ok, reason, price = Rules.canBuyVehicle(data, itemId)
		if not ok then
			return false, reason
		end
		data.cash -= price
		data.vehicles[itemId] = true
		Telemetry.CashSpent(player, price, data.cash, "Vehicle", itemId)
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
		if type(data.flags.opsCompleted) == "number" then
			player:SetAttribute("OpsCompletedTotal", data.flags.opsCompleted)
		end
		push(player, data)
	end)
	CashEffects.init(ProgressionService.Refresh)
end

function ProgressionService.Start()
	CashEffects.start()
end

return ProgressionService
