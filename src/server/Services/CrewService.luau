--!strict
-- CrewService: MVP crew joining (docs 02 section 7, up to 4 players) and the crew roles that come
-- from what each player does (docs 09 section 4.1, G30). There is no role wheel or role menu.
--
-- Joining: walk up to another player's multi-seat boat and press "Join crew" (a ProximityPrompt
-- on the hull, which also seats you in a free passenger seat), or fire CrewJoin with
-- { targetUserId = number } (e.g. the radio panel). CrewLeave (no payload) leaves.
-- The server echoes changes: CrewJoin:FireClient(member, { leader = userId, members = { userId } })
-- and CrewLeave:FireClient(player) when a player is no longer in a crew.
--
-- Roles (src/shared/CrewRoles.luau is the pure rule set):
--   Helm       sits in a boat's DriverSeat (a crewmate may take it while the boat is at rest)
--   Navigator  stands at the boat's chart table (CrewChart), or holds the search tablet
--   Crew       is in the water, or wears the drysuit from the kit locker (icon: Swimmer)
--   Medic      carries the med bag (no boat hands one out since 2026-10-22: no medical props;
--              survivors are dragged aboard. The MedBag tool code stays for the role rules.)
-- Taking a seat or tool takes the role; another crewmate taking the tool hands it over. Each
-- operating crew boat carries a code-built CrewChart (tablet) and CrewLocker (drysuit) with
-- proximity prompts. Player attribute CrewRole = the icon role ("" none).
--
-- API (server):
--   CrewService.GetCrew(player) -> { Player }   everyone in the player's crew, the player included
--                                                (just { player } when solo)
--   CrewService.GetRoles(player) -> { string }  the crew roles the player is doing right now,
--                                                in step order; solo keeps the old implicit roles
--   CrewService.IsCrewmate(owner, player) -> boolean
--   CrewService.RecordRoleAction(player, callId) / CrewService.HasRoleAction(player, callId)
--     Role actions (pull aboard, tow, drive, spot) are recorded by the services that see them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrewRoles = require(Shared:WaitForChild("CrewRoles"))
local Net = require(Shared:WaitForChild("Net"))
local ProgressionConfig = require(Shared:WaitForChild("Config"):WaitForChild("ProgressionConfig"))
local VehicleConfig = require(Shared:WaitForChild("Config"):WaitForChild("VehicleConfig"))

local BadgeService = require(script.Parent:WaitForChild("BadgeService"))
local FriendService = require(script.Parent:WaitForChild("FriendService"))

local CrewService = {}
CrewService.Priority = 40

local ROLE_ACTION_TTL = 30 * 60 -- forget role actions on calls older than this
local ROLE_TICK = 0.5 -- s between role sweeps (seat, chart, water, tools)
local CHART_RADIUS = 6 -- studs from the chart table
local TOOL_REACH = 14 -- studs the kit prompts work from
local JOIN_COOLDOWN = 5 -- s between joins, per player (server-side, prompts and remotes alike)
local REJOIN_COOLDOWN = 30 -- s before rejoining a crew you just left
-- Deck height above the DriverSeat centre (the greybox and the art RIB share the seat frame).
local SEAT_TO_DECK: { [string]: number } = { RIB = 2.23, Lifeboat = 1.55 }
local DEFAULT_SEAT_TO_DECK = 2.0
local DECK_COLOUR = Color3.fromRGB(58, 66, 72)
local KIT_COLOUR = Color3.fromRGB(52, 122, 74)
local LOCKER_COLOUR = Color3.fromRGB(74, 82, 88)
local SUIT_COLOUR = Color3.fromRGB(236, 196, 46)
local TABLET_COLOUR = Color3.fromRGB(28, 32, 36)
local SCREEN_COLOUR = Color3.fromRGB(142, 196, 208)

type RoleState = {
	id: number,
	helm: boolean?,
	chart: boolean?,
	water: boolean?,
	tablet: boolean?,
	drysuit: boolean?,
	medbag: boolean?,
}

-- Where the role props sit in hull space (root origin, deck level). The two boats we have; any
-- other multi-seat craft gets the fallback.
type PropSpot = { chart: Vector3, kit: Vector3, locker: Vector3 }
local PROP_SPOTS: { [string]: PropSpot } = {
	RIB = {
		chart = Vector3.new(2.0, 0, -1.0), -- chart table along the console
		kit = Vector3.new(2.35, 0, 6.5), -- kit box between the crew seats
		locker = Vector3.new(-2.35, 0, 6.5),
	},
	Lifeboat = {
		chart = Vector3.new(3.8, 0, -3.0), -- chart table in the wheelhouse
		kit = Vector3.new(5.2, 0, 6.0),
		locker = Vector3.new(-5.2, 0, 6.0),
	},
}
local FALLBACK_SPOT: PropSpot = {
	chart = Vector3.new(1.8, 0, -1.0),
	kit = Vector3.new(1.8, 0, 5.0),
	locker = Vector3.new(-1.8, 0, 5.0),
}

-- leader -> members (leader first)
local crews: { [Player]: { Player } } = {}
local leaderOf: { [Player]: Player } = {}
local roleActions: { [Player]: { [any]: number } } = {}
local lastJoin: { [Player]: number } = {}
local leftAt: { [Player]: { [Player]: number } } = {}
local vehicleService: any = nil

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

-- True for the boat owner and anyone in that owner's crew (the boat's own crew, not a stranger).
function CrewService.IsCrewmate(owner: Player, player: Player): boolean
	if owner == player then
		return true
	end
	local leader = leaderOf[owner] or owner
	return leaderOf[player] == leader
end

---------------------------------------------------------------- roles from actions

local function vehicleServiceModule(): any
	if vehicleService == nil then
		local module = script.Parent:FindFirstChild("VehicleService")
		if module and module:IsA("ModuleScript") then
			local ok, result = pcall(require, module)
			vehicleService = if ok then result else false
		else
			vehicleService = false
		end
	end
	return if vehicleService ~= false then vehicleService else nil
end

local function boatOf(player: Player): Model?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if seat then
		local model = seat:FindFirstAncestorOfClass("Model")
		local vehicleId = model and model:GetAttribute("VehicleId")
		if model and type(vehicleId) == "string" and VehicleConfig.get(vehicleId) then
			return model
		end
	end
	local service = vehicleServiceModule()
	if service and type(service.GetVehicle) == "function" then
		local ok, model = pcall(service.GetVehicle, player)
		if ok and typeof(model) == "Instance" and model:IsA("Model") then
			return model
		end
	end
	return nil
end

local function seatIsHelm(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if not seat or seat.Name ~= "DriverSeat" then
		return false
	end
	local model = seat:FindFirstAncestorOfClass("Model")
	local vehicleId = model and model:GetAttribute("VehicleId")
	return type(vehicleId) == "string" and VehicleConfig.get(vehicleId) ~= nil
end

local function flatDistance(a: Vector3, b: Vector3): number
	return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

-- Standing at a chart table on a boat whose owner is in the same crew.
local function atChart(player: Player): boolean
	local root = player.Character and player.Character.PrimaryPart
	if not root then
		return false
	end
	local folder = Workspace:FindFirstChild("Vehicles")
	if not folder then
		return false
	end
	local position = root.Position
	for _, model in folder:GetChildren() do
		if model:IsA("Model") then
			local chart = model:FindFirstChild("CrewChart")
			if
				chart
				and chart:IsA("BasePart")
				and flatDistance(position, chart.Position) <= CHART_RADIUS
			then
				local ownerId = tonumber(model:GetAttribute("Owner"))
				local owner = if ownerId then Players:GetPlayerByUserId(ownerId) else nil
				if owner and CrewService.IsCrewmate(owner, player) then
					return true
				end
			end
		end
	end
	return false
end

local function toolState(player: Player): { drysuit: boolean, tablet: boolean, medbag: boolean }
	local out = { drysuit = false, tablet = false, medbag = false }
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	local function scan(container: Instance?, equipped: boolean)
		if not container then
			return
		end
		for _, tool in container:GetChildren() do
			if tool:IsA("Tool") then
				local kind = tool:GetAttribute("CrewTool")
				if kind == "MedBag" then
					out.medbag = true
				elseif kind == "Tablet" and equipped then
					out.tablet = true
				elseif kind == "Drysuit" and equipped then
					out.drysuit = true
				end
			end
		end
	end
	scan(character, true)
	scan(backpack, false)
	return out
end

local function inWater(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid:GetState() == Enum.HumanoidStateType.Swimming
end

local function roleState(player: Player): RoleState
	local tools = toolState(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seated = humanoid ~= nil and humanoid.SeatPart ~= nil
	return {
		id = player.UserId,
		helm = seatIsHelm(player),
		chart = not seated and atChart(player),
		water = inWater(player),
		tablet = tools.tablet,
		drysuit = tools.drysuit,
		medbag = tools.medbag,
	}
end

-- Solo keeps the old implicit roles exactly: the jet ski rider is everyone, any other boat's solo
-- helm also works the radio (OperationService's old roleOf solo branch).
local function soloRoles(player: Player): { string }
	local boat = boatOf(player)
	if boat and VehicleConfig.isJetSki(boat:GetAttribute("VehicleId")) then
		return CrewRoles.implicit() :: any
	end
	return { "Helm", "Navigator" }
end

function CrewService.GetRoles(player: Player): { string }
	local crew = CrewService.GetCrew(player)
	if #crew <= 1 then
		return soloRoles(player)
	end
	local states: { any } = {}
	for _, member in crew do
		table.insert(states, roleState(member))
	end
	local roles: { [number]: { string } } = CrewRoles.resolve(states) :: any
	return roles[player.UserId] or {}
end

-- The icon role: the action the player is doing, never the solo implicit set (a solo player on
-- foot shows no icon until they take a seat or a tool).
local function displayRole(player: Player): string?
	local crew = CrewService.GetCrew(player)
	if #crew <= 1 then
		return CrewRoles.primary(CrewRoles.of(roleState(player)))
	end
	local ok, roles = pcall(CrewService.GetRoles, player)
	if not ok then
		return nil
	end
	return CrewRoles.primary(roles :: any)
end

local function refreshPlayer(player: Player)
	local primary = displayRole(player)
	local current = player:GetAttribute("CrewRole")
	if current ~= primary then
		player:SetAttribute("CrewRole", if primary then primary else nil)
	end
end

function CrewService.RefreshRoles()
	for _, player in Players:GetPlayers() do
		refreshPlayer(player)
	end
end

---------------------------------------------------------------- kit tools

local function weld(handle: BasePart, part: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	local joint = Instance.new("WeldConstraint")
	joint.Part0 = handle
	joint.Part1 = part
	joint.Parent = part
end

local function toolPart(tool: Tool, name: string, size: Vector3, colour: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = colour
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = tool
	return part
end

local function buildTool(kind: string): Tool
	local tool = Instance.new("Tool")
	tool.Name = if kind == "MedBag"
		then "Med bag"
		elseif kind == "Tablet" then "Search tablet"
		else "Drysuit"
	tool.RequiresHandle = true
	tool.CanBeDropped = false -- handover is taking it from the kit, not dropping it
	tool:SetAttribute("CrewTool", kind)
	local handle = toolPart(
		tool,
		"Handle",
		if kind == "Tablet"
			then Vector3.new(0.55, 0.08, 0.85)
			elseif kind == "Drysuit" then Vector3.new(0.65, 0.4, 0.5)
			else Vector3.new(0.65, 0.5, 0.85),
		Color3.fromRGB(255, 255, 255)
	)
	if kind == "MedBag" then
		handle.Color = KIT_COLOUR
		local bar = toolPart(tool, "CrossLong", Vector3.new(0.12, 0.04, 0.42), Color3.new(1, 1, 1))
		bar.CFrame = handle.CFrame * CFrame.new(0, 0.25, 0)
		weld(handle, bar)
		local short =
			toolPart(tool, "CrossShort", Vector3.new(0.36, 0.04, 0.12), Color3.new(1, 1, 1))
		short.CFrame = bar.CFrame
		weld(handle, short)
	elseif kind == "Tablet" then
		handle.Color = TABLET_COLOUR
		local screen = toolPart(tool, "Screen", Vector3.new(0.46, 0.03, 0.72), SCREEN_COLOUR)
		screen.CFrame = handle.CFrame * CFrame.new(0, 0.05, 0)
		weld(handle, screen)
	else
		handle.Color = SUIT_COLOUR
		handle.Material = Enum.Material.Fabric
		local band = toolPart(tool, "Band", Vector3.new(0.7, 0.1, 0.52), Color3.fromRGB(40, 44, 48))
		band.CFrame = handle.CFrame * CFrame.new(0, 0.0, 0)
		weld(handle, band)
	end
	tool.Grip = CFrame.new(0, -0.2, 0)
	return tool
end

local function stripKind(player: Player, kind: string)
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	local containers: { Instance? } = { character, backpack }
	for _, container in containers do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("CrewTool") == kind then
					child:Destroy()
				end
			end
		end
	end
end

local function giveTool(player: Player, kind: string, owner: Player)
	-- handover is inside the crew: another crew's kit is their own
	for _, other in CrewService.GetCrew(owner) do
		stripKind(other, kind)
	end
	local tool = buildTool(kind)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	tool.Parent = backpack or character
	if humanoid and humanoid.Parent then
		task.defer(function()
			if tool.Parent and humanoid.Parent then
				pcall(humanoid.EquipTool, humanoid, tool)
			end
		end)
	end
	refreshPlayer(player)
end

---------------------------------------------------------------- crew boat props

local function addProp(
	model: Model,
	name: string,
	size: Vector3,
	offset: Vector3,
	colour: Color3,
	deck: number
): BasePart?
	local root = model.PrimaryPart
	if not root then
		return nil
	end
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = colour
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	part.Massless = true
	part.CFrame = root.CFrame * CFrame.new(offset.X, deck + size.Y * 0.5, offset.Z)
	part.Parent = model
	local joint = Instance.new("WeldConstraint")
	joint.Part0 = root
	joint.Part1 = part
	joint.Parent = part
	return part
end

local function addToolPrompt(part: BasePart, objectText: string, kind: string, owner: Player)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = `Crew{kind}Prompt`
	prompt.ActionText = "Take"
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = TOOL_REACH
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("CrewOwner", owner.UserId)
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		if not CrewService.IsCrewmate(owner, player) then
			return
		end
		giveTool(player, kind, owner)
	end)
end

local function addCrewProps(owner: Player, model: Model)
	local vehicleId = model:GetAttribute("VehicleId")
	local spec = if type(vehicleId) == "string" then VehicleConfig.get(vehicleId) else nil
	if not spec or spec.seats <= 1 then
		return -- the jet ski is a one-person craft: solo already holds every role
	end
	if model:FindFirstChild("CrewChart") then
		return
	end
	local root = model.PrimaryPart
	if not root then
		return
	end
	local spot = PROP_SPOTS[vehicleId :: string] or FALLBACK_SPOT
	local seat = model:FindFirstChild("DriverSeat")
	local seatY = if seat and seat:IsA("BasePart")
		then root.CFrame:PointToObjectSpace(seat.Position).Y
		else 0
	local deck = seatY - (SEAT_TO_DECK[vehicleId :: string] or DEFAULT_SEAT_TO_DECK)
	local chart =
		addProp(model, "CrewChart", Vector3.new(1.1, 0.9, 1.7), spot.chart, DECK_COLOUR, deck)
	local locker =
		addProp(model, "CrewLocker", Vector3.new(1.2, 2.1, 0.95), spot.locker, LOCKER_COLOUR, deck)
	if chart then
		local board = addProp(
			model,
			"CrewChartBoard",
			Vector3.new(1.0, 0.12, 0.8),
			spot.chart + Vector3.new(0, 0.55, 0),
			Color3.fromRGB(226, 220, 200),
			deck
		)
		if board then
			board.CFrame = chart.CFrame * CFrame.new(0, 0.5, 0) * CFrame.Angles(math.rad(-18), 0, 0)
		end
		addToolPrompt(chart, "Tablet", "Tablet", owner)
	end
	if locker then
		local stripe = addProp(
			model,
			"CrewLockerStripe",
			Vector3.new(1.24, 0.22, 0.98),
			spot.locker + Vector3.new(0, 1.55, 0),
			SUIT_COLOUR,
			deck
		)
		if stripe then
			stripe.CFrame = locker.CFrame * CFrame.new(0, 0.75, 0)
		end
		addToolPrompt(locker, "Drysuit", "Drysuit", owner)
	end
end

---------------------------------------------------------------- joining

function CrewService.Leave(player: Player)
	local leader = leaderOf[player]
	if not leader then
		return
	end
	local left = leftAt[player]
	if not left then
		left = {}
		leftAt[player] = left
	end
	left[leader] = os.clock()
	local members = crews[leader]
	leaderOf[player] = nil
	stripKind(player, "Drysuit")
	stripKind(player, "MedBag")
	stripKind(player, "Tablet")
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
			stripKind(member, "Drysuit")
			stripKind(member, "MedBag")
			stripKind(member, "Tablet")
			if member.Parent then
				Net.event("CrewLeave"):FireClient(member)
			end
		end
		crews[leader] = nil
		task.defer(CrewService.RefreshRoles)
		return
	end
	broadcast(leader)
	task.defer(CrewService.RefreshRoles)
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
	local at = os.clock()
	local joined = lastJoin[player]
	if joined and at - joined < JOIN_COOLDOWN then
		return false, "Too fast"
	end
	local left = leftAt[player]
	if left and left[leader] and at - left[leader] < REJOIN_COOLDOWN then
		return false, "Wait before rejoining"
	end
	local members = crews[leader] or { leader }
	if #members >= ProgressionConfig.MaxCrew then
		return false, "Crew is full"
	end
	CrewService.Leave(player)
	lastJoin[player] = at
	crews[leader] = members
	leaderOf[leader] = leader
	table.insert(members, player)
	leaderOf[player] = leader
	broadcast(leader)
	task.defer(CrewService.RefreshRoles)
	if FriendService.AreFriends(player, target) then
		BadgeService.Count(player, "FriendCrew")
		BadgeService.Count(target, "FriendCrew")
	end
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
	Players.PlayerAdded:Connect(function(player)
		refreshPlayer(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		CrewService.Leave(player)
		roleActions[player] = nil
		leaderOf[player] = nil
		lastJoin[player] = nil
		leftAt[player] = nil
		for _, left in leftAt do
			left[player] = nil
		end
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
					addCrewProps(owner, model)
					task.defer(CrewService.RefreshRoles)
				end)
			end)
		end
	end
	task.spawn(function()
		while true do
			CrewService.RefreshRoles()
			task.wait(ROLE_TICK)
		end
	end)
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
