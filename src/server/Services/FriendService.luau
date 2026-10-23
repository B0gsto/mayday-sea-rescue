--!strict
-- FriendService: friends in the server (docs/15 H9).
--
-- Friends: Player:IsFriendsWith is cached on join and refreshed on PlayerAdded / PlayerRemoving.
-- Each player carries `FriendCount` and `FriendBonus` (percent) attributes; ProgressionService.Award
-- multiplies Cash by FriendBonus.multiplier(FriendService.Count(player)) (cap +30%).
-- Spawning is VehicleService's (a returning player spawns at their bay).
-- Studio: Workspace attribute FriendCountForce (number) overrides every player's count.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FriendBonus = require(Shared:WaitForChild("FriendBonus"))

local FriendService = {}
FriendService.Priority = 45

local friendIds: { [Player]: { [number]: boolean } } = {}

local function forcedCount(): number?
	local value = Workspace:GetAttribute("FriendCountForce")
	return if typeof(value) == "number" and RunService:IsStudio()
		then math.max(0, math.floor(value))
		else nil
end

-- Friends in this server right now (the dev override wins in Studio).
function FriendService.Count(player: Player): number
	local forced = forcedCount()
	if forced then
		return forced
	end
	local set = friendIds[player]
	local count = 0
	if set then
		for id in set do
			if Players:GetPlayerByUserId(id) then
				count += 1
			end
		end
	end
	return count
end

-- Cached friendship (CrewService uses it for the crew-up badge).
function FriendService.AreFriends(a: Player, b: Player): boolean
	local set = friendIds[a]
	return set ~= nil and set[b.UserId] == true
end

local function publish(player: Player)
	if not player.Parent then
		return
	end
	local count = FriendService.Count(player)
	player:SetAttribute("FriendCount", count)
	player:SetAttribute("FriendBonus", FriendBonus.percent(count))
end

local function publishAll()
	for _, player in Players:GetPlayers() do
		publish(player)
	end
end

local function remember(a: Player, b: Player, friends: boolean)
	if a == b or not friends then
		return
	end
	local sa = friendIds[a] or {}
	friendIds[a] = sa
	sa[b.UserId] = true
	local sb = friendIds[b] or {}
	friendIds[b] = sb
	sb[a.UserId] = true
end

local function resolveFriends(player: Player)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local ok, friends = pcall(function()
				return player:IsFriendsWithAsync(other.UserId)
			end)
			if ok then
				remember(player, other, friends == true)
			end
		end
	end
	if not player.Parent then
		return
	end
	publishAll()
end

function FriendService.Init()
	Players.PlayerAdded:Connect(function(player: Player)
		friendIds[player] = friendIds[player] or {}
		publish(player)
		task.spawn(resolveFriends, player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		friendIds[player] = nil
		for _, set in friendIds do
			set[player.UserId] = nil
		end
		publishAll()
	end)
	Workspace:GetAttributeChangedSignal("FriendCountForce"):Connect(publishAll)
	for _, player in Players:GetPlayers() do
		friendIds[player] = friendIds[player] or {}
		publish(player)
		task.spawn(resolveFriends, player)
	end
end

return FriendService
