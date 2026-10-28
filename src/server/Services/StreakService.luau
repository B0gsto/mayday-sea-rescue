--!strict
-- StreakService: the daily streak reward and the welcome-back bonus (docs/15 section 1, hook H5).
-- One reward per UTC day per player, shown by the client's join reward prompt (RewardController) and
-- granted here only when they press Collect. StreakRules owns the day maths and the forgiveness;
-- StreakConfig owns the payouts. Cash goes through ProgressionService.Award and the streak lives on the
-- profile (data.flags.streak). Not collected (left first): today stays available on the next join.
-- Remotes (under ReplicatedStorage.Net):
--   Streak_State    S->C  { day, streak, available, secondsToDay, preview? } (preview.bonus: the group +10%)
--   Streak_Get      C->S  function -> the same view (first pull)
--   Streak_Collect  C->S  function -> { ok, cash, cashAfter, streak, welcome, cosmetic } or nil
-- Studio: ServerStorage.StreakDev (BindableFunction) sets today's reward to a streak day.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GroupReward = require(Shared:WaitForChild("GroupReward"))
local Net = require(Shared:WaitForChild("Net"))
local Rules = require(Shared:WaitForChild("StreakRules"))
local SkillRules = require(Shared:WaitForChild("SkillRules"))
local SocialConfig = require(Shared:WaitForChild("Config"):WaitForChild("SocialConfig"))
local StreakConfig = require(Shared:WaitForChild("Config"):WaitForChild("StreakConfig"))

local BadgeService = require(script.Parent.BadgeService)
local DataService = require(script.Parent.DataService)
local GroupRewardService = require(script.Parent.GroupRewardService)
local ProgressionService = require(script.Parent.ProgressionService)
local SkillService = require(script.Parent.SkillService)
local Telemetry = require(script.Parent:WaitForChild("TelemetryService"))

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

-- The group members' flat +10% on the reward (G68); never multiplied, never a second reward.
local function groupBonus(player: Player, cash: number): number
	local groupState = GroupRewardService.State(player)
	if not groupState then
		return 0
	end
	return GroupReward.bonus(groupState, cash, SocialConfig.BonusPercent, SocialConfig.GroupId)
end

local function viewOf(player: Player, state: Rules.State, now: number): { [string]: any }
	local view: { [string]: any } = {
		day = Rules.dayIndex(now),
		streak = state.streak,
		secondsToDay = Rules.secondsToDay(now),
		available = Rules.available(state, now),
	}
	if view.available then
		local preview: any = Rules.preview(state, now)
		if preview then
			preview.bonus = groupBonus(player, preview.cash)
		end
		view.preview = preview
	end
	return view
end

local function push(player: Player, state: Rules.State)
	local remote = stateRemote
	if remote and player.Parent then
		remote:FireClient(player, viewOf(player, state, os.time()))
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

-- Collect today's reward (the prompt's Collect button). Rules.claim refuses a second claim the same day.
local function collect(player: Player): any
	local data = DataService.Get(player)
	if not data then
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
	local reason = if claim.welcome then "Streak:Welcome" else `Streak:Day{claim.streak}`
	ProgressionService.Award(player, claim.cash, reason, true)
	SkillService.grantMedals(player, SkillRules.chestMedals(claim.streak), "DailyChest")
	local bonus = groupBonus(player, claim.cash)
	if bonus > 0 then
		ProgressionService.Award(player, bonus, "Group:Crew", true)
	end
	local after = ProgressionService.GetData(player)
	local cashAfter = if after then after.cash else before.cash + claim.cash + bonus

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

-- Studio only: last claim was yesterday and the next reward is `tier` (1..7). Used by the
-- smoke/test snippet to see the day-7 weekly reward without waiting a week.
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
	local collectFn = ensureRemoteFunction(folder, "Streak_Collect")

	get.OnServerInvoke = function(player: Player)
		local data = DataService.Get(player)
		return if data then viewOf(player, stateOf(data), os.time()) else nil
	end
	collectFn.OnServerInvoke = collect

	if RunService:IsStudio() then
		-- Studio dev hook for play tests: ServerStorage.StreakDev:Invoke("day", 7) sets today's
		-- reward to that streak day; ("break", 5) fakes a 5-day break (welcome-back bonus);
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
			return if data then viewOf(player, stateOf(data), os.time()) else nil
		end
		dev.Parent = game:GetService("ServerStorage")
	end

	DataService.OnLoaded(function(player: Player, data: any)
		push(player, stateOf(data))
	end)
	Players.PlayerAdded:Connect(function(player: Player)
		-- the group check lands after the first push: re-send the view with its +10% (the prompt shows it)
		player:GetAttributeChangedSignal("GroupCrew"):Connect(function()
			refresh(player)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		pushedDay[player] = nil
	end)
end

function StreakService.Start()
	-- Players who stay in the server across 00:00 UTC get the new day's reward prompt.
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
