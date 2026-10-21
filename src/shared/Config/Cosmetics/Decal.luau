--!strict
-- Cosmetics slot "Decal" (G28 earned rewards): a painted hull-side badge on the player's boat,
-- built by src/server/Cosmetics/Decals as code-made parts (no uploads). Earned only: every option
-- names the flag key it needs in `earn` (src/shared/CosmeticLoadout).
-- Fields: color (badge plate), ring (roundel), markColor, mark (1-2 characters, painted on the ring).
type Option = { id: string, name: string, pass: string?, earn: string?, [string]: any }

local options: { Option } = {
	{ id = "None", name = "No decal", pass = nil },
	{
		id = "Season1",
		name = "Season 1 badge",
		earn = "season:Decal_Season1",
		color = Color3.fromRGB(18, 28, 44), -- near-black navy plate
		ring = Color3.fromRGB(244, 196, 72), -- bright brass roundel
		markColor = Color3.fromRGB(250, 246, 234), -- near-white mark
		mark = "S1",
	},
}

return {
	slot = "Decal",
	options = options,
	default = "None",
}
