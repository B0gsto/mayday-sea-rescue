--!strict
-- BuildTreeLayout (docs/24 G-a2): where each building sits in the Build tab's tree. Columns are
-- prerequisite depth (a node is one column right of its deepest need), rows are stable order inside a
-- column (DockConfig.BUILDINGS order), so no two nodes share a cell. Pure
-- (tests/BuildTreeLayout.spec.luau); the tablet feeds col/row straight to Kit/TreeView. Two lanes (`group`):
-- "Build" = the unlock tree, then "Quest" = quest-chain blueprints (DockConfig.Blueprints, never sold) in
-- one column, sorted by key.
local DockConfig = require(script.Parent:WaitForChild("Config"):WaitForChild("DockConfig"))

local BuildTreeLayout = {}

export type Cell = { id: string, col: number, row: number, group: string } -- "Build" | "Quest"

-- Relax depths until stable: the unlock tree is small and its needs point left (the bound stops a
-- bad config with a cycle from spinning forever).
function BuildTreeLayout.cells(order: { string }?): { Cell }
	local keys = order or DockConfig.BUILDINGS
	local depth: { [string]: number } = {}
	for _, key in keys do
		depth[key] = 0
	end
	for _ = 1, #keys do
		local moved = false
		for _, key in keys do
			local building = DockConfig.Buildings[key]
			if building then
				for _, need in building.needs do
					local d = (depth[need] or 0) + 1
					if d > depth[key] then
						depth[key], moved = d, true
					end
				end
			end
		end
		if not moved then
			break
		end
	end
	local rows: { [number]: number } = {}
	local out: { Cell } = {}
	for _, key in keys do
		local col = depth[key] or 0
		rows[col] = (rows[col] or -1) + 1
		table.insert(out, { id = key, col = col, row = rows[col], group = "Build" })
	end
	local quests: { string } = {}
	for key in DockConfig.Blueprints do
		table.insert(quests, key)
	end
	table.sort(quests)
	for i, key in quests do
		table.insert(out, { id = key, col = 0, row = i - 1, group = "Quest" })
	end
	return out
end

return BuildTreeLayout
