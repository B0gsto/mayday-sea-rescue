--!strict
-- WorkerRules (docs/23 (o), WP-26; docs/25 E + K1 survivors v2): rescued people become your workers. Pure
-- (tests/WorkerRules.spec.luau); the server (RescueService at spawn, WorkerService), the build tablet and the
-- Crew panel agree through it.
-- A survivor rolls a category, a rarity (Rarity.TIERS 1..6), a trait (Uncommon and up) and, on a Legendary or
-- Mythic roll, a chance at a named special. `roll(seed, opts)`: a deterministic server roll, never Robux; the
-- player's pity counters and owned specials ride in opts so a special never comes twice.
-- Delivered home they join data.workers, at most CAP. Each category works at its building (DockConfig.Buildings
-- `worker`); a built one has slots(owned) places, the best rarity first; the rest idle on the jetty (Haulers work
-- at the Depot, DepotRules). Effects come from the assigned workers only.
local DockConfig = require(script.Parent:WaitForChild("Config"):WaitForChild("DockConfig"))
local Rarity = require(script.Parent:WaitForChild("Rarity"))

export type Worker = {
	category: string,
	rarity: number, -- Rarity.TIERS index: 1 Common .. 6 Mythic
	name: string,
	trait: string, -- "", or one of W.TRAITS
	special: string, -- "", or a W.SPECIALS id
}
-- A special survivor: one per player, only on a Legendary/Mythic roll, from its source (docs/25 E).
export type Special = {
	id: string,
	name: string,
	category: string, -- their K1 category, "Any" = any job
	rarity: number,
	source: string, -- "any", "MermaidLagoon", "Splashdown", "WreckNight"; events not built never match
}
-- The assigned crew, aggregated (W.crew): rarity-weighted units per category (Cheerful applied), the share that
-- works at full rate away (NightOwl, Bolt) and the assigned Lucky workers (better NPC-trip recruits).
export type Crew = {
	units: { [string]: number },
	night: { [string]: number },
	lucky: number,
}
export type Effects = {
	gatherPerMin: number, -- Cash a minute while you play
	rescuePerTrip: number, -- Cash per NPC rescue boat trip (0: no boat)
	boatScale: number, -- Boat to me cooldown x this
	craftSpeed: number, -- your craft's SpeedMultiplier
	payBonus: number, -- call pay x (1 + this)
	rescuePeriod: number, -- s between NPC rescue boat trips (SkillRules Rescuer -15%)
	recruitChance: number, -- a trip brings home a new worker this often
	offlineRate: number, -- share of the gather/trip rate paid while away
	offlinePerMin: number, -- Cash a minute while away (NightOwl and Bolt at full rate)
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
export type Pity = { epic: number, legendary: number }
export type RollOpts = {
	rareAdd: number?,
	source: string?, -- the call's source; "any" (default) also gives the any-source specials
	category: string?, -- forced category (the tutorial's first Builder)
	owned: { [string]: boolean }?, -- special ids this player already has
	pity: Pity?, -- the player's counters: only their own calls pass this
}

local W = {}

W.CATEGORIES = { "Builder", "Hauler", "Gatherer", "Rescuer", "Mechanic", "Medic" }
W.RARITY_WEIGHTS = { 62, 25, 9, 3, 0.9, 0.1 } -- % Common..Mythic, sums to 100 -- tune
W.RARITY_MULT = { 1, 1.25, 1.6, 2.2, 3, 5 } -- work value per rarity -- tune
W.TRAITS = { "Speedy", "Strong", "Lucky", "NightOwl", "Cheerful" }
W.EPIC = 4
W.LEGENDARY = 5
W.PITY_EPIC = 40 -- an Epic or better at least every N survivors the player rescues -- tune
W.PITY_LEGENDARY = 250 -- a Legendary or better at least every N -- tune
W.SPECIAL_CHANCE = 0.25 -- a Legendary/Mythic roll becomes an owned-out special this often -- tune
W.CHEERFUL = 0.05 -- per Cheerful co-worker at the same building -- tune
W.LUCKY_RECRUIT = 0.03 -- per assigned Lucky worker, NPC-trip recruit chance -- tune
W.SPEEDY = 1.3 -- walk and carry speed
W.CARRY_LOAD = 2 -- Strong carries two loads
W.SPECIAL_CARRY = 3 -- Brickbeard and Big Lou carry like x3 Strong
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

-- Named specials (docs/25 E). Nova and Old Bones only come with their events (Splashdown, Wreck Reef at
-- night), so they never roll yet; Pearl only from calls at Mermaid Lagoon.
-- TODO: Dr. Coral promotes 5% of the arrivals she checks one rarity (the name tag pops to the new colour).
W.SPECIALS = {
	{
		id = "Brickbeard",
		name = "Brickbeard",
		category = "Builder",
		rarity = W.LEGENDARY,
		source = "any",
	},
	{ id = "BigLou", name = "Big Lou", category = "Hauler", rarity = W.LEGENDARY, source = "any" },
	{
		id = "CaptainMarlow",
		name = "Captain Marlow",
		category = "Rescuer",
		rarity = W.LEGENDARY,
		source = "any",
	},
	{
		id = "DrCoral",
		name = "Dr. Coral",
		category = "Medic",
		rarity = W.LEGENDARY,
		source = "any",
	},
	{ id = "Bolt", name = "Bolt", category = "Mechanic", rarity = Rarity.MYTHIC, source = "any" },
	{
		id = "Pearl",
		name = "Pearl",
		category = "Gatherer",
		rarity = Rarity.MYTHIC,
		source = "MermaidLagoon",
	},
	{ id = "Nova", name = "Nova", category = "Any", rarity = Rarity.MYTHIC, source = "Splashdown" },
	{
		id = "OldBones",
		name = "Old Bones",
		category = "Any",
		rarity = Rarity.MYTHIC,
		source = "WreckNight",
	},
} :: { Special }
W.specialById = {} :: { [string]: Special }
for _, special in W.SPECIALS do
	W.specialById[special.id] = special
end

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

-- A plain survivor name, picked by `n` (a special that can't join twice takes one of these).
function W.plainName(n: number): string
	return NAMES[1 + math.floor(n) % #NAMES]
end

-- The special ids this crew already has. shortcut: only the workers still aboard count (no Album page yet);
-- a special never leaves (they are Legendary/Mythic, so admit never replaces them), revisit with the Album.
function W.ownedSpecials(workers: { Worker }): { [string]: boolean }
	local owned = {}
	for _, w in workers do
		if type(w.special) == "string" and w.special ~= "" then
			owned[w.special] = true
		end
	end
	return owned
end

-- Loads a survivor carries at once: one, two (Strong), three (Brickbeard, Big Lou).
function W.carryLoads(w: Worker): number
	if w.special == "Brickbeard" or w.special == "BigLou" then
		return W.SPECIAL_CARRY
	elseif w.trait == "Strong" then
		return W.CARRY_LOAD
	end
	return 1
end

-- A tiny LCG step (exact on doubles): the next state and a 0..1 value.
local function step(state: number): (number, number)
	local s = (state * 48271) % 2147483647
	return s, s / 2147483647
end

-- The survivor from a seed (the server picks the seed). `rareAdd` is the Crew branch's rarity luck: it moves
-- that many percentage points from Common to Rare. Pity upgrades the result and updates `opts.pity` in place.
function W.roll(seed: number, opts: RollOpts?): Worker
	local o: RollOpts = opts or {}
	local s = math.floor(math.abs(seed)) % 2147483646 + 1
	local a, b, c, d, e, f
	s, a = step(s)
	s, b = step(s)
	s, c = step(s)
	s, d = step(s)
	s, e = step(s)
	s, f = step(s)
	local category = o.category or W.CATEGORIES[1 + math.floor(a * #W.CATEGORIES) % #W.CATEGORIES]
	local bonus = math.clamp(o.rareAdd or 0, 0, 0.5) * 100
	local pick, rarity = b * 100, 1
	for r, weight in W.RARITY_WEIGHTS do
		if r == 1 then
			weight -= bonus
		elseif r == 3 then
			weight += bonus
		end
		if pick < weight then
			rarity = r
			break
		end
		pick -= weight
	end
	local pity = o.pity
	if pity then
		pity.epic += 1
		pity.legendary += 1
		if rarity < W.EPIC and pity.epic >= W.PITY_EPIC then
			rarity = W.EPIC
		end
		if rarity < W.LEGENDARY and pity.legendary >= W.PITY_LEGENDARY then
			rarity = W.LEGENDARY
		end
		if rarity >= W.EPIC then
			pity.epic = 0
		end
		if rarity >= W.LEGENDARY then
			pity.legendary = 0
		end
	end
	local trait = if rarity >= 2 then W.TRAITS[1 + math.floor(d * #W.TRAITS) % #W.TRAITS] else ""
	local special = ""
	local name = NAMES[1 + math.floor(c * #NAMES) % #NAMES]
	if rarity >= W.LEGENDARY then
		local source = o.source or "any"
		local candidates = {}
		for _, sp in W.SPECIALS do
			if
				sp.rarity == rarity
				and (sp.category == category or sp.category == "Any")
				and (sp.source == "any" or sp.source == source)
				and not (o.owned and o.owned[sp.id])
			then
				table.insert(candidates, sp)
			end
		end
		if #candidates > 0 and e < W.SPECIAL_CHANCE then
			local sp = candidates[1 + math.floor(f * #candidates) % #candidates]
			special, name = sp.id, sp.name
		end
	end
	return { category = category, rarity = rarity, name = name, trait = trait, special = special }
end

-- A new worker joins `workers`: appended under the cap; at the cap they take the place of the first worker of
-- the lowest rarity when they are rarer (that one leaves), else they don't stay (the call's Cash is all).
-- Returns the index they went to, or nil. `cap` is W.CAP + the Crew branch's workerCapAdd.
function W.admit(workers: { Worker }, w: Worker, cap: number?): number?
	if #workers < (cap or W.CAP) then
		table.insert(workers, w)
		return #workers
	end
	local worst: number? = nil -- a special never leaves (ownedSpecials counts the crew)
	for i, other in workers do
		if (other.special or "") == "" and (not worst or other.rarity < workers[worst].rarity) then
			worst = i
		end
	end
	if not worst or w.rarity <= workers[worst].rarity then
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

-- The assigned crew: rarity-weighted units per category, Cheerful +5% per co-worker at the same building,
-- Captain Marlow x2 (his boat pays double), and the NightOwl/Bolt and Lucky shares effects reads.
function W.crew(
	workers: { Worker },
	owned: { [string]: boolean },
	extraSlots: { [string]: number }?
): Crew
	local out: Crew = { units = {}, night = {}, lucky = 0 }
	for _, category in W.CATEGORIES do
		out.units[category] = 0
		out.night[category] = 0
	end
	local place = W.assign(workers, owned, extraSlots)
	local cheerful: { [string]: number } = {}
	for i in place do
		local w = workers[i]
		if w.trait == "Cheerful" then
			cheerful[w.category] = (cheerful[w.category] or 0) + 1
		end
	end
	for i in place do
		local w = workers[i]
		local value = W.RARITY_MULT[w.rarity] or 1
		if w.special == "CaptainMarlow" then
			value *= 2
		end
		if w.trait ~= "Cheerful" then
			value *= 1 + W.CHEERFUL * (cheerful[w.category] or 0)
		end
		out.units[w.category] += value
		if w.trait == "NightOwl" or w.special == "Bolt" then
			out.night[w.category] += value
		end
		if w.trait == "Lucky" then
			out.lucky += 1
		end
	end
	return out
end

function W.effects(crew: Crew, skill: Skill?): Effects
	local s: Skill = skill or {}
	local u = function(c: string): number
		return crew.units[c] or 0
	end
	local n = function(c: string): number
		return crew.night[c] or 0
	end
	local speedCap = W.SPEED_CAP + (s.speedCapAdd or 0)
	local boatCap = W.BOAT_CAP + (s.boatCapAdd or 0)
	local payCap = W.PAY_CAP + (s.medicCapAdd or 0)
	local payPer = W.PAY_PER + (s.medicPerUnit or 0)
	local gatherMult = 1 + (s.gatherMult or 0)
	local tripMult = 1 + (s.tripPayMult or 0)
	local rescuePeriod = W.RESCUE_PERIOD * (1 - math.clamp(s.tripScale or 0, 0, 0.9))
	local offlineRate = W.OFFLINE_RATE + (s.offlineRate or 0)
	local gatherPerMin = u("Gatherer") * W.GATHER_PER * gatherMult
	local rescuePerTrip = u("Rescuer") * W.RESCUE_PER * tripMult
	local awayPerMin = gatherPerMin + rescuePerTrip * 60 / rescuePeriod
	local nightPerMin = n("Gatherer") * W.GATHER_PER * gatherMult
		+ n("Rescuer") * W.RESCUE_PER * tripMult * 60 / rescuePeriod
	return {
		gatherPerMin = gatherPerMin,
		rescuePerTrip = rescuePerTrip,
		boatScale = 1 - math.min(u("Mechanic") * W.BOAT_PER, boatCap),
		craftSpeed = 1 + math.min(u("Mechanic") * W.SPEED_PER, speedCap),
		payBonus = math.min(u("Medic") * payPer, payCap),
		rescuePeriod = rescuePeriod,
		recruitChance = math.clamp(
			W.RESCUE_RECRUIT + (s.recruitChance or 0) + crew.lucky * W.LUCKY_RECRUIT,
			0,
			1
		),
		offlineRate = offlineRate,
		-- NightOwl and Bolt pay full rate away; everyone else pays offlineRate
		offlinePerMin = awayPerMin * offlineRate + nightPerMin * (1 - math.min(offlineRate, 1)),
	}
end

-- Cash earned while away `seconds` (Gatherers + Rescuers; NightOwl and Bolt at full rate, capped).
function W.offlinePay(fx: Effects, seconds: number): number
	local minutes = math.clamp(seconds, 0, W.OFFLINE_CAP) / 60
	return math.floor(fx.offlinePerMin * minutes)
end

-- A saved worker list from anything (corrupt saves included): known categories, rarity 1..6, short names,
-- known traits and specials, <= cap (W.CAP + the Crew branch's workerCapAdd). `legacy` maps the old three
-- rarities (1 / 2 / 3 = common / rare / legendary) onto 1 / 3 / 5 and gives no trait.
function W.clean(raw: any, cap: number?, legacy: boolean?): { Worker }
	local oldRarity = { 1, 3, 5 }
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
			local rarity = math.clamp(math.floor(w.rarity), 1, Rarity.MYTHIC)
			if legacy then
				rarity = oldRarity[rarity] or rarity
			end
			local trait = if rarity >= 2
					and type(w.trait) == "string"
					and table.find(W.TRAITS, w.trait)
				then w.trait
				else ""
			local special = if type(w.special) == "string" then w.special else ""
			local sp = W.specialById[special]
			if
				not sp
				or sp.rarity ~= rarity
				or (sp.category ~= "Any" and sp.category ~= w.category)
			then
				special = ""
			end
			table.insert(out, {
				category = w.category,
				rarity = rarity,
				name = string.sub(w.name, 1, 16),
				trait = trait,
				special = special,
			})
		end
	end
	return out
end

return W
