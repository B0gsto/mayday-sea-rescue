--!strict
-- Exercise: Coxswain (docs/09-rescue-operations.md section 9.2 and section 11; docs/03 section
-- 3.1). The all-weather lifeboat's handling assessment: take the heavy boat out, run the marks
-- into wind, find the casualty vessel in the swell and bring 41 tonnes alongside her dead slow.
-- Everything is the live helm mechanics; the lifeboat is the station loaner, so the pass sets the
-- Coxswain certification (which also gates buying the lifeboat).
local Types = require(script.Parent.Parent.Types)

local def: Types.OperationDef = {
	id = "ExerciseCoxswain",
	displayName = "Exercise: Coxswain",
	radioLine = "Haven Rescue, Haven Station. Coxswain exercise, lifeboat away when ready.",
	weight = 0, -- exercises pay the first-pass reward only (ProgressionConfig.ExerciseReward)
	capSeconds = 480,
	isBig = false,
	casualtyKind = "Person",
	states = { Alert = 1 }, -- the casualty is afloat in the vessel's lee: a grab-and-lift recovery
	lifejacketChance = 1,
	takeoverAsset = "Chief Aggie",
	sceneKinds = { "Swimmer" },
	steps = {
		{
			id = "kit_launch",
			label = "Take the lifeboat out",
			realTerm = "Kit and launch",
			role = "Helm",
			mechanicId = "kit_launch",
			gradeBands = {
				{ metric = "kitFit", gold = 1, silver = 0.6, bronze = 0, higherIsBetter = true },
				{ metric = "elapsed", gold = 30, silver = 45, bronze = 70 },
			},
			serverMetrics = { "elapsed" },
			weight = 1,
			timeoutSec = 75,
			onFail = "retry",
			npcAllowed = false,
			tip = "Lifejacket and kill cord on, crew seated, before 41 tonnes moves.",
		},
		{
			id = "passage",
			label = "Run out to the buoy course",
			realTerm = "Passage",
			role = "Helm",
			mechanicId = "passage",
			gradeBands = {
				{ metric = "routeRatio", gold = 1.15, silver = 1.4, bronze = 1.8 },
			},
			weight = 0.5,
			timeoutSec = 150,
			onFail = "continue",
			npcAllowed = false,
			tip = "She carries way: ease off early for the first mark.",
		},
		{
			id = "mark",
			label = "Round the mark into the wind",
			realTerm = "Buoy course",
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
			weight = 1.5,
			timeoutSec = 75,
			onFail = "retry",
			npcAllowed = false,
			tip = "Bow to wind and sea, neutral before the mark: a lifeboat does not stop quickly.",
		},
		{
			id = "find_vessel",
			label = "Find the casualty vessel",
			realTerm = "Search and lookout",
			role = "Navigator",
			mechanicId = "search",
			gradeBands = {
				{ metric = "startError", gold = 30, silver = 60, bronze = 120 },
				{ metric = "lostSight", gold = 0, silver = 1, bronze = 2 },
			},
			weight = 1,
			timeoutSec = 90,
			onFail = "retry",
			npcAllowed = false,
			tip = "Place the search start down-drift, run the pattern and keep eyes on.",
		},
		{
			id = "alongside_vessel",
			label = "Come alongside the casualty vessel",
			realTerm = "Coming alongside",
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
			timeoutSec = 75,
			onFail = "retry",
			npcAllowed = false,
			tip = "Shallow angle, into the wind, dead slow: fenders take the last metre.",
		},
	},
}

return def
