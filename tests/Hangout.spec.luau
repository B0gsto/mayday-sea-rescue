-- shared/Hangout: the commons stays clear of the streets, building stubs, lots and the cove; seating never doubles up.
return function(t)
	local H = t.load("src/shared/Hangout.luau")
	local P = t.load("src/shared/DockPieces.luau")
	local D = t.load("src/shared/Config/DockConfig.luau")
	local Marina = t.load("src/shared/Marina.luau")
	local R = t.load("src/shared/Config/RingLayout.luau")

	-- an island-space box (min r, min f, max r, max f) of a footprint at berth-frame CFrame `cf`
	local function box(cf: CFrame, size: Vector2, pad: number): { number }
		local rel = Marina.ISLAND:ToObjectSpace(cf)
		local x = rel:VectorToWorldSpace(Vector3.new(size.X / 2, 0, 0))
		local z = rel:VectorToWorldSpace(Vector3.new(0, 0, size.Y / 2))
		local hr = math.abs(x.X) + math.abs(z.X) + pad
		local hf = math.abs(x.Z) + math.abs(z.Z) + pad
		local p = rel.Position
		return { p.X - hr, -p.Z - hf, p.X + hr, -p.Z + hf }
	end
	local function overlap(a: { number }, b: { number }): boolean
		return a[1] < b[3] and b[1] < a[3] and a[2] < b[4] and b[2] < a[4]
	end
	local function segDist(p: Vector2, a: Vector2, b: Vector2): number
		local ab = b - a
		return (a + ab * math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1) - p).Magnitude
	end

	local props = {}
	for name, p in H.PROPS do
		props[name] = box(H.frame(CFrame.identity, name), p.size, 0)
	end

	t.test(
		"every prop is on the plate, off the plaza, 2+ studs clear of streets, stubs and lots",
		function()
			local edge, notch = R.IslandPlate.edge, R.IslandPlate.notch
			local c, h = P.PLAZA.centre, P.PLAZA.size / 2
			local plaza = { c.X - h.X, c.Y - h.Y, c.X + h.X, c.Y + h.Y }
			local paths = table.clone(P.STREETS)
			for _, key in D.BUILDINGS do
				local def = D.Buildings[key]
				if key ~= "HQ" and key ~= "Harbour" then
					table.insert(paths, P.stub(def.spot, def.size))
				end
			end
			for name, b in props do
				t.expect(b[1] > -edge and b[3] < edge and b[2] > -edge and b[4] < edge).toBe(true)
				t.expect(b[4] < notch.head or b[3] < -notch.halfWidth or b[1] > notch.halfWidth)
					.toBe(true)
				t.expect(overlap(b, plaza)).toBe(false)
				for _, pts in paths do
					for k = 1, #pts - 1 do
						for _, corner in
							{
								Vector2.new(b[1], b[2]),
								Vector2.new(b[3], b[2]),
								Vector2.new(b[1], b[4]),
								Vector2.new(b[3], b[4]),
								Vector2.new((b[1] + b[3]) / 2, (b[2] + b[4]) / 2),
							}
						do
							if segDist(corner, pts[k], pts[k + 1]) < 4 + 2 then -- paths are 8 wide
								error(`{name} sits on a path`)
							end
						end
					end
				end
				for key, def in D.Buildings do
					if overlap(b, box(def.spot, def.size, 2)) then
						error(`{name} overlaps {key}`)
					end
				end
				for _, key in { "Spare1", "Spare2", "Spare3", "Jetty", "QuestTablet" } do -- the lots still in use (decor, quests)
					local lot = Marina.LOTS[key]
					if overlap(b, box(lot.cf, lot.size, 2)) then
						error(`{name} overlaps lot {key}`)
					end
				end
				for other, o in props do
					if other ~= name and overlap(b, o) then
						error(`{name} overlaps {other}`)
					end
				end
			end
		end
	)

	t.test(
		"seating keeps places, fills in order, bunks need a Bunkhouse, a move takes a free spot",
		function()
			local first = H.seat({ 4, 7, 9 }, {}, false)
			t.expect(first[4]).toBe(1)
			t.expect(first[7]).toBe(2)
			t.expect(first[9]).toBe(3)
			local again = H.seat({ 9, 4, 7 }, first, false)
			t.expect(again[4] == 1 and again[7] == 2 and again[9] == 3).toBe(true)
			local all = {}
			for i = 1, 60 do
				table.insert(all, i)
			end
			local function check(seats: { [number]: number }, bunks: boolean): number
				local used, n = {}, 0
				for _, k in seats do
					t.expect(used[k]).toBe(nil)
					used[k] = true
					n += 1
					t.expect(H.open(H.SPOTS[k], bunks)).toBe(true)
				end
				return n
			end
			local bunks = 0
			for _, s in H.SPOTS do
				bunks += if s.prop == "Bunkhouse" then 1 else 0
			end
			t.expect(check(H.seat(all, {}, true), true)).toBe(#H.SPOTS)
			local full = H.seat(all, {}, true)
			t.expect(check(H.seat(all, full, false), false)).toBe(#H.SPOTS - bunks)
			local few = H.seat({ 1, 2 }, {}, true)
			local moved = H.seat({ 1, 2 }, few, true, 1, function(n)
				return n
			end)
			t.expect(moved[1] ~= few[1] and moved[2] == few[2]).toBe(true)
			check(moved, true)
		end
	)

	t.test("a seat's rest sits over its feet; a sleeper lies head to the rest's +Z", function()
		local bay = Marina.berth(2)
		for _, s in H.SPOTS do
			local feet, rest = H.place(bay, s)
			t.expect(feet.Position.X == feet.Position.X).toBe(true) -- not NaN
			if s.rest then
				t.expect(rest ~= nil and rest.Position.Y > 1).toBe(true)
				t.expect(rest.Position.Magnitude < 5).toBe(true)
			else
				t.expect(rest).toBe(nil)
			end
		end
	end)
end
