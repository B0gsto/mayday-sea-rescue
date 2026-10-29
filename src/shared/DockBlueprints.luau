--!strict
-- DockBlueprints (docs/23 (j), WP-14d; the unlock tree, docs/23 (q), WP-28): the items on the build tablet. Pure
-- (tests/DockBlueprints.spec.luau). `catalog` = every tree building, quest blueprint and decor, owned ones
-- included, so the tablet can show them as Owned. `needs` = the prerequisite a building still lacks (the card's
-- padlock + "Needs: <item>" chip). `buyable` = the price card can sell it (blueprints come from quests).
local Shared = script.Parent
local DockConfig = require(Shared:WaitForChild("Config"):WaitForChild("DockConfig"))
local UnlockTree = require(Shared:WaitForChild("UnlockTree"))

export type Item =
	{ kind: "Building", key: string }
	| { kind: "Blueprint", key: string }
	| { kind: "Decor", key: string }

local DockBlueprints = {}

-- Every item the tablet lists, in card order: tree buildings, quest blueprints, decor. Ownership is the
-- caller's business (`owned` keys), so the same catalog drives the Build and Decor tabs and the Owned state.
function DockBlueprints.catalog(): { Item }
	local out: { Item } = {}
	for _, key in DockConfig.BUILDINGS do
		table.insert(out, { kind = "Building", key = key })
	end
	for key in DockConfig.Blueprints do
		table.insert(out, { kind = "Blueprint", key = key })
	end
	for _, key in DockConfig.DECOR do
		table.insert(out, { kind = "Decor", key = key })
	end
	return out
end

-- The 1-3 word name on the card: "Pontoon", "Sub pen", "Lighthouse", "Flower bed"; a building at `level`
-- (0 / nil: not built) shows that level's name (the HQ: "Rescue Hut", "Rescue Post", ...).
function DockBlueprints.label(item: Item, level: number?): string
	if item.kind == "Building" then
		return DockConfig.levelName(item.key, level or 0)
	elseif item.kind == "Decor" then
		return DockConfig.Decorations[item.key].name
	end
	return item.key
end

-- Buildings and decor are sold; a blueprint is a quest reward.
function DockBlueprints.buyable(item: Item): boolean
	return item.kind ~= "Blueprint"
end

-- The prerequisite a building still lacks (a DockConfig.Buildings key), or nil. Decor needs only the jetty.
function DockBlueprints.needs(item: Item, owned: { [string]: boolean }): string?
	return if item.kind == "Building" then UnlockTree.missing(item.key, owned) else nil
end

-- The focus strip's one line (DockConfig `desc`).
function DockBlueprints.desc(item: Item): string
	if item.kind == "Building" then
		return DockConfig.Buildings[item.key].desc
	elseif item.kind == "Blueprint" then
		return DockConfig.Blueprints[item.key].desc
	end
	return DockConfig.Decorations[item.key].desc
end

-- A simple Lego line drawing per item, drawn on the card art and on the paper blueprint: boxes in a unit
-- square (x, y from the top left, w, h); `round` = a circle / pill, `hole` = drawn in the paper's colour.
export type Box = { x: number, y: number, w: number, h: number, round: boolean?, hole: boolean? }
local function b(x: number, y: number, w: number, h: number, kind: string?): Box
	return { x = x, y = y, w = w, h = h, round = kind == "round", hole = kind == "hole" }
end

DockBlueprints.GLYPHS = {
	Pontoon = { -- pontoon, lamp, flag
		b(0.05, 0.62, 0.9, 0.12),
		b(0.15, 0.74, 0.08, 0.18),
		b(0.77, 0.74, 0.08, 0.18),
		b(0.25, 0.27, 0.05, 0.35),
		b(0.19, 0.15, 0.17, 0.13, "round"),
		b(0.66, 0.12, 0.05, 0.5),
		b(0.71, 0.12, 0.22, 0.14),
	},
	Boathouse = {
		b(0.15, 0.45, 0.7, 0.45),
		b(0.08, 0.36, 0.84, 0.1),
		b(0.2, 0.26, 0.6, 0.1),
		b(0.33, 0.16, 0.34, 0.1),
		b(0.33, 0.58, 0.34, 0.32, "hole"),
	},
	LookoutTower = {
		b(0.3, 0.5, 0.07, 0.42),
		b(0.63, 0.5, 0.07, 0.42),
		b(0.3, 0.68, 0.4, 0.05),
		b(0.22, 0.28, 0.56, 0.24),
		b(0.32, 0.33, 0.36, 0.1, "hole"),
		b(0.16, 0.18, 0.68, 0.1),
	},
	Station = { -- station with beacon
		b(0.05, 0.45, 0.9, 0.45),
		b(0.38, 0.17, 0.24, 0.28),
		b(0.43, 0.04, 0.14, 0.13, "round"),
		b(0.42, 0.64, 0.16, 0.26, "hole"),
		b(0.13, 0.54, 0.15, 0.12, "hole"),
		b(0.72, 0.54, 0.15, 0.12, "hole"),
	},
	Helipad = { -- an H on a round pad
		b(0.08, 0.08, 0.84, 0.84, "round"),
		b(0.31, 0.27, 0.09, 0.46, "hole"),
		b(0.6, 0.27, 0.09, 0.46, "hole"),
		b(0.31, 0.455, 0.38, 0.09, "hole"),
	},
	Hangar = { -- a round-roofed shed, wide doors
		b(0.08, 0.42, 0.84, 0.48),
		b(0.08, 0.22, 0.84, 0.36, "round"),
		b(0.24, 0.52, 0.52, 0.38, "hole"),
	},
	SubPen = { -- submarine
		b(0.06, 0.45, 0.8, 0.26, "round"),
		b(0.38, 0.3, 0.22, 0.18),
		b(0.51, 0.14, 0.05, 0.16),
		b(0.84, 0.47, 0.1, 0.22),
		b(0.2, 0.53, 0.09, 0.09, "hole"),
	},
	Workshop = { -- a hut and a hammer
		b(0.12, 0.48, 0.62, 0.42),
		b(0.06, 0.38, 0.74, 0.1),
		b(0.36, 0.64, 0.14, 0.26, "hole"),
		b(0.78, 0.18, 0.06, 0.34),
		b(0.7, 0.12, 0.22, 0.09),
	},
	FishShed = { -- a shed and a fish
		b(0.08, 0.5, 0.56, 0.4),
		b(0.04, 0.4, 0.64, 0.1),
		b(0.28, 0.64, 0.16, 0.26, "hole"),
		b(0.58, 0.16, 0.28, 0.15, "round"),
		b(0.84, 0.16, 0.1, 0.15),
	},
	BoatYard = { -- a boat up on stands
		b(0.1, 0.38, 0.8, 0.2, "round"),
		b(0.36, 0.24, 0.26, 0.15),
		b(0.24, 0.58, 0.07, 0.28),
		b(0.69, 0.58, 0.07, 0.28),
		b(0.04, 0.86, 0.92, 0.07),
	},
	LifeboatSlip = { -- a lifeboat on a ramp
		b(0.04, 0.8, 0.92, 0.1),
		b(0.16, 0.68, 0.68, 0.12),
		b(0.18, 0.42, 0.64, 0.22, "round"),
		b(0.38, 0.26, 0.24, 0.17),
	},
	Crane = {
		b(0.2, 0.18, 0.09, 0.7),
		b(0.12, 0.84, 0.25, 0.08),
		b(0.2, 0.12, 0.7, 0.08),
		b(0.81, 0.2, 0.04, 0.32),
		b(0.77, 0.5, 0.12, 0.09),
	},
	RescueBoathouse = { -- a hut with a life ring
		b(0.1, 0.44, 0.8, 0.46),
		b(0.04, 0.34, 0.92, 0.1),
		b(0.36, 0.5, 0.28, 0.28, "round"),
		b(0.45, 0.59, 0.1, 0.1, "hole"),
	},
	Clinic = { -- a block with a cross
		b(0.12, 0.28, 0.76, 0.62),
		b(0.44, 0.38, 0.12, 0.38, "hole"),
		b(0.31, 0.51, 0.38, 0.12, "hole"),
	},
	TrophyHall = { -- a cup
		b(0.29, 0.12, 0.42, 0.4, "round"),
		b(0.15, 0.18, 0.13, 0.2, "round"),
		b(0.72, 0.18, 0.13, 0.2, "round"),
		b(0.45, 0.5, 0.1, 0.18),
		b(0.3, 0.68, 0.4, 0.09),
		b(0.2, 0.8, 0.6, 0.1),
	},
	Depot = { -- a pile of bricks
		b(0.08, 0.72, 0.84, 0.16),
		b(0.14, 0.54, 0.3, 0.16),
		b(0.5, 0.54, 0.36, 0.16),
		b(0.26, 0.36, 0.44, 0.16),
	},
	Bunkhouse = { -- a hut with two bunks
		b(0.1, 0.44, 0.8, 0.46),
		b(0.04, 0.34, 0.92, 0.1),
		b(0.18, 0.62, 0.28, 0.2, "hole"),
		b(0.54, 0.62, 0.28, 0.2, "hole"),
	},
	Lighthouse = {
		b(0.28, 0.82, 0.44, 0.1),
		b(0.36, 0.38, 0.28, 0.44),
		b(0.36, 0.54, 0.28, 0.08, "hole"),
		b(0.38, 0.22, 0.24, 0.16),
		b(0.42, 0.1, 0.16, 0.12),
	},
	FlowerBed = {
		b(0.08, 0.68, 0.84, 0.22),
		b(0.24, 0.45, 0.05, 0.23),
		b(0.475, 0.4, 0.05, 0.28),
		b(0.71, 0.45, 0.05, 0.23),
		b(0.17, 0.28, 0.19, 0.19, "round"),
		b(0.405, 0.22, 0.19, 0.19, "round"),
		b(0.64, 0.28, 0.19, 0.19, "round"),
	},
	PicnicTable = {
		b(0.1, 0.38, 0.8, 0.11),
		b(0.22, 0.49, 0.08, 0.4),
		b(0.7, 0.49, 0.08, 0.4),
		b(0.02, 0.64, 0.96, 0.09),
	},
	LampRow = {
		b(0.05, 0.86, 0.9, 0.06),
		b(0.17, 0.36, 0.05, 0.5),
		b(0.475, 0.36, 0.05, 0.5),
		b(0.78, 0.36, 0.05, 0.5),
		b(0.11, 0.22, 0.17, 0.15, "round"),
		b(0.415, 0.22, 0.17, 0.15, "round"),
		b(0.72, 0.22, 0.17, 0.15, "round"),
	},
	FlagPole = {
		b(0.28, 0.1, 0.05, 0.78),
		b(0.17, 0.86, 0.27, 0.07),
		b(0.33, 0.12, 0.44, 0.25),
		b(0.265, 0.03, 0.08, 0.08, "round"),
	},
	Statue = {
		b(0.25, 0.7, 0.5, 0.2),
		b(0.38, 0.4, 0.24, 0.3),
		b(0.4, 0.2, 0.2, 0.2, "round"),
		b(0.62, 0.18, 0.07, 0.24),
	},
	Fountain = {
		b(0.08, 0.66, 0.84, 0.24),
		b(0.44, 0.38, 0.12, 0.28),
		b(0.26, 0.32, 0.48, 0.08),
		b(0.39, 0.1, 0.22, 0.22, "round"),
	},
} :: { [string]: { Box } }

local G = DockBlueprints.GLYPHS
G.HQ = G.Station -- same station silhouette
G.Harbour = G.Pontoon -- the jetty and pontoon
G.AirStation = G.Hangar -- the hangar (the pad shares its card)
G.SeaPlate1 = { -- docs/27: a deck on three pillars, the jump ramp off its end
	b(0.05, 0.42, 0.62, 0.1),
	b(0.1, 0.52, 0.07, 0.38),
	b(0.33, 0.52, 0.07, 0.38),
	b(0.56, 0.52, 0.07, 0.38),
	b(0.72, 0.56, 0.24, 0.08),
	b(0.84, 0.46, 0.12, 0.1),
}
G.SeaPlate2 = { -- docs/27: a deck on three pillars, the barge alongside
	b(0.05, 0.42, 0.62, 0.1),
	b(0.1, 0.52, 0.07, 0.38),
	b(0.33, 0.52, 0.07, 0.38),
	b(0.56, 0.52, 0.07, 0.38),
	b(0.7, 0.6, 0.26, 0.14),
	b(0.74, 0.5, 0.08, 0.1),
	b(0.84, 0.5, 0.08, 0.1),
}

function DockBlueprints.glyph(item: Item): { Box }
	return DockBlueprints.GLYPHS[item.key] or DockBlueprints.GLYPHS.Boathouse
end

return DockBlueprints
