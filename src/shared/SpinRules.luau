--!strict
-- SpinRules: the pure prize-wheel rules (docs/24 D). No Roblox services; safe in Lune
-- (tests/SpinRules.spec.luau).
--
-- Odds are per rarity in percent. Pity guarantees an Epic or better at least every 10 spins and a
-- Legendary or better at least every 50; the counters are the number of spins since the last such
-- win and are saved in the profile flag. A prize already owned becomes Cash by rarity.
--
-- The saved flag `spin` is a flat table of scalars (ProgressionRules.sanitizeFlag):
--   d = last UTC day a free spin was granted, f = free spins available,
--   e / l = spins since the last Epic+ / Legendary+, r = rescued people already paid out,
--   o = bitmask of owned finish / trail prizes (bit i = PRIZES[i]).
--
-- Free spins: 1 a day plus 1 for every 10 people rescued (docs/24 D); see accrue.
--
-- The wheel draws SEGMENTS in this order; the server picks one of the rolled rarity's segments so
-- the animation always stops on the prize it actually granted.

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"
export type Kind = "cash" | "petVariant" | "finish" | "trail" | "boat"

export type Prize = {
	id: string,
	rarity: Rarity,
	kind: Kind,
	name: string,
	icon: string,
	cash: number?,
	variant: string?,
	option: string?,
	vehicle: string?,
}

export type Pity = { epic: number, legendary: number }
export type State = {
	day: number,
	free: number,
	pity: Pity,
	rescued: number,
	owned: number,
}
export type Result = { prize: Prize, pity: Pity }

local SpinRules = {}

SpinRules.PITY_EPIC = 10
SpinRules.PITY_LEGENDARY = 50
SpinRules.MAX_FREE = 99

local ORDER: { Rarity } = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }
SpinRules.RARITY_ORDER = ORDER

-- odds in percent, the Kit colour the UI / Toast uses, and the Cash an owned duplicate pays
SpinRules.RARITIES = {
	Common = { odds = 50, color = "disabled", cash = 150 },
	Uncommon = { odds = 25, color = "green", cash = 400 },
	Rare = { odds = 15, color = "blue", cash = 1200 },
	Epic = { odds = 7, color = "purple", cash = 3000 },
	Legendary = { odds = 2.5, color = "yellow", cash = 8000 },
	Mythic = { odds = 0.5, color = "pink", cash = 20000 },
} :: { [string]: { odds: number, color: string, cash: number } }

SpinRules.SEGMENTS = {
	"Common",
	"Uncommon",
	"Common",
	"Rare",
	"Common",
	"Uncommon",
	"Epic",
	"Common",
	"Uncommon",
	"Rare",
	"Legendary",
	"Mythic",
} :: { Rarity }

SpinRules.PRIZES = {
	{ id = "CashSmall", rarity = "Common", kind = "cash", name = "Cash", icon = "cash" },
	{ id = "CashBig", rarity = "Uncommon", kind = "cash", name = "Cash", icon = "cash" },
	{
		id = "GoldenPet",
		rarity = "Rare",
		kind = "petVariant",
		name = "Golden Pet",
		icon = "companion",
		variant = "Golden",
	},
	{
		id = "GoldFinish",
		rarity = "Rare",
		kind = "finish",
		name = "Gold Chrome",
		icon = "boat_to_me",
		option = "SpinGold",
	},
	{
		id = "RainbowTrail",
		rarity = "Rare",
		kind = "trail",
		name = "Rainbow Wake",
		icon = "waves",
		option = "SpinRainbow",
	},
	{
		id = "NeonPet",
		rarity = "Epic",
		kind = "petVariant",
		name = "Neon Pet",
		icon = "companion",
		variant = "Neon",
	},
	{
		id = "NeonFinish",
		rarity = "Epic",
		kind = "finish",
		name = "Neon Glow",
		icon = "boat_to_me",
		option = "SpinNeon",
	},
	{
		id = "FireTrail",
		rarity = "Epic",
		kind = "trail",
		name = "Fire Wake",
		icon = "waves",
		option = "SpinFire",
	},
	{
		id = "RainbowPet",
		rarity = "Legendary",
		kind = "petVariant",
		name = "Rainbow Pet",
		icon = "companion",
		variant = "Rainbow",
	},
	{
		id = "LavaFinish",
		rarity = "Legendary",
		kind = "finish",
		name = "Lava",
		icon = "boat_to_me",
		option = "SpinLava",
	},
	{
		id = "StarTrail",
		rarity = "Legendary",
		kind = "trail",
		name = "Star Wake",
		icon = "waves",
		option = "SpinStars",
	},
	{
		id = "GalaxyPet",
		rarity = "Mythic",
		kind = "petVariant",
		name = "Galaxy Pet",
		icon = "companion",
		variant = "Galaxy",
	},
	{
		id = "GalaxyFinish",
		rarity = "Mythic",
		kind = "finish",
		name = "Galaxy",
		icon = "boat_to_me",
		option = "SpinGalaxy",
	},
	{
		id = "GrandBoat",
		rarity = "Mythic",
		kind = "boat",
		name = "Storm Runner",
		icon = "boat_to_me",
		vehicle = "StormRunner",
	},
} :: { Prize }

local byId: { [string]: Prize } = {}
local byRarity: { [string]: { Prize } } = {}
for _, prize in SpinRules.PRIZES do
	byId[prize.id] = prize
	byRarity[prize.rarity] = byRarity[prize.rarity] or {}
	table.insert(byRarity[prize.rarity], prize)
	prize.cash = SpinRules.RARITIES[prize.rarity].cash
end

function SpinRules.prize(id: string): Prize?
	return byId[id]
end

function SpinRules.prizesOf(rarity: Rarity): { Prize }
	return byRarity[rarity] or {}
end

function SpinRules.rank(rarity: string): number
	return table.find(SpinRules.RARITY_ORDER, rarity) or 0
end

-- Sum of every rarity's odds in percent (100 when the table is right).
function SpinRules.oddsSum(): number
	local sum = 0
	for i = 1, #ORDER do
		sum += SpinRules.RARITIES[ORDER[i]].odds
	end
	return sum
end

function SpinRules.cashFor(rarity: string): number
	local row = SpinRules.RARITIES[rarity]
	return if row then row.cash else 0
end

-- An owned duplicate pays this much Cash instead.
function SpinRules.duplicateCash(prize: Prize): number
	return SpinRules.cashFor(prize.rarity)
end

function SpinRules.newState(): State
	return { day = 0, free = 0, pity = { epic = 0, legendary = 0 }, rescued = 0, owned = 0 }
end

function SpinRules.decode(raw: any): State
	local state = SpinRules.newState()
	if type(raw) ~= "table" then
		return state
	end
	state.day = math.max(0, math.floor(tonumber(raw.d) or 0))
	state.free = math.max(0, math.floor(tonumber(raw.f) or 0))
	state.pity.epic = math.max(0, math.floor(tonumber(raw.e) or 0))
	state.pity.legendary = math.max(0, math.floor(tonumber(raw.l) or 0))
	state.rescued = math.max(0, math.floor(tonumber(raw.r) or 0))
	state.owned = math.max(0, math.floor(tonumber(raw.o) or 0))
	return state
end

function SpinRules.encode(state: State): { [string]: any }
	return {
		d = math.max(0, math.floor(state.day)),
		f = math.max(0, math.floor(state.free)),
		e = math.max(0, math.floor(state.pity.epic)),
		l = math.max(0, math.floor(state.pity.legendary)),
		r = math.max(0, math.floor(state.rescued)),
		o = math.max(0, math.floor(state.owned)),
	}
end

-- Grants the free spins that came due: 1 on a new UTC day (not banked for days away) and 1 per 10
-- people rescued since the wheel first saw this profile (no back-pay for rescues made before it
-- shipped). A clock that steps back never re-opens a day. Returns the new state and how many were added.
function SpinRules.accrue(state: State, rescued: number, now: number): (State, number)
	local day = math.max(state.day, math.floor(now / 86400))
	local people = math.max(0, math.floor(rescued))
	local baseline = if state.day == 0 then people else state.rescued
	local added = if day > state.day then 1 else 0
	added += math.max(0, math.floor(people / 10) - math.floor(baseline / 10))
	local nextState: State = {
		day = day,
		free = math.min(state.free + added, math.max(state.free, SpinRules.MAX_FREE)),
		pity = state.pity,
		rescued = math.max(baseline, people),
		owned = state.owned,
	}
	return nextState, added
end

local function pickWeighted(rng: () -> number, rarities: { Rarity }): Rarity
	local total = 0
	for i = 1, #rarities do
		total += SpinRules.RARITIES[rarities[i]].odds
	end
	local roll = rng() * total
	for i = 1, #rarities do
		local rarity: Rarity = rarities[i]
		roll -= SpinRules.RARITIES[rarity].odds
		if roll < 0 then
			return rarity
		end
	end
	return rarities[#rarities]
end

function SpinRules.rollRarity(rng: () -> number): Rarity
	return pickWeighted(rng, SpinRules.RARITY_ORDER)
end

function SpinRules.rollRarityAtLeast(rng: () -> number, floorRarity: Rarity): Rarity
	local floor = SpinRules.rank(floorRarity)
	local pool: { Rarity } = {}
	for i = 1, #ORDER do
		local rarity: Rarity = ORDER[i]
		if SpinRules.rank(rarity) >= floor then
			table.insert(pool, rarity)
		end
	end
	return pickWeighted(rng, pool)
end

local function pickPrize(rng: () -> number, rarity: Rarity): Prize
	local pool = SpinRules.prizesOf(rarity)
	return pool[math.clamp(math.floor(rng() * #pool) + 1, 1, #pool)]
end

-- One roll: the prize and the pity counters after it (Epic+ / Legendary+ gaps reset on a win).
function SpinRules.roll(rng: () -> number, pity: Pity?): Result
	local epics = math.max(0, math.floor(tonumber(pity and pity.epic) or 0))
	local legends = math.max(0, math.floor(tonumber(pity and pity.legendary) or 0))
	local rarity: Rarity
	if legends >= SpinRules.PITY_LEGENDARY - 1 then
		rarity = SpinRules.rollRarityAtLeast(rng, "Legendary")
	elseif epics >= SpinRules.PITY_EPIC - 1 then
		rarity = SpinRules.rollRarityAtLeast(rng, "Epic")
	else
		rarity = SpinRules.rollRarity(rng)
	end
	local nextPity: Pity = {
		epic = if SpinRules.rank(rarity) >= SpinRules.rank("Epic") then 0 else epics + 1,
		legendary = if SpinRules.rank(rarity) >= SpinRules.rank("Legendary")
			then 0
			else legends + 1,
	}
	return { prize = pickPrize(rng, rarity), pity = nextPity }
end

-- The dev hook's forced rarity: a random prize of exactly that rarity, no pity change.
function SpinRules.prizeOfRarity(rng: () -> number, rarity: Rarity): Prize
	return pickPrize(rng, rarity)
end

-- One of the wheel's segments for this rarity (the pointer lands on it).
function SpinRules.segment(rng: () -> number, rarity: Rarity): number
	local pool: { number } = {}
	for i, segment in SpinRules.SEGMENTS do
		if segment == rarity then
			table.insert(pool, i)
		end
	end
	return pool[math.clamp(math.floor(rng() * #pool) + 1, 1, #pool)]
end

-- Prize bits: only finish / trail prizes are stored in the profile flag.
function SpinRules.bit(prizeId: string): number?
	for i, prize in SpinRules.PRIZES do
		if prize.id == prizeId and (prize.kind == "finish" or prize.kind == "trail") then
			return bit32.lshift(1, i - 1)
		end
	end
	return nil
end

function SpinRules.owns(state: State, prize: Prize): boolean
	local bit = SpinRules.bit(prize.id)
	return bit ~= nil and bit32.band(state.owned, bit) ~= 0
end

function SpinRules.claim(state: State, prize: Prize): State
	local bit = SpinRules.bit(prize.id)
	if not bit or bit32.band(state.owned, bit) ~= 0 then
		return state
	end
	return {
		day = state.day,
		free = state.free,
		pity = state.pity,
		rescued = state.rescued,
		owned = bit32.bor(state.owned, bit),
	}
end

-- Earned cosmetic keys (`earn = "spin:<prize id>"` in the Livery / Wake slot configs).
function SpinRules.ownedKeys(ownedBits: number): { string }
	local keys: { string } = {}
	for i, prize in SpinRules.PRIZES do
		if
			(prize.kind == "finish" or prize.kind == "trail")
			and bit32.band(ownedBits, bit32.lshift(1, i - 1)) ~= 0
		then
			table.insert(keys, "spin:" .. prize.id)
		end
	end
	return keys
end

return SpinRules
