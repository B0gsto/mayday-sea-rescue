--!strict
-- Cosmetics slot "Horn" (RP-M5). Vehicle horn sound (boats and cars). Played through the Cosmetics_Action channel; others can mute it (Settings: horns).
-- Pass(es): HornPack.
-- STUB: placeholder options from the RP-M5 spine; the slot's builder replaces them.
-- Shape: { slot, options = { { id, name, pass = <GamePass key, nil for free>, ...free-form } }, default }.
-- The default must be a free option (pass = nil). A file may also return a list of such slot tables.
type Option = { id: string, name: string, pass: string?, [string]: any }

local options: { Option } = {
	{ id = "Standard", name = "Standard horn", pass = nil, stub = true },
	{ id = "AirHorn", name = "Twin-trumpet air horn", pass = "HornPack", stub = true },
}

return {
	slot = "Horn",
	options = options,
	default = "Standard",
}
