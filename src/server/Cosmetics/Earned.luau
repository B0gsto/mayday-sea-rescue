--!strict
-- Earned (server cosmetic feature, G28): makes the earned-but-data-only rewards show.
-- Stock trims, season rewards, the monthly livery and the Halloween bay pumpkin live in profile
-- flags (data.flags.stock / season / monthlyLivery / halloween). CosmeticLoadout turns those flags
-- into the `earn` keys the cosmetic options use; this feature:
--   * mirrors them to the player attribute "CosOwned" (client pickers read it) through
--     CosmeticsService.Refresh;
--   * auto-equips the newest earned option once so the player notices it (a claim, a purchase or a
--     dev grant), and migrates existing saves once (flag `cosmeticAuto`);
--   * has the Studio hook ServerStorage.CosmeticDev: "all" / "stock" / "season" / "monthly" /
--     "halloween" / "state".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CosmeticLoadout = require(Shared:WaitForChild("CosmeticLoadout"))
local Season = require(Shared:WaitForChild("Config"):WaitForChild("Season"))
local SeasonalRules = require(Shared:WaitForChild("SeasonalRules"))
local StockConfig = require(Shared:WaitForChild("Config"):WaitForChild("StockConfig"))

local Services = script.Parent.Parent:WaitForChild("Services")
local DataService = require(Services:WaitForChild("DataService"))
local ProgressionService = require(Services:WaitForChild("ProgressionService"))

local Earned = {}
Earned.Priority = 10

local POLL = 2
local service: any = nil
local last: { [Player]: CosmeticLoadout.Loadout } = {}
local seen: { [Player]: boolean } = {}

local function dataOf(player: Player): any
	return DataService.Get(player)
end

local function show(player: Player): CosmeticLoadout.Loadout?
	local data = dataOf(player)
	return if data then CosmeticLoadout.show(data.flags) else nil
end

local function sameOwned(a: { [string]: boolean }, b: { [string]: boolean }): boolean
	return CosmeticLoadout.encode(a) == CosmeticLoadout.encode(b)
end

-- Compares this loadout with the last poll; equips what is newly earned. `first` = profile load.
local function sync(player: Player, first: boolean)
	local data = dataOf(player)
	local loadout = show(player)
	if not data or not loadout then
		return
	end
	local previous = last[player]
	last[player] = loadout
	if not sameOwned(loadout.owned, if previous then previous.owned else {}) then
		service.Refresh(player)
	end
	local migrate = first and data.flags.cosmeticAuto ~= true
	for slot, entry in loadout.newest do
		local before = previous and previous.newest[slot]
		local fresh = before == nil or before.id ~= entry.id
		local wanted = if first then migrate and data.cosmetics[slot] == nil else fresh
		if wanted then
			service.Equip(player, slot, entry.id)
		end
	end
	if migrate then
		ProgressionService.SetFlag(player, "cosmeticAuto", true)
	end
end

local function poll()
	for _, player in Players:GetPlayers() do
		if not dataOf(player) then
			continue
		end
		if not seen[player] then
			seen[player] = true
			sync(player, true)
		else
			local loadout = show(player)
			local previous = last[player]
			if loadout and (previous == nil or not sameOwned(loadout.owned, previous.owned)) then
				sync(player, false)
			end
		end
	end
end

---------------------------------------------------------------- Studio dev hook

local function grantStock(player: Player, keys: string)
	local data = dataOf(player)
	if not data then
		return
	end
	local owned: any = if type(data.flags.stock) == "table"
		then table.clone(data.flags.stock)
		else {}
	for key in string.gmatch(keys, "[^,%s]+") do
		owned[key] = true
	end
	ProgressionService.SetFlag(player, "stock", owned)
end

local function grantSeason(player: Player)
	local claimed = 0
	for tier = 1, Season.maxTier do
		if Season.tiers[tier] and Season.tiers[tier].cosmetic then
			claimed = bit32.bor(claimed, bit32.lshift(1, tier - 1))
		end
	end
	local top = Season.tiers[#Season.tiers]
	ProgressionService.SetFlag(player, "season", {
		s = Season.id,
		xp = if top then top.xp else 0,
		c = tostring(claimed),
		v = 0,
	})
end

local function grantHalloween(player: Player)
	local data = dataOf(player)
	if not data then
		return
	end
	local state =
		SeasonalRules.fromFlag(if type(data.flags) == "table" then data.flags.halloween else nil)
	state.owned.livery = true
	state.owned.decor = true
	ProgressionService.SetFlag(player, "halloween", SeasonalRules.flagTable(state))
end

local function allStock(): string
	local out = {}
	for _, key in StockConfig.Order do
		local item = StockConfig.Items[key]
		if item and item.cosmetic then
			table.insert(out, item.cosmetic)
		end
	end
	return table.concat(out, ",")
end

function Earned.Init(cosmeticsService: any)
	service = cosmeticsService
	if RunService:IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "CosmeticDev"
		dev.OnInvoke = function(cmd: string): any
			local player = Players:GetPlayers()[1]
			if not player then
				return nil
			end
			if cmd == "stock" then
				grantStock(player, allStock())
			elseif cmd == "season" then
				grantSeason(player)
			elseif cmd == "monthly" then
				ProgressionService.SetFlag(player, "monthlyLivery", "2026-10")
			elseif cmd == "halloween" then
				grantHalloween(player)
			elseif cmd == "all" then
				grantStock(player, allStock())
				grantSeason(player)
				ProgressionService.SetFlag(player, "monthlyLivery", "2026-10")
				grantHalloween(player)
			end
			sync(player, false)
			return show(player)
		end
		dev.Parent = ServerStorage
	end
end

function Earned.Start()
	DataService.OnLoaded(function(player: Player)
		seen[player] = true
		sync(player, true)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		last[player] = nil
		seen[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(POLL)
			if not pcall(poll) then
				warn("[Earned] poll failed")
			end
		end
	end)
end

return Earned
