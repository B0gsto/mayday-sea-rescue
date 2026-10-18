--!strict
-- Cosmetics slot "DogWear" (RP-M5). Dog coat / bandana. May be split into DogCoat and DogBandana: return a list of slot tables from this file.
-- Pass(es): BosunsWardrobe.
-- STUB: placeholder options from the RP-M5 spine; the slot's builder replaces them.
-- Shape: { slot, options = { { id, name, pass = <GamePass key, nil for free>, ...free-form } }, default }.
-- The default must be a free option (pass = nil). A file may also return a list of such slot tables.
type Option = { id: string, name: string, pass: string?, [string]: any }

local options: { Option } = {
	{ id = "None", name = "No coat", pass = nil, stub = true },
	{ id = "Coat", name = "Dog coat", pass = "BosunsWardrobe", stub = true },
}

return {
	slot = "DogWear",
	options = options,
	default = "None",
}
