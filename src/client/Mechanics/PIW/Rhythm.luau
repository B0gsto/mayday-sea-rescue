--!strict
-- PIW/Rhythm: the two-hand rhythm (docs 09 section 2.7): hauling a line hand over hand, swimming
-- a tow, cranking a net, CPR compressions to a metronome. Pure (Lune-tested).
local Rhythm = {}

export type State = {
	target: number, -- s between taps
	window: number, -- fraction of target either side that still counts as on time
	alternate: boolean, -- hands must alternate (hauling); CPR takes either hand
	last: number?,
	lastHand: string?,
	taps: number,
	good: number,
	fast: number,
	slow: number,
	wrongHand: number,
}

function Rhythm.new(target: number, window: number, alternate: boolean?): State
	return {
		target = target,
		window = window,
		alternate = alternate ~= false,
		last = nil,
		lastHand = nil,
		taps = 0,
		good = 0,
		fast = 0,
		slow = 0,
		wrongHand = 0,
	}
end

-- "first" | "good" | "fast" | "slow" | "hand" (same hand twice while alternating: ignored)
function Rhythm.tap(r: State, hand: string, t: number): string
	if r.alternate and r.lastHand == hand then
		r.wrongHand += 1
		return "hand"
	end
	r.lastHand = hand
	local last = r.last
	r.last = t
	r.taps += 1
	if last == nil then
		return "first"
	end
	local dt = t - last
	if dt < r.target * (1 - r.window) then
		r.fast += 1
		return "fast"
	elseif dt > r.target * (1 + r.window) then
		r.slow += 1
		return "slow"
	end
	r.good += 1
	return "good"
end

-- 0..1: the share of intervals that were on time.
function Rhythm.evenness(r: State): number
	local intervals = r.good + r.fast + r.slow
	if intervals == 0 then
		return 0
	end
	return r.good / intervals
end

-- Metronome: how far (s) a tap at t is from the nearest beat of a metronome started at t0.
function Rhythm.beatError(t: number, t0: number, interval: number): number
	local phase = ((t - t0) / interval) % 1
	return math.min(phase, 1 - phase) * interval
end

-- Drowning CPR (docs 09 section 5.6; verify: Resuscitation Council UK / ERC): 5 rescue breaths
-- first, then 30:2 for an adult, 15:2 for a child (trained rescuers), at 100 to 120 a minute.
export type CprPlan = {
	initialBreaths: number,
	compressions: number,
	breaths: number,
	bpm: number,
	cycles: number,
}

function Rhythm.cprPlan(ageBand: string): CprPlan
	if ageBand == "Child" then
		return { initialBreaths = 5, compressions = 15, breaths = 2, bpm = 110, cycles = 3 }
	end
	return { initialBreaths = 5, compressions = 30, breaths = 2, bpm = 110, cycles = 2 }
end

-- The sequence of prompts: "B" breath, "C" compression.
function Rhythm.cprSequence(plan: CprPlan): { string }
	local seq = {}
	for _ = 1, plan.initialBreaths do
		table.insert(seq, "B")
	end
	for _ = 1, plan.cycles do
		for _ = 1, plan.compressions do
			table.insert(seq, "C")
		end
		for _ = 1, plan.breaths do
			table.insert(seq, "B")
		end
	end
	return seq
end

-- CPR quality 0..1 from compressions on the beat and breaths given in the right place.
function Rhythm.cprQuality(
	onBeat: number,
	compressions: number,
	breathsRight: number,
	breaths: number
): number
	local c = if compressions > 0 then onBeat / compressions else 0
	local b = if breaths > 0 then breathsRight / breaths else 1
	return math.clamp(0.75 * c + 0.25 * b, 0, 1)
end

return Rhythm
