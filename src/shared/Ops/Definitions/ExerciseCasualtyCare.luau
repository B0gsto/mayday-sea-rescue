--!strict
-- Exercise: Casualty care (docs/09-rescue-operations.md section 9.2; the Casualty Care
-- certification, section 11). Data only, built from the live medical mechanics. On the station
-- floor Chief Aggie sets up the training manikin and reads its signs aloud as a scenario ("just
-- pulled out of the harbour"); the scenario is rolled, so the right answers change between runs:
-- a very cold casualty (shelter, wrap, keep flat), an exhausted one (recovery position, oxygen) or
-- an unresponsive one without a lifejacket who is not breathing (CPR at 30:2). Then the ATMIST
-- handover to Aggie playing the paramedic.
local Types = require(script.Parent.Parent.Types)

local def: Types.OperationDef = {
	id = "ExerciseCasualtyCare",
	displayName = "Exercise: Casualty care",
	radioLine = "Haven Rescue, Haven Station. Casualty care exercise on the station floor.",
	weight = 0,
	capSeconds = 300,
	isBig = false,
	casualtyKind = "Person",
	-- the manikin scenario; Unresponsive without a lifejacket is "not breathing normally" (CPR)
	states = { VeryCold = 0.35, Exhausted = 0.25, Unresponsive = 0.4 },
	lifejacketChance = 0.3,
	takeoverAsset = "Chief Aggie",
	sceneKinds = { "Swimmer" },
	steps = {
		{
			id = "survey",
			label = "Check the manikin over",
			realTerm = "Primary survey (DR ABCDE)",
			role = "Medic",
			mechanicId = "primary_survey",
			gradeBands = {
				{ metric = "correct", gold = 1, silver = 0.8, bronze = 0.5, higherIsBetter = true },
				{ metric = "elapsed", gold = 25, silver = 35, bronze = 50 },
			},
			serverMetrics = { "elapsed" },
			weight = 2,
			timeoutSec = 50,
			onFail = "retry",
			npcAllowed = false,
			effect = "survey",
			tip = "Danger and Response first, then Airway and Breathing: watch the chest for a full five seconds.",
		},
		{
			id = "treatment",
			label = "Treat what you found",
			realTerm = "Treatment (position, oxygen, CPR)",
			role = "Medic",
			mechanicId = "treat",
			gradeBands = {
				{
					metric = "matches",
					gold = 1,
					silver = 0.75,
					bronze = 0.5,
					higherIsBetter = true,
				},
			},
			allowedEvents = { harmfulTreatment = 2, wrongHandling = 1 },
			weight = 2,
			timeoutSec = 90, -- CPR runs two full 30:2 cycles inside the step
			onFail = "retry",
			npcAllowed = false,
			effect = "treat",
			tip = "Not breathing normally means CPR straight away: 30 compressions, 2 breaths, at 100 to 120 a minute.",
		},
		{
			id = "handover",
			label = "Hand over to the paramedic",
			realTerm = "Handover (ATMIST)",
			role = "Medic",
			mechanicId = "handover",
			gradeBands = {
				{ metric = "elapsed", gold = 20, silver = 30, bronze = 45 },
			},
			serverMetrics = { "elapsed" },
			weight = 0.5,
			timeoutSec = 45,
			onFail = "retry",
			npcAllowed = false,
			tip = "ATMIST: Age, Time, Mechanism, Injuries, Signs, Treatment, in that order.",
		},
	},
}

return def
