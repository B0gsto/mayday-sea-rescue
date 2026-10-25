--!strict
-- Operation: Wildlife Rescue (docs/15 section 2, hook H4; docs/16 K16). Data only.
-- A seal pup in a net, a puffin in oil, an otter, a turtle or a gull in line: a swimmer scene that
-- SanctuaryService dresses as the animal. The plan is SimpleSteps: get near and steady, it climbs
-- aboard (the net drops), rides home on your craft and goes to the sanctuary to recover as a pet.
local SimpleSteps = require(script.Parent.SimpleSteps)
local Types = require(script.Parent.Parent.Types)

local def: Types.OperationDef = {
	id = "WildlifeRescue",
	displayName = "Wildlife Rescue",
	weight = 0.8, -- a light call (docs/02 section 3: x0.8) -- tune
	capSeconds = 420,
	isBig = false,
	casualtyKind = "Person",
	states = { Alert = 1 },
	lifejacketChance = 0,
	sceneKinds = { "Swimmer" },
	steps = SimpleSteps("Answer the call quickly; the animal is tangled and tiring."),
}

return def
