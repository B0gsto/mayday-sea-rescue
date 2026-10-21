--!strict
-- Operation 8.1: Sinking Vessel (docs/09-rescue-operations.md section 8.1, docs/13 LU-3).
-- A fishing boat is taking water off the harbour: she lists and settles while the crew wait on
-- the cabin roof. Read her from the world (list, rising waterline, the swirl at the leak), then
-- any way that works keeps the people safe: put the salvage pump aboard and run the hose over
-- the side, plug the leak, or take the crew off before she goes. Data only.
local Types = require(script.Parent.Parent.Types)

local def: Types.OperationDef = {
	id = "SinkingVessel",
	displayName = "Sinking Vessel",
	radioLine = "MAYDAY from the fishing boat Morwenna's Pride: taking water fast off the harbour, three aboard.",
	weight = 1.2,
	capSeconds = 480,
	isBig = false,
	casualtyKind = "Vessel",
	states = { Vessel = 1 },
	lifejacketChance = 1,
	takeoverAsset = "Haven Patrol",
	sceneKinds = { "Sinking" },
	steps = {
		{
			id = "tasking",
			label = "Answer the MAYDAY",
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
			tip = "Answer the Coastguard quickly: she is settling while you talk.",
		},
		{
			id = "kit_launch",
			label = "Load the salvage pump",
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
			onFail = "npc",
			npcSeconds = 15,
			tip = "The pump and the plugs go in the boat before you push off.",
		},
		{
			id = "passage",
			label = "Get to her",
			realTerm = "Passage and ETA",
			role = "Helm",
			mechanicId = "passage",
			gradeBands = {
				{ metric = "routeRatio", gold = 1.1, silver = 1.3, bronze = 1.6 },
			},
			weight = 0.5,
			timeoutSec = 180,
			onFail = "continue",
			npcSeconds = 30,
			tip = "Take the shortest safe water: every minute counts for a boat that is filling.",
		},
		{
			id = "assess",
			label = "Read her list and find the leak",
			realTerm = "Assessment",
			role = "Navigator",
			mechanicId = "sinking_assess",
			gradeBands = {
				{ metric = "found", gold = 1, silver = 1, bronze = 0, higherIsBetter = true },
				{ metric = "elapsed", gold = 45, silver = 70, bronze = 110 },
			},
			serverMetrics = { "elapsed" },
			weight = 1,
			timeoutSec = 120,
			onFail = "npc",
			npcSeconds = 30,
			npcAllowed = false,
			tip = "Watch the swirl and the list: that is where the water is coming in.",
		},
		{
			id = "save",
			label = "Keep her afloat",
			realTerm = "Pump, plug or take them off",
			role = "Crew",
			mechanicId = "sinking_save",
			gradeBands = {
				{ metric = "saved", gold = 1, silver = 1, bronze = 0, higherIsBetter = true },
				{ metric = "elapsed", gold = 45, silver = 75, bronze = 130 },
			},
			serverMetrics = { "elapsed" },
			weight = 2,
			timeoutSec = 180,
			onFail = "npc",
			npcSeconds = 60,
			npcAllowed = false,
			effect = "sinking",
			tip = "Any of the three works: pump her out, plug the hole, or get the crew off in time.",
		},
		{
			id = "handover",
			label = "Close out with the Coastguard",
			realTerm = "Handover",
			role = "Navigator",
			mechanicId = "radio_closeout",
			gradeBands = {
				{ metric = "elapsed", gold = 12, silver = 20, bronze = 30 },
			},
			serverMetrics = { "elapsed" },
			weight = 0.5,
			timeoutSec = 30,
			onFail = "npc",
			npcSeconds = 8,
			tip = "Count everyone off: the Coastguard needs the POB before she is left.",
		},
	},
}

return def
