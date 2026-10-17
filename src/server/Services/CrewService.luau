--!strict
-- CrewService: MVP crew joining (docs 02 section 7: no roles yet, up to 4 players).
--
-- Joining: walk up to another player's multi-seat boat and press "Join crew" (a ProximityPrompt
-- on the hull, which also seats you in a free passenger seat), or fire CrewJoin with
-- { targetUserId = number } (e.g. a future radio panel). CrewLeave (no payload) leaves.
-- The server echoes changes: CrewJoin:FireClient(member, { leader = userId, members = { userId } })
-- and CrewLeave:FireClient(player) when a player is no longer in a crew.
--
-- API (server):
--   CrewService.GetCrew(player) -> { Player }   everyone in the player's crew, the player included
--                                                (just { player } when solo)
--   CrewService.RecordRoleAction(player, callId) / CrewService.HasRoleAction(player, callId)
--     Role actions (pull aboard, tow, drive, spot) are recorded by the services that see them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local ProgressionConfig = require(Shared:WaitForChild("Config"):WaitForChild("ProgressionConfig"))
local VehicleConfig = require(Shared:WaitForChild("Config"):WaitForChild("VehicleConfig"))

local CrewService = {}
CrewService.Priority = 40

local ROLE_ACTION_TTL = 30 * 60 -- forget role actions on calls older than this

-- leader -> members (leader first)
local crews: { [Player]: { Player } } = {}
local leaderOf: { [Player]: Player } = {}
local roleActions: { [Player]: { [any]: number } } = {}

local function rankAllowsCrew(player: Player): boolean
	if RunService:IsStudio() then
		return true -- solo/2-player Studio tests start at Recruit
	end
	local rankIndex = player:GetAttribute("RankIndex")
	return type(rankIndex) == "number" and rankIndex >= ProgressionConfig.CrewJoinRankIndex
end

local function broadcast(leader: Player)
	local members = crews[leader]
	if not members then
		return
	end
	local ids = {}
	for _, member in members do
		table.insert(ids, member.UserId)
	end
	local payload = { leader = leader.UserId, members = ids }
	for _, member in members do
		Net.event("CrewJoin"):FireClient(member, payload)
	end
end

function CrewService.GetCrew(player: Player): { Player }
	local leader = leaderOf[player]
	if leader and crews[leader] then
		return table.clone(crews[leader])
	end
	return { player }
end

function CrewService.Leave(player: Player)
	local leader = leaderOf[player]
	if not leader then
		return
	end
	local members = crews[leader]
	leaderOf[player] = nil
	if player.Parent then
		Net.event("CrewLeave"):FireClient(player)
	end
	if not members then
		return
	end
	local index = table.find(members, player)
	if index then
		table.remove(members, index)
	end
	if player == leader or #members <= 1 then
		-- the owner left, or nobody is left to crew with: disband
		for _, member in members do
			leaderOf[member] = nil
			if member.Parent then
				Net.event("CrewLeave"):FireClient(member)
			end
		end
		crews[leader] = nil
		return
	end
	broadcast(leader)
end

-- ok, reason. Joins target's crew (target becomes leader if they are solo).
function CrewService.Join(player: Player, target: Player): (boolean, string)
	if player == target or not target.Parent then
		return false, "No target"
	end
	if not rankAllowsCrew(player) then
		local rank = ProgressionConfig.Ranks[ProgressionConfig.CrewJoinRankIndex]
		return false, `Crew joining opens at {rank.displayName}`
	end
	local leader = leaderOf[target] or target
	if leaderOf[player] == leader then
		return true, "Already in crew"
	end
	local members = crews[leader] or { leader }
	if #members >= ProgressionConfig.MaxCrew then
		return false, "Crew is full"
	end
	CrewService.Leave(player)
	crews[leader] = members
	leaderOf[leader] = leader
	table.insert(members, player)
	leaderOf[player] = leader
	broadcast(leader)
	return true, "ok"
end

function CrewService.RecordRoleAction(player: Player, callId: any)
	if callId == nil then
		return
	end
	local actions = roleActions[player]
	if not actions then
		actions = {}
		roleActions[player] = actions
	end
	assert(actions, "unreachable")
	actions[callId] = os.clock()
end

function CrewService.HasRoleAction(player: Player, callId: any): boolean
	local actions = roleActions[player]
	return actions ~= nil and callId ~= nil and actions[callId] ~= nil
end

local function seatPassenger(player: Player, model: Model)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.SeatPart then
		return
	end
	for _, d in model:GetDescendants() do
		if d:IsA("Seat") and not d.Occupant and not d.Disabled then
			d:Sit(humanoid)
			return
		end
	end
end

local function addJoinPrompt(owner: Player, model: Model)
	local vehicleId = model:GetAttribute("VehicleId")
	local spec = if type(vehicleId) == "string" then VehicleConfig.get(vehicleId) else nil
	if not spec or spec.seats <= 1 then
		return -- the jet ski has no passenger seat
	end
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not root or root:FindFirstChild("CrewJoinPrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CrewJoinPrompt"
	prompt.ActionText = "Join crew"
	prompt.ObjectText = `{owner.DisplayName}'s {spec.displayName}`
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("CrewOwner", owner.UserId) -- the HUD hides it for the owner
	prompt.Parent = root
	prompt.Triggered:Connect(function(player)
		if player == owner then
			return
		end
		local ok = CrewService.Join(player, owner)
		if ok then
			seatPassenger(player, model)
		end
	end)
end

function CrewService.Init()
	Net.event("CrewJoin").OnServerEvent:Connect(function(player, payload: any)
		if type(payload) ~= "table" or type(payload.targetUserId) ~= "number" then
			return
		end
		local target = Players:GetPlayerByUserId(payload.targetUserId)
		if target then
			CrewService.Join(player, target)
		end
	end)
	Net.event("CrewLeave").OnServerEvent:Connect(function(player)
		CrewService.Leave(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		CrewService.Leave(player)
		roleActions[player] = nil
	end)
end

function CrewService.Start()
	-- VehicleService (stream B) is optional at boot.
	local module = script.Parent:FindFirstChild("VehicleService")
	if module and module:IsA("ModuleScript") then
		local ok, VehicleService = pcall(require, module)
		local spawned = ok and type(VehicleService) == "table" and VehicleService.VehicleSpawned
		if spawned then
			-- CONTRACT: VehicleService.VehicleSpawned (player, model)
			pcall(function()
				spawned:Connect(function(owner: Player, model: Model)
					addJoinPrompt(owner, model)
				end)
			end)
		end
	end
	while true do
		task.wait(60)
		local cutoff = os.clock() - ROLE_ACTION_TTL
		for _, actions in roleActions do
			for callId, at in actions do
				if at < cutoff then
					actions[callId] = nil
				end
			end
		end
	end
end

return CrewService
