-- CottageRig (H3 cottages, I1a): the pure light / smoke rules and the House1..6 swap entries.
return function(t)
	local CottageLights = t.load("src/server/World/CottageLights.luau")
	local Swaps = t.load("src/server/World/Swaps.luau")

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

	t.test("House1..6 swap in place of the greybox, facing +Z, with box colliders", function()
		local spots = {
			Vector3.new(-150, 4, -192),
			Vector3.new(-60, 4, -192),
			Vector3.new(90, 4, -192),
			Vector3.new(130, 4, -192),
			Vector3.new(260, 4, -192),
			Vector3.new(310, 4, -192),
		}
		for n = 1, 6 do
			local s = Swaps[`House{n}`]
			t.expect(s ~= nil).toBe(true)
			t.expect(s.greybox[3]).toBe(`House{n}`)
			t.expect(s.shell[1]).toBe(string.format("M_Bld_Cottage_%02d", n))
			t.expect(s.rig).toBe("CottageRig")
			t.expect(s.collide).toBe(false)
			t.expect((s.pivot.Position - spots[n]).Magnitude).toBeCloseTo(0, 1e-6)
			-- the asset front (-Z) faces the street (+Z)
			t.expect(s.pivot.LookVector.Z).toBeCloseTo(1, 1e-6)
			-- the wall box matches the greybox footprint: (18 + (n % 3) * 4) x 16 studs, eaves 12 + (n % 2) * 6
			local b = (s.colliders :: any)[1]
			t.expect((b[4] - b[1]) * 3).toBeCloseTo(18 + (n % 3) * 4, 1e-6)
			t.expect((b[5] - b[2]) * 3).toBeCloseTo(16, 1e-6)
			t.expect(b[6] * 3).toBeCloseTo(12 + (n % 2) * 6, 1e-6)
			t.expect(b[3]).toBeCloseTo(-0.4, 1e-9)
		end
		-- the pairs have two door steps, House4 its slate porch
		t.expect(#(Swaps.House2.colliders :: any)).toBe(3)
		t.expect(#(Swaps.House5.colliders :: any)).toBe(3)
		t.expect(#(Swaps.House4.colliders :: any)).toBe(5)
	end)
end
