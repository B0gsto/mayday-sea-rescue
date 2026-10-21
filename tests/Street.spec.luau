-- Street (I1b-3): the pure placement rules (StreetLayout) and the Harbour Light's Fl(2) W 10s character.
return function(t)
	local StreetLayout = t.load("src/server/World/StreetLayout.luau")
	local Beam = t.load("src/shared/HarbourLightBeam.luau")

	local line = { Vector3.new(0, 4, 0), Vector3.new(100, 4, 0), Vector3.new(100, 14, 100) }

	t.test("walk samples every step of arc length and interpolates the road height", function()
		local s = StreetLayout.walk(line, 25)
		t.expect(#s).toBe(9) -- 0, 25 .. 200
		t.expect(math.abs(s[2].pos.X - 25) < 1e-4).toBe(true)
		t.expect(math.abs(s[6].pos.Z - 25) < 1e-4).toBe(true) -- 125: a quarter up the second leg
		t.expect(math.abs(s[6].pos.Y - 6.5) < 1e-4).toBe(true)
		t.expect(s[6].dir.Z).toBe(1)
		local part = StreetLayout.walk(line, 10, 30, 50)
		t.expect(#part).toBe(3)
		t.expect(math.abs(part[1].pos.X - 30) < 1e-4).toBe(true)
	end)

	t.test("right of travel is +Z heading east (the quay side of Harbour Road)", function()
		local s = StreetLayout.walk(line, 50)[1]
		local r = StreetLayout.offset(s, 1, 10)
		t.expect(r.Z).toBe(10)
		t.expect(StreetLayout.offset(s, -1, 10).Z).toBe(-10)
	end)

	t.test("centre dashes: 4 m marks with 5 m gaps", function()
		local d = StreetLayout.dashes({ Vector3.new(0, 0, 0), Vector3.new(90, 0, 0) }, 12, 15)
		t.expect(#d).toBe(3) -- starts 0, 27, 54 (81 would run to 93: off the end, dropped)
		t.expect(math.abs(d[1].b.X - d[1].a.X - 12) < 1e-4).toBe(true)
		t.expect(math.abs(d[2].a.X - 27) < 1e-4).toBe(true)
	end)

	t.test("edge lines chain the offset curve without gaps", function()
		local c = StreetLayout.chain({ Vector3.new(0, 0, 0), Vector3.new(64, 0, 0) }, 16, -1, 8)
		t.expect(#c).toBe(4)
		t.expect(c[1].b).toBe(c[2].a)
		t.expect(c[1].a.Z).toBe(-8)
	end)

	t.test("lamp yaw turns the bracket (asset -X) over the carriageway", function()
		for _, toward in
			{
				Vector3.new(0, 0, -1),
				Vector3.new(0, 0, 1),
				Vector3.new(1, 0, 0),
				Vector3.new(-0.6, 0, 0.8),
			}
		do
			local cf = CFrame.Angles(0, StreetLayout.lampYaw(toward), 0)
			local bracket = cf:VectorToWorldSpace(Vector3.new(-1, 0, 0))
			t.expect((bracket - toward).Magnitude < 1e-6).toBe(true)
		end
	end)

	t.test("face yaw turns a vehicle's forward (-Z) along the parking direction", function()
		for _, face in
			{
				Vector3.new(0, 0, -1),
				Vector3.new(1, 0, 0),
				Vector3.new(-0.4, 0, 0.9),
			}
		do
			local cf = CFrame.Angles(0, StreetLayout.faceYaw(face), 0)
			local forward = cf:VectorToWorldSpace(Vector3.new(0, 0, -1))
			t.expect((forward - face.Unit).Magnitude < 1e-6).toBe(true)
		end
	end)

	t.test("clearance: blockers, keep-out rects and distance to a road", function()
		local block = { { pos = Vector3.new(10, 0, 10), r = 5 } }
		t.expect(StreetLayout.clear(Vector3.new(12, 99, 12), block)).toBe(false)
		t.expect(StreetLayout.clear(Vector3.new(20, 0, 10), block)).toBe(true)
		t.expect(StreetLayout.clear(Vector3.new(-150, 4, 0), {}, { { -185, -46, -72, 8 } }))
			.toBe(false)
		t.expect(StreetLayout.distToPolyline(Vector3.new(50, 0, 7), line)).toBe(7)
	end)

	t.test("Fl(2) W 10s: two 0.5 s flashes 1.67 s apart every 10 s from any bearing", function()
		for _, bearing in { 47, 123, 200, 260, 330 } do
			local flashes: { number } = {}
			local was = false
			for i = 0, 3999 do
				local tt = i * 0.005 -- 20 s
				local on = Beam.intensity(tt, bearing) > 0.5
				if on and not was then
					table.insert(flashes, tt)
				end
				was = on
			end
			t.expect(#flashes).toBe(4) -- one optic turn: two pairs
			for k = 2, #flashes do
				local gap = flashes[k] - flashes[k - 1]
				local short = math.abs(gap - 30 / 18) < 0.05 -- within a pair
				local long = math.abs(gap - (10 - 30 / 18)) < 0.05 -- the 8.3 s eclipse
				t.expect(short or long).toBe(true)
			end
			-- the next flash after the last one closes the 20 s cycle
			t.expect(
				math.abs(
					flashes[1]
						+ 20
						- flashes[4]
						- (if flashes[2] - flashes[1] < 2 then 10 - 30 / 18 else 30 / 18)
				) < 0.05
			).toBe(true)
		end
		-- flash length about 0.5 s (above half intensity ~0.35 s of a 0.5 s bump)
		local n = 0
		for i = 0, 1999 do
			if Beam.intensity(i * 0.005, 90) > 0 then
				n += 1
			end
		end
		t.expect(math.abs(n * 0.005 / 2 - 0.5) < 0.03).toBe(true) -- two flashes in 10 s
	end)

	t.test("bearing matches the optic's turn and the light is on at night or in a storm", function()
		local dir = CFrame.Angles(0, math.rad(40), 0) * Vector3.xAxis
		t.expect(math.abs(Beam.bearing(dir.X, dir.Z) - 40) < 1e-3).toBe(true)
		t.expect(Beam.intensity(40 / 18, 40) > 0.999).toBe(true)
		t.expect(Beam.lit("Calm", "Clear", 0.5)).toBe(false)
		t.expect(Beam.lit("Calm", "Night", 0.5)).toBe(true)
		t.expect(Beam.lit("Calm", "Overcast", -0.1)).toBe(true)
		t.expect(Beam.lit("Storm", "Clear", 0.5)).toBe(true)
	end)
end
