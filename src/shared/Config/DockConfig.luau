--!strict
-- DockConfig (docs/23 (q), WP-28): the unlock tree. Every buildable thing on your island is one row of
-- `Buildings`: its Cash price, what it `needs` (other rows; {} = only the bare jetty you start with), an optional
-- Robux product (skips the Cash, never `needs`), where it stands (`spot`, berth frame) and its footprint. Adding
-- content = adding a row (and its key to BUILDINGS). The rules that read it: shared/UnlockTree
-- (tests/UnlockTree.spec.luau). Piece geometry lives in shared/DockPieces; DockService builds it, the build
-- tablet prices it.
--   Jetty (start)
--   +- Pontoon (2nd berth) -- Lookout tower -- Helipad -- Hangar -> Helicopter
--   |    +- Clinic                 +- Rescue boathouse
--   +- Workshop -+- Boathouse -> RIB, boat board, paint booth, Robux boats
--   |            |    +- Lifeboat slip -> Lifeboat
--   |            |    +- Crane -- Sub pen -> Submarine
--   |            +- Boat yard
--   +- Fish shed
--   +- Station (Boathouse + Lookout tower) -- Trophy hall
--   Prices and pacing: docs/23 (r) (tests/Pacing; R$ floors in tests/DockConfig cap the late Cash prices).
--   Decor: the jetty only.
local Marina = require(script.Parent.Parent:WaitForChild("Marina"))

export type Building = {
	name: string, -- the card's 1-3 words
	desc: string, -- the build tablet's focus line, <= 10 words
	cash: number,
	needs: { string }, -- DockConfig.Buildings keys that must be owned first
	product: string?, -- MonetizationConfig.Products key
	robux: number?, -- its launch price (docs/23 (i): never a cheaper way to Cash than the packs)
	spot: CFrame, -- berth frame, on the ground: the paper blueprint and the build camera's focus
	size: Vector2, -- footprint (x / z of `spot`)
	vehicles: { string }?, -- its own vehicle board's craft, in order (BoatBoard)
	worker: string?, -- a worker building (WP-26): a Lego cottage (DockPieces), its workers in front of the door (-Z)
	color: Color3?, -- the cottage's wall colour
	scale: number?, -- WP-25 r8/r9: built at size / scale, then scaled up round its spot (size = the scaled footprint)
}

local DockConfig = {}

local LOTS = Marina.LOTS
-- a spot on the island, `right` / `fwd` studs from its centre (RingLayout's island frame), turned `yaw` degrees
local function isle(right: number, fwd: number, yaw: number?): CFrame
	return Marina.ISLAND * CFrame.new(right, 0, -fwd) * CFrame.Angles(0, math.rad(yaw or 0), 0)
end

-- card order (roughly the tree's, left to right)
DockConfig.BUILDINGS = {
	"Pontoon",
	"Workshop",
	"FishShed",
	"Boathouse",
	"LookoutTower",
	"BoatYard",
	"LifeboatSlip",
	"Crane",
	"Helipad",
	"RescueBoathouse",
	"SubPen",
	"Hangar",
	"Station",
	"TrophyHall",
	"Clinic",
}

DockConfig.Buildings = {
	Pontoon = {
		name = "Pontoon",
		desc = "Moors a second boat beside your jetty.",
		cash = 2500, -- tune
		needs = {},
		product = "DockLevel2",
		robux = 35,
		spot = CFrame.new(16, 2.1, 2),
		size = Vector2.new(8, 50),
	},
	Workshop = {
		name = "Workshop",
		desc = "Builders work here. Unlocks the boathouse.",
		cash = 500, -- tune: the first build, right after the first rescue (tests/NewPlayerPace)
		needs = {},
		product = "DockWorkshop",
		robux = 15,
		spot = isle(60, -10, 90), -- open front onto the east lane (WP-25 layout)
		size = Vector2.new(29, 22), -- docs/24 C r3: pads 1.5x bigger (within the lot)
		scale = 1.2,
		worker = "Builder",
		color = Color3.fromRGB(250, 208, 40),
	},
	FishShed = {
		name = "Fish shed",
		desc = "Gatherers work here.",
		cash = 1500, -- tune
		needs = {},
		product = "DockFishShed",
		robux = 35,
		spot = isle(73, 105, 90), -- on the east quay, open front onto the cove walk
		size = Vector2.new(27, 20), -- docs/24 C r3: pads 1.5x bigger
		scale = 1.15,
		worker = "Gatherer",
		color = Color3.fromRGB(40, 96, 208),
	},
	Boathouse = {
		name = "Boathouse",
		desc = "Pick and paint boats. Unlocks the RIB.",
		cash = 2500, -- tune
		needs = { "Workshop" },
		product = "DockLevel3",
		robux = 35,
		spot = LOTS.Boathouse.cf,
		size = Vector2.new(34, 40) * 1.2,
		scale = 1.2,
	},
	LookoutTower = {
		name = "Lookout tower",
		desc = "A tall tower to spot calls from.",
		cash = 19000, -- tune
		needs = { "Pontoon" },
		product = "DockLevel4",
		robux = 75,
		spot = LOTS.LifeguardTower.cf,
		size = Vector2.new(10, 10) * 1.5,
		scale = 1.5,
	},
	BoatYard = {
		name = "Boat yard",
		desc = "Mechanics work here.",
		cash = 5000, -- tune
		needs = { "Workshop" },
		product = "DockBoatYard",
		robux = 75,
		spot = isle(85, -105), -- back right, open front onto the bridge path
		size = Vector2.new(32, 22), -- docs/24 C r3: pads 1.5x bigger
		scale = 1.15,
		worker = "Mechanic",
		color = Color3.fromRGB(250, 140, 30),
	},
	LifeboatSlip = {
		name = "Lifeboat slip",
		desc = "A slipway for the big lifeboat.",
		cash = 8000, -- tune
		needs = { "Boathouse" },
		product = "DockLifeboatSlip",
		robux = 99,
		spot = isle(138, 20, -90), -- on the east edge, the slipway runs off the plate into the sea
		size = Vector2.new(16, 22) * 1.5,
		scale = 1.5,
		color = Color3.fromRGB(60, 160, 220),
	},
	Crane = {
		name = "Crane",
		desc = "A slipway crane: relaunch with no wait.",
		cash = 25000, -- tune
		needs = { "Boathouse" },
		product = "DockCrane",
		robux = 99,
		spot = CFrame.new(16, Marina.DECK_TOP, 66),
		size = Vector2.new(8, 8),
	},
	Helipad = {
		name = "Helipad",
		desc = "A landing pad for a helicopter.",
		cash = 22000, -- tune
		needs = { "LookoutTower" },
		product = "DockHelipad",
		robux = 99,
		spot = LOTS.Helipad.cf,
		size = LOTS.Helipad.size,
	},
	RescueBoathouse = {
		name = "Rescue boathouse",
		desc = "Rescuers work here.",
		cash = 16000, -- tune
		needs = { "LookoutTower" },
		product = "DockRescueBoathouse",
		robux = 99,
		spot = isle(-70, 99, -90), -- on the west quay, open front onto the cove walk
		size = Vector2.new(29, 22), -- docs/24 C r3: pads 1.5x bigger
		scale = 1.15,
		worker = "Rescuer",
		color = Color3.fromRGB(224, 56, 40),
	},
	SubPen = {
		name = "Sub pen",
		desc = "A sub pen to launch your submarine.",
		cash = 38000, -- tune
		needs = { "Crane" },
		product = "DockSubPen",
		robux = 149,
		spot = LOTS.SubPen.cf,
		size = LOTS.SubPen.size,
		vehicles = { "Submarine" },
	},
	Hangar = {
		name = "Hangar",
		desc = "A hangar for your rescue helicopter.",
		cash = 32000, -- tune
		needs = { "Helipad" },
		product = "DockHangar",
		robux = 149,
		spot = LOTS.Hangar.cf,
		size = LOTS.Hangar.size * 1.3,
		scale = 1.3,
		vehicles = { "RescueHelicopter" },
	},
	Station = {
		name = "Station",
		desc = "A lit station and a beacon for the harbour.",
		cash = 51000, -- tune
		needs = { "Boathouse", "LookoutTower" },
		product = "DockLevel5",
		robux = 199,
		spot = LOTS.Station.cf,
		size = Vector2.new(60, 44),
	},
	TrophyHall = {
		name = "Trophy hall",
		desc = "Cups and island stamps on the station wall.",
		cash = 38000, -- tune
		needs = { "Station" },
		product = "DockTrophyHall",
		robux = 149,
		spot = LOTS.Station.cf * CFrame.new(-15.5, 0, -18),
		size = Vector2.new(20, 6),
	},
	Clinic = {
		name = "Clinic",
		desc = "Medics work here.",
		cash = 8000, -- tune
		needs = { "Pontoon" },
		product = "DockClinic",
		robux = 199,
		spot = isle(-85, -105), -- back left, open front onto the bridge path
		size = Vector2.new(27, 22), -- docs/24 C r3: pads 1.5x bigger
		scale = 1.15,
		worker = "Medic",
		color = Color3.fromRGB(242, 240, 232),
	},
} :: { [string]: Building }

-- Old saves (the dock-level ladder before WP-28): what each old level owns in the tree (ProgressionRules.migrate).
DockConfig.LEVEL_ITEMS = {
	[2] = { "Pontoon" },
	[3] = { "Workshop", "Boathouse" },
	[4] = { "LookoutTower", "Crane" },
	[5] = { "Station", "TrophyHall" },
} :: { [number]: { string } }

-- Blueprints (docs/23 (j) "Exploration feeds the plot", WP-21b): cosmetic buildings a quest chain unlocks (never
-- sold). Owned ones are data.dockBuildings[key]; DockService raises them on their island lot (Marina.LOTS[lot]).
DockConfig.Blueprints = {
	Lighthouse = { lot = "Spare1", desc = "Keeper Ives' lamp, earned on his quest." }, -- Quests/Data Lamp3
} :: { [string]: { lot: string, desc: string } }

-- Decorations (WP-14d): Lego set pieces on the free lots by the spawn. Bought from the build tablet's Decor tab
-- (Cash, or Robux) and kept in data.dockBuildings like buildings, so the save migration accepts them.
export type Decor = {
	name: string,
	cash: number,
	desc: string, -- the build tablet's focus line, <= 10 words
	color: string, -- Theme.Grad accent for the build card
	lot: string, -- Marina.LOTS key
	offset: Vector2, -- studs from the lot centre, x / z
	size: Vector2, -- footprint in studs (x / z)
	product: string?, -- MonetizationConfig.Products key (skips the Cash; decor needs only the jetty)
	robux: number?, -- its launch price (docs/23 (i))
}

DockConfig.DECOR = { "FlowerBed", "PicnicTable", "LampRow", "FlagPole", "Statue", "Fountain" }

DockConfig.Decorations = {
	FlowerBed = {
		name = "Flower bed",
		cash = 2000,
		product = "DecorFlowerBed",
		robux = 35,
		desc = "Bright Lego flowers by your spawn.",
		color = "pink",
		lot = "Spare2",
		offset = Vector2.new(-10, 0),
		size = Vector2.new(8, 8),
	},
	PicnicTable = {
		name = "Picnic table",
		cash = 5000,
		product = "DecorPicnicTable",
		robux = 49,
		desc = "A picnic table for crew breaks.",
		color = "green",
		lot = "Spare2",
		offset = Vector2.new(0, 0),
		size = Vector2.new(8, 8),
	},
	LampRow = {
		name = "Lamp row",
		cash = 9000,
		product = "DecorLampRow",
		robux = 75,
		desc = "A row of lamps that glow at night.",
		color = "yellow",
		lot = "Spare2",
		offset = Vector2.new(10, 0),
		size = Vector2.new(9, 6),
	},
	FlagPole = {
		name = "Flag pole",
		cash = 15000,
		product = "DecorFlagPole",
		robux = 99,
		desc = "A tall flag pole flying your colours.",
		color = "blue",
		lot = "Spare3",
		offset = Vector2.new(9, -8),
		size = Vector2.new(7, 7),
	},
	Statue = {
		name = "Statue",
		cash = 25000,
		product = "DecorStatue",
		robux = 199,
		desc = "A hero statue for your island.",
		color = "orange",
		lot = "Spare3",
		offset = Vector2.new(9, 0),
		size = Vector2.new(7, 7),
	},
	Fountain = {
		name = "Fountain",
		cash = 40000,
		product = "DecorFountain",
		robux = 199,
		desc = "A splashing fountain in the square.",
		color = "teal",
		lot = "Spare3",
		offset = Vector2.new(9, 8),
		size = Vector2.new(7, 7),
	},
} :: { [string]: Decor }

-- The building a MonetizationConfig product key builds, or nil.
function DockConfig.buildingFor(productKey: string): string?
	for key, b in DockConfig.Buildings do
		if b.product == productKey then
			return key
		end
	end
	return nil
end

-- Which building's board holds craft `id` (nil: the boat board's).
function DockConfig.buildingOf(id: string): string?
	for key, b in DockConfig.Buildings do
		if b.vehicles and table.find(b.vehicles, id) then
			return key
		end
	end
	return nil
end

-- Where the boat board (WP-5) stands, in the berth frame (Marina.berth): on the boathouse floor (its lot)
-- by the back wall, facing the roll-up door and the cove. The boathouse keeps a clear
-- BOARD_SIZE x BOARD_SIZE floor area centred here.
DockConfig.BOARD_SLOT = Marina.LOTS.Boathouse.cf * CFrame.new(0, 0, 14)
DockConfig.BOARD_SIZE = 6

-- The build station (WP-14d) stands on the free Spare3 lot by the spawn, clear of the decor spots.
DockConfig.BUILD_STATION =
	{ lot = "Spare3", offset = Vector2.new(-11, 0), size = Vector2.new(16, 12) }

-- The boathouse's paint booth (docs/23 d.3), in the berth frame: the gantry over the berth's inshore half. A craft
-- seated inside this box opens its owner's paint card (DockController). The docked spot (z <= 0) stays out.
DockConfig.PAINT_BOOTH = { cf = CFrame.new(1.5, 6, 15), size = Vector3.new(23, 20, 26) }

-- World spot of a decoration in the berth frame (`frame` = marina berth frame).
function DockConfig.decorSpot(key: string, frame: CFrame): CFrame?
	local d = DockConfig.Decorations[key]
	if not d then
		return nil
	end
	return frame * Marina.LOTS[d.lot].cf * CFrame.new(d.offset.X, 0, d.offset.Y)
end

-- World spot of the build station in the berth frame.
function DockConfig.stationSpot(frame: CFrame): CFrame
	local st = DockConfig.BUILD_STATION
	return frame * Marina.LOTS[st.lot].cf * CFrame.new(st.offset.X, 0, st.offset.Y)
end

-- Can a player buy decoration `key` with Cash? -> ok, reason ("Owned" | "Cash"), price.
function DockConfig.canBuyDecor(
	key: string,
	owned: boolean,
	cash: number
): (boolean, string?, number?)
	local d = DockConfig.Decorations[key]
	if not d or owned then
		return false, "Owned", nil
	end
	if cash < d.cash then
		return false, "Cash", d.cash
	end
	return true, nil, d.cash
end

return DockConfig
