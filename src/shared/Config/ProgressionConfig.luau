--!strict
-- ProgressionConfig: ranks (by Rep only, docs/16 K7), vehicle unlocks and payout multipliers. Pure
-- data (no services), safe to load in Lune. Numbers come from docs/03-progression.md and docs/16.
-- The rules that read this table live in src/shared/ProgressionRules.luau.

export type Rank = {
	id: string,
	displayName: string,
	rep: number, -- total Rep needed (docs 03 section 3)
	unlocks: { string }, -- short lines for the rank-up toast
}

export type VehicleUnlock = {
	rankIndex: number, -- rank needed to own and drive it
	price: number, -- Cash to buy once the rank is reached (0 = free)
	passOnly: boolean?, -- Robux only: owned through its MonetizationConfig.GamePasses `vehicle` pass, never Cash
}

local ProgressionConfig = {}

ProgressionConfig.SchemaVersion = 1

ProgressionConfig.Ranks = {
	{
		id = "Recruit",
		displayName = "Recruit",
		rep = 0,
		unlocks = { "Jet Ski", "Bosun", "Cove calls" },
	},
	{
		id = "Lifeguard",
		displayName = "Lifeguard",
		rep = 400, -- tune
		unlocks = { "RIB", "Crew joining", "Dock Lv2", "Farther calls" },
	},
	{
		id = "RescueSwimmer",
		displayName = "Rescue Swimmer",
		rep = 900, -- tune
		unlocks = { "Dock Lv3", "Boathouse", "Paint booth" },
	},
	{
		id = "Coxswain",
		displayName = "Coxswain",
		rep = 3000, -- tune
		unlocks = { "Lifeboat", "Submarine", "Sub pen", "Dock Lv4", "Crew hire", "Top call reach" },
	},
	{
		id = "RescuePilot",
		displayName = "Rescue Pilot",
		rep = 9000, -- tune
		unlocks = { "Helicopter", "Hangar", "Dock Lv5" },
	},
	{
		id = "Captain",
		displayName = "Captain",
		rep = 22000, -- tune
		unlocks = { "Captain's title" },
	},
	{
		id = "Commodore",
		displayName = "Commodore",
		rep = 55000, -- tune
		unlocks = { "Commodore livery" },
	},
	{
		id = "Admiral",
		displayName = "Admiral",
		rep = 150000, -- tune
		unlocks = { "Gold livery", "Admiral's coat", "Honour board" },
	},
} :: { Rank }

-- docs 03 section 3: Service Stars are endless prestige levels, one per 30,000 Rep past Admiral.
ProgressionConfig.ServiceStarStep = 30000

-- docs/16 K7: jet ski free at Recruit, RIB 2,500 Cash at Lifeguard (RIBPass stays the instant path).
ProgressionConfig.Vehicles = {
	JetSki = { rankIndex = 1, price = 0 },
	RIB = { rankIndex = 2, price = 2500 }, -- tune: affordable ~15 to 20 min in (docs/16 B4)
	Lifeboat = { rankIndex = 4, price = 12000 }, -- tune
	-- docs/23 (h): the hangar and sub pen craft; each also has a Robux pass (any rank, docs/23 rule 4).
	RescueHelicopter = { rankIndex = 5, price = 75000 }, -- tune
	Submarine = { rankIndex = 4, price = 40000 }, -- tune
	-- Premium fleet (2026-10-21, user): Robux only, any rank, through the vehicle's Game Pass.
	StormRunner = { rankIndex = 1, price = 0, passOnly = true },
	Tidewalker = { rankIndex = 1, price = 0, passOnly = true },
	RiptideX = { rankIndex = 1, price = 0, passOnly = true },
	GildedGull = { rankIndex = 1, price = 0, passOnly = true },
} :: { [string]: VehicleUnlock }

-- docs 03 section 2: Cash x1.5 in storms, x2 in a Great Storm; Rep is never multiplied.
ProgressionConfig.StormCashMultiplier = 1.5
ProgressionConfig.GreatStormCashMultiplier = 2

-- docs 03 section 3: Lifeguard unlocks crew joining (bypassed in Studio for testing).
ProgressionConfig.CrewJoinRankIndex = 2
ProgressionConfig.MaxCrew = 4 -- docs 02 section 7

ProgressionConfig.StartingCash = 0

return ProgressionConfig
