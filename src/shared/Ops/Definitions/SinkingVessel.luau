--!strict
-- Operation 8.1: Sinking Vessel (docs/09-rescue-operations.md section 8.1, docs/16 K1). Data only.
-- A fishing boat lists and settles off the harbour (src/server/Ops/SinkingScene, spectacle only); her
-- three crew are in the water beside her and tire fast in the cold (OperationService.FAST_TIRING).
-- The plan is SimpleSteps: a jet ski takes one at a time, a RIB the lot.
local SimpleSteps = require(script.Parent.SimpleSteps)
local Types = require(script.Parent.Parent.Types)

local def: Types.OperationDef = {
	id = "SinkingVessel",
	displayName = "Sinking Vessel",
	weight = 1.2,
	capSeconds = 480,
	isBig = false,
	casualtyKind = "Person",
	states = { Alert = 0.5, Exhausted = 0.3, VeryCold = 0.2 },
	lifejacketChance = 1,
	sceneKinds = { "Sinking" },
	steps = SimpleSteps(),
}

return def
