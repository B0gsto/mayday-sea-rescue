--!strict
-- Cosmetics slot "Outfit" (RP-M5). Player uniform.
-- Pass(es): CaptainsLocker / StormChaserLiveries.
-- STUB: placeholder options from the RP-M5 spine; the slot's builder replaces them.
-- Shape: { slot, options = { { id, name, pass = <GamePass key, nil for free>, ...free-form } }, default }.
-- The default must be a free option (pass = nil). A file may also return a list of such slot tables.
type Option = { id: string, name: string, pass: string?, [string]: any }

local options: { Option } = {
	{ id = "Station", name = "Station uniform", pass = nil, stub = true },
	{ id = "Captain", name = "Captain's uniform", pass = "CaptainsLocker", stub = true },
	{
		id = "StormChaser",
		name = "Storm Chaser uniform",
		pass = "StormChaserLiveries",
		stub = true,
	},
}

return {
	slot = "Outfit",
	options = options,
	default = "Station",
}
