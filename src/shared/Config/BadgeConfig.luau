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
--   icon                one-line icon concept for the Creator Hub image
--   count               counted badges: awarded when the counter reaches this (1 = the first time)
--   rank                rank badges: awarded on reaching this ProgressionConfig rank id
--   awardedBy           who calls BadgeService.Award for it, when it is not OperationService's debrief

export type Badge = {
	id: number,
	name: string,
	description: string,
	icon: string?,
	count: number?,
	rank: string?,
	awardedBy: string?,
}

local BadgeConfig = {}

-- Every operation kind, once each, for the EveryCall badge.
BadgeConfig.OpKinds = table.freeze({
	"PersonInWater",
	"DisabledVessel",
	"CapsizedFerry",
	"CliffCasualty",
	"RipCurrent",
	"SinkingVessel",
	"VesselFire",
	"WildlifeRescue",
})

-- order = the order of the table below (the Creator Hub list); keys are stable, never rename one
BadgeConfig.Order = table.freeze({
	"FirstRescue",
	"CertHelm",
	"CertCasualtyCare",
	"CertRescueSwimmer",
	"CertCoxswain",
	"Downwind",
	"TowTruck",
	"StormChaser",
	"RankLifeguard",
	"RankRescueSwimmer",
	"FerryHero",
	"FirstWreck",
	"FirstWildlife",
	"AllWildlife",
	"FirstPet",
	"LegendaryRescue",
	"GoldenGull",
	"AlbumSet",
	"AlbumComplete",
	"Streak7",
	"Streak30",
	"GreatStormRescue",
	"SeasonTier10",
	"SeasonTier30",
	"EveryCall",
	"LifeboatBought",
	"RankAdmiral",
	"FriendCrew",
	"PhotoFirst",
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
	CertCoxswain = {
		id = 0,
		name = "Coxswain",
		description = "Pass the Coxswain certification.",
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
	FirstWreck = {
		id = 0,
		name = "First Wreck",
		description = "Find the Morwenna in Calm Bay.",
		awardedBy = "exploration logbook (RP-X1)",
	},
	FirstWildlife = {
		id = 0,
		name = "First Wildlife Rescue",
		description = "Free your first animal in a wildlife rescue.",
		icon = "A life ring with a paw print in the middle",
		count = 1,
	},
	AllWildlife = {
		id = 0,
		name = "Sanctuary Five",
		description = "Rescue all five wildlife species.",
		icon = "Five animal silhouettes around a life ring",
		count = 5,
	},
	FirstPet = {
		id = 0,
		name = "First Pet",
		description = "Adopt your first pet at the sanctuary.",
		icon = "A paw print inside a heart",
		count = 1,
	},
	LegendaryRescue = {
		id = 0,
		name = "Legendary Rescue",
		description = "Finish a Legendary rarity call.",
		icon = "A gold star over a rescue boat",
		count = 1,
	},
	GoldenGull = {
		id = 0,
		name = "Golden Gull",
		description = "Bring in the Golden Gull.",
		icon = "A golden gull with spread wings",
		count = 1,
	},
	AlbumSet = {
		id = 0,
		name = "Set Complete",
		description = "Complete any Rescue Album set.",
		icon = "A full page of stickers with one gold frame",
		count = 1,
	},
	AlbumComplete = {
		id = 0,
		name = "Full Album",
		description = "Collect every sticker in the Rescue Album.",
		icon = "A closed sticker album with a gold clasp",
		count = 1,
	},
	Streak7 = {
		id = 0,
		name = "Seven-Day Streak",
		description = "Open the daily crate seven days in a row.",
		icon = "Seven lit lanterns in a row",
		count = 1,
	},
	Streak30 = {
		id = 0,
		name = "Thirty-Day Streak",
		description = "Open the daily crate thirty days in a row.",
		icon = "A calendar page with thirty lit lanterns",
		count = 1,
	},
	GreatStormRescue = {
		id = 0,
		name = "Great Storm Rescue",
		description = "Finish a rescue during a Great Storm.",
		icon = "A boat on a huge wave under a dark sky",
		count = 1,
	},
	SeasonTier10 = {
		id = 0,
		name = "Season One: Tier 10",
		description = "Reach tier 10 of Season 1.",
		icon = "A bronze season badge with a 10",
		count = 1,
	},
	SeasonTier30 = {
		id = 0,
		name = "Season One: Tier 30",
		description = "Reach tier 30 of Season 1.",
		icon = "A gold season badge with a 30",
		count = 1,
	},
	EveryCall = {
		id = 0,
		name = "Every Call",
		description = "Complete every operation type once: swimmer, tow, ferry, cliff, rip current, sinking, fire and wildlife.",
		icon = "Eight small icons in a ring",
		count = 8,
	},
	LifeboatBought = {
		id = 0,
		name = "Lifeboat",
		description = "Buy the All-Weather Lifeboat.",
		icon = "A lifeboat bow on over a crest",
		count = 1,
	},
	RankAdmiral = {
		id = 0,
		name = "Admiral",
		description = "Reach the rank of Admiral.",
		icon = "An admiral's shoulder board with four stars",
		rank = "Admiral",
	},
	FriendCrew = {
		id = 0,
		name = "Crew Up",
		description = "Join a crew with a friend.",
		icon = "Two clasped hands over a boat deck",
		count = 1,
	},
	PhotoFirst = {
		id = 0,
		name = "First Shot",
		description = "Take your first photo in photo mode.",
		icon = "A camera shutter with a wave inside",
		count = 1,
		awardedBy = "photo mode (no server remote yet)",
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
