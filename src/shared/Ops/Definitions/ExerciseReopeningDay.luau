--!strict
-- Exercise: the Reopening Day drill (docs/09-rescue-operations.md section 9.2), the old
-- first-minute drill moved after the cold open. A manikin on a line off the slipway: read it, pick
-- the throw bag, aim with the wind (the bag drifts downwind in flight), throw, then the two-hand
-- haul and the lift on three. About 25 s. It cannot be failed: a miss is coiled back and rethrown,
-- and the step always completes (onFail "continue", Bronze at worst). No certification.
local Types = require(script.Parent.Parent.Types)

local def: Types.OperationDef = {
	id = "ExerciseReopeningDay",
	displayName = "Reopening Day drill",
	radioLine = "Haven Rescue, Haven Station. Reopening Day drill: manikin on the line off the slip.",
	weight = 0,
	capSeconds = 180,
	isBig = false,
	casualtyKind = "Person",
	states = { Alert = 1 }, -- the manikin "grips": the throw-bag recovery
	lifejacketChance = 1,
	takeoverAsset = "Chief Aggie",
	sceneKinds = { "Swimmer" },
	steps = {
		{
			id = "recovery",
			label = "Throw the bag and haul them in",
			realTerm = "Throw-bag recovery",
			role = "Crew",
			mechanicId = "recover_throwbag",
			gradeBands = {
				{ metric = "rightMethod", gold = 1, silver = 1, bronze = 0, higherIsBetter = true },
				{ metric = "score", gold = 0.8, silver = 0.5, bronze = 0.2, higherIsBetter = true },
			},
			weight = 1,
			timeoutSec = 90,
			onFail = "continue", -- the drill cannot be failed
			npcAllowed = false,
			effect = "board",
			tip = "Aim upwind of them: the wind carries the bag the rest of the way.",
		},
	},
}

return def
