--!strict
-- ProductShelves (RP-M3): the rules behind every Robux item card in the phone's Store app (UI/StoreApp):
-- which items list, what a card says and when its Buy button may open a Roblox purchase prompt (never for
-- an item with id 0 or one the server did not offer). Pure, no requires: tests/StoreCards.spec runs it
-- under Lune. The in-world shelves are gone (docs/16 C5): the Store app sells every launch id.
--
-- Signals other packages publish (all optional; the card degrades to the plain description):
--   player attribute Pass_<Key>          true when a game pass is owned (MonetizationService, RP-M1)
--   player attribute OpsCompleted        operations finished this session (OperationService)
--   player attribute CashPacksToday      Cash packs bought today on this account (RP-M2, docs/04 4.1)
--   player attribute CashPerMinute       the top open zone's Cash rate (RP-M2), for the exact pack Cash
--   ReplicatedStorage.Weather SummonQueue  summoned storms waiting (RP-M2, docs/04 section 5; max 2)

export type Kind = "Products" | "GamePasses"
export type ItemRef = { kind: Kind, key: string }
export type CardContext = {
	offered: boolean, -- in this player's Monetization_GetCatalogue (id ~= 0, ready, policy)
	owned: boolean?, -- game pass owned
	price: number?, -- live MarketplaceService price in Robux (nil while loading or failed)
	priceFailed: boolean?,
	ownsDoubleCash: boolean?,
	cashPacksToday: number?,
	cashPerMinute: number?,
	stormQueue: number?,
	pending: boolean?, -- a purchase prompt is already open
}

export type CardState = {
	status: "hidden"
		| "comingSoon"
		| "owned"
		| "queueFull"
		| "limit"
		| "loading"
		| "unavailable"
		| "buy",
	canBuy: boolean,
	buyText: string,
	note: string?, -- the line under the effect (exact Cash, limits)
}

local ProductShelves = {}

ProductShelves.ROBUX = utf8.char(0xE002) -- the Robux glyph in Roblox fonts
ProductShelves.STORM_QUEUE_MAX = 2 -- docs/04 section 5 rule 3
ProductShelves.CURTAIN_TEXT = "Restocking for Reopening Day"

local function configItem(config: any, ref: ItemRef): any
	local list = config and config[ref.kind]
	return if type(list) == "table" then list[ref.key] else nil
end
ProductShelves.configItem = configItem

local function isCashPack(config: any, key: string): boolean
	for _, k in (config and config.CashPacks) or {} do
		if k == key then
			return true
		end
	end
	return false
end

-- Whether an item can appear on a shelf at all: ready items always (with "Coming soon" until RP-M4
-- gives them an id); unfinished ones (ready = false) only in Studio, so the shelves can be checked.
function ProductShelves.listed(item: any, studio: boolean): boolean
	if type(item) ~= "table" then
		return false
	end
	return item.ready ~= false or studio
end

-- The phone Store's tabs (UI/StoreApp): game passes, day passes (Products with dayPassFor), the other
-- products; each in config order, listed by the shelf rule.
function ProductShelves.storeItems(config: any, tab: string, studio: boolean): { ItemRef }
	local out: { ItemRef } = {}
	local kind: Kind = if tab == "Passes" then "GamePasses" else "Products"
	for key, item in (config and config[kind]) or {} do
		local day = type(item) == "table" and item.dayPassFor ~= nil
		if
			ProductShelves.listed(item, studio)
			and item.dockLevel == nil -- dock levels and buildings sell at the dock's ghost (docs/23 c.3)
			and item.dockBuilding == nil
			and (kind == "GamePasses" or day == (tab == "DayPasses"))
		then
			table.insert(out, { kind = kind, key = key })
		end
	end
	table.sort(out, function(a: ItemRef, b: ItemRef)
		return config[kind][a.key].order < config[kind][b.key].order
	end)
	return out
end

-- docs/04 section 4.1: the exact Cash a pack gives at this rate (nil when the rate is unknown).
function ProductShelves.packCash(item: any, cashPerMinute: number?): number?
	if type(item) ~= "table" or type(item.cashMinutes) ~= "number" then
		return nil
	end
	if type(cashPerMinute) ~= "number" or cashPerMinute <= 0 then
		return nil
	end
	return math.floor(cashPerMinute * item.cashMinutes * (1 + (item.valueBonus or 0)) + 0.5)
end

local function formatNumber(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end
ProductShelves.formatNumber = formatNumber

-- What the card shows for one item. Only status "buy" (canBuy) may open a purchase prompt.
function ProductShelves.cardState(config: any, ref: ItemRef, ctx: CardContext): CardState
	local item = configItem(config, ref)
	local function state(status: any, text: string, note: string?): CardState
		return { status = status, canBuy = status == "buy", buyText = text, note = note }
	end
	if type(item) ~= "table" then
		return state("hidden", "")
	end
	-- docs/04 4.2: Cash Boost is hidden for 2x Cash owners (it does not stack with the pass)
	if ref.kind == "Products" and ref.key == "CashBoost" and ctx.ownsDoubleCash then
		return state("hidden", "")
	end
	if not ctx.offered or type(item.id) ~= "number" or item.id <= 0 then
		return state("comingSoon", "Coming soon")
	end
	if ref.kind == "GamePasses" and ctx.owned then
		return state("owned", "Owned", "Equip it at the station locker or the Chandlery mirror.")
	end
	local note: string? = nil
	local cash = ProductShelves.packCash(item, ctx.cashPerMinute)
	if cash then
		note = `You get {formatNumber(cash)} Cash at your top open zone's rate.`
	end
	if item.stormTier then
		local queued = ctx.stormQueue or 0
		if queued >= ProductShelves.STORM_QUEUE_MAX then
			return state("queueFull", "Queue full", "Storm queue full, try again soon.")
		end
		note = if queued > 0
			then `{queued} of {ProductShelves.STORM_QUEUE_MAX} storms queued. Yours joins the queue.`
			else "No storms queued."
	end
	if ref.kind == "Products" and isCashPack(config, ref.key) then
		local limit = config.CashPackDailyLimit or 5
		local today = ctx.cashPacksToday or 0
		if today >= limit then
			return state("limit", "Daily limit", `{limit} Cash packs a day. More tomorrow.`)
		end
	end
	if ctx.pending then
		return state("loading", "Opening...", note)
	end
	if ctx.priceFailed then
		return state("unavailable", "Unavailable", "The price could not be read. Try again soon.")
	end
	if type(ctx.price) ~= "number" or ctx.price < 0 then
		return state("loading", "...", note)
	end
	return state("buy", `Buy  {ProductShelves.ROBUX} {formatNumber(ctx.price)}`, note)
end

-- The last guard before MarketplaceService: a real id and a "buy" state.
function ProductShelves.mayPrompt(config: any, ref: ItemRef, ctx: CardContext): boolean
	local item = configItem(config, ref)
	return type(item) == "table"
		and type(item.id) == "number"
		and item.id > 0
		and ProductShelves.cardState(config, ref, ctx).canBuy
end

return ProductShelves
