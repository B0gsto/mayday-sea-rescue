--!strict
-- SkillService (docs/24 G): the player + crew skill tree's server half. Buys one node with Cash through the
-- pure rules (SkillRules.canBuy), saves data.skills and publishes the effect totals as `Skill*` player
-- attributes for the readers (WorkerRules/WorkerService, BuildTimer/DockService, VehicleService, Ops/Board,
-- OperationService, SwimController). Attributes are set on join and after every buy, so an old save or a
-- player with no skills reads the same values as before (no effect).
-- Remote: Skill_Buy C->S function (id) -> ok, reason; Skill_State S->C { owned, cash } for the tree panel.
-- shortcut: no Robux skip for nodes (34 dev products would be noise); add a Cash top-up product if asked.
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
-- (default 0) and extra slots are per branch.
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
	for _, branch in SkillRules.BRANCHES do
		player:SetAttribute(`SkillSlots{branch}`, e.extraSlots[branch] or 0)
	end
	Net.event("Skill_State"):FireClient(player, {
		owned = table.clone(data.skills),
		cash = data.cash,
	})
end

local function buy(player: Player, id: string): (boolean, string?)
	local data = DataService.Get(player)
	if not data then
		return false, "Data"
	end
	local ok, reason = SkillRules.canBuy(data.skills, id, data.cash)
	if not ok then
		return false, reason
	end
	local n = SkillRules.byId[id]
	data.cash -= n.cash
	data.skills[id] = true
	DataService.MarkDirty(player)
	publish(player, data)
	ProgressionService.Refresh(player)
	task.spawn(DataService.Save, player, false)
	return true, "ok"
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
	Players.PlayerRemoving:Connect(function(player)
		lastUse[player] = nil
	end)
	DataService.OnLoaded(function(player: Player, data: ProgressionRules.PlayerData)
		publish(player, data)
	end)
end

return SkillService
