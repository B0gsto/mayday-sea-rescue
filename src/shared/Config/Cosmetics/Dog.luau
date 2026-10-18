--!strict
-- Cosmetics slot "Dog" (RP-M5, Water Dog Friends): which dog companion follows the player. Bosun is the
-- free default. Every dog has the same abilities (DogService runs the same follow / swim / ride / point
-- for all of them); only the look and the name differ.
-- `fur` false drops the long Newfoundland fur cards from the rig. `unfinished` = no real model of that
-- breed exists yet (there are no Labrador / Portuguese Water Dog meshes): DogService shows Bosun's rig as
-- a stand-in, so the pass must stay unsold until real dogs are made.
-- Shape: { slot, options = { { id, name, pass = <GamePass key, nil for free>, ...free-form } }, default }.
type Option = { id: string, name: string, pass: string?, [string]: any }

local options: { Option } = {
	{ id = "Bosun", name = "Bosun", breed = "Newfoundland", fur = true },
	{
		id = "Labrador",
		name = "Skipper",
		breed = "Labrador",
		pass = "WaterDogFriends",
		fur = true, -- dropping the fur cards read as a shaved Bosun (RP-M5 review), not a Labrador
		unfinished = true,
	},
	{
		id = "PortugueseWaterDog",
		name = "Biscay",
		breed = "Portuguese Water Dog",
		pass = "WaterDogFriends",
		fur = true,
		unfinished = true,
	},
}

return {
	slot = "Dog",
	options = options,
	default = "Bosun",
}
