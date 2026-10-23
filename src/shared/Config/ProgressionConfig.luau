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
	passOnly: boolean?, -- Robux only: owned through its MonetizationConfig.GamePasses `vehicle` pass, never Cash
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
		unlocks = { "RIB", "Crew joining" },
	},
	{
		id = "RescueSwimmer",
		displayName = "Rescue Swimmer",
		rep = 900, -- tune
		unlocks = { "Coastguard 4x4" },
	},
	{
		id = "Coxswain",
		displayName = "Coxswain",
		rep = 3000, -- tune
		unlocks = { "Lifeboat", "Open Sea" },
	},
	{
		id = "RescuePilot",
		displayName = "Rescue Pilot",
		rep = 9000, -- tune
		unlocks = { "Helicopter", "Helipad", "Winch work" },
	},
	{
		id = "Captain",
		displayName = "Captain",
		rep = 22000, -- tune
		unlocks = { "Storm Front", "Tempest Point", "Captain's cap" },
	},
	{
		id = "Commodore",
		displayName = "Commodore",
		rep = 55000, -- tune
		unlocks = { "Iceberg North", "Commodore livery", "Radio title" },
	},
	{
		id = "Admiral",
		displayName = "Admiral",
		rep = 150000, -- tune
		unlocks = { "Gold livery", "Admiral's coat", "Honor board" },
	},
} :: { Rank }

-- docs 03 section 3: Service Stars are endless prestige levels, one per 30,000 Rep past Admiral.
ProgressionConfig.ServiceStarStep = 30000

-- Retired (docs/16 C3): nothing earns, gates or shows certifications any more; saved certs stay in
-- profiles. shortcut: kept only for readers in other packages (Ops/Definitions/Exercises and
-- OperationService.StartExercise, WP1; OnboardingController, WP9); delete with them (WP10).
ProgressionConfig.Certifications = {
	Helm = {
		id = "Helm",
		displayName = "Helm",
		exercise = "ExerciseBoatHandling",
		live = {
			-- 2026-10-21: the Person in the Water pick-up (auto_board: close and steady) is helm work
			-- too; mechanicIds keeps the cliff's on-foot "recovery" out
			stepIds = { "approach", "alongside", "recovery" },
			mechanicIds = { "approach", "alongside", "berth", "fire_approach", "auto_board" },
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
	Coxswain = {
		id = "Coxswain",
		displayName = "Coxswain",
		exercise = "ExerciseCoxswain",
		live = {
			stepIds = { "approach", "alongside" },
			mode = "any",
			minGrade = "Silver",
			count = 3, -- tune: docs 03 section 3.1 (one tow, one storm)
			label = "operations",
		},
		needs = { "Helm", "CasualtyCare" },
		gates = { "Coxswain rank", "Lifeboat", "On Scene Coordinator", "Search patterns" },
		badge = "CertCoxswain",
	},
} :: { [string]: Certification }

ProgressionConfig.CertOrder = { "Helm", "CasualtyCare", "RescueSwimmer", "Coxswain" }

-- docs/16 K7: jet ski free at Recruit, RIB 2,500 Cash at Lifeguard (RIBPass stays the instant path).
ProgressionConfig.Vehicles = {
	JetSki = { rankIndex = 1, price = 0 },
	RIB = { rankIndex = 2, price = 2500 }, -- tune: affordable ~15 to 20 min in (docs/16 B4)
	-- docs 03 section 4: data only until the hull and the helicopter exist (no rows in VehicleConfig).
	Lifeboat = { rankIndex = 4, price = 12000 }, -- tune
	RescueHelicopter = { rankIndex = 5, price = 75000 }, -- tune
	-- docs 10 section 3: land vehicles are free station pool vehicles gated by rank. The Ambulance
	-- is an NPC handover point until [P1], so it is not listed (not player-drivable).
	LifeguardPickup = { rankIndex = 1, price = 0, land = true },
	BeachATV = { rankIndex = 2, price = 0, land = true },
	CoastguardResponse = { rankIndex = 3, price = 0, land = true },
	-- Premium fleet (2026-10-21, user): Robux only, any rank, through the vehicle's Game Pass.
	StormRunner = { rankIndex = 1, price = 0, passOnly = true },
	Tidewalker = { rankIndex = 1, price = 0, passOnly = true },
	RiptideX = { rankIndex = 1, price = 0, passOnly = true },
	GildedGull = { rankIndex = 1, price = 0, passOnly = true },
	HarbourGT = { rankIndex = 1, price = 0, land = true, passOnly = true },
	LighthouseCruiser = { rankIndex = 1, price = 0, land = true, passOnly = true },
} :: { [string]: VehicleUnlock }

-- True when the id is a land vehicle (never offered as a boat launch).
function ProgressionConfig.isLandVehicle(vehicleId: string): boolean
	local unlock = ProgressionConfig.Vehicles[vehicleId]
	return unlock ~= nil and unlock.land == true
end

-- docs 03 section 2: Cash x1.5 in storms, x2 in a Great Storm; Rep is never multiplied.
ProgressionConfig.StormCashMultiplier = 1.5
ProgressionConfig.GreatStormCashMultiplier = 2

-- docs 03 section 3: Lifeguard unlocks crew joining (bypassed in Studio for testing).
ProgressionConfig.CrewJoinRankIndex = 2
ProgressionConfig.MaxCrew = 4 -- docs 02 section 7

ProgressionConfig.StartingCash = 0

return ProgressionConfig
