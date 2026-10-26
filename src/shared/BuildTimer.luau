--!strict
-- BuildTimer (docs/24 B): every build takes time. Base work comes from the Cash price (decor is a flat 8 s);
-- Builders cut time instead of Cash: rate = (1 + PER * units) * mult, units = RARITY_MULT over the island's
-- Builders (rarest first, at most BUILDERS: a full crew about halves a build, docs/23 (r)). The island keeps
-- its BASE_CREW, so even 0 Builders build at rate 1. The skill tree raises the Builder count, the rate and the
-- base crew; readers pass those totals in. Pure
-- (tests/BuildTimer.spec.luau); DockService saves progress with it and the build tablet shows its time left.
local WorkerRules = require(script.Parent:WaitForChild("WorkerRules"))

local B = {}

B.MIN, B.MAX = 20, 600 -- seconds of one-crew work
B.SCALE, B.POW = 20, 0.9 -- 1k 20 s, 2.5k 45 s, 10k 2:39, 40k 9:15 of one-crew work -- tune
B.DECOR = 8
B.PER = 0.15 -- rate per Builder unit -- tune
B.BUILDERS = 5 -- the most Builders a site takes (the best rarities): 5 commons x1.75, a late rarer crew ~x2.2 -- tune
B.BASE_CREW = 2 -- the hard-hat NPCs every island builds with (docs/24 B); SkillRules' baseCrew adds one -- tune
export type Skill = { max: number?, mult: number?, crew: number? } -- skill tree totals (nil = no change)

-- Seconds of one-crew work for a building bought at `cash`; decor is flat.
function B.work(cash: number, decor: boolean?): number
	if decor then
		return B.DECOR
	end
	local value = math.max(0, cash or 0)
	return math.clamp(B.SCALE * (value / 1000) ^ B.POW, B.MIN, B.MAX)
end

-- The island's Builders at a site: data.workers indices, rarest first, at most `max` (default BUILDERS).
function B.builders(workers: { WorkerRules.Worker }, max: number?): { number }
	local out = {}
	for i, w in workers do
		if w.category == "Builder" then
			table.insert(out, i)
		end
	end
	table.sort(out, function(a: number, b: number): boolean
		local ra, rb = workers[a].rarity, workers[b].rarity
		return if ra ~= rb then ra > rb else a < b
	end)
	while #out > (max or B.BUILDERS) do
		table.remove(out)
	end
	return out
end

-- Sum of RARITY_MULT over those Builders.
function B.units(workers: { WorkerRules.Worker }, max: number?): number
	local units = 0
	for _, i in B.builders(workers, max) do
		units += WorkerRules.RARITY_MULT[workers[i].rarity] or 1
	end
	return units
end

-- `mult` is the Builder branch's rate bonus, `crew` extra base-crew units (one common Builder each).
function B.rate(units: number, mult: number?, crew: number?): number
	return (1 + B.PER * (math.max(0, units or 0) + math.max(0, crew or 0))) * (mult or 1)
end

function B.rateOf(workers: { WorkerRules.Worker }, skill: Skill?): number
	local s: Skill = skill or {}
	return B.rate(B.units(workers, s.max), s.mult, s.crew)
end

-- Progress after `dt` seconds at a crew rate (progress is 0..1 of `work`; omit for a rate per second).
function B.advance(progress: number, rate: number, dt: number, work: number?): number
	local span = math.max(work or 1, 1e-3)
	return math.clamp(progress + rate * math.max(0, dt) / span, 0, 1)
end

-- Seconds until the site finishes at `rate` (0 when done).
function B.timeLeft(progress: number, rate: number, work: number): number
	return math.max(0, (1 - math.clamp(progress, 0, 1)) * work / math.max(rate, 1e-3))
end

-- The Robux "Finish now" tier for a site's current time left (docs/24 B): 1 <= 60 s, 2 <= 300 s, 3 longer.
function B.finishTier(secondsLeft: number): number
	if secondsLeft <= 60 then
		return 1
	elseif secondsLeft <= 300 then
		return 2
	end
	return 3
end

-- "m:ss" for a board or the tablet.
function B.text(seconds: number): string
	local s = math.max(0, math.floor(seconds + 0.5))
	return `{math.floor(s / 60)}:{string.format("%02d", s % 60)}`
end

return B
