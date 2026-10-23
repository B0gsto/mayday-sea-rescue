--!strict
-- Operation 8.5: Cliff Casualty (docs/09-rescue-operations.md section 8.5, docs/16 K1). Data only.
-- A walker slipped off the ledge at the foot of Haven Head and is in the surf below the cliff: open
-- water, so the waves make holding steady the hard part. The plan is SimpleSteps (sea side only).
local SimpleSteps = require(script.Parent.SimpleSteps)
local Types = require(script.Parent.Parent.Types)

local def: Types.OperationDef = {
	id = "CliffCasualty",
	displayName = "Cliff Casualty",
	radioLine = "Haven Rescue, Gale Isles Coastguard. Walker in the water below Haven Head, one casualty. Over.",
	weight = 1.4,
	capSeconds = 600,
	isBig = false,
	casualtyKind = "Person",
	states = { Exhausted = 0.5, VeryCold = 0.3, Alert = 0.2 },
	lifejacketChance = 0,
	takeoverAsset = "Rescue Gale One",
	sceneKinds = { "Cliff" },
	steps = SimpleSteps(
		"Answer the Coastguard quickly; the surf under the cliff is no place to wait."
	),
}

return def
