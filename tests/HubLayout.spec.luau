-- HubLayout (docs/23 (k), WP-18): the ring geometry, every lot on its island's plateau in the terrain bake and
-- clear of the others, berths in deep water with a clear route out, bridges landing on land and arched high enough.
return function(t)
	local L = t.load("src/shared/Config/HubLayout.luau")
	local fs = t.lune("fs")
	local meta = t.lune("serde")
		.decode("json", fs.readFile(`{t.gameDir}/map/generated/terrain.json`))
	local raw = fs.readFile(`{t.gameDir}/map/generated/{meta.height}`)
	local function ground(p: Vector3): number -- the bake's surface Y (nearest sample)
		local ix = math.floor((p.X - meta.originX) / meta.cell + 0.5)
		local iz = math.floor((p.Z - meta.originZ) / meta.cell + 0.5)
		assert(
			ix >= 0 and ix < meta.nx and iz >= 0 and iz < meta.nz,
			`({p.X}, {p.Z}) is outside the main bake`
		)
		return string.unpack("<i2", raw, (iz * meta.nx + ix) * 2 + 1) / meta.heightScale
	end
	local function corners(lot: any): { Vector3 }
		local w, d = lot.size.X / 2, lot.size.Y / 2
		local out = {}
		for _, o in { { -w, -d }, { w, -d }, { -w, d }, { w, d } } do
			table.insert(out, (lot.cframe * CFrame.new(o[1], 0, o[2])).Position)
		end
		return out
	end
	-- footprint as an axis-aligned box in a frame (lots are turned in 90 degree steps)
	local function box(frame: CFrame, lot: any): (number, number, number, number)
		local x0, z0, x1, z1 = math.huge, math.huge, -math.huge, -math.huge
		for _, c in corners(lot) do
			local l = frame:PointToObjectSpace(c)
			x0, z0, x1, z1 =
				math.min(x0, l.X), math.min(z0, l.Z), math.max(x1, l.X), math.max(z1, l.Z)
		end
		return x0, z0, x1, z1
	end
	local WATER = { SubPen = true, Jetty = true, BlueprintTable = true }

	t.test("six islands 900 studs out, 60 degrees apart, one bridge each", function()
		t.expect(#L.Islands).toBe(6)
		t.expect(#L.Bridges).toBe(6)
		for i, isl in L.Islands do
			t.expect(isl.id).toBe(`Plot{i}`)
			t.expect((isl.center - L.Hub.center).Magnitude).toBeCloseTo(900, 1)
			local nxt = L.Islands[i % 6 + 1]
			t.expect(math.deg(math.acos(isl.facing:Dot(nxt.facing)))).toBeCloseTo(60, 1e-3)
			t.expect(L.byId[isl.id]).toBe(isl)
			t.expect(isl.bridge.island).toBe(isl.id)
		end
	end)

	t.test("hub lots and spawn stand on the hub plateau; the drop-off is in its harbour", function()
		for name, lot in L.Hub.lots do
			for _, c in corners(lot) do
				if math.abs(ground(c) - L.PlateauY) > 2.5 then
					error(`hub {name} corner over ground Y {ground(c)}`)
				end
			end
		end
		t.expect(math.abs(ground(L.Hub.spawn.Position) - L.PlateauY) < 2.5).toBe(true)
		t.expect(ground(L.Hub.dropOff) < -8).toBe(true)
	end)

	t.test(
		"island lots: on the plateau (or in the cove), apart, the helipad's rotor circle clear",
		function()
			for _, isl in L.Islands do
				for name, lot in isl.lots do
					for _, c in corners(lot) do
						local y = ground(c)
						local ok = if WATER[name]
							then y < -4
							elseif name == "LifeguardTower" then y > 0.5
							else math.abs(y - L.PlateauY) < 2.5
						if not ok then
							error(`{isl.id} {name} corner ({c.X}, {c.Z}) over ground Y {y}`)
						end
					end
				end
				t.expect(math.abs(ground(isl.spawn.Position) - L.PlateauY) < 2.5).toBe(true)
				local names = {}
				for name in isl.lots do
					if name ~= "BlueprintTable" then -- it stands on the jetty
						table.insert(names, name)
					end
				end
				for a = 1, #names do
					for b = a + 1, #names do
						local ax0, az0, ax1, az1 = box(isl.frame, isl.lots[names[a]])
						local bx0, bz0, bx1, bz1 = box(isl.frame, isl.lots[names[b]])
						if ax0 < bx1 and bx0 < ax1 and az0 < bz1 and bz0 < az1 then
							error(`{isl.id} {names[a]} overlaps {names[b]}`)
						end
					end
				end
				local pad = isl.lots.Helipad
				for _, name in names do
					if name ~= "Helipad" then
						local x0, z0, x1, z1 = box(pad.cframe, isl.lots[name])
						local dx, dz = math.max(x0, 0, -x1), math.max(z0, 0, -z1)
						if math.sqrt(dx * dx + dz * dz) < pad.clearRadius then
							error(`{isl.id} {name} inside the helipad rotor circle`)
						end
					end
				end
				local _, tz0, _, tz1 = box(isl.lots.Jetty.cframe, isl.lots.BlueprintTable)
				t.expect(math.abs(tz0) < 35 and math.abs(tz1) < 35).toBe(true) -- the table is on the jetty
			end
		end
	)

	t.test("berths float in deep water with a straight run out to sea", function()
		for _, isl in L.Islands do
			for name, berth in isl.berths do
				t.expect(berth.Position.Y).toBe(0)
				for _, o in
					{
						Vector3.zero,
						Vector3.new(9, 0, 0),
						Vector3.new(-9, 0, 0),
						Vector3.new(0, 0, 26),
					}
				do
					local y = ground((berth * CFrame.new(o)).Position)
					if y > -8 then
						error(`{isl.id} {name} berth over ground Y {y}`)
					end
				end
			end
			local b = isl.berths.Boat
			for s = 0, 200, 8 do
				local y = ground(b.Position + b.LookVector * s)
				if y > -6 then
					error(`{isl.id} route out blocked {s} studs from the berth: ground Y {y}`)
				end
			end
		end
	end)

	t.test(
		"bridges: both ends on the plateau, towers on land, arched high over the water",
		function()
			for _, br in L.Bridges do
				t.expect(math.abs(ground(br.from) - L.PlateauY) < 2.5).toBe(true)
				t.expect(math.abs(ground(br.to) - L.PlateauY) < 2.5).toBe(true)
				t.expect(L.deckY(br, 0)).toBe(L.PlateauY)
				for _, tw in br.towers do
					t.expect(ground(tw) > 0).toBe(true)
				end
				t.expect(L.deckY(br, 0.5) - 1.2 >= 35).toBe(true) -- underside at the arch top
				local steep = 0
				for k = 0, 200 do
					local p = L.deckAt(br, k / 200)
					if ground(p) < -4 and p.Y - 1.2 < 18 then -- navigable water: room for every boat
						error(`{br.id} only {p.Y - 1.2} studs over water at t = {k / 200}`)
					end
					if k > 0 then
						local q = L.deckAt(br, (k - 1) / 200)
						local run = Vector3.new(p.X - q.X, 0, p.Z - q.Z).Magnitude
						steep = math.max(steep, math.deg(math.atan(math.abs(p.Y - q.Y) / run)))
					end
				end
				t.expect(steep < 13).toBe(true) -- a gentle walk
				t.expect(br.cableLowY > br.apexY + 4).toBe(true) -- cables clear walkers' heads
			end
		end
	)
end
