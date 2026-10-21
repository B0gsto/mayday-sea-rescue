--!strict
-- WinterService: the "Frost Fleet" seasonal event (docs/15 hook H7), a sibling of HalloweenService
-- on the same shared rules (Config/SeasonalEvents + SeasonalRules). While the event is live (or
-- Workspace.SeasonalEventForce is true in Studio):
--   * every few minutes a server-wide Frost Fleet big call starts on the existing Capsized Ferry
--     flow (OperationService.ForceBigCall("FrostFleet")): lit boats iced in off the harbour mouth;
--   * every rescue pays Snowflakes (the Frost Fleet call pays more);
--   * the snowflake stall on the quay sells the festive livery, the Bosun scarf and the snowman bay
--     decor for Snowflakes only (docs/15 section 1: nothing for Robux).
-- The scarf is a data.flags.winter cosmetic welded to Bosun; the livery and the snowman are earned
-- keys (CosmeticLoadout / BayDecor). The client builds the snow, the roof frost, the string lights,
-- the tree, the stall and the ice floes (World/WinterWorld); this service owns the call and the money.
-- Replicated state: ReplicatedStorage.WinterState attributes Active, Now, EndsAt, DaysLeft,
-- FrostFleetOp. Remotes under ReplicatedStorage.Net: Winter_State S->C view, Winter_Get and
-- Winter_Buy C->S functions. Studio: ServerStorage.WinterDev (BindableFunction) "award" n,
-- "buy" id, "call", "state"; chat "/winter" forces the window and starts the call (server-side,
-- so it works from either command bar), "/frost" just forces the window.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local OfferPacing = require(Shared:WaitForChild("Calls"):WaitForChild("OfferPacing"))
local Rules = require(Shared:WaitForChild("SeasonalRules"))
local SeasonalEvents = require(Shared:WaitForChild("Config"):WaitForChild("SeasonalEvents"))

local DataService = require(script.Parent.DataService)
local DogService = require(script.Parent.DogService)
local OperationService = require(script.Parent.OperationService)
local ProgressionService = require(script.Parent.ProgressionService)

local EVENT = SeasonalEvents.Winter
local FLAG = EVENT.currencyFlag or "winter"
local VARIANT = EVENT.callVariant or "FrostFleet"
local FOLDER_NAME = "WinterState"
local TICK = 1
local DECORATE_TICK = 2
local BUY_COOLDOWN = 0.4
local SCARF_RED = Color3.fromRGB(196, 66, 58)

local WinterService = {}
WinterService.Priority = 93

local folder: Folder
local stateRemote: RemoteEvent? = nil
local lastCallAt = 0
local lastBuy: { [Player]: number } = {}
local lastOffer: { [Player]: number } = {}

local function offset(): number
	local value = Workspace:GetAttribute("EventClockOffset")
	return if type(value) == "number"
			and (RunService:IsStudio() or Workspace:GetAttribute("DevBoard"))
		then value
		else 0
end

local function now(): number
	return os.time() + offset()
end

local function forced(): boolean
	return RunService:IsStudio() and Workspace:GetAttribute(SeasonalEvents.DevAttribute) == true
end

local function active(): boolean
	return Rules.live(EVENT, now(), forced())
end

local function stateOf(player: Player): Rules.State
	local data = DataService.Get(player)
	return Rules.fromFlag(if data then data.flags[FLAG] else nil, EVENT)
end

local function owned(player: Player, flag: string): boolean
	return stateOf(player).owned[flag] == true
end

local function viewOf(player: Player): { [string]: any }
	local state = stateOf(player)
	local t = now()
	return {
		active = Rules.live(EVENT, t, forced()),
		now = t,
		endsAt = EVENT.endUtc,
		daysLeft = math.max(if forced() then 1 else 0, Rules.daysLeft(EVENT, t)),
		currency = EVENT.currency or "Snowflakes",
		snowflakes = state.candy,
		owned = state.owned,
	}
end

local function push(player: Player)
	local remote = stateRemote
	if remote and player.Parent then
		remote:FireClient(player, viewOf(player))
	end
end

local function save(player: Player, state: Rules.State): boolean
	return ProgressionService.SetFlag(player, FLAG, Rules.flagTable(state))
end

local function award(player: Player, amount: number)
	local data = DataService.Get(player)
	if not data or amount <= 0 then
		return
	end
	local state = stateOf(player)
	if save(player, Rules.reward(state, amount)) then
		push(player)
	end
end

---------------------------------------------------------------- the Bosun scarf

local function weldTo(parent: BasePart, part: BasePart, cf: CFrame)
	part.CFrame = cf
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.Parent = parent.Parent
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = parent
	weld.Part1 = part
	weld.Parent = part
end

local function decorateDog(player: Player)
	local dog = DogService.GetDog(player)
	if not dog or dog:GetAttribute("WinterScarf") then
		return
	end
	local neck = dog:FindFirstChild("Neck")
	if not neck or not neck:IsA("BasePart") then
		return
	end
	local wrap = Instance.new("Part")
	wrap.Name = "WinterScarf"
	wrap.Shape = Enum.PartType.Ball
	wrap.Size = Vector3.new(0.9, 0.34, 0.9)
	wrap.Color = SCARF_RED
	wrap.Material = Enum.Material.Fabric
	weldTo(neck, wrap, neck.CFrame * CFrame.new(0, 0.12, 0))
	local tail = Instance.new("Part")
	tail.Name = "WinterScarfTail"
	tail.Size = Vector3.new(0.26, 0.7, 0.12)
	tail.Color = SCARF_RED
	tail.Material = Enum.Material.Fabric
	weldTo(neck, tail, neck.CFrame * CFrame.new(0.34, -0.22, 0.36))
	dog:SetAttribute("WinterScarf", true)
end

---------------------------------------------------------------- the Frost Fleet call

local function eventCallRunning(): boolean
	for _, info in OperationService.GetActiveOperations() do
		if info.isBig then
			return true
		end
	end
	return false
end

local function publishFrostOp(): string
	local opId = ""
	for _, info in OperationService.GetActiveOperations() do
		if info.isBig and info.variant == VARIANT then
			opId = info.id
			break
		end
	end
	folder:SetAttribute("FrostFleetOp", opId)
	return opId
end

-- Returns whether the tagged call is up. A plain storm ferry already running blocks it, so the
-- caller retries soon instead of burning the whole callCooldown on nothing.
local function startCall(): boolean
	local ok = pcall(OperationService.ForceBigCall, VARIANT)
	if not ok then
		warn("[WinterService] Frost Fleet call could not start")
	end
	return publishFrostOp() ~= ""
end

---------------------------------------------------------------- stall

local function nearStall(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	local dx = root.Position.X - EVENT.stallPosition.X
	local dz = root.Position.Z - EVENT.stallPosition.Z
	return dx * dx + dz * dz <= EVENT.stallRange * EVENT.stallRange
end

local function buy(player: Player, id: any, skipRange: boolean?): (boolean, string)
	if type(id) ~= "string" then
		return false, "Unknown"
	end
	if not active() then
		return false, "Closed"
	end
	local t = os.clock()
	if t - (lastBuy[player] or 0) < BUY_COOLDOWN then
		return false, "Wait"
	end
	lastBuy[player] = t
	if not skipRange and not nearStall(player) then
		return false, "Too far"
	end
	local state = stateOf(player)
	local after, reason = Rules.buy(EVENT, state, id)
	if not after then
		return false, reason or "No"
	end
	if not save(player, after) then
		return false, "Save failed"
	end
	local item = Rules.item(EVENT, id)
	if item and item.flag == "scarf" then
		decorateDog(player)
	end
	push(player)
	return true, "ok"
end

local function ensureRemoteEvent(parent: Instance, name: string): RemoteEvent
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local created = Instance.new("RemoteEvent")
	created.Name = name
	created.Parent = parent
	return created
end

local function ensureRemoteFunction(parent: Instance, name: string): RemoteFunction
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("RemoteFunction") then
		return existing
	end
	local created = Instance.new("RemoteFunction")
	created.Name = name
	created.Parent = parent
	return created
end

local function refresh()
	local t = now()
	local live = Rules.live(EVENT, t, forced())
	folder:SetAttribute("Active", live)
	folder:SetAttribute("Now", t)
	folder:SetAttribute("EndsAt", EVENT.endUtc)
	folder:SetAttribute("DaysLeft", Rules.daysLeft(EVENT, t))
	if live then
		publishFrostOp()
		local frostOp = folder:GetAttribute("FrostFleetOp")
		if frostOp ~= "" then
			-- the server-wide call keeps offering itself to players who are free
			for _, player in Players:GetPlayers() do
				if
					OfferPacing.eventOfferDue(
						t - (lastOffer[player] or 0),
						not OperationService.GetOperationOf(player)
					)
				then
					lastOffer[player] = t
					pcall(OperationService.OfferBigCall, player, VARIANT)
				end
			end
		end
		local players = #Players:GetPlayers()
		if
			OfferPacing.eventCallDue(
				players,
				eventCallRunning(),
				t - lastCallAt,
				EVENT.callCooldown
			)
		then
			if startCall() then
				lastCallAt = t
			else
				-- a storm ferry (or a failed start) held it: try again in EventRetry s, not 20 min
				lastCallAt = t - EVENT.callCooldown + OfferPacing.EventRetry
			end
		end
	else
		folder:SetAttribute("FrostFleetOp", "")
	end
end

function WinterService.Init()
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	folder:SetAttribute("Active", false)
	folder:SetAttribute("Now", os.time())
	folder:SetAttribute("EndsAt", EVENT.endUtc)
	folder:SetAttribute("DaysLeft", 0)
	folder:SetAttribute("FrostFleetOp", "")

	local net = ReplicatedStorage:WaitForChild("Net")
	stateRemote = ensureRemoteEvent(net, "Winter_State")
	ensureRemoteFunction(net, "Winter_Get").OnServerInvoke = function(player: Player)
		return viewOf(player)
	end
	ensureRemoteFunction(net, "Winter_Buy").OnServerInvoke = function(player: Player, id: any)
		return buy(player, id)
	end

	OperationService.OperationCompleted:Connect(function(info, helpers)
		if not active() then
			return
		end
		local amount = Rules.candyFor(EVENT, info.variant == VARIANT)
		for _, player in helpers do
			award(player, amount)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastBuy[player] = nil
		lastOffer[player] = nil
	end)
	if RunService:IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "WinterDev"
		dev.OnInvoke = function(cmd: string, value: any): any
			local player = Players:GetPlayers()[1]
			if cmd == "award" and player then
				award(player, tonumber(value) or 5)
				return viewOf(player)
			elseif cmd == "buy" and player then
				return buy(player, value, true)
			elseif cmd == "call" or cmd == "force" then
				-- every dev action implies the window: art capture must not need the date or a
				-- second command bar (a client-set attribute never reaches the server)
				Workspace:SetAttribute(SeasonalEvents.DevAttribute, true)
				-- nothing yet? the tick retries next second rather than after the cooldown
				lastCallAt = if startCall() then now() else 0
				refresh()
				return if player then viewOf(player) else nil
			elseif cmd == "state" and player then
				return viewOf(player)
			end
			return nil
		end
		dev.Parent = ServerStorage
	end
end

function WinterService.Start()
	DataService.OnLoaded(function(player: Player, _data)
		task.defer(function()
			if player.Parent then
				push(player)
				if owned(player, "scarf") then
					decorateDog(player)
				end
			end
		end)
	end)
	Players.PlayerAdded:Connect(function(player)
		task.delay(3, function()
			if player.Parent then
				push(player)
			end
		end)
		if RunService:IsStudio() then
			player.Chatted:Connect(function(msg)
				if msg ~= "/winter" and msg ~= "/frost" then
					return
				end
				Workspace:SetAttribute(SeasonalEvents.DevAttribute, true)
				if msg == "/winter" then
					lastCallAt = if startCall() then now() else 0
					pcall(OperationService.OfferBigCall, player, VARIANT)
				end
				refresh()
			end)
		end
	end)
	refresh()
	local elapsed = 0
	while true do
		task.wait(TICK)
		refresh()
		elapsed += TICK
		if elapsed >= DECORATE_TICK then
			elapsed = 0
			for _, player in Players:GetPlayers() do
				if owned(player, "scarf") then
					decorateDog(player)
				end
			end
		end
	end
end

return WinterService
