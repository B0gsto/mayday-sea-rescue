--!strict
-- DockConfig (docs/23 d.2, WP-4): dock levels 2..5. Each has two prices: Cash + rank, or Robux (the
-- MonetizationConfig product `product`, which skips both). Pure (tests/DockConfig.spec.luau).
-- Piece geometry lives in shared/DockPieces; DockService builds it, DockController draws the ghost.
local ProgressionConfig = require(script.Parent.ProgressionConfig)

export type Level = {
	cash: number,
	rank: string, -- ProgressionConfig.Ranks id
	robux: number, -- launch price (tune); the product's `price`
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
		adds = { "Boathouse", "BoatBoard" },
		unlocks = { "ChooseAtDock" },
	},
	[4] = {
		cash = 30000,
		rank = "Coxswain",
		robux = 149,
		product = "DockLevel4",
		adds = { "LookoutTower", "SlipwayCrane" },
		unlocks = { "NoRelaunchCooldown", "LifeboatBerth" },
	},
	[5] = {
		cash = 100000,
		rank = "RescuePilot",
		robux = 249,
		product = "DockLevel5",
		adds = { "StationFront", "Beacon" },
		unlocks = { "TrophyHall", "HarbourMaster" },
	},
} :: { [number]: Level }

-- Where the boat board (WP-5) stands, in the berth frame (Marina.berth): on the boathouse floor (deck
-- top) against the back wall, facing the roll-up door and the sea. The Lv 3 boathouse keeps a clear
-- BOARD_SIZE x BOARD_SIZE floor area centred here.
DockConfig.BOARD_SLOT = CFrame.new(-11, 3, 48.5)
DockConfig.BOARD_SIZE = 6

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
