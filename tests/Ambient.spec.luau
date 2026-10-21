-- Ambient (RP-NPC1): the living-town plan: caps, routines, routes and static spots that never block roads, the
-- slipways or the quay ladders.
return function(t)
	local Plan = t.require("Ambient/AmbientPlan")
	local WorldConfig = t.require("Config/WorldConfig")
	local Harbour = t.load("src/server/World/Harbour.luau")

	t.test("caps grow with the quality tier and stay small", function()
		local l, m, h = Plan.CAPS.low, Plan.CAPS.medium, Plan.CAPS.high
		t.expect(l.people < m.people and m.people < h.people).toBe(true)
		t.expect(l.cars <= m.cars and m.cars <= h.cars).toBe(true)
		t.expect(h.people * 120 + h.cars * 15 < 4000).toBe(true) -- a slice of the ~20k instance budget
	end)

	t.test("traffic scales with the lane length in the ring, capped per tier", function()
		local m = Plan.CAPS.medium
		t.expect(Plan.carCap(m, 0, 1)).toBe(0)
		t.expect(Plan.carCap(m, Plan.LANE_PER_CAR * 4, 1)).toBe(4)
		t.expect(Plan.carCap(m, 1e6, 1)).toBe(m.cars)
		t.expect(Plan.carCap(m, 1e6, 0.5)).toBe(m.cars // 2)
	end)

	t.test(
		"storms send the street, beach and quay indoors but not the shop; night clears the beach",
		function()
			local storm = Plan.routine("Storm", false)
			t.expect(storm.beach).toBe(0)
			t.expect(storm.quay).toBe(0)
			t.expect(storm.indoor).toBe(1)
			t.expect(storm.street).toBe(0) -- everyone is indoors
			local night = Plan.routine("Calm", true)
			t.expect(night.beach).toBe(0)
			t.expect(night.street < 1).toBe(true)
			t.expect(Plan.routine("Calm", false).street).toBe(1)
			t.expect(Plan.routine("Nonsense", false).street).toBe(1)
		end
	)

	t.test(
		"pavements run beside every road off the carriageway; lanes stay on it, left of centre",
		function()
			local roads = {}
			for _, r in WorldConfig.Roads do
				roads[r.id] = r
			end
			local lanes = 0
			for _, r in Plan.routes() do
				local road = roads[r.road]
				if not road then
					-- the quay promenade is a pavement off the roads, behind the coping
					t.expect(r.kind).toBe("pavement")
					local p = Plan.sample(r, r.length / 2)
					t.expect(math.abs(p.Z - Harbour.QUAY_FACE_Z) < 6).toBe(true)
					continue
				end
				t.expect(Plan.NO_WALK[r.road]).toBeNil()
				local mid = Plan.sample(r, r.length / 2)
				local d = Plan.distToPolyline(mid, road.points)
				if r.kind == "pavement" then
					t.expect(d > road.width / 2).toBe(true)
				else
					lanes += 1
					t.expect(road.surface).toBe("Asphalt")
					t.expect(d).toBeCloseTo(road.width / 4, 0.5)
					-- left-hand traffic: the lane is left of the travel direction
					local p, dir = Plan.sample(r, r.length / 2)
					local left = Vector3.new(dir.Z, 0, -dir.X)
					local nearest = Plan.distToPolyline(p - left * (road.width / 4), road.points)
					t.expect(nearest < 0.5).toBe(true)
				end
			end
			t.expect(lanes > 0).toBe(true)
		end
	)

	t.test("sample walks the arc length", function()
		local r = {
			kind = "lane",
			road = "x",
			points = { Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), Vector3.new(10, 2, 10) },
			cum = { 0, 10, 20 },
			length = 20,
		}
		local p, dir = Plan.sample(r, 15)
		t.expect(p.X).toBeCloseTo(10, 1e-6)
		t.expect(p.Z).toBeCloseTo(5, 1e-6)
		t.expect(p.Y).toBeCloseTo(1, 1e-6)
		t.expect(dir.Z).toBeCloseTo(1, 1e-6)
		t.expect(Plan.sample(r, 99).Z).toBeCloseTo(10, 1e-6)
	end)

	t.test("cars carry on to the next road, or U-turn at a dead end", function()
		local lanes = {}
		for _, r in Plan.routes() do
			if r.kind == "lane" then
				table.insert(lanes, r)
			end
		end
		for i, l in lanes do
			local j = Plan.nextLane(lanes, i)
			local a, b = l.points[#l.points], lanes[j].points[1]
			t.expect(Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude < 30).toBe(true)
		end
	end)

	t.test("cars route across junctions: every way on but back, turns join smoothly", function()
		local RoadNet = t.require("RoadNet")
		local lanes = {}
		for _, r in Plan.routes() do
			if r.kind == "lane" then
				table.insert(lanes, r)
			end
		end
		local stops = Plan.junctionStops(lanes, RoadNet.junctions(WorldConfig.Roads))
		local entered = 0
		for i, list in stops do
			for _, st in list do
				entered += 1
				local p0, d0 = Plan.sample(lanes[i], st.at)
				for _, e in st.exits do
					local turn = Plan.turn(lanes[i], st.at, lanes[e.lane], e.s)
					local p1, d1 = Plan.sample(lanes[e.lane], e.s)
					-- never a U-turn: the same road only straight on, in the same direction
					t.expect(lanes[e.lane].road ~= lanes[i].road or d1:Dot(d0) > 0.7).toBe(true)
					t.expect((turn.points[1] - p0).Magnitude < 1e-3).toBe(true)
					t.expect((turn.points[#turn.points] - p1).Magnitude < 1e-3).toBe(true)
					t.expect(turn.length < 120).toBe(true)
				end
			end
		end
		t.expect(entered >= 13).toBe(true)
	end)

	t.test("a T: left turn is the tight one, right turn swings wide", function()
		local RoadNet = t.require("RoadNet")
		local saved = WorldConfig.Roads
		WorldConfig.Roads = {
			{
				id = "Main",
				surface = "Asphalt",
				width = 16,
				points = { Vector3.new(-200, 0, 0), Vector3.new(200, 0, 0) },
			},
			{
				id = "Side",
				surface = "Asphalt",
				width = 16,
				points = { Vector3.new(0, 0, 0), Vector3.new(0, 0, -200) },
			},
		}
		local lanes = {}
		for _, r in Plan.routes() do
			if r.kind == "lane" then
				table.insert(lanes, r)
			end
		end
		local stops = Plan.junctionStops(lanes, RoadNet.junctions(WorldConfig.Roads))
		WorldConfig.Roads = saved
		-- eastbound on Main (lane 1): straight on, or left (north, -Z, keeping left = the tight one)
		local st = stops[1][1]
		t.expect(#st.exits).toBe(2)
		local lens = {}
		for _, e in st.exits do
			lens[lanes[e.lane].road] = Plan.turn(lanes[1], st.at, lanes[e.lane], e.s).length
		end
		t.expect(lens.Main ~= nil and lens.Side ~= nil).toBe(true)
		-- southbound on Side (lane 4) ends at the T: left (east) and right (west), no U-turn
		local sst = stops[4][1]
		t.expect(#sst.exits).toBe(2)
		local left, right
		for _, e in sst.exits do
			local _, d1 = Plan.sample(lanes[e.lane], e.s)
			local len = Plan.turn(lanes[4], sst.at, lanes[e.lane], e.s).length
			if d1.X > 0 then
				left = len
			else
				right = len
			end
		end
		t.expect(left < right).toBe(true)
	end)

	t.test("no spot blocks a road, a slipway, the quay ladders or steps", function()
		local launches = {}
		for _, p in WorldConfig.Points do
			if p.kind == "Launch" then
				table.insert(launches, p.position)
			end
		end
		local spots = Plan.spots()
		t.expect(#spots >= 20).toBe(true)
		for _, s in spots do
			for _, road in WorldConfig.Roads do
				local clear = road.width / 2 + 1
				if Plan.NO_WALK[road.id] then
					clear = road.width / 2 + 15
				end
				t.expect(Plan.distToPolyline(s.pos, road.points) > clear).toBe(true)
			end
			for _, l in launches do
				t.expect((Vector3.new(s.pos.X - l.X, 0, s.pos.Z - l.Z)).Magnitude > 20).toBe(true)
			end
			-- quay ladders and steps: any spot on the quay strip keeps 9 studs along X from them
			if math.abs(s.pos.Z - Harbour.QUAY_FACE_Z) < 6 then
				for i = 1, #Harbour.QUAY do
					local c = string.sub(Harbour.QUAY, i, i)
					if c == "L" or c == "T" then
						t.expect(math.abs(s.pos.X - Harbour.quaySlotX(i)) >= 9).toBe(true)
					end
				end
			end
		end
	end)

	t.test(
		"fishing slots are straight quay with straight neighbours, off the gangways and pier",
		function()
			t.expect(Plan.QUAY_X0).toBe(Harbour.QUAY_X0)
			t.expect(Plan.QUAY_GRID).toBe(Harbour.GRID)
			t.expect(Plan.QUAY_FACE_Z).toBe(Harbour.QUAY_FACE_Z)
			t.expect(Plan.QUAY_SLOTS).toBe(Harbour.QUAY_SLOTS)
			local reserved = {
				[1] = true,
				[2] = true,
				[3] = true,
				[7] = true,
				[8] = true,
				[9] = true,
				[35] = true,
			}
			for _, slot in Plan.FISH_SLOTS do
				t.expect(reserved[slot]).toBeNil()
				for i = slot - 1, slot + 1 do
					t.expect(string.sub(Harbour.QUAY, i, i)).toBe("S")
				end
			end
		end
	)

	t.test(
		"beach families stand landward of the waterline, clear of the lifeguard tower",
		function()
			local tower = Vector3.zero
			for _, p in WorldConfig.Points do
				if p.id == "HavenSandsTower" then
					tower = p.position
				end
			end
			local n = 0
			for _, s in Plan.spots() do
				if s.zone == "beach" then
					n += 1
					t.expect(Vector3.new(s.pos.X - tower.X, 0, s.pos.Z - tower.Z).Magnitude > 20)
						.toBe(true)
				end
			end
			t.expect(n >= 6).toBe(true)
		end
	)

	t.test("keep is stable and follows the share", function()
		local kept = 0
		for i = 1, 400 do
			t.expect(Plan.keep(i, 0)).toBe(false)
			t.expect(Plan.keep(i, 1)).toBe(true)
			if Plan.keep(i, 0.5) then
				kept += 1
			end
		end
		t.expect(kept > 150 and kept < 250).toBe(true)
	end)
end
