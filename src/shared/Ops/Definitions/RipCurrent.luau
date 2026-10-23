--!strict
-- Operation: rip-current rescue (docs/09-rescue-operations.md section 8.4, docs/16 K1). Data only.
-- A swimmer or body-boarder caught in the rip off Haven Sands is carried seaward while you come: the
-- rip (shared/RipCurrent) is the drift. The plan is SimpleSteps; they climb aboard like any swimmer.
local SimpleSteps = require(script.Parent.SimpleSteps)
local Types = require(script.Parent.Parent.Types)

local def: Types.OperationDef = {
	id = "RipCurrent",
	displayName = "Rip Current",
	radioLine = "Haven Rescue, Gale Isles Coastguard. Swimmer caught in a rip current off Haven Sands, request you launch.",
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
	takeoverAsset = "Rescue Gale One",
	sceneKinds = { "RipCurrent" },
	steps = SimpleSteps(
		"Answer the Coastguard quickly; the rip keeps taking them out while you talk."
	),
}

return def
