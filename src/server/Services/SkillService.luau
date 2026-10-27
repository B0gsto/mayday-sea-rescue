--!strict
-- SkillService (docs/25 F, K3): the radial player + survivor tree's server half. Buys one node with
-- Medals through the pure rules (SkillRules.canBuy: any one need owned; rim nodes refuse), saves
-- data.skills, and publishes the effect totals as `Skill*` player attributes for the readers
-- (WorkerRules/WorkerService, BuildTimer/DockService, VehicleService, Ops/Board, OperationService,
-- SwimController). Attributes are set on join and after every buy, so an old save or a player with no
-- skills reads the same values as before (no effect). A free reset refunds every Medal and clears the tree.
-- Medals: `grantMedals` is called where rescues, grades, quests and the daily chest pay, and DockService
-- when an HQ level finishes building. Player attributes: `Medals`.
-- Remotes: Skill_Buy C->S fn (id) -> ok, reason; Skill_Reset C->S fn -> ok, refunded;
-- Skill_State S->C { owned, medals } for the tree panel.
-- shortcut: no Robux skip for nodes; Medals never come from Robux (docs/25 I.1).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local ProgressionRules = require(Shared:WaitForChild("ProgressionRules"))
local SkillRules = require(Shared:WaitForChild("SkillRules"))

local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)

local SkillService = {}
SkillService.Priority = 35 -- before DockService (40), VehicleService (50) and WorkerService (100): their joins read the attributes

local COOLDOWN = 0.35
local lastUse: { [Player]: number } = {}

-- The effect totals as attributes: multipliers arrive ready to multiply (default 1), bonuses are deltas
-- (default 0) and extra slots are per K1 category.
local function publish(player: Player, data: ProgressionRules.PlayerData)
	local e = SkillRules.effects(data.skills)
	player:SetAttribute("SkillSpeedMult", 1 + e.speedMult)
	player:SetAttribute("SkillGrip", e.grip)
	player:SetAttribute("SkillReach", e.reach)
	player:SetAttribute("SkillBoatScale", 1 - e.boatScale)
	player:SetAttribute("SkillPayBonus", e.payBonus)
	player:SetAttribute("SkillSwimMult", 1 + e.swimMult)
	player:SetAttribute("SkillBuildRate", 1 + e.buildRate)
	player:SetAttribute("SkillExtraBuilders", e.extraBuilders)
	player:SetAttribute("SkillBaseCrew", e.baseCrew)
	player:SetAttribute("SkillGatherMult", 1 + e.gatherMult)
	player:SetAttribute("SkillOfflineAdd", e.offlineRate)
	player:SetAttribute("SkillTripScale", 1 - e.tripScale)
	player:SetAttribute("SkillRecruitChance", e.recruitChance)
	player:SetAttribute("SkillTripPayMult", 1 + e.tripPayMult)
	player:SetAttribute("SkillSpeedCapAdd", e.speedCapAdd)
	player:SetAttribute("SkillBoatCapAdd", e.boatCapAdd)
	player:SetAttribute("SkillMedicCapAdd", e.medicCapAdd)
	player:SetAttribute("SkillMedicPerUnit", e.medicPerUnit)
	player:SetAttribute("SkillWorkerCapAdd", e.workerCapAdd)
	player:SetAttribute("SkillRareChanceAdd", e.rareChanceAdd)
	player:SetAttribute("Medals", data.medals)
	for _, category in SkillRules.FOCUS_CATEGORIES do
		player:SetAttribute(`SkillSlots{category}`, e.extraSlots[category] or 0)
	end
	Net.event("Skill_State"):FireClient(player, {
		owned = table.clone(data.skills),
		medals = data.medals,
	})
end

local function save(player: Player, data: ProgressionRules.PlayerData)
	DataService.MarkDirty(player)
	publish(player, data)
	ProgressionService.Refresh(player)
	task.spawn(DataService.Save, player, false)
end

local function buy(player: Player, id: string): (boolean, string?)
	local data = DataService.Get(player)
	if not data then
		return false, "Data"
	end
	local ok, reason = SkillRules.canBuy(data.skills, id, data.medals)
	if not ok then
		return false, reason
	end
	local n = SkillRules.byId[id]
	data.medals -= n.medals
	data.skills[id] = true
	save(player, data)
	return true, "ok"
end

-- The panel's free reset: hand back every Medal and empty the tree.
local function reset(player: Player): (boolean, string?)
	local data = DataService.Get(player)
	if not data then
		return false, "Data"
	end
	local refunded = SkillRules.refund(data.skills)
	if refunded > 0 then
		data.medals += refunded
	end
	data.skills = {}
	save(player, data)
	return true, `{refunded}`
end

-- Medals from the world: rescues, gold grades, quests, the daily chest and HQ levels (DockService).
function SkillService.grantMedals(player: Player, n: number, reason: string): number
	local data = DataService.Get(player)
	local count = math.floor(tonumber(n) or 0)
	if not data or count <= 0 then
		return 0
	end
	data.medals = math.clamp(data.medals + count, 0, 1e9)
	DataService.MarkDirty(player)
	publish(player, data)
	local extra = { award = { medals = count, reason = reason } }
	ProgressionService.Refresh(player, extra)
	return count
end

function SkillService.Init()
	Net.func("Skill_Buy").OnServerInvoke = function(player: Player, id: any): (boolean, string?)
		local now = os.clock()
		if lastUse[player] and now - lastUse[player] < COOLDOWN then
			return false, "Too fast"
		end
		lastUse[player] = now
		if type(id) ~= "string" then
			return false, "Unknown"
		end
		return buy(player, id)
	end
	Net.func("Skill_Reset").OnServerInvoke = function(player: Player): (boolean, string?)
		local now = os.clock()
		if lastUse[player] and now - lastUse[player] < COOLDOWN then
			return false, "Too fast"
		end
		lastUse[player] = now
		return reset(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastUse[player] = nil
	end)
	DataService.OnLoaded(function(player: Player, data: ProgressionRules.PlayerData)
		publish(player, data)
	end)
end

return SkillService
