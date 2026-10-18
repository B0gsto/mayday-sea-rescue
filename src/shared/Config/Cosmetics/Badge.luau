--!strict
-- Cosmetics slot "Badge" (RP-M5). On/off style slot: gold nameplate and radio tag.
-- Pass(es): VipCrewCard.
-- STUB: placeholder options from the RP-M5 spine; the slot's builder replaces them.
-- Shape: { slot, options = { { id, name, pass = <GamePass key, nil for free>, ...free-form } }, default }.
-- The default must be a free option (pass = nil). A file may also return a list of such slot tables.
type Option = { id: string, name: string, pass: string?, [string]: any }

local options: { Option } = {
	{ id = "Off", name = "Off", pass = nil, stub = true },
	{ id = "Gold", name = "Gold nameplate and radio tag", pass = "VipCrewCard", stub = true },
}

return {
	slot = "Badge",
	options = options,
	default = "Off",
}
