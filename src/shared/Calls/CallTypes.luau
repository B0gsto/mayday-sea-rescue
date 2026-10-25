--!strict
-- CallTypes: pure data for every call kind and spawn zone. No services; safe to load in Lune.
-- Payout numbers: docs 03 section 2 (Calm Bay base 250 Cash / 60 Rep, weights from docs 02
-- section 3, tutorial chain, fail-safe 10%, big-call shares). Numbers without a doc source: -- tune.
--
-- World frame (WorldConfig, docs/23 (p)): sea level Y = 0, an open lagoon at the origin ringed by the six player
-- islands 470 out (HubLayout, coves facing out), the outer islands beyond. Calls count from the player's berth.

export type Interaction = {
	kind: "Pull",
	holdSeconds: number, -- ProximityPrompt hold time
	range: number, -- studs: how close the player must be to trigger the prompt
	vehicleRange: number, -- studs: how close the player's boat must be to the victim
}

export type CallKind = {
	id: string,
	displayName: string,
	weight: number, -- payout weight (docs 02 section 3)
	timer: number, -- seconds from accept until the fail-safe (harbour patrol) takes over
	victims: number, -- people to pick up
	interaction: Interaction,
	zones: { string }, -- spawn zone ids (SpawnZones below) this kind may use
	isBig: boolean,
	dive: boolean?, -- a diver on the seabed at a CallTypes.DiveSites wreck (zones = their islands)
}

-- A wreck on the seabed (docs/23 (h) "Sub pen"): `wreck` its centre on the seabed, `at` the diver's feet
-- beside it, `hull` = build a placeholder hull there (no wreck in the world yet), `yaw` its heading (deg).
export type DiveSite = {
	id: string,
	island: string,
	wreck: Vector3,
	at: Vector3,
	hull: boolean,
	yaw: number,
}

export type SpawnZone = {
	id: string,
	displayName: string,
	center: Vector3, -- ring centre (cove / fromHome zones: the player's berth instead)
	minRadius: number,
	maxRadius: number,
	area: "Open" | "Outer", -- Open = any open water, Outer = also Areas.OuterMin from the ring centre (CallLogic.isWater)
	timerMultiplier: number, -- longer timers for storm beginner calls (docs 02 section 8)
	fallback: Vector3?, -- fixed sites; nil: CallLogic.homeFallback (open water out past your island)
	reach: number?, -- distance-tier zones (docs/23 e.2): offered once the player's craft reach is at least this
	cove: boolean?, -- a cone straight out of your island's cove (CallLogic.pickSpawnPoint)
	fromHome: boolean?, -- a ring round your berth
	island: boolean?, -- an outer island's ring: offered when its centre is within reach of your berth
}

local HubLayout = require(script.Parent.Parent.Config.HubLayout)
local RipCurrent = require(script.Parent.Parent.RipCurrent)
local WorldConfig = require(script.Parent.Parent.Config.WorldConfig)

local CallTypes = {}

-- Where calls are measured from: the centre of the ring of islands (docs/23 (p); HubLayout.Center at sea level).
CallTypes.STATION = Vector3.new(HubLayout.Center.X, 0, HubLayout.Center.Z)

-- the fixed scenes (docs/23 (p)): the ferry in open sea south of the ring (between Plot2 and Plot3, 1,000 studs out
-- from the centre), the rip off Puffin Isle's beach (shared/RipCurrent.Beach)
local FERRY_AT = Vector3.new(0, 0, 1000)
local RIP_AT = RipCurrent.point(RipCurrent.Beach, 120, 0)

-- Travel budget (docs 02 section 4.1): about 45 s out with the zone's intended vehicle (jet ski).
-- Cruise is below top speed: waves, turns and the trip out through the harbour mouth. -- tune
CallTypes.TRAVEL_SECONDS = 45
CallTypes.CRUISE_FACTOR = 0.5

CallTypes.Payout = {
	BaseCash = 250, -- Calm Bay (and harbour mouth storm calls), docs 03 section 2
	BaseRep = 60,
	Grade = { Gold = 1.25, Silver = 1.0, Bronze = 0.75 },
	GoldUnder = 0.6, -- finished in under 60% of the timer
	SilverUnder = 0.85, -- the "late" warning point; after it, Bronze -- tune
	CrewBonusPerMember = 0.1, -- +10% per extra member
	CrewBonusMax = 0.3, -- up to +30% for four
	FailSafeShare = 0.1, -- timer ran out (or a crew member with no role action): 10% Cash, no Rep
	Tutorial = {
		{ cash = 500, rep = 150 }, -- call 1
		{ cash = 300, rep = 80 }, -- calls 2 to 5
		{ cash = 300, rep = 80 },
		{ cash = 300, rep = 80 },
		{ cash = 300, rep = 80 },
	},
	BigVictimShare = 0.6, -- per victim, to the player who delivers it (x zone base)
	BigBonusCash = 5, -- completion bonus to every helper (x zone base), scaled by share saved
	BigBonusRep = 3,
}

CallTypes.Scheduler = {
	OfferDelay = 9, -- seconds after a player is free before the next offer (within ~10 s) -- tune
	FirstOfferDelay = 3, -- a new player's first call (docs 02 section 2, 0:02) -- tune
	OfferSeconds = 180, -- docs/16 K2: the call stands while you run to the bay and head out -- tune
	LateGrace = 90, -- a call with a survivor aboard at timer end gets this long to deliver -- tune
}

CallTypes.Kinds = {
	Swimmer = {
		id = "Swimmer",
		displayName = "Swimmer in Trouble",
		weight = 1.0,
		timer = 150, -- tune
		victims = 1,
		interaction = { kind = "Pull", holdSeconds = 1.5, range = 14, vehicleRange = 30 },
		zones = { "Near", "CalmBay", "Outer", "HarbourMouth" },
		isBig = false,
	},
	DriftingCraft = {
		id = "DriftingCraft",
		displayName = "Drifting Craft",
		weight = 1.1,
		timer = 180, -- tune
		victims = 2,
		interaction = { kind = "Pull", holdSeconds = 1.5, range = 14, vehicleRange = 30 },
		zones = { "CalmBay", "Outer", "HarbourMouth" },
		isBig = false,
	},
	CapsizedFerry = {
		id = "CapsizedFerry",
		displayName = "Capsized Ferry",
		weight = 1.0, -- big calls pay by share, not weight (docs 03 section 2)
		timer = 420, -- its own 7-minute timer (docs 02 section 3.1, 6 to 8 min)
		victims = 4, -- base; scaled to at least one per player (CallLogic.bigCallVictimCount)
		interaction = { kind = "Pull", holdSeconds = 1.5, range = 14, vehicleRange = 30 },
		zones = { "FerrySite" },
		isBig = true,
	},
	RipCurrent = {
		id = "RipCurrent",
		displayName = "Rip Current",
		weight = 0.9, -- docs/02 section 3
		timer = 600,
		victims = 1,
		interaction = { kind = "Pull", holdSeconds = 1.5, range = 14, vehicleRange = 30 },
		zones = { "BeachRip" },
		isBig = false,
	},
	Sinking = {
		id = "Sinking",
		displayName = "Sinking Vessel",
		weight = 1.2, -- docs/02 section 3
		timer = 480,
		victims = 3,
		interaction = { kind = "Pull", holdSeconds = 1.5, range = 14, vehicleRange = 30 },
		zones = { "Offshore", "FarSea", "DeepSea" }, -- a distance tier (CallLogic.chooseCall)
		isBig = false,
	},
	VesselFire = {
		id = "VesselFire",
		displayName = "Vessel Fire",
		weight = 1.5, -- docs/02 section 3: all but Calm Bay
		timer = 480,
		victims = 2,
		interaction = { kind = "Pull", holdSeconds = 1.5, range = 14, vehicleRange = 30 },
		zones = { "Offshore", "FarSea", "DeepSea" },
		isBig = false,
	},
	WildlifeRescue = {
		id = "WildlifeRescue",
		displayName = "Wildlife Rescue",
		weight = 0.8, -- docs/02 section 3: a light call
		timer = 420,
		victims = 1,
		interaction = { kind = "Pull", holdSeconds = 1.5, range = 14, vehicleRange = 30 },
		zones = { "Near", "CalmBay" },
		isBig = false,
	},
	-- docs/23 (h) "Sub pen": a diver trapped at a wreck on the seabed; only the submarine reaches them.
	-- Not in NormalKinds: CallLogic.chooseCall offers it to sub owners (DIVER_CHANCE, from DIVER_FROM_CALL).
	Diver = {
		id = "Diver",
		displayName = "Diver at a Wreck",
		weight = 1.4, -- tune
		timer = 600, -- x1.3 at the islands = 13 min; the sub runs 40 surfaced, a far wreck ~2.5 min -- tune
		victims = 1,
		interaction = { kind = "Pull", holdSeconds = 1.5, range = 14, vehicleRange = 30 },
		zones = {}, -- the islands of CallTypes.DiveSites (filled below)
		isBig = false,
		dive = true,
	},
} :: { [string]: CallKind }

CallTypes.DIVER_CHANCE = 1 / 6 -- of a sub owner's calls -- tune
CallTypes.DIVER_FROM_CALL = 3 -- the first call number a diver can be

-- Normal (non-big) kinds, in offer-weight order.
CallTypes.NormalKinds = {
	"Swimmer",
	"DriftingCraft",
	"RipCurrent",
	"Sinking",
	"VesselFire",
	"WildlifeRescue",
}
CallTypes.KindWeights = {
	Swimmer = 0.45,
	DriftingCraft = 0.3,
	RipCurrent = 0.2,
	Sinking = 0.16,
	VesselFire = 0.2,
	WildlifeRescue = 0.16,
} -- tune

-- Fixed chain for a player's first calls (docs/16 B3, B4, B9), each { kind, zone, victims? }. The
-- cold open is call 1, so a new player meets the chain from entry 2: one aboard a drifting dinghy, then
-- two (a jet ski holds one: the second waits for another trip or a bigger boat), then the seal pup.
-- docs/23 e.2: only calls 1-2 stay in the harbour; from call 3 the zone is a distance tier (no zone here).
CallTypes.TutorialChain = {
	{ kind = "Swimmer", zone = "Near" },
	{ kind = "DriftingCraft", zone = "CalmBay", victims = 1 },
	{ kind = "DriftingCraft", victims = 2 },
	{ kind = "Swimmer" },
	{ kind = "WildlifeRescue" },
} :: { { kind: string, zone: string?, victims: number? } }

-- Distance tiers (docs/23 e.2): how far out (studs from their berth) a player's best craft takes calls.
-- Keyed by craft, not top speed: the RIB and lifeboat are slower than the jet ski but are the bigger
-- earned craft. Capped by rank (CallLogic.craftReach): a Robux craft goes no farther than the free craft
-- the player's rank has unlocked. No other craft: the jet ski. -- tune
CallTypes.CraftReach = {
	JetSki = 2000,
	RIB = 3500,
	Lifeboat = 5500,
	Submarine = 5500, -- the lifeboat's tier (both Coxswain)
	RescueHelicopter = 5500, -- top tier (Rescue Pilot)
	StormRunner = 5500,
	Tidewalker = 5500,
	RiptideX = 5500,
	GildedGull = 5500,
} :: { [string]: number }
CallTypes.BASE_REACH = 2000

-- Pay x (distance / PayPerStuds), clamped to 1..PayMax (CallLogic.distancePay). x1 inside ~1,500 studs (the harbour
-- approaches), then about pays for the extra travel (docs/23 (i), tests/Pacing.spec.luau). -- tune
CallTypes.Distance = { PayPerStuds = 1500, PayMax = 4 }
-- A call landed farther than this from your berth pays for the trip sailed
-- from your berth (CallLogic.deliveredPay). -- tune
CallTypes.HOME_RADIUS = 150
-- Tutorial calls spawn in a cone this many degrees either side of straight out of your cove (ring centre -> berth).
CallTypes.COVE_HALF_ANGLE = 35

CallTypes.SpawnZones = {
	-- Calls 1-2 (docs/23 (k)): open water just off your own island's cove (studs from your berth, in the
	-- COVE_HALF_ANGLE cone), never behind the island or under a bridge.
	Near = {
		id = "Near",
		displayName = "Your Cove",
		center = CallTypes.STATION,
		minRadius = 150,
		maxRadius = 220,
		area = "Open",
		timerMultiplier = 1.2,
		cove = true,
	},
	CalmBay = {
		id = "CalmBay",
		displayName = "Your Cove",
		center = CallTypes.STATION,
		minRadius = 180,
		maxRadius = 300,
		area = "Open",
		timerMultiplier = 1,
		cove = true,
	},
	-- Storm beginner calls just past your cove: full storm waves, a short ride.
	HarbourMouth = {
		id = "HarbourMouth",
		displayName = "Cove Mouth",
		center = CallTypes.STATION,
		minRadius = 300,
		maxRadius = 450,
		area = "Outer",
		timerMultiplier = 1.4,
		cove = true,
	},
	-- The open water between the six islands and the outer islands (free-roam swimmers).
	Outer = {
		id = "Outer",
		displayName = "Open Water",
		center = CallTypes.STATION,
		minRadius = 1200,
		maxRadius = 1900,
		area = "Outer",
		timerMultiplier = 1.3,
	},
	-- The big call, in open sea south of the ring.
	FerrySite = {
		id = "FerrySite",
		displayName = "Ferry Lane",
		center = FERRY_AT,
		minRadius = 0,
		maxRadius = 0,
		area = "Open",
		timerMultiplier = 1,
		fallback = FERRY_AT,
	},
	-- Rip-current beach rescue (docs/09 section 8.4): one place, the channel off Puffin Isle's beach
	-- (shared/RipCurrent.Beach); the casualty starts 120 studs down the rip: origin + direction * 120.
	BeachRip = {
		id = "BeachRip",
		displayName = "Puffin Beach",
		center = RIP_AT,
		minRadius = 0,
		maxRadius = 0,
		area = "Open",
		timerMultiplier = 1,
		fallback = RIP_AT,
	},
} :: { [string]: SpawnZone }

-- Open-sea rings round your berth, one per tier (CraftReach), kept Areas.OuterMin from the ring centre.
local RINGS: { [string]: { number } } =
	{ Offshore = { 500, 2000 }, FarSea = { 2000, 3500 }, DeepSea = { 3500, 5500 } }
for id, ring in RINGS do
	CallTypes.SpawnZones[id] = {
		id = id,
		displayName = "Open Water",
		center = CallTypes.STATION,
		minRadius = ring[1],
		maxRadius = ring[2],
		area = "Outer",
		timerMultiplier = 1.3,
		reach = ring[2],
		fromHome = true,
	}
end
-- Every outer island (WorldConfig.Islands): a ring of open water just off it.
for _, island in WorldConfig.Islands do
	CallTypes.SpawnZones[island.id] = {
		id = island.id,
		displayName = island.name,
		center = island.center,
		minRadius = island.radius + 60,
		maxRadius = island.radius + 400,
		area = "Outer",
		timerMultiplier = 1.3,
		island = true,
	}
end

-- Dive sites (docs/23 (h)), Studio-sampled 2026-10-25 (terrain raycasts; the seaplane re-sampled on the hub map, WP-19c): the mail seaplane
-- is the CoastArt wreck (WorldConfig POI MailSeaplane); the SS Gannet Star (docs/10) and the Wreck Reef
-- hulk are placeholder hulls (server/Ops/DiverRescue). Every diver is over 25 studs down.
CallTypes.DiveSites = {
	{
		id = "MailSeaplane",
		island = "SkerryIsle",
		wreck = Vector3.new(1300, -34.8, 1500),
		at = Vector3.new(1322, -35, 1500),
		hull = false,
		yaw = -35,
	},
	{
		id = "GannetStar",
		island = "GannetRock",
		wreck = Vector3.new(3638, -42, 3420),
		at = Vector3.new(3660, -42.3, 3420),
		hull = true,
		yaw = 0, -- along Z
	},
	{
		id = "ReefHulk",
		island = "WreckReef",
		wreck = Vector3.new(-3520, -45.9, 4200),
		at = Vector3.new(-3520, -45.9, 4222),
		hull = true,
		yaw = 90, -- along X
	},
} :: { DiveSite }
for _, site in CallTypes.DiveSites do
	table.insert(CallTypes.Kinds.Diver.zones, site.island)
end

-- Open water on the new map (CallLogic.isWater; the server adds its terrain / route raycasts on top).
CallTypes.Areas = {
	Shore = 40, -- studs off the player islands' rims (HubLayout radii)
	BridgeClear = 36, -- studs from a bridge's centre line: half its deck + 30
	OuterMin = 1200, -- "Outer" area: this far from the ring centre, well past the six islands
	MapMargin = 120, -- stay this far inside GameConfig.MapRadius
}

CallTypes.BigCall = {
	FerryVictimMinRadius = 14,
	FerryVictimMaxRadius = 34,
}

function CallTypes.get(kind: string): CallKind?
	return CallTypes.Kinds[kind]
end

return CallTypes
