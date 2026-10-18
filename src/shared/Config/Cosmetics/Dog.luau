--!strict
-- Cosmetics slot "Dog" (RP-M5). Which dog companion follows the player. Bosun is the free default.
-- Pass(es): WaterDogFriends.
-- STUB: placeholder options from the RP-M5 spine; the slot's builder replaces them.
-- Shape: { slot, options = { { id, name, pass = <GamePass key, nil for free>, ...free-form } }, default }.
-- The default must be a free option (pass = nil). A file may also return a list of such slot tables.
type Option = { id: string, name: string, pass: string?, [string]: any }

local options: { Option } = {
	{ id = "Bosun", name = "Bosun", pass = nil, stub = true },
	{ id = "Labrador", name = "Labrador", pass = "WaterDogFriends", stub = true },
}

return {
	slot = "Dog",
	options = options,
	default = "Bosun",
}
