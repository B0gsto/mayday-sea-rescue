-- DockBuild (docs/23 (j) rule 4, WP-14d): the top-down camera frames the island from the bridge side; every
-- catalog card has a spot and footprint; the decor is a Cash-only ladder on the spare lots, and the build
-- station stands inside Spare3.
return function(t)
	local B = t.load("src/shared/DockBuild.luau")
	local DB = t.load("src/shared/DockBlueprints.luau")
	local D = t.load("src/shared/Config/DockConfig.luau")
	local M = t.load("src/shared/Marina.luau")

	local frame = M.berth(1)
	local centre = (frame * M.ISLAND).Position

	t.test("camera sits inland, above the island, looking out to sea", function()
		local cam = B.camera(frame, B.ISLAND_RADIUS, 16 / 9, nil)
		local offset = cam.Position - centre
		t.expect(offset.Y > 0).toBe(true)
		t.expect(offset:Dot(frame.LookVector) < 0).toBe(true)
		t.expect(cam.LookVector:Dot(frame.LookVector) > 0).toBe(true)
		local d = offset.Magnitude
		local pitch = math.asin(offset.Y / d)
		t.expect(math.abs(pitch - B.PITCH) < 0.01).toBe(true)
	end)

	t.test("the view fits the island, and a narrow viewport backs off further", function()
		local wide = B.distance(B.ISLAND_RADIUS, 16 / 9)
		local narrow = B.distance(B.ISLAND_RADIUS, 0.5)
		t.expect(narrow > wide).toBe(true)
		local vf = math.tan(math.rad(B.FOV) / 2)
		t.expect(wide * vf >= B.ISLAND_RADIUS).toBe(true)
		local hf = vf * (16 / 9)
		t.expect(wide * math.min(vf, hf) >= B.ISLAND_RADIUS).toBe(true)
	end)

	t.test("aiming at a card's spot only turns the view, it does not move the camera", function()
		local spot = (frame * M.LOTS.Station.cf).Position
		local plain = B.camera(frame, B.ISLAND_RADIUS, 16 / 9, nil)
		local aimed = B.camera(frame, B.ISLAND_RADIUS, 16 / 9, spot)
		t.expect((plain.Position - aimed.Position).Magnitude < 1e-3).toBe(true)
		t.expect((plain.LookVector - aimed.LookVector).Magnitude > 1e-3).toBe(true)
	end)

	t.test(
		"free share: the island centre sits in the middle of the area left of the list",
		function()
			local cam = B.camera(frame, B.ISLAND_RADIUS, 16 / 9, nil, 0.6)
			local rel = cam:PointToObjectSpace(centre)
			local vf = math.tan(math.rad(B.FOV) / 2)
			local ndcX = rel.X / (-rel.Z * vf * 16 / 9)
			t.expect(ndcX).toBeCloseTo(-0.4, 2)
			local plain = B.camera(frame, B.ISLAND_RADIUS, 16 / 9, nil)
			t.expect((cam.Position - centre).Magnitude > (plain.Position - centre).Magnitude)
				.toBe(true)
		end
	)

	t.test("bottom band: the island centre moves into the visible area above it", function()
		local vf = math.tan(math.rad(B.FOV) / 2)
		local plain = B.camera(frame, B.ISLAND_RADIUS, 16 / 9, nil)
		local cam = B.camera(frame, B.ISLAND_RADIUS, 16 / 9, nil, nil, 0.45)
		local rel = cam:PointToObjectSpace(centre)
		t.expect(rel.Y / (-rel.Z * vf)).toBeCloseTo(0.45, 2)
		t.expect((cam.Position - centre).Magnitude > (plain.Position - centre).Magnitude).toBe(true)
		-- the focus view is raised to the same visible middle
		local spot = (frame * M.LOTS.Spare3.cf).Position
		local focus = B.focus(frame, spot, Vector2.new(7, 7), 16 / 9, nil, 0.45)
		local frel = focus:PointToObjectSpace(spot)
		t.expect(frel.Y / (-frel.Z * vf)).toBeCloseTo(0.45, 2)
	end)

	t.test("every catalog item has a lot spot and a footprint", function()
		local items = DB.catalog()
		t.expect(#items > 0).toBe(true)
		for _, item in items do
			local cf, size = B.spot(item)
			t.expect(cf ~= nil).toBe(true)
			t.expect(size.X > 0 and size.Y > 0).toBe(true)
		end
	end)

	t.test("decor is a Cash-only ladder from 2k to 40k on the spare lots", function()
		t.expect(#D.DECOR).toBe(6)
		local last = 0
		for _, key in D.DECOR do
			local d = D.Decorations[key]
			t.expect(d.cash >= 2000 and d.cash <= 40000).toBe(true)
			t.expect(d.cash > last).toBe(true)
			last = d.cash
			t.expect(D.canBuyDecor(key, false, d.cash - 1)).toBe(false)
			local ok, reason = D.canBuyDecor(key, false, d.cash - 1)
			t.expect(reason).toBe("Cash")
			ok, reason = D.canBuyDecor(key, true, 1e9)
			t.expect(ok).toBe(false)
			t.expect(reason).toBe("Owned")
			t.expect(D.canBuyDecor(key, false, d.cash)).toBe(true)
		end
	end)

	t.test("decor and the build station stay inside their lots", function()
		local seen = {}
		for _, key in D.DECOR do
			local d = D.Decorations[key]
			local lot = M.LOTS[d.lot]
			t.expect(lot ~= nil).toBe(true)
			local spot = D.decorSpot(key, frame)
			t.expect(spot ~= nil).toBe(true)
			local localCf = lot.cf:Inverse() * (frame:Inverse() * (spot :: CFrame))
			t.expect(math.abs(localCf.X) + d.size.X / 2 <= lot.size.X / 2 + 1e-3).toBe(true)
			t.expect(math.abs(localCf.Z) + d.size.Y / 2 <= lot.size.Y / 2 + 1e-3).toBe(true)
			local tag = d.lot .. tostring(d.offset)
			t.expect(seen[tag]).toBeNil()
			seen[tag] = true
		end
		local st = D.BUILD_STATION
		local lot = M.LOTS[st.lot]
		local station = D.stationSpot(frame)
		local localCf = lot.cf:Inverse() * (frame:Inverse() * station)
		t.expect(math.abs(localCf.X) + st.size.X / 2 <= lot.size.X / 2 + 1e-3).toBe(true)
		t.expect(math.abs(localCf.Z) + st.size.Y / 2 <= lot.size.Y / 2 + 1e-3).toBe(true)
	end)

	t.test(
		"WP-14e: a paper blueprint lies just above its lot, turned to the berth frame",
		function()
			for _, item in DB.catalog() do
				local cf, size = B.paper(item, frame)
				local spot, raw = B.spot(item)
				local want = (frame * spot).Position + Vector3.new(0, B.PAPER_LIFT, 0)
				t.expect((cf.Position - want).Magnitude < 1e-3).toBe(true)
				t.expect(cf.LookVector:Dot(frame.LookVector) > 0.999).toBe(true)
				t.expect(math.abs(size.X * size.Y - raw.X * raw.Y) < 1e-3).toBe(true)
			end
			-- the boathouse lot is turned 90 degrees: its footprint swaps
			local _, raw = B.spot({ kind = "Building", key = "Boathouse" })
			local _, size = B.paper({ kind = "Building", key = "Boathouse" }, frame)
			t.expect(size.X).toBe(raw.Y)
		end
	)

	t.test(
		"WP-14e: the focus view keeps the pitch, comes closer and sets the spot left of centre",
		function()
			local spot = (frame * M.LOTS.Spare3.cf).Position
			local island = B.camera(frame, B.ISLAND_RADIUS, 16 / 9, nil)
			local cam = B.focus(frame, spot, Vector2.new(7, 7), 16 / 9)
			t.expect((cam.Position - spot).Magnitude < (island.Position - centre).Magnitude)
				.toBe(true)
			t.expect((cam.Position - spot).Magnitude >= B.FOCUS_MIN).toBe(true)
			t.expect(math.abs(math.asin(-cam.LookVector.Y) - B.PITCH) < 0.01).toBe(true)
			local rel = cam:PointToObjectSpace(spot)
			t.expect(rel.Z < 0).toBe(true) -- in front
			t.expect(rel.X < 0).toBe(true) -- left of the right-hand list
			t.expect(rel.Y > 0).toBe(true) -- above the bottom strip
			local big = B.focus(frame, spot, Vector2.new(60, 44), 16 / 9)
			t.expect((big.Position - spot).Magnitude > (cam.Position - spot).Magnitude).toBe(true)
		end
	)
end
