--!strict
-- DockBlueprints (docs/23 (j), WP-14d): the items on the build tablet. Pure (tests/DockBlueprints.spec.luau).
-- `available` = what the plot can buy now (the next dock level when there is one, every DockConfig building
-- the plot's level qualifies for and does not own, and every quest blueprint not earned yet). `catalog` = every
-- level, building, blueprint and decor, owned ones included, so the tablet can show them as Owned. `locked` =
-- not for sale yet: the rank is too low, or the quest blueprint still has to be earned (padlock on the card).
-- `buyable` = the price card can sell it (blueprints come from quests, not Cash or Robux).
local DockConfig = require(script.Parent:WaitForChild("Config"):WaitForChild("DockConfig"))

export type Item =
	{ kind: "Level", key: number }
	| { kind: "Building", key: string }
	| { kind: "Blueprint", key: string }
	| { kind: "Decor", key: string }

local DockBlueprints = {}

DockBlueprints.WORDS = { Hangar = "Helipad", SubPen = "Sub pen" } :: { [string]: string }

-- Every item the tablet lists, in card order: levels 2..MAX, buildings, blueprints, decor. Ownership is the
-- caller's business (`owned` keys), so the same catalog drives Build and Decor tabs and the Owned state.
function DockBlueprints.catalog(): { Item }
	local out: { Item } = {}
	for n = 2, DockConfig.MAX do
		table.insert(out, { kind = "Level", key = n })
	end
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

function DockBlueprints.available(level: number, owned: { [string]: boolean }): { Item }
	local out: { Item } = {}
	if level < DockConfig.MAX then
		table.insert(out, { kind = "Level", key = level + 1 })
	end
	for _, key in DockConfig.BUILDINGS do
		local b = DockConfig.Buildings[key]
		if b and level >= b.needs and owned[key] ~= true then
			table.insert(out, { kind = "Building", key = key })
		end
	end
	for key in DockConfig.Blueprints do
		if owned[key] ~= true then
			table.insert(out, { kind = "Blueprint", key = key })
		end
	end
	return out
end

-- The 1-3 word name on the card: "Level 3", "Helipad", "Sub pen", "Lighthouse", "Flower bed".
function DockBlueprints.label(item: Item): string
	if item.kind == "Level" then
		return `Level {item.key}`
	elseif item.kind == "Decor" then
		return DockConfig.Decorations[item.key].name
	end
	return DockBlueprints.WORDS[item.key] or item.key
end

-- Only levels, DockConfig buildings and decor are sold; a blueprint is a quest reward.
function DockBlueprints.buyable(item: Item): boolean
	return item.kind ~= "Blueprint"
end

-- WP-14e: the lots that get a paper blueprint in build mode: everything for sale now and not owned (the next
-- level, qualifying buildings, every decor not owned). Rank-locked ones count: Robux skips the rank.
function DockBlueprints.onIsland(level: number, owned: { [string]: boolean }): { Item }
	local out: { Item } = {}
	for _, item in DockBlueprints.available(level, owned) do
		if DockBlueprints.buyable(item) then
			table.insert(out, item)
		end
	end
	for _, key in DockConfig.DECOR do
		if owned[key] ~= true then
			table.insert(out, { kind = "Decor", key = key })
		end
	end
	return out
end

-- The focus strip's one line (DockConfig `desc`).
function DockBlueprints.desc(item: Item): string
	if item.kind == "Level" then
		return DockConfig.Levels[item.key].desc
	elseif item.kind == "Building" then
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
	Level2 = { -- pontoon, lamp, flag
		b(0.05, 0.62, 0.9, 0.12),
		b(0.15, 0.74, 0.08, 0.18),
		b(0.77, 0.74, 0.08, 0.18),
		b(0.25, 0.27, 0.05, 0.35),
		b(0.19, 0.15, 0.17, 0.13, "round"),
		b(0.66, 0.12, 0.05, 0.5),
		b(0.71, 0.12, 0.22, 0.14),
	},
	Level3 = { -- boathouse
		b(0.15, 0.45, 0.7, 0.45),
		b(0.08, 0.36, 0.84, 0.1),
		b(0.2, 0.26, 0.6, 0.1),
		b(0.33, 0.16, 0.34, 0.1),
		b(0.33, 0.58, 0.34, 0.32, "hole"),
	},
	Level4 = { -- lookout tower
		b(0.3, 0.5, 0.07, 0.42),
		b(0.63, 0.5, 0.07, 0.42),
		b(0.3, 0.68, 0.4, 0.05),
		b(0.22, 0.28, 0.56, 0.24),
		b(0.32, 0.33, 0.36, 0.1, "hole"),
		b(0.16, 0.18, 0.68, 0.1),
	},
	Level5 = { -- station with beacon
		b(0.05, 0.45, 0.9, 0.45),
		b(0.38, 0.17, 0.24, 0.28),
		b(0.43, 0.04, 0.14, 0.13, "round"),
		b(0.42, 0.64, 0.16, 0.26, "hole"),
		b(0.13, 0.54, 0.15, 0.12, "hole"),
		b(0.72, 0.54, 0.15, 0.12, "hole"),
	},
	Hangar = { -- helipad H
		b(0.08, 0.08, 0.84, 0.84, "round"),
		b(0.31, 0.27, 0.09, 0.46, "hole"),
		b(0.6, 0.27, 0.09, 0.46, "hole"),
		b(0.31, 0.455, 0.38, 0.09, "hole"),
	},
	SubPen = { -- submarine
		b(0.06, 0.45, 0.8, 0.26, "round"),
		b(0.38, 0.3, 0.22, 0.18),
		b(0.51, 0.14, 0.05, 0.16),
		b(0.84, 0.47, 0.1, 0.22),
		b(0.2, 0.53, 0.09, 0.09, "hole"),
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

function DockBlueprints.glyph(item: Item): { Box }
	local key = if item.kind == "Level" then `Level{item.key}` else item.key :: string
	return DockBlueprints.GLYPHS[key] or DockBlueprints.GLYPHS.Level3
end

function DockBlueprints.locked(item: Item, rankIndex: number): boolean
	if item.kind == "Blueprint" then
		return true -- quest-locked until the chain hands it over
	elseif item.kind == "Decor" then
		return false -- Cash only, no rank
	end
	local entry = if item.kind == "Level"
		then DockConfig.Levels[item.key]
		else DockConfig.Buildings[item.key]
	return DockConfig.rankIndex(entry.rank) > rankIndex
end

return DockBlueprints
