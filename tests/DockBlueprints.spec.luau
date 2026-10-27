-- DockBlueprints (docs/23 (j), WP-14d; the unlock tree, docs/23 (q), WP-28): the build tablet shows every tree
-- building, quest blueprint and decor; a building whose prerequisite is missing names it ("Needs: X"); only
-- buildings and decor are for sale; the island gets a paper for everything not owned (locked ones too).
return function(t)
	local D = t.load("src/shared/DockBlueprints.luau")
	local DockConfig = t.load("src/shared/Config/DockConfig.luau")

	t.test("catalog lists every building, blueprint and decoration, in card order", function()
		local items = D.catalog()
		local blueprints = 0
		for _ in DockConfig.Blueprints do
			blueprints += 1
		end
		t.expect(#items).toBe(#DockConfig.BUILDINGS + blueprints + #DockConfig.DECOR)
		t.expect(items[1].kind).toBe("Building")
		t.expect(items[1].key).toBe(DockConfig.BUILDINGS[1])
		t.expect(items[#items].kind).toBe("Decor")
		t.expect(items[#items].key).toBe(DockConfig.DECOR[#DockConfig.DECOR])
	end)

	t.test("cards carry 1-3 word labels", function()
		t.expect(D.label({ kind = "Building", key = "LookoutTower" })).toBe("Lookout Tower")
		t.expect(D.label({ kind = "Building", key = "SubPen" })).toBe("Sub Pen")
		t.expect(D.label({ kind = "Blueprint", key = "Lighthouse" })).toBe("Lighthouse")
		t.expect(D.label({ kind = "Decor", key = "PicnicTable" })).toBe("Picnic table")
	end)

	t.test("buildings and decor are sold; a blueprint is a quest reward", function()
		t.expect(D.buyable({ kind = "Building", key = "AirStation" })).toBe(true)
		t.expect(D.buyable({ kind = "Decor", key = "FlowerBed" })).toBe(true)
		t.expect(D.buyable({ kind = "Blueprint", key = "Lighthouse" })).toBe(false)
	end)

	t.test("level rows carry no old padlock; decor and blueprints need nothing", function()
		t.expect(D.needs({ kind = "Building", key = "Depot" }, {})).toBeNil()
		t.expect(D.needs({ kind = "Building", key = "AirStation" }, {})).toBeNil()
		t.expect(D.needs({ kind = "Decor", key = "Statue" }, {})).toBeNil()
		t.expect(D.needs({ kind = "Blueprint", key = "Lighthouse" }, {})).toBeNil()
	end)

	t.test("WP-14e: the island gets a paper for every building and decor not owned", function()
		local items = D.onIsland({})
		t.expect(#items).toBe(#DockConfig.BUILDINGS + #DockConfig.DECOR) -- no quest lighthouse
		for _, item in items do
			t.expect(D.buyable(item)).toBe(true)
		end
		local owned = { SubPen = true, FlowerBed = true }
		for _, item in D.onIsland(owned) do
			t.expect(owned[item.key]).toBeNil()
		end
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
				local boxes = D.GLYPHS[item.key]
				t.expect(boxes ~= nil).toBe(true)
				for _, box in boxes do
					t.expect(box.x >= 0 and box.y >= 0 and box.w > 0 and box.h > 0).toBe(true)
					t.expect(box.x + box.w <= 1 + 1e-6 and box.y + box.h <= 1 + 1e-6).toBe(true)
				end
			end
		end
	)
end
