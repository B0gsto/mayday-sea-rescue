--!strict
-- GoldenCalls (docs/25 B, E, F): about 1 in 40 calls is golden: a gold pin, more Cash and one survivor who is
-- Epic or better (shown with a gold glow). The Lookout Tower's levels (DockConfig effects GoldCalls15 / GoldCalls2)
-- and the Golden Mayday skill (SkillRules `goldenCalls`) raise the chance. Pure: OperationService rolls the call,
-- RescueService lifts the survivor; clients read the op's `golden` and the survivor's `Golden` attribute.
local DockConfig = require(script.Parent.Parent:WaitForChild("Config"):WaitForChild("DockConfig"))

local GoldenCalls = {}

GoldenCalls.BASE = 1 / 40 -- docs/25 E -- tune
GoldenCalls.MAX_CHANCE = 0.25
GoldenCalls.CASH_MULT = 2 -- a golden call's pay -- tune
GoldenCalls.MIN_RARITY = 4 -- Epic (WorkerRules.EPIC)
-- Lookout Tower level effect -> the chance multiplier from that level on (docs/25 B: x1.5, then x2)
GoldenCalls.LOOKOUT = { GoldCalls15 = 1.5, GoldCalls2 = 2 } :: { [string]: number }

-- The chance multiplier of a Lookout Tower built to `level` (0 = none).
function GoldenCalls.lookoutMult(level: number): number
	local levels = DockConfig.Buildings.LookoutTower.levels
	local mult = 1
	for i = 1, math.min(math.floor(tonumber(level) or 0), #levels) do
		mult = GoldenCalls.LOOKOUT[levels[i].effect or ""] or mult
	end
	return mult
end

-- goldenCalls: the summed SkillRules effect (Golden Mayday = 2, i.e. x2; 0 = not owned).
function GoldenCalls.chance(lookoutLevel: number, goldenCalls: number): number
	local skill = math.max(1, tonumber(goldenCalls) or 0)
	return math.min(
		GoldenCalls.MAX_CHANCE,
		GoldenCalls.BASE * GoldenCalls.lookoutMult(lookoutLevel) * skill
	)
end

-- The golden survivor: raised to Epic (a raised Common gets a trait from `traits` by `pick` 0..1), and the
-- owner's Epic pity counter starts over since this call paid it out. Changes `w` and `pity` in place.
function GoldenCalls.lift(
	w: { rarity: number, trait: string },
	traits: { string },
	pick: number,
	pity: { epic: number }?
)
	if w.rarity < GoldenCalls.MIN_RARITY then
		w.rarity = GoldenCalls.MIN_RARITY
		if w.trait == "" then
			w.trait = traits[1 + math.floor(pick * #traits) % #traits]
		end
	end
	if pity then
		pity.epic = 0
	end
end

return GoldenCalls
