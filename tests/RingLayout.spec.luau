-- RingLayout (docs/23 (p), WP-24, WP-27): the ring geometry, every lot on its island's Lego plate (built from Parts
-- by src/server/World/IslandPlates.luau, a U cut-out over the berth cove) and clear of the others, deep water round
-- the plate and in the cove with a clear route out, the quest pontoon, neighbour bridges high enough for boats.
return function(t)
	local L = t.load("src/shared/Config/RingLayout.luau")
	local fs = t.lune("fs")
	local meta = t.lune("serde")
		.decode("json", fs.readFile(`{t.gameDir}/map/generated/terrain.json`))
	local raw = fs.readFile(`{t.gameDir}/map/generated/{meta.height}`)
	local RENDER_BIAS = 2 -- terrain renders this far over the baked height (tools/world/layout.py RENDER_BIAS)
	local function ground(p: Vector3): number -- the rendered surface Y (nearest bake sample)
		local ix = math.floor((p.X - meta.originX) / meta.cell + 0.5)
		local iz = math.floor((p.Z - meta.originZ) / meta.cell + 0.5)
		assert(
			ix >= 0 and ix < meta.nx and iz >= 0 and iz < meta.nz,
			`({p.X}, {p.Z}) is outside the main bake`
		)
		return string.unpack("<i2", raw, (iz * meta.nx + ix) * 2 + 1) / meta.heightScale
			+ RENDER_BIAS
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
	local WATER = { SubPen = true, Jetty = true }
	local PLATE = L.IslandPlate

	t.test(
		"six islands in a tight ring round an open lagoon, 60 degrees apart, 80 studs apart",
		function()
			t.expect(#L.Islands).toBe(6)
			t.expect(#L.Bridges).toBe(6)
			t.expect(ground(L.Center) < -30).toBe(true) -- no island in the middle
			for i, isl in L.Islands do
				t.expect(isl.id).toBe(`Plot{i}`)
				t.expect((isl.center - L.Center).Magnitude).toBeCloseTo(L.Ring, 1)
				local nxt = L.Islands[i % 6 + 1]
				t.expect(math.deg(math.acos(isl.facing:Dot(nxt.facing)))).toBeCloseTo(60, 1e-3)
				t.expect(L.byId[isl.id]).toBe(isl)
				-- the nearest corners of neighbouring plates: ~80 studs of water
				local gap = math.huge
				for _, c in
					{
						{ PLATE.edge, -(PLATE.edge - PLATE.chamfer) },
						{ PLATE.edge - PLATE.chamfer, -PLATE.edge },
					}
				do
					for _, sx in { -1, 1 } do
						local p = (isl.frame * CFrame.new(sx * c[1], 0, -c[2])).Position
						for _, d in
							{
								{ PLATE.edge, -(PLATE.edge - PLATE.chamfer) },
								{ PLATE.edge - PLATE.chamfer, -PLATE.edge },
							}
						do
							for _, dx in { -1, 1 } do
								local q = (nxt.frame * CFrame.new(dx * d[1], 0, -d[2])).Position
								gap = math.min(gap, (p - q).Magnitude)
							end
						end
					end
				end
				t.expect(gap > 70 and gap < 95).toBe(true)
			end
		end
	)

	t.test(
		"the quest pontoon reaches out to sea; its boats moor in deep water clear of the berth's way out",
		function()
			for _, isl in L.Islands do
				local q = isl.quest
				local len = L.QUEST_PONTOON.Y
				local root = q.pontoon * CFrame.new(0, 0, len / 2 - 2)
				local l = isl.frame:PointToObjectSpace(
					Vector3.new(root.Position.X, PLATE.topY, root.Position.Z)
				)
				t.expect(L.plateContains(l.X, -l.Z) == false).toBe(true) -- off the plate, right at its edge
				t.expect(math.abs(-l.Z - PLATE.edge) < 4).toBe(true)
				t.expect(q.pontoon.LookVector:Dot(isl.facing) > 0.99).toBe(true)
				t.expect(#q.slots).toBe(3)
				for _, s in q.slots do
					t.expect(s.Position.Y).toBe(0)
					t.expect(s.LookVector:Dot(isl.facing) < -0.99).toBe(true) -- bow to the plate
					t.expect(ground(s.Position) < -8).toBe(true)
					local sl = isl.frame:PointToObjectSpace(
						Vector3.new(s.Position.X, PLATE.topY, s.Position.Z)
					)
					t.expect(L.plateContains(sl.X, -sl.Z - 7) == false).toBe(true) -- the bow is off the plate
					local berth = isl.frame:PointToObjectSpace(isl.berths.Boat.Position)
					t.expect(math.abs(sl.X - berth.X) > 40).toBe(true) -- clear of the berth's run out
				end
				local tab = isl.lots.QuestTablet.cframe.Position
				t.expect((tab - q.pontoon.Position).Magnitude < 40).toBe(true)
			end
		end
	)

	t.test(
		"island lots: on the plate (or in its cove water), apart, the helipad's rotor circle clear",
		function()
			for _, isl in L.Islands do
				for name, lot in isl.lots do
					for _, c in corners(lot) do
						if WATER[name] then
							local l =
								isl.frame:PointToObjectSpace(Vector3.new(c.X, PLATE.topY, c.Z))
							if L.plateContains(l.X, -l.Z) then
								error(
									`{isl.id} {name} corner ({c.X}, {c.Z}) stands on the plate, not in the cove water`
								)
							end
							local y = ground(c)
							if y > -4 then
								error(
									`{isl.id} {name} cove corner ({c.X}, {c.Z}) is only Y {y} deep`
								)
							end
						elseif not L.onPlate(isl, c.X, c.Z) then
							error(`{isl.id} {name} corner ({c.X}, {c.Z}) is off the plate`)
						end
					end
				end
				if not L.onPlate(isl, isl.spawn.Position.X, isl.spawn.Position.Z) then
					error(`{isl.id} spawn is off the plate`)
				end
				local names = {}
				for name in isl.lots do
					table.insert(names, name)
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
			end
		end
	)

	t.test(
		"the plates: chunky 320-stud squares, 2 studs thick, the berth notch open, deep water all round",
		function()
			t.expect(PLATE.topY).toBe(L.PlateauY)
			t.expect(PLATE.thick).toBe(2)
			t.expect(PLATE.edge).toBe(L.IslandRadius)
			t.expect(PLATE.notch.halfWidth).toBe(L.Notch.island.halfWidth)
			t.expect(PLATE.notch.head).toBe(L.Notch.island.head)
			for a, r in PLATE.rects do
				t.expect(
					r[1] >= -PLATE.edge
						and r[2] <= PLATE.edge
						and r[3] >= -PLATE.edge
						and r[4] <= PLATE.edge
				).toBe(true)
				for b = a + 1, #PLATE.rects do
					local o = PLATE.rects[b]
					if r[1] < o[2] and o[1] < r[2] and r[3] < o[4] and o[3] < r[4] then
						error(`plate rects {a} and {b} overlap`)
					end
				end
			end
			-- the U cut-out is open water: the mouth, the middle and the head's approach
			for _, fwd in
				{ PLATE.notch.head + 1, (PLATE.notch.head + PLATE.edge) / 2, PLATE.edge - 1 }
			do
				t.expect(L.plateContains(0, fwd)).toBe(false)
				t.expect(L.plateContains(PLATE.notch.halfWidth - 1, fwd)).toBe(false)
			end
			t.expect(L.plateContains(0, PLATE.notch.head - 1)).toBe(true) -- the quay at the head
			t.expect(L.plateContains(PLATE.notch.halfWidth + 1, PLATE.edge - 1)).toBe(true) -- the wing beside the mouth
			for _, isl in L.Islands do
				for _, o in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
					local p = isl.center
						+ (isl.frame.RightVector * o[1] + isl.facing * o[2]) * (PLATE.edge + 40)
					local y = ground(p)
					if y > -22 then
						error(
							`{isl.id} plate edge is only Y {y} deep at ({math.floor(p.X)}, {math.floor(
								p.Z
							)})`
						)
					end
				end
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
		"bridges: a full ring of neighbours, both ends on the plates, a gentle climb, boats pass under",
		function()
			for i, br in L.Bridges do
				local a, b = L.byId[br.a], L.byId[br.b]
				t.expect(a.index).toBe(i)
				t.expect(b.index).toBe(i % 6 + 1)
				t.expect(L.onPlate(a, br.from.X, br.from.Z)).toBe(true)
				t.expect(L.onPlate(b, br.to.X, br.to.Z)).toBe(true)
				t.expect(L.deckY(br, 0)).toBeCloseTo(PLATE.topY, 1e-3)
				t.expect(L.deckY(br, 1)).toBeCloseTo(PLATE.topY, 1e-3)
				t.expect(L.deckY(br, 0.5) - 1.2 >= 19).toBe(true) -- underside at the crest
				local steep, water = 0, 0
				for k = 0, 200 do
					local p = L.deckAt(br, k / 200)
					local onA, onB = L.onPlate(a, p.X, p.Z), L.onPlate(b, p.X, p.Z)
					if not (onA or onB) then
						water += 1
						if ground(p) > -20 then
							error(`{br.id} crosses shallow water at t = {k / 200}`)
						end
					end
					for _, isl in { a, b } do -- never over a lot
						for name, lot in isl.lots do
							local o = lot.cframe:PointToObjectSpace(
								Vector3.new(p.X, lot.cframe.Position.Y, p.Z)
							)
							if
								math.abs(o.X) < lot.size.X / 2 + br.width / 2
								and math.abs(o.Z) < lot.size.Y / 2 + br.width / 2
							then
								error(`{br.id} runs over {isl.id} {name}`)
							end
						end
					end
					if k > 0 then
						local q = L.deckAt(br, (k - 1) / 200)
						local run = Vector3.new(p.X - q.X, 0, p.Z - q.Z).Magnitude
						steep = math.max(steep, math.deg(math.atan(math.abs(p.Y - q.Y) / run)))
					end
				end
				t.expect(steep <= 12).toBe(true) -- a gentle walk
				local span = water / 200 * (br.to - br.from).Magnitude
				if span < 70 or span > 110 then
					error(`{br.id} spans {span} studs of water`)
				end
			end
		end
	)
	t.test(
		"seaRoute: the home pin leads round the plate and in through the cove mouth, never over land",
		function()
			local function onLand(
				p: Vector3
			): string? -- on the plate or within 8 studs (trim skirt, bridge piers)
				for _, isl in L.Islands do
					for _, o in { { 0, 0 }, { 8, 0 }, { -8, 0 }, { 0, 8 }, { 0, -8 } } do
						if L.onPlate(isl, p.X + o[1], p.Z + o[2]) then
							return isl.id
						end
					end
				end
				return nil
			end
			for k, isl in L.Islands do
				local berth = isl.berths.Boat.Position
				local right = isl.frame.RightVector
				local nxt = L.Islands[k % #L.Islands + 1]
				local starts = {
					isl.center - isl.facing * 230, -- the lagoon, behind the island
					isl.center + right * 260, -- beside it
					isl.center - right * 260,
					isl.center + isl.facing * 420 + right * 320, -- out at sea, off the mouth's line
					nxt.berths.Boat.Position, -- a neighbour's berth
				}
				for _, s0 in starts do
					local p = Vector3.new(s0.X, 0, s0.Z)
					t.expect(onLand(p)).toBe(nil)
					local leg0, len = L.seaRoute(p, berth)
					t.expect(len >= (Vector3.new(berth.X, 0, berth.Z) - p).Magnitude - 1e-6)
						.toBe(true)
					local steps = 0
					while (Vector3.new(berth.X, 0, berth.Z) - p).Magnitude > 4 do
						local leg = L.seaRoute(p, berth)
						local d = Vector3.new(leg.X - p.X, 0, leg.Z - p.Z)
						p += if d.Magnitude > 4 then d.Unit * 4 else d
						local land = onLand(p)
						if land then
							error(`{isl.id}: the route from {s0} runs over {land} at {p}`)
						end
						steps += 1
						if steps > 1000 then
							error(`{isl.id}: no way home from {s0}`)
						end
					end
					t.expect(leg0 ~= berth or (s0 - isl.center):Dot(isl.facing) > 0).toBe(true)
				end
				-- straight in through the mouth: the pin is the berth itself
				local front = isl.center + isl.facing * 400
				t.expect(L.seaRoute(Vector3.new(front.X, 0, front.Z), berth)).toBe(berth)
			end
		end
	)
end
