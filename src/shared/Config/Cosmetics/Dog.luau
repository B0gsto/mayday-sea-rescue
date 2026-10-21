--!strict
-- Cosmetics slot "Dog" (RP-M5, Water Dog Friends): which dog companion follows the player. Bosun is the
-- free default. Every dog has the same abilities (DogService runs the same follow / swim / ride / point
-- for all of them); only the look and the name differ.
-- `coat` (hex) paints the coat of Bosun's code-built rig (Shared.Dog.BosunRig; nil: the black coat).
-- `unfinished` = no real model of that breed exists yet: DogService shows Bosun's rig in another coat as a
-- stand-in, so the pass must stay unsold until real dogs are made.
-- Shape: { slot, options = { { id, name, pass = <GamePass key, nil for free>, ...free-form } }, default }.
type Option = { id: string, name: string, pass: string?, [string]: any }

local options: { Option } = {
	{ id = "Bosun", name = "Bosun", breed = "Newfoundland" },
	{
		id = "Labrador",
		name = "Skipper",
		breed = "Labrador",
		pass = "WaterDogFriends",
		coat = "C9A46A", -- yellow Labrador
		unfinished = true,
	},
	{
		id = "PortugueseWaterDog",
		name = "Biscay",
		breed = "Portuguese Water Dog",
		pass = "WaterDogFriends",
		coat = "4B3527", -- brown
		unfinished = true,
	},
}

return {
	slot = "Dog",
	options = options,
	default = "Bosun",
}
