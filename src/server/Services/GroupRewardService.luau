--!strict
-- GroupRewardService: the Roblox group ("Crew") reward (docs/15 H1/H9, G68). GroupId = 0 in
-- Shared/Config/SocialConfig turns it all off. Members get the Crew bay pennant (flags.group.c,
-- read by CosmeticLoadout -> BayDecor) and a flat +10% on the daily streak crate (StreakService
-- asks IsMember). The membership check is cached on join and re-run when the player walks up to
-- the harbour noticeboard; everything is pcall-guarded so a failed group read never breaks a
-- session.
--
-- Remotes (under ReplicatedStorage.Net):
--   Group_Check  C->S function -> { enabled, member, crew } (rechecks only near the board, 15 s)
-- Player attribute GroupCrew (bool) mirrors current membership for the noticeboard sign.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GroupReward = require(Shared:WaitForChild("GroupReward"))
local Net = require(Shared:WaitForChild("Net"))
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

function GroupRewardService.IsMember(player: Player): boolean
	local state = stateOf(player)
	return state ~= nil and GroupReward.isMember(state, SocialConfig.GroupId)
end

function GroupRewardService.State(player: Player): GroupReward.State?
	return stateOf(player)
end

local function view(state: GroupReward.State?): { [string]: any }
	return {
		enabled = GroupReward.enabled(SocialConfig.GroupId),
		member = state ~= nil and GroupReward.isMember(state, SocialConfig.GroupId),
		crew = state ~= nil and GroupReward.earned(state),
	}
end

local function nearBoard(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	local here = SocialConfig.NoticeboardPosition
	local dx = root.Position.X - here.X
	local dz = root.Position.Z - here.Z
	return dx * dx + dz * dz <= SocialConfig.CheckRange * SocialConfig.CheckRange
end

function GroupRewardService.Init()
	local folder = Net.init()
	local name = "Group_Check"
	local found = folder:FindFirstChild(name)
	local remote: RemoteFunction
	if found and found:IsA("RemoteFunction") then
		remote = found
	else
		remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
	end
	remote.OnServerInvoke = function(player: Player)
		if nearBoard(player) then
			return view(check(player, false))
		end
		return view(stateOf(player))
	end

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
