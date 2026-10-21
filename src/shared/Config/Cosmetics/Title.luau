--!strict
-- Cosmetics slot "Title" (G28 earned rewards): 1-2 words under the player's name tag, drawn by
-- src/client/Cosmetics/TitleTag. Earned only (`earn` = the flag key, src/shared/CosmeticLoadout).
type Option =
	{ id: string, name: string, pass: string?, earn: string?, text: string?, [string]: any }

local options: { Option } = {
	{ id = "None", name = "No title", pass = nil },
	{
		id = "Season1",
		name = "Season 1",
		earn = "season:Title_Season1",
		text = "Season 1",
	},
}

return {
	slot = "Title",
	options = options,
	default = "None",
}
