--!strict
-- StockRotation: the shared Chandlery restock clock and roll (docs/15 hook H3), pure and Lune-tested.
-- The window is floor(os.time() / Period), so every server in the world sees the same stock at the same
-- UTC second. Within a window a small deterministic RNG (Park-Miller, no globals) rolls 6-8 unique
-- items by rarity weight; a client can therefore rebuild the shelf from the window index alone.
--
--   StockRotation.windowIndex(now) -> number       the restock window containing `now` (epoch seconds)
--   StockRotation.windowStart(now) -> number       its first second
--   StockRotation.secondsToRestock(now) -> number  seconds left in the window
--   StockRotation.formatTime(seconds) -> string    the clock text, `7:42` style
--   StockRotation.roll(now) -> { Slot }            the shelf's items and stock counts
--   StockRotation.seed(window) -> number           the window's RNG seed (tests and tooling)

local StockConfig = require(script.Parent.Config.StockConfig)

export type Slot = { item: StockConfig.Item, count: number }

local StockRotation = {}

StockRotation.Period = StockConfig.Period

local MOD = 2147483647 -- Park-Miller, 16807 x 2^31 is still exact in float64

function StockRotation.windowIndex(now: number): number
	return math.floor(now / StockConfig.Period)
end

function StockRotation.windowStart(now: number): number
	return StockRotation.windowIndex(now) * StockConfig.Period
end

function StockRotation.secondsToRestock(now: number): number
	return StockRotation.windowStart(now) + StockConfig.Period - now
end

function StockRotation.formatTime(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

function StockRotation.seed(window: number): number
	return (StockConfig.Seed + window * 7919) % (MOD - 1) + 1
end

local function rngFor(window: number): () -> number
	local state = StockRotation.seed(window)
	return function(): number
		state = (state * 16807) % MOD
		return state / MOD
	end
end

local function weightOf(item: StockConfig.Item): number
	return StockConfig.RarityWeight[item.rarity]
end

-- The index of one weighted pick in `list`, consuming one random number.
local function pick(rng: () -> number, list: { StockConfig.Item }): number
	local total = 0
	for _, it in list do
		total += weightOf(it)
	end
	local target = rng() * total
	for i, it in list do
		target -= weightOf(it)
		if target < 0 then
			return i
		end
	end
	return #list
end

function StockRotation.roll(now: number): { Slot }
	local rng = rngFor(StockRotation.windowIndex(now))
	local count = StockConfig.SlotMin
		+ math.floor(rng() * (StockConfig.SlotMax - StockConfig.SlotMin + 1))
	local remaining: { StockConfig.Item } = {}
	for _, id in StockConfig.Order do
		local entry = StockConfig.Items[id]
		assert(entry, id)
		table.insert(remaining, entry)
	end
	local slots: { Slot } = {}
	for _ = 1, count do
		local item = table.remove(remaining, pick(rng, remaining)) :: StockConfig.Item
		table.insert(slots, { item = item, count = StockConfig.CountByRarity[item.rarity] })
	end
	return slots
end

return StockRotation
