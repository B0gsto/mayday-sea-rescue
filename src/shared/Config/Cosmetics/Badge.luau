--!strict
-- Cosmetics slot "Badge" (RP-M5 E2): the VIP Crew Card's gold nameplate.
-- Pass(es): VipCrewCard. On/off: "Off" (free default, everyone's plain Roblox name) or "Gold"
-- (owners). Owners can switch it off again to hide the gold tag.
-- Drawn by src/client/Cosmetics/VipNameplate.luau (HudTheme.Colors.gold, pale brass).
type Option = { id: string, name: string, pass: string?, [string]: any }

local options: { Option } = {
	{ id = "Off", name = "Hidden", pass = nil },
	{ id = "Gold", name = "Gold nameplate and VIP tag", pass = "VipCrewCard" },
}

return {
	slot = "Badge",
	label = "VIP badge",
	options = options,
	default = "Off",
}
