-- SeaLife: every ambient route and spot is open water, clear of berths, bridges, islands and each other.
return function(t)
	local CallLogic = t.load("src/shared/Calls/CallLogic.luau")
	local RingLayout = t.load("src/shared/Config/RingLayout.luau")
	local SeaLife = t.load("src/shared/SeaLife.luau")

	local function clear(p: Vector3, margin: number)
		t.expect(CallLogic.isWater(p, "Open")).toBeTruthy()
		for _, island in RingLayout.Islands do
			t.expect(CallLogic.flatDistance(p, island.berths.Boat.Position) >= margin).toBeTruthy()
		end
	end

	local loops = {}
	for _, b in SeaLife.Boats do
		table.insert(loops, b.loop)
	end
	for _, p in SeaLife.Pods do
		table.insert(loops, p.loop)
	end
	table.insert(loops, SeaLife.Whale)

	t.test(
		"every loop stays in open water, 300+ studs off the berths, clear of the sandbars",
		function()
			for _, l in loops do
				local period = 2 * math.pi * l.r / l.speed
				for i = 0, 199 do
					local p, dir = SeaLife.at(l, period * i / 200)
					clear(p, 300)
					t.expect(math.abs(dir.Magnitude - 1) < 1e-3).toBeTruthy()
					for _, s in SeaLife.Sandbars do
						t.expect(CallLogic.flatDistance(p, s.at) > s.size.X / 2 + 60).toBeTruthy()
					end
				end
			end
		end
	)

	t.test("sandbars, marks and flotsam sit in open water", function()
		for _, s in SeaLife.Sandbars do
			local cf = CFrame.new(s.at) * CFrame.Angles(0, math.rad(s.yaw), 0)
			for _, c in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
				clear(
					cf:PointToWorldSpace(Vector3.new(c[1] * s.size.X / 2, 0, c[2] * s.size.Y / 2)),
					300
				)
			end
		end
		for _, p in SeaLife.WreckMarks do
			clear(p, 300)
		end
		for _, p in SeaLife.Flotsam do
			clear(p, 300)
		end
	end)

	t.test("a leap starts and ends at the sea, nose up then down", function()
		local y0, p0 = SeaLife.leap(0, 6)
		local y1, p1 = SeaLife.leap(1, 6)
		t.expect(y0).toBe(0)
		t.expect(y1).toBe(0)
		t.expect(SeaLife.leap(0.5, 6)).toBe(6)
		t.expect(p0 > 0 and p1 < 0).toBeTruthy()
	end)
end
