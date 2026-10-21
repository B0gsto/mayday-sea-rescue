--!strict
-- FriendService: friends in the server and the crew-up flare (docs/15 H9).
--
-- Friends: Player:IsFriendsWith is cached on join and refreshed on PlayerAdded / PlayerRemoving.
-- Each player carries `FriendCount` and `FriendBonus` (percent) attributes; ProgressionService.Award
-- multiplies Cash by FriendBonus.multiplier(FriendService.Count(player)) (cap +30%).
-- Friends in the server and joining mid-session spawn at the station's QuaySpawn instead of a
-- random neutral spawn, and respawn there.
--
-- Flare: a player on an active operation fires Friend_Flare (hold the flare glyph, client). Friends
-- in the server and crewmates receive Friend_FlareSeen { from, name, opId, position, color, seconds }
-- and see a flare rise over the operation. A "Crew up" ProximityPrompt at the operation position
-- (60 studs) runs the normal CrewService.Join path for anyone who comes alongside.
--
-- Remotes (own RemoteEvents under ReplicatedStorage.Net; Net.luau is shared):
--   Friend_Flare      C->S  (no payload)
--   Friend_FlareSeen  S->C  the flare payload above
-- Studio: Workspace attribute FriendCountForce (number) overrides every player's count.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FriendBonus = require(Shared:WaitForChild("FriendBonus"))
local Net = require(Shared:WaitForChild("Net"))

local Telemetry = require(script.Parent:WaitForChild("TelemetryService"))

local FriendService = {}
FriendService.Priority = 45

local FLARE_SECONDS = 45
local FLARE_RANGE = 60
local FLARE_COOLDOWN = 10 -- s between flares from one player
local FLARE_COLORS = {
	Color3.fromRGB(255, 120, 40),
	Color3.fromRGB(80, 200, 255),
	Color3.fromRGB(255, 210, 70),
	Color3.fromRGB(120, 255, 140),
}

local friendIds: { [Player]: { [number]: boolean } } = {}
local lastFlare: { [Player]: number } = {}
local livePrompt: { [Player]: { part: Part, prompt: ProximityPrompt, serial: number } } = {}

local flareSeen: RemoteEvent? = nil

local function sibling(name: string): any?
	local module = script.Parent:FindFirstChild(name)
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		return if ok then result else nil
	end
	return nil
end

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

local function stationSpawn(): SpawnLocation?
	local found = Workspace:FindFirstChild("QuaySpawn", true)
	return if found and found:IsA("SpawnLocation") then found else nil
end

-- Joining mid-session with a friend already here: at the station, not a random spawn.
local function spawnAtStation(player: Player)
	local spawn = stationSpawn()
	if not spawn then
		return
	end
	player.RespawnLocation = spawn
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.CFrame = spawn.CFrame * CFrame.new(0, 3, 0)
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
	if FriendService.Count(player) > 0 and #Players:GetPlayers() > 1 then
		spawnAtStation(player)
	end
end

local function clearPrompt(player: Player)
	local live = livePrompt[player]
	if not live then
		return
	end
	livePrompt[player] = nil
	live.prompt:Destroy()
	live.part:Destroy()
end

local function raisePrompt(player: Player, position: Vector3)
	clearPrompt(player)
	local part = Instance.new("Part")
	part.Name = `FriendFlare_{player.UserId}`
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(8, 1, 8)
	part.Position = position
	part.Parent = Workspace
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CrewUpPrompt"
	prompt.ActionText = "Crew up"
	prompt.ObjectText = player.DisplayName
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = FLARE_RANGE
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(function(other: Player)
		local crew = sibling("CrewService")
		if crew and type(crew.Join) == "function" then
			crew.Join(other, player)
		end
	end)
	local serial = (if livePrompt[player] then livePrompt[player].serial else 0) + 1
	livePrompt[player] = { part = part, prompt = prompt, serial = serial }
	task.delay(FLARE_SECONDS, function()
		local live = livePrompt[player]
		if live and live.serial == serial then
			clearPrompt(player)
		end
	end)
end

local function flareColor(player: Player): Color3
	return FLARE_COLORS[(player.UserId % #FLARE_COLORS) + 1]
end

local function onFlare(player: Player)
	local now = os.clock()
	if now - (lastFlare[player] or -math.huge) < FLARE_COOLDOWN then
		return
	end
	lastFlare[player] = now
	local ops = sibling("OperationService")
	local op = if ops and type(ops.GetOperationOf) == "function"
		then ops.GetOperationOf(player)
		else nil
	if not op or not op.position then
		return
	end
	Telemetry.Custom(player, "CrewFlare")
	local color = flareColor(player)
	local payload = {
		from = player.UserId,
		name = player.DisplayName,
		opId = op.id,
		position = op.position,
		color = { color.R, color.G, color.B },
		seconds = FLARE_SECONDS,
	}
	local sent: { [Player]: boolean } = { [player] = true }
	local crew = sibling("CrewService")
	local mates = if crew and type(crew.GetCrew) == "function" then crew.GetCrew(player) else nil
	if type(mates) == "table" then
		for _, mate in mates do
			if typeof(mate) == "Instance" and mate:IsA("Player") and not sent[mate] then
				sent[mate] = true
				if flareSeen then
					flareSeen:FireClient(mate, payload)
				end
			end
		end
	end
	for _, other in Players:GetPlayers() do
		if not sent[other] and friendIds[player] and friendIds[player][other.UserId] then
			sent[other] = true
			if flareSeen then
				flareSeen:FireClient(other, payload)
			end
		end
	end
	raisePrompt(player, op.position)
end

local function ensureRemote(name: string): RemoteEvent
	local folder = Net.init()
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local created = Instance.new("RemoteEvent")
	created.Name = name
	created.Parent = folder
	return created
end

function FriendService.Init()
	flareSeen = ensureRemote("Friend_FlareSeen")
	ensureRemote("Friend_Flare").OnServerEvent:Connect(onFlare)
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
		lastFlare[player] = nil
		clearPrompt(player)
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
