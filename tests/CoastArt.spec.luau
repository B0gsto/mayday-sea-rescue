-- CoastArt (G75): the placement data for the I2f coast and seabed art.
return function(t)
	local Layout = t.load("src/server/World/CoastArtLayout.luau")

	t.test("the mail seaplane replaces its POI", function()
		t.expect(Layout.Seaplane.asset).toBe("M_Sea_MailSeaplane")
		t.expect(Layout.Seaplane.poi).toBe("MailSeaplane")
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
