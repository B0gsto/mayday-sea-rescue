--!strict
-- ProgressionConfig: ranks, vehicle unlocks, gear and payout multipliers. Pure data (no services),
-- safe to load in Lune. Numbers come from docs/03-progression.md (MVP scope: 3 ranks, 2 gear items).
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
	land: boolean?, -- true for the land fleet (LandVehicleService); boat UIs must skip these
}

export type GearStat = "speed" | "pullTime" | "searchRadius"

export type GearItem = {
	id: string,
	displayName: string,
	description: string,
	stat: GearStat,
	-- multiplier on the stat at each level (index = level); level 0 is always 1
	levels: { number },
}

local ProgressionConfig = {}

ProgressionConfig.SchemaVersion = 1

ProgressionConfig.Ranks = {
	{
		id = "Recruit",
		displayName = "Recruit",
		rep = 0,
		unlocks = { "Jet Ski", "Bosun", "Calm Bay calls" },
	},
	{
		id = "Lifeguard",
		displayName = "Lifeguard",
		rep = 400, -- tune
		unlocks = { "Crew joining" },
	},
	{
		id = "RescueSwimmer",
		displayName = "Rescue Swimmer",
		rep = 900, -- tune
		unlocks = { "RIB (buy)", "Gear level 3" },
	},
} :: { Rank }

-- docs 03 section 4: jet ski free at Recruit, RIB 4,000 Cash at Rescue Swimmer.
ProgressionConfig.Vehicles = {
	JetSki = { rankIndex = 1, price = 0 },
	RIB = { rankIndex = 3, price = 4000 }, -- tune
	-- docs 10 section 3: land vehicles are free station pool vehicles gated by rank. The Ambulance
	-- is an NPC handover point until [P1], so it is not listed (not player-drivable).
	LifeguardPickup = { rankIndex = 1, price = 0, land = true },
	BeachATV = { rankIndex = 2, price = 0, land = true },
	CoastguardResponse = { rankIndex = 3, price = 0, land = true },
} :: { [string]: VehicleUnlock }

-- True when the id is a land vehicle (never offered as a boat launch).
function ProgressionConfig.isLandVehicle(vehicleId: string): boolean
	local unlock = ProgressionConfig.Vehicles[vehicleId]
	return unlock ~= nil and unlock.land == true
end

-- docs 03 section 5: level prices and the rank each level needs. MVP caps gear at level 3.
ProgressionConfig.GearLevelPrices = { 300, 1200, 4000 } -- tune
ProgressionConfig.GearLevelRank = { 1, 1, 3 } -- rank index needed for each level

ProgressionConfig.Gear = {
	EngineTune = {
		id = "EngineTune",
		displayName = "Engine Tune",
		description = "+8% top speed per level",
		stat = "speed",
		levels = { 1.08, 1.16, 1.24 }, -- tune
	},
	StrongGrip = {
		id = "StrongGrip",
		displayName = "Strong Grip",
		description = "Pull victims aboard faster",
		stat = "pullTime",
		levels = { 0.75, 0.65, 0.55 }, -- tune: -25% at level 1
	},
	-- Spotter Binoculars (searchRadius) are [L] in docs 03: deferred.
} :: { [string]: GearItem }

-- Shop order.
ProgressionConfig.GearOrder = { "EngineTune", "StrongGrip" }

-- docs 03 section 2: Cash x1.5 in storms, x2 in a Great Storm; Rep is never multiplied.
ProgressionConfig.StormCashMultiplier = 1.5
ProgressionConfig.GreatStormCashMultiplier = 2

-- docs 03 section 3: Lifeguard unlocks crew joining (bypassed in Studio for testing).
ProgressionConfig.CrewJoinRankIndex = 2
ProgressionConfig.MaxCrew = 4 -- docs 02 section 7

ProgressionConfig.StartingCash = 0

return ProgressionConfig
