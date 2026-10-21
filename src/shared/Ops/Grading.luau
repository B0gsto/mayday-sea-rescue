--!strict
-- Ops/Grading: step grades from metrics, the operation grade, payouts and the NPC cap.
-- Rules: docs/09-rescue-operations.md section 2.4 (points, weights, thresholds) and 4.2 (NPC
-- Silver cap); payouts: docs/03-progression.md section 2. Storm multipliers are NOT applied here:
-- ProgressionService.Award applies them itself.
local Condition = require(script.Parent.Condition)
local Types = require(script.Parent.Types)

type Grade = Types.Grade
type StepDef = Types.StepDef
type Metrics = Types.Metrics

local Grading = {}

Grading.Points = table.freeze({ Gold = 3, Silver = 2, Bronze = 1, Fail = 0 })
Grading.OpThresholds = table.freeze({ Gold = 2.5, Silver = 1.7 }) -- weighted average (tune)

Grading.Payout = table.freeze({
	BaseCash = 550, -- Calm Bay (docs 03 section 2)
	BaseRep = 135,
	GradeMult = table.freeze({ Gold = 1.25, Silver = 1.0, Bronze = 0.75, Fail = 0.5 }),
	CrewBonusPerMember = 0.1, -- human crew only, 1.0 to 1.3
	CrewBonusMax = 0.3,
	ShareWithoutStep = 0.1, -- crew on the op who completed no step: 10% Cash
	Tutorial = table.freeze({
		table.freeze({ cash = 500, rep = 150 }),
		-- 200, not 160: with the Helm exercise (50) a new player has Lifeguard's 400 Rep at the
		-- ~10 min certification without needing a lucky daily (tests/NewPlayerPace.spec.luau)
		table.freeze({ cash = 600, rep = 200 }),
		table.freeze({ cash = 600, rep = 160 }),
	}),
	BigCasualtyShare = 0.3, -- x zone base, to the player who hands the casualty over
	BigBonusCash = 2.5, -- completion bonus x zone base, scaled by share saved
	BigBonusRep = 1.5,
	OscBonus = 0.2,
})

local NPC_CAP: Grade = Types.Rules.NpcGradeCap :: any
local STUB_CAP: Grade = Types.Rules.StubGradeCap :: any

local ORDER: { [string]: number } = { Gold = 3, Silver = 2, Bronze = 1, Fail = 0 }

function Grading.worse(a: Grade, b: Grade): Grade
	return if ORDER[a] <= ORDER[b] then a else b
end

function Grading.cap(grade: Grade, cap: Grade): Grade
	return Grading.worse(grade, cap)
end

local function num(v: any): number?
	if type(v) == "number" and v == v then
		return v
	elseif type(v) == "boolean" then
		return if v then 1 else 0
	end
	return nil
end

-- Grade of one band. A missing metric grades Bronze (the server cannot credit what it can't see).
function Grading.bandGrade(band: Types.GradeBand, metrics: Metrics): Grade
	local v = num(metrics[band.metric])
	if v == nil then
		return "Bronze"
	end
	if band.higherIsBetter then
		if v >= band.gold then
			return "Gold"
		elseif v >= band.silver then
			return "Silver"
		elseif v >= band.bronze then
			return "Bronze"
		end
		return "Fail"
	end
	if v <= band.gold then
		return "Gold"
	elseif v <= band.silver then
		return "Silver"
	elseif v <= band.bronze then
		return "Bronze"
	end
	return "Fail"
end

-- Step grade: the worst band. `only` restricts grading to those metric names (stub results are
-- graded on the server-owned metrics alone). No bands (or none selected): Silver.
function Grading.stepGrade(step: StepDef, metrics: Metrics, only: { string }?): Grade
	local grade: Grade = "Gold"
	local any = false
	for _, band in step.gradeBands do
		if not only or table.find(only, band.metric) then
			any = true
			grade = Grading.worse(grade, Grading.bandGrade(band, metrics))
		end
	end
	return if any then grade else "Silver"
end

-- Final grade of a step result, with the caps applied.
--   npc: done by an NPC crewmate (Silver at most; NPCs follow the book, so never below Silver)
--   stub: the default stub mechanic (Silver at most, graded on server metrics only)
function Grading.resolveStep(
	step: StepDef,
	metrics: Metrics,
	opts: { npc: boolean?, stub: boolean? }?
): Grade
	local o: { npc: boolean?, stub: boolean? } = opts or {}
	if o.npc then
		return NPC_CAP
	end
	if o.stub then
		local only: { string } = step.serverMetrics or {}
		local g: Grade = Grading.stepGrade(step, metrics, only) :: any
		return (Grading.cap(g, STUB_CAP) :: any) :: Grade
	end
	return Grading.stepGrade(step, metrics)
end

-- Grade of the condition at handover (docs 09 section 5.1 step 9).
function Grading.conditionGrade(value: number): Grade
	local band = Condition.band(value)
	return if band == "Stable"
		then "Gold"
		elseif band == "Concern" then "Silver"
		elseif band == "Serious" then "Bronze"
		else "Fail"
end

export type ScoredStep = { grade: Grade, weight: number }

function Grading.weightedAverage(steps: { ScoredStep }): number
	local sum, w = 0, 0
	for _, s in steps do
		sum += Grading.Points[s.grade] * s.weight
		w += s.weight
	end
	return if w > 0 then sum / w else 0
end

-- Operation grade: weighted average >= 2.5 Gold, >= 1.7 Silver, else Bronze.
function Grading.operationGrade(steps: { ScoredStep }): Grade
	local avg = Grading.weightedAverage(steps)
	if avg >= Grading.OpThresholds.Gold then
		return "Gold"
	elseif avg >= Grading.OpThresholds.Silver then
		return "Silver"
	end
	return "Bronze"
end

function Grading.crewMultiplier(humanCrew: number): number
	local P = Grading.Payout
	local extra = math.max(math.floor(humanCrew) - 1, 0)
	return 1 + math.min(extra * P.CrewBonusPerMember, P.CrewBonusMax)
end

export type Reward = { cash: number, rep: number }

local function round(x: number): number
	return math.floor(x + 0.5)
end

-- Payout for one paid player on a standard operation. tutorialIndex = operations the player
-- finished before this one (0 = first); the tutorial chain pays fixed amounts.
function Grading.payout(
	opWeight: number,
	grade: Grade,
	humanCrew: number?,
	tutorialIndex: number?
): Reward
	local P = Grading.Payout
	local crew = Grading.crewMultiplier(humanCrew or 1)
	local tut = if tutorialIndex then P.Tutorial[tutorialIndex + 1] else nil
	if tut then
		return { cash = round(tut.cash * crew), rep = round(tut.rep * crew) }
	end
	local m = opWeight * P.GradeMult[grade] * crew
	return { cash = round(P.BaseCash * m), rep = round(P.BaseRep * m) }
end

-- Takeover payout (2026-10-21, user: "do not give the player points/cash for failing"): nothing for
-- a casualty someone else picked up. On a call with several casualties only the ones the player
-- brought home pay, each its share of a Bronze payout.
function Grading.takeoverPayout(
	opWeight: number,
	saved: number,
	total: number,
	humanCrew: number?
): Reward
	if saved <= 0 or total <= 0 then
		return { cash = 0, rep = 0 }
	end
	local full = Grading.payout(opWeight, "Bronze", humanCrew)
	local share = math.min(saved / total, 1)
	return { cash = round(full.cash * share), rep = round(full.rep * share) }
end

-- Crew member on the operation who completed no step: 10% Cash, no Rep.
function Grading.shareWithoutStep(opWeight: number): Reward
	return {
		cash = round(Grading.Payout.BaseCash * opWeight * Grading.Payout.ShareWithoutStep),
		rep = 0,
	}
end

-- Big call: per casualty handed over, to the player who hands it over.
function Grading.bigCasualtyPay(): Reward
	local P = Grading.Payout
	return {
		cash = round(P.BaseCash * P.BigCasualtyShare),
		rep = round(P.BaseRep * P.BigCasualtyShare),
	}
end

-- Big call: completion bonus for every player who completed a step, scaled by share saved.
function Grading.bigCompletionBonus(saved: number, total: number, isOsc: boolean?): Reward
	local P = Grading.Payout
	local share = if total > 0 then math.clamp(saved / total, 0, 1) else 0
	local osc = if isOsc then 1 + P.OscBonus else 1
	return {
		cash = round(P.BaseCash * P.BigBonusCash * share * osc),
		rep = round(P.BaseRep * P.BigBonusRep * share * osc),
	}
end

-- The weakest step (lowest points, ties: highest weight, then earliest) for the debrief tip.
function Grading.weakest(steps: { ScoredStep }): number?
	local best: number? = nil
	for i, s in steps do
		local b = best
		if b == nil then
			best = i
		else
			local cur = steps[b]
			local p, q = Grading.Points[s.grade], Grading.Points[cur.grade]
			if p < q or (p == q and s.weight > cur.weight) then
				best = i
			end
		end
	end
	return best
end

return Grading
