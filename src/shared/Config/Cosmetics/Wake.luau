--!strict
-- Cosmetics slot "Wake" (RP-M5). Boat and jet ski wake trail look.
-- Pass(es): WakeTrails.
-- STUB: placeholder options from the RP-M5 spine; the slot's builder replaces them.
-- Shape: { slot, options = { { id, name, pass = <GamePass key, nil for free>, ...free-form } }, default }.
-- The default must be a free option (pass = nil). A file may also return a list of such slot tables.
type Option = { id: string, name: string, pass: string?, [string]: any }

local options: { Option } = {
	{ id = "Standard", name = "Standard wake", pass = nil, stub = true },
	{ id = "Long", name = "Long white wake", pass = "WakeTrails", stub = true },
}

return {
	slot = "Wake",
	options = options,
	default = "Standard",
}
