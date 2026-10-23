--!strict
-- StreakService: the daily streak crate and the welcome-back crate (docs/15 section 1, hook H5).
-- One crate per UTC day per player, at their launch bay on the spawn path (docs/16 K12,
-- BayLaunch.CRATE; the station porch when no bay). StreakRules owns the day maths and the
-- forgiveness; StreakConfig owns the payouts. Cash goes through ProgressionService.Award and the
-- streak lives on the profile (data.flags.streak).
--
-- The crate and its day-pip sign are built locally by each client (World/StreakCrate,
-- World/StreakSign) so only that player sees their own crate open. Remotes (under
-- ReplicatedStorage.Net):
--   Streak_State  S->C  { day, streak, available, secondsToDay, preview? }
--   Streak_Get    C->S  function -> the same view (first pull)
--   Streak_Open   C->S  function -> { ok, cash, cashAfter, streak, welcome, cosmetic } or nil
-- Studio: ServerStorage.StreakDev (BindableFunction) sets today's crate to a streak day.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BayLaunch = require(Shared:WaitForChild("Boat"):WaitForChild("BayLaunch"))
local GroupReward = require(Shared:WaitForChild("GroupReward"))
local Net = require(Shared:WaitForChild("Net"))
local Rules = require(Shared:WaitForChild("StreakRules"))
local SocialConfig = require(Shared:WaitForChild("Config"):WaitForChild("SocialConfig"))
local StreakConfig = require(Shared:WaitForChild("Config"):WaitForChild("StreakConfig"))

local BadgeService = require(script.Parent.BadgeService)
local DataService = require(script.Parent.DataService)
local GroupRewardService = require(script.Parent.GroupRewardService)
local ProgressionService = require(script.Parent.ProgressionService)
local Telemetry = require(script.Parent:WaitForChild("TelemetryService"))
local VehicleService = require(script.Parent:WaitForChild("VehicleService"))

local StreakService = {}
StreakService.Priority = 90

local FLAG = "streak"

local stateRemote: RemoteEvent? = nil

local pushedDay: { [Player]: number } = {}

local function flagOf(data: any): any
	if type(data) ~= "table" or type(data.flags) ~= "table" then
		return nil
	end
	return data.flags[FLAG]
end

local function stateOf(data: any): Rules.State
	return Rules.fromFlagTable(flagOf(data))
end

local function viewOf(state: Rules.State, now: number): { [string]: any }
	local view: { [string]: any } = {
		day = Rules.dayIndex(now),
		streak = state.streak,
		secondsToDay = Rules.secondsToDay(now),
		available = Rules.available(state, now),
	}
	if view.available then
		view.preview = Rules.preview(state, now)
	end
	return view
end

local function push(player: Player, state: Rules.State)
	local remote = stateRemote
	if remote and player.Parent then
		remote:FireClient(player, viewOf(state, os.time()))
		pushedDay[player] = Rules.dayIndex(os.time())
	end
end

local function refresh(player: Player)
	local data = DataService.Get(player)
	if data then
		push(player, stateOf(data))
	end
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

-- Claim today's crate. The client has already seen its own local crate; the server only checks
-- that the player is at their crate and that today is still unclaimed.
local function open(player: Player): any
	local data = DataService.Get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not data or not root or not root:IsA("BasePart") then
		return nil
	end
	local bay = VehicleService.GetBay(player)
	local at = if bay then (bay.CFrame * BayLaunch.CRATE).Position else StreakConfig.PorchPosition
	local dx = root.Position.X - at.X
	local dz = root.Position.Z - at.Z
	if dx * dx + dz * dz > StreakConfig.OpenRange * StreakConfig.OpenRange then
		return nil
	end

	local claim = Rules.claim(stateOf(data), os.time())
	if not claim then
		return nil
	end
	local before = ProgressionService.GetData(player)
	if not before then
		return nil
	end
	if not ProgressionService.SetFlag(player, FLAG, Rules.flagTable(claim.state)) then
		return nil
	end
	player:SetAttribute("StreakClaim", claim.day)
	Telemetry.Custom(
		player,
		"DailyCrate",
		claim.streak,
		if claim.welcome then "Welcome" else "Daily",
		tostring(claim.day)
	)
	Telemetry.Funnel(player, "FirstDailyCrate")
	local reason = if claim.welcome then "Streak:Welcome" else `Streak:Day{claim.streak}`
	ProgressionService.Award(player, claim.cash, 0, reason, true)
	-- Group members get a flat +10% on the crate (G68); never multiplied, never a second crate.
	local groupBonus = 0
	local groupState = GroupRewardService.State(player)
	if groupState then
		groupBonus = GroupReward.bonus(
			groupState,
			claim.cash,
			SocialConfig.BonusPercent,
			SocialConfig.GroupId
		)
		if groupBonus > 0 then
			ProgressionService.Award(player, groupBonus, 0, "Group:Crew", true)
		end
	end
	local after = ProgressionService.GetData(player)
	local cashAfter = if after then after.cash else before.cash + claim.cash + groupBonus

	push(player, claim.state)
	if claim.streak >= 7 then
		BadgeService.Count(player, "Streak7")
	end
	if claim.streak >= 30 then
		BadgeService.Count(player, "Streak30")
	end
	return {
		ok = true,
		cash = cashAfter - before.cash,
		cashAfter = cashAfter,
		streak = claim.streak,
		welcome = claim.welcome,
		calm = claim.calm,
		cosmetic = claim.cosmeticDay ~= nil,
	}
end

-- Studio only: last claim was yesterday and the next crate is `tier` (1..7). Used by the
-- smoke/test snippet to see the day-7 weekly crate without waiting a week.
function StreakService.DevSet(player: Player, tier: number)
	local data = DataService.Get(player)
	if not data then
		return false
	end
	local wanted = math.clamp(math.floor(tier), 1, StreakConfig.WeekDays)
	local state: Rules.State = {
		lastDay = Rules.dayIndex(os.time()) - 1,
		streak = wanted - 1,
		cosmeticDay = 0,
	}
	if not ProgressionService.SetFlag(player, FLAG, Rules.flagTable(state)) then
		return false
	end
	push(player, Rules.fromFlagTable(Rules.flagTable(state)))
	return true
end

function StreakService.Init()
	local folder = Net.init()

	stateRemote = ensureRemoteEvent(folder, "Streak_State")
	local get = ensureRemoteFunction(folder, "Streak_Get")
	local openFn = ensureRemoteFunction(folder, "Streak_Open")

	get.OnServerInvoke = function(player: Player)
		local data = DataService.Get(player)
		return if data then viewOf(stateOf(data), os.time()) else nil
	end
	openFn.OnServerInvoke = open

	if RunService:IsStudio() then
		-- Studio dev hook for play tests: ServerStorage.StreakDev:Invoke("day", 7) sets today's
		-- crate to that streak day; ("break", 5) fakes a 5-day break (welcome-back crate);
		-- ("view") returns the pushed view.
		local dev = Instance.new("BindableFunction")
		dev.Name = "StreakDev"
		dev.OnInvoke = function(cmd: string, arg: any): any
			local player = Players:GetPlayers()[1]
			if not player then
				return nil
			end
			if cmd == "day" then
				return StreakService.DevSet(player, tonumber(arg) or 1)
			end
			if cmd == "break" then
				local data = DataService.Get(player)
				local days = math.max(4, math.floor(tonumber(arg) or 5))
				local state: Rules.State = {
					lastDay = Rules.dayIndex(os.time()) - days,
					streak = 3,
					cosmeticDay = 0,
				}
				if
					not data or not ProgressionService.SetFlag(player, FLAG, Rules.flagTable(state))
				then
					return false
				end
				push(player, Rules.fromFlagTable(Rules.flagTable(state)))
				return true
			end
			local data = DataService.Get(player)
			return if data then viewOf(stateOf(data), os.time()) else nil
		end
		dev.Parent = game:GetService("ServerStorage")
	end

	DataService.OnLoaded(function(player: Player, data: any)
		push(player, stateOf(data))
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		pushedDay[player] = nil
	end)
end

function StreakService.Start()
	-- Players who stay in the server across 00:00 UTC get the new crate appear.
	task.spawn(function()
		while true do
			task.wait(30)
			local today = Rules.dayIndex(os.time())
			for _, player in Players:GetPlayers() do
				if pushedDay[player] ~= today then
					refresh(player)
				end
			end
		end
	end)
end

return StreakService
