--!strict
-- StockConfig: the rotating Chandlery stock (docs/15 hook H3). Pure data, safe to load in Lune.
-- Every restock rolls 6-8 unique items from this pool by rarity weight. Prices are Cash only (docs/15
-- section 1: no Robux on the rotating shelves). Gear items grant one level of the existing gear (real
-- effect); trims and bay decor are earned cosmetics read by src/shared/CosmeticLoadout.
-- StockRotation owns the roll and the clock; StockService owns the purchase.

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic"
export type Kind = "Gear" | "Trim" | "Decor" | "Treat"
export type Shape = "Box" | "Cylinder" | "Ball" | "Wedge"

export type Item = {
	id: string,
	name: string, -- shelf tag, 1-3 words
	kind: Kind,
	rarity: Rarity,
	price: number, -- Cash
	limit: number, -- per player per restock
	gear: string?, -- ProgressionConfig.Gear id: grants one level
	cosmetic: string?, -- data.flags.stock flag key
	treat: boolean?, -- G48: a consumable fish treat, counted in data.flags.pets
	color: Color3,
	shape: Shape,
}

local StockConfig = {}

StockConfig.Period = 600 -- seconds between restocks (10 min), shared clock (os.time UTC)
StockConfig.Seed = 20261020
StockConfig.SlotMin = 6
StockConfig.SlotMax = 8

StockConfig.RarityWeight = { Common = 62, Uncommon = 26, Rare = 9, Epic = 3 }
StockConfig.CountByRarity = { Common = 3, Uncommon = 2, Rare = 2, Epic = 1 }

StockConfig.RarityColor = {
	Common = Color3.fromRGB(214, 210, 198),
	Uncommon = Color3.fromRGB(104, 196, 130),
	Rare = Color3.fromRGB(96, 164, 246),
	Epic = Color3.fromRGB(196, 124, 246),
}

local function item(
	id: string,
	name: string,
	kind: Kind,
	rarity: Rarity,
	price: number,
	limit: number,
	color: Color3,
	shape: Shape,
	gear: string?,
	cosmetic: string?,
	treat: boolean?
): Item
	return {
		id = id,
		name = name,
		kind = kind,
		rarity = rarity,
		price = price,
		limit = limit,
		color = color,
		shape = shape,
		gear = gear,
		cosmetic = cosmetic,
		treat = treat,
	}
end

-- Order fixes the deterministic roll (StockRotation walks this list).
StockConfig.Order = {
	"EngineTunePart",
	"GripKit",
	"RedHullPaint",
	"TealHullPaint",
	"GoldHullPaint",
	"AmberLightBar",
	"BlueLightBar",
	"TurquoiseWake",
	"GoldWake",
	"DeckLantern",
	"BrassBell",
	"RopeWreath",
	"HarbourFlag",
	"DriftwoodShelf",
	"SignalFlags",
	"FishTreat",
}

StockConfig.Items = {
	EngineTunePart = item(
		"EngineTunePart",
		"Engine Part",
		"Gear",
		"Common",
		280,
		1,
		Color3.fromRGB(170, 176, 184),
		"Cylinder",
		"EngineTune"
	),
	GripKit = item(
		"GripKit",
		"Grip Kit",
		"Gear",
		"Uncommon",
		900,
		1,
		Color3.fromRGB(74, 84, 96),
		"Box",
		"StrongGrip"
	),
	RedHullPaint = item(
		"RedHullPaint",
		"Red Paint",
		"Trim",
		"Uncommon",
		1200,
		1,
		Color3.fromRGB(176, 52, 44),
		"Cylinder",
		nil,
		"paint_red"
	),
	TealHullPaint = item(
		"TealHullPaint",
		"Teal Paint",
		"Trim",
		"Rare",
		3800,
		1,
		Color3.fromRGB(36, 140, 140),
		"Cylinder",
		nil,
		"paint_teal"
	),
	GoldHullPaint = item(
		"GoldHullPaint",
		"Gold Paint",
		"Trim",
		"Epic",
		14000,
		1,
		Color3.fromRGB(220, 176, 66),
		"Cylinder",
		nil,
		"paint_gold"
	),
	AmberLightBar = item(
		"AmberLightBar",
		"Amber Bar",
		"Trim",
		"Common",
		700,
		2,
		Color3.fromRGB(250, 176, 70),
		"Box",
		nil,
		"lightbar_amber"
	),
	BlueLightBar = item(
		"BlueLightBar",
		"Blue Bar",
		"Trim",
		"Uncommon",
		1100,
		2,
		Color3.fromRGB(70, 130, 246),
		"Box",
		nil,
		"lightbar_blue"
	),
	TurquoiseWake = item(
		"TurquoiseWake",
		"Turquoise Wake",
		"Trim",
		"Uncommon",
		1400,
		1,
		Color3.fromRGB(64, 214, 200),
		"Wedge",
		nil,
		"wake_turquoise"
	),
	GoldWake = item(
		"GoldWake",
		"Gold Wake",
		"Trim",
		"Epic",
		16000,
		1,
		Color3.fromRGB(246, 206, 96),
		"Wedge",
		nil,
		"wake_gold"
	),
	DeckLantern = item(
		"DeckLantern",
		"Deck Lantern",
		"Decor",
		"Common",
		420,
		2,
		Color3.fromRGB(236, 196, 120),
		"Cylinder",
		nil,
		"decor_lantern"
	),
	BrassBell = item(
		"BrassBell",
		"Brass Bell",
		"Decor",
		"Rare",
		4200,
		1,
		Color3.fromRGB(214, 170, 82),
		"Ball",
		nil,
		"decor_bell"
	),
	RopeWreath = item(
		"RopeWreath",
		"Rope Wreath",
		"Decor",
		"Common",
		350,
		2,
		Color3.fromRGB(198, 174, 130),
		"Cylinder",
		nil,
		"decor_wreath"
	),
	HarbourFlag = item(
		"HarbourFlag",
		"Harbour Flag",
		"Decor",
		"Uncommon",
		1000,
		2,
		Color3.fromRGB(196, 68, 72),
		"Box",
		nil,
		"decor_flag"
	),
	DriftwoodShelf = item(
		"DriftwoodShelf",
		"Driftwood Shelf",
		"Decor",
		"Rare",
		3000,
		1,
		Color3.fromRGB(168, 142, 108),
		"Box",
		nil,
		"decor_shelf"
	),
	SignalFlags = item(
		"SignalFlags",
		"Signal Flags",
		"Decor",
		"Uncommon",
		950,
		2,
		Color3.fromRGB(88, 162, 206),
		"Box",
		nil,
		"decor_signals"
	),
	FishTreat = item(
		"FishTreat",
		"Fish Treat",
		"Treat",
		"Common",
		60,
		3,
		Color3.fromRGB(196, 150, 92),
		"Box",
		nil,
		nil,
		true
	),
} :: { [string]: Item }

return StockConfig
