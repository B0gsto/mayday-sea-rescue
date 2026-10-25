--!strict
-- Operation 3: Capsized Ferry (docs/09-rescue-operations.md section 7). Data only.
-- The server's big call: one track per joining crew; the `perCasualty` run (pick-up, movement)
-- loops once per casualty a track claims from the pool.
-- 2026-10-21 (simple rescue): reach the survivors, they climb aboard (auto_board, any free one, as many
-- as the boat holds), bring them home. Scene command, hull knock, air pocket, triage and the
-- close-out are gone.
-- MVP fallback (section 7): boats only; the helicopter ride-along (step 7) arrives at [L].
local Types = require(script.Parent.Parent.Types)

local def: Types.OperationDef = {
	id = "CapsizedFerry",
	displayName = "Capsized Ferry",
	weight = 1.0, -- big calls pay by share (docs 03 section 2)
	capSeconds = 540, -- its own 8 to 10 minute timer (tune)
	isBig = true,
	casualtyKind = "Person",
	states = { Alert = 0.45, Exhausted = 0.3, VeryCold = 0.2, Unresponsive = 0.05 },
	lifejacketChance = 1,
	takeoverAsset = "Rescue Gale One",
	sceneKinds = { "CapsizedFerry" },
	steps = {
		{
			id = "relay",
			label = "Answer",
			realTerm = "MAYDAY RELAY",
			role = "Navigator",
			mechanicId = "answer",
			gradeBands = {
				{ metric = "elapsed", gold = 15, silver = 25, bronze = 40 },
			},
			serverMetrics = { "elapsed" },
			weight = 0.5,
			timeoutSec = 45,
			onFail = "npc",
			npcSeconds = 8,
			tip = "Answer the relay at once.",
		},
		{
			id = "pickup",
			label = "Pick up",
			realTerm = "Search and pick-up",
			role = "Crew",
			mechanicId = "auto_board", -- 2026-10-21: close and steady, they climb aboard
			perCasualty = true,
			gradeBands = {
				{ metric = "elapsed", gold = 45, silver = 90, bronze = 180 },
			},
			serverMetrics = { "elapsed" },
			allowedEvents = { bump = 2 },
			weight = 1,
			timeoutSec = 540, -- the call's own timer ends it: a timed-out pick-up would board them by magic
			onFail = "retry",
			npcAllowed = false,
			effect = "board",
			tip = "Come in slow and steady: they climb aboard.",
		},
		{
			id = "movement",
			label = "Home",
			realTerm = "Casualty movement",
			role = "Helm",
			mechanicId = "transport",
			perCasualty = true,
			gradeBands = {
				{
					metric = "conditionAtEnd",
					gold = 70,
					silver = 40,
					bronze = 20,
					higherIsBetter = true,
				},
			},
			serverMetrics = { "conditionAtEnd" },
			allowedEvents = { slam = 6 },
			weight = 1,
			timeoutSec = 150,
			onFail = "continue",
			npcSeconds = 40,
			effect = "deliver",
			tip = "A bigger boat brings more home per trip.",
		},
	},
}

return def
