--!strict
-- SeasonService: the Season Logbook (docs/15 hook H8; docs/04 section 3.1). Season XP comes from
-- every rescue (OperationCompleted, scaled by grade plus big / storm / event bonuses), new album
-- stickers (the rarest call variants), completed challenges (the ChallengeStamps attribute) and
-- streak crates (the one StreakClaim attribute line in StreakService). Tiers pay Cash and Rep
-- through ProgressionService.Award; cosmetics and surprises are data flags read from the tier
-- table, so a claim never touches another service. Unclaimed tiers stay claimable until the
-- season end. The paid track is data only (MonetizationConfig.SeasonLogbook, id 0, ready false).
--
-- The book is the phone's Season app (client SeasonController + UI/SeasonBook); no world desk.
--
-- Remotes (under ReplicatedStorage.Net):
--   Season_State  S->C  Rules.View plus optional { gain, claim }
--   Season_Get    C->S  function -> Rules.View (first pull)
--   Season_Claim  C->S  function (tier) -> { ok, view, reward } or nil
-- Studio: ServerStorage.SeasonDev (BindableFunction) "set" n / "xp" n / "reset" / "claim" tier.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("Season"))
local Rules = require(Shared:WaitForChild("SeasonRules"))

local BadgeService = require(script.Parent.BadgeService)
local DataService = require(script.Parent.DataService)
local OperationService = require(script.Parent.OperationService)
local ProgressionService = require(script.Parent.ProgressionService)
local Telemetry = require(script.Parent:WaitForChild("TelemetryService"))

local SeasonService = {}
SeasonService.Priority = 91

local FLAG = "season"

local stateRemote: RemoteEvent? = nil
local challengeStamps: { [Player]: number } = {}
local devNow: number? = nil -- Studio: the season clock, so the book can be played outside its dates

local function clock(): number
	return devNow or os.time()
end

local function ensureRemoteEvent(folder: Instance, name: string): RemoteEvent
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local created = Instance.new("RemoteEvent")
	created.Name = name
	created.Parent = folder
	return created
end

local function ensureRemoteFunction(folder: Instance, name: string): RemoteFunction
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteFunction") then
		return existing
	end
	local created = Instance.new("RemoteFunction")
	created.Name = name
	created.Parent = folder
	return created
end

local function stateOf(data: any): Rules.State
	local flags = if type(data) == "table" then data.flags else nil
	return Rules.fromFlag(if type(flags) == "table" then flags[FLAG] else nil)
end

local function push(player: Player, state: Rules.State, extra: { [string]: any }?)
	local remote = stateRemote
	if not remote or not player.Parent then
		return
	end
	local view: any = Rules.view(state, clock())
	if extra then
		for key, value in extra do
			view[key] = value
		end
	end
	remote:FireClient(player, view)
end

local function store(player: Player, state: Rules.State): boolean
	return ProgressionService.SetFlag(player, FLAG, Rules.flagTable(state))
end

-- The profile's persisted challenge stamp count (data.flags.challenges.s, ChallengeService).
local function stampsOf(data: any): number
	local flags = if type(data) == "table" then data.flags else nil
	local challenges = if type(flags) == "table" then flags.challenges else nil
	return math.max(
		0,
		math.floor(tonumber(if type(challenges) == "table" then challenges.s else 0) or 0)
	)
end

local function noteTier(player: Player, tier: number)
	if tier >= 10 then
		BadgeService.Count(player, "SeasonTier10")
	end
	if tier >= 30 then
		BadgeService.Count(player, "SeasonTier30")
	end
end

-- Adds XP, stores it and pushes the new view with the gain for the client flash.
local function addXp(player: Player, amount: number, source: string?)
	if amount <= 0 then
		return
	end
	local data = DataService.Get(player)
	if not data then
		return
	end
	if not Rules.live(clock()) then
		return
	end
	local state = stateOf(data)
	local before = Rules.tierForXp(state.xp)
	state.xp = math.min(Rules.MAX_XP, state.xp + math.floor(amount))
	if not store(player, state) then
		return
	end
	local extra: { [string]: any } = { gain = math.floor(amount), source = source }
	local after = Rules.tierForXp(state.xp)
	if after > before then
		extra.tierUp = after
	end
	push(player, state, extra)
	noteTier(player, after)
end

local function refresh(player: Player)
	local data = DataService.Get(player)
	if data then
		push(player, stateOf(data))
	end
end

local function onCompleted(snap: any, helpers: { Player })
	if type(snap) ~= "table" then
		return
	end
	if not Rules.live(clock()) then
		return
	end
	local base = Rules.xpForOperation(snap)
	local rare = snap.grade ~= "Fail" and type(snap.variant) == "string"
	for _, player in helpers do
		if player.Parent then
			local data = DataService.Get(player)
			if data then
				local state = stateOf(data)
				local xp = base
				if rare then
					xp += Rules.stickerXp(state, snap.variant)
				end
				if xp > 0 then
					local before = Rules.tierForXp(state.xp)
					state.xp = math.min(Rules.MAX_XP, state.xp + xp)
					if store(player, state) then
						local extra: { [string]: any } = { gain = xp, source = "Rescue" }
						local after = Rules.tierForXp(state.xp)
						if after > before then
							extra.tierUp = after
						end
						push(player, state, extra)
						noteTier(player, after)
					end
				end
			end
		end
	end
end

-- A claim: no yields, every check before the mutation.
local function claim(player: Player, tier: any): any
	local n = tonumber(tier)
	if not n then
		return nil
	end
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local state = stateOf(data)
	local reward, why = Rules.claim(state, math.floor(n), clock())
	if not reward then
		return { ok = false, reason = why }
	end
	if not store(player, state) then
		return nil
	end
	if reward.cash > 0 or reward.rep > 0 then
		ProgressionService.Award(player, reward.cash, reward.rep, `Season:Tier{reward.tier}`, true)
	end
	Telemetry.Custom(player, "SeasonClaim", reward.tier)
	push(player, state, { claim = reward })
	return { ok = true, reward = reward, view = Rules.view(state, clock()) }
end

local function onChallengeStamps(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local now = math.max(0, math.floor(tonumber(player:GetAttribute("ChallengeStamps")) or 0))
	local before = challengeStamps[player]
	challengeStamps[player] = now
	if before == nil or now <= before then
		return
	end
	addXp(player, (now - before) * Config.xp.challenge, "Challenge")
end

---------------------------------------------------------------- lifecycle

function SeasonService.Init()
	local net = ReplicatedStorage:FindFirstChild("Net")
	if not net or not net:IsA("Folder") then
		net = ReplicatedStorage:WaitForChild("Net")
	end
	stateRemote = ensureRemoteEvent(net, "Season_State")
	local get = ensureRemoteFunction(net, "Season_Get")
	get.OnServerInvoke = function(player: Player)
		local data = DataService.Get(player)
		return if data then Rules.view(stateOf(data), clock()) else nil
	end
	local claimFn = ensureRemoteFunction(net, "Season_Claim")
	claimFn.OnServerInvoke = function(player: Player, tier: any)
		return claim(player, tier)
	end

	DataService.OnLoaded(function(player: Player, data: any)
		challengeStamps[player] = stampsOf(data)
		player:SetAttribute("ChallengeStamps", challengeStamps[player])
		push(player, stateOf(data))
	end)

	OperationService.OperationCompleted:Connect(onCompleted)

	local added = function(player: Player)
		player:GetAttributeChangedSignal("ChallengeStamps"):Connect(function()
			onChallengeStamps(player)
		end)
		-- The one line SeasonService needs from another service (see the reply).
		player:GetAttributeChangedSignal("StreakClaim"):Connect(function()
			if player:GetAttribute("StreakClaim") ~= nil then
				addXp(player, Config.xp.streak, "Streak")
			end
		end)
	end
	for _, player in Players:GetPlayers() do
		added(player)
	end
	Players.PlayerAdded:Connect(added)
	Players.PlayerRemoving:Connect(function(player: Player)
		challengeStamps[player] = nil
	end)

	if RunService:IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "SeasonDev"
		dev.OnInvoke = function(cmd: string, arg: any): any
			local player = Players:GetPlayers()[1]
			local data = if player then DataService.Get(player) else nil
			if not player or not data then
				return nil
			end
			local state = stateOf(data)
			if cmd == "force" then
				devNow = if arg == false then nil else Config.startUtc + 10 * 86400
				push(player, state)
				return Rules.live(clock())
			elseif cmd == "set" then
				state.xp = math.clamp(math.floor(tonumber(arg) or 0), 0, Rules.MAX_XP)
				store(player, state)
				push(player, state)
				return state.xp
			elseif cmd == "xp" then
				addXp(player, tonumber(arg) or 0, "Dev")
				return stateOf(data).xp
			elseif cmd == "reset" then
				store(player, Rules.newState())
				refresh(player)
				return true
			elseif cmd == "claim" then
				return claim(player, tonumber(arg) or 1)
			end
			return Rules.view(state, clock())
		end
		dev.Parent = ServerStorage
	end
end

return SeasonService
