--!strict
-- BadgeRules: pure badge logic (Lune-tested in tests/Badges.spec.luau). BadgeService feeds it the debrief
-- snapshot OperationService passes to OperationCompleted and keeps the counters on the profile.
--
--   BadgeRules.opProgress(snap, userId, helper) -> { [badgeKey]: number }   counter increments from one op
--   BadgeRules.apply(counters, increments) -> { badgeKey }                  bumps counters, returns badges whose
--                                                                           threshold was reached (now or before)
--   BadgeRules.rankBadges(rankIndex, rankIds) -> { badgeKey }               rank badges at or below a rank

local BadgeConfig = require(script.Parent.Config.BadgeConfig)

export type StepRecord = { id: string, grade: string?, userId: number? }

-- the OperationCompleted snapshot fields BadgeRules reads (OperationService.info plus the debrief extras)
export type OpSnapshot = {
	kind: string,
	isBig: boolean?,
	grade: string?,
	reason: string?,
	storm: boolean?,
	saved: number?,
	towParted: boolean?,
	steps: { StepRecord }?,
}

local BadgeRules = {}

local function finished(snap: OpSnapshot): boolean
	return snap.reason == "Complete" and snap.grade ~= "Fail" and snap.grade ~= "Takeover"
end

local function stepsBy(snap: OpSnapshot, userId: number, stepId: string, grade: string?): number
	local n = 0
	local steps: { StepRecord } = snap.steps or {}
	for _, s in steps do
		if s.id == stepId and s.userId == userId and s.grade ~= nil and s.grade ~= "Fail" then
			if grade == nil or s.grade == grade then
				n += 1
			end
		end
	end
	return n
end

-- helper: the player completed at least one step of this op (OperationService's `helpers` list)
function BadgeRules.opProgress(
	snap: OpSnapshot,
	userId: number,
	helper: boolean
): { [string]: number }
	local out: { [string]: number } = {}
	if not helper then
		return out
	end
	-- step badges count even when the op as a whole fails: the step itself was done
	local gold = stepsBy(snap, userId, "approach", "Gold")
	if gold > 0 then
		out.Downwind = gold
	end
	if stepsBy(snap, userId, "air_pocket", nil) > 0 then
		out.AirPocket = 1
	end
	if not finished(snap) then
		return out
	end
	out.FirstRescue = 1
	if snap.storm then
		out.StormChaser = 1
	end
	if snap.kind == "DisabledVessel" and not snap.towParted then
		out.TowTruck = 1
	end
	if snap.isBig and snap.kind == "CapsizedFerry" and (snap.saved or 0) > 0 then
		out.FerryHero = 1
	end
	return out
end

-- counters: the profile table { [badgeKey]: number } (mutated). A badge is returned whenever its counter is
-- at or past the threshold, so one switched on later (id 0 -> real id) still gets awarded.
function BadgeRules.apply(
	counters: { [string]: number },
	increments: { [string]: number }
): { string }
	local due: { string } = {}
	for _, key in BadgeConfig.Order do
		local inc = increments[key]
		if inc and inc > 0 then
			local b = BadgeConfig.Badges[key]
			local after = (counters[key] or 0) + inc
			counters[key] = after
			if b and after >= (b.count or 1) then
				table.insert(due, key)
			end
		end
	end
	return due
end

-- rankIds: ProgressionConfig rank ids in order (index 1 = Recruit). Every rank badge at or below rankIndex.
function BadgeRules.rankBadges(rankIndex: number, rankIds: { string }): { string }
	local due: { string } = {}
	for _, key in BadgeConfig.Order do
		local b = BadgeConfig.Badges[key]
		if b.rank then
			local at = table.find(rankIds, b.rank)
			if at and rankIndex >= at then
				table.insert(due, key)
			end
		end
	end
	return due
end

return BadgeRules
