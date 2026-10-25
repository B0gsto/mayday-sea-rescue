--!strict
-- CallTypes: pure data for every call kind and spawn zone. No services; safe to load in Lune.
-- Payout numbers: docs 03 section 2 (Calm Bay base 250 Cash / 60 Rep, weights from docs 02
-- section 3, tutorial chain, fail-safe 10%, big-call shares). Numbers without a doc source: -- tune.
--
-- World frame (GameConfig): sea level Y = 0, Port Haven north (-Z), harbour opens south (+Z).
-- The station's launch bays sit at about (-95, 0, 50) on the east side of the dock.

export type Interaction = {
	kind: "Pull",
	holdSeconds: number, -- ProximityPrompt hold time
	range: number, -- studs: how close the player must be to trigger the prompt
	vehicleRange: number, -- studs: how close the player's boat must be to the victim
}

export type CallKind = {
	id: string,
	displayName: string,
	radioLine: string, -- shown on the call card
	weight: number, -- payout weight (docs 02 section 3)
	timer: number, -- seconds from accept until the fail-safe (harbour patrol) takes over
	victims: number, -- people to pick up
	interaction: Interaction,
	zones: { string }, -- spawn zone ids (SpawnZones below) this kind may use
	dropOffs: { string }, -- DropOff attribute values that complete it ("Dock", "Hospital")
	isBig: boolean,
	land: boolean?, -- the survivor is ashore at a CallTypes.LandSites site (zones = their islands)
	dive: boolean?, -- a diver on the seabed at a CallTypes.DiveSites wreck (zones = their islands)
}

-- A land call site (docs/23 e.3): `at` is the survivor's feet, `beach` the shore point the craft runs to.
export type LandSite = { id: string, island: string, beach: Vector3, at: Vector3 }

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
	center: Vector3, -- ring centre
	minRadius: number,
	maxRadius: number,
	area: "Inside" | "Outside", -- Inside = Calm Bay behind the breakwater, Outside = beyond it
	timerMultiplier: number, -- longer timers for storm beginner calls (docs 02 section 8)
	fallback: Vector3, -- used if random picks keep landing on land or walls
	reach: number?, -- distance-tier zones (docs/23 e.2): offered once the player's craft reach is at least this
}

local WorldConfig = require(script.Parent.Parent.Config.WorldConfig)

local CallTypes = {}

-- Where the radio dispatches from: the hub island's centre (docs/23 (k); HubLayout.Hub.center at sea level).
CallTypes.STATION = Vector3.new(0, 0, 0)

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
	FirstOfferDelay = 3, -- a new player's first radio call (docs 02 section 2, 0:02) -- tune
	OfferSeconds = 180, -- docs/16 K2: the call stands while you run to the bay and head out -- tune
	LateGrace = 90, -- a call with a survivor aboard at timer end gets this long to deliver -- tune
}

CallTypes.Kinds = {
	Swimmer = {
		id = "Swimmer",
		displayName = "Swimmer in Trouble",
		radioLine = "Mayday! Swimmer caught in the current!",
		weight = 1.0,
		timer = 150, -- tune
		victims = 1,
		interaction = { kind = "Pull", holdSeconds = 1.5, range = 14, vehicleRange = 30 },
		zones = { "Near", "CalmBay", "Outer", "HarbourMouth" },
		dropOffs = { "Dock", "Hospital" },
		isBig = false,
	},
	DriftingCraft = {
		id = "DriftingCraft",
		displayName = "Drifting Craft",
		radioLine = "A dinghy is drifting out with two aboard!",
		weight = 1.1,
		timer = 180, -- tune
		victims = 2,
		interaction = { kind = "Pull", holdSeconds = 1.5, range = 14, vehicleRange = 30 },
		zones = { "CalmBay", "Outer", "HarbourMouth" },
		dropOffs = { "Dock", "Hospital" },
		isBig = false,
	},
	CapsizedFerry = {
		id = "CapsizedFerry",
		displayName = "Capsized Ferry",
		radioLine = "All stations! The Gale Queen has capsized off the harbour mouth!",
		weight = 1.0, -- big calls pay by share, not weight (docs 03 section 2)
		timer = 420, -- its own 7-minute timer (docs 02 section 3.1, 6 to 8 min)
		victims = 4, -- base; scaled to at least one per player (CallLogic.bigCallVictimCount)
		interaction = { kind = "Pull", holdSeconds = 1.5, range = 14, vehicleRange = 30 },
		zones = { "FerrySite" },
		dropOffs = { "Dock", "Hospital" },
		isBig = true,
	},
	Cliff = {
		id = "Cliff",
		displayName = "Cliff Casualty",
		radioLine = "Walker in the water below Haven Head, one casualty.",
		weight = 1.4, -- docs/02 section 3: cliff is a Skerries-rate rescue
		timer = 600,
		victims = 1,
		interaction = { kind = "Pull", holdSeconds = 1.5, range = 14, vehicleRange = 30 },
		zones = { "HavenHeadCliff" },
		dropOffs = { "Dock", "Hospital" },
		isBig = false,
	},
	RipCurrent = {
		id = "RipCurrent",
		displayName = "Rip Current",
		radioLine = "Swimmer caught in a rip current off Haven Sands, one casualty.",
		weight = 0.9, -- docs/02 section 3
		timer = 600,
		victims = 1,
		interaction = { kind = "Pull", holdSeconds = 1.5, range = 14, vehicleRange = 30 },
		zones = { "HavenSandsRip" },
		dropOffs = { "Dock", "Hospital" },
		isBig = false,
	},
	Sinking = {
		id = "Sinking",
		displayName = "Sinking Vessel",
		radioLine = "Fishing boat taking water off the harbour, three aboard.",
		weight = 1.2, -- docs/02 section 3
		timer = 480,
		victims = 3,
		interaction = { kind = "Pull", holdSeconds = 1.5, range = 14, vehicleRange = 30 },
		zones = { "SinkingSite" },
		dropOffs = { "Dock", "Hospital" },
		isBig = false,
	},
	VesselFire = {
		id = "VesselFire",
		displayName = "Vessel Fire",
		radioLine = "MAYDAY from the motor cruiser Firefly: engine fire, two people in the water.",
		weight = 1.5, -- docs/02 section 3: all but Calm Bay
		timer = 480,
		victims = 2,
		interaction = { kind = "Pull", holdSeconds = 1.5, range = 14, vehicleRange = 30 },
		zones = { "Outer" },
		dropOffs = { "Dock", "Hospital" },
		isBig = false,
	},
	WildlifeRescue = {
		id = "WildlifeRescue",
		displayName = "Wildlife Rescue",
		radioLine = "Wildlife in trouble off the harbour, request a rescue swimmer.",
		weight = 0.8, -- docs/02 section 3: a light call
		timer = 420,
		victims = 1,
		interaction = { kind = "Pull", holdSeconds = 1.5, range = 14, vehicleRange = 30 },
		zones = { "Near", "CalmBay" },
		dropOffs = { "Dock" },
		isBig = false,
	},
	-- docs/23 e.3: ashore (cut off by the tide, on a ledge, lost inland); reached on foot, they follow you aboard
	Stranded = {
		id = "Stranded",
		displayName = "Stranded Ashore",
		radioLine = "Walker cut off on the shore, one casualty.",
		weight = 1.3, -- tune
		timer = 600,
		victims = 1,
		interaction = { kind = "Pull", holdSeconds = 1.5, range = 14, vehicleRange = 30 },
		zones = {}, -- the islands of CallTypes.LandSites (filled below)
		dropOffs = { "Dock", "Hospital" },
		isBig = false,
		land = true,
	},
	-- docs/23 (h) "Sub pen": a diver trapped at a wreck on the seabed; only the submarine reaches them.
	-- Not in NormalKinds: CallLogic.chooseCall offers it to sub owners (DIVER_CHANCE, from DIVER_FROM_CALL).
	Diver = {
		id = "Diver",
		displayName = "Diver at a Wreck",
		radioLine = "Diver trapped at a wreck, one casualty.",
		weight = 1.4, -- tune
		timer = 600, -- x1.3 at the islands = 13 min; the sub runs 40 surfaced, a far wreck ~2.5 min -- tune
		victims = 1,
		interaction = { kind = "Pull", holdSeconds = 1.5, range = 14, vehicleRange = 30 },
		zones = {}, -- the islands of CallTypes.DiveSites (filled below)
		dropOffs = { "Dock", "Hospital" },
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
	"Cliff",
	"Stranded",
	"RipCurrent",
	"Sinking",
	"VesselFire",
	"WildlifeRescue",
}
CallTypes.KindWeights = {
	Swimmer = 0.45,
	DriftingCraft = 0.3,
	Cliff = 0.18,
	RipCurrent = 0.2,
	Sinking = 0.16,
	VesselFire = 0.2,
	WildlifeRescue = 0.16,
	Stranded = 0.41, -- about 1 call in 5 once past the tutorial chain
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

-- Distance tiers (docs/23 e.2): how far out (studs from the station) a player's best craft takes calls.
-- Keyed by craft, not top speed: the RIB and lifeboat are slower than the jet ski but are the bigger
-- earned craft. Capped by rank (CallLogic.craftReach): a Robux craft goes no farther than the free craft
-- the player's rank has unlocked. No other craft: the jet ski. -- tune
CallTypes.CraftReach = {
	JetSki = 2000,
	RIB = 3500,
	Lifeboat = 5500,
	Submarine = 5500, -- the lifeboat's tier (both Coxswain)
	RescueHelicopter = 5500, -- top tier (Rescue Pilot)
	Seaplane = 5500,
	StormRunner = 5500,
	Tidewalker = 5500,
	RiptideX = 5500,
	GildedGull = 5500,
} :: { [string]: number }
CallTypes.BASE_REACH = 2000

-- Pay x (distance / PayPerStuds), clamped to 1..PayMax (CallLogic.distancePay). x1 inside ~1,500 studs (the harbour
-- approaches), then about pays for the extra travel (docs/23 (i), tests/Pacing.spec.luau). -- tune
CallTypes.Distance = { PayPerStuds = 1500, PayMax = 4 }
-- Drop-offs within this of the station are Port Haven (pads, marina docks, station slip); a call landed beyond
-- it (Haven Sands slipway, ~1,100 out) pays for the trip sailed (CallLogic.deliveredPay). -- tune
CallTypes.PORT_HAVEN_RADIUS = 800

-- Island call zones: a ring of open water just off each island (WorldConfig.Islands), offered from this
-- reach (must be a ring's reach: its fallback). Not St Elowen's Mount or The Arches: Great Gale blocks
-- every straight sea line from the harbour mouth (Studio-sampled 2026-10-25).
CallTypes.IslandReach = {
	SkerryIsle = 2000,
	PuffinIsle = 3500,
	GannetRock = 5500,
	Penwyn = 5500,
	WreckReef = 5500,
	MermaidLagoon = 5500,
} :: { [string]: number }

local OUTER_MAX = CallTypes.TRAVEL_SECONDS * 75 * CallTypes.CRUISE_FACTOR -- JetSki topSpeed 75

CallTypes.SpawnZones = {
	-- First call: a short hop from the bays, inside the breakwater.
	Near = {
		id = "Near",
		displayName = "Calm Bay",
		center = CallTypes.STATION,
		minRadius = 110,
		maxRadius = 220,
		area = "Inside",
		timerMultiplier = 1.2,
		fallback = Vector3.new(40, 0, 180),
	},
	CalmBay = {
		id = "CalmBay",
		displayName = "Calm Bay",
		center = CallTypes.STATION,
		minRadius = 160,
		maxRadius = 420,
		area = "Inside",
		timerMultiplier = 1,
		fallback = Vector3.new(150, 0, 260),
	},
	-- Beyond the breakwater, sized by the 45 s jet ski budget (about 840 to 1690 studs out).
	Outer = {
		id = "Outer",
		displayName = "Open Water",
		center = CallTypes.STATION,
		minRadius = OUTER_MAX * 0.5,
		maxRadius = OUTER_MAX,
		area = "Outside",
		timerMultiplier = 1.3,
		fallback = Vector3.new(0, 0, 1100),
	},
	-- Storm beginner calls just outside the gap: full storm waves, a short ride.
	HarbourMouth = {
		id = "HarbourMouth",
		displayName = "Harbour Mouth",
		center = Vector3.new(0, 0, 420),
		minRadius = 0,
		maxRadius = 30,
		area = "Outside",
		timerMultiplier = 1.4,
		fallback = Vector3.new(0, 0, 420),
	},
	FerrySite = {
		id = "FerrySite",
		displayName = "Harbour Mouth",
		center = Vector3.new(60, 0, 500),
		minRadius = 0,
		maxRadius = 0,
		area = "Outside",
		timerMultiplier = 1,
		fallback = Vector3.new(60, 0, 500),
	},
	-- Cliff casualty: in the surf off the ledge at the foot of Haven Head (the shelf is at (1740, 22, 890),
	-- facing +Z out to sea; docs/09 section 8.5).
	HavenHeadCliff = {
		id = "HavenHeadCliff",
		displayName = "Haven Head",
		center = Vector3.new(1740, 0, 925),
		minRadius = 0,
		maxRadius = 0,
		area = "Outside",
		timerMultiplier = 1,
		fallback = Vector3.new(1740, 0, 925),
	},
	-- Rip-current beach rescue (docs/09 section 8.4): one place, the channel off Haven Sands.
	-- The casualty starts about 120 studs down the rip and is carried seaward (shared/RipCurrent):
	-- origin + direction * 120, in the water off the Haven Sands waterline.
	HavenSandsRip = {
		id = "HavenSandsRip",
		displayName = "Haven Sands",
		center = Vector3.new(888, 0, 426),
		minRadius = 0,
		maxRadius = 0,
		area = "Outside",
		timerMultiplier = 1,
		fallback = Vector3.new(888, 0, 426),
	},
	-- Sinking vessel (docs/09 section 8.1): fixed open water in Calm Bay, a short run from the bays.
	SinkingSite = {
		id = "SinkingSite",
		displayName = "Calm Bay",
		center = Vector3.new(150, 0, 260),
		minRadius = 0,
		maxRadius = 0,
		area = "Inside",
		timerMultiplier = 1,
		fallback = Vector3.new(150, 0, 260),
	},
} :: { [string]: SpawnZone }

-- Open-sea rings around the station, one per tier (the backup when an island's near side is blocked).
local RINGS: { [string]: { number } } =
	{ Offshore = { 600, 2000 }, FarSea = { 2000, 3500 }, DeepSea = { 3500, 5500 } }
local ringFallback: { [number]: Vector3 } = {}
for id, ring in RINGS do
	local minR, maxR = ring[1], ring[2]
	ringFallback[maxR] = CallTypes.STATION + Vector3.new(0, 0, (minR + maxR) / 2) -- due south: open sea
	CallTypes.SpawnZones[id] = {
		id = id,
		displayName = "Open Water",
		center = CallTypes.STATION,
		minRadius = minR,
		maxRadius = maxR,
		area = "Outside",
		timerMultiplier = 1.3,
		fallback = ringFallback[maxR],
		reach = maxR,
	}
end
-- only islands that exist in the map data get a zone
for _, island in WorldConfig.Islands do
	local reach = CallTypes.IslandReach[island.id]
	if reach then
		CallTypes.SpawnZones[island.id] = {
			id = island.id,
			displayName = island.name,
			center = island.center,
			minRadius = island.radius + 60,
			maxRadius = island.radius + 400,
			area = "Outside",
			timerMultiplier = 1.3,
			fallback = ringFallback[reach], -- its tier's open sea (Studio-checked routable)
			reach = reach,
		}
	end
end

-- Land call sites (docs/23 e.3), Studio-sampled 2026-10-25 (build/wp9 terrain raycasts): `beach` is the
-- first dry terrain coming in from water over 2 deep, `at` is up a path whose every 3-stud step rises under
-- 2.4 studs. Only islands with a CallTypes.IslandReach (routable from the harbour); offered within it.
CallTypes.LandSites = {
	-- cut off by the tide
	{
		id = "SkerryCove",
		island = "SkerryIsle",
		beach = Vector3.new(1606, 1, 1911),
		at = Vector3.new(1625, 5.1, 1896),
	},
	{
		id = "PuffinStrand",
		island = "PuffinIsle",
		beach = Vector3.new(-2511, 1.1, 3069),
		at = Vector3.new(-2517, 5.6, 3092),
	},
	{
		id = "GannetLanding",
		island = "GannetRock",
		beach = Vector3.new(3390, 1.7, 3460),
		at = Vector3.new(3413, 7.5, 3468),
	},
	-- on a ledge
	{
		id = "SkerryLedge",
		island = "SkerryIsle",
		beach = Vector3.new(1550, 1.4, 1894),
		at = Vector3.new(1592, 21.1, 1870),
	},
	{
		id = "PuffinLedge",
		island = "PuffinIsle",
		beach = Vector3.new(-2411, 0.6, 3072),
		at = Vector3.new(-2442, 16, 3127),
	},
	{
		id = "WreckReefLedge",
		island = "WreckReef",
		beach = Vector3.new(-3777, 0.9, 4285),
		at = Vector3.new(-3800, 33.8, 4198),
	},
	-- lost inland
	{
		id = "PenwynMoor",
		island = "Penwyn",
		beach = Vector3.new(-4244, 0.9, -621),
		at = Vector3.new(-4399, 7.1, -531),
	},
	{
		id = "LagoonDunes",
		island = "MermaidLagoon",
		beach = Vector3.new(172, 0.8, 4875),
		at = Vector3.new(203, 5.1, 5052),
	},
} :: { LandSite }
for _, site in CallTypes.LandSites do
	local zones = CallTypes.Kinds.Stranded.zones
	if not table.find(zones, site.island) then
		table.insert(zones, site.island)
	end
end

-- Dive sites (docs/23 (h)), Studio-sampled 2026-10-25 (terrain raycasts, build/wp10c): the mail seaplane
-- is the CoastArt wreck (WorldConfig POI MailSeaplane); the SS Gannet Star (docs/10) and the Wreck Reef
-- hulk are placeholder hulls (server/Ops/DiverRescue). Every diver is over 25 studs down.
CallTypes.DiveSites = {
	{
		id = "MailSeaplane",
		island = "SkerryIsle",
		wreck = Vector3.new(1300, -40.8, 1200),
		at = Vector3.new(1300, -39.8, 1222),
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

-- Water areas (studs) used to reject spawn points on land, the dock or the breakwater.
CallTypes.Areas = {
	-- elbow: each breakwater dog-legs from its knee (x +-320, z kneeW / kneeE) to its head (x +-headW / headE, z 360)
	-- (Harbour.BREAKWATER, west and east differ); points within `clear` studs of that leg's centreline, or seaward
	-- of it, are not inside
	Inside = {
		minX = -290,
		maxX = 290,
		minZ = 30,
		maxZ = 340,
		elbow = {
			x = 320,
			far = 360,
			clear = 20,
			kneeW = 334,
			headW = 294,
			kneeE = 196,
			headE = 164,
		},
	},
	DockKeepOut = { minX = -145, maxX = -75, maxZ = 125 }, -- dock, bays and drop-off pad
	OutsideMinZ = 392, -- breakwater heads end at z = 368
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
