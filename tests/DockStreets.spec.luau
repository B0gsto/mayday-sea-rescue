-- docs/25 J: every building's own path stub leaves its door and ends on a street or the plaza, on the plate.
return function(t)
	local P = t.load("src/shared/DockPieces.luau")
	local D = t.load("src/shared/Config/DockConfig.luau")
	local R = t.load("src/shared/Config/RingLayout.luau")

	local function onStreet(p: Vector2): boolean
		for _, pts in P.STREETS do
			for k = 1, #pts - 1 do
				local a, ab = pts[k], pts[k + 1] - pts[k]
				local q = a + ab * math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
				if (q - p).Magnitude < 1e-3 then
					return true
				end
			end
		end
		local c, h = P.PLAZA.centre, P.PLAZA.size / 2
		return math.abs(p.X - c.X) <= h.X + 1e-3 and math.abs(p.Y - c.Y) <= h.Y + 1e-3
	end

	t.test("each building's stub is short, axis-aligned and ends on a street", function()
		local edge = R.IslandPlate.edge
		for _, key in D.BUILDINGS do
			local def = D.Buildings[key]
			if key == "HQ" or key == "Harbour" or string.find(key, "^SeaPlate") then -- afloat
				continue
			end
			local pts = P.stub(def.spot, def.size)
			t.expect(#pts >= 2).toBe(true)
			t.expect(onStreet(pts[#pts])).toBe(true)
			local len = 0
			for k = 1, #pts - 1 do
				local d = pts[k + 1] - pts[k]
				t.expect(math.min(math.abs(d.X), math.abs(d.Y)) < 1e-3).toBe(true)
				len += d.Magnitude
			end
			t.expect(len < 70).toBe(true)
			for _, p in pts do
				t.expect(math.abs(p.X) <= edge and math.abs(p.Y) <= edge).toBe(true)
			end
		end
	end)
end
