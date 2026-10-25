-- DockBlueprints (docs/23 (j), WP-14c): the blueprint table shows the next level, every building the
-- plot's level qualifies for, and the quest blueprints not earned yet; owned ones drop off; the rank
-- (or the quest) gates the padlock, and only levels / buildings are for sale.
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

	t.test("sheets carry 1-3 word labels", function()
		t.expect(D.label({ kind = "Level", key = 3 })).toBe("Level 3")
		t.expect(D.label({ kind = "Building", key = "Hangar" })).toBe("Helipad")
		t.expect(D.label({ kind = "Building", key = "SubPen" })).toBe("Sub pen")
		t.expect(D.label({ kind = "Blueprint", key = "Lighthouse" })).toBe("Lighthouse")
	end)

	t.test("only levels and buildings are sold; a blueprint is a quest reward", function()
		t.expect(D.buyable({ kind = "Level", key = 2 })).toBe(true)
		t.expect(D.buyable({ kind = "Building", key = "Hangar" })).toBe(true)
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
	end)
end
