--!strict
-- The one plan every single-crew operation runs (docs/16 K1; 2026-10-21, user: "just get near him, and he
-- gets on whatever you are driving"): answer -> get aboard your boat -> drive up close and steady (auto_board:
-- they climb on, if there is room) -> bring them home (they climb off at the drop-off). The scene changes,
-- the steps never do. recovery and transport loop once per survivor (perCasualty): a full craft brings
-- the first ones home and comes back for the rest. Data only.
local Types = require(script.Parent.Parent.Types)

return function(answerTip: string): { Types.StepDef }
	return {
		{
			id = "tasking",
			label = "Answer",
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
			tip = answerTip,
		},
		{
			id = "launch",
			label = "Go",
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
			label = "Pick up",
			realTerm = "Recovery",
			role = "Helm",
			mechanicId = "auto_board",
			perCasualty = true,
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
			label = "Home",
			realTerm = "Transport",
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
			weight = 2,
			timeoutSec = 180,
			onFail = "continue",
			npcSeconds = 45,
			effect = "deliver",
			tip = "Ease off on the crests on the way home: every slam hurts a cold survivor.",
		},
	}
end
