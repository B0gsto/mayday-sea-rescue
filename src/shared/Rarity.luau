--!strict
-- Rarity (docs/25 K1): the one rarity language of the game, shared by survivors and the prize wheel.
-- TIERS[i]: the name, the Kit colour key (UI/Kit/Theme gradients, as SpinRules.RARITIES uses) and a flat Color3
-- for world text (survivor name tags). Mythic name tags animate a rainbow on the client.
local Rarity = {}

export type Tier = { name: string, kit: string, color: Color3 }

Rarity.TIERS = {
	{ name = "Common", kit = "disabled", color = Color3.fromHex("D7DBE1") },
	{ name = "Uncommon", kit = "green", color = Color3.fromHex("5BE356") },
	{ name = "Rare", kit = "blue", color = Color3.fromHex("4FB8FF") },
	{ name = "Epic", kit = "purple", color = Color3.fromHex("B07CFF") },
	{ name = "Legendary", kit = "yellow", color = Color3.fromHex("FFC83A") },
	{ name = "Mythic", kit = "pink", color = Color3.fromHex("FF5CB8") },
} :: { Tier }
Rarity.COMMON = 1
Rarity.MYTHIC = #Rarity.TIERS

-- the tier index of a rarity name ("Epic" -> 4), nil if unknown
function Rarity.index(name: string): number?
	for i, t in Rarity.TIERS do
		if t.name == name then
			return i
		end
	end
	return nil
end

return Rarity
