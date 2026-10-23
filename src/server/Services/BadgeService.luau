--!strict
-- BadgeService: Roblox badge awards (docs/03 section 8, MVP set; ids in Shared.Config.BadgeConfig, 0 = off).
--
-- Triggers: OperationService.OperationCompleted (the debrief snapshot: grade and step grades per
-- userId) through Shared.BadgeRules; the RankIndex player attribute (rank badges, also re-checked on
-- join); and BadgeService.Award / BadgeService.Count for other systems.
--
-- Profile fields (DataService, extra keys on the player's data): badgeCounters { [key]: number } and
-- badgesAwarded { [key]: true }. Counters run even while a badge's id is 0, so switching a badge on later
-- awards it to players who already qualify. A badge is marked awarded only after AwardBadge (or
-- UserHasBadgeAsync) confirms it; failures retry on the next trigger.
--
--   BadgeService.Award(player, key) -> boolean          award now (true when owned afterwards)
--   BadgeService.Count(player, key, n?) -> ()           bump a counted badge (awards at its threshold)
--   BadgeService.Once(player, key, token) -> ()         bump, but each token (species, kind) only once
--   BadgeService.Has(player, key) -> boolean            awarded this profile (cached, no web call)

local Badges = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BadgeConfig = require(Shared:WaitForChild("Config"):WaitForChild("BadgeConfig"))
local BadgeRules = require(Shared:WaitForChild("BadgeRules"))
local ProgressionConfig = require(Shared:WaitForChild("Config"):WaitForChild("ProgressionConfig"))

local BadgeService = {}
BadgeService.Priority = 60

local DataService: any = nil
local busy: { [Player]: { [string]: boolean } } = {}
local rankIds: { string } = {}

type Store = { badgeCounters: { [string]: number }, badgesAwarded: { [string]: boolean } }

local function store(player: Player): Store?
	local data: any = DataService and DataService.Get(player)
	if type(data) ~= "table" then
		return nil
	end
	if type(data.badgeCounters) ~= "table" then
		data.badgeCounters = {}
	end
	if type(data.badgesAwarded) ~= "table" then
		data.badgesAwarded = {}
	end
	return data :: Store
end

local function dirty(player: Player)
	pcall(DataService.MarkDirty, player)
end

local function award(player: Player, key: string): boolean
	local b = BadgeConfig.get(key)
	if not b then
		warn(`[BadgeService] unknown badge {key}`)
		return false
	end
	local s = store(player)
	if s and s.badgesAwarded[key] then
		return true
	end
	if b.id <= 0 or not player.Parent then
		return false -- off: the counter (if any) keeps the progress for later
	end
	local mine = busy[player]
	if not mine or mine[key] then
		return false
	end
	mine[key] = true
	local owned = false
	local okHas, has = pcall(Badges.UserHasBadgeAsync, Badges, player.UserId, b.id)
	if okHas and has then
		owned = true
	elseif okHas then
		local ok, result = pcall(Badges.AwardBadge, Badges, player.UserId, b.id)
		owned = ok and result == true
		if not ok then
			warn(`[BadgeService] AwardBadge {key} ({b.id}) for {player.Name} failed: {result}`)
		end
	end
	if busy[player] then
		busy[player][key] = nil
	end
	if owned and s and player.Parent then
		s.badgesAwarded[key] = true
		dirty(player)
	end
	return owned
end

function BadgeService.Award(player: Player, key: string): boolean
	return award(player, key)
end

function BadgeService.Has(player: Player, key: string): boolean
	local s = store(player)
	return s ~= nil and s.badgesAwarded[key] == true
end

local function applyCounts(player: Player, increments: { [string]: number })
	local s = store(player)
	if not s or next(increments) == nil then
		return
	end
	local due = BadgeRules.apply(s.badgeCounters, increments)
	dirty(player)
	for _, key in due do
		if not s.badgesAwarded[key] then
			task.spawn(award, player, key)
		end
	end
end

function BadgeService.Count(player: Player, key: string, n: number?)
	applyCounts(player, { [key] = n or 1 })
end

function BadgeService.Once(player: Player, key: string, token: string)
	local s = store(player)
	if s then
		applyCounts(player, BadgeRules.once(s.badgeCounters, key, token))
	end
end

local function checkRank(player: Player)
	local idx = player:GetAttribute("RankIndex")
	if type(idx) ~= "number" then
		return
	end
	local s = store(player)
	for _, key in BadgeRules.rankBadges(idx, rankIds) do
		if not (s and s.badgesAwarded[key]) then
			task.spawn(award, player, key)
		end
	end
end

local function onOperationCompleted(snap: any, helpers: { Player })
	local helperSet: { [Player]: boolean } = {}
	for _, p in helpers do
		helperSet[p] = true
	end
	local done = BadgeRules.completed(snap)
	for _, p in snap.assignedTo or helpers do
		if typeof(p) == "Instance" and p:IsA("Player") and p.Parent then
			local ok, err = pcall(function()
				applyCounts(p, BadgeRules.opProgress(snap, p.UserId, helperSet[p] == true))
				if done and helperSet[p] == true then
					local s = store(p)
					if s then
						applyCounts(p, BadgeRules.once(s.badgeCounters, "EveryCall", snap.kind))
					end
				end
			end)
			if not ok then
				warn(`[BadgeService] op {snap.id}: {err}`)
			end
		end
	end
end

local function onPlayer(player: Player)
	busy[player] = {}
	player:GetAttributeChangedSignal("RankIndex"):Connect(function()
		checkRank(player)
	end)
end

function BadgeService.Init()
	for _, r in ProgressionConfig.Ranks do
		table.insert(rankIds, r.id)
	end
	DataService = require(script.Parent:WaitForChild("DataService")) :: any
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(p)
		busy[p] = nil
	end)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
end

function BadgeService.Start()
	local OperationService: any = require(script.Parent:WaitForChild("OperationService"))
	OperationService.OperationCompleted:Connect(onOperationCompleted)
	DataService.OnLoaded(function(player: Player)
		task.defer(checkRank, player)
		-- counted badges switched on since the last session
		local s = store(player)
		if s then
			for key, n in s.badgeCounters do
				local b = BadgeConfig.get(key)
				if b and b.id > 0 and not s.badgesAwarded[key] and n >= (b.count or 1) then
					task.spawn(award, player, key)
				end
			end
		end
	end)
	if RunService:IsStudio() then
		local off = 0
		for _, key in BadgeConfig.Order do
			if not BadgeConfig.enabled(key) then
				off += 1
			end
		end
		if off > 0 then
			print(
				`[BadgeService] {off} of {#BadgeConfig.Order} badges have id 0 (off): docs/13 U-6`
			)
		end
	end
end

return BadgeService
