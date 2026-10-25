-- DockBlueprints (docs/23 (j), WP-14d): the build tablet shows every level, building, quest blueprint and
-- decor; `available` still lists what Lv 1 can buy now; owned ones drop off that list; the rank (or the
-- quest) gates the padlock, and only levels / buildings / decor are for sale.
return function(t)
	local D = t.load("src/shared/DockBlueprints.luau")
	local DockConfig = t.load("src/shared/Config/DockConfig.luau")

	local function kinds(items: { any }): { string }
		local out = {}
		for _, item in items do
			table.insert(out, item.kind)
		end
		return out
	end

	t.test("Lv 1: the next level, the sub pen (needs 1) and the quest lighthouse", function()
		local items = D.available(1, {})
		t.expect(#items).toBe(3)
		t.expect(items[1].kind).toBe("Level")
		t.expect(items[1].key).toBe(2)
		t.expect(items[2].kind).toBe("Building")
		t.expect(items[2].key).toBe("SubPen")
		t.expect(items[3].kind).toBe("Blueprint")
		t.expect(items[3].key).toBe("Lighthouse")
		t.expect(table.find(kinds(D.available(1, { SubPen = true, Lighthouse = true })), "Level"))
			.toBe(1)
	end)

	t.test("Lv 3: the next level, the hangar, the sub pen and the lighthouse", function()
		local items = D.available(3, {})
		t.expect(#items).toBe(4)
		t.expect(items[1].key).toBe(4)
		t.expect(items[2].key).toBe("Hangar")
		t.expect(items[3].key).toBe("SubPen")
	end)

	t.test("owned things drop off; at max level no level sheet", function()
		t.expect(#D.available(5, {})).toBe(3)
		t.expect(#D.available(5, { Hangar = true })).toBe(2)
		t.expect(#D.available(5, { Hangar = true, SubPen = true, Lighthouse = true })).toBe(0)
		t.expect(#D.available(2, { SubPen = true })).toBe(2)
	end)

	t.test("catalog lists every level, building, blueprint and decoration", function()
		local items = D.catalog()
		t.expect(#items).toBe(DockConfig.MAX - 1 + #DockConfig.BUILDINGS + 1 + #DockConfig.DECOR)
		t.expect(items[1].kind).toBe("Level")
		t.expect(items[1].key).toBe(2)
		t.expect(items[#items].kind).toBe("Decor")
		t.expect(items[#items].key).toBe(DockConfig.DECOR[#DockConfig.DECOR])
	end)

	t.test("cards carry 1-3 word labels", function()
		t.expect(D.label({ kind = "Level", key = 3 })).toBe("Level 3")
		t.expect(D.label({ kind = "Building", key = "Hangar" })).toBe("Helipad")
		t.expect(D.label({ kind = "Building", key = "SubPen" })).toBe("Sub pen")
		t.expect(D.label({ kind = "Blueprint", key = "Lighthouse" })).toBe("Lighthouse")
		t.expect(D.label({ kind = "Decor", key = "PicnicTable" })).toBe("Picnic table")
	end)

	t.test("levels, buildings and decor are sold; a blueprint is a quest reward", function()
		t.expect(D.buyable({ kind = "Level", key = 2 })).toBe(true)
		t.expect(D.buyable({ kind = "Building", key = "Hangar" })).toBe(true)
		t.expect(D.buyable({ kind = "Decor", key = "FlowerBed" })).toBe(true)
		t.expect(D.buyable({ kind = "Blueprint", key = "Lighthouse" })).toBe(false)
	end)

	t.test("the padlock follows the rank; a quest blueprint stays locked", function()
		local lifeguard = DockConfig.rankIndex("Lifeguard")
		t.expect(D.locked({ kind = "Level", key = 2 }, lifeguard)).toBe(false)
		t.expect(D.locked({ kind = "Level", key = 2 }, lifeguard - 1)).toBe(true)
		t.expect(D.locked({ kind = "Building", key = "Hangar" }, lifeguard)).toBe(true)
		t.expect(
			D.locked({ kind = "Building", key = "Hangar" }, DockConfig.rankIndex("RescuePilot"))
		)
			.toBe(false)
		t.expect(
			D.locked({ kind = "Blueprint", key = "Lighthouse" }, DockConfig.rankIndex("Admiral"))
		)
			.toBe(true)
		t.expect(D.locked({ kind = "Decor", key = "Statue" }, 1)).toBe(false)
	end)

	t.test("WP-14e: the island blueprints are what is for sale now and not owned", function()
		local items = D.onIsland(1, {})
		t.expect(items[1].kind).toBe("Level")
		t.expect(items[1].key).toBe(2)
		t.expect(items[2].key).toBe("SubPen")
		t.expect(#items).toBe(2 + #DockConfig.DECOR) -- no quest lighthouse
		for _, item in items do
			t.expect(D.buyable(item)).toBe(true)
		end
		local owned = { SubPen = true, FlowerBed = true }
		for _, item in D.onIsland(1, owned) do
			t.expect(owned[item.key]).toBeNil()
		end
		t.expect(#D.onIsland(5, { Hangar = true, SubPen = true })).toBe(#DockConfig.DECOR)
	end)

	t.test(
		"WP-14e: every item has a short desc and its own drawing inside the unit square",
		function()
			for _, item in D.catalog() do
				local desc = D.desc(item)
				t.expect(type(desc)).toBe("string")
				local words = 0
				for _ in string.gmatch(desc, "%S+") do
					words += 1
				end
				t.expect(words >= 3 and words <= 10).toBe(true)
				local key = if item.kind == "Level" then `Level{item.key}` else item.key
				local boxes = D.GLYPHS[key]
				t.expect(boxes ~= nil).toBe(true)
				for _, box in boxes do
					t.expect(box.x >= 0 and box.y >= 0 and box.w > 0 and box.h > 0).toBe(true)
					t.expect(box.x + box.w <= 1 + 1e-6 and box.y + box.h <= 1 + 1e-6).toBe(true)
				end
			end
		end
	)
end
