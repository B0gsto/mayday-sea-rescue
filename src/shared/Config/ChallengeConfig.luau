--!strict
-- ChallengeConfig: the daily and weekly challenge pools (docs/03 section 9, LU-1).
-- Pure data (no services), safe to load in Lune. The roll, progress and reward maths live in
-- src/shared/ChallengeRules.luau.
--
-- Rewards scale with the highest open zone's base (docs/03 section 2); the rank index picks the
-- row. Daily: 3 from the pool at 00:00 UTC, weekly: 5 on Monday 00:00 UTC. Unfinished challenges
-- simply expire. "label" is 1-2 words for the board; "icon" keeps it readable without text.

export type ChallengeDef = {
	id: string,
	scope: "daily" | "weekly",
	icon: string,
	label: string,
	stat: string, -- the counter ChallengeRules.operationCredit fills
	target: number,
}

local ChallengeConfig = {}

ChallengeConfig.DailyCount = 3
ChallengeConfig.WeeklyCount = 5

-- docs/03 section 9: multiplied by the zone base.
ChallengeConfig.DailyReward = { cash = 1.4, rep = 0.9 }
ChallengeConfig.WeeklyReward = { cash = 4.5, rep = 2.3 }
ChallengeConfig.DailyBonusCash = 1000 -- all three daily challenges
ChallengeConfig.RerollDailyLimit = 3

-- docs/03 section 2 zone bases, keyed by the rank index that opens the zone (docs/03 section 3:
-- Calm Bay at Recruit, Skerries at Lifeguard, Open Sea at Coxswain, Storm Front at Captain,
-- Iceberg North at Commodore). A rank between rows keeps the last open zone.
ChallengeConfig.ZoneBase = {
	{ rank = 1, cash = 550, rep = 135 },
	{ rank = 2, cash = 900, rep = 200 },
	{ rank = 3, cash = 1500, rep = 280 },
	{ rank = 6, cash = 2400, rep = 390 },
	{ rank = 7, cash = 3300, rep = 500 },
}

ChallengeConfig.Pool = {
	-- daily
	{
		id = "d_ops",
		scope = "daily",
		icon = "⚓",
		label = "OPS",
		stat = "ops",
		target = 3,
	},
	{
		id = "d_piw",
		scope = "daily",
		icon = "🛟",
		label = "PIW",
		stat = "op:PersonInWater",
		target = 2,
	},
	{
		id = "d_rescue",
		scope = "daily",
		icon = "🚨",
		label = "SAVED",
		stat = "rescues",
		target = 3,
	},
	{
		id = "d_storm",
		scope = "daily",
		icon = "⛈",
		label = "STORM",
		stat = "stormOps",
		target = 2,
	},
	{
		id = "d_gold",
		scope = "daily",
		icon = "⭐",
		label = "GOLD",
		stat = "goldSteps",
		target = 5,
	},
	{
		id = "d_find",
		scope = "daily",
		icon = "🐕",
		label = "FINDS",
		stat = "finds",
		target = 2,
	},
	{
		id = "d_tow",
		scope = "daily",
		icon = "🚤",
		label = "TOW",
		stat = "tows",
		target = 1,
	},
	{
		id = "d_treat",
		scope = "daily",
		icon = "🩹",
		label = "TREAT",
		stat = "treatments",
		target = 2,
	},
	{
		id = "d_crew",
		scope = "daily",
		icon = "👥",
		label = "CREW",
		stat = "crewOps",
		target = 2,
	},

	-- weekly
	{
		id = "w_big",
		scope = "weekly",
		icon = "🚁",
		label = "BIG CALLS",
		stat = "bigCalls",
		target = 3,
	},
	{
		id = "w_rescue",
		scope = "weekly",
		icon = "🛟",
		label = "SAVED",
		stat = "rescues",
		target = 20,
	},
	{
		id = "w_crew",
		scope = "weekly",
		icon = "👥",
		label = "CREW",
		stat = "crewOps",
		target = 6,
	},
	{
		id = "w_storm",
		scope = "weekly",
		icon = "⛈",
		label = "STORM",
		stat = "stormOps",
		target = 6,
	},
	{
		id = "w_ops",
		scope = "weekly",
		icon = "⚓",
		label = "OPS",
		stat = "ops",
		target = 10,
	},
	{
		id = "w_gold",
		scope = "weekly",
		icon = "⭐",
		label = "GOLD",
		stat = "goldSteps",
		target = 20,
	},
	{
		id = "w_tow",
		scope = "weekly",
		icon = "🚤",
		label = "TOWS",
		stat = "tows",
		target = 3,
	},
} :: { ChallengeDef }

return ChallengeConfig
