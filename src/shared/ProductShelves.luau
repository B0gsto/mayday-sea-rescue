--!strict
-- ProductShelves (RP-M3): where every Robux item is shown in Port Haven and what its product card says
-- (docs/04 sections 1 and 1.1). Pure data and rules: no services, no requires, so tests/ProductCard.spec
-- runs it under Lune. The client card (src/client/UI/ProductCard.luau) and the server rigs that tag the
-- shelf markers (ChandleryRig, map/Build.luau buildHarbourmasterDesk) read it.
--
-- A shelf is a real place: a marker (Attachment or BasePart) carrying the attribute ProductShelf = <id>.
-- The client adds the ProximityPrompt itself, so a player who has not reached the priced shelves never
-- sees them (rule 6). The prompt opens the shelf's product card; only its Buy button opens a Roblox
-- purchase prompt (rule 5), and never for an item with id 0 or one the server did not offer.
--
-- Signals other packages publish (all optional; the card degrades to the plain description):
--   player attribute Pass_<Key>          true when a game pass is owned (MonetizationService, RP-M1)
--   player attribute OpsCompleted        operations finished this session (OperationService)
--   player attribute CashPacksToday      Cash packs bought today on this account (RP-M2, docs/04 4.1)
--   player attribute CashPerMinute       the top open zone's Cash rate (RP-M2), for the exact pack Cash
--   ReplicatedStorage.Weather SummonQueue  summoned storms waiting (RP-M2, docs/04 section 5; max 2)

export type Kind = "Products" | "GamePasses"
export type ItemRef = { kind: Kind, key: string }
export type Shelf = {
	id: string,
	title: string, -- card header: the place
	action: string, -- ProximityPrompt ActionText
	object: string, -- ProximityPrompt ObjectText
	attachment: string?, -- Chandlery ATT_ marker that carries it (ChandleryRig tags it)
	priced: boolean, -- behind the "Restocking for Reopening Day" curtain until three operations (rule 6)
	items: { ItemRef },
}

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
ProductShelves.PRICED_AFTER_OPS = 3 -- docs/04 section 1 rule 6
ProductShelves.CURTAIN_TEXT = "Restocking for Reopening Day"

local function p(key: string): ItemRef
	return { kind = "GamePasses", key = key }
end
local function d(key: string): ItemRef
	return { kind = "Products", key = key }
end

-- docs/04 section 1.1, in walking order through the shop
ProductShelves.Order = {
	"ServiceCards",
	"Till",
	"UniformRack",
	"DogCorner",
	"LiveryWall",
	"HornBoard",
	"RadioShelf",
	"StormDesk",
	"BoatDeskQuickLaunch",
}

ProductShelves.Shelves = {
	ServiceCards = {
		id = "ServiceCards",
		title = "SERVICE CARDS",
		action = "Read the cards",
		object = "Framed service cards",
		attachment = "ATT_ServiceCards",
		priced = true,
		items = {
			p("DoubleCash"),
			p("VipCrewCard"),
			p("QuickLaunch"),
			p("StarterKit"),
			d("DayDoubleCash"),
			d("DayQuickLaunch"),
		},
	},
	Till = {
		id = "Till",
		title = "THE TILL",
		action = "Talk to the shopkeeper",
		object = "Chandlery till",
		attachment = "ATT_Till",
		priced = true,
		items = {
			d("SmallBonus"),
			d("CrewPayroll"),
			d("StationBudget"),
			d("HarborFund"),
			d("CashBoost"),
			d("CrewBoost"),
		},
	},
	UniformRack = {
		id = "UniformRack",
		title = "UNIFORM RACK",
		action = "Look at the uniforms",
		object = "Uniform rack",
		attachment = "ATT_Rack_02",
		priced = true,
		items = { p("CaptainsLocker"), p("StormChaserLiveries") },
	},
	DogCorner = {
		id = "DogCorner",
		title = "THE DOG CORNER",
		action = "Look at the dog coats",
		object = "Dog basket",
		attachment = "ATT_DogBasket",
		priced = true,
		items = { p("BosunsWardrobe"), p("WaterDogFriends") },
	},
	LiveryWall = {
		id = "LiveryWall",
		title = "LIVERIES AND FITTINGS",
		action = "Look at the swatches",
		object = "Livery swatch board",
		attachment = "ATT_SwatchBoard",
		priced = true,
		items = { p("StormChaserLiveries"), p("LightBars"), p("WakeTrails") },
	},
	HornBoard = {
		id = "HornBoard",
		title = "HORN BOARD",
		action = "Try the horns",
		object = "Horn board",
		attachment = "ATT_HornBoard",
		priced = true,
		items = { p("HornPack"), p("SirenPack") },
	},
	RadioShelf = {
		id = "RadioShelf",
		title = "RADIO SHELF",
		action = "Pick up the radio",
		object = "Marine radio set",
		attachment = "ATT_RadioShelf",
		priced = true,
		items = { p("SeaShantyRadio") },
	},
	StormDesk = {
		id = "StormDesk",
		title = "HARBOURMASTER'S DESK",
		action = "Read the barometer",
		object = "Harbourmaster's desk",
		priced = true,
		items = { d("CallTheStorm"), d("CallTheGreatStorm") },
	},
	BoatDeskQuickLaunch = {
		id = "BoatDeskQuickLaunch",
		title = "BOAT DESK",
		action = "Quick Launch card",
		object = "Boatyard desk",
		priced = true,
		items = { p("QuickLaunch") },
	},
} :: { [string]: Shelf }

-- ATT_ marker name -> shelf id (ChandleryRig tags these on the H2 models)
function ProductShelves.attachmentShelves(): { [string]: string }
	local out: { [string]: string } = {}
	for id, shelf in ProductShelves.Shelves do
		if shelf.attachment then
			out[shelf.attachment] = id
		end
	end
	return out
end

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

-- Rule 6: no prices until the tutorial chain is three operations in. OpsCompleted is per session, so a
-- returning player also passes on persisted progress: a rank above Recruit, an earned certification,
-- or three live operations counted toward certifications.
function ProductShelves.pricedOpen(snapshot: { [string]: any }?, opsCompleted: number?): boolean
	local s: { [string]: any } = snapshot or {}
	if s.coldOpenDone == false then
		return false
	end
	if (opsCompleted or 0) >= ProductShelves.PRICED_AFTER_OPS then
		return true
	end
	if type(s.rankIndex) == "number" and s.rankIndex >= 2 then
		return true
	end
	local live = 0
	if type(s.certs) == "table" then
		for _, st in s.certs do
			if type(st) == "table" then
				if st.earned == true then
					return true
				end
				live += if type(st.live) == "number" then st.live else 0
			end
		end
	end
	return live >= ProductShelves.PRICED_AFTER_OPS
end

-- Whether an item can appear on a shelf at all: ready items always (with "Coming soon" until RP-M4
-- gives them an id); unfinished ones (ready = false) only in Studio, so the shelves can be checked.
function ProductShelves.listed(item: any, studio: boolean): boolean
	if type(item) ~= "table" then
		return false
	end
	return item.ready ~= false or studio
end

-- The items a shelf shows, in shelf order (skips unknown keys).
function ProductShelves.shelfItems(config: any, shelfId: string, studio: boolean): { ItemRef }
	local shelf = ProductShelves.Shelves[shelfId]
	local out: { ItemRef } = {}
	if not shelf then
		return out
	end
	for _, ref in shelf.items do
		if ProductShelves.listed(configItem(config, ref), studio) then
			table.insert(out, ref)
		end
	end
	return out
end

-- A shelf gets a prompt when it lists anything (and, if priced, once rule 6 allows prices).
function ProductShelves.shelfVisible(
	config: any,
	shelfId: string,
	studio: boolean,
	pricedOpen: boolean
): boolean
	local shelf = ProductShelves.Shelves[shelfId]
	if not shelf or (shelf.priced and not pricedOpen) then
		return false
	end
	return #ProductShelves.shelfItems(config, shelfId, studio) > 0
end

-- The phone Store's tabs (UI/StoreApp): game passes, day passes (Products with dayPassFor), the other
-- products; each in config order, listed by the shelf rule.
ProductShelves.STORE_TABS = { "Passes", "DayPasses", "Items" }
function ProductShelves.storeItems(config: any, tab: string, studio: boolean): { ItemRef }
	local out: { ItemRef } = {}
	local kind: Kind = if tab == "Passes" then "GamePasses" else "Products"
	for key, item in (config and config[kind]) or {} do
		local day = type(item) == "table" and item.dayPassFor ~= nil
		if
			ProductShelves.listed(item, studio)
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

-- The chalkboard by the harbourmaster's door (docs/04 section 5 rule 3).
function ProductShelves.stormBoardText(queued: number?): string
	local n = queued or 0
	if n >= ProductShelves.STORM_QUEUE_MAX then
		return "STORM QUEUE\nFull, try again soon"
	elseif n > 0 then
		return `STORM QUEUE\n{n} of {ProductShelves.STORM_QUEUE_MAX} waiting`
	end
	return "STORM QUEUE\nNone waiting"
end

return ProductShelves
