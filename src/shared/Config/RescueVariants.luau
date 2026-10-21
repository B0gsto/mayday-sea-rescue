--!strict
-- RescueVariants: the rare-call variants and their rarities (docs/15 section 2, hook H2).
-- Pure data plus the roll, safe to load in Lune (tests/RescueAlbum.spec.luau). The code-built
-- dressing is src/server/Ops/RescueDressing.luau; the collection is src/shared/RescueAlbum.luau.
--
-- Fair FOMO (docs/15 section 1): every variant is earnable by playing, nothing is sold. Common and
-- Uncommon roll on every call; Rare rolls at a tiny base rate, and every rarity rolls at its full
-- weight only while the hourly Great Storm is active (EventService.IsEventActive("GreatStorm")).
-- A Legendary call puts a flare over the scene and flashes its sticker to everyone (AlbumService).
-- Seasonal variants (season = "Halloween" / "Winter") roll only inside their event window
-- (Config/SeasonalEvents); they still show in the album all year and return each year.

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

export type Variant = {
	id: string,
	kind: string,
	rarity: Rarity,
	label: string, -- 1-2 words, the album sticker
	weight: number,
	accent: Color3, -- the sticker's fill once rescued
	style: "Person" | "Creature" | "Boat",
	season: string?, -- "Halloween" / "Winter": only rolls inside that window
	paint: { [string]: Color3 }?, -- part name -> colour (RescueDressing)
}

export type RarityInfo = { colour: Color3, rank: number }

local A11yPalette = require(script.Parent.Parent:WaitForChild("A11yPalette"))

local RescueVariants = {}

RescueVariants.Rarity = {
	Common = { colour = Color3.fromRGB(138, 155, 168), rank = 1 },
	Uncommon = { colour = Color3.fromRGB(63, 164, 106), rank = 2 },
	Rare = { colour = Color3.fromRGB(61, 125, 216), rank = 3 },
	Epic = { colour = Color3.fromRGB(139, 91, 214), rank = 4 },
	Legendary = { colour = Color3.fromRGB(227, 167, 47), rank = 5 },
} :: { [string]: RarityInfo }

-- Outside a Great Storm a Rare keeps this share of its weight: a tiny base rate, never Epic or
-- Legendary (docs/15 section 1: rare calls are the storm's draw, but a collector can still meet one).
RescueVariants.RareBaseRate = 0.06

-- Completing a call kind's set pays this Cash once (ProgressionService.Award).
RescueVariants.SetCash = {
	PersonInWater = 2200,
	DisabledVessel = 1500,
	CliffCasualty = 1100,
	RipCurrent = 1000,
	SinkingVessel = 1050,
	VesselFire = 1000,
	WildlifeRescue = 700,
} :: { [string]: number }

-- The album's row order and one-word row names.
RescueVariants.KindOrder = {
	"PersonInWater",
	"DisabledVessel",
	"CliffCasualty",
	"RipCurrent",
	"SinkingVessel",
	"VesselFire",
	"WildlifeRescue",
} :: { string }

RescueVariants.KindLabel = {
	PersonInWater = "Swimmer",
	DisabledVessel = "Tow",
	CliffCasualty = "Cliff",
	RipCurrent = "Rip",
	SinkingVessel = "Sinking",
	VesselFire = "Fire",
	WildlifeRescue = "Wildlife",
} :: { [string]: string }

RescueVariants.Kinds = {
	PersonInWater = {
		{
			id = "Swimmer",
			kind = "PersonInWater",
			rarity = "Common",
			label = "Swimmer",
			weight = 46,
			accent = Color3.fromRGB(96, 164, 196),
			style = "Person",
		},
		{
			id = "Kayaker",
			kind = "PersonInWater",
			rarity = "Common",
			label = "Kayak",
			weight = 22,
			accent = Color3.fromRGB(219, 124, 62),
			style = "Person",
			paint = { LifeVest = Color3.fromRGB(226, 120, 48) },
		},
		{
			id = "Paddleboarder",
			kind = "PersonInWater",
			rarity = "Uncommon",
			label = "Paddle",
			weight = 18,
			accent = Color3.fromRGB(64, 168, 158),
			style = "Person",
			paint = { LifeVest = Color3.fromRGB(58, 174, 160) },
		},
		{
			id = "PirateSwimmer",
			kind = "PersonInWater",
			rarity = "Rare",
			label = "Pirate",
			weight = 7,
			accent = Color3.fromRGB(180, 52, 62),
			style = "Person",
			paint = { LifeVest = Color3.fromRGB(178, 48, 58) },
		},
		{
			id = "LostDog",
			kind = "PersonInWater",
			rarity = "Rare",
			label = "Lost Dog",
			weight = 5,
			accent = Color3.fromRGB(160, 108, 66),
			style = "Creature",
		},
		{
			id = "GoldenGull",
			kind = "PersonInWater",
			rarity = "Legendary",
			label = "Golden Gull",
			weight = 2,
			accent = Color3.fromRGB(240, 190, 58),
			style = "Creature",
		},
		{
			id = "Surfer",
			kind = "PersonInWater",
			rarity = "Uncommon",
			label = "Surfer",
			weight = 14,
			accent = Color3.fromRGB(54, 154, 190),
			style = "Person",
			paint = { Torso = Color3.fromRGB(32, 58, 84) },
		},
		{
			id = "Mermaid",
			kind = "PersonInWater",
			rarity = "Rare",
			label = "Mermaid",
			weight = 7,
			accent = Color3.fromRGB(72, 190, 176),
			style = "Person",
			paint = { Torso = Color3.fromRGB(58, 178, 164) },
		},
		{
			id = "Grandad",
			kind = "PersonInWater",
			rarity = "Common",
			label = "Grandad",
			weight = 18,
			accent = Color3.fromRGB(214, 96, 84),
			style = "Person",
			paint = { Torso = Color3.fromRGB(236, 226, 202) },
		},
		{
			id = "SeaScout",
			kind = "PersonInWater",
			rarity = "Uncommon",
			label = "Sea Scout",
			weight = 12,
			accent = Color3.fromRGB(112, 150, 84),
			style = "Person",
			paint = { Torso = Color3.fromRGB(138, 158, 96) },
		},
		{
			id = "SkeletonSwimmer",
			kind = "PersonInWater",
			rarity = "Rare",
			label = "Bones",
			weight = 8,
			accent = Color3.fromRGB(228, 226, 214),
			style = "Person",
			season = "Halloween",
			paint = { Torso = Color3.fromRGB(38, 38, 46) },
		},
		{
			id = "SantaSwimmer",
			kind = "PersonInWater",
			rarity = "Rare",
			label = "Santa",
			weight = 8,
			accent = Color3.fromRGB(206, 54, 58),
			style = "Person",
			season = "Winter",
			paint = { Torso = Color3.fromRGB(190, 46, 50) },
		},
	},
	DisabledVessel = {
		{
			id = "FishingBoat",
			kind = "DisabledVessel",
			rarity = "Common",
			label = "Fishing",
			weight = 55,
			accent = Color3.fromRGB(78, 136, 176),
			style = "Boat",
		},
		{
			id = "RowingBoat",
			kind = "DisabledVessel",
			rarity = "Uncommon",
			label = "Rowboat",
			weight = 30,
			accent = Color3.fromRGB(176, 126, 70),
			style = "Boat",
			paint = {
				Hull = Color3.fromRGB(146, 98, 56),
				Stripe = Color3.fromRGB(96, 62, 34),
				Cabin = Color3.fromRGB(146, 98, 56),
				Windshield = Color3.fromRGB(96, 62, 34),
			},
		},
		{
			id = "CelebrityYacht",
			kind = "DisabledVessel",
			rarity = "Epic",
			label = "Yacht",
			weight = 4,
			accent = Color3.fromRGB(232, 210, 150),
			style = "Boat",
			paint = {
				Hull = Color3.fromRGB(248, 248, 244),
				Stripe = Color3.fromRGB(214, 176, 74),
				Cabin = Color3.fromRGB(252, 252, 250),
			},
		},
		{
			id = "SwanPedalo",
			kind = "DisabledVessel",
			rarity = "Rare",
			label = "Swan",
			weight = 7,
			accent = Color3.fromRGB(240, 240, 234),
			style = "Boat",
			paint = {
				Hull = Color3.fromRGB(248, 248, 244),
				Stripe = Color3.fromRGB(176, 212, 222),
				Cabin = Color3.fromRGB(248, 248, 244),
				Windshield = Color3.fromRGB(176, 212, 222),
			},
		},
		{
			id = "PirateShip",
			kind = "DisabledVessel",
			rarity = "Epic",
			label = "Pirate Ship",
			weight = 4,
			accent = Color3.fromRGB(74, 54, 44),
			style = "Boat",
			paint = {
				Hull = Color3.fromRGB(104, 72, 48),
				Stripe = Color3.fromRGB(34, 32, 34),
				Cabin = Color3.fromRGB(120, 84, 54),
				Windshield = Color3.fromRGB(42, 38, 36),
			},
		},
		{
			id = "Trawler",
			kind = "DisabledVessel",
			rarity = "Common",
			label = "Trawler",
			weight = 26,
			accent = Color3.fromRGB(96, 146, 176),
			style = "Boat",
			paint = {
				Hull = Color3.fromRGB(212, 224, 228),
				Stripe = Color3.fromRGB(150, 58, 52),
				Cabin = Color3.fromRGB(242, 240, 232),
			},
		},
		{
			id = "Houseboat",
			kind = "DisabledVessel",
			rarity = "Uncommon",
			label = "Houseboat",
			weight = 16,
			accent = Color3.fromRGB(96, 138, 100),
			style = "Boat",
			paint = {
				Hull = Color3.fromRGB(84, 124, 88),
				Stripe = Color3.fromRGB(238, 230, 206),
				Cabin = Color3.fromRGB(240, 232, 208),
			},
		},
	},
	CliffCasualty = {
		{
			id = "Hiker",
			kind = "CliffCasualty",
			rarity = "Common",
			label = "Hiker",
			weight = 60,
			accent = Color3.fromRGB(104, 152, 92),
			style = "Person",
			paint = { Torso = Color3.fromRGB(104, 152, 92) },
		},
		{
			id = "Climber",
			kind = "CliffCasualty",
			rarity = "Uncommon",
			label = "Climber",
			weight = 30,
			accent = Color3.fromRGB(206, 148, 48),
			style = "Person",
			paint = { Torso = Color3.fromRGB(214, 156, 56) },
		},
		{
			id = "Paraglider",
			kind = "CliffCasualty",
			rarity = "Rare",
			label = "Paraglider",
			weight = 7,
			accent = Color3.fromRGB(198, 76, 128),
			style = "Person",
			paint = { Torso = Color3.fromRGB(198, 76, 128) },
		},
	},
	RipCurrent = {
		{
			id = "RipSwimmer",
			kind = "RipCurrent",
			rarity = "Common",
			label = "Swimmer",
			weight = 55,
			accent = Color3.fromRGB(92, 158, 190),
			style = "Person",
		},
		{
			id = "BodyBoarder",
			kind = "RipCurrent",
			rarity = "Uncommon",
			label = "Boarder",
			weight = 30,
			accent = Color3.fromRGB(66, 166, 150),
			style = "Person",
			paint = { LifeVest = Color3.fromRGB(54, 168, 152) },
		},
		{
			id = "Seal",
			kind = "RipCurrent",
			rarity = "Rare",
			label = "Seal",
			weight = 7,
			accent = Color3.fromRGB(128, 136, 148),
			style = "Creature",
		},
	},
	SinkingVessel = {
		{
			id = "SinkingFishingBoat",
			kind = "SinkingVessel",
			rarity = "Common",
			label = "Fishing",
			weight = 55,
			accent = Color3.fromRGB(78, 136, 176),
			style = "Boat",
		},
		{
			id = "Tugboat",
			kind = "SinkingVessel",
			rarity = "Uncommon",
			label = "Tug",
			weight = 30,
			accent = Color3.fromRGB(176, 92, 48),
			style = "Boat",
			paint = {
				Hull = Color3.fromRGB(78, 82, 86),
				Keel = Color3.fromRGB(168, 58, 48),
				Cabin = Color3.fromRGB(196, 188, 168),
			},
		},
		{
			id = "FerryTender",
			kind = "SinkingVessel",
			rarity = "Rare",
			label = "Tender",
			weight = 7,
			accent = Color3.fromRGB(228, 228, 220),
			style = "Boat",
			paint = {
				Hull = Color3.fromRGB(246, 246, 242),
				Keel = Color3.fromRGB(42, 92, 156),
				Cabin = Color3.fromRGB(246, 246, 242),
				RailPort = Color3.fromRGB(42, 92, 156),
				RailStarboard = Color3.fromRGB(42, 92, 156),
			},
		},
	},
	-- Wildlife (H4): the five sanctuary species, and the rare palette the album collects. The id
	-- matches the animal SanctuaryService actually dresses (`Wildlife_<species>` / `..._Rare`).
	WildlifeRescue = {
		{
			id = "Wildlife_SealPup",
			kind = "WildlifeRescue",
			rarity = "Common",
			label = "Seal",
			weight = 20,
			accent = Color3.fromRGB(128, 136, 148),
			style = "Creature",
		},
		{
			id = "Wildlife_Puffin",
			kind = "WildlifeRescue",
			rarity = "Common",
			label = "Puffin",
			weight = 20,
			accent = Color3.fromRGB(52, 56, 64),
			style = "Creature",
		},
		{
			id = "Wildlife_Otter",
			kind = "WildlifeRescue",
			rarity = "Common",
			label = "Otter",
			weight = 20,
			accent = Color3.fromRGB(132, 92, 60),
			style = "Creature",
		},
		{
			id = "Wildlife_Turtle",
			kind = "WildlifeRescue",
			rarity = "Common",
			label = "Turtle",
			weight = 20,
			accent = Color3.fromRGB(74, 118, 88),
			style = "Creature",
		},
		{
			id = "Wildlife_Gull",
			kind = "WildlifeRescue",
			rarity = "Common",
			label = "Gull",
			weight = 20,
			accent = Color3.fromRGB(196, 200, 204),
			style = "Creature",
		},
		{
			id = "Wildlife_SealPup_Rare",
			kind = "WildlifeRescue",
			rarity = "Rare",
			label = "Gold Seal",
			weight = 2.5,
			accent = Color3.fromRGB(230, 184, 82),
			style = "Creature",
		},
		{
			id = "Wildlife_Puffin_Rare",
			kind = "WildlifeRescue",
			rarity = "Rare",
			label = "Albino",
			weight = 2.5,
			accent = Color3.fromRGB(236, 232, 226),
			style = "Creature",
		},
		{
			id = "Wildlife_Otter_Rare",
			kind = "WildlifeRescue",
			rarity = "Rare",
			label = "Silver",
			weight = 2.5,
			accent = Color3.fromRGB(176, 182, 190),
			style = "Creature",
		},
		{
			id = "Wildlife_Turtle_Rare",
			kind = "WildlifeRescue",
			rarity = "Rare",
			label = "Gold Shell",
			weight = 2.5,
			accent = Color3.fromRGB(222, 176, 74),
			style = "Creature",
		},
		{
			id = "Wildlife_Gull_Rare",
			kind = "WildlifeRescue",
			rarity = "Rare",
			label = "Snow Gull",
			weight = 2.5,
			accent = Color3.fromRGB(244, 246, 248),
			style = "Creature",
		},
	},
	VesselFire = {
		{
			id = "Cruiser",
			kind = "VesselFire",
			rarity = "Common",
			label = "Cruiser",
			weight = 55,
			accent = Color3.fromRGB(96, 148, 180),
			style = "Boat",
		},
		{
			id = "CharterBoat",
			kind = "VesselFire",
			rarity = "Uncommon",
			label = "Charter",
			weight = 30,
			accent = Color3.fromRGB(72, 160, 148),
			style = "Boat",
			paint = {
				Hull = Color3.fromRGB(236, 240, 238),
				Stripe = Color3.fromRGB(48, 156, 140),
				Cabin = Color3.fromRGB(232, 238, 236),
			},
		},
		{
			id = "Tanker",
			kind = "VesselFire",
			rarity = "Rare",
			label = "Tanker",
			weight = 7,
			accent = Color3.fromRGB(204, 96, 52),
			style = "Boat",
			paint = {
				Hull = Color3.fromRGB(60, 64, 68),
				Stripe = Color3.fromRGB(224, 122, 40),
				Cabin = Color3.fromRGB(210, 210, 204),
			},
		},
	},
} :: { [string]: { Variant } }

local byId: { [string]: Variant } = {}
for _, list in RescueVariants.Kinds do
	for _, variant in list do
		byId[variant.id] = variant
	end
end

function RescueVariants.ById(id: any): Variant?
	return if type(id) == "string" then byId[id] else nil
end

function RescueVariants.get(kind: string, id: any): Variant?
	local variant = RescueVariants.ById(id)
	return if variant and variant.kind == kind then variant else nil
end

function RescueVariants.rarityColour(rarity: string): Color3
	return A11yPalette.colour("Rarity", rarity)
end

-- The weight a variant carries for this roll: Epics and Legendaries only come with the Great
-- Storm; Rares are scaled down to the tiny base rate outside it; a seasonal variant carries no
-- weight outside its own window.
local function weightFor(variant: Variant, greatStorm: boolean, season: string?): number
	if variant.season and variant.season ~= season then
		return 0
	end
	if greatStorm then
		return variant.weight
	elseif variant.rarity == "Rare" then
		return variant.weight * RescueVariants.RareBaseRate
	elseif variant.rarity == "Epic" or variant.rarity == "Legendary" then
		return 0
	end
	return variant.weight
end

-- Roll one variant for a call kind. `roll` is [0, 1) from the server's Random. `forced` (Studio's
-- Workspace RescueVariantForce) wins when it belongs to the kind, window or not. `season` is the
-- live SeasonalEvents id ("Halloween" / "Winter"); seasonal variants roll only while it matches.
function RescueVariants.choose(
	kind: string,
	roll: number,
	greatStorm: boolean,
	forced: string?,
	season: string?
): Variant?
	local list = RescueVariants.Kinds[kind]
	if not list then
		return nil
	end
	local forcedVariant = RescueVariants.get(kind, forced)
	if forcedVariant then
		return forcedVariant
	end
	local total = 0
	for _, variant in list do
		total += weightFor(variant, greatStorm, season)
	end
	if total <= 0 then
		return list[1]
	end
	local target = math.clamp(roll, 0, 0.999999) * total
	for _, variant in list do
		target -= weightFor(variant, greatStorm, season)
		if target < 0 then
			return variant
		end
	end
	return list[#list]
end

return RescueVariants
