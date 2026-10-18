--!strict
-- Cosmetics slot "LightBar" (RP-M5). Light bar flash set and pattern (cars and RIB). Must not use docs/05 section 3.2 reserved signal colours.
-- Pass(es): LightBars.
-- STUB: placeholder options from the RP-M5 spine; the slot's builder replaces them.
-- Shape: { slot, options = { { id, name, pass = <GamePass key, nil for free>, ...free-form } }, default }.
-- The default must be a free option (pass = nil). A file may also return a list of such slot tables.
type Option = { id: string, name: string, pass: string?, [string]: any }

local options: { Option } = {
	{ id = "Standard", name = "Standard blue", pass = nil, stub = true },
	{ id = "Alternate", name = "Alternate flash pattern", pass = "LightBars", stub = true },
}

return {
	slot = "LightBar",
	options = options,
	default = "Standard",
}
