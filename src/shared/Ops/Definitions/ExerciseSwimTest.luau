--!strict
-- Exercise: Swim test (docs/09-rescue-operations.md section 9.2; the Rescue Swimmer
-- certification, section 11). Data only, built from the live swimmer mechanics. Off the slipway an
-- instructor plays a panicking swimmer: stop at arm's length, work round behind them, present the
-- tube and talk them down in the lulls; if they grab, break free (flick away and reset) rather than
-- holding on. Then the tube tow back to the slip and the recovery, and a quick check on the slip
-- (the swimmer needs Casualty Care for a reason).
local Types = require(script.Parent.Parent.Types)

local def: Types.OperationDef = {
	id = "ExerciseSwimTest",
	displayName = "Exercise: Swim test",
	radioLine = "Haven Rescue, Haven Station. Swim test off the slipway, swimmer to the water.",
	weight = 0,
	capSeconds = 300,
	isBig = false,
	casualtyKind = "Person",
	states = { Panicking = 1 }, -- the instructor always plays the panicking swimmer
	lifejacketChance = 0,
	takeoverAsset = "Chief Aggie",
	sceneKinds = { "Swimmer" },
	steps = {
		{
			id = "calm",
			label = "Talk down the instructor",
			realTerm = "Panicking casualty: arm's length, break free",
			role = "Crew",
			mechanicId = "panic_calm",
			gradeBands = {
				{ metric = "calmSeconds", gold = 20, silver = 30, bronze = 45 },
				{ metric = "grabbed", gold = 0, silver = 1, bronze = 3 },
			},
			weight = 2,
			timeoutSec = 60,
			onFail = "retry",
			npcAllowed = false,
			tip = "Stop at arm's length and offer the tube, never your hand; if they grab, sink and push away.",
		},
		{
			id = "recovery",
			label = "Tube tow and recovery",
			realTerm = "Swimmer recovery",
			role = "Crew",
			mechanicId = "recover_swimmer",
			gradeBands = {
				{ metric = "rightMethod", gold = 1, silver = 1, bronze = 0, higherIsBetter = true },
				{ metric = "score", gold = 0.8, silver = 0.5, bronze = 0.2, higherIsBetter = true },
			},
			allowedEvents = { wrongHandling = 1 },
			weight = 2,
			timeoutSec = 90,
			onFail = "retry",
			npcAllowed = false,
			effect = "board",
			tip = "Contact from behind, tube under their arms, and tow with long strokes while you talk to them.",
		},
		{
			id = "survey",
			label = "Check them on the slip",
			realTerm = "Primary survey",
			role = "Medic",
			mechanicId = "primary_survey",
			gradeBands = {
				{ metric = "correct", gold = 1, silver = 0.8, bronze = 0.5, higherIsBetter = true },
				{ metric = "elapsed", gold = 25, silver = 35, bronze = 50 },
			},
			serverMetrics = { "elapsed" },
			weight = 1,
			timeoutSec = 50,
			onFail = "retry",
			npcAllowed = false,
			effect = "survey",
			tip = "A rescued swimmer still needs the full check: panic hides cold and swallowed water.",
		},
	},
}

return def
