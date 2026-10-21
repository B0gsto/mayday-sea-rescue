-- RoadNet: junction detection, stop lines and traffic light phases (left-hand traffic).
return function(t)
	local RoadNet = t.load("src/shared/RoadNet.luau")

	local function road(id: string, width: number, points: { Vector3 }, surface: string?)
		return { id = id, surface = surface or "Asphalt", width = width, points = points }
	end
	-- a through road west-east, a side road going north from its middle, a continuation at the east end
	local main =
		road("Main", 18, { Vector3.new(-200, 0, 0), Vector3.new(0, 0, 0), Vector3.new(200, 0, 0) })
	local side = road("Side", 12, { Vector3.new(20, 0, 0), Vector3.new(20, 0, -200) })
	local on = road("On", 18, { Vector3.new(200, 0, 0), Vector3.new(400, 0, 0) })
	local cross = road("Cross", 12, { Vector3.new(-100, 0, 100), Vector3.new(-100, 0, -100) })

	t.test("a T and an X are junctions; an end-to-end continuation is not", function()
		local js = RoadNet.junctions({ main, side, on, cross })
		t.expect(#js).toBe(2)
		local tee = if js[1].pos.X > 0 then js[1] else js[2]
		local x = if js[1].pos.X > 0 then js[2] else js[1]
		t.expect(#tee.arms).toBe(3)
		t.expect(tee.groups).toBe(2)
		t.expect((tee.pos - Vector3.new(20, 0, 0)).Magnitude < 1).toBe(true)
		t.expect(#x.arms).toBe(4)
		t.expect(x.groups).toBe(2)
		t.expect(tee.signals).toBe(true)
		for _, a in tee.arms do
			t.expect(a.stop).toBe(if a.road == "Side" then 12 else 9)
		end
	end)

	t.test("no lights where a road is not asphalt", function()
		local track =
			road("Track", 10, { Vector3.new(20, 0, 0), Vector3.new(20, 0, 200) }, "Ground")
		t.expect(RoadNet.junctions({ main, track })[1].signals).toBe(false)
	end)

	t.test("every group gets green then amber then red, one at a time", function()
		local j = RoadNet.junctions({ main, side })[1]
		local c = RoadNet.CYCLE
		local slot = c.green + c.amber + c.red
		for k = 0, slot * 2 - 1 do
			local time = k - j.offset + slot * 10
			local a, b = RoadNet.light(j, 1, time), RoadNet.light(j, 2, time)
			t.expect(a == "red" or b == "red").toBe(true)
		end
		local t0 = -j.offset + slot * 10
		t.expect(RoadNet.light(j, 1, t0 + 1)).toBe("green")
		t.expect(RoadNet.light(j, 1, t0 + c.green + 1)).toBe("amber")
		t.expect(RoadNet.light(j, 1, t0 + slot + 1)).toBe("red")
		t.expect(RoadNet.light(j, 2, t0 + slot + 1)).toBe("green")
	end)

	t.test("the stop line spans the left-hand incoming lane", function()
		local j = RoadNet.junctions({ main, side })[1]
		for _, a in j.arms do
			if a.road == "Main" and a.dir.X < 0 then
				-- eastbound traffic arrives from the west and keeps left: the north (-Z) half
				local c, across = RoadNet.incoming(a)
				t.expect((c - Vector3.new(11, 0, 0)).Magnitude < 1e-6).toBe(true)
				t.expect((across - Vector3.new(0, 0, -1)).Magnitude < 1e-6).toBe(true)
			end
		end
	end)

	t.test("a car stops at red, not once past the line, not on another road", function()
		local j = RoadNet.junctions({ main, side })[1]
		local slot = RoadNet.CYCLE.green + RoadNet.CYCLE.amber + RoadNet.CYCLE.red
		local redForMain = -j.offset + slot * 10 + slot + 1 -- group 2 (Side) green
		local east = Vector3.new(1, 0, 0)
		local d = RoadNet.stopFor({ j }, "Main", Vector3.new(0, 0, -4), east, redForMain)
		t.expect(d).toBeCloseTo(11, 1e-6)
		t.expect(RoadNet.stopFor({ j }, "Main", Vector3.new(15, 0, -4), east, redForMain)).toBeNil()
		t.expect(RoadNet.stopFor({ j }, "Side", Vector3.new(-10, 0, -4), east, redForMain))
			.toBeNil()
		t.expect(RoadNet.stopFor({ j }, "Main", Vector3.new(-10, 0, -4), east, redForMain - slot))
			.toBeNil()
	end)
end
