--!strict
-- DiscoveryConfig: the exploration album (docs/21 §3), pure data, safe in Lune. Each WorldConfig.Islands
-- row gets a page: sticker 1 is always the island stamp (WorldConfig `stamp` point), then the listed
-- collectibles. A collectible sits at a WorldConfig island point (`from`: stamp / landing / dock /
-- landmark) plus `offset`; the server settles it on the ground. Kinds: Bottle (walk into it), View (stand
-- at the telescope), Critter (get near a rare animal; `species` is a Config/Wildlife id). Amounts tune
-- (docs/03 owns numbers). `cosmetic` is the key a completed page unlocks (DiscoveryRules.cosmetics).
-- `icon` picks the code-drawn placeholder (UI/Sticker) until docs/18's sticker art lands.

export type Sticker = {
	id: string,
	kind: string, -- "Bottle" | "View" | "Critter"
	from: string,
	offset: Vector3,
	species: string?,
}
export type Page = {
	colour: Color3,
	icon: string,
	cosmetic: string?,
	stickers: { Sticker },
}

local DiscoveryConfig = {
	-- seen from the sea: within the island radius plus this
	SightRange = 600,
	-- pick-up reach per kind (studs, 3D from the character root)
	Range = { Stamp = 12, Bottle = 8, View = 9, Critter = 24, Wreck = 30 } :: { [string]: number },
	-- one-time Cash per sticker kind, and the completed-page bonus
	Cash = { Stamp = 150, Bottle = 75, View = 75, Critter = 75, Wreck = 150, Page = 300 } :: {
		[string]: number,
	},
	-- the fog grid the map draws (docs/21 §3): square cells over the map canvas, cleared near the player
	Fog = { origin = -7168, cell = 256, count = 56, radius = 400 },
	Pages = {} :: { [string]: Page },
}

local function v(x: number, z: number): Vector3
	return Vector3.new(x, 0, z)
end

DiscoveryConfig.Pages = {
	SkerryIsle = {
		colour = Color3.fromHex("5B7F95"),
		icon = "seal",
		cosmetic = "isle:SkerryIsle",
		stickers = {
			{ id = "Bottle", kind = "Bottle", from = "landing", offset = v(16, 10) },
			{ id = "View", kind = "View", from = "stamp", offset = v(-14, 12) },
			{
				id = "Seal",
				kind = "Critter",
				from = "dock",
				offset = v(30, 20),
				species = "SealPup",
			},
		},
	},
	PuffinIsle = {
		colour = Color3.fromHex("E2557A"),
		icon = "bird",
		cosmetic = "isle:PuffinIsle",
		stickers = {
			{ id = "Bottle", kind = "Bottle", from = "landing", offset = v(14, 14) },
			{ id = "View", kind = "View", from = "stamp", offset = v(-16, 10) },
			{
				id = "Puffin",
				kind = "Critter",
				from = "stamp",
				offset = v(20, 18),
				species = "Puffin",
			},
		},
	},
	Penwyn = {
		colour = Color3.fromHex("2F9BD6"),
		icon = "mill",
		cosmetic = "isle:Penwyn",
		stickers = {
			{ id = "Bottle", kind = "Bottle", from = "landing", offset = v(10, 24) },
			{ id = "View", kind = "View", from = "stamp", offset = v(16, -14) },
			{
				id = "Otter",
				kind = "Critter",
				from = "dock",
				offset = v(20, -40),
				species = "Otter",
			},
		},
	},
	WreckReef = {
		colour = Color3.fromHex("B5562B"),
		icon = "wreck",
		cosmetic = "isle:WreckReef",
		stickers = {
			{ id = "Bottle", kind = "Bottle", from = "landing", offset = v(-10, 18) },
			{ id = "View", kind = "View", from = "stamp", offset = v(14, 14) },
			{
				id = "Gull",
				kind = "Critter",
				from = "landing",
				offset = v(30, -26),
				species = "Gull",
			},
		},
	},
	TheArches = {
		colour = Color3.fromHex("7A6FB0"),
		icon = "arch",
		cosmetic = "isle:TheArches",
		stickers = {
			{ id = "Bottle", kind = "Bottle", from = "landing", offset = v(-16, 10) },
			{ id = "View", kind = "View", from = "stamp", offset = v(12, 16) },
			{
				id = "Seal",
				kind = "Critter",
				from = "dock",
				offset = v(-30, 30),
				species = "SealPup",
			},
		},
	},
	GannetRock = {
		colour = Color3.fromHex("D23B3B"),
		icon = "light",
		cosmetic = "isle:GannetRock",
		stickers = {
			{ id = "Bottle", kind = "Bottle", from = "landing", offset = v(10, -12) },
			{ id = "View", kind = "View", from = "stamp", offset = v(-10, -10) },
			{
				id = "Gull",
				kind = "Critter",
				from = "landing",
				offset = v(-20, 24),
				species = "Gull",
			},
		},
	},
	MermaidLagoon = {
		colour = Color3.fromHex("1FB5A8"),
		icon = "palm",
		cosmetic = "isle:MermaidLagoon",
		stickers = {
			{ id = "Bottle", kind = "Bottle", from = "landing", offset = v(-18, 12) },
			{ id = "View", kind = "View", from = "stamp", offset = v(-14, -14) },
			{
				id = "Turtle",
				kind = "Critter",
				from = "dock",
				offset = v(-30, -30),
				species = "Turtle",
			},
		},
	},
	-- docs/23 (l): the hub forest's hidden spots (WorldConfig.Hub.clearings), no trail leads to either
	Hub = {
		colour = Color3.fromHex("4E7A3A"),
		icon = "castle",
		stickers = {
			{ id = "Ruin", kind = "View", from = "Ruin", offset = v(4, 3) }, -- the hilltop ruin's view
			{ id = "Wreck", kind = "Bottle", from = "Wreck", offset = v(-6, 5) }, -- by the overgrown wreck
		},
	},
}

return DiscoveryConfig
