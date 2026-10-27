--!strict
-- DepotRules (docs/25 D, K4): bricks are a real limit. A build needs loadsFor(work) loads; the island's Builders
-- carry them from the Depot (crewRate, in BuildTimer units: Strong and Brickbeard carry more, the Strong Backs node
-- makes every Builder carry 2), the supply barge moors every BARGE_PERIOD s and puts bargeLoads in the Depot
-- (the barge crew's drop, plus the assigned Haulers; Depot Lv2 doubles it, Hand Carts add a share). Build speed =
-- min(carry, stock + refill). With no Depot the quay holds one drop, so builds run on the barge crew alone and
-- are never blocked forever. Pure (tests/DepotRules.spec.luau); DockService and tests/Pacing.spec.luau both step
-- the same `advance`, which also catches up time away in one call.
local BuildTimer = require(script.Parent:WaitForChild("BuildTimer"))
local WorkerRules = require(script.Parent:WaitForChild("WorkerRules"))

local D = {}

D.CAPS = { 20, 40, 80 } -- loads the Depot holds per level
D.BARGE_PERIOD = 60 -- s between moorings
D.CREW_DROP = 2 -- loads the barge crew drops itself (no Haulers) -- tune
D.HAUL_PER = 0.5 -- loads per mooring per Hauler unit (rarity value x carry loads) -- tune
D.LEVEL_MULT = { 1, 2, 2 } -- the barge drop per Depot level (Lv2 doubles it; Lv3 adds room) -- tune
D.LOAD_WORK = 10 -- s of one-crew work per load
D.START = 6 -- loads on the quay in a new save: the Rescue Hut, Workshop and Depot never wait -- tune

export type State = {
	stock: number, -- loads in the Depot (on the quay with no Depot)
	progress: number?, -- the running site's progress 0..1, nil = no site
	next: number, -- s until the next mooring (0 < next <= BARGE_PERIOD)
}
export type Params = {
	cap: number, -- cap(depotLevel)
	drop: number, -- bargeLoads(...)
	carry: number?, -- loads a second the Builders carry (carrySpeed), with a site
	loads: number?, -- loadsFor(work), with a site
}
export type Skill = {
	max: number?, -- BuildTimer.Skill
	mult: number?,
	crew: number?,
	carry: number?, -- SkillRules buildersCarry (Strong Backs: 2)
}

function D.cap(depotLevel: number?): number
	return D.CAPS[depotLevel or 0] or 0
end

-- Loads one mooring puts in the Depot. `refill` is SkillRules' depotRefill share (Hand Carts +50%).
function D.bargeLoads(depotLevel: number?, haulerUnits: number?, refill: number?): number
	local level = math.clamp(depotLevel or 0, 0, #D.LEVEL_MULT)
	local mult = if level > 0 then D.LEVEL_MULT[level] else 1
	return (D.CREW_DROP + D.HAUL_PER * math.max(0, haulerUnits or 0))
		* mult
		* (1 + math.max(0, refill or 0))
end

function D.loadsFor(work: number): number
	return math.max(1, math.ceil(work / D.LOAD_WORK))
end

-- The assigned Haulers (WorkerRules.assign at the Depot): rarity value x the loads each carries (Strong 2,
-- Big Lou 3).
function D.haulUnits(
	workers: { WorkerRules.Worker },
	owned: { [string]: boolean },
	extraSlots: { [string]: number }?
): number
	local units = 0
	for i in WorkerRules.assign(workers, owned, extraSlots) do
		local w = workers[i]
		if w.category == "Hauler" then
			units += (WorkerRules.RARITY_MULT[w.rarity] or 1) * WorkerRules.carryLoads(w)
		end
	end
	return units
end

-- The Builders' carry as a BuildTimer crew rate: every Builder's units count once per load they carry.
-- With carry 1 and no Strong Builders this is BuildTimer.rateOf.
function D.crewRate(workers: { WorkerRules.Worker }, skill: Skill?): number
	local s: Skill = skill or {}
	local all = math.max(1, s.carry or 1)
	local units = 0
	for _, i in BuildTimer.builders(workers, s.max) do
		local w = workers[i]
		units += (WorkerRules.RARITY_MULT[w.rarity] or 1) * math.max(WorkerRules.carryLoads(w), all)
	end
	return BuildTimer.rate(units, s.mult, (s.crew or 0) * all)
end

-- Loads a second a crew at `rate` carries to a site of `work` seconds (a full Depot: the BuildTimer time).
function D.carrySpeed(rate: number, work: number): number
	return rate * D.loadsFor(work) / math.max(work, 1e-3)
end

-- Steps the Depot and site by `dt` seconds (untilDone: until the site finishes). -> state, s run, s waited.
local function run(s: State, p: Params, dt: number, untilDone: boolean): (State, number, number)
	local stock, progress, nxt = math.max(0, s.stock), s.progress, s.next
	local drop = math.max(p.drop, 1) -- the barge always comes: a site never waits forever
	local hold = math.max(p.cap, drop) -- with no Depot the quay holds one drop
	local loads = math.max(p.loads or 1, 1)
	local carry = math.max(p.carry or 0, 1e-6)
	local elapsed, waited = 0, 0
	while progress and progress < 1 and elapsed < dt do
		local seg = math.min(dt - elapsed, nxt)
		local need = (1 - progress) * loads
		local got = math.min(need, stock, carry * seg)
		stock -= got
		if got >= need - 1e-9 then
			progress = 1
			seg = got / carry -- done mid-segment
		else
			progress += got / loads
			waited += seg - got / carry
		end
		elapsed += seg
		nxt -= seg
		if nxt <= 1e-9 then
			stock = math.max(stock, math.min(stock + drop, hold))
			nxt = D.BARGE_PERIOD
		end
	end
	if not untilDone then
		-- no site (or it finished): the rest only refills, every mooring at once
		local rest = dt - elapsed
		if rest >= nxt then
			local n = 1 + math.floor((rest - nxt) / D.BARGE_PERIOD)
			if stock < hold then
				stock = math.min(stock + n * drop, hold)
			end
			nxt = D.BARGE_PERIOD - (rest - nxt) % D.BARGE_PERIOD
		else
			nxt -= rest
		end
		elapsed = dt
	end
	return { stock = stock, progress = progress, next = nxt }, elapsed, waited
end

-- The Depot and site after `dt` seconds (one server tick, or a whole time away). -> state, s the site waited.
function D.advance(s: State, p: Params, dt: number): (State, number)
	local out, _, waited = run(s, p, math.max(0, dt), false)
	return out, waited
end

-- Seconds until the site finishes from `s`, of which waiting on an empty Depot, and the state then.
function D.timeLeft(s: State, p: Params): (number, number, State)
	local out, elapsed, waited = run(s, p, math.huge, true)
	return elapsed, waited, out
end

-- Seconds to the next mooring at `now` for an island whose barge runs `offset` s late.
function D.nextAt(now: number, offset: number?): number
	return D.BARGE_PERIOD - (now - (offset or 0)) % D.BARGE_PERIOD
end

return D
