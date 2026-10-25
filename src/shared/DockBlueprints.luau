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
