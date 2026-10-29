--!strict
-- BadgeConfig: the Roblox badges (docs/03 section 8) and the station leaderboards (docs/03 section 9.1).
--
-- Badge ids: paste each badge's Creator Hub id into `id` (U-6 in docs/13). id 0 = off: BadgeService never
-- calls AwardBadge for it, but still keeps its progress counter, so a badge switched on later is awarded
-- to anyone who already qualifies the next time the trigger fires (counted badges) or on their next join
-- (rescued badges). tools/deploy.py cannot create badges (Open Cloud covers passes and products only there),
-- so the ids are entered by hand.
--
--   name, description   the Creator Hub text (keep them in sync when creating the badge)
--   icon                one-line icon concept for the Creator Hub image
--   count               counted badges: awarded when the counter reaches this (1 = the first time)
--   rescued             rescued badges: awarded once this many people are delivered home (data.totalRescues;
--                       WP-28: the old rank badges, same keys and ids, now people-rescued milestones)
--   awardedBy           who calls BadgeService.Award for it, when it is not OperationService's debrief

export type Badge = {
	id: number,
	name: string,
	description: string,
	icon: string?,
	count: number?,
	rescued: number?,
	awardedBy: string?,
}

local BadgeConfig = {}

-- Every operation kind a player can be offered, once each, for the EveryCall badge (the ferry is the
-- scheduled big call, OfferPacing.nextBigCallAt).
BadgeConfig.OpKinds = table.freeze({
	"PersonInWater",
	"CapsizedFerry",
	"RipCurrent",
	"SinkingVessel",
	"VesselFire",
	"WildlifeRescue",
})

-- order = the order of the table below (the Creator Hub list); keys are stable, never rename one
BadgeConfig.Order = table.freeze({
	"FirstRescue",
	"SmoothRide",
	"RankLifeguard",
	"RankRescueSwimmer",
	"FirstWildlife",
	"AllWildlife",
	"FirstPet",
	"Streak7",
	"Streak30",
	"EveryCall",
	"LifeboatBought",
	"RankCoxswain",
	"Rescue100",
	"RankCaptain",
	"RankAdmiral",
	"FriendCrew",
	"FerryHero",
})

BadgeConfig.Badges = table.freeze({
	FirstRescue = {
		id = 4274933981811790,
		name = "First Rescue",
		description = "Finish your first rescue operation.",
		count = 1,
	},
	SmoothRide = {
		id = 1288197496135131,
		name = "Smooth Ride",
		description = "Bring survivors home with a smooth ride 10 times.",
		icon = "A boat on a flat gold wake",
		count = 10,
	},
	RankLifeguard = {
		id = 4175264142830449,
		name = "Ten Rescued",
		description = "Bring 10 people home.",
		rescued = 10,
	},
	RankRescueSwimmer = {
		id = 2536652141146668,
		name = "Fifty Rescued",
		description = "Bring 50 people home.",
		rescued = 50,
	},
	RankCoxswain = {
		id = 679044961405564,
		name = "Two Hundred Rescued",
		description = "Bring 200 people home.",
		icon = "A life ring with 200 on it",
		rescued = 200,
	},
	RankCaptain = {
		id = 3988634187712861,
		name = "Five Hundred Rescued",
		description = "Bring 500 people home.",
		icon = "A gold life ring with 500 on it",
		rescued = 500,
	},
	Rescue100 = {
		id = 2256878015580327,
		name = "Hundred Rescues",
		description = "Finish 100 rescues.",
		icon = "A life ring with 100 on it",
		count = 100,
	},
	FirstWildlife = {
		id = 214011811450046,
		name = "First Wildlife Rescue",
		description = "Free your first animal in a wildlife rescue.",
		icon = "A life ring with a paw print in the middle",
		count = 1,
	},
	AllWildlife = {
		id = 3723954163251165,
		name = "Sanctuary Five",
		description = "Rescue all five wildlife species.",
		icon = "Five animal silhouettes around a life ring",
		count = 5,
	},
	FirstPet = {
		id = 3649679878233996,
		name = "First Pet",
		description = "Adopt your first pet.",
		icon = "A paw print inside a heart",
		count = 1,
	},
	Streak7 = {
		id = 3913305071013999,
		name = "Seven-Day Streak",
		description = "Collect your daily reward seven days in a row.",
		icon = "Seven lit lanterns in a row",
		count = 1,
	},
	Streak30 = {
		id = 2543589237302297,
		name = "Thirty-Day Streak",
		description = "Collect your daily reward thirty days in a row.",
		icon = "A calendar page with thirty lit lanterns",
		count = 1,
	},
	EveryCall = {
		id = 4343454098465465,
		name = "Every Call",
		description = "Complete every call type once: person in the water, capsized ferry, rip current, sinking boat, boat on fire and wildlife.",
		icon = "Six small icons in a ring",
		count = 6,
	},
	LifeboatBought = {
		id = 3683726869740416,
		name = "Lifeboat",
		description = "Buy the All-Weather Lifeboat.",
		icon = "A lifeboat bow on over a crest",
		count = 1,
	},
	RankAdmiral = {
		id = 4056188676601948,
		name = "Two Thousand Rescued",
		description = "Bring 2,000 people home.",
		icon = "A gold life ring with a crown, 2000 on it",
		rescued = 2000,
	},
	FriendCrew = {
		id = 0,
		name = "Crew Up",
		description = "Join a crew with a friend.",
		icon = "Two clasped hands over a boat deck",
		count = 1,
	},
	FerryHero = {
		id = 0,
		name = "Ferry Hero",
		description = "Bring a survivor home from the capsized ferry.",
		icon = "A ferry with a life ring",
		count = 1,
	},
} :: { [string]: Badge })

-- Station boards (docs/03 section 9.1): rescues only, never Cash or Robux. Weekly boards reset
-- Monday 00:00 UTC (a new OrderedDataStore per ISO-style week index), so new players can place.
export type Board = {
	key: string,
	title: string,
	weekly: boolean,
}

BadgeConfig.Boards = table.freeze({
	{ key = "Rescued", title = "Rescued this week", weekly = true },
	-- was StormRescued (storms never come): a new store key, so no old data is read or written
	{ key = "FerryRescued", title = "Ferry rescues this week", weekly = true },
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
