--!strict
-- Cosmetics slot "Livery" (RP-M5 E1). Paint schemes for the player's own vehicles (RIB, jet ski,
-- and the land vehicles: pickup, response car, beach ATV). Applied by src/server/Cosmetics/Liveries
-- with the role mapping in src/shared/LiveryPaint.luau.
-- Pass(es): VipCrewCard (VIP Gold), StormChaserLiveries (Storm Chaser), StarterKit (Station Orange).
-- Shape: { slot, options = { { id, name, pass = <GamePass key, nil for free>, ...free-form } }, default }.
--
-- Paint roles (free fields of each option, sRGB albedo):
--   primary    RIB tubes, jet ski hull/deck, car body panels
--   secondary  RIB GRP hull below the tubes, jet ski lower sled
--   stripe     the RIB / jet ski decal bands (plain paint band, no lettering), the car's first checks
--   stripe2    the car's second check colour (falls back to secondary)
--   trim       optional: RIB A-frame and helm console (nil keeps the stock orange)
--   metallic   car panels get a faint clear-coat sheen (Reflectance); boats keep their roughness maps
-- Every colour stays clear of docs/05 section 3.2 reserved signal colours (LiveryPaint.signalClash,
-- checked in tests/Livery.spec.luau). "Standard" is the stock factory paint: nothing is changed.
--
-- `pattern` (G38) is the code-made trim welded on by src/server/Cosmetics/Liveries through
-- src/shared/LiveryPattern (hull sides, tubes, deck): "band", "twin", "stripes", "chevron",
-- "glow" or "lights" (Neon trim in the option's `glow` colour). Contrast is the point: a dark secondary hull
-- and a pale stripe against a bold primary, readable at 30-60 studs.
type Option = { id: string, name: string, pass: string?, [string]: any }

local options: { Option } = {
	{ id = "Standard", name = "Station issue", pass = nil },
	{
		id = "StationOrange",
		name = "Station Orange",
		pass = "StarterKit",
		blurb = "Deep station orange over a charcoal hull with a pale cream band.",
		primary = Color3.fromRGB(214, 86, 20), -- deep station orange, darker than Hull Orange
		secondary = Color3.fromRGB(36, 38, 42), -- charcoal lower hull
		stripe = Color3.fromRGB(238, 222, 176), -- pale cream band
		stripe2 = Color3.fromRGB(238, 222, 176),
		pattern = "band",
		metallic = false,
	},
	{
		id = "StormChaser",
		name = "Storm Chaser",
		pass = "StormChaserLiveries",
		blurb = "Storm blue over a near-black hull, two warm sand bands.",
		primary = Color3.fromRGB(79, 98, 117), -- storm slate blue
		secondary = Color3.fromRGB(30, 36, 46), -- near-black storm slate
		stripe = Color3.fromRGB(224, 196, 96), -- warm sand twin bands
		stripe2 = Color3.fromRGB(224, 196, 96),
		pattern = "twin",
		trim = Color3.fromRGB(58, 69, 82), -- A-frame and helm console
		metallic = true,
	},
	{
		id = "VipGold",
		name = "VIP Gold",
		pass = "VipCrewCard",
		blurb = "Champagne gold over a near-black hull with a cream band.",
		primary = Color3.fromRGB(201, 162, 74), -- champagne gold
		secondary = Color3.fromRGB(32, 34, 38), -- near-black lower hull
		stripe = Color3.fromRGB(238, 224, 176), -- cream band
		stripe2 = Color3.fromRGB(238, 224, 176),
		pattern = "band",
		trim = Color3.fromRGB(43, 47, 54), -- gunmetal A-frame and helm console
		metallic = true,
	},
	{
		id = "StockRed",
		name = "Chandlery red",
		earn = "stock:paint_red",
		blurb = "Oxide red over a charcoal hull with a sand band (Chandlery paint tin).",
		primary = Color3.fromRGB(176, 52, 44),
		secondary = Color3.fromRGB(34, 34, 38),
		stripe = Color3.fromRGB(236, 220, 178),
		stripe2 = Color3.fromRGB(236, 220, 178),
		pattern = "band",
		metallic = false,
	},
	{
		id = "StockTeal",
		name = "Chandlery teal",
		earn = "stock:paint_teal",
		blurb = "Harbour teal over a dark hull with twin cream bands (Chandlery paint tin).",
		primary = Color3.fromRGB(36, 140, 140),
		secondary = Color3.fromRGB(30, 38, 42),
		stripe = Color3.fromRGB(232, 214, 170),
		stripe2 = Color3.fromRGB(232, 214, 170),
		pattern = "twin",
		metallic = false,
	},
	{
		id = "StockGold",
		name = "Chandlery gold",
		earn = "stock:paint_gold",
		blurb = "Old brass gold over a near-black hull with an ivory band (Chandlery paint tin).",
		primary = Color3.fromRGB(220, 176, 66),
		secondary = Color3.fromRGB(30, 32, 36),
		stripe = Color3.fromRGB(238, 226, 188),
		stripe2 = Color3.fromRGB(238, 226, 188),
		pattern = "band",
		metallic = true,
	},
	{
		id = "Season1",
		name = "Season 1",
		earn = "season:Livery_Season1",
		blurb = "Deep rescue blue over a near-black hull, brass chevrons: the Season 1 logbook livery.",
		primary = Color3.fromRGB(36, 74, 112),
		secondary = Color3.fromRGB(30, 40, 54),
		stripe = Color3.fromRGB(214, 170, 74),
		stripe2 = Color3.fromRGB(214, 170, 74),
		pattern = "chevron",
		metallic = true,
	},
	{
		id = "Halloween",
		name = "Lantern livery",
		earn = "halloween:livery",
		blurb = "Pumpkin tubes and a black hull with a live green glow trim (pumpkin stall).",
		primary = Color3.fromRGB(190, 86, 26), -- pumpkin orange tubes
		secondary = Color3.fromRGB(34, 30, 36), -- black hull
		stripe = Color3.fromRGB(188, 214, 168), -- bone green band
		stripe2 = Color3.fromRGB(188, 214, 168),
		glow = Color3.fromRGB(124, 255, 154), -- lantern green Neon trim
		pattern = "glow",
		metallic = false,
	},
	{
		id = "Winter",
		name = "Festive livery",
		earn = "winter:livery",
		blurb = "Ice-blue tubes and a dark hull strung with warm fairy lights (Frost Fleet stall).",
		primary = Color3.fromRGB(126, 190, 214), -- ice-blue tubes
		secondary = Color3.fromRGB(30, 44, 58), -- deep winter hull
		stripe = Color3.fromRGB(166, 214, 236), -- ice band
		stripe2 = Color3.fromRGB(166, 214, 236),
		glow = Color3.fromRGB(255, 214, 132), -- warm bulb Neon trim
		pattern = "lights",
		metallic = false,
	},
}

-- The monthly liveries: once earned from weekly challenges (data.flags.monthlyLivery = "YYYY-MM",
-- kept in saves); since the challenges were cut (docs/16 C12) Commodore unlocks all twelve
-- (CosmeticLoadout).
local MONTH_NAMES = {
	"January",
	"February",
	"March",
	"April",
	"May",
	"June",
	"July",
	"August",
	"September",
	"October",
	"November",
	"December",
}
local MONTH_PAINT = {
	{ Color3.fromRGB(168, 52, 62), Color3.fromRGB(34, 34, 40) }, -- January, crimson
	{ Color3.fromRGB(44, 78, 150), Color3.fromRGB(30, 32, 44) }, -- February, cobalt
	{ Color3.fromRGB(36, 126, 88), Color3.fromRGB(32, 38, 38) }, -- March, emerald
	{ Color3.fromRGB(96, 116, 150), Color3.fromRGB(32, 36, 46) }, -- April, slate
	{ Color3.fromRGB(200, 104, 40), Color3.fromRGB(32, 32, 36) }, -- May, amber
	{ Color3.fromRGB(118, 146, 60), Color3.fromRGB(30, 34, 30) }, -- June, olive
	{ Color3.fromRGB(132, 74, 150), Color3.fromRGB(34, 32, 44) }, -- July, violet
	{ Color3.fromRGB(214, 184, 120), Color3.fromRGB(34, 34, 36) }, -- August, sand
	{ Color3.fromRGB(164, 92, 70), Color3.fromRGB(34, 30, 32) }, -- September, terracotta
	{ Color3.fromRGB(196, 84, 32), Color3.fromRGB(30, 28, 30) }, -- October, pumpkin
	{ Color3.fromRGB(82, 88, 158), Color3.fromRGB(30, 34, 48) }, -- November, indigo
	{ Color3.fromRGB(40, 120, 118), Color3.fromRGB(32, 38, 40) }, -- December, teal
}
for month, name in MONTH_NAMES do
	local paint = MONTH_PAINT[month]
	local key = string.format("2026-%02d", month)
	table.insert(options, {
		id = "Month" .. key,
		name = name .. " livery",
		earn = "monthly:" .. key,
		blurb = "The " .. name .. " livery, a Commodore's colours.",
		primary = paint[1],
		secondary = paint[2],
		stripe = Color3.fromRGB(230, 214, 172),
		stripe2 = Color3.fromRGB(230, 214, 172),
		pattern = "stripes",
		metallic = true,
	})
end

return {
	slot = "Livery",
	options = options,
	default = "Standard",
}
