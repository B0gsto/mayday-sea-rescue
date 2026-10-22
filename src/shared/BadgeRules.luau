--!strict
-- BadgeRules: pure badge logic (Lune-tested in tests/Badges.spec.luau). BadgeService feeds it the debrief
-- snapshot OperationService passes to OperationCompleted and keeps the counters on the profile.
--
--   BadgeRules.opProgress(snap, userId, helper) -> { [badgeKey]: number }   counter increments from one op
--   BadgeRules.apply(counters, increments) -> { badgeKey }                  bumps counters, returns badges whose
--                                                                           threshold was reached (now or before)
--   BadgeRules.once(counters, key, token) -> { [string]: number }           increments that count a token once
--   BadgeRules.rankBadges(rankIndex, rankIds) -> { badgeKey }               rank badges at or below a rank
--   BadgeRules.completed(snap) -> boolean                                   the op finished (not failed/taken over)

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

function BadgeRules.completed(snap: OpSnapshot): boolean
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
	if not BadgeRules.completed(snap) then
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

-- counters: the profile table { [badgeKey]: number } (mutated). Every increment is kept (the seen: tokens
-- below), but only badge keys are returned. A badge is due whenever its counter is at or past the threshold,
-- so one switched on later (id 0 -> real id) still gets awarded.
function BadgeRules.apply(
	counters: { [string]: number },
	increments: { [string]: number }
): { string }
	local touched: { [string]: boolean } = {}
	for key, inc in increments do
		if inc > 0 then
			counters[key] = (counters[key] or 0) + inc
			touched[key] = true
		end
	end
	local due: { string } = {}
	for _, key in BadgeConfig.Order do
		local b = BadgeConfig.Badges[key]
		if touched[key] and b and (counters[key] or 0) >= (b.count or 1) then
			table.insert(due, key)
		end
	end
	return due
end

-- Count a token at most once per profile: a species, an operation kind, a set. Empty increments when
-- the token was seen before, so the caller can pass them straight to apply.
function BadgeRules.once(
	counters: { [string]: number },
	key: string,
	token: string
): { [string]: number }
	local seen = `seen:{key}:{token}`
	if (counters[seen] or 0) > 0 then
		return {}
	end
	return { [seen] = 1, [key] = 1 }
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
