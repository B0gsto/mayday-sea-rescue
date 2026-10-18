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
type Option = { id: string, name: string, pass: string?, [string]: any }

local options: { Option } = {
	{ id = "Standard", name = "Station issue", pass = nil },
	{
		id = "StationOrange",
		name = "Station Orange",
		pass = "StarterKit",
		blurb = "Deep lifeboat-station orange with a navy band.",
		primary = Color3.fromRGB(214, 86, 20), -- deep RNLI-style orange, darker than Hull Orange
		secondary = Color3.fromRGB(176, 64, 14), -- burnt orange lower hull
		stripe = Color3.fromRGB(20, 40, 75), -- navy band
		stripe2 = Color3.fromRGB(214, 86, 20), -- navy and orange checks on the cars (white is too close to retro silver)
		metallic = false,
	},
	{
		id = "StormChaser",
		name = "Storm Chaser",
		pass = "StormChaserLiveries",
		blurb = "Storm-blue slate with a silver band and slate frames.",
		primary = Color3.fromRGB(79, 98, 117), -- storm slate blue
		secondary = Color3.fromRGB(54, 70, 90), -- dark storm slate
		stripe = Color3.fromRGB(172, 178, 184), -- silver (well below retroreflective tape)
		stripe2 = Color3.fromRGB(54, 70, 90),
		trim = Color3.fromRGB(58, 69, 82), -- A-frame and helm console
		metallic = true,
	},
	{
		id = "VipGold",
		name = "VIP Gold",
		pass = "VipCrewCard",
		blurb = "Champagne gold with a dark navy band and gunmetal frames.",
		primary = Color3.fromRGB(201, 162, 74), -- champagne gold
		secondary = Color3.fromRGB(166, 124, 46), -- deep gold lower hull
		stripe = Color3.fromRGB(14, 27, 51), -- dark navy band
		stripe2 = Color3.fromRGB(184, 146, 63),
		trim = Color3.fromRGB(43, 47, 54), -- gunmetal A-frame and helm console
		metallic = true,
	},
}

return {
	slot = "Livery",
	options = options,
	default = "Standard",
}
