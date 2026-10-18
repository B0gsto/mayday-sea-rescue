--!strict
-- BadgeConfig: the Roblox badges (docs/03 section 8) and the station leaderboards (docs/03 section 9.1).
--
-- Badge ids: paste each badge's Creator Hub id into `id` (U-6 in docs/13). id 0 = off: BadgeService never
-- calls AwardBadge for it, but still keeps its progress counter, so a badge switched on later is awarded
-- to anyone who already qualifies the next time the trigger fires (counted badges) or on their next join
-- (rank badges). tools/deploy.py cannot create badges (Open Cloud covers passes and products only there),
-- so the ids are entered by hand.
--
--   name, description   the Creator Hub text (keep them in sync when creating the badge)
--   count               counted badges: awarded when the counter reaches this (1 = the first time)
--   rank                rank badges: awarded on reaching this ProgressionConfig rank id
--   awardedBy           who calls BadgeService.Award for it, when it is not OperationService's debrief

export type Badge = {
	id: number,
	name: string,
	description: string,
	count: number?,
	rank: string?,
	awardedBy: string?,
}

local BadgeConfig = {}

-- order = the order of the table below (the Creator Hub list); keys are stable, never rename one
BadgeConfig.Order = table.freeze({
	"FirstRescue",
	"CertHelm",
	"CertCasualtyCare",
	"CertRescueSwimmer",
	"Downwind",
	"TowTruck",
	"StormChaser",
	"RankLifeguard",
	"RankRescueSwimmer",
	"FerryHero",
	"AirPocket",
	"FirstWreck",
})

BadgeConfig.Badges = table.freeze({
	FirstRescue = {
		id = 0,
		name = "First Rescue",
		description = "Finish your first rescue operation.",
		count = 1,
	},
	CertHelm = {
		id = 0,
		name = "Helm",
		description = "Pass the Helm certification.",
		awardedBy = "certifications (RP-C1)",
	},
	CertCasualtyCare = {
		id = 0,
		name = "Casualty Care",
		description = "Pass the Casualty Care certification.",
		awardedBy = "certifications (RP-C1)",
	},
	CertRescueSwimmer = {
		id = 0,
		name = "Rescue Swimmer",
		description = "Pass the Rescue Swimmer certification.",
		awardedBy = "certifications (RP-C1)",
	},
	Downwind = {
		id = 0,
		name = "Downwind",
		description = "Make 10 approaches graded Gold.",
		count = 10,
	},
	TowTruck = {
		id = 0,
		name = "Tow Truck",
		description = "Finish a tow without parting the line.",
		count = 1,
	},
	StormChaser = {
		id = 0,
		name = "Storm Chaser",
		description = "Finish an operation you were tasked to during a storm.",
		count = 1,
	},
	RankLifeguard = {
		id = 0,
		name = "Lifeguard",
		description = "Reach the rank of Lifeguard.",
		rank = "Lifeguard",
	},
	RankRescueSwimmer = {
		id = 0,
		name = "Rescue Swimmer (rank)",
		description = "Reach the rank of Rescue Swimmer.",
		rank = "RescueSwimmer",
	},
	FerryHero = {
		id = 0,
		name = "Ferry Hero",
		description = "Bring a casualty home from a Capsized Ferry.",
		count = 1,
	},
	AirPocket = {
		id = 0,
		name = "Air Pocket",
		description = "Lead a trapped passenger out of the air pocket.",
		count = 1,
	},
	FirstWreck = {
		id = 0,
		name = "First Wreck",
		description = "Find the Morwenna in Calm Bay.",
		awardedBy = "exploration logbook (RP-X1)",
	},
} :: { [string]: Badge })

-- Station boards (docs/03 section 9.1): rescues only, never Cash, Rep or Robux. Weekly boards reset
-- Monday 00:00 UTC (a new OrderedDataStore per ISO-style week index), so new players can place.
export type Board = {
	key: string,
	title: string,
	weekly: boolean,
}

BadgeConfig.Boards = table.freeze({
	{ key = "Rescued", title = "Rescued this week", weekly = true },
	{ key = "StormRescued", title = "Storm rescues this week", weekly = true },
	{ key = "RescuedAllTime", title = "Rescued, all time", weekly = false },
} :: { Board })

BadgeConfig.Leaderboard = table.freeze({
	storePrefix = "Lb1_", -- OrderedDataStore name = prefix .. key (.. "_W" .. week for weekly boards)
	rows = 8, -- names shown per board
	flushSeconds = 60, -- pending increments are written at most this often per player
	refreshSeconds = 120, -- the board re-reads the top rows this often
})

function BadgeConfig.get(key: string): Badge?
	return BadgeConfig.Badges[key]
end

function BadgeConfig.enabled(key: string): boolean
	local b = BadgeConfig.Badges[key]
	return b ~= nil and b.id > 0
end

return BadgeConfig
