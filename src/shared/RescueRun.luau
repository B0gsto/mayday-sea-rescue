--!strict
-- RescueRun (docs/29 C): the rules of a rescue run and the pick-up boost. Pure, tests/RescueRun.spec.luau.
-- A run counts survivors delivered home in a row; pay reads the multiplier before the delivery counts (the x on the
-- chip when you arrive is the x you get). Server state: RescueRunService.
local RescueRun = {}

RescueRun.WINDOW = 75 -- s after the last pick-up or delivery -- tune
RescueRun.TIERS = { -- best first -- tune
	{ at = 10, mult = 2 },
	{ at = 6, mult = 1.5 },
	{ at = 3, mult = 1.25 },
}
RescueRun.BOOST_SECONDS = 3 -- tune
RescueRun.BOOST_MULT = 1.25 -- top speed -- tune

export type State = { count: number, endsAt: number }

function RescueRun.new(): State
	return { count = 0, endsAt = 0 }
end

function RescueRun.multiplierFor(count: number): number
	for _, tier in RescueRun.TIERS do
		if count >= tier.at then
			return tier.mult
		end
	end
	return 1
end

function RescueRun.current(st: State, now: number): number
	return if now < st.endsAt then RescueRun.multiplierFor(st.count) else 1
end

local function touch(st: State, now: number)
	if now >= st.endsAt then
		st.count = 0
	end
	st.endsAt = now + RescueRun.WINDOW
end

function RescueRun.pickup(st: State, now: number)
	touch(st, now)
end

function RescueRun.delivered(st: State, people: number, now: number)
	touch(st, now)
	st.count += people
end

function RescueRun.finish(st: State)
	st.count, st.endsAt = 0, 0
end

-- The craft's PickupBoostUntil attribute at `now` -> its top speed multiplier.
function RescueRun.boostAt(untilTime: any, now: number): number
	return if type(untilTime) == "number" and now < untilTime then RescueRun.BOOST_MULT else 1
end

return RescueRun
