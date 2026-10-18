--!strict
-- Cosmetics slot "Siren" (RP-M5). Emergency siren tone (cars with a siren). Others can mute it (Settings: sirens).
-- Pass(es): SirenPack.
-- STUB: placeholder options from the RP-M5 spine; the slot's builder replaces them.
-- Shape: { slot, options = { { id, name, pass = <GamePass key, nil for free>, ...free-form } }, default }.
-- The default must be a free option (pass = nil). A file may also return a list of such slot tables.
type Option = { id: string, name: string, pass: string?, [string]: any }

local options: { Option } = {
	{ id = "Standard", name = "Standard two-tone", pass = nil, stub = true },
	{ id = "Yelp", name = "Yelp", pass = "SirenPack", stub = true },
}

return {
	slot = "Siren",
	options = options,
	default = "Standard",
}
