--!strict
-- Cosmetics slot "LightBar" (RP-M5 stream B). LED emergency light bar colour sets for the RIB and
-- the jet ski (a small mast-top beacon). Pass: LightBars.
-- The free default "Stock" keeps each vehicle's own lighting: a single blue LED beacon on the RIB's A-frame (as on a real RNLI or
-- coastguard RIB), nothing on the jet ski.
--
-- Option fields (read by server/Cosmetics/LightBars and the pure shared/LightBarFlash):
--   half      lamp colours (keys of `colors`) for one half of the bar, from the outer end inwards,
--             repeated to fill the half and mirrored on the other half
--   invert    colours that flash in the opposite half's timing (interleaved two-colour sets)
--   steady    colours that stay lit while the lights are on (white work / scene lights)
--   pattern   flash pattern with no siren running (LightBarFlash.Patterns)
-- Colours are real LED emitter colours. None is a docs/05 section 3.2 reserved signal colour: no red,
-- and amber (about 590 nm) sits well clear of Hull Orange and SOLAS Orange in hue (tests/LightBars.spec).
type Option = { id: string, name: string, pass: string?, [string]: any }

local colors: { [string]: Color3 } = {
	Blue = Color3.fromRGB(28, 82, 255), -- 465 nm LED blue
	White = Color3.fromRGB(232, 238, 255), -- cool white LED flasher
	Amber = Color3.fromRGB(255, 150, 12), -- 590 nm amber (Neon renders it lighter; kept off hi-vis yellow)
	Work = Color3.fromRGB(255, 244, 226), -- neutral white work / scene light, steady
}

local options: { Option } = {
	{ id = "Stock", name = "Stock lights", pass = nil, stock = true },
	{
		id = "Blue",
		name = "Blue LED",
		pass = "LightBars",
		half = { "Blue" },
		pattern = "Alternate",
	},
	{
		id = "BlueWhite",
		name = "Blue and white",
		pass = "LightBars",
		half = { "Blue", "White" },
		invert = { "White" },
		pattern = "Alternate",
	},
	{
		id = "Amber",
		name = "Amber LED",
		pass = "LightBars",
		half = { "Amber" },
		pattern = "Alternate",
	},
	{
		id = "AmberWhite",
		name = "Amber and white",
		pass = "LightBars",
		half = { "Amber", "White" },
		invert = { "White" },
		pattern = "Alternate",
	},
	{
		id = "BlueAmber",
		name = "Blue and amber",
		pass = "LightBars",
		half = { "Blue", "Amber" },
		invert = { "Amber" },
		pattern = "Alternate",
	},
	{
		id = "WorkAmber",
		name = "Amber with white work lights",
		pass = "LightBars",
		half = { "Amber", "Work" },
		steady = { "Work" },
		pattern = "Alternate",
	},
	{
		id = "StockAmber",
		name = "Amber bar",
		earn = "stock:lightbar_amber",
		half = { "Amber" },
		pattern = "Alternate",
	},
	{
		id = "StockBlue",
		name = "Blue bar",
		earn = "stock:lightbar_blue",
		half = { "Blue" },
		pattern = "Alternate",
	},
}

-- Mount points in HullRoot space (studs). RIB: the asset's modelled light bar on the forward edge of
-- the A-frame radar platform (art/source/vehicles/M_Veh_RIB/build.py: 2.0 x 0.18 x 0.2 at blender
-- (0, AF_BASE - 0.56, AF_TOP + 0.29), plus Boat/Builder.RIB_ORIGIN); the cosmetic bar encloses it.
-- The stock beacon sits over the modelled blue beacon dome (ATT_Beacon + RIB_ORIGIN). Jet ski: on top
-- of the stern mast's all-round white light (ATT_NavMasthead + JETSKI_ORIGIN, raised).
local mounts = {
	RIB = {
		bar = CFrame.new(0, 6.38, 9.59),
		barSize = Vector3.new(2.5, 0.26, 0.27), -- wider than the modelled 2.0 bar, clear of the beacon and masthead light
		beacon = CFrame.new(-1.25, 6.55, 10.1),
		beaconSize = Vector3.new(0.27, 0.4, 0.27),
	},
	JetSki = {
		beacon = CFrame.new(0, 2.74, 4.85),
		beaconSize = Vector3.new(0.24, 0.42, 0.24),
	},
}

return {
	slot = "LightBar",
	options = options,
	default = "Stock",
	colors = colors,
	mounts = mounts,
	stockBeacon = { color = "Blue", pattern = "Alternate" }, -- the RIB's free beacon
}
