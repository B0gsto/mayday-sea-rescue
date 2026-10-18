--!strict
-- ProgressionConfig: ranks, vehicle unlocks, gear and payout multipliers. Pure data (no services),
-- safe to load in Lune. Numbers come from docs/03-progression.md (MVP scope: 3 ranks, 2 gear items).
-- The rules that read this table live in src/shared/ProgressionRules.luau.

export type Rank = {
	id: string,
	displayName: string,
	rep: number, -- total Rep needed (docs 03 section 3)
	unlocks: { string }, -- short lines for the rank-up toast
	cert: string?, -- the certification this rank also needs (docs 03 section 3); nil: none
}

-- What counts toward a certification's live half (docs 03 section 3.1, docs 09 section 11): an
-- operation (not an exercise) where the player themselves did the listed steps at minGrade or
-- better. mode "any": one of the steps is enough; "all": every listed step that the operation
-- has. mechanicIds narrows a step to the mechanic that played it (a swimmer recovery is the
-- recovery step played by recover_swimmer). Each operation counts once per certification.
export type CertLive = {
	stepIds: { string },
	mode: "any" | "all",
	mechanicIds: { string }?,
	minGrade: string, -- "Gold" | "Silver" | "Bronze"
	count: number,
	label: string, -- the HUD's "next thing" noun ("operations", "swimmer recoveries")
}

export type Certification = {
	id: string,
	displayName: string,
	exercise: string, -- Ops/Definitions/Exercises id: the first half
	live: CertLive, -- the second half
	needs: { string }, -- certifications that must be held first
	gates: { string }, -- short lines for the debrief and the crew board
	badge: string, -- BadgeConfig key (RP-B1 maps it to a Roblox badge id)
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
		cert = "Helm",
		unlocks = { "Crew joining" },
	},
	{
		id = "RescueSwimmer",
		displayName = "Rescue Swimmer",
		rep = 900, -- tune
		cert = "RescueSwimmer",
		unlocks = { "RIB (buy)", "Gear level 3" },
	},
} :: { Rank }

-- docs 03 section 3.1 and docs 09 section 11 (MVP: the first three). Never sold, never expire,
-- never lost. Coxswain, Winch Operator, Pilot and Rescue Diver are [L].
ProgressionConfig.Certifications = {
	Helm = {
		id = "Helm",
		displayName = "Helm",
		exercise = "ExerciseBoatHandling",
		live = {
			stepIds = { "approach", "alongside" },
			mode = "any",
			minGrade = "Silver",
			count = 2, -- tune
			label = "operations",
		},
		needs = {},
		gates = { "Lifeguard rank", "Helm seat as lead", "Buying the RIB" },
		badge = "CertHelm",
	},
	CasualtyCare = {
		id = "CasualtyCare",
		displayName = "Casualty Care",
		exercise = "ExerciseCasualtyCare",
		live = {
			stepIds = { "survey", "treatment" },
			mode = "all",
			minGrade = "Silver",
			count = 2, -- tune
			label = "operations",
		},
		needs = {},
		gates = { "Medic seat as lead", "Oxygen and CPR as lead", "Triage on big calls" },
		badge = "CertCasualtyCare",
	},
	RescueSwimmer = {
		id = "RescueSwimmer",
		displayName = "Rescue Swimmer",
		exercise = "ExerciseSwimTest",
		live = {
			stepIds = { "recovery" },
			mode = "any",
			mechanicIds = { "recover_swimmer" },
			minGrade = "Silver",
			count = 1, -- tune
			label = "swimmer recoveries",
		},
		needs = { "CasualtyCare" },
		gates = { "Rescue Swimmer rank", "Entering the water from boats", "Air-pocket dive" },
		badge = "CertRescueSwimmer",
	},
} :: { [string]: Certification }

-- Ladder order (HUD, crew board, debrief).
ProgressionConfig.CertOrder = { "Helm", "CasualtyCare", "RescueSwimmer" }

-- docs 03 section 2: an exercise pays 200 Cash and 50 Rep the first time it is passed, nothing on
-- repeats. The optional Reopening Day drill pays a token amount (tune).
ProgressionConfig.ExerciseReward = { cash = 200, rep = 50 }
ProgressionConfig.DrillReward = { cash = 50, rep = 10 } -- tune
ProgressionConfig.DrillExercise = "ExerciseReopeningDay"
-- The worst overall grade that passes an exercise (every step must be the player's own).
ProgressionConfig.ExercisePassGrade = "Bronze" -- tune

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
