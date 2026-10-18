--!strict
-- Exercise: Boat handling (docs/09-rescue-operations.md section 9.2; the Helm certification,
-- section 11). Data only, built from the live mechanics. At the station with Chief Aggie: kit up
-- and launch, run out to the training buoy, pick it up from downwind, then Aggie throws the
-- manikin over the side ("Man overboard!"): keep eyes on it, turn back, come in from downwind and
-- get it aboard, and finish by bringing the boat alongside the pontoon. The man-overboard drill
-- follows the RYA / RNLI routine (research/rescue-procedures.md 2a): shout, point, never look
-- away, come back under control into the wind.
local Types = require(script.Parent.Parent.Types)

local def: Types.OperationDef = {
	id = "ExerciseBoatHandling",
	displayName = "Exercise: Boat handling",
	radioLine = "Haven Rescue, Haven Station. Boat handling exercise, launch when ready.",
	weight = 0, -- exercises pay the first-pass reward only (ProgressionConfig.ExerciseReward)
	capSeconds = 420,
	isBig = false,
	casualtyKind = "Person",
	states = { Alert = 1 }, -- the manikin floats face up: a grab-and-lift recovery
	lifejacketChance = 1,
	takeoverAsset = "Chief Aggie",
	sceneKinds = { "Swimmer" }, -- the manikin is a swimmer scene off the slipway
	steps = {
		{
			id = "kit_launch",
			label = "Kit up and launch",
			realTerm = "Kit and launch",
			role = "Helm",
			mechanicId = "kit_launch",
			gradeBands = {
				{ metric = "kitFit", gold = 1, silver = 0.6, bronze = 0, higherIsBetter = true },
				{ metric = "elapsed", gold = 25, silver = 35, bronze = 60 },
			},
			serverMetrics = { "elapsed" },
			weight = 1,
			timeoutSec = 60,
			onFail = "retry",
			npcAllowed = false,
			tip = "Lifejacket and kill cord on before the boat leaves the slip.",
		},
		{
			id = "passage",
			label = "Run out to the training buoy",
			realTerm = "Passage",
			role = "Helm",
			mechanicId = "passage",
			gradeBands = {
				{ metric = "routeRatio", gold = 1.15, silver = 1.4, bronze = 1.8 },
				{ metric = "etaError", gold = 0.3, silver = 0.5, bronze = 0.8 },
			},
			weight = 1,
			timeoutSec = 120,
			onFail = "continue",
			npcAllowed = false,
			tip = "Keep the speed down inside the harbour; the wash hits every moored boat.",
		},
		{
			id = "approach",
			label = "Pick up the buoy from downwind",
			realTerm = "Approach",
			role = "Helm",
			mechanicId = "approach",
			gradeBands = {
				{ metric = "overSpeedSec", gold = 0.5, silver = 2, bronze = 5 },
				{ metric = "neutralDistance", gold = 8, silver = 12, bronze = 20 },
				{
					metric = "fromDownwind",
					gold = 1,
					silver = 1,
					bronze = 0,
					higherIsBetter = true,
				},
			},
			allowedEvents = { wash = 2 },
			weight = 2,
			timeoutSec = 60,
			onFail = "retry",
			npcAllowed = false,
			tip = "Stem the wind: come up to the buoy heading into it, and neutral before you reach it.",
		},
		{
			id = "mob_spot",
			label = "Man overboard: point and keep eyes on",
			realTerm = "Man overboard: spotter",
			role = "Navigator",
			mechanicId = "search",
			gradeBands = {
				{ metric = "startError", gold = 30, silver = 60, bronze = 120 },
				{ metric = "lostSight", gold = 0, silver = 1, bronze = 2 },
			},
			weight = 1,
			timeoutSec = 60,
			onFail = "retry",
			npcAllowed = false,
			tip = "Shout, point and never take your eyes off them; a head in a swell vanishes in seconds.",
		},
		{
			id = "mob_approach",
			label = "Turn back and come in from downwind",
			realTerm = "Man overboard turn",
			role = "Helm",
			mechanicId = "approach",
			gradeBands = {
				{ metric = "overSpeedSec", gold = 0.5, silver = 2, bronze = 5 },
				{ metric = "neutralDistance", gold = 8, silver = 12, bronze = 20 },
				{
					metric = "fromDownwind",
					gold = 1,
					silver = 1,
					bronze = 0,
					higherIsBetter = true,
				},
			},
			allowedEvents = { wash = 2 },
			weight = 2,
			timeoutSec = 60,
			onFail = "retry",
			npcAllowed = false,
			tip = "Turn towards the side they fell from to swing the propeller clear, then come back up into the wind.",
		},
		{
			id = "mob_recovery",
			label = "Get the manikin aboard",
			realTerm = "Man overboard recovery",
			role = "Crew",
			mechanicId = "recover_throwbag",
			gradeBands = {
				{ metric = "rightMethod", gold = 1, silver = 1, bronze = 0, higherIsBetter = true },
				{ metric = "score", gold = 0.8, silver = 0.5, bronze = 0.2, higherIsBetter = true },
			},
			allowedEvents = { wrongHandling = 1 },
			weight = 1,
			timeoutSec = 60,
			onFail = "retry",
			npcAllowed = false,
			effect = "board",
			tip = "Engine in neutral before anyone reaches over the side.",
		},
		{
			id = "alongside",
			label = "Come alongside the pontoon",
			realTerm = "Coming alongside",
			role = "Helm",
			mechanicId = "berth",
			noTow = true, -- our own boat alone: lines to the pontoon, no lashed pair to release
			gradeBands = {
				{ metric = "contactSpeed", gold = 2, silver = 4, bronze = 8 },
				{ metric = "lineInWater", gold = 0, silver = 0, bronze = 1 },
				{
					metric = "lineOrderRight",
					gold = 1,
					silver = 1,
					bronze = 0,
					higherIsBetter = true,
				},
			},
			weight = 2,
			timeoutSec = 90,
			onFail = "retry",
			npcAllowed = false,
			effect = "deliver",
			tip = "A shallow angle and the slow mark: let the boat kiss the pontoon, then bow line first.",
		},
	},
}

return def
