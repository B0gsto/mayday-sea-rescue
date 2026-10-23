--!strict
-- SanctuaryService: the wildlife half of the animal sanctuary (docs/15 section 2, hook H4).
--
-- WildlifeRescue operations reuse the Person in the Water scene (a swimmer casualty), so this
-- service dresses the victim as the species the call rolled: the human rig is hidden and a chunky
-- Part animal (WildlifeRig) rides the same floater, so it climbs aboard like any survivor (auto_board,
-- docs/16 K16). The animal follows the victim's root every frame; its net / oil / line drops once it
-- is aboard, and it rides home on the craft and climbs off at the drop-off.
--
-- When the operation finishes with a good grade, each rescuer gets the animal in their own
-- sanctuary (PetService.AddRescue), where it recovers for 10 real minutes and can then be adopted.
-- No edits to RescueService or OperationService beyond one DressOffer hook.
--
-- Studio: ServerStorage.SanctuaryDev (BindableFunction)
--   "force" <speciesId> [rare]  the next wildlife call is that animal (screenshots / checks)
--   "add" <speciesId> [rare]    put that animal in the first player's sanctuary
--   "ready"                     make every animal in the sanctuary ready to adopt now
--   "equip" <id>                adopt one
--   "view"                      the sanctuary view
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetRules = require(Shared:WaitForChild("PetRules"))
local Wildlife = require(Shared:WaitForChild("Config"):WaitForChild("Wildlife"))
local WildlifeRig = require(Shared:WaitForChild("WildlifeRig"))

local BadgeService = require(script.Parent.BadgeService)
local OperationService = require(script.Parent.OperationService)
local PetService = require(script.Parent.PetService)

local SanctuaryService = {}
SanctuaryService.Priority = 64

local GOOD_GRADES = { Gold = true, Silver = true, Bronze = true }
local POLL_SECONDS = 0.5
local TRACK_LIFETIME = 600 -- s: forget an offer that never became an operation

type Tracked = {
	species: string,
	rare: boolean,
	at: number,
	offered: { [Player]: boolean },
	players: { [Player]: boolean },
	credited: { [Player]: boolean },
	dressed: boolean,
}

type Live = {
	animal: Model,
	root: BasePart,
	connection: RBXScriptConnection?,
}

local tracked: { [string]: Tracked } = {}
local live: { [string]: Live } = {}

local function newTracked(species: string, rare: boolean): Tracked
	return {
		species = species,
		rare = rare,
		at = os.clock(),
		offered = {},
		players = {},
		credited = {},
		dressed = false,
	}
end

-- OperationService calls this once per offer, before the card is shown, so the radio line names
-- the animal. It is also the earliest point where the operation's animal is fixed.
function SanctuaryService.DressOffer(op: any, player: Player?)
	if type(op) ~= "table" or op.kind ~= "WildlifeRescue" then
		return
	end
	local species, rare = PetRules.roll(tostring(op.id))
	local force = Workspace:GetAttribute("WildlifeForce")
	if type(force) == "string" and Wildlife.Species[force] and RunService:IsStudio() then
		species = force
		rare = Workspace:GetAttribute("WildlifeForceRare") == true
	end
	local t = tracked[op.id]
	if not t then
		t = newTracked(species, rare)
		tracked[op.id] = t
	else
		t.species, t.rare = species, rare
	end
	if player then
		t.offered[player] = true
	end
	op.radioLine = Wildlife.callLine(species, rare)
	op.wildlifeSpecies = species
	op.wildlifeRare = rare
	-- the variant is the animal actually dressed, not a second roll
	op.variant = if rare then `Wildlife_{species}_Rare` else `Wildlife_{species}`
	if type(op.scene) == "table" then
		op.scene.wildlifeSpecies = species
		op.scene.wildlifeRare = rare
		op.scene.variant = op.variant
	end
end

local function hideHuman(model: Model, animal: Model)
	local function hide(part: Instance)
		if part:IsA("BasePart") and not part:IsDescendantOf(animal) then
			part.Transparency = 1
			part.CanQuery = false
			part.CanCollide = false
		end
	end
	for _, descendant in model:GetDescendants() do
		hide(descendant)
	end
	-- an R15 rig can arrive a beat after the greybox; hide it too
	return model.DescendantAdded:Connect(hide)
end

local function findVictim(opId: string): Model?
	local folder = Workspace:FindFirstChild("CallProps")
	if not folder then
		return nil
	end
	for _, child in folder:GetChildren() do
		if
			child:IsA("Model")
			and child.Name == "Victim"
			and child:GetAttribute("CallId") == opId
			and child.PrimaryPart
		then
			return child
		end
	end
	return nil
end

-- Dress the victim of an active wildlife operation as the animal. Returns true once placed.
local function dressScene(opId: string, t: Tracked): boolean
	if live[opId] then
		return true
	end
	local victim = findVictim(opId)
	if not victim then
		return false
	end
	local species = Wildlife.Species[t.species]
	if not species then
		return false
	end
	local root = victim.PrimaryPart
	if not root then
		return false
	end
	local animal = WildlifeRig.build(t.species, t.rare)
	if not animal then
		return false
	end
	animal.Name = "Wildlife"
	WildlifeRig.entangle(animal, species.verb)
	animal.Parent = victim
	victim:SetAttribute("Wildlife", t.species)
	victim:SetAttribute("WildlifeRare", t.rare)
	victim:SetAttribute("WildlifeVerb", species.verb)
	live[opId] = {
		animal = animal,
		root = root,
		connection = hideHuman(victim, animal),
	}
	return true
end

-- The animal follows the casualty's root (in the water or aboard); aboard, the net drops.
local function stepLive()
	for opId, l in live do
		if not l.animal.Parent or not l.root.Parent then
			if l.connection then
				l.connection:Disconnect()
			end
			if l.animal.Parent then
				l.animal:Destroy()
			end
			live[opId] = nil
		else
			WildlifeRig.setCFrame(l.animal, l.root.CFrame * CFrame.new(0, Wildlife.RescueLift, 0))
			local net = l.animal:FindFirstChild("Entanglement", true)
			if net and (l.root.Parent :: Instance):GetAttribute("OnVehicle") ~= nil then
				net:Destroy()
			end
		end
	end
end

local function pollOperations()
	local ok, infos = pcall(OperationService.GetActiveOperations)
	if not ok or type(infos) ~= "table" then
		return
	end
	local now = os.clock()
	for _, info in infos do
		if info.kind == "WildlifeRescue" then
			local t = tracked[info.id]
			if not t then
				local species, rare = PetRules.roll(tostring(info.id))
				t = newTracked(species, rare)
				tracked[info.id] = t
			end
			for _, player in info.assignedTo do
				t.players[player] = true
			end
			if not t.dressed then
				t.dressed = dressScene(info.id, t)
			end
		end
	end
	for id, t in tracked do
		if now - t.at > TRACK_LIFETIME then
			tracked[id] = nil
		end
	end
end

-- A wildlife operation ended for this player: credit the animal on a good grade.
local function onFinished(player: Player)
	local kind = player:GetAttribute("OpsLastKind")
	if kind ~= "WildlifeRescue" then
		return
	end
	local grade = player:GetAttribute("OpsLastGrade")
	local best: Tracked? = nil
	local bestAt = -math.huge
	for _, t in tracked do
		if
			not t.credited[player]
			and (t.players[player] or t.offered[player])
			and t.at > bestAt
		then
			best, bestAt = t, t.at
		end
	end
	if not best then
		return
	end
	best.credited[player] = true
	if not GOOD_GRADES[grade] then
		return
	end
	BadgeService.Count(player, "FirstWildlife")
	BadgeService.Once(player, "AllWildlife", best.species)
	PetService.AddRescue(player, best.species, best.rare)
end

local function watchPlayer(player: Player)
	player:GetAttributeChangedSignal("OpsLastKind"):Connect(function()
		onFinished(player)
	end)
end

local function dev(cmd: string, a: any, b: any): any
	if cmd == "force" then
		Workspace:SetAttribute("WildlifeForce", if type(a) == "string" then a else nil)
		Workspace:SetAttribute("WildlifeForceRare", b == true)
		return a
	end
	local player = Players:GetPlayers()[1]
	if not player then
		return nil
	end
	if cmd == "add" then
		local species = if type(a) == "string" and Wildlife.Species[a] then a else "SealPup"
		return PetService.AddRescue(player, species, b == true)
	elseif cmd == "ready" then
		return PetService.DevReady(player)
	elseif cmd == "equip" then
		return PetService.Equip(player, tonumber(a))
	elseif cmd == "view" then
		return PetService.GetView(player)
	end
	return nil
end

function SanctuaryService.Init()
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	if RunService:IsStudio() then
		local devButton = Instance.new("BindableFunction")
		devButton.Name = "SanctuaryDev"
		devButton.OnInvoke = dev
		devButton.Parent = ServerStorage
	end
end

function SanctuaryService.Start()
	local accum = 0
	RunService.Heartbeat:Connect(function(dt)
		stepLive()
		accum += dt
		if accum >= POLL_SECONDS then
			accum = 0
			pollOperations()
		end
	end)
end

return SanctuaryService
