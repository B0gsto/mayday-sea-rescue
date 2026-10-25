--!strict
-- DockBlueprints (docs/23 (j), WP-14c): which upgrades the plot's blueprint table shows. Pure
-- (tests/DockBlueprints.spec.luau). `available` = the next dock level (when there is one), every
-- DockConfig building the plot's level qualifies for and does not own, and every quest blueprint
-- (DockConfig.Blueprints, e.g. the Lighthouse) not earned yet. `locked` = not for sale yet: the rank is
-- too low, or the quest blueprint still has to be earned (padlock on the sheet). `buyable` = the price
-- card can sell it (blueprints come from quests, not Cash or Robux).
local DockConfig = require(script.Parent:WaitForChild("Config"):WaitForChild("DockConfig"))

export type Item =
	{ kind: "Level", key: number }
	| { kind: "Building", key: string }
	| { kind: "Blueprint", key: string }

local DockBlueprints = {}

DockBlueprints.WORDS = { Hangar = "Helipad", SubPen = "Sub pen" } :: { [string]: string }

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

-- The 1-3 word name on the sheet (and the prompt): "Level 3", "Helipad", "Sub pen", "Lighthouse".
function DockBlueprints.label(item: Item): string
	if item.kind == "Level" then
		return `Level {item.key}`
	end
	return DockBlueprints.WORDS[item.key] or item.key
end

-- Only levels and DockConfig buildings are sold; a blueprint is a quest reward.
function DockBlueprints.buyable(item: Item): boolean
	return item.kind ~= "Blueprint"
end

function DockBlueprints.locked(item: Item, rankIndex: number): boolean
	if item.kind == "Blueprint" then
		return true -- quest-locked until the chain hands it over
	end
	local entry = if item.kind == "Level"
		then DockConfig.Levels[item.key]
		else DockConfig.Buildings[item.key]
	return DockConfig.rankIndex(entry.rank) > rankIndex
end

return DockBlueprints
