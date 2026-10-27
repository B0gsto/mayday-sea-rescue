-- BuildTreeLayout (docs/24 G-a2): the Build tab's tree cells: one column right of every prerequisite,
-- stable DockConfig order down a column, one node per cell.
return function(t)
	local L = t.load("src/shared/BuildTreeLayout.luau")
	local DockConfig = t.load("src/shared/Config/DockConfig.luau")

	local function buildCells()
		local out = {}
		for _, cell in L.cells() do
			if cell.group == "Build" then
				table.insert(out, cell)
			end
		end
		return out
	end

	t.test("every building gets a cell, in BUILDINGS order", function()
		local cells = buildCells()
		t.expect(#cells).toBe(#DockConfig.BUILDINGS)
		for i, cell in cells do
			t.expect(cell.id).toBe(DockConfig.BUILDINGS[i])
		end
	end)

	t.test("quest blueprints follow in their own Quest lane, one column", function()
		local cells = L.cells()
		local n = 0
		for _ in DockConfig.Blueprints do
			n += 1
		end
		t.expect(#cells).toBe(#DockConfig.BUILDINGS + n)
		local row = 0
		for i = #DockConfig.BUILDINGS + 1, #cells do
			local cell = cells[i]
			t.expect(cell.group).toBe("Quest")
			t.expect(DockConfig.Blueprints[cell.id] ~= nil).toBe(true)
			t.expect(cell.col).toBe(0)
			t.expect(cell.row).toBe(row)
			row += 1
		end
		t.expect(cells[#cells].id).toBe("Lighthouse")
	end)

	t.test(
		"level rows all sit in the first column (HQ gates replace the old prerequisite tree)",
		function()
			for _, cell in buildCells() do
				t.expect(cell.col).toBe(0)
				t.expect(DockConfig.Buildings[cell.id].needs).toEqual({})
			end
		end
	)

	t.test("no two nodes share a cell", function()
		local seen: { [string]: boolean } = {}
		for _, cell in L.cells() do
			local key = `{cell.group}:{cell.col}:{cell.row}`
			t.expect(seen[key]).toBeNil()
			seen[key] = true
			t.expect(cell.col >= 0 and cell.row >= 0).toBe(true)
		end
	end)

	t.test("rows inside a column keep the stable config order; calls agree", function()
		t.expect(L.cells()).toEqual(L.cells())
		local first = buildCells()
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
