--!strict
-- Cosmetics slots "Outfit" and "Cap" (RP-M5 E2). The player's R15 avatar, dressed through a
-- HumanoidDescription by src/server/Cosmetics/Outfits.luau (plan in src/shared/AvatarCosmetics.luau).
-- Pass(es): CaptainsLocker (bright wetsuit, foul-weather coat, three caps, whistle emote) and
-- StormChaserLiveries (the storm-blue suit).
--
-- Every id is a real public Roblox catalog asset, looked up with the catalog search and thumbnail
-- APIs on 2026-10-18 (name and creator in the comment). Colours avoid docs/05 section 3.2 reserved
-- signal colours: no Hull / SOLAS orange, no hi-vis yellow-green, no distress red.
--
-- Option fields (free-form, read by AvatarCosmetics.plan):
--   layers   layered clothing { id, kind } (kind = Enum.AccessoryType name); replaces the avatar's
--            own layered clothing when the option has any
--   shirt / pants   classic Shirt / Pants ids (0 clears them; nil keeps the player's own)
--   hat      rigid hat accessory id (Cap slot); replaces the avatar's own hats
-- The default options ("Station", "None") leave the player's own avatar untouched (the normal
-- crew look: there is no imposed player uniform; docs 02 section 7, no RP roles yet).
type Option = { id: string, name: string, pass: string?, [string]: any }

local ID = {
	brightWetsuit = 93775739678892, -- layered jacket "Cyan Wetsuit" (DuckXander): black, cyan panels
	navyWetsuit = 102755032915916, -- layered jacket "Navy Blue Wetsuit" (DuckXander)
	raincoat = 17009234923, -- layered jacket "Raincoat" (Emotes CO.), yellow PVC foul-weather coat
	wetsuitPants = 9120251003, -- layered pants "Wetsuit Pants - Black" (Roblox)
	watchCap = 97244725486307, -- hat "Knit Watch Cap Beanie (Navy)" (FirstSight UGC)
	skipperCap = 15295647016, -- hat "Captain Hat" (arashiyama), white peaked cap, anchor badge
	baseballCap = 87601992010058, -- hat "Navy Blue Baseball Cap" (Dante's Cop Shop), plain
}

local outfits: { Option } = {
	{ id = "Station", name = "Own clothes", pass = nil },
	{
		id = "Wetsuit",
		name = "Bright wetsuit",
		pass = "CaptainsLocker",
		layers = { { id = ID.brightWetsuit, kind = "Jacket" } },
	},
	{
		id = "FoulWeather",
		name = "Foul-weather coat",
		pass = "CaptainsLocker",
		layers = {
			{ id = ID.wetsuitPants, kind = "Pants" },
			{ id = ID.raincoat, kind = "Jacket" },
		},
	},
	{
		id = "StormChaser",
		name = "Storm Chaser suit",
		pass = "StormChaserLiveries",
		layers = { { id = ID.navyWetsuit, kind = "Jacket" } },
	},
}

local caps: { Option } = {
	{ id = "None", name = "Own hat", pass = nil },
	{ id = "WatchCap", name = "Navy watch cap", pass = "CaptainsLocker", hat = ID.watchCap },
	{ id = "Skipper", name = "Skipper's cap", pass = "CaptainsLocker", hat = ID.skipperCap },
	{ id = "Baseball", name = "Navy baseball cap", pass = "CaptainsLocker", hat = ID.baseballCap },
}

return {
	{
		slot = "Outfit",
		label = "Outfit",
		options = outfits,
		default = "Station",
	},
	{
		slot = "Cap",
		label = "Cap",
		options = caps,
		default = "None",
	},
}
