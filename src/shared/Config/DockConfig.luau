--!strict
-- DockConfig (docs/23 d.2, WP-4): dock levels 2..5, and the WP-10b buildings (hangar, sub pen). Each has two prices: Cash + rank, or Robux (the
-- MonetizationConfig product `product`, which skips both). Pure (tests/DockConfig.spec.luau).
-- Piece geometry lives in shared/DockPieces; DockService builds it, DockController draws the ghost.
local ProgressionConfig = require(script.Parent.ProgressionConfig)

export type Level = {
	cash: number,
	rank: string, -- ProgressionConfig.Ranks id
	robux: number, -- launch price, docs/23 (i): at least the Cash packs' price for the Cash, plus a rank-skip premium
	product: string, -- MonetizationConfig.Products key
	adds: { string },
	unlocks: { string },
}

local DockConfig = {}

DockConfig.MAX = 5

DockConfig.Levels = {
	[2] = {
		cash = 2500,
		rank = "Lifeguard",
		robux = 49,
		product = "DockLevel2",
		adds = { "Pontoon", "LampPosts", "Flag", "RescueBoard" },
		unlocks = { "SecondBerth" },
	},
	[3] = {
		cash = 10000,
		rank = "RescueSwimmer",
		robux = 99,
		product = "DockLevel3",
		adds = { "Boathouse", "BoatBoard", "PaintBooth" },
		unlocks = { "ChooseAtDock" },
	},
	[4] = {
		cash = 30000,
		rank = "Coxswain",
		robux = 199,
		product = "DockLevel4",
		adds = { "LookoutTower", "SlipwayCrane" },
		unlocks = { "NoRelaunchCooldown", "LifeboatBerth" },
	},
	[5] = {
		cash = 100000,
		rank = "RescuePilot",
		robux = 399,
		product = "DockLevel5",
		adds = { "StationFront", "Beacon", "TrophyHall" },
		unlocks = { "TrophyHall", "HarbourMaster" },
	},
} :: { [number]: Level }

-- docs/23 h (WP-10b): buildings bought apart from the level, same two prices. `needs` = the lowest dock level
-- it stands on (the helipad sits on the Lv 3 boathouse roof). `vehicles` = its board's craft, in order.
export type Building = Level & { needs: number, vehicles: { string } }

DockConfig.BUILDINGS = { "Hangar", "SubPen" } -- the car Garage was cut 2026-10-25 (pre-hub-cut)

DockConfig.Buildings = {
	Hangar = {
		cash = 25000,
		rank = "RescuePilot",
		robux = 199,
		product = "DockHangar",
		adds = { "Helipad", "Hangar", "HangarBoard" },
		unlocks = { "AircraftAtDock" },
		needs = 3,
		vehicles = { "RescueHelicopter", "Seaplane" },
	},
	SubPen = {
		cash = 20000,
		rank = "Coxswain",
		robux = 149,
		product = "DockSubPen",
		adds = { "SubPen", "SubBoard" },
		unlocks = { "SubAtDock" },
		needs = 1,
		vehicles = { "Submarine" },
	},
} :: { [string]: Building }

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

-- Where the boat board (WP-5) stands, in the berth frame (Marina.berth): on the boathouse floor (deck
-- top) against the back wall, facing the roll-up door and the sea. The Lv 3 boathouse keeps a clear
-- BOARD_SIZE x BOARD_SIZE floor area centred here.
DockConfig.BOARD_SLOT = CFrame.new(-11, 3, 48.5)
DockConfig.BOARD_SIZE = 6

-- The Lv 3 paint booth (docs/23 d.3), in the berth frame: the gantry over the berth's inshore half. A craft
-- seated inside this box opens its owner's paint card (DockController). The docked spot (z <= 0) stays out.
DockConfig.PAINT_BOOTH = { cf = CFrame.new(-1.5, 6, 15), size = Vector3.new(23, 20, 26) }

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
