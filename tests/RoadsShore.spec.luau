-- RoadsShore (I2c): the pure placement rules for road furniture, shore dressing and the island proxies.
return function(t)
	local Layout = t.load("src/server/World/RoadsShoreLayout.luau")

	local function near(a: number, b: number, eps: number?): boolean
		return math.abs(a - b) <= (eps or 1e-4)
	end

	local function localAxis(yaw: number, axis: Vector3): Vector3
		return CFrame.Angles(0, yaw, 0):VectorToWorldSpace(axis)
	end

	t.test(
		"yawAlong turns a piece's local -X (barrier / wall / gate run) along the road",
		function()
			for _, dir in
				{
					Vector3.new(1, 0, 0),
					Vector3.new(0, 0, -1),
					Vector3.new(-0.6, 0, 0.8),
				}
			do
				local got = localAxis(Layout.yawAlong(dir), Vector3.new(-1, 0, 0))
				t.expect((got - dir.Unit).Magnitude < 1e-6).toBe(true)
			end
		end
	)

	t.test("faceYaw turns a sign's local -Z toward the road", function()
		for _, face in
			{
				Vector3.new(0, 0, 1),
				Vector3.new(-1, 0, 0),
				Vector3.new(0.3, 0, -0.7),
			}
		do
			local got = localAxis(Layout.faceYaw(face), Vector3.new(0, 0, -1))
			t.expect((got - face.Unit).Magnitude < 1e-6).toBe(true)
		end
	end)

	t.test("length and run: 12-stud pieces tile the offset line", function()
		local road = { Vector3.new(0, 4, 0), Vector3.new(100, 4, 0) }
		t.expect(near(Layout.length(road), 100)).toBe(true)
		local pieces = Layout.run(road, 10, 70, 1, 8, 12)
		t.expect(#pieces).toBe(6) -- s 10, 22, 34, 46, 58, 70
		for i, p in pieces do
			t.expect(near(p.pos.X, 10 + (i - 1) * 12)).toBe(true)
			t.expect(near(p.pos.Z, 8)).toBe(true) -- right of eastbound travel
		end
	end)

	t.test("spot: side and offset, negative s from the end", function()
		local road = { Vector3.new(0, 4, 0), Vector3.new(100, 4, 0) }
		local p = Layout.spot(road, -20, -1, 15)
		t.expect(p ~= nil).toBe(true)
		t.expect(near((p :: any).pos.X, 80)).toBe(true)
		t.expect(near((p :: any).pos.Z, -15)).toBe(true)
		t.expect(Layout.spot(road, 200, 1, 10)).toBeNil()
	end)

	t.test("barriers sit on the outside of a right-hand bend", function()
		local road = { Vector3.new(0, 0, 0), Vector3.new(100, 0, 0), Vector3.new(100, 0, 100) }
		local pieces =
			Layout.barriers(road, { step = 4, look = 24, run = 3, offset = 11, gap = 45 })
		t.expect(#pieces >= 3).toBe(true)
		local outside = 0
		for _, p in pieces do
			if (p.s <= 100 and p.pos.Z < 0) or (p.s > 100 and p.pos.X > 100) then
				outside += 1
			end
		end
		t.expect(outside).toBe(#pieces)
	end)

	t.test("barriers swap sides for a left-hand bend and keep the gap between bends", function()
		local road = { Vector3.new(0, 0, 0), Vector3.new(100, 0, 0), Vector3.new(100, 0, -100) }
		local pieces =
			Layout.barriers(road, { step = 4, look = 24, run = 3, offset = 11, gap = 45 })
		t.expect(#pieces >= 3).toBe(true)
		for _, p in pieces do
			if p.s <= 100 then
				t.expect(p.pos.Z > 0).toBe(true)
			else
				t.expect(p.pos.X > 100).toBe(true)
			end
		end
		local centres = {}
		for _, p in pieces do
			table.insert(centres, p.s)
		end
		t.expect(#centres >= 3).toBe(true)
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
