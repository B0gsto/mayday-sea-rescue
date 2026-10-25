--!strict
-- Operation: rip-current rescue (docs/09-rescue-operations.md section 8.4, docs/16 K1). Data only.
-- A swimmer or body-boarder caught in the rip off the hub beach is carried seaward while you come: the
-- rip (shared/RipCurrent) is the drift. The plan is SimpleSteps; they climb aboard like any swimmer.
local SimpleSteps = require(script.Parent.SimpleSteps)
local Types = require(script.Parent.Parent.Types)

local def: Types.OperationDef = {
	id = "RipCurrent",
	displayName = "Rip Current",
	weight = 0.9, -- docs/02 section 3
	capSeconds = 600,
	isBig = false,
	casualtyKind = "Person",
	states = {
		Alert = 0.45,
		Panicking = 0.25,
		Exhausted = 0.2,
		VeryCold = 0.07,
		Unresponsive = 0.03,
	},
	lifejacketChance = 0.35,
	sceneKinds = { "RipCurrent" },
	steps = SimpleSteps("Answer the call quickly; the rip keeps taking them out."),
}

return def
