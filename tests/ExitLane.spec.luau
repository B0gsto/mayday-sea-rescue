-- The berth's exit lane (RingLayout.EXIT_LANE; live v33: 49 Unstick push-offs in 6 h, half by a home island): on
-- every island no collidable piece a hull or rider can meet (the plates, quay edge, streets, every building at its top
-- level, decorations, build station, bridges, the jetty and its finger and head deck, quest pontoons and boats moved
-- or not, the second barge's mooring) enters the lane, the berth heads straight down it, and the sea route out of the
-- cove leaves along it.
return function(t)
	local L = t.load("src/shared/Config/RingLayout.luau")
	local DP = t.load("src/shared/DockPieces.luau")
	local DockConfig = t.load("src/shared/Config/DockConfig.luau")
	local Marina = t.load("src/shared/Marina.luau")
	local IslandPlates = t.load("src/server/World/IslandPlates.luau")
	local Bridges = t.load("src/server/World/Bridges.luau")
	DP.scaleTo = function(m: Model, s: number) -- Model:ScaleTo round its WorldPivot (as tests/ZFight.spec.luau)
		local pivot = m.WorldPivot
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				local rel = pivot:ToObjectSpace(d.CFrame)
				d.CFrame = pivot * (rel - rel.Position + rel.Position * s)
				d.Size *= s
			end
		end
	end

	local REACH = 12 -- studs above sea level a hull or its rider can touch (bridge decks clear 19+)
	local BARGE = Vector2.new(16, 37) -- M_Veh_SupplyBarge's beam x length (its RESULT.md bbox)

	-- island-frame AABB { r0, r1, f0, f1, lowest Y } of a box (all 8 corners: pitched slipways and the ramp wedge)
	local function footprint(isl: any, cf: CFrame, size: Vector3): { number }
		local r0, r1, f0, f1, y0 = math.huge, -math.huge, math.huge, -math.huge, math.huge
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local w = cf * (size * Vector3.new(sx, sy, sz) / 2)
					local l = isl.frame:PointToObjectSpace(w)
					y0 = math.min(y0, w.Y)
					r0, r1 = math.min(r0, l.X), math.max(r1, l.X)
					f0, f1 = math.min(f0, -l.Z), math.max(f1, -l.Z)
				end
			end
		end
		return { r0, r1, f0, f1, y0 }
	end
	local function intrudes(a: { number }): { number }?
		for _, r in L.EXIT_LANE do
			if a[1] < r[2] and a[2] > r[1] and a[3] < r[4] and a[4] > r[3] then
				return r
			end
		end
		return nil
	end
	local function rect(r: { number }): string
		return `r {math.floor(r[1])}..{math.floor(r[2])} fwd {math.floor(r[3])}..{math.floor(r[4])}`
	end

	t.test(
		"the lane is wide, starts at the berth's bow and runs out past the sea plates and the ramp",
		function()
			local slot, lane = L.EXIT_LANE[1], L.EXIT_LANE[2]
			t.expect(lane[2] - lane[1] >= 80).toBe(true)
			t.expect(lane[4] >= 560).toBe(true) -- open sea: past the plates (424) and the ramp (484)
			local isl = L.Islands[1]
			local b = isl.frame:PointToObjectSpace(isl.berths.Boat.Position)
			t.expect(-b.Z >= slot[3] and -b.Z <= slot[4] and b.X > slot[1] and b.X < slot[2])
				.toBe(true)
			t.expect(slot[4] >= lane[3]).toBe(true) -- the two rects join
		end
	)

	t.test("berths and home spawns point straight down the lane", function()
		for i, isl in L.Islands do
			local berth = isl.berths.Boat
			t.expect(berth.LookVector:Dot(isl.facing) > 0.9999).toBe(true)
			t.expect(Marina.berth(i).LookVector:Dot(isl.facing) > 0.9999).toBe(true)
			local f = L.laneFacing(berth.Position.X, berth.Position.Z)
			t.expect(f ~= nil and f:Dot(isl.facing) > 0.9999).toBe(true)
			local out = berth.Position + isl.facing * 200 -- 200 down the lane: still in it
			t.expect(L.laneFacing(out.X, out.Z) == isl.facing).toBe(true)
		end
		t.expect(L.laneFacing(L.Center.X, L.Center.Z)).toBeNil() -- the lagoon is no lane
	end)

	t.test("the sea route from the berth leaves down the lane", function()
		for _, isl in L.Islands do
			local berth = isl.berths.Boat.Position
			for _, far in { { -900, -200 }, { 900, -200 }, { 0, -1200 }, { -400, 900 } } do
				local p = (isl.frame * CFrame.new(far[1], 0, -far[2])).Position
				local leg = L.seaRoute(berth, Vector3.new(p.X, 0, p.Z))
				local l = isl.frame:PointToObjectSpace(Vector3.new(leg.X, L.PlateauY, leg.Z))
				if not intrudes({ l.X, l.X, -l.Z, -l.Z }) then
					error(
						`{isl.id} route to {far[1]}, {far[2]} first steers to r {l.X} fwd {-l.Z}, off the lane`
					)
				end
			end
		end
	end)

	t.test("no collidable piece enters any island's exit lane", function()
		local world = Instance.new("Folder")
		IslandPlates.place(world)
		Bridges.place(world)
		local roots: { { isl: any, root: Instance } } = {}
		for i, isl in L.Islands do
			local b = Marina.berth(i)
			local m = Instance.new("Folder")
			DP.base(b).Parent = m
			DP.streets(b).Parent = m
			for _, key in DockConfig.BUILDINGS do
				local def = DockConfig.Buildings[key]
				DP.building(key, b, if def then #def.levels else nil).Parent = m
			end
			for key in DockConfig.Blueprints do
				DP.building(key, b).Parent = m
			end
			for key in DockConfig.Decorations do
				DP.decoration(key, b).Parent = m
			end
			DP.buildStation(b).Parent = m
			table.insert(roots, { isl = isl, root = m })
		end
		local bad = {}
		local function check(isl: any, name: string, box: { number })
			local r = intrudes(box)
			if r then
				table.insert(bad, `{isl.id} {name} at {rect(box)} enters {rect(r)}`)
			end
		end
		local function scan(isl: any, root: Instance)
			for _, d in root:GetDescendants() do
				if d:IsA("BasePart") and d.CanCollide then
					local box = footprint(isl, d.CFrame, d.Size)
					if box[5] < REACH then
						check(isl, `{d.Parent and d.Parent.Name}.{d.Name}`, box)
					end
				end
			end
		end
		for _, isl in L.Islands do
			scan(isl, world) -- every plate and bridge, against this island's lane
		end
		for _, e in roots do
			scan(e.isl, e.root)
		end
		for i, isl in L.Islands do
			local b = Marina.berth(i)
			-- DockService's jetty (its lot, run on to the quay wall), the finger beside the berth, the head deck
			local J, jcf = Marina.LOTS.Jetty, b * Marina.LOTS.Jetty.cf
			check(
				isl,
				"Jetty",
				footprint(isl, jcf * CFrame.new(0, 0, 2), Vector3.new(J.size.X, 1, J.size.Y + 4))
			)
			local j = Marina.JETTY
			check(
				isl,
				"Finger",
				footprint(
					isl,
					b * CFrame.new((j.x0 + j.x1) / 2, 0, (j.z1 + j.out) / 2),
					Vector3.new(j.x1 - j.x0 + 1.2, 1, j.z1 - j.out + 1.2) -- its pilings stand 0.6 in from the edge
				)
			)
			local H = DockConfig.JETTY_HEAD
			check(
				isl,
				"JettyHead",
				footprint(
					isl,
					jcf * CFrame.new(H.offset.X, 0, H.offset.Y),
					Vector3.new(H.size.X, 1, H.size.Y)
				)
			)
			-- the quest pontoon and its boats, at home and moved out with the Ramp Wharf
			for _, shift in { Vector2.zero, L.QUEST_SHIFT } do
				local s = isl.frame.RightVector * shift.X + isl.frame.LookVector * shift.Y
				local Q = L.QUEST_PONTOON
				check(
					isl,
					"QuestPontoon",
					footprint(isl, isl.quest.pontoon + s, Vector3.new(Q.X, 2, Q.Y))
				)
				for k, slot in isl.quest.slots do
					check(isl, `QuestBoat{k}`, footprint(isl, slot + s, Vector3.new(10, 4, 24)))
				end
			end
			-- the second barge moored along the Freight Wharf (DepotController: mark * 180 deg, beam X, length Z)
			local wharf = DP.building("SeaPlate2", b)
			for _, a in wharf:GetDescendants() do
				if a:IsA("Attachment") and a.Name == "ATT_BargeMoor" then
					local moor = (a.Parent :: BasePart).CFrame
						* a.CFrame
						* CFrame.Angles(0, math.pi, 0)
					local barge = footprint(isl, moor, Vector3.new(BARGE.X, 4, BARGE.Y))
					check(isl, "Barge", barge)
					local station = L.STATION_RECT -- its deck stands clear of the moored barge
					t.expect(
						barge[2] <= station[1]
							or barge[1] >= station[2]
							or barge[4] <= station[3]
							or barge[3] >= station[4]
					).toBe(true)
				end
			end
		end
		if #bad > 0 then
			for k = 1, math.min(#bad, 40) do
				print("  " .. bad[k])
			end
		end
		t.expect(#bad).toBe(0)
	end)
end
