--!strict
-- StockService: the rotating Chandlery stock (docs/15 hook H3). StockRotation owns the shared
-- 10-minute UTC window and its deterministic roll; this service owns the live stock counts, the
-- per-player limits and the purchase. Cash only, never Robux (docs/15 section 1).
--
-- Remotes (under ReplicatedStorage.Net):
--   Stock_State  S->C  { window, secondsToRestock, items = { { slot, id, name, price, rarity, kind,
--                        remaining, mine, limit } } }
--   Stock_Get    C->S  function -> the same view (first pull, or the client's own restock probe)
--   Stock_Buy    C->S  function (slot) -> ok, reason
-- The shelf and clock are built locally by StockController at the counter prompt.
-- Studio: ServerStorage.StockDev (BindableFunction) "shift" [n] jumps the clock n windows,
-- "reset" returns to the real clock, "view" / "buy" slot for play tests.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local StockConfig = require(Shared:WaitForChild("Config"):WaitForChild("StockConfig"))
local StockRotation = require(Shared:WaitForChild("StockRotation"))

local DataService = require(script.Parent.DataService)
local PetService = require(script.Parent.PetService)
local ProgressionService = require(script.Parent.ProgressionService)

local StockService = {}
StockService.Priority = 90

local BUY_COOLDOWN = 0.4
local COUNTER_RANGE = 20 -- studs, horizontal, like the other in-world shop counters

local stateRemote: RemoteEvent? = nil
local stockOffset = 0 -- Studio only: StockDev "shift" moves the window without waiting 10 minutes
local cacheWindow: number? = nil
local cacheSlots: { StockRotation.Slot } = {}
local sold: { [number]: { [number]: number } } = {}
local bought: { [number]: { [number]: { [number]: number } } } = {}
local lastBuy: { [Player]: number } = {}
local shopCounter: BasePart? = nil

local function now(): number
	return os.time() + stockOffset
end

local function slotsFor(window: number): { StockRotation.Slot }
	if cacheWindow ~= window then
		cacheWindow = window
		cacheSlots = StockRotation.roll(window * StockConfig.Period)
		sold = {}
		bought = {}
	end
	return cacheSlots
end

local function soldFor(window: number): { [number]: number }
	local list = sold[window]
	if not list then
		list = {}
		sold[window] = list
	end
	return list
end

local function boughtFor(window: number, player: Player): { [number]: number }
	local byWindow = bought[window]
	if not byWindow then
		byWindow = {}
		bought[window] = byWindow
	end
	local mine = byWindow[player.UserId]
	if not mine then
		mine = {}
		byWindow[player.UserId] = mine
	end
	return mine
end

local function viewFor(player: Player, window: number): { [string]: any }
	local slots = slotsFor(window)
	local counts = soldFor(window)
	local mine = boughtFor(window, player)
	local items = {}
	for slot, entry in slots do
		local item = entry.item
		items[slot] = {
			slot = slot,
			id = item.id,
			name = item.name,
			kind = item.kind,
			rarity = item.rarity,
			price = item.price,
			remaining = math.max(0, entry.count - (counts[slot] or 0)),
			mine = mine[slot] or 0,
			limit = item.limit,
		}
	end
	return {
		window = window,
		secondsToRestock = StockRotation.secondsToRestock(now()),
		items = items,
	}
end

local function counter(): BasePart?
	local cached = shopCounter
	if cached and cached.Parent then
		return cached
	end
	for _, descendant in Workspace:GetDescendants() do
		local parent = descendant.Parent
		if
			descendant:IsA("ProximityPrompt")
			and descendant:GetAttribute("Panel") == "ShopCounter"
			and parent
			and parent:IsA("BasePart")
		then
			shopCounter = parent
			return parent
		end
	end
	return nil
end

local function nearCounter(player: Player): boolean
	local shelf = counter()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not shelf or not root or not root:IsA("BasePart") then
		return false
	end
	local dx = root.Position.X - shelf.Position.X
	local dz = root.Position.Z - shelf.Position.Z
	return dx * dx + dz * dz <= COUNTER_RANGE * COUNTER_RANGE
end

local function push(player: Player, window: number)
	local remote = stateRemote
	if remote and player.Parent then
		remote:FireClient(player, viewFor(player, window))
	end
end

local function broadcast()
	local window = StockRotation.windowIndex(now())
	for _, player in Players:GetPlayers() do
		push(player, window)
	end
end

local function buy(player: Player, slot: any): (boolean, string)
	local slotIndex = tonumber(slot)
	if not slotIndex or slotIndex ~= math.floor(slotIndex) or slotIndex < 1 then
		return false, "Bad slot"
	end
	if not nearCounter(player) then
		return false, "Too far"
	end
	local at = os.clock()
	if lastBuy[player] and at - lastBuy[player] < BUY_COOLDOWN then
		return false, "Too fast"
	end
	lastBuy[player] = at
	local window = StockRotation.windowIndex(now())
	local entry = slotsFor(window)[slotIndex]
	if not entry then
		return false, "Sold out"
	end
	local item = entry.item
	local counts = soldFor(window)
	if (counts[slotIndex] or 0) >= entry.count then
		return false, "Sold out"
	end
	local mine = boughtFor(window, player)
	if (mine[slotIndex] or 0) >= item.limit then
		return false, "Limit"
	end
	if item.treat then
		local ok, reason = PetService.BuyTreat(player, item.price)
		if not ok then
			return false, reason or "Could not buy"
		end
		counts[slotIndex] = (counts[slotIndex] or 0) + 1
		mine[slotIndex] = (mine[slotIndex] or 0) + 1
		broadcast()
		return true, "ok"
	end
	local data = DataService.Get(player)
	if not data then
		return false, "Data not loaded"
	end
	if data.cash < item.price then
		return false, "Need Cash"
	end
	local gearId = item.gear
	local key = if gearId then gearId else item.cosmetic
	if not key then
		return false, "Bad item"
	end
	local ok, reason = ProgressionService.BuyStock(player, item.price, key, gearId ~= nil)
	if not ok then
		return false, reason
	end
	counts[slotIndex] = (counts[slotIndex] or 0) + 1
	mine[slotIndex] = (mine[slotIndex] or 0) + 1
	broadcast()
	return true, "ok"
end

local function ensureRemoteEvent(folder: Instance, name: string): RemoteEvent
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local created = Instance.new("RemoteEvent")
	created.Name = name
	created.Parent = folder
	return created
end

local function ensureRemoteFunction(folder: Instance, name: string): RemoteFunction
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteFunction") then
		return existing
	end
	local created = Instance.new("RemoteFunction")
	created.Name = name
	created.Parent = folder
	return created
end

function StockService.Init()
	local folder = Net.init()
	stateRemote = ensureRemoteEvent(folder, "Stock_State")
	ensureRemoteFunction(folder, "Stock_Get").OnServerInvoke = function(player: Player)
		return viewFor(player, StockRotation.windowIndex(now()))
	end
	ensureRemoteFunction(folder, "Stock_Buy").OnServerInvoke = function(player: Player, slot: any)
		return buy(player, slot)
	end
	if RunService:IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "StockDev"
		dev.OnInvoke = function(cmd: string, value: any): any
			local player = Players:GetPlayers()[1]
			if cmd == "shift" then
				stockOffset += StockConfig.Period * (tonumber(value) or 1)
				broadcast()
				if player then
					return viewFor(player, StockRotation.windowIndex(now()))
				end
				return true
			elseif cmd == "reset" then
				stockOffset = 0
				broadcast()
				return true
			elseif cmd == "buy" and player then
				return buy(player, value)
			elseif cmd == "view" and player then
				return viewFor(player, StockRotation.windowIndex(now()))
			end
			return nil
		end
		dev.Parent = ServerStorage
	end
end

function StockService.Start()
	local seen = StockRotation.windowIndex(now())
	broadcast()
	while true do
		task.wait(1)
		local window = StockRotation.windowIndex(now())
		if window ~= seen then
			seen = window
			broadcast() -- slotsFor clears the sold counts when the window moves on
		end
	end
end

return StockService
