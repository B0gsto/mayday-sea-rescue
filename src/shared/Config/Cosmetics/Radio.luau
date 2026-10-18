--!strict
-- Cosmetics slot "Radio" (RP-M5). In-vehicle music radio station. Others can mute it (Settings: radios).
-- Pass(es): SeaShantyRadio.
-- STUB: placeholder options from the RP-M5 spine; the slot's builder replaces them.
-- Shape: { slot, options = { { id, name, pass = <GamePass key, nil for free>, ...free-form } }, default }.
-- The default must be a free option (pass = nil). A file may also return a list of such slot tables.
type Option = { id: string, name: string, pass: string?, [string]: any }

local options: { Option } = {
	{ id = "Off", name = "Radio off", pass = nil, stub = true },
	{ id = "Shanties", name = "Sea shanties", pass = "SeaShantyRadio", stub = true },
}

return {
	slot = "Radio",
	options = options,
	default = "Off",
}
