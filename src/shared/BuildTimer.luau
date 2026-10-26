--!strict
-- BuildTimer (docs/24 B): every build takes time. Base work comes from the Cash price (decor is a flat 8 s);
-- Builders cut time instead of Cash: rate = 1 + 0.35 * units, units = RARITY_MULT over the island's Builders
-- (rarest first, at most 10). The island keeps its two base crew, so even 0 Builders build at rate 1. Pure
-- (tests/BuildTimer.spec.luau); DockService saves progress with it and the build tablet shows its time left.
local WorkerRules = require(script.Parent:WaitForChild("WorkerRules"))

local B = {}

B.MIN, B.MAX = 15, 600 -- seconds of one-crew work
B.SCALE, B.POW = 20, 0.65
B.DECOR = 8
B.PER = 0.35 -- rate per Builder unit
B.BUILDERS = 10 -- the most Builders a site takes (the best rarities)

-- Seconds of one-crew work for a building bought at `cash`; decor is flat.
function B.work(cash: number, decor: boolean?): number
	if decor then
		return B.DECOR
	end
	local value = math.max(0, cash or 0)
	return math.clamp(B.SCALE * (value / 1000) ^ B.POW, B.MIN, B.MAX)
end

-- The island's Builders at a site: data.workers indices, rarest first, at most BUILDERS.
function B.builders(workers: { WorkerRules.Worker }): { number }
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
	while #out > B.BUILDERS do
		table.remove(out)
	end
	return out
end

-- Sum of RARITY_MULT over those Builders.
function B.units(workers: { WorkerRules.Worker }): number
	local units = 0
	for _, i in B.builders(workers) do
		units += WorkerRules.RARITY_MULT[workers[i].rarity] or 1
	end
	return units
end

function B.rate(units: number): number
	return 1 + B.PER * math.max(0, units or 0)
end

function B.rateOf(workers: { WorkerRules.Worker }): number
	return B.rate(B.units(workers))
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
