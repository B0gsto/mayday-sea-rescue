-- CoastArt (G75): the placement data for the I2f coast and seabed art.
return function(t)
	local Layout = t.load("src/server/World/CoastArtLayout.luau")

	t.test("the arch uses the GullyArch POI", function()
		t.expect(Layout.Arch.poi).toBe("GullyArch")
		t.expect(Layout.Arch.asset).toBe("M_Rock_NeedlesEye")
	end)

	t.test("the mail seaplane replaces its POI", function()
		t.expect(Layout.Seaplane.asset).toBe("M_Sea_MailSeaplane")
		t.expect(Layout.Seaplane.poi).toBe("MailSeaplane")
	end)

	t.test("three cliffs and the ledges, each asset named and sunk", function()
		t.expect(#Layout.Cliffs).toBe(3)
		t.expect(#Layout.Ledges >= 3).toBe(true)
		for _, list in { Layout.Cliffs, Layout.Ledges } do
			for _, s in list do
				t.expect(string.sub(s.asset, 1, 7) == "M_Rock_").toBe(true)
				t.expect(s.sink >= 0).toBe(true)
			end
		end
	end)

	t.test("nothing is dressed on the cliff-casualty shelf", function()
		t.expect(Layout.excluded(1740, 890)).toBe(true)
		for _, s in Layout.Cliffs do
			t.expect(Layout.excluded(s.x, s.z)).toBe(false)
		end
		for _, s in Layout.Ledges do
			t.expect(Layout.excluded(s.x, s.z)).toBe(false)
		end
	end)

	t.test("the harbour channel stays clear of clutter", function()
		t.expect(Layout.inHarbourChannel(0, 200)).toBe(true)
		t.expect(Layout.inHarbourChannel(59, 400)).toBe(true)
		t.expect(Layout.inHarbourChannel(61, 400)).toBe(false)
		for _, s in Layout.Pots do
			t.expect(Layout.inHarbourChannel(s.x, s.z)).toBe(false)
		end
		for _, s in Layout.MooringBlocks do
			t.expect(Layout.inHarbourChannel(s.x, s.z)).toBe(false)
		end
	end)

	t.test("each kelp bed names a WorldConfig bed and a valid plant", function()
		for _, s in Layout.Kelp do
			t.expect(#s.bed > 0).toBe(true)
			t.expect(s.piece >= 1 and s.piece <= 4).toBe(true)
			t.expect(s.count > 0).toBe(true)
			t.expect(s.lod == "LOD0" or s.lod == "LOD1").toBe(true)
		end
	end)

	t.test("every ripple keeps one of the four patch parts", function()
		for _, s in Layout.Ripples do
			t.expect(string.find(s.keep, "M_Sea_SandRipples_Patch") == 1).toBe(true)
		end
	end)

	t.test("scatter is deterministic, evenly spread and inside the disk", function()
		local a = Layout.scatter(Vector3.new(10, 0, -4), 60, 24, 7, 10)
		local b = Layout.scatter(Vector3.new(10, 0, -4), 60, 24, 7, 10)
		t.expect(#a).toBe(24)
		local minD, maxD = math.huge, -math.huge
		for i, p in a do
			t.expect(p.X == b[i].X and p.Z == b[i].Z).toBe(true)
			local d = Vector3.new(p.X - 10, 0, p.Z + 4).Magnitude
			minD = math.min(minD, d)
			maxD = math.max(maxD, d)
		end
		t.expect(maxD <= 60 + 1e-4).toBe(true)
		t.expect(minD >= 10 * 0.85).toBe(true)
		t.expect(maxD > 40).toBe(true) -- the outer ring is populated too
	end)
end
