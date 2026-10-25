--!strict
-- CashEffects (RP-M2): the Cash side of the Robux catalogue, wired by ProgressionService.
--   2x Cash pass, Cash Boost, Crew Boost   multiplier(player) -> Cash multiplier for Award
--   Cash packs (4)                          Cash of the top open zone's rate, once per receipt
--   Starter Kit pass                        3,000 Cash once per account (flag shop.starterKit)
-- Pure math: src/shared/MonetizationEffects.luau. Nothing here touches Reputation (docs/04 §1, §7).
--
-- Player attributes (read by the product cards, RP-M3): CashPerMinute, CashPacksToday,
-- CashBoostLeft, CrewBoostLeft (seconds), CrewBoostActive (someone in the crew has one running).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Effects = require(Shared:WaitForChild("MonetizationEffects"))
local MonetizationConfig = require(Shared:WaitForChild("Config"):WaitForChild("MonetizationConfig"))
local Rules = require(Shared:WaitForChild("ProgressionRules"))

local Services = script.Parent.Parent
local DataService = require(Services:WaitForChild("DataService"))
local MonetizationService = require(Services:WaitForChild("MonetizationService"))

local TICK_SECONDS = 5

local CashEffects = {}

type Refresh = (player: Player, extra: { [string]: any }?) -> ()
local refresh: Refresh = function(_player: Player, _extra: { [string]: any }?) end

local crewService: any = nil
local function crewOf(player: Player): { Player }
	if crewService == nil then
		local module = Services:FindFirstChild("CrewService")
		local ok, result = pcall(require, module :: ModuleScript)
		crewService = if ok and type(result) == "table" then result else false
	end
	if crewService and type(crewService.GetCrew) == "function" then
		local ok, crew = pcall(crewService.GetCrew, player)
		if ok and type(crew) == "table" then
			return crew
		end
	end
	return { player }
end

-- The profile's `shop` flag table, created on first use.
local function shopOf(data: Rules.PlayerData): Effects.Shop
	local shop = data.flags.shop
	if type(shop) ~= "table" then
		shop = {}
		data.flags.shop = shop
	end
	return shop
end

local function boostLeft(player: Player, field: string): number
	local data = DataService.Get(player)
	local shop = data and data.flags.shop
	local v = if type(shop) == "table" then shop[field] else nil
	return if type(v) == "number" then v else 0
end

local function crewBoostActive(player: Player): boolean
	for _, member in crewOf(player) do
		if boostLeft(member, "crewBoost") > 0 then
			return true
		end
	end
	return false
end

function CashEffects.multiplier(player: Player): number
	return Effects.cashMultiplier(
		MonetizationService.OwnsPass(player, "DoubleCash"),
		boostLeft(player, "cashBoost"),
		crewBoostActive(player)
	)
end

local function publish(player: Player, data: Rules.PlayerData)
	local shop = data.flags.shop
	local today = Effects.dayOf(os.time())
	player:SetAttribute(
		"CashPerMinute",
		Effects.cashPerMinute(MonetizationConfig.CashPackZones, Rules.rankIndex(data))
	)
	player:SetAttribute(
		"CashPacksToday",
		Effects.packsToday(if type(shop) == "table" then shop else nil, today)
	)
	player:SetAttribute("CashBoostLeft", math.ceil(boostLeft(player, "cashBoost")))
	player:SetAttribute("CrewBoostLeft", math.ceil(boostLeft(player, "crewBoost")))
	player:SetAttribute("CrewBoostActive", crewBoostActive(player))
end

local function registerPack(key: string)
	local item = MonetizationConfig.Products[key]
	MonetizationService.OnProduct(key, function(_player, data, receipt)
		local cash = Effects.packCash(
			item,
			Effects.cashPerMinute(MonetizationConfig.CashPackZones, Rules.rankIndex(data))
		)
		if cash <= 0 then
			return false -- no rate to pay from: Roblox retries rather than taking Robux for nothing
		end
		data.cash += cash
		Effects.countPack(shopOf(data), Effects.dayOf(os.time()))
		receipt.MaydayCash = cash -- for afterSaved
		return true
	end, function(player, receipt, fresh)
		local data = DataService.Get(player)
		if data and fresh then
			publish(player, data)
			local cash = tonumber(receipt.MaydayCash) or 0
			refresh(player, {
				award = { cash = cash, rep = 0, multiplier = 1, reason = `Purchase:{key}` },
			})
		end
	end)
end

local function registerBoost(key: string, field: string)
	local item = MonetizationConfig.Products[key]
	MonetizationService.OnProduct(key, function(_player, data)
		Effects.addBoost(shopOf(data), field, (item.boostMinutes or 0) * 60)
		return true
	end, function(player, _receipt, fresh)
		if not fresh then
			return
		end
		for _, member in crewOf(player) do
			local data = DataService.Get(member)
			if data then
				publish(member, data)
			end
		end
	end)
end

local function payStarterKit(player: Player)
	local deadline = os.clock() + 30
	while player.Parent and DataService.Get(player) == nil and os.clock() < deadline do
		task.wait(0.5)
	end
	local data = DataService.Get(player)
	if not data or player:GetAttribute("DataTemporary") == true then
		return -- a temporary profile would lose the flag: pay on a later join instead
	end
	local shop = shopOf(data)
	if shop.starterKit == true then
		return
	end
	local cash = MonetizationConfig.GamePasses.StarterKit.cashOnce or 0
	shop.starterKit = true
	data.cash += cash
	DataService.MarkDirty(player)
	task.spawn(DataService.Save, player, false)
	refresh(
		player,
		{ award = { cash = cash, rep = 0, multiplier = 1, reason = "Purchase:StarterKit" } }
	)
end

function CashEffects.init(refreshFn: Refresh)
	refresh = refreshFn
	for _, key in MonetizationConfig.CashPacks do
		registerPack(key)
	end
	registerBoost("CashBoost", "cashBoost")
	registerBoost("CrewBoost", "crewBoost")
	MonetizationService.OnPassOwned("StarterKit", function(player)
		payStarterKit(player)
	end)
	DataService.OnLoaded(function(player, data)
		publish(player, data)
	end)
end

-- Boost time counts down only while the player is in a server (docs/04 4.2: the timer pauses).
function CashEffects.start()
	task.spawn(function()
		while true do
			local dt = task.wait(TICK_SECONDS)
			for _, player in Players:GetPlayers() do
				local data = DataService.Get(player)
				if data then
					local shop = data.flags.shop
					if type(shop) == "table" and Effects.tickBoosts(shop, dt) then
						DataService.MarkDirty(player)
					end
					publish(player, data)
				end
			end
		end
	end)
end

return CashEffects
