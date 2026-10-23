--!strict
-- PetService: the per-player animal sanctuary (docs/15 section 2, hook H4).
--
-- The profile flag `pets` holds up to Wildlife.MaxPets animals, each with the species, whether it
-- is the rare colour variant and the Unix time it was landed (PetRules owns the encoding). They
-- recover for 10 real minutes even while the player is away; after that the client adopts one
-- (PetController: the first recovered one when no pet is out). One active pet at a time.
--
-- SanctuaryService calls AddRescue when a WildlifeRescue operation finishes. Remotes (under
-- ReplicatedStorage.Net; created here so shared/Net.luau needs no edit):
--   Pet_State  S->C  PetRules.view (pets, bond, treats, progress, remaining, active)
--   Pet_Get    C->S  function -> the same view (first pull)
--   Pet_Equip  C->S  function (id) -> (ok, reason); only when recovered
--   Pet_Treat  C->S  function (id) -> (ok, reason); feeds one fish treat to the pet with you
-- G48: one fish treat fills one bond pip; a full bond unlocks the code-built life vest. Treats
-- come from each daily crate (the StreakClaim attribute). Studio: ServerStorage.SanctuaryDev "add" / "ready" / "equip" / "view";
-- ServerStorage.PetDev "view" / "equip" / "treat" n.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local PetRules = require(Shared:WaitForChild("PetRules"))
local Wildlife = require(Shared:WaitForChild("Config"):WaitForChild("Wildlife"))

local BadgeService = require(script.Parent.BadgeService)
local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)
local Telemetry = require(script.Parent:WaitForChild("TelemetryService"))

local PetService = {}
PetService.Priority = 66

local FLAG = "pets"
local EQUIP_COOLDOWN = 0.5
local PUSH_SECONDS = 10

local stateRemote: RemoteEvent? = nil
local lastEquip: { [Player]: number } = {}
local lastTreat: { [Player]: number } = {}

local function ensureEvent(folder: Instance, name: string): RemoteEvent
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local created = Instance.new("RemoteEvent")
	created.Name = name
	created.Parent = folder
	return created
end

local function ensureFunction(folder: Instance, name: string): RemoteFunction
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteFunction") then
		return existing
	end
	local created = Instance.new("RemoteFunction")
	created.Name = name
	created.Parent = folder
	return created
end

local function flagOf(data: any): any
	if type(data) ~= "table" or type(data.flags) ~= "table" then
		return nil
	end
	return data.flags[FLAG]
end

local function stateOf(data: any): PetRules.State
	return PetRules.decode(flagOf(data))
end

local function viewOf(state: PetRules.State): any
	return PetRules.view(state, os.time())
end

local function push(player: Player, state: PetRules.State)
	local remote = stateRemote
	if remote and player.Parent then
		remote:FireClient(player, viewOf(state))
	end
end

local function store(player: Player, state: PetRules.State): boolean
	if not ProgressionService.SetFlag(player, FLAG, PetRules.encode(state)) then
		return false
	end
	push(player, state)
	return true
end

-- SanctuaryService: one rescued animal comes home.
function PetService.AddRescue(player: Player, speciesId: string, rare: boolean): PetRules.Entry?
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local state = stateOf(data)
	local nextState, entry = PetRules.add(state, speciesId, rare, os.time())
	if not entry then
		return nil
	end
	if not store(player, nextState) then
		return nil
	end
	return entry
end

function PetService.GetState(player: Player): PetRules.State?
	local data = DataService.Get(player)
	return if data then stateOf(data) else nil
end

function PetService.GetView(player: Player): any
	local data = DataService.Get(player)
	return if data then viewOf(stateOf(data)) else nil
end

-- G48: a fish treat (Chandlery shelf or a crate) lands in the same flag.
function PetService.AddTreats(player: Player, count: number): boolean
	local data = DataService.Get(player)
	if not data or count <= 0 then
		return false
	end
	local state = PetRules.addTreats(stateOf(data), count)
	return store(player, state)
end

function PetService.GiveTreat(player: Player, id: any): (boolean, string?)
	local data = DataService.Get(player)
	if not data then
		return false, "Profile not loaded"
	end
	local petId = tonumber(id)
	if not petId then
		return false, "Bad request"
	end
	local now = os.clock()
	if now - (lastTreat[player] or 0) < EQUIP_COOLDOWN then
		return false, "Too fast"
	end
	lastTreat[player] = now
	local nextState, ok, reason = PetRules.giveTreat(stateOf(data), petId)
	if not ok then
		return false, reason
	end
	if not store(player, nextState) then
		return false, "Could not save"
	end
	local pet = PetRules.get(nextState, petId)
	Telemetry.Custom(
		player,
		"PetTreated",
		1,
		if pet then pet.species else "?",
		tostring(if pet then pet.bond else 0)
	)
	return true
end

function PetService.Equip(player: Player, id: any): (boolean, string?)
	local data = DataService.Get(player)
	if not data then
		return false, "Profile not loaded"
	end
	local petId = tonumber(id)
	if not petId then
		return false, "Bad request"
	end
	local now = os.clock()
	if now - (lastEquip[player] or 0) < EQUIP_COOLDOWN then
		return false, "Too fast"
	end
	lastEquip[player] = now
	local state = stateOf(data)
	local ok, reason = PetRules.canEquip(state, petId, os.time())
	if not ok then
		return false, reason
	end
	local nextState, equipped = PetRules.equip(state, petId)
	if not equipped then
		return false, "Unknown pet"
	end
	if not store(player, nextState) then
		return false, "Could not save"
	end
	local pet = PetRules.get(nextState, petId)
	Telemetry.Custom(
		player,
		"PetAdopted",
		1,
		if pet then pet.species else "?",
		if pet and pet.rare then "Rare" else "Common"
	)
	BadgeService.Count(player, "FirstPet")
	return true
end

-- Studio: finish recovery now (screenshots / checks; also useful for the first play test).
function PetService.DevReady(player: Player): boolean
	local data = DataService.Get(player)
	if not data then
		return false
	end
	local state = stateOf(data)
	local entries = {}
	for _, entry in state.entries do
		table.insert(entries, {
			id = entry.id,
			species = entry.species,
			rare = entry.rare,
			at = os.time() - Wildlife.RecoverySeconds - 5,
			bond = entry.bond,
			adopted = entry.adopted,
		})
	end
	return store(player, {
		nextId = state.nextId,
		active = state.active,
		entries = entries,
		treats = state.treats,
	})
end

local function watchCrates(player: Player)
	player:GetAttributeChangedSignal("StreakClaim"):Connect(function()
		if player:GetAttribute("StreakClaim") ~= nil then
			PetService.AddTreats(player, 1) -- one fish treat per daily crate
		end
	end)
end

function PetService.Init()
	local folder = Net.init()

	stateRemote = ensureEvent(folder, "Pet_State")
	local get = ensureFunction(folder, "Pet_Get")
	local equip = ensureFunction(folder, "Pet_Equip")
	local treat = ensureFunction(folder, "Pet_Treat")

	get.OnServerInvoke = function(player: Player)
		return PetService.GetView(player)
	end
	equip.OnServerInvoke = function(player: Player, id: any)
		return PetService.Equip(player, id)
	end
	treat.OnServerInvoke = function(player: Player, id: any)
		return PetService.GiveTreat(player, id)
	end

	DataService.OnLoaded(function(player: Player, data: any)
		push(player, stateOf(data))
	end)
	for _, player in Players:GetPlayers() do
		watchCrates(player)
	end
	Players.PlayerAdded:Connect(watchCrates)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastEquip[player] = nil
		lastTreat[player] = nil
	end)

	if RunService:IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "PetDev"
		dev.OnInvoke = function(cmd: string, a: any, _b: any): any
			local player = Players:GetPlayers()[1]
			if not player then
				return nil
			end
			if cmd == "view" then
				return PetService.GetView(player)
			elseif cmd == "equip" then
				return PetService.Equip(player, a)
			elseif cmd == "treat" then
				return PetService.AddTreats(player, tonumber(a) or 1)
			end
			return nil
		end
		dev.Parent = ServerStorage
	end
end

function PetService.Start()
	task.spawn(function()
		while true do
			task.wait(PUSH_SECONDS)
			for _, player in Players:GetPlayers() do
				local data = DataService.Get(player)
				if not data then
					continue
				end
				local state = stateOf(data)
				for _, entry in state.entries do
					if not PetRules.ready(entry, os.time()) then
						push(player, state)
						break
					end
				end
			end
		end
	end)
end

return PetService
