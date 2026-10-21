--!strict
-- Operation 1: Person in the Water (docs/09-rescue-operations.md section 5.1). Data only.
-- Absorbs the old Swimmer and DriftingCraft calls as scene variants.
-- 2026-10-21 (user): "just get near him, and he gets on whatever you are driving". The plan is
-- answer -> get aboard your boat -> drive up close and steady (auto_board: they climb on, if
-- there is room) -> bring them home (they climb off at the drop-off). No kit, no approach
-- coaching, no grab/throw choice, no swimming rescue, no first-person care. Running out of time
-- (condition Critical or the cap) is the fail: zero pay and an NPC boat picks them up instead.
local Types = require(script.Parent.Parent.Types)

local def: Types.OperationDef = {
	id = "PersonInWater",
	displayName = "Person in the Water",
	radioLine = "Haven Rescue, Gale Isles Coastguard. Person in the water, request you launch.",
	weight = 1.0,
	capSeconds = 720,
	isBig = false,
	casualtyKind = "Person",
	states = { Alert = 0.4, Panicking = 0.2, Exhausted = 0.2, VeryCold = 0.15, Unresponsive = 0.05 },
	lifejacketChance = 0.6,
	takeoverAsset = "Rescue Gale One",
	sceneKinds = { "Swimmer", "DriftingCraft" },
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
			tip = "Answer the Coastguard quickly; every second counts for the casualty.",
		},
		{
			id = "launch",
			label = "Get aboard your boat",
			realTerm = "Launch",
			role = "Helm",
			mechanicId = "launch",
			gradeBands = {
				{ metric = "elapsed", gold = 25, silver = 40, bronze = 90 },
			},
			serverMetrics = { "elapsed" },
			weight = 0.5,
			timeoutSec = 180, -- never skipped: the step ends only aboard (retry restarts it)
			onFail = "retry",
			npcAllowed = false,
			tip = "Your boat waits at your bay: run straight down the pier and jump aboard.",
		},
		{
			id = "recovery",
			label = "Pick them up",
			realTerm = "Recovery",
			role = "Helm",
			mechanicId = "auto_board",
			gradeBands = {
				-- server-timed: take the call to them aboard
				{ metric = "elapsed", gold = 60, silver = 120, bronze = 240 },
			},
			serverMetrics = { "elapsed" },
			allowedEvents = { bump = 2 }, -- ran into them
			weight = 2,
			timeoutSec = 300,
			onFail = "takeover", -- an NPC boat picks them up (never on the first missions)
			npcAllowed = false,
			effect = "board",
			tip = "Come in slow and hold her steady beside them: they climb on by themselves.",
		},
		{
			id = "transport",
			label = "Bring them home smoothly",
			realTerm = "Transport",
			role = "Helm",
			mechanicId = "transport",
			gradeBands = {
				{
					metric = "conditionAtEnd",
					gold = 70,
					silver = 40,
					bronze = 20,
					higherIsBetter = true,
				},
				-- server: the pad reached suits the casualty (a heli case goes to the station)
				{
					metric = "destinationRight",
					gold = 1,
					silver = 1,
					bronze = 0,
					higherIsBetter = true,
				},
			},
			serverMetrics = { "conditionAtEnd", "destinationRight" },
			allowedEvents = { slam = 6 },
			weight = 2,
			timeoutSec = 180,
			onFail = "continue",
			npcSeconds = 45,
			effect = "deliver",
			tip = "Ease off on the crests on the way home: every slam hurts a cold casualty.",
		},
	},
}

return def
