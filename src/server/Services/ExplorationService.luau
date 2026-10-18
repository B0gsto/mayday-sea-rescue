--!strict
-- ExplorationService: the exploration logbook and the On watch / Off duty switch (docs 10 section 5,
-- docs 03 section 8.1). Rules in Shared.Explore.Discovery.
--
--   detection  1 Hz: each player's root against every unfound entry (Discovery.reached). "In the
--              water" = not seated and the root below the sea surface (y < IN_WATER_Y).
--   rewards    one time, Cash only (no Reputation): ProgressionService.Award(player, cash, 0, ...)
--   saving     the found set in profile flags logbook1..n, Off duty in flag "offDuty"
--   duty       player attribute OffDuty (bool). OperationService skips standard taskings for an
--              off-duty player once the tutorial chain is done (docs 10 section 5.1).
--
-- Remotes (created here under ReplicatedStorage.Net):
--   Explore_State   RemoteFunction C->S () -> { found = { [id]: true }, offDuty = bool }
--   Explore_Found   RemoteEvent S->C ({ id, cash, pages = { pageId } })
--   Explore_SetDuty RemoteEvent C->S (offDuty: boolean)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DataService = require(script.Parent.DataService)
local Discovery = require(Shared:WaitForChild("Explore"):WaitForChild("Discovery"))
local ProgressionService = require(script.Parent.ProgressionService)

local ExplorationService = {}
ExplorationService.Priority = 150

local TICK = 1 -- s
local IN_WATER_Y = -0.8 -- root below this (sea level 0) and not seated = in the sea -- tune

local found: { [Player]: { [string]: boolean } } = {}
local foundRemote: RemoteEvent
local discovered = Instance.new("BindableEvent")

-- (player, entryId, award) after a discovery is logged and paid.
ExplorationService.Discovered = discovered.Event

local function save(player: Player)
	local set = found[player]
	if not set then
		return
	end
	local data = ProgressionService.GetData(player)
	local chunks = Discovery.encode(set)
	-- clear chunks that shrank away (never happens in play; keeps the flags tidy after a reset)
	if data and type(data.flags) == "table" then
		for name in data.flags do
			if
				type(name) == "string"
				and string.sub(name, 1, #Discovery.FLAG_PREFIX) == Discovery.FLAG_PREFIX
				and not chunks[name]
			then
				ProgressionService.SetFlag(player, name, nil)
			end
		end
	end
	for name, chunk in chunks do
		if not ProgressionService.SetFlag(player, name, chunk) then
			warn(`[ExplorationService] could not save {name} for {player.Name}`)
		end
	end
end

local function load(player: Player)
	local data = ProgressionService.GetData(player)
	if not data then
		return
	end
	found[player] = Discovery.decode(data.flags)
	player:SetAttribute(
		"OffDuty",
		type(data.flags) == "table" and data.flags[Discovery.DUTY_FLAG] == true
	)
end

function ExplorationService.GetFound(player: Player): { [string]: boolean }
	return table.clone(found[player] or {})
end

function ExplorationService.IsOffDuty(player: Player): boolean
	return player:GetAttribute("OffDuty") == true
end

function ExplorationService.SetOffDuty(player: Player, offDuty: boolean)
	player:SetAttribute("OffDuty", offDuty)
	ProgressionService.SetFlag(player, Discovery.DUTY_FLAG, if offDuty then true else nil)
end

-- Logs an entry (also for later systems: photo mode, binoculars). Returns true if it was new.
function ExplorationService.Log(player: Player, id: string): boolean
	local set = found[player]
	if not set then
		return false
	end
	local award = Discovery.log(set, id)
	if not award then
		return false
	end
	local entry = Discovery.get(id)
	local pages: { string } = {}
	for _, p in award.pages do
		table.insert(pages, p.id)
	end
	save(player)
	ProgressionService.Award(player, award.cash, 0, `Logbook: {if entry then entry.name else id}`)
	foundRemote:FireClient(player, { id = id, cash = award.cash, pages = pages })
	discovered:Fire(player, id, award)
	return true
end

local function check(player: Player)
	local set = found[player]
	local character = player.Character
	if not set or not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	local pos = root.Position
	local seated = humanoid.SeatPart ~= nil
	local ctx = { seated = seated, inWater = not seated and pos.Y < IN_WATER_Y }
	for _, e in Discovery.Entries do
		if not set[e.id] and Discovery.reached(e, pos, ctx) then
			ExplorationService.Log(player, e.id)
		end
	end
end

local function makeRemote(className: string, name: string): Instance
	local net = ReplicatedStorage:WaitForChild("Net")
	local r = net:FindFirstChild(name)
	if not r then
		local made = Instance.new(className)
		made.Name = name
		made.Parent = net
		return made
	end
	return r
end

function ExplorationService.Init()
	foundRemote = makeRemote("RemoteEvent", "Explore_Found") :: RemoteEvent
	local state = makeRemote("RemoteFunction", "Explore_State") :: RemoteFunction
	local duty = makeRemote("RemoteEvent", "Explore_SetDuty") :: RemoteEvent

	state.OnServerInvoke = function(player: Player)
		if not found[player] then
			load(player)
		end
		return {
			found = table.clone(found[player] or {}),
			offDuty = ExplorationService.IsOffDuty(player),
		}
	end
	duty.OnServerEvent:Connect(function(player: Player, offDuty: any)
		if type(offDuty) == "boolean" and found[player] then
			ExplorationService.SetOffDuty(player, offDuty)
		end
	end)

	DataService.OnLoaded(function(player: Player)
		load(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		found[player] = nil
	end)
end

function ExplorationService.Start()
	for _, player in Players:GetPlayers() do
		if not found[player] and DataService.Get(player) then
			load(player)
		end
	end
	while true do
		task.wait(TICK)
		for _, player in Players:GetPlayers() do
			xpcall(check, function(err)
				warn(`[ExplorationService] {player.Name}: {err}`)
			end, player)
		end
	end
end

return ExplorationService
