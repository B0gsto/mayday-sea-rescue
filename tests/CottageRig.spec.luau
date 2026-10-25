-- CottageRig (H3 cottages, I1a): the pure light / smoke rules.
return function(t)
	local CottageLights = t.load("src/server/World/CottageLights.luau")

	t.test("part names: GlassLit glows, Glass is glass, the rest is left alone", function()
		t.expect(CottageLights.kind("M_Bld_Cottage_GlassLit_01_LOD0")).toBe("glow")
		t.expect(CottageLights.kind("M_Bld_Cottage_Glass_05_LOD2")).toBe("glass")
		t.expect(CottageLights.kind("M_Bld_Cottage_Walls_01_LOD0")).toBe(nil)
		t.expect(CottageLights.kind("M_Bld_Cottage_Details_03_LOD1")).toBe(nil)
	end)

	t.test("lights at night and in a storm, off on a clear or overcast day", function()
		t.expect(CottageLights.lightsOn("Night")).toBe(true)
		t.expect(CottageLights.lightsOn("Storm")).toBe(true)
		t.expect(CottageLights.lightsOn("Clear")).toBe(false)
		t.expect(CottageLights.lightsOn("Overcast")).toBe(false)
	end)

	t.test("chimney smoke in cold weather or a storm, not on a clear calm day", function()
		t.expect(CottageLights.smokeOn("Clear", "Calm")).toBe(false)
		t.expect(CottageLights.smokeOn("Overcast", "Calm")).toBe(true)
		t.expect(CottageLights.smokeOn("Night", "Calm")).toBe(true)
		t.expect(CottageLights.smokeOn("Clear", "Warning")).toBe(true)
		t.expect(CottageLights.smokeOn("Storm", "Storm")).toBe(true)
	end)

	t.test("one smoke point per chimney stack", function()
		-- M_Bld_Cottage_02: a three-pot ridge stack and a two-pot gable stack
		local pots = {
			Vector3.new(0.9, 23.43, 0),
			Vector3.new(0, 24.18, 0),
			Vector3.new(-0.9, 23.73, 0),
			Vector3.new(-11.98, 23.58, 0),
			Vector3.new(-12.88, 23.13, 0),
		}
		local kept = CottageLights.stacks(pots)
		t.expect(#kept).toBe(2)
		t.expect(kept[1]).toBe(1)
		t.expect(kept[2]).toBe(4)
	end)
end
