--!strict
-- Operation: Wildlife Rescue (docs/15 section 2, hook H4; docs/02 section 3).
-- A light call: a seal pup in a net, a puffin in oil, an otter, a turtle or a gull in line. The
-- animal is a swimmer scene, so this reuses the Person in the Water flow and mechanics end to end:
-- answer the radio, get there, come alongside, free it (hold: cut / wipe / loosen) and carry it
-- aboard (the same drag, throw or come-to-you ways). No transport leg: landing it completes the
-- call, and SanctuaryService walks the animal home to the station pens.
-- Data only; the animal's look comes from Config/Wildlife + WildlifeRig.
local Types = require(script.Parent.Parent.Types)

local def: Types.OperationDef = {
	id = "WildlifeRescue",
	displayName = "Wildlife Rescue",
	radioLine = "Wildlife in trouble off the harbour, request a rescue swimmer.",
	weight = 0.8, -- a light call (docs/02 section 3: x0.8) -- tune
	capSeconds = 420,
	isBig = false,
	casualtyKind = "Person",
	states = { Alert = 1 },
	lifejacketChance = 0,
	takeoverAsset = "Rescue Gale One",
	sceneKinds = { "Swimmer" },
	steps = {
		{
			id = "tasking",
			label = "Answer the Coastguard",
			realTerm = "Tasking",
			role = "Navigator",
			mechanicId = "radio_ack",
			gradeBands = {
				{ metric = "elapsed", gold = 15, silver = 25, bronze = 40 },
			},
			serverMetrics = { "elapsed" },
			weight = 0.5,
			timeoutSec = 45,
			onFail = "npc",
			npcSeconds = 8,
			tip = "Answer the Coastguard quickly; the animal is tangled and tiring.",
		},
		{
			id = "passage",
			label = "Get to the animal",
			realTerm = "Passage and ETA",
			role = "Helm",
			mechanicId = "passage",
			gradeBands = {
				{ metric = "routeRatio", gold = 1.1, silver = 1.3, bronze = 1.6 },
			},
			weight = 0.5,
			timeoutSec = 150,
			onFail = "continue",
			npcSeconds = 30,
			tip = "It cannot swim free: every minute in the water costs it strength.",
		},
		{
			id = "approach",
			label = "Come alongside, slowly",
			realTerm = "Approach",
			role = "Helm",
			mechanicId = "approach",
			gradeBands = { -- s over 3 knots in the last 30 m (0.5 s grace for a wave surge)
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
			weight = 1,
			timeoutSec = 60,
			onFail = "retry",
			npcAllowed = false,
			tip = "Slow and from downwind: your wash and propeller can hurt a tired animal.",
		},
		{
			id = "free",
			label = "Free it",
			realTerm = "Entangled wildlife",
			role = "Crew",
			mechanicId = "free_wildlife",
			gradeBands = {
				{ metric = "elapsed", gold = 8, silver = 14, bronze = 25 },
			},
			serverMetrics = { "elapsed" },
			weight = 2,
			timeoutSec = 60,
			onFail = "npc",
			npcSeconds = 10,
			tip = "Hold steady and work the net or line loose; pulling it tight only hurts more.",
		},
		{
			id = "carry",
			label = "Carry it aboard",
			realTerm = "Recovery",
			role = "Crew",
			mechanicId = "wildlife_carry",
			gradeBands = {
				{ metric = "rightMethod", gold = 1, silver = 1, bronze = 0, higherIsBetter = true },
				{ metric = "score", gold = 0.8, silver = 0.5, bronze = 0.2, higherIsBetter = true },
			},
			allowedEvents = { wrongHandling = 1 },
			weight = 2,
			timeoutSec = 60,
			onFail = "npc",
			npcSeconds = 16,
			effect = "board",
			tip = "Come alongside and let it hold on, or draw it in gently with the line.",
		},
		{
			id = "closeout",
			label = "Report the rescue",
			realTerm = "Close-out",
			role = "Navigator",
			mechanicId = "radio_closeout",
			gradeBands = {
				{ metric = "elapsed", gold = 15, silver = 25, bronze = 40 },
			},
			serverMetrics = { "elapsed" },
			weight = 0.5,
			timeoutSec = 45,
			onFail = "npc",
			npcSeconds = 10,
			tip = "Tell the Coastguard the animal is aboard and on its way to the sanctuary.",
		},
	},
}

return def
