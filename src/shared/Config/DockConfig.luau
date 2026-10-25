--!strict
-- DockConfig (docs/23 d.2, WP-4): dock levels 2..5, and the WP-10b buildings (hangar, sub pen). Each has two prices: Cash + rank, or Robux (the
-- MonetizationConfig product `product`, which skips both). Pure (tests/DockConfig.spec.luau).
-- Piece geometry lives in shared/DockPieces; DockService builds it, the blueprint table prices it.
local Marina = require(script.Parent.Parent:WaitForChild("Marina"))
local ProgressionConfig = require(script.Parent.ProgressionConfig)

export type Level = {
	cash: number,
	rank: string, -- ProgressionConfig.Ranks id
	robux: number, -- launch price, docs/23 (i): at least the Cash packs' price for the Cash, plus a rank-skip premium
	product: string, -- MonetizationConfig.Products key
	desc: string, -- the build tablet's focus line, <= 10 words
	adds: { string },
	unlocks: { string },
}

local DockConfig = {}

DockConfig.MAX = 5

DockConfig.Levels = {
	[2] = {
		desc = "Moors a second boat beside your jetty.",
		cash = 2500,
		rank = "Lifeguard",
		robux = 49,
		product = "DockLevel2",
		adds = { "Pontoon", "LampPosts", "Flag", "RescueBoard" },
		unlocks = { "SecondBerth" },
	},
	[3] = {
		desc = "A boathouse to pick and paint your boats.",
		cash = 10000,
		rank = "RescueSwimmer",
		robux = 99,
		product = "DockLevel3",
		adds = { "Boathouse", "BoatBoard", "PaintBooth" },
		unlocks = { "ChooseAtDock" },
	},
	[4] = {
		desc = "A lookout tower and crane; relaunch with no wait.",
		cash = 30000,
		rank = "Coxswain",
		robux = 199,
		product = "DockLevel4",
		adds = { "LookoutTower", "SlipwayCrane" },
		unlocks = { "NoRelaunchCooldown", "LifeboatBerth" },
	},
	[5] = {
		desc = "A lit station front and a beacon for the harbour.",
		cash = 100000,
		rank = "RescuePilot",
		robux = 399,
		product = "DockLevel5",
		adds = { "StationFront", "Beacon", "TrophyHall" },
		unlocks = { "TrophyHall", "HarbourMaster" },
	},
} :: { [number]: Level }

-- docs/23 h (WP-10b): buildings bought apart from the level, same two prices. `needs` = the lowest dock level
-- that may buy it (each stands on its own island lot, WP-19b). `vehicles` = its board's craft, in order.
export type Building = Level & { needs: number, vehicles: { string }, lot: string }

DockConfig.BUILDINGS = { "Hangar", "SubPen" } -- the car Garage was cut 2026-10-25 (pre-hub-cut)

DockConfig.Buildings = {
	Hangar = {
		desc = "A helipad and hangar for your rescue helicopter.",
		cash = 25000,
		rank = "RescuePilot",
		robux = 199,
		product = "DockHangar",
		adds = { "Helipad", "Hangar", "HangarBoard" },
		unlocks = { "AircraftAtDock" },
		needs = 3,
		vehicles = { "RescueHelicopter" },
		lot = "Hangar",
	},
	SubPen = {
		desc = "A sub pen to launch your submarine.",
		cash = 20000,
		rank = "Coxswain",
		robux = 149,
		product = "DockSubPen",
		adds = { "SubPen", "SubBoard" },
		unlocks = { "SubAtDock" },
		needs = 1,
		vehicles = { "Submarine" },
		lot = "SubPen",
	},
} :: { [string]: Building }

-- Blueprints (docs/23 (j) "Exploration feeds the plot", WP-21b): cosmetic buildings a quest chain unlocks (never
-- sold). Owned ones are data.dockBuildings[key]; DockService raises them on their island lot (Marina.LOTS[lot]).
DockConfig.Blueprints = {
	Lighthouse = { lot = "Spare1", desc = "Keeper Ives' lamp, earned on his quest." }, -- Quests/Data Lamp3
} :: { [string]: { lot: string, desc: string } }

-- Decorations (WP-14d): Cash-only Lego set pieces on the free lots by the spawn. Bought from the build
-- tablet's Decor tab and kept in data.dockBuildings like buildings, so the save migration accepts them.
export type Decor = {
	name: string,
	cash: number,
	desc: string, -- the build tablet's focus line, <= 10 words
	color: string, -- Theme.Grad accent for the build card
	lot: string, -- Marina.LOTS key
	offset: Vector2, -- studs from the lot centre, x / z
	size: Vector2, -- footprint in studs (x / z)
}

DockConfig.DECOR = { "FlowerBed", "PicnicTable", "LampRow", "FlagPole", "Statue", "Fountain" }

DockConfig.Decorations = {
	FlowerBed = {
		name = "Flower bed",
		cash = 2000,
		desc = "Bright Lego flowers by your spawn.",
		color = "pink",
		lot = "Spare2",
		offset = Vector2.new(-10, 0),
		size = Vector2.new(8, 8),
	},
	PicnicTable = {
		name = "Picnic table",
		cash = 5000,
		desc = "A picnic table for crew breaks.",
		color = "green",
		lot = "Spare2",
		offset = Vector2.new(0, 0),
		size = Vector2.new(8, 8),
	},
	LampRow = {
		name = "Lamp row",
		cash = 9000,
		desc = "A row of lamps that glow at night.",
		color = "yellow",
		lot = "Spare2",
		offset = Vector2.new(10, 0),
		size = Vector2.new(9, 6),
	},
	FlagPole = {
		name = "Flag pole",
		cash = 15000,
		desc = "A tall flag pole flying your colours.",
		color = "blue",
		lot = "Spare3",
		offset = Vector2.new(9, -8),
		size = Vector2.new(7, 7),
	},
	Statue = {
		name = "Statue",
		cash = 25000,
		desc = "A hero statue for your island.",
		color = "orange",
		lot = "Spare3",
		offset = Vector2.new(9, 0),
		size = Vector2.new(7, 7),
	},
	Fountain = {
		name = "Fountain",
		cash = 40000,
		desc = "A splashing fountain in the square.",
		color = "teal",
		lot = "Spare3",
		offset = Vector2.new(9, 8),
		size = Vector2.new(7, 7),
	},
} :: { [string]: Decor }

-- Can a player buy building `key` with Cash? -> ok, reason ("Owned" | "Level" | "Rank" | "Cash"), price.
function DockConfig.canBuyBuilding(
	key: string,
	owned: boolean,
	level: number,
	cash: number,
	rankIndex: number
): (boolean, string?, number?)
	local b = DockConfig.Buildings[key]
	if not b or owned then
		return false, "Owned", nil
	end
	if level < b.needs then
		return false, "Level", b.cash
	end
	if rankIndex < DockConfig.rankIndex(b.rank) then
		return false, "Rank", b.cash
	end
	if cash < b.cash then
		return false, "Cash", b.cash
	end
	return true, nil, b.cash
end

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
		if table.find(b.vehicles, id) then
			return key
		end
	end
	return nil
end

-- Where the boat board (WP-5) stands, in the berth frame (Marina.berth): on the boathouse floor (its lot)
-- by the back wall, facing the roll-up door and the cove. The Lv 3 boathouse keeps a clear
-- BOARD_SIZE x BOARD_SIZE floor area centred here.
DockConfig.BOARD_SLOT = Marina.LOTS.Boathouse.cf * CFrame.new(0, 0, 14)
DockConfig.BOARD_SIZE = 6

-- The build station (WP-14d) stands on the free Spare3 lot by the spawn, clear of the decor spots.
DockConfig.BUILD_STATION =
	{ lot = "Spare3", offset = Vector2.new(-11, 0), size = Vector2.new(16, 12) }

-- The Lv 3 paint booth (docs/23 d.3), in the berth frame: the gantry over the berth's inshore half. A craft
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

function DockConfig.rankIndex(rankId: string): number
	for i, r in ProgressionConfig.Ranks do
		if r.id == rankId then
			return i
		end
	end
	error(`DockConfig: unknown rank {rankId}`)
end

-- Can a player at dock level `current` buy `target` with Cash? -> ok, reason ("Level" | "Rank" |
-- "Cash"), price. Only the next level is for sale.
function DockConfig.canBuy(
	current: number,
	target: number,
	cash: number,
	rankIndex: number
): (boolean, string?, number?)
	local lv = DockConfig.Levels[target]
	if not lv or target ~= current + 1 then
		return false, "Level", nil
	end
	if rankIndex < DockConfig.rankIndex(lv.rank) then
		return false, "Rank", lv.cash
	end
	if cash < lv.cash then
		return false, "Cash", lv.cash
	end
	return true, nil, lv.cash
end

-- The level a MonetizationConfig product key builds, or nil.
function DockConfig.levelFor(productKey: string): number?
	for n, lv in DockConfig.Levels do
		if lv.product == productKey then
			return n
		end
	end
	return nil
end

return DockConfig
