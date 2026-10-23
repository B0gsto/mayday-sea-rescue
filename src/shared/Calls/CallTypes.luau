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
}

local CallTypes = {}

-- Where the radio dispatches from: the launch bays (map/Build.luau Bay1..Bay4).
CallTypes.STATION = Vector3.new(-95, 0, 50)

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
} :: { [string]: CallKind }

-- Normal (non-big) kinds, in offer-weight order.
CallTypes.NormalKinds = {
	"Swimmer",
	"DriftingCraft",
	"Cliff",
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
} -- tune

-- Fixed chain for a player's first calls (docs/16 B3, B4, B9), each { kind, zone, victims? }. The
-- cold open is call 1, so a new player meets the chain from entry 2: one aboard a drifting dinghy, then
-- two (a jet ski holds one: the second waits for another trip or a bigger boat), then the seal pup.
CallTypes.TutorialChain = {
	{ kind = "Swimmer", zone = "Near" },
	{ kind = "DriftingCraft", zone = "CalmBay", victims = 1 },
	{ kind = "DriftingCraft", zone = "CalmBay", victims = 2 },
	{ kind = "Swimmer", zone = "CalmBay" },
	{ kind = "WildlifeRescue", zone = "Near" },
}

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

-- Water areas (studs) used to reject spawn points on land, the dock or the breakwater.
CallTypes.Areas = {
	Inside = { minX = -290, maxX = 290, minZ = 30, maxZ = 340 },
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
