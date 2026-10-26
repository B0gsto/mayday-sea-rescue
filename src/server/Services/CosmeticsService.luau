--!strict
-- CosmeticsService (RP-M5 spine): equipped cosmetics for every player, checked against the game
-- passes they own (src/shared/Cosmetics, slot data in src/shared/Config/Cosmetics/*).
--
-- * Profile field `cosmetics = { [slot] = id }` (ProgressionRules) holds what the player chose. The
--   effective choice is Cosmetics.sanitize(saved, owns) and is mirrored as player attributes
--   "Cos_<Slot>" = id for every slot (clients and server modules read these). It is re-applied on
--   join (once the passes are checked) and whenever MonetizationService.OnPassOwned fires.
-- * Remotes (created here under ReplicatedStorage.Net):
--     Cosmetics_Equip   RemoteFunction C->S (slot, id) -> (ok: boolean, reason: string)
--     Cosmetics_Action  RemoteEvent    C->S (name, ...)   rate limited, dispatched to OnAction
--     Cosmetics_Event   RemoteEvent    S->C (name, ...)   Broadcast / FireNear / FireClient
-- * Feature modules: every ModuleScript in src/server/Cosmetics/ (ServerScriptService.Server
--   .Cosmetics) is required here; `Init(service)` runs in this service's Init (sorted by optional
--   `Priority`, then name), `Start()` in its own thread in this service's Start. Add files there
--   without touching Main.
--
-- API (server):
--   CosmeticsService.Equipped(player, slot): string        the effective option id
--   CosmeticsService.Owns(player, key): boolean            a game pass, or an earned flag key
--   CosmeticsService.Refresh(player)                       re-sanitise (earned flags changed)
--   player attribute "CosOwned"                            newline list of earned flag keys
--   CosmeticsService.Equip(player, slot, id): (boolean, string)   same checks as the remote
--   CosmeticsService.Changed: signal (player, slot, id)    an effective choice changed
--   CosmeticsService.OnAction(name, handler(player, ...))  one handler per action name
--   CosmeticsService.Broadcast(name, ...)                  every client
--   CosmeticsService.FireNear(position, radius, name, ...) clients whose character is in range
--   CosmeticsService.FireClient(player, name, ...)
--   CosmeticsService.VehicleOf(player): (Model?, kind?)    kind "Boat" | "JetSki"; the vehicle
--       the player is seated in, else the one they own (VehicleService)
--   CosmeticsService.KindOf(model): string?                "Boat" | "JetSki" | nil
--   CosmeticsService.VehicleSpawned: signal (player, model, kind) boats and jet skis
--   CosmeticsService.Cosmetics                             the shared registry
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CosmeticLoadout = require(Shared:WaitForChild("CosmeticLoadout"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local MonetizationService = require(script.Parent:WaitForChild("MonetizationService"))
local Net = require(Shared:WaitForChild("Net"))
local VehicleConfig = require(Shared:WaitForChild("Config"):WaitForChild("VehicleConfig"))

local CosmeticsService = {}
CosmeticsService.Priority = 40 -- after DataService (20) and MonetizationService (30)
CosmeticsService.Cosmetics = Cosmetics

local ACTION_RATE = 6 -- tokens per second
local ACTION_BURST = 10
local EQUIP_RATE = 4
local EQUIP_BURST = 8
local MAX_NAME = 40
local PASS_WAIT = 15

local changedEvent = Instance.new("BindableEvent")
CosmeticsService.Changed = changedEvent.Event
local spawnedEvent = Instance.new("BindableEvent")
CosmeticsService.VehicleSpawned = spawnedEvent.Event

local eventRemote: RemoteEvent? = nil
local actionHandlers: { [string]: (Player, ...any) -> () } = {}
local buckets: { [Player]: { [string]: { tokens: number, at: number } } } = {}
local features: { { name: string, module: any, priority: number } } = {}

local function log(message: string)
	warn(`[CosmeticsService] {message}`)
end

-- token bucket per player and channel; true = allowed
local function allow(player: Player, channel: string, rate: number, burst: number): boolean
	local mine = buckets[player]
	if not mine then
		mine = {}
		buckets[player] = mine
	end
	local now = os.clock()
	local b = mine[channel]
	if not b then
		b = { tokens = burst, at = now }
		mine[channel] = b
	end
	b.tokens = math.min(burst, b.tokens + (now - b.at) * rate)
	b.at = now
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end

local function earnedOf(player: Player): { [string]: boolean }
	local data = DataService.Get(player) :: any
	return if data then CosmeticLoadout.owned(data.flags, data.totalRescues) else {}
end

local function ownsFor(player: Player): Cosmetics.Owns
	local earned = earnedOf(player)
	return function(key: string): boolean
		return MonetizationService.OwnsPass(player, key) or earned[key] == true
	end
end

function CosmeticsService.Owns(player: Player, key: string): boolean
	return MonetizationService.OwnsPass(player, key) or earnedOf(player)[key] == true
end

function CosmeticsService.Equipped(player: Player, slot: string): string
	local v = player:GetAttribute(Cosmetics.attribute(slot))
	if type(v) == "string" then
		return v
	end
	return Cosmetics.default(slot) or ""
end

local function savedOf(player: Player): { [string]: string }?
	local data = DataService.Get(player) :: any
	if not data then
		return nil
	end
	if type(data.cosmetics) ~= "table" then
		data.cosmetics = {}
	end
	return data.cosmetics
end

-- Recompute the effective choices and mirror them to attributes; fires Changed for each change.
local function apply(player: Player)
	if not player.Parent then
		return
	end
	local earned = earnedOf(player)
	local owns: Cosmetics.Owns = function(key: string): boolean
		return MonetizationService.OwnsPass(player, key) or earned[key] == true
	end
	local encoded = CosmeticLoadout.encode(earned)
	if player:GetAttribute("CosOwned") ~= encoded then
		player:SetAttribute("CosOwned", encoded)
	end
	local effective = Cosmetics.sanitize(savedOf(player) or {}, owns)
	for slot, id in effective do
		local attr = Cosmetics.attribute(slot)
		if player:GetAttribute(attr) ~= id then
			player:SetAttribute(attr, id)
			changedEvent:Fire(player, slot, id)
		end
	end
end

--- Re-sanitise after earned flags changed (the Earned feature calls this).
function CosmeticsService.Refresh(player: Player)
	apply(player)
end

function CosmeticsService.Equip(player: Player, slot: any, id: any): (boolean, string)
	if type(slot) ~= "string" or type(id) ~= "string" or #slot > MAX_NAME or #id > MAX_NAME then
		return false, "Bad request"
	end
	if not Cosmetics.slot(slot) then
		return false, "Unknown slot"
	end
	if not Cosmetics.option(slot, id) then
		return false, "Unknown item"
	end
	if not Cosmetics.canEquip(slot, id, ownsFor(player)) then
		return false, "Not owned"
	end
	local saved = savedOf(player)
	if not saved then
		return false, "Profile not loaded"
	end
	(saved :: any)[slot] = if id == Cosmetics.default(slot) then nil else id
	DataService.MarkDirty(player)
	apply(player)
	return true, "ok"
end

---------------------------------------------------------------- action / event channels

function CosmeticsService.OnAction(name: string, handler: (Player, ...any) -> ())
	assert(type(name) == "string" and #name <= MAX_NAME, "OnAction: bad name")
	if actionHandlers[name] then
		log(`action {name} registered twice; the later handler wins`)
	end
	actionHandlers[name] = handler
end

function CosmeticsService.FireClient(player: Player, name: string, ...: any)
	if eventRemote and player.Parent then
		eventRemote:FireClient(player, name, ...)
	end
end

function CosmeticsService.FireNear(position: Vector3, radius: number, name: string, ...: any)
	local remote = eventRemote
	if not remote then
		return
	end
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and (root.Position - position).Magnitude <= radius then
			remote:FireClient(player, name, ...)
		end
	end
end

local function onAction(player: Player, name: any, ...: any)
	if type(name) ~= "string" or #name > MAX_NAME then
		return
	end
	local handler = actionHandlers[name]
	if not handler or not allow(player, "action", ACTION_RATE, ACTION_BURST) then
		return
	end
	local args = table.pack(...)
	task.spawn(function()
		xpcall(handler, function(err: any)
			log(`action {name} failed: {err}`)
		end, player, table.unpack(args, 1, args.n))
	end)
end

---------------------------------------------------------------- vehicles

local function sibling(name: string): any
	local m = script.Parent:FindFirstChild(name)
	if not m then
		return nil
	end
	local ok, result = pcall(require, m)
	return if ok then result else nil
end

function CosmeticsService.KindOf(model: Instance?): string?
	if not model or not model:IsA("Model") then
		return nil
	end
	local id = model:GetAttribute("VehicleId")
	if VehicleConfig.isJetSki(id) then
		return "JetSki"
	elseif type(id) == "string" then
		return "Boat"
	end
	return nil
end

-- the vehicle Model above a seat part (the nearest ancestor with a VehicleId)
local function vehicleAbove(part: Instance?): Model?
	local node = part
	while node and node ~= workspace do
		if node:IsA("Model") and node:GetAttribute("VehicleId") ~= nil then
			return node
		end
		node = node.Parent
	end
	return nil
end

function CosmeticsService.VehicleOf(player: Player): (Model?, string?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seated = vehicleAbove(humanoid and humanoid.SeatPart)
	if seated then
		return seated, CosmeticsService.KindOf(seated)
	end
	for _, name in { "VehicleService" } do
		local service = sibling(name)
		if service and service.GetVehicle then
			local ok, model = pcall(service.GetVehicle, player)
			if ok and model and model.Parent then
				return model, CosmeticsService.KindOf(model)
			end
		end
	end
	return nil, nil
end

local function hookVehicleSignals()
	for _, name in { "VehicleService" } do
		local service = sibling(name)
		local signal = service and service.VehicleSpawned
		if signal then
			signal:Connect(function(player: Player, model: Model)
				spawnedEvent:Fire(player, model, CosmeticsService.KindOf(model))
			end)
		else
			log(
				`{name}.VehicleSpawned missing; CosmeticsService.VehicleSpawned will not fire for it`
			)
		end
	end
end

---------------------------------------------------------------- feature modules

local function loadFeatures()
	local folder = script.Parent.Parent:FindFirstChild("Cosmetics")
	if not folder then
		return
	end
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			local ok, module = pcall(require, child)
			if ok and type(module) == "table" then
				table.insert(features, {
					name = child.Name,
					module = module,
					priority = (module :: any).Priority or 100,
				})
			else
				log(`feature {child.Name} failed to load: {module}`)
			end
		end
	end
	table.sort(features, function(a, b)
		if a.priority ~= b.priority then
			return a.priority < b.priority
		end
		return a.name < b.name
	end)
end

local function runFeature(phase: string, name: string, fn: (...any) -> (), ...: any)
	xpcall(fn, function(err: any)
		log(`{name}.{phase} failed: {err}\n{debug.traceback()}`)
	end, ...)
end

---------------------------------------------------------------- lifecycle

local function getOrCreate(netFolder: Instance, name: string, className: string): Instance
	local existing = netFolder:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = netFolder
	return created
end

function CosmeticsService.Init()
	for _, problem in Cosmetics.validate() do
		log(`config: {problem}`)
	end
	local netFolder = Net.init()
	local equip = getOrCreate(netFolder, "Cosmetics_Equip", "RemoteFunction") :: RemoteFunction
	equip.OnServerInvoke = function(player: Player, slot: any, id: any)
		if not allow(player, "equip", EQUIP_RATE, EQUIP_BURST) then
			return false, "Too fast"
		end
		return CosmeticsService.Equip(player, slot, id)
	end
	local action = getOrCreate(netFolder, "Cosmetics_Action", "RemoteEvent") :: RemoteEvent
	action.OnServerEvent:Connect(onAction)
	eventRemote = getOrCreate(netFolder, "Cosmetics_Event", "RemoteEvent") :: RemoteEvent

	for _, pass in Cosmetics.passes() do
		xpcall(
			MonetizationService.OnPassOwned,
			function(err: any)
				log(`pass {pass}: {err}`)
			end,
			pass,
			function(player: Player)
				apply(player)
			end
		)
	end

	loadFeatures()
	for _, f in features do
		if f.module.Init then
			runFeature("Init", f.name, f.module.Init, CosmeticsService)
		end
	end
end

function CosmeticsService.Start()
	hookVehicleSignals()
	DataService.OnLoaded(function(player: Player)
		apply(player) -- defaults (and free choices) at once
		MonetizationService.WaitForPasses(player, PASS_WAIT)
		apply(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		buckets[player] = nil
	end)
	for _, f in features do
		if f.module.Start then
			task.spawn(runFeature, "Start", f.name, f.module.Start)
		end
	end
end

return CosmeticsService
