--!strict
-- The one plan every single-crew operation runs (docs/16 K1; 2026-10-21, user: "just get near him, and he
-- gets on whatever you are driving"): answer -> get aboard your boat -> drive up close and steady (auto_board:
-- they climb on, if there is room) -> bring them home (they climb off at the drop-off). The scene changes,
-- the steps never do. recovery and transport loop once per survivor (perCasualty): a full craft brings
-- the first ones home and comes back for the rest. Data only.
local Types = require(script.Parent.Parent.Types)

return function(): { Types.StepDef }
	return {
		{
			id = "tasking",
			label = "Answer",
			realTerm = "Tasking",
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
			onFail = "continue", -- slow is Bronze, never a fail (docs/00 section 3)
			npcAllowed = false,
			effect = "board",
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
		},
	}
end
