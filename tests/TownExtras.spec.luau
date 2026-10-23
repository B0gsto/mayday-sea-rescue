-- TownExtras (I2a): the moored boats sit on the six visitors' moorings, bows to their buoys and clear of the
-- pick-up buoys and the dredged channel.
return function(t)
	local Layout = t.load("src/server/World/TownExtrasLayout.luau")
	local R = t.load("src/shared/SeamarkRules.luau")

	local moorings = {}
	for _, m in R.Marks do
		if string.match(m.id, "^Mooring%d+$") then
			table.insert(moorings, { id = m.id, x = m.x, z = m.z })
		end
	end

	t.test("one boat per visitors' mooring, bow to the buoy", function()
		t.expect(#moorings).toBe(6)
		local boats = Layout.mooredBoats(moorings, 0)
		t.expect(#boats).toBe(6)
		for i, b in boats do
			local m = moorings[i]
			local buoy = Vector3.new(m.x, 0, m.z)
			t.expect(b.id).toBe(m.id)
			t.expect(math.abs((b.cf.Position - buoy).Magnitude - Layout.BOAT_OFFSET) < 1e-3)
				.toBe(true)
			local bow = b.cf * Vector3.new(0, 0, -Layout.MOOR_BOW)
			-- the bow points at the mooring: it is BOAT_OFFSET - MOOR_BOW studs short of it
			t.expect(
				math.abs((bow - buoy).Magnitude - (Layout.BOAT_OFFSET - Layout.MOOR_BOW)) < 1e-3
			)
				.toBe(true)
		end
	end)

	t.test("boats stay clear of the pick-up buoys and the dredged channel", function()
		local boats = Layout.mooredBoats(moorings, 0)
		for i, b in boats do
			local m = moorings[i]
			local pickup = Vector3.new(m.x + 3.2, 0, m.z + 2.4)
			t.expect((b.cf.Position - pickup).Magnitude > 8).toBe(true)
			t.expect(math.abs(b.cf.Position.X) > 40).toBe(true) -- channel |x| < 40
		end
	end)

	t.test(
		"harbour crabbers and trawlers float at sea level, spaced and out of the channel",
		function()
			local boats = Layout.harbourBoats(0)
			t.expect(#boats).toBe(11)
			local small = Layout.mooredBoats(moorings, 0)
			for _, b in boats do
				t.expect(b.cf.Position.Y).toBe(0)
				local hull = Layout.HULL[b.asset]
				t.expect(hull ~= nil).toBe(true)
				local r = math.sqrt(hull.half ^ 2 + hull.beam ^ 2)
				t.expect(math.abs(b.cf.Position.X) > 40 + hull.beam).toBe(true)
				t.expect(b.cf.Position.Z > 4 + hull.beam).toBe(true) -- off the quay face
				t.expect(b.cf.Position.Z < 340 - hull.half).toBe(true) -- short of the mouth
				t.expect(math.abs(b.cf.Position.X) < 300 - hull.beam).toBe(true) -- inside the arms
				for _, o in boats do
					if o ~= b then
						local oh = Layout.HULL[o.asset]
						t.expect(
							(o.cf.Position - b.cf.Position).Magnitude
								> r + math.sqrt(oh.half ^ 2 + oh.beam ^ 2)
						).toBe(true)
					end
				end
				for _, o in small do
					t.expect((o.cf.Position - b.cf.Position).Magnitude > r + 7).toBe(true)
				end
			end
		end
	)
end
