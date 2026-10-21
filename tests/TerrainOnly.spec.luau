-- TerrainOnly: Parts never keep a material or variant the terrain's MaterialService slots use.
return function(t)
	local TerrainOnly = t.load("src/shared/TerrainOnly.luau")

	t.test("overridden built-in materials move to an unmapped lookalike", function()
		t.expect(TerrainOnly.remap("Concrete", "")).toBe("Plaster")
		t.expect(TerrainOnly.remap("Grass", "")).toBe("Fabric")
		t.expect(TerrainOnly.remap("WoodPlanks", "")).toBe("Wood")
		t.expect(TerrainOnly.remap("Slate", "KelpRock")).toBe("Granite")
	end)

	t.test("unmapped materials and part-only variants are left alone", function()
		t.expect(TerrainOnly.remap("Granite", "")).toBe(nil)
		t.expect(TerrainOnly.remap("SmoothPlastic", "")).toBe(nil)
		t.expect(TerrainOnly.remap("Granite", "RoadKerbGranite")).toBe(nil)
		t.expect(TerrainOnly.remap("Concrete", "WeedyConcrete")).toBe(nil)
	end)

	t.test("a terrain variant on an unmapped base is dropped", function()
		t.expect(TerrainOnly.remap("Plastic", "Turf_Wet")).toBe("Plastic")
	end)
end
