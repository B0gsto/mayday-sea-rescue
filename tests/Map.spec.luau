-- Map: the world -> map transform matches the terrain bake and the minimap maths.
return function(t)
	local MapConfig = t.require("Config/MapConfig")

	t.test("world <-> UV round-trips and covers the bake square", function()
		local u, v = MapConfig.worldToUV(-7168, -7168)
		t.expect(u).toBe(0)
		t.expect(v).toBe(0)
		u, v = MapConfig.worldToUV(0, 0)
		t.expect(u).toBeCloseTo(0.5, 1e-9)
		t.expect(v).toBeCloseTo(0.5, 1e-9)
		local x, z = MapConfig.uvToWorld(MapConfig.worldToUV(880, 115))
		t.expect(x).toBeCloseTo(880, 1e-6)
		t.expect(z).toBeCloseTo(115, 1e-6)
	end)

	t.test("the view puts the heading up and east to the right when facing north", function()
		local x, y = MapConfig.toView(0, -10, 0, -1)
		t.expect(x).toBeCloseTo(0, 1e-9)
		t.expect(y).toBeCloseTo(-10, 1e-9)
		x, y = MapConfig.toView(10, 0, 0, -1)
		t.expect(x).toBeCloseTo(10, 1e-9)
		-- facing east, a point to the east is straight up
		x, y = MapConfig.toView(10, 0, 1, 0)
		t.expect(x).toBeCloseTo(0, 1e-9)
		t.expect(y).toBeCloseTo(-10, 1e-9)
	end)

	t.test("blips past the rim clamp onto it", function()
		local x, y, c = MapConfig.clampToRim(300, 400, 100)
		t.expect(c).toBe(true)
		t.expect(math.sqrt(x * x + y * y)).toBeCloseTo(100, 1e-9)
		local _, _, inside = MapConfig.clampToRim(10, 10, 100)
		t.expect(inside).toBe(false)
	end)

	t.test("zoom widens with speed in a boat and stays close on foot", function()
		t.expect(MapConfig.zoomFor("foot", 50)).toBe(MapConfig.Zoom.foot)
		t.expect(MapConfig.zoomFor("boat", 0)).toBe(MapConfig.Zoom.boat.slow)
		t.expect(MapConfig.zoomFor("boat", 500)).toBe(MapConfig.Zoom.boat.fast)
		t.expect(MapConfig.zoomFor("boat", 60) > MapConfig.zoomFor("foot", 0)).toBe(true)
	end)

	t.test("the island plates and bridges land where RingLayout builds them", function()
		local RingLayout = t.require("Config/RingLayout")
		local shapes = MapConfig.landShapes()
		local plates, bridges = 0, 0
		for _, sh in shapes do
			if sh.kind == "plate" then
				plates += 1
				local on = false
				for _, isl in RingLayout.Islands do
					on = on or RingLayout.onPlate(isl, sh.x, sh.z)
				end
				t.expect(on).toBe(true)
			else
				bridges += 1
				t.expect(sh.w > 100).toBe(true)
			end
		end
		t.expect(plates).toBe(#RingLayout.Islands * #RingLayout.IslandPlate.rects)
		t.expect(bridges).toBe(#RingLayout.Bridges)
	end)
end
