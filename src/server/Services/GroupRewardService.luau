--!strict
-- GroupRewardService: the Roblox group ("Crew") reward (docs/15 H1/H9, G68). GroupId = 0 in
-- Shared/Config/SocialConfig turns it all off. Members get the Crew bay pennant (flags.group.c,
-- read by CosmeticLoadout -> BayDecor) and a flat +10% on the daily streak crate (StreakService
-- asks IsMember). The membership check runs on join, pcall-guarded so a failed group read never
-- breaks a session. Player attribute GroupCrew (bool) mirrors current membership.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GroupReward = require(Shared:WaitForChild("GroupReward"))
local SocialConfig = require(Shared:WaitForChild("Config"):WaitForChild("SocialConfig"))

local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)

local GroupRewardService = {}
GroupRewardService.Priority = 86

local FLAG = "group"

local lastCheck: { [Player]: number } = {}

local function stateOf(player: Player): GroupReward.State?
	local data = DataService.Get(player)
	if not data or type(data.flags) ~= "table" then
		return nil
	end
	return GroupReward.decode(data.flags[FLAG])
end

local function readGroup(player: Player): boolean?
	if not GroupReward.enabled(SocialConfig.GroupId) then
		return false
	end
	local ok, result = pcall(function()
		return player:IsInGroupAsync(SocialConfig.GroupId)
	end)
	if ok and type(result) == "boolean" then
		return result
	end
	return nil
end

local function apply(player: Player, isInGroup: boolean): GroupReward.State?
	local state = stateOf(player)
	if not state then
		return nil
	end
	local nextState = GroupReward.update(state, isInGroup, SocialConfig.GroupId)
	if
		nextState.crew ~= state.crew
		or nextState.member ~= state.member
		or nextState.groupId ~= state.groupId
	then
		ProgressionService.SetFlag(player, FLAG, GroupReward.encode(nextState))
	end
	player:SetAttribute("GroupCrew", GroupReward.isMember(nextState, SocialConfig.GroupId))
	return nextState
end

-- Cached check. force bypasses the throttle (profile load only).
local function check(player: Player, force: boolean): GroupReward.State?
	local state = stateOf(player)
	if not state then
		return nil
	end
	if not GroupReward.enabled(SocialConfig.GroupId) then
		return apply(player, false)
	end
	local now = os.clock()
	local last = lastCheck[player]
	if not force and last and now - last < SocialConfig.CheckCooldown then
		return state
	end
	lastCheck[player] = now
	local inGroup = readGroup(player)
	if inGroup == nil then
		return state
	end
	return apply(player, inGroup)
end

function GroupRewardService.State(player: Player): GroupReward.State?
	return stateOf(player)
end

function GroupRewardService.Init()
	DataService.OnLoaded(function(player: Player)
		task.spawn(function()
			local state = check(player, true)
			if state then
				player:SetAttribute("GroupCrew", GroupReward.isMember(state, SocialConfig.GroupId))
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastCheck[player] = nil
	end)
end

function GroupRewardService.Start() end

return GroupRewardService
