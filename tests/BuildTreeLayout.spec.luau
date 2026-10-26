-- BuildTreeLayout (docs/24 G-a2): the Build tab's tree cells: one column right of every prerequisite,
-- stable DockConfig order down a column, one node per cell.
return function(t)
	local L = t.load("src/shared/BuildTreeLayout.luau")
	local DockConfig = t.load("src/shared/Config/DockConfig.luau")

	t.test("every building gets a cell, in BUILDINGS order", function()
		local cells = L.cells()
		t.expect(#cells).toBe(#DockConfig.BUILDINGS)
		for i, cell in cells do
			t.expect(cell.id).toBe(DockConfig.BUILDINGS[i])
		end
	end)

	t.test("a node sits right of all its prerequisites", function()
		local cells = L.cells()
		local col: { [string]: number } = {}
		for _, cell in cells do
			col[cell.id] = cell.col
		end
		for _, cell in cells do
			local building = DockConfig.Buildings[cell.id]
			for _, need in building.needs do
				t.expect(col[need] ~= nil).toBe(true)
				t.expect(cell.col > col[need]).toBe(true)
			end
		end
		t.expect(col.Workshop).toBe(0)
		t.expect(col.Boathouse).toBe(1)
		t.expect(col.Station).toBe(2)
		t.expect(col.TrophyHall).toBe(col.Station + 1)
	end)

	t.test("no two nodes share a cell", function()
		local seen: { [string]: boolean } = {}
		for _, cell in L.cells() do
			local key = `{cell.col}:{cell.row}`
			t.expect(seen[key]).toBeNil()
			seen[key] = true
			t.expect(cell.col >= 0 and cell.row >= 0).toBe(true)
		end
	end)

	t.test("rows inside a column keep the stable config order; calls agree", function()
		local first = L.cells()
		local second = L.cells()
		t.expect(second).toEqual(first)
		local byCol: { [number]: { any } } = {}
		for _, cell in first do
			local list = byCol[cell.col]
			if not list then
				list = {}
				byCol[cell.col] = list
			end
			table.insert(list, cell)
		end
		for _, list in byCol do
			table.sort(list, function(a: any, b: any): boolean
				return a.row < b.row
			end)
			for i = 2, #list do
				local prev = table.find(DockConfig.BUILDINGS, list[i - 1].id)
				local now = table.find(DockConfig.BUILDINGS, list[i].id)
				t.expect(prev < now).toBe(true)
			end
		end
	end)
end
