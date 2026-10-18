--!strict
-- Cosmetics slot "Livery" (RP-M5). Vehicle livery (boats, jet ski, cars).
-- Pass(es): VipCrewCard / StormChaserLiveries / StarterKit.
-- STUB: placeholder options from the RP-M5 spine; the slot's builder replaces them.
-- Shape: { slot, options = { { id, name, pass = <GamePass key, nil for free>, ...free-form } }, default }.
-- The default must be a free option (pass = nil). A file may also return a list of such slot tables.
type Option = { id: string, name: string, pass: string?, [string]: any }

local options: { Option } = {
	{ id = "Standard", name = "Standard livery", pass = nil, stub = true },
	{ id = "StationOrange", name = "Station Orange", pass = "StarterKit", stub = true },
	{ id = "StormChaser", name = "Storm Chaser", pass = "StormChaserLiveries", stub = true },
	{ id = "VipGold", name = "VIP trim", pass = "VipCrewCard", stub = true },
}

return {
	slot = "Livery",
	options = options,
	default = "Standard",
}
