--!strict
-- Stranded Ashore (docs/23 e.3, (h) "Land calls"). Data only. Cut off by the tide, on a ledge or lost
-- inland: run the craft to the beach marker, walk to them, they follow you back aboard (server/Ops/LandRescue).
-- Same SimpleSteps plan: the recovery step ends when they climb aboard.
local SimpleSteps = require(script.Parent.SimpleSteps)
local Types = require(script.Parent.Parent.Types)

local def: Types.OperationDef = {
	id = "Stranded",
	displayName = "Stranded Ashore",
	radioLine = "Haven Rescue, Gale Isles Coastguard. Walker cut off on the shore, one casualty. Over.",
	weight = 1.3, -- tune
	capSeconds = 720,
	isBig = false,
	casualtyKind = "Person",
	states = { Alert = 0.6, Exhausted = 0.4 }, -- they have to walk
	lifejacketChance = 0,
	takeoverAsset = "Rescue Gale One",
	sceneKinds = { "Stranded" },
	steps = SimpleSteps("Answer the Coastguard quickly; the tide will not wait."),
}

return def
