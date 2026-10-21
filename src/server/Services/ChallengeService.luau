--!strict
-- ChallengeService: daily and weekly challenges (docs/03 section 9, LU-1).
--
-- Rolls come from ChallengeConfig (pure maths in Shared/ChallengeRules): 3 daily at 00:00 UTC,
-- 5 weekly on Monday 00:00 UTC, per player and persisted on the profile (data.flags.challenges).
-- Progress is credited from OperationService.OperationCompleted, so no other service is edited:
-- completed ops, kind, storm calls, big calls, crew ops, rescues, the player's Gold steps, search
-- finds (Bosun's finds) and treatments. Completions pay Cash/Rep through ProgressionService.Award;
-- finishing all three daily challenges pays the set bonus and Bosun's treat (DogService.Treat).
-- Each weekly stamp also counts toward the month (data.flags.challengeMonth): the fourth sets
-- data.flags.monthlyLivery to that month's key (data only).
--
-- Challenge Reroll: the MonetizationConfig product (id 0 / ready = false until RP-M4). The receipt
-- path is MonetizationService.OnProduct; a reroll swaps the first unfinished daily challenge,
-- within RerollDailyLimit per UTC day.
--
-- Board and tracker: the server puts the physical board by the quay spawn (Workspace
-- .StationChallengeBoard); the client draws that player's rolls on it (SurfaceGui) and in a small
-- HUD tracker. Remotes (under ReplicatedStorage.Net):
--   Challenge_State  S->C  ChallengeRules.View after a roll, a completion or a reroll
--   Challenge_Get    C->S  function -> ChallengeRules.View (first pull)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ChallengeConfig = require(Shared:WaitForChild("Config"):WaitForChild("ChallengeConfig"))
local Net = require(Shared:WaitForChild("Net"))
local Rules = require(Shared:WaitForChild("ChallengeRules"))

local DataService = require(script.Parent.DataService)
local DogService = require(script.Parent.DogService)
local MonetizationService = require(script.Parent.MonetizationService)
local OperationService = require(script.Parent.OperationService)
local ProgressionService = require(script.Parent.ProgressionService)
local Telemetry = require(script.Parent:WaitForChild("TelemetryService"))

local ChallengeService = {}
ChallengeService.Priority = 90

local FLAG = "challenges"
local MONTH_FLAG = "challengeMonth"
local LIVERY_FLAG = "monthlyLivery"
local BOARD_NAME = "StationChallengeBoard"

local stateRemote: RemoteEvent? = nil
local getRemote: RemoteFunction? = nil

local function flagOf(data: any): any
	if type(data) ~= "table" or type(data.flags) ~= "table" then
		return nil
	end
	return data.flags[FLAG]
end

local function stateFor(player: Player, data: any): (Rules.State, boolean)
	return Rules.ensure(Rules.fromFlagTable(flagOf(data)), player.UserId, os.time())
end

local function store(player: Player, state: Rules.State)
	-- SetFlag sanitizes the flat table and marks the profile dirty; the next autosave persists it.
	ProgressionService.SetFlag(player, FLAG, Rules.flagTable(state))
	player:SetAttribute("ChallengeStamps", state.stamps)
end

local function push(player: Player, state: Rules.State)
	if stateRemote and player.Parent then
		stateRemote:FireClient(player, Rules.view(state, os.time()))
	end
end

local function refresh(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local state, changed = stateFor(player, data)
	if changed then
		store(player, state)
	end
	push(player, state)
end

-- One weekly stamp for this UTC month; the fourth unlocks that month's livery (data only).
local function creditMonth(player: Player, data: any)
	local raw = if type(data.flags) == "table" then data.flags[MONTH_FLAG] else nil
	local month, unlocked = Rules.monthlyStamp(raw, os.time())
	ProgressionService.SetFlag(player, MONTH_FLAG, month)
	if unlocked then
		ProgressionService.SetFlag(player, LIVERY_FLAG, month.month)
	end
end

local function apply(player: Player, counts: Rules.Counts)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local state, _ = stateFor(player, data)
	local newly = Rules.addProgress(state, counts)
	local settled = Rules.settle(state)
	store(player, state)
	local snapshot = ProgressionService.GetData(player)
	local rankIndex = if snapshot and type(snapshot.rankIndex) == "number"
		then snapshot.rankIndex
		else 1
	for _, def in newly do
		local cash, rep = Rules.rewardFor(def, rankIndex)
		Telemetry.Custom(player, "ChallengeDone", 1, def.scope, def.id)
		ProgressionService.Award(player, cash, rep, `Challenge:{def.id}`)
	end
	if settled.dailyBonus then
		ProgressionService.Award(player, ChallengeConfig.DailyBonusCash, 0, "Challenge:DailyBonus")
		DogService.Treat(player)
	end
	if settled.weeklyStamp then
		creditMonth(player, data)
	end
	push(player, state)
end

local function onOperationCompleted(snap: any, helpers: { Player })
	local crewSize = #helpers
	for _, player in helpers do
		local counts = Rules.operationCredit(snap, player.UserId, crewSize)
		if next(counts) ~= nil then
			apply(player, counts)
		end
	end
end

-- A reroll grant: no yields, all checks before the mutation (MonetizationService contract).
local function rerollGrant(player: Player, data: any): boolean
	local state, _ = stateFor(player, data)
	local picked = Rules.rerollDaily(state, player.UserId, os.time())
	if not picked then
		return false
	end
	return ProgressionService.SetFlag(player, FLAG, Rules.flagTable(state))
end

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function buildBoard()
	local model = Instance.new("Model")
	model.Name = BOARD_NAME
	-- RP-P1: the client mounts a local SurfaceGui on the panel once; a streamed-out Atomic board
	-- would come back as new parts and the printed board would never remount. Four parts, keep it.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	local wood = Color3.fromRGB(92, 66, 44)
	local paper = Color3.fromRGB(32, 44, 52)
	local cf = CFrame.new(-72, 7.35, -8) * CFrame.Angles(0, -math.pi / 2, 0)
	local panel =
		part(model, "Panel", Vector3.new(5.2, 4.7, 0.2), cf, paper, Enum.Material.SmoothPlastic)
	model.PrimaryPart = panel
	-- Posts frame the panel from its outer edges so nothing crosses the printed face.
	for _, z in { -10.6, -5.4 } do
		part(
			model,
			"Post",
			Vector3.new(0.24, 5.6, 0.24),
			CFrame.new(-71.94, 6.8, z),
			wood,
			Enum.Material.Wood
		)
	end
	part(
		model,
		"Cap",
		Vector3.new(0.3, 0.24, 5.5),
		CFrame.new(-71.94, 9.85, -8),
		wood,
		Enum.Material.Wood
	)
	panel:SetAttribute("ChallengeBoard", true)
	model.Parent = Workspace
end

function ChallengeService.Init()
	local netFolder = Net.init()

	local event = netFolder:FindFirstChild("Challenge_State")
	if not event or not event:IsA("RemoteEvent") then
		local created = Instance.new("RemoteEvent")
		created.Name = "Challenge_State"
		created.Parent = netFolder
		event = created
	end
	stateRemote = event :: RemoteEvent

	local get = netFolder:FindFirstChild("Challenge_Get")
	if not get or not get:IsA("RemoteFunction") then
		local created = Instance.new("RemoteFunction")
		created.Name = "Challenge_Get"
		created.Parent = netFolder
		get = created
	end
	getRemote = get :: RemoteFunction
	(getRemote :: RemoteFunction).OnServerInvoke = function(player: Player)
		local data = DataService.Get(player)
		if not data then
			return nil
		end
		local state, changed = stateFor(player, data)
		if changed then
			store(player, state)
		end
		return Rules.view(state, os.time())
	end

	DataService.OnLoaded(function(player, data)
		local state, changed = stateFor(player, data)
		if changed then
			store(player, state)
		else
			player:SetAttribute("ChallengeStamps", state.stamps)
		end
		push(player, state)
	end)

	OperationService.OperationCompleted:Connect(onOperationCompleted)

	MonetizationService.OnProduct("ChallengeReroll", rerollGrant, function(player, _receipt, fresh)
		if fresh then
			task.spawn(refresh, player)
		end
	end)
end

function ChallengeService.Start()
	task.spawn(buildBoard)
	-- Rolls refresh at 00:00 UTC even for players who stay in the server across the day boundary.
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				local data = DataService.Get(player)
				if data then
					local state, changed = stateFor(player, data)
					if changed then
						store(player, state)
						push(player, state)
					end
				end
			end
		end
	end)
end

return ChallengeService
