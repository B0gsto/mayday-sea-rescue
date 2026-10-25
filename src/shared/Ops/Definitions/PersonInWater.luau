--!strict
-- Operation 1: Person in the Water (docs/09-rescue-operations.md section 5.1, docs/16 K1). Data only.
-- Absorbs the old Swimmer and DriftingCraft calls as scenes: a swimmer, or a dinghy drifting with
-- one or two aboard. The plan is SimpleSteps. Running out of time (condition Critical or the cap)
-- still pays: the call is graded Bronze.
local SimpleSteps = require(script.Parent.SimpleSteps)
local Types = require(script.Parent.Parent.Types)

local def: Types.OperationDef = {
	id = "PersonInWater",
	displayName = "Person in the Water",
	weight = 1.0,
	capSeconds = 720,
	isBig = false,
	casualtyKind = "Person",
	states = { Alert = 0.4, Panicking = 0.2, Exhausted = 0.2, VeryCold = 0.15, Unresponsive = 0.05 },
	lifejacketChance = 0.6,
	sceneKinds = { "Swimmer", "DriftingCraft" },
	steps = SimpleSteps("Answer the call quickly; every second counts in the water."),
}

return def
