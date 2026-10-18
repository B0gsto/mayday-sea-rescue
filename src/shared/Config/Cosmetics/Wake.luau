--!strict
-- Cosmetics slot "Wake" (RP-M5 stream C). The wake trail look of the owner's boats and jet ski,
-- seen by every player (src/client/Ocean/Wake reads the owner's "Cos_Wake" attribute per vehicle).
-- Pass: WakeTrails. All five looks are real-world water: white water, wake spread, prop wash, hull
-- spray, and bioluminescent plankton (Noctiluca, lit only at night). No rainbow, petals, bubbles
-- or sparkles; no docs/05 section 3.2 signal colours.
--
-- `style` fields (all optional; nil = the standard wake, see Wake.visual in src/shared/Boat/Wake):
--   length     trail lifetime multiplier (how far astern the white water lasts)
--   width      foam band width multiplier (the stern attachments' spread)
--   taper      band width at the stern, 0.4..1 (WidthScale at birth; standard 1)
--   spread     how much the band widens as it ages (WidthScale at the tail; standard 2.6)
--   opacity    foam opacity multiplier (1 = standard)
--   hold       0..1, how long the foam stays dense before fading (standard 0.4 of its life)
--   tint       foam colour (hex)
--   bowRate    bow / hull spray particle rate multiplier
--   bowSize    spray particle size multiplier
--   bowSpeed   spray throw speed multiplier
--   bowLife    spray particle lifetime multiplier
--   bowSpread  spray fan angle multiplier
--   glow       night tint (hex) blended in by the night factor; glowEmission its LightEmission
type Option = { id: string, name: string, pass: string?, [string]: any }

local options: { Option } = {
	{ id = "Standard", name = "Standard wake", pass = nil, style = {} },
	{
		id = "LongWhite",
		name = "Long white water",
		pass = "WakeTrails",
		style = {
			length = 1.9,
			opacity = 1.25,
			hold = 0.6,
			taper = 0.7,
			spread = 3.1,
			tint = "#F3F6F5",
		},
	},
	{
		id = "WideFan",
		name = "Wide fan",
		pass = "WakeTrails",
		style = {
			width = 1.7,
			taper = 0.6,
			spread = 4.8,
			length = 1.45,
			opacity = 1.3,
			bowSpread = 1.4,
		},
	},
	{
		id = "DeepChurn",
		name = "Deep churn",
		pass = "WakeTrails",
		-- heavy aerated prop wash: denser and greener-white, narrower and longer held
		style = {
			opacity = 1.45,
			hold = 0.7,
			spread = 1.9,
			length = 1.35,
			taper = 0.8,
			tint = "#E3F1EB",
			bowRate = 1.25,
			bowSize = 1.2,
		},
	},
	{
		id = "Spray",
		name = "Spray",
		pass = "WakeTrails",
		-- more, finer and faster spray off the hull; shorter-lived so the particle count stays low
		style = { bowRate = 1.9, bowSize = 0.6, bowSpeed = 1.8, bowLife = 0.6, bowSpread = 1.2 },
	},
	{
		id = "NightGlow",
		name = "Night glow",
		pass = "WakeTrails",
		-- the standard wake by day; at night a faint blue-green plankton glow in the churned water
		style = { glow = "#46BCCB", glowEmission = 0.45 },
	},
}

return {
	slot = "Wake",
	options = options,
	default = "Standard",
}
