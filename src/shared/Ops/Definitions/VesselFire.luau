--!strict
-- Operation: Vessel Fire (docs/09-rescue-operations.md section 8.2, docs/16 K1). Data only.
-- A motor cruiser burns at anchor (src/server/Ops/FireScene, spectacle only: flames, smoke downwind);
-- the two people aboard jumped and are in the water beside her, tiring fast
-- (OperationService.FAST_TIRING). The plan is SimpleSteps.
local SimpleSteps = require(script.Parent.SimpleSteps)
local Types = require(script.Parent.Parent.Types)

local def: Types.OperationDef = {
	id = "VesselFire",
	displayName = "Vessel Fire",
	weight = 1.5, -- docs/02 section 3: all but Calm Bay, x1.5
	capSeconds = 600,
	isBig = false,
	casualtyKind = "Person",
	states = { Alert = 0.5, Panicking = 0.3, Exhausted = 0.2 },
	lifejacketChance = 1,
	sceneKinds = { "VesselFire" },
	steps = SimpleSteps("Answer the MAYDAY at once: smoke and cold water wear them down fast."),
}

return def
