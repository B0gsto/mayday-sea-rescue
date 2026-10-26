--!strict
-- WorkerRules (docs/23 (o), WP-26): rescued people become your workers. Pure (tests/WorkerRules.spec.luau); the
-- server (WorkerService), the build tablet and the Crew panel agree through it.
-- On pick-up a survivor rolls a category and a rarity (roll(seed): a deterministic server roll, never Robux).
-- Delivered home they join data.workers ({ category, rarity, name }), at most CAP. Each category works at its
-- building (DockConfig.Buildings `worker`); a built one has slots(owned) places, the best rarity first; the rest
-- idle on the jetty. Effects come from the assigned workers only, each counting RARITY_MULT[rarity] units.
local DockConfig = require(script.Parent:WaitForChild("Config"):WaitForChild("DockConfig"))

export type Worker = { category: string, rarity: number, name: string }
export type Effects = {
	gatherPerMin: number, -- Cash a minute while you play
	rescuePerTrip: number, -- Cash per NPC rescue boat trip (0: no boat)
	boatScale: number, -- Boat to me cooldown x this
	craftSpeed: number, -- your craft's SpeedMultiplier
	payBonus: number, -- call pay x (1 + this)
	rescuePeriod: number, -- s between NPC rescue boat trips (SkillRules Rescuer -15%)
	recruitChance: number, -- a trip brings home a new worker this often
	offlineRate: number, -- share of the gather/trip rate paid while away
}
-- SkillRules.effects totals: the skill tree's deltas the effects math reads (nil/0 = no skills).
export type Skill = {
	gatherMult: number?,
	tripPayMult: number?,
	tripScale: number?,
	recruitChance: number?,
	offlineRate: number?,
	speedCapAdd: number?,
	boatCapAdd: number?,
	medicCapAdd: number?,
	medicPerUnit: number?,
}

local W = {}

W.CATEGORIES = { "Builder", "Gatherer", "Rescuer", "Mechanic", "Medic" }
W.RARITY_WEIGHTS = { 80, 17, 3 } -- common / rare / legendary, % -- tune
W.RARITY_MULT = { 1, 1.5, 2.5 }
W.CAP = 30 -- workers kept (full in ~1.3 h of play); past it see admit -- tune
W.SLOTS = 3 -- per worker building -- tune
W.STATION_SLOTS = 2 -- more per building once the Station stands (the island's top tier) -- tune

W.GATHER_PER = 3 -- Gatherer: Cash a minute per unit -- tune
W.RESCUE_PERIOD = 300 -- s between NPC rescue boat trips -- tune
W.RESCUE_PER = 40 -- Rescuer: Cash per trip per unit -- tune
W.RESCUE_RECRUIT = 0.1 -- a trip brings home a new worker this often -- tune
W.BOAT_PER, W.BOAT_CAP = 0.1, 0.5 -- Mechanic: Boat to me cooldown -10% per unit, cap -50%
W.SPEED_PER, W.SPEED_CAP = 0.03, 0.15 -- Mechanic: craft top speed +3% per unit, cap +15%
W.PAY_PER, W.PAY_CAP = 0.03, 0.2 -- Medic: call pay +3% per unit, cap +20%
W.OFFLINE_RATE = 0.15 -- Gatherers and Rescuers earn this share while you are away (0.1 of the old 2 Cash/min read as worthless, playtest 2; 0.3 outearned play at the 2026-10-26 rates) -- tune
W.OFFLINE_CAP = 2 * 3600 -- s

local NAMES = {
	"Sam",
	"Ava",
	"Leo",
	"Mia",
	"Finn",
	"Isla",
	"Owen",
	"Ruby",
	"Theo",
	"Nell",
	"Jack",
	"Erin",
	"Kai",
	"Lola",
	"Ben",
	"Cora",
	"Max",
	"Ivy",
	"Rory",
	"Tess",
	"Alfie",
	"Maya",
	"Noah",
	"Elsie",
	"Ned",
	"Skye",
	"Ollie",
	"Rosa",
	"Hugo",
	"Wren",
}

-- The category's building key (DockConfig.Buildings with `worker` = category), nil for an unknown one.
function W.buildingOf(category: string): string?
	for key, b in DockConfig.Buildings do
		if b.worker == category then
			return key
		end
	end
	return nil
end

-- A tiny LCG step (exact on doubles): the next state and a 0..1 value.
local function step(state: number): (number, number)
	local s = (state * 48271) % 2147483647
	return s, s / 2147483647
end

-- The survivor's category, rarity (1..3 stars) and name from a seed (the server picks the seed). `rareAdd` is
-- the Crew branch's rare-chance bonus: it moves that many percentage points from common to rare.
function W.roll(seed: number, rareAdd: number?): (string, number, string)
	local s = math.floor(math.abs(seed)) % 2147483646 + 1
	local a, b
	s, a = step(s)
	s, b = step(s)
	local _, c = step(s)
	local category = W.CATEGORIES[1 + math.floor(a * #W.CATEGORIES) % #W.CATEGORIES]
	local bonus = math.clamp(rareAdd or 0, 0, 0.5) * 100
	local pick, rarity = b * 100, 1
	for r, weight in W.RARITY_WEIGHTS do
		if r == 1 then
			weight -= bonus
		elseif r == 2 then
			weight += bonus
		end
		if pick < weight then
			rarity = r
			break
		end
		pick -= weight
	end
	return category, rarity, NAMES[1 + math.floor(c * #NAMES) % #NAMES]
end

-- A new worker joins `workers`: appended under the cap; at the cap they take the place of the first worker of
-- the lowest rarity when they are rarer (that one leaves), else they don't stay (the call's Cash is all).
-- Returns the index they went to, or nil. `cap` is W.CAP + the Crew branch's workerCapAdd.
function W.admit(workers: { Worker }, w: Worker, cap: number?): number?
	if #workers < (cap or W.CAP) then
		table.insert(workers, w)
		return #workers
	end
	local worst = 1
	for i, other in workers do
		if other.rarity < workers[worst].rarity then
			worst = i
		end
	end
	if w.rarity <= workers[worst].rarity then
		return nil
	end
	workers[worst] = w
	return worst
end

-- Places in each built worker building (extra: SkillRules' Gatherer slot).
function W.slots(owned: { [string]: boolean }, extra: number?): number
	return W.SLOTS + (if owned.Station then W.STATION_SLOTS else 0) + (extra or 0)
end

-- Where each worker goes: place[i] = their slot (1..slots) at their category's building, nil = idle on the
-- jetty. The best rarity fills a building first; ties keep the earlier rescue.
function W.assign(
	workers: { Worker },
	owned: { [string]: boolean },
	extraSlots: { [string]: number }?
): { [number]: number }
	local place = {}
	local base = W.slots(owned)
	for _, category in W.CATEGORIES do
		local key = W.buildingOf(category)
		if key and owned[key] then
			local slots = base + (if extraSlots then extraSlots[category] or 0 else 0)
			local mine = {}
			for i, w in workers do
				if w.category == category then
					table.insert(mine, i)
				end
			end
			table.sort(mine, function(x, y)
				local rx, ry = workers[x].rarity, workers[y].rarity
				return if rx ~= ry then rx > ry else x < y
			end)
			for n = 1, math.min(slots, #mine) do
				place[mine[n]] = n
			end
		end
	end
	return place
end

-- Rarity-weighted units of the assigned workers, per category.
function W.units(
	workers: { Worker },
	owned: { [string]: boolean },
	extraSlots: { [string]: number }?
): { [string]: number }
	local out = {}
	for _, category in W.CATEGORIES do
		out[category] = 0
	end
	for i in W.assign(workers, owned, extraSlots) do
		local w = workers[i]
		out[w.category] += W.RARITY_MULT[w.rarity] or 1
	end
	return out
end

function W.effects(units: { [string]: number }, skill: Skill?): Effects
	local s: Skill = skill or {}
	local u = function(c: string): number
		return units[c] or 0
	end
	local speedCap = W.SPEED_CAP + (s.speedCapAdd or 0)
	local boatCap = W.BOAT_CAP + (s.boatCapAdd or 0)
	local payCap = W.PAY_CAP + (s.medicCapAdd or 0)
	local payPer = W.PAY_PER + (s.medicPerUnit or 0)
	return {
		gatherPerMin = u("Gatherer") * W.GATHER_PER * (1 + (s.gatherMult or 0)),
		rescuePerTrip = u("Rescuer") * W.RESCUE_PER * (1 + (s.tripPayMult or 0)),
		boatScale = 1 - math.min(u("Mechanic") * W.BOAT_PER, boatCap),
		craftSpeed = 1 + math.min(u("Mechanic") * W.SPEED_PER, speedCap),
		payBonus = math.min(u("Medic") * payPer, payCap),
		rescuePeriod = W.RESCUE_PERIOD * (1 - math.clamp(s.tripScale or 0, 0, 0.9)),
		recruitChance = math.clamp(W.RESCUE_RECRUIT + (s.recruitChance or 0), 0, 1),
		offlineRate = W.OFFLINE_RATE + (s.offlineRate or 0),
	}
end

-- Cash earned while away `seconds` (Gatherers + Rescuers at OFFLINE_RATE, capped at OFFLINE_CAP).
function W.offlinePay(fx: Effects, seconds: number): number
	local minutes = math.clamp(seconds, 0, W.OFFLINE_CAP) / 60
	local perMin = fx.gatherPerMin + fx.rescuePerTrip * 60 / (fx.rescuePeriod or W.RESCUE_PERIOD)
	return math.floor(perMin * minutes * (fx.offlineRate or W.OFFLINE_RATE))
end

-- A saved worker list from anything (corrupt saves included): known categories, rarity 1..3, short names,
-- <= cap (W.CAP + the Crew branch's workerCapAdd).
function W.clean(raw: any, cap: number?): { Worker }
	local out = {}
	if type(raw) ~= "table" then
		return out
	end
	for _, w in raw do
		if #out >= (cap or W.CAP) then
			break
		end
		if
			type(w) == "table"
			and table.find(W.CATEGORIES, w.category)
			and type(w.rarity) == "number"
			and type(w.name) == "string"
		then
			table.insert(out, {
				category = w.category,
				rarity = math.clamp(math.floor(w.rarity), 1, #W.RARITY_MULT),
				name = string.sub(w.name, 1, 16),
			})
		end
	end
	return out
end

return W
