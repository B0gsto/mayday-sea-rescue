-- Harbour (RP-I1b-1): the pure harbour layout (quay run, pier, floating berths, pads, armour, props).
return function(t)
	local Harbour = t.load("src/server/World/Harbour.luau")

	local function near(a: number, b: number, eps: number?): boolean
		return math.abs(a - b) <= (eps or 1e-3)
	end

	t.test("the quay run covers x -182..187 in 9-stud slots, aligned to the pier root", function()
		t.expect(#Harbour.QUAY).toBe(Harbour.QUAY_SLOTS)
		local x0 = Harbour.QUAY_X0
		t.expect(x0 + 7 * Harbour.GRID).toBe(Harbour.PIER.west)
		t.expect(x0 + 9 * Harbour.GRID).toBe(Harbour.PIER.east)
		local covered, minX, maxX = 0, math.huge, -math.huge
		for _, p in Harbour.kitLayout() do
			if p.group == "Harbour_Quay" and p.asset ~= "M_Hbr_Ladder" then
				local w = if p.asset == "M_Hbr_QuayKit_Steps" then 18 else 9
				covered += w
				minX = math.min(minX, p.cf.Position.X - w / 2)
				maxX = math.max(maxX, p.cf.Position.X + w / 2)
				t.expect(near(p.cf.Position.Z, 4)).toBe(true)
				-- the front (local -Z, the LookVector) faces the sea (+Z)
				t.expect(near(p.cf.LookVector.Z, 1)).toBe(true)
			end
		end
		t.expect(covered).toBe(Harbour.QUAY_SLOTS * 9)
		t.expect(minX).toBe(-182)
		t.expect(maxX).toBe(187)
	end)

	t.test(
		"every ladder bay has a ladder at its pivot; the pier ends in a head at z 103",
		function()
			local bays, ladders, head = 0, 0, nil
			for _, p in Harbour.kitLayout() do
				if p.asset == "M_Hbr_QuayKit_LadderBay" then
					bays += 1
				elseif p.asset == "M_Hbr_Ladder" then
					ladders += 1
				elseif p.asset == "M_Hbr_QuayKit_Head" then
					head = p.cf.Position
				end
			end
			t.expect(bays > 4).toBe(true)
			t.expect(ladders).toBe(bays)
			t.expect(head and near(head.X, -110) and near(head.Z, 103)).toBe(true)
		end
	)

	t.test("pier faces point out (west -X, east +X) and leave the launch bays clear", function()
		for _, p in Harbour.kitLayout() do
			if
				p.group == "Harbour_Pier"
				and p.asset ~= "M_Hbr_QuayKit_Head"
				and p.asset ~= "M_Hbr_Ladder"
			then
				local front = p.cf.LookVector -- local -Z
				local x = p.cf.Position.X
				if near(x, -119) then
					t.expect(near(front.X, -1)).toBe(true)
				else
					t.expect(near(x, -101) and near(front.X, 1)).toBe(true)
				end
			end
		end
		-- Bay1..4 at x -95 (12 wide): the east face at -101 stays outside them
		t.expect(Harbour.PIER.east <= -95 - 6).toBe(true)
	end)

	t.test("the gangway roller lands on the pontoon deck at any tide", function()
		for _, tide in { -2, 0, 1.5 } do
			local deck = tide + Harbour.FREEBOARD
			local cf, rollerZ = Harbour.gangway(-124, deck)
			local roller = cf * Vector3.new(0, -0.93, 26.25)
			t.expect(near(roller.Y, deck, 1e-2)).toBe(true)
			t.expect(near(roller.Z, rollerZ, 1e-2)).toBe(true)
			local hinge = cf * Vector3.new(0, -0.06, -0.12)
			t.expect(near(hinge.Y, Harbour.QUAY_Y + Harbour.LIFT, 1e-3)).toBe(true)
		end
		local lowA = Harbour.gangwayPitch(4)
		local highA = Harbour.gangwayPitch(1)
		t.expect(lowA > highA).toBe(true) -- steeper at low water
	end)

	t.test("pontoon decks float 1.5 studs above the tide; pads sit clear alongside", function()
		for _, f in Harbour.floats(0) do
			for _, p in f.pieces do
				if string.find(p.asset, "Pontoon_") then
					t.expect(near(p.cf.Position.Y, 1.5)).toBe(true)
				end
			end
		end
		local raised = Harbour.floats(1)
		t.expect(near(raised[1].pieces[1].cf.Position.Y, 2.5)).toBe(true)
		local pads = Harbour.padFrames(0)
		local dock = pads.DropOff_Dock
		-- east edge of the pad stays west of the pontoon's D-fenders (x -124 - 3.9)
		t.expect(dock.cf.Position.X + dock.size.X / 2 < -124 - 3.9).toBe(true)
		t.expect(dock.size.Z > dock.size.X).toBe(true) -- along the pontoon (berth angle check)
		local hosp = pads.DropOff_Hospital
		t.expect(hosp.size.X > hosp.size.Z).toBe(true)
		local floats = Harbour.floats(0)
		local corner = floats[2].pieces[1].cf.Position
		t.expect(hosp.cf.Position.Z - hosp.size.Z / 2 > corner.Z + 7.2).toBe(true)
	end)

	t.test(
		"armour scales to the seabed depth, crest at quay-top level, skips the shallows",
		function()
			local run = {
				from = Vector3.new(0, 0, 0),
				to = Vector3.new(0, 0, 200),
				normal = Vector3.new(1, 0, 0),
				group = "T",
			}
			local pieces = Harbour.armourRun(run, function(_x: number, z: number): number?
				return if z < 40 then 2 else -20 -- land at the root, then 24 studs deep
			end)
			t.expect(#pieces > 3).toBe(true)
			for _, p in pieces do
				t.expect(p.cf.Position.Z > 20).toBe(true)
				t.expect(near(p.cf.Position.Y + 12 * (p.scale :: number), Harbour.CREST)).toBe(true)
				t.expect((p.scale :: number) <= 3).toBe(true)
			end
			t.expect(near(pieces[#pieces].scale :: number, 2)).toBe(true)
		end
	)

	t.test(
		"props: bollards on the coping, a lifebuoy station at least every 40 m of quay",
		function()
			local buoys = {}
			for _, p in Harbour.propLayout() do
				t.expect(p.ground).toBe(true)
				if p.asset == "M_Hbr_LifebuoyStation" and p.group == "Harbour_Quay" then
					table.insert(buoys, p.cf.Position.X)
				end
				if string.find(p.asset, "Bollard") and p.group == "Harbour_Quay" then
					t.expect(near(p.cf.Position.Z, 2.4)).toBe(true)
				end
			end
			table.sort(buoys)
			for i = 2, #buoys do
				t.expect(buoys[i] - buoys[i - 1] <= 120).toBe(true)
			end
		end
	)

	t.test("the breakwaters dog-leg to the unchanged mouth", function()
		for _, side in { -1, 1 } do
			local P = Harbour.breakwaterLine(side)
			t.expect(P[#P].X).toBe(side * 30) -- the 60-stud mouth
			-- the kit faces the basin and sits 8 studs in from the centreline, the arm's from the quay line
			local slots = Harbour.breakwaterSlots(side)
			t.expect(#slots > 50).toBe(true)
			t.expect(near(slots[1].cf.Position.Z, 4 + 4.5)).toBe(true)
			for _, s in slots do
				local p = s.cf.Position
				t.expect((Vector3.new(0, p.Y, 180) - p):Dot(s.cf.LookVector) > 0).toBe(true)
			end
		end
		t.expect(#Harbour.armourRuns()).toBe(6)
	end)

	t.test(
		"station rail: open at the gangway, pier root and steps, a gap at each ladder",
		function()
			local runs = Harbour.railRuns()
			t.expect(#runs > 0).toBe(true)
			local function covered(x: number): boolean
				for _, r in runs do
					t.expect(r.x1 > r.x0).toBe(true)
					if x > r.x0 and x < r.x1 then
						return true
					end
				end
				return false
			end
			t.expect(covered(Harbour.quaySlotX(4))).toBe(true)
			t.expect(covered(Harbour.quaySlotX(7))).toBe(false) -- dock gangway
			t.expect(covered((Harbour.PIER.west + Harbour.PIER.east) / 2)).toBe(false)
			t.expect(covered(Harbour.quaySlotX(5))).toBe(false) -- ladder top
			t.expect(covered(Harbour.quaySlotX(11))).toBe(false)
			t.expect(covered(Harbour.quaySlotX(13) + 4)).toBe(false) -- steps
		end
	)
end
