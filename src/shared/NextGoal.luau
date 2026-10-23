--!strict
-- NextGoal: the one unlock the HUD chip shows (docs/16 K6). Pure and Lune-tested
-- (tests/NextGoal.spec.luau). Reads the client's PlayerDataChanged snapshot and returns two kinds
-- of goal, nearest first:
--   Rank     the next rank (or Service Star past Admiral), Rep progress
--   Vehicle  the next boat to buy (the cheapest unowned Cash boat), Cash progress
-- The fraction is value / target; the order only breaks ties (rank first).
local ProgressionConfig = require(script.Parent.Config.ProgressionConfig)
local ProgressionRules = require(script.Parent.ProgressionRules)

export type Kind = "Rank" | "Vehicle"
export type Unit = "Rep" | "Cash"

export type Goal = {
	kind: Kind,
	key: string, -- stable while this exact unlock is the goal ("Vehicle:RIB")
	label: string, -- 1-3 words next to the icon
	vehicleId: string?, -- Vehicle goals: the boat whose silhouette the chip draws
	value: number,
	target: number,
	fraction: number,
	unit: Unit,
}

local NextGoal = {}

local VEHICLE_LABEL = { RIB = "RIB", Lifeboat = "Lifeboat" }

local function goal(
	kind: Kind,
	key: string,
	label: string,
	value: number,
	target: number,
	unit: Unit
): Goal
	local clamped = math.clamp(value, 0, target)
	return {
		kind = kind,
		key = key,
		label = label,
		value = clamped,
		target = target,
		fraction = clamped / target,
		unit = unit,
	}
end

local function rankGoal(snapshot: { [string]: any }, rankIndex: number): Goal?
	local rep = tonumber(snapshot.rep) or 0
	local ranks = ProgressionConfig.Ranks
	if rankIndex >= #ranks then
		local stars = tonumber(snapshot.stars) or ProgressionRules.serviceStarsFromRep(rep)
		local base = ranks[#ranks].rep + stars * ProgressionConfig.ServiceStarStep
		return goal(
			"Rank",
			`Star:{stars + 1}`,
			`Star {stars + 1}`,
			rep - base,
			ProgressionConfig.ServiceStarStep,
			"Rep"
		)
	end
	local nextRank = ranks[rankIndex + 1]
	return goal("Rank", `Rank:{nextRank.id}`, nextRank.displayName, rep, nextRank.rep, "Rep")
end

-- The cheapest boat the player can still buy with Cash (rank-locked ones too: the rank comes first).
local function vehicleGoal(snapshot: { [string]: any }): Goal?
	local owned = if type(snapshot.vehicles) == "table" then snapshot.vehicles else {}
	local bestId: string?, bestPrice = nil, math.huge
	for id, unlock in ProgressionConfig.Vehicles do
		if
			VEHICLE_LABEL[id]
			and unlock.price > 0
			and unlock.passOnly ~= true
			and owned[id] ~= true
			and unlock.price < bestPrice
		then
			bestId, bestPrice = id, unlock.price
		end
	end
	if not bestId then
		return nil
	end
	local g = goal(
		"Vehicle",
		`Vehicle:{bestId}`,
		VEHICLE_LABEL[bestId],
		tonumber(snapshot.cash) or 0,
		bestPrice,
		"Cash"
	)
	g.vehicleId = bestId
	return g
end

-- Both live goals, nearest first (ties: rank first).
function NextGoal.goals(snapshot: { [string]: any }): { Goal }
	local goals: { Goal } = {}
	if type(snapshot) ~= "table" then
		return goals
	end
	local rankIndex = math.clamp(
		tonumber(snapshot.rankIndex)
			or ProgressionRules.rankIndexForRep(tonumber(snapshot.rep) or 0),
		1,
		#ProgressionConfig.Ranks
	)
	table.insert(goals, rankGoal(snapshot, rankIndex) :: Goal)
	local vehicle = vehicleGoal(snapshot)
	if vehicle then
		table.insert(goals, vehicle)
	end
	table.sort(goals, function(a, b)
		if a.fraction ~= b.fraction then
			return a.fraction > b.fraction
		end
		return a.kind == "Rank"
	end)
	return goals
end

function NextGoal.best(snapshot: { [string]: any }): Goal?
	return NextGoal.goals(snapshot)[1]
end

return NextGoal
