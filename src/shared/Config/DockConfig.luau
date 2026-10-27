--!strict
-- DockConfig (docs/23 (q), WP-28; docs/25 K2 buildings v2): every buildable on your island is one row of
-- `Buildings`. A row has a `levels` array (index = level): the Cash price, the HQ level it needs, its Robux
-- product (skips the Cash, never the order) and the visible add-on it brings. `unlockAt` is the HQ that first
-- offers the row (the HQ gate), `needs` are extra building keys (row-level, normally {}), `spot` / `size` place
-- it on the plate in the berth frame. Old one-time rows merged into levels: Pontoon/Crane -> Harbour,
-- LifeboatSlip -> Boathouse Lv2, Helipad/Hangar -> Air Station, Station -> HQ Lv3. Adding content = adding a
-- row (and its key to BUILDINGS). Rules: shared/UnlockTree (tests/UnlockTree.spec.luau); pieces:
-- shared/DockPieces; server: DockService.
--   HQ Lv1 (free) gates every district; each HQ level raises every building's max level.
--   HQ1 Harbour, Depot, Workshop, Bunkhouse, Fish Market
--   HQ2 Boathouse -> RIB, Boat Yard, Clinic; Boathouse Lv2 -> Lifeboat
--   HQ3 Rescue Boathouse, Lookout Tower; Harbour Lv3 -> crane  HQ4 Air Station -> helicopter
--   HQ5 Sub Pen -> submarine, Trophy Hall
--   Decor: the jetty only.
local Marina = require(script.Parent.Parent:WaitForChild("Marina"))

export type Level = {
	cash: number,
	hq: number, -- the HQ level needed for this level
	robux: number?, -- its launch price (docs/23 (i): never a cheaper way to Cash than the packs)
	product: string?, -- MonetizationConfig.Products key (skips the Cash, never the order)
	effect: string?, -- the server flag this level switches on (DockService / BoatBoard / WorkerService)
	piece: string?, -- the visible add-on (DockPieces)
	name: string?, -- this level's own name (the HQ: Rescue Hut .. Coastguard HQ); nil = the row's name
	needs: { string }?, -- extra building keys for this level (usually nil)
}

export type Building = {
	name: string, -- the card's 1-3 words
	desc: string, -- the build tablet's focus line, <= 10 words
	levels: { Level },
	unlockAt: number, -- the first HQ level that offers this row
	cash: number, -- level 1's Cash (kept for the current build tablet; levels are the source of truth)
	needs: { string }, -- DockConfig.Buildings keys that must be owned first (row-level; normally {})
	product: string?, -- level 1's MonetizationConfig.Products key
	robux: number?, -- level 1's launch price
	spot: CFrame, -- berth frame, on the ground: the lot marker and the build camera's focus
	size: Vector2, -- footprint (x / z of `spot`)
	vehicles: { string }?, -- its own vehicle board's craft, in order (BoatBoard)
	worker: string?, -- a worker building (WP-26): a Lego cottage (DockPieces), its workers in front of the door (-Z)
	color: Color3?, -- the cottage's wall colour
	scale: number?, -- WP-25 r8/r9: built at size / scale, then scaled up round its spot (size = the scaled footprint)
}

local DockConfig = {}

-- a spot on the island, `right` / `fwd` studs from its centre (RingLayout's island frame), turned `yaw` degrees
local function isle(right: number, fwd: number, yaw: number?): CFrame
	return Marina.ISLAND * CFrame.new(right, 0, -fwd) * CFrame.Angles(0, math.rad(yaw or 0), 0)
end

-- card order (the map's districts, HQ spine first)
DockConfig.BUILDINGS = {
	"HQ",
	"Harbour",
	"Depot",
	"Workshop",
	"Bunkhouse",
	"FishShed",
	"Boathouse",
	"BoatYard",
	"Clinic",
	"RescueBoathouse",
	"LookoutTower",
	"AirStation",
	"SubPen",
	"TrophyHall",
}

-- The Bunkhouse's people cap by level (docs/25 B); WorkerRules.W.CAP stays untouched, WorkerService reads this.
DockConfig.BunkhouseCaps = { 10, 20, 30, 45, 60 }
DockConfig.HutCap = 5 -- people the Rescue Hut sleeps before a Bunkhouse stands (the tutorial's first Builder)

local rows: { [string]: any } = {
	HQ = {
		name = "Rescue Station",
		desc = "The island's heart: every district grows from it.",
		unlockAt = 1,
		needs = {},
		spot = isle(0, -12, 0), -- the plaza at the head of the cove, facing the jetty
		size = Vector2.new(54, 32),
		levels = {
			{ cash = 0, hq = 0, effect = "HQ", piece = "Hut", name = "Rescue Hut" }, -- the free first build (tutorial)
			{ cash = 3000, hq = 1, effect = "HQ", piece = "Post", name = "Rescue Post" },
			{
				cash = 12000,
				hq = 2,
				product = "DockLevel5",
				robux = 199,
				effect = "HQ",
				piece = "Station",
				name = "Lifeboat Station",
			},
			{ cash = 80000, hq = 3, effect = "HQ", piece = "Base", name = "Coastguard Base" },
			{ cash = 160000, hq = 4, effect = "HQ", piece = "HQ", name = "Coastguard HQ" },
		} :: { Level },
	},
	Harbour = {
		name = "Harbour",
		desc = "Jetty, pontoon and crane on the cove.",
		unlockAt = 1,
		needs = {},
		spot = isle(-28, 100, 0), -- the pontoon on the west side of the cove (on the water)
		size = Vector2.new(8, 80),
		levels = {
			{ cash = 0, hq = 0, effect = "Jetty", piece = "Jetty" }, -- the start: the jetty is already there
			{
				cash = 2500,
				hq = 2,
				product = "DockLevel2",
				robux = 35,
				effect = "Pontoon",
				piece = "Pontoon",
			},
			{
				cash = 25000,
				hq = 3,
				product = "DockCrane",
				robux = 99,
				effect = "Crane",
				piece = "Crane",
			},
		} :: { Level },
	},
	Depot = {
		name = "Depot",
		desc = "Brick pile and freight quay: builds start here.",
		unlockAt = 1,
		needs = {},
		spot = isle(-90, -2, -90), -- work yard, open front onto the plaza
		size = Vector2.new(36, 30),
		scale = 1.15,
		worker = "Hauler",
		color = Color3.fromRGB(250, 208, 40),
		levels = {
			{ cash = 700, hq = 1, effect = "Depot", piece = "Yard" },
			{ cash = 2000, hq = 2, effect = "Depot", piece = "Pile" },
			{ cash = 14000, hq = 3, effect = "Depot", piece = "Conveyor" },
		} :: { Level },
	},
	Workshop = {
		name = "Workshop",
		desc = "Builders work here.",
		unlockAt = 1,
		needs = {},
		spot = isle(-135, -35, -90), -- the work yard's open front onto the plaza lane
		size = Vector2.new(36, 26),
		scale = 1.2,
		worker = "Builder",
		color = Color3.fromRGB(250, 208, 40),
		levels = {
			{
				cash = 500,
				hq = 1,
				product = "DockWorkshop",
				robux = 15,
				effect = "Builders",
				piece = "Yard",
			},
			{ cash = 1500, hq = 2, effect = "BuilderSlots5", piece = "SawBench" },
			{ cash = 11000, hq = 3, effect = "BuilderSlots8", piece = "BoatFrame" },
		} :: { Level },
	},
	Bunkhouse = {
		name = "Bunkhouse",
		desc = "Homes for the people you rescue.",
		unlockAt = 1,
		needs = {},
		spot = isle(130, -18, 90), -- village, open front onto the plaza
		size = Vector2.new(40, 46),
		scale = 1.2,
		color = Color3.fromRGB(80, 190, 90),
		levels = {
			{ cash = 800, hq = 1, effect = "People10", piece = "Hut" },
			{ cash = 3000, hq = 2, effect = "People20", piece = "Floor" },
			{ cash = 10000, hq = 3, effect = "People30", piece = "Floor" },
			{ cash = 25000, hq = 4, effect = "People45", piece = "Hammocks" },
			{ cash = 50000, hq = 5, effect = "People60", piece = "Lights" },
		} :: { Level },
	},
	FishShed = {
		name = "Fish Market",
		desc = "Fishers work the stalls and the pier.",
		unlockAt = 1,
		needs = {},
		spot = isle(133, 68, 90), -- harbour east, open front onto the cove walk
		size = Vector2.new(40, 34),
		scale = 1.15,
		worker = "Gatherer",
		color = Color3.fromRGB(40, 96, 208),
		levels = {
			{
				cash = 600,
				hq = 1,
				product = "DockFishShed",
				robux = 35,
				effect = "Fishers",
				piece = "Stalls",
			},
			{ cash = 1750, hq = 2, effect = "FishSlots4", piece = "Stalls" },
			{ cash = 11000, hq = 3, effect = "FishSlots8", piece = "Smokehouse" },
		} :: { Level },
	},
	Boathouse = {
		name = "Boathouse",
		desc = "Pick and paint boats. Unlocks the RIB.",
		unlockAt = 2,
		needs = {},
		spot = isle(-80, 58, -90), -- harbour west, the doors open onto the cove
		size = Vector2.new(44, 36),
		scale = 1.2,
		levels = {
			{
				cash = 900,
				hq = 2,
				product = "DockLevel3",
				robux = 35,
				effect = "RIB",
				piece = "Boathouse",
			},
			{
				cash = 2250,
				hq = 2,
				product = "DockLifeboatSlip",
				robux = 99,
				effect = "LifeboatSlip",
				piece = "Slip",
			},
			{ cash = 14000, hq = 3, effect = "QuickLaunch", piece = "QuickBay" },
		} :: { Level },
	},
	BoatYard = {
		name = "Boat Yard",
		desc = "Mechanics work here.",
		unlockAt = 2,
		needs = {},
		spot = isle(-132, 72, -90), -- harbour west, open front onto the cove walk
		size = Vector2.new(36, 40),
		scale = 1.15,
		worker = "Mechanic",
		color = Color3.fromRGB(250, 140, 30),
		levels = {
			{
				cash = 1000,
				hq = 2,
				product = "DockBoatYard",
				robux = 75,
				effect = "Mechanics",
				piece = "Cradle",
			},
			{ cash = 3000, hq = 2, effect = "Gantry", piece = "Gantry" },
			{ cash = 16000, hq = 3, effect = "DryDock", piece = "DryDock" },
		} :: { Level },
	},
	Clinic = {
		name = "Clinic",
		desc = "Medics meet every arrival.",
		unlockAt = 2,
		needs = {},
		spot = isle(75, -20, 90), -- village, open front onto the plaza; back from the east promenade (fwd 18-26): the Lv3 hospital wing reaches 37 studs fwd of the lot centre
		size = Vector2.new(36, 28),
		scale = 1.15,
		worker = "Medic",
		color = Color3.fromRGB(242, 240, 232),
		levels = {
			{
				cash = 1200,
				hq = 2,
				product = "DockClinic",
				robux = 199,
				effect = "Medics",
				piece = "Tent",
			},
			{ cash = 3500, hq = 2, effect = "Pavilion", piece = "Pavilion" },
			{ cash = 18000, hq = 3, effect = "Hospital", piece = "Hospital" },
		} :: { Level },
	},
	RescueBoathouse = {
		name = "Rescue Boathouse",
		desc = "Rescuers run their own boats from here.",
		unlockAt = 3,
		needs = {},
		spot = isle(80, 58, 90), -- harbour east, the doors open onto the cove
		size = Vector2.new(44, 36),
		scale = 1.15,
		worker = "Rescuer",
		color = Color3.fromRGB(224, 56, 40),
		levels = {
			{
				cash = 1500,
				hq = 3,
				product = "DockRescueBoathouse",
				robux = 99,
				effect = "Rescuers",
				piece = "Dinghy",
			},
			{ cash = 10000, hq = 3, effect = "RescueRIB", piece = "RIB" },
			{ cash = 30000, hq = 3, effect = "RescueLifeboat", piece = "Lifeboat" },
		} :: { Level },
	},
	LookoutTower = {
		name = "Lookout Tower",
		desc = "Spot calls from farther out.",
		unlockAt = 3,
		needs = {},
		spot = isle(72, -95, 0), -- air field, at the back of the plaza; 10 east of the Air Station patrol hut (Lv3)
		size = Vector2.new(16, 16),
		scale = 1.5,
		levels = {
			{
				cash = 1600,
				hq = 3,
				product = "DockLevel4",
				robux = 75,
				effect = "CallsFar",
				piece = "Tower",
			},
			{ cash = 10000, hq = 3, effect = "GoldCalls15", piece = "Lamp" },
			{ cash = 30000, hq = 3, effect = "GoldCalls2", piece = "Spotlight" },
		} :: { Level },
	},
	AirStation = {
		name = "Air Station",
		desc = "Helipad and hangar for the helicopter.",
		unlockAt = 4,
		needs = {},
		spot = isle(88, -124, 0), -- the hangar; the pad sits 38 right, 27 fwd (DockPieces)
		size = Vector2.new(42, 28),
		vehicles = { "RescueHelicopter" },
		levels = {
			{
				cash = 1800,
				hq = 4,
				product = "DockHangar",
				robux = 149,
				effect = "Helicopter",
				piece = "HelipadHangar",
			},
			{ cash = 12000, hq = 4, effect = "Refuel", piece = "RefuelPad" },
			{ cash = 36000, hq = 4, effect = "Patrol", piece = "PatrolHut" },
		} :: { Level },
	},
	SubPen = {
		name = "Sub Pen",
		desc = "A domed pen for the submarine.",
		unlockAt = 5,
		needs = {},
		spot = isle(90, 128, 0), -- harbour east, down the quay
		size = Vector2.new(40, 40),
		vehicles = { "Submarine" },
		levels = {
			{
				cash = 1900,
				hq = 5,
				product = "DockSubPen",
				robux = 149,
				effect = "Submarine",
				piece = "Dome",
			},
			{ cash = 13000, hq = 5, effect = "DeepDives", piece = "Gantry" },
			{ cash = 38000, hq = 5, effect = "Salvage", piece = "Salvage" },
		} :: { Level },
	},
	TrophyHall = {
		name = "Trophy Hall",
		desc = "Cups, stamps and quest trophies on display.",
		unlockAt = 5,
		needs = {},
		spot = isle(0, -122, 0), -- landmarks, behind the plaza
		size = Vector2.new(50, 28),
		levels = {
			{
				cash = 2000,
				hq = 5,
				product = "DockTrophyHall",
				robux = 149,
				effect = "Trophies",
				piece = "Hall",
			},
			{ cash = 14000, hq = 5, effect = "TrophyPlinths", piece = "Dome" },
			{ cash = 40000, hq = 5, effect = "TrophyWheel", piece = "GoldDome" },
		} :: { Level },
	},
}

-- Fill level 1 back onto the row (the current build tablet still reads these) and the row's needs default.
for _, b in rows do
	b.cash = b.levels[1].cash
	b.product = b.levels[1].product
	b.robux = b.levels[1].robux
	b.needs = b.needs or {}
end
DockConfig.Buildings = rows :: { [string]: Building }

-- The lifeboat slip add-on (Boathouse Lv2) on its own map lot, facing the sea.
DockConfig.BOATHOUSE_SLIP = isle(-80, 112, 0)

-- Old saves (the dock-level ladder before WP-28): what each old level owns in the tree (UnlockTree.migrateLegacy).
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

-- A building's name at level `n` (0 = not built yet: its Lv1 name): the HQ's Rescue Hut .. Coastguard HQ.
function DockConfig.levelName(key: string, n: number): string
	local b = DockConfig.Buildings[key]
	local l = b.levels[math.clamp(n, 1, #b.levels)]
	return l.name or b.name
end

-- The building (and level) a MonetizationConfig product key builds: -> key, level.
function DockConfig.buildingFor(productKey: string): (string?, number?)
	for key, b in DockConfig.Buildings do
		for n, l in b.levels do
			if l.product == productKey then
				return key, n
			end
		end
	end
	return nil, nil
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
DockConfig.BOARD_SLOT = isle(-80, 58, -90) * CFrame.new(0, 0, 14)
DockConfig.BOARD_SIZE = 6

-- The build station (WP-14d, docs/25 J) stands at the jetty head: on the head deck west of the jetty's quay end
-- (DockService builds it, JETTY_HEAD), its tablet facing the plate, clear of the jetty walk and the moored craft.
-- Offsets are in the Jetty lot (x = right, y = toward the quay).
DockConfig.BUILD_STATION =
	{ lot = "Jetty", offset = Vector2.new(-15, 25), size = Vector2.new(16, 12) }
DockConfig.JETTY_HEAD = { offset = Vector2.new(-15, 28), size = Vector2.new(20, 20) } -- the deck under it

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
