--!strict
-- SpinCinePlan: the spin cinematic's timeline (owner 2026-11-01), pure (tests/SpinCinePlan.spec.luau). Times are
-- seconds from the moment the wheel lands. The rarity ladder climbs Common -> the won rarity, one step per beat
-- (never faster than ~2.8 Hz: docs/26 no strobe); Epic and up get one fake-out (the flare nearly dies, then surges)
-- before the last step; then the tier's payoff, the reveal, and a hold on the prize before the camera returns.
-- `quick` (back-to-back spins): Common..Rare skip the climb and show only the won rarity.
local SpinRules = require(script.Parent.SpinRules)

local SpinCinePlan = {}

SpinCinePlan.SKIP_AFTER = 1 -- seconds into the takeover before a tap skips to the reveal
SpinCinePlan.FIRST = 0.15 -- the first step, just after the wheel stops
SpinCinePlan.GAP = 0.36 -- the first gap; each later one is GAP_GROW longer (the climb slows as it nears the top)
SpinCinePlan.GAP_GROW = 0.06
SpinCinePlan.FAKE = 0.9 -- the fake-out dip before the last step
-- the payoff after the last step, then the hold on the revealed prize
SpinCinePlan.PAYOFF = table.freeze({
	Common = 0.25,
	Uncommon = 0.3,
	Rare = 1.2,
	Epic = 2.4,
	Legendary = 5,
	Mythic = 8,
})
SpinCinePlan.HOLD = table.freeze({
	Common = 0.9,
	Uncommon = 0.7,
	Rare = 1.4,
	Epic = 1.8,
	Legendary = 2.4,
	Mythic = 2.6,
})

export type Step = { rarity: string, at: number }
export type Plan = {
	rarity: string,
	rank: number,
	steps: { Step },
	fake: number?, -- when the fake-out dip starts (Epic+)
	payoff: number, -- after the last step
	reveal: number,
	done: number, -- the camera returns
}

function SpinCinePlan.plan(rarity: string, quick: boolean?): Plan
	local rank = math.max(SpinRules.rank(rarity), 1)
	local name: string = SpinRules.RARITY_ORDER[rank]
	local from = if quick and rank <= 3 then rank else 1
	local steps: { Step } = {}
	local at = SpinCinePlan.FIRST
	local fake: number? = nil
	for i = from, rank do
		if i > from then
			local gap = SpinCinePlan.GAP + SpinCinePlan.GAP_GROW * (i - from - 1)
			if i == rank and rank >= 4 then
				fake = at + gap * 0.5
				gap += SpinCinePlan.FAKE
			end
			at += gap
		end
		table.insert(steps, { rarity = SpinRules.RARITY_ORDER[i] :: string, at = at })
	end
	local reveal = at + SpinCinePlan.PAYOFF[name]
	return {
		rarity = name,
		rank = rank,
		steps = steps,
		fake = fake,
		payoff = at,
		reveal = reveal,
		done = reveal + SpinCinePlan.HOLD[name],
	}
end

return SpinCinePlan
