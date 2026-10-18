--!strict
-- Cosmetics slots for what the dog wears (RP-M5, Bosun's Wardrobe), one slot per thing worn:
--   DogBandana  six cotton bandanas folded on the chest
--   DogJacket   a dog life jacket (replaces the harness while worn)
-- Not shipped (RP-M5 art review): harness colours (`harness` below; a tint on the black-coated dog's
-- harness is barely visible in play) and the captain's hat (`hat`; did not read on his head). DogService
-- and Shared.Dog.DogWear still support slots DogHarness / DogHat: add them to the returned list to ship.
-- `look` is the key in src/shared/Dog/DogWear.luau. Pass: BosunsWardrobe. Coat colours were dropped: the
-- uploaded coat is black and a SurfaceAppearance tint can only darken it.
-- Shape: { slot, options = { { id, name, pass = <GamePass key, nil for free>, ...free-form } }, default }.
type Option = { id: string, name: string, pass: string?, [string]: any }

local PASS = "BosunsWardrobe"

local harness: { Option } = {
	{ id = "Duty", name = "Duty harness", look = "Duty" },
	{ id = "Navy", name = "Navy harness", pass = PASS, look = "Navy" },
	{ id = "Forest", name = "Forest harness", pass = PASS, look = "Forest" },
	{ id = "Burgundy", name = "Burgundy harness", pass = PASS, look = "Burgundy" },
	{ id = "Teal", name = "Teal harness", pass = PASS, look = "Teal" },
}

local bandana: { Option } = {
	{ id = "None", name = "No bandana", look = "None" },
	{ id = "Red", name = "Red bandana", pass = PASS, look = "Red" },
	{ id = "Navy", name = "Navy bandana", pass = PASS, look = "Navy" },
	{ id = "Forest", name = "Forest bandana", pass = PASS, look = "Forest" },
	{ id = "Burgundy", name = "Burgundy bandana", pass = PASS, look = "Burgundy" },
	{ id = "Chambray", name = "Chambray bandana", pass = PASS, look = "Chambray" },
	{ id = "Mustard", name = "Mustard bandana", pass = PASS, look = "Mustard" },
}

local jacket: { Option } = {
	{ id = "None", name = "No life jacket", look = "None" },
	{ id = "LifeJacket", name = "Dog life jacket", pass = PASS, look = "LifeJacket" },
}

local hat: { Option } = {
	{ id = "None", name = "No hat", look = "None" },
	{ id = "CaptainsHat", name = "Captain's hat", pass = PASS, look = "CaptainsHat" },
}

local _unshipped = { harness = harness, hat = hat }

return {
	{ slot = "DogBandana", options = bandana, default = "None" },
	{ slot = "DogJacket", options = jacket, default = "None" },
}
