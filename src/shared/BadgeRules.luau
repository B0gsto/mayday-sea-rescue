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
local Grading = require(script.Parent.Ops.Grading)

export type StepRecord = { id: string, grade: string?, userId: number? }

-- the OperationCompleted snapshot fields BadgeRules reads (OperationService.info plus the debrief extras)
export type OpSnapshot = {
	kind: string,
	isBig: boolean?,
	grade: string?,
	reason: string?,
	saved: number?,
	steps: { StepRecord }?,
}

local BadgeRules = {}

function BadgeRules.completed(snap: OpSnapshot): boolean
	return snap.reason == "Complete" and snap.grade ~= "Fail" and snap.grade ~= "Takeover"
end

-- this player's own step records, in the shape Grading.mastery reads
local function mine(
	snap: OpSnapshot,
	userId: number
): { { id: string, grade: string, at: number? } }
	local out = {}
	local steps: { StepRecord } = snap.steps or {}
	for _, s in steps do
		if s.userId == userId and s.grade ~= nil then
			table.insert(out, { id = s.id, grade = s.grade :: string })
		end
	end
	return out
end

-- helper: the player completed at least one step of this op (OperationService's `helpers` list)
function BadgeRules.opProgress(
	snap: OpSnapshot,
	userId: number,
	helper: boolean
): { [string]: number }
	local out: { [string]: number } = {}
	if not helper or not BadgeRules.completed(snap) then
		return out
	end
	out.FirstRescue = 1
	out.Rescue100 = 1
	-- the debrief's smooth-ride mastery, on this player's own rides home
	if Grading.mastery(snap.grade or "", mine(snap, userId), 0, 0).smooth then
		out.SmoothRide = 1
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
