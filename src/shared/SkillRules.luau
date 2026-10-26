--!strict
-- SkillRules (docs/24 G): the player + crew skill tree's data and pure rules. One table of nodes; every node
-- belongs to a branch (Captain, Builder, Gatherer, Rescuer, Mechanic, Medic, Crew) and needs the ids before it.
-- `col, row` is the layout hint: col grows left to right along a branch, row splits a fork.
-- Effects are summed as deltas (owned -> effects): multipliers read `1 + delta` (speedMult, swimMult,
-- gatherMult, payBonus, buildRate, tripPayMult) or `1 - delta` (boatScale, tripScale); everything else is added.
-- extraSlots is per branch (the building that gets the place). Pure (tests/SkillRules.spec.luau); the server
-- (SkillService) publishes the totals as `Skill*` player attributes the readers use.
local SkillRules = {}

export type Effect = { kind: string, amount: number }
export type Node = {
	id: string,
	branch: string,
	name: string,
	icon: string, -- a UiImages.Kit key, "" for no art
	cash: number,
	needs: { string },
	effect: Effect,
	col: number,
	row: number,
}

SkillRules.BRANCHES = {
	"Captain",
	"Builder",
	"Gatherer",
	"Rescuer",
	"Mechanic",
	"Medic",
	"Crew",
}

local function node(
	id: string,
	branch: string,
	name: string,
	icon: string,
	cash: number,
	needs: { string },
	kind: string,
	amount: number,
	col: number,
	row: number
): Node
	return {
		id = id,
		branch = branch,
		name = name,
		icon = icon,
		cash = cash,
		needs = needs,
		effect = { kind = kind, amount = amount },
		col = col,
		row = row,
	}
end

SkillRules.NODES = {
	-- Captain (you): craft speed, handling, reach, Boat to me, call pay, swim
	node("CaptSpeed1", "Captain", "Ski Speed", "boost", 1000, {}, "speedMult", 0.04, 0, 0),
	node(
		"CaptSpeed2",
		"Captain",
		"Speed II",
		"speed",
		1500,
		{ "CaptSpeed1" },
		"speedMult",
		0.04,
		1,
		0
	),
	node(
		"CaptSpeed3",
		"Captain",
		"Speed III",
		"speed",
		2500,
		{ "CaptSpeed2" },
		"speedMult",
		0.04,
		2,
		0
	),
	node("CaptGrip", "Captain", "Grip", "wave", 1600, { "CaptSpeed2" }, "grip", 0.25, 2, -1),
	node(
		"CaptReach",
		"Captain",
		"Pickup Reach",
		"lifebuoy",
		1800,
		{ "CaptSpeed2" },
		"reach",
		3,
		2,
		1
	),
	node(
		"CaptPay1",
		"Captain",
		"Call Pay I",
		"cash",
		2800,
		{ "CaptGrip" },
		"payBonus",
		0.05,
		3,
		-1
	),
	node(
		"CaptBoatCall",
		"Captain",
		"Boat Call",
		"boat_to_me",
		3000,
		{ "CaptReach" },
		"boatScale",
		0.1,
		3,
		1
	),
	node(
		"CaptPay2",
		"Captain",
		"Call Pay II",
		"cash",
		6000,
		{ "CaptPay1" },
		"payBonus",
		0.05,
		4,
		-1
	),
	node(
		"CaptSwim",
		"Captain",
		"Swim Speed",
		"waves",
		8000,
		{ "CaptBoatCall" },
		"swimMult",
		0.2,
		4,
		1
	),

	-- Builder: build rate, more builders at a site, a third base crew NPC
	node("Build1", "Builder", "Quick Hands", "build", 1200, {}, "buildRate", 0.1, 0, 0),
	node("Build2", "Builder", "Build II", "build", 1700, { "Build1" }, "buildRate", 0.1, 1, 0),
	node("Build3", "Builder", "Build III", "build", 2800, { "Build2" }, "buildRate", 0.1, 2, 0),
	node(
		"BuildCrew",
		"Builder",
		"Extra Hands",
		"crew",
		4500,
		{ "Build2" },
		"extraBuilders",
		2,
		2,
		-1
	),
	node("BuildBase", "Builder", "Base Crew", "crew", 6000, { "Build3" }, "baseCrew", 1, 3, 0),

	-- Gatherer: gather pay, offline rate, one more slot at the fish shed
	node("Gather1", "Gatherer", "Fish Price", "cash", 1300, {}, "gatherMult", 0.15, 0, 0),
	node("Gather2", "Gatherer", "Price II", "cash", 1800, { "Gather1" }, "gatherMult", 0.15, 1, 0),
	node("Gather3", "Gatherer", "Price III", "cash", 3000, { "Gather2" }, "gatherMult", 0.15, 2, 0),
	node(
		"GatherNight",
		"Gatherer",
		"Night Shift",
		"daily",
		3500,
		{ "Gather2" },
		"offlineRate",
		0.1,
		2,
		-1
	),
	node(
		"GatherStall",
		"Gatherer",
		"Market Stall",
		"crew",
		5000,
		{ "Gather2" },
		"extraSlots",
		1,
		2,
		1
	),

	-- Rescuer: trip time, recruit chance, trip pay
	node("Rescue1", "Rescuer", "Faster Boat", "lifebuoy", 1500, {}, "tripScale", 0.15, 0, 0),
	node(
		"Rescue2",
		"Rescuer",
		"Recruiter",
		"crew",
		2500,
		{ "Rescue1" },
		"recruitChance",
		0.05,
		1,
		0
	),
	node(
		"Rescue3",
		"Rescuer",
		"Bigger Cut",
		"cash",
		6000,
		{ "Rescue2" },
		"tripPayMult",
		0.25,
		2,
		0
	),

	-- Mechanic: raise the speed and Boat to me caps
	node("Mech1", "Mechanic", "Tuned Engine", "boost", 2500, {}, "speedCapAdd", 0.05, 0, 0),
	node(
		"Mech2",
		"Mechanic",
		"Quick Call",
		"boat_to_me",
		7000,
		{ "Mech1" },
		"boatCapAdd",
		0.1,
		1,
		0
	),

	-- Medic: raise the call-pay cap, pay more per Medic unit
	node("Medic1", "Medic", "Field Kit", "boost", 3000, {}, "medicCapAdd", 0.1, 0, 0),
	node("Medic2", "Medic", "Medic Pay", "cash", 6000, { "Medic1" }, "medicPerUnit", 0.05, 1, 0),

	-- Crew: worker cap, rarer rescues
	node("Crew1", "Crew", "Bunkhouse", "crew", 1400, {}, "workerCapAdd", 5, 0, 0),
	node("Crew2", "Crew", "Bunkhouse II", "crew", 2400, { "Crew1" }, "workerCapAdd", 5, 1, 0),
	node("Crew3", "Crew", "Bunkhouse III", "crew", 3500, { "Crew2" }, "workerCapAdd", 5, 2, 0),
	node("CrewRare1", "Crew", "Lucky Find", "spin", 3500, { "Crew1" }, "rareChanceAdd", 0.03, 1, 1),
	node(
		"CrewRare2",
		"Crew",
		"Lucky Find II",
		"spin",
		40000,
		{ "CrewRare1" },
		"rareChanceAdd",
		0.03,
		2,
		1
	),
} :: { Node }

SkillRules.byId = {}
for _, n in SkillRules.NODES do
	SkillRules.byId[n.id] = n
end

SkillRules.KINDS = {
	"speedMult",
	"grip",
	"reach",
	"boatScale",
	"payBonus",
	"swimMult",
	"buildRate",
	"extraBuilders",
	"baseCrew",
	"gatherMult",
	"offlineRate",
	"tripScale",
	"recruitChance",
	"tripPayMult",
	"speedCapAdd",
	"boatCapAdd",
	"medicCapAdd",
	"medicPerUnit",
	"workerCapAdd",
	"rareChanceAdd",
}

-- Every effect kind summed over the owned nodes (extraSlots per branch), zero for the rest.
function SkillRules.effects(owned: { [string]: boolean }): { [string]: any }
	local out: { [string]: any } = {}
	for _, kind in SkillRules.KINDS do
		out[kind] = 0
	end
	out.extraSlots = {}
	for id in owned do
		local n = SkillRules.byId[id]
		if n then
			local kind = n.effect.kind
			if kind == "extraSlots" then
				out.extraSlots[n.branch] = (out.extraSlots[n.branch] or 0) + n.effect.amount
			elseif out[kind] ~= nil then
				out[kind] += n.effect.amount
			end
		end
	end
	return out
end

-- May `id` be bought? -> ok, reason: "Owned" | "Needs" | "Cash" | "Unknown" (nil when ok).
function SkillRules.canBuy(
	owned: { [string]: boolean },
	id: string,
	cash: number
): (boolean, string?)
	local n = if type(id) == "string" then SkillRules.byId[id] else nil
	if not n then
		return false, "Unknown"
	end
	if owned[id] == true then
		return false, "Owned"
	end
	for _, need in n.needs do
		if owned[need] ~= true then
			return false, "Needs"
		end
	end
	if (tonumber(cash) or 0) < n.cash then
		return false, "Cash"
	end
	return true, nil
end

return SkillRules
