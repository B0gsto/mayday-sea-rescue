-- TreeMath (docs/24 G-a): the TreeView's pure math: connector frames rotate about their own
-- midpoint, the gamepad picks the nearest node in a direction, lanes stack and pan stays bounded.
return function(t)
	local M = t.load("src/client/UI/Kit/TreeMath.luau")

	local function v(x: number, y: number): Vector2
		return Vector2.new(x, y)
	end

	t.test("connector: centred on the midpoint and rotated about its own centre", function()
		local from, to = v(100, 50), v(300, 150)
		local c = M.connector(from, to, 8)
		t.expect(c.pos.X).toBeCloseTo(200, 1e-6)
		t.expect(c.pos.Y).toBeCloseTo(100, 1e-6)
		t.expect(c.size.X).toBeCloseTo((to - from).Magnitude, 1e-6)
		t.expect(c.size.Y).toBe(8)
		t.expect(c.rotation).toBeCloseTo(math.deg(math.atan2(100, 200)), 1e-6)
		-- rebuild both ends from the frame's centre: the line must land exactly on both nodes
		local half = Vector2.new(math.cos(math.rad(c.rotation)), math.sin(math.rad(c.rotation)))
			* (c.size.X / 2)
		t.expect((c.pos - half - from).Magnitude).toBeCloseTo(0, 1e-4)
		t.expect((c.pos + half - to).Magnitude).toBeCloseTo(0, 1e-4)
	end)

	t.test("connector: axis lines are horizontal / vertical, no NaN for one node", function()
		t.expect(M.connector(v(0, 0), v(100, 0)).rotation).toBeCloseTo(0, 1e-6)
		t.expect(M.connector(v(0, 0), v(0, 100)).rotation).toBeCloseTo(90, 1e-6)
		local same = M.connector(v(5, 5), v(5, 5))
		t.expect(same.size.X).toBe(0)
		t.expect(same.pos).toEqual(v(5, 5))
	end)

	t.test("gamepad: nearest node in a direction, never one behind", function()
		local points = {
			{ id = "up", pos = v(0, -100) },
			{ id = "up2", pos = v(0, -220) },
			{ id = "right", pos = v(100, 0) },
			{ id = "down", pos = v(0, 100) },
			{ id = "left", pos = v(-100, 0) },
			{ id = "upRight", pos = v(100, -100) },
		}
		t.expect(M.nearest(points, v(0, 0), v(0, -1))).toBe("up")
		t.expect(M.nearest(points, v(0, 0), v(0, 1))).toBe("down")
		t.expect(M.nearest(points, v(0, 0), v(1, 0))).toBe("right")
		t.expect(M.nearest(points, v(0, 0), v(-1, 0))).toBe("left")
		t.expect(M.nearest(points, v(0, 0), v(0, 0))).toBeNil()
		-- from the up node, up again reaches the farther one; down skips the node you are on
		t.expect(M.nearest(points, v(0, -100), v(0, -1))).toBe("up2")
		t.expect(M.nearest(points, v(0, -100), v(0, 1))).toBe("down")
	end)

	t.test("gamepad: a node mostly off the axis is not picked", function()
		local points = {
			{ id = "side", pos = v(200, -10) },
			{ id = "ahead", pos = v(10, -100) },
		}
		t.expect(M.nearest(points, v(0, 0), v(0, -1))).toBe("ahead")
		t.expect(M.nearest({ { id = "side", pos = v(200, -10) } }, v(0, 0), v(0, -1))).toBeNil()
	end)

	t.test("layout: groups become vertical lanes, columns run left to right", function()
		local nodes = {
			{ id = "a", col = 0, row = 0, group = "A" },
			{ id = "b", col = 1, row = 0, group = "A" },
			{ id = "c", col = 0, row = 1, group = "B" },
			{ id = "d", col = 0, row = 0, group = "B" },
			{ id = "e", col = 1, row = 0, group = "A" },
		}
		local out = M.layout(nodes)
		t.expect(#out.lanes).toBe(2)
		local A, B = out.lanes[1], out.lanes[2]
		t.expect(A.id).toBe("A")
		t.expect(B.id).toBe("B")
		t.expect(A.y).toBe(M.PAD)
		t.expect(B.y).toBeCloseTo(A.y + A.height + M.LANE_GAP, 1e-6)
		local a, b = A.nodes[1], A.nodes[2]
		t.expect(a.pos.X).toBe(M.PAD)
		t.expect(b.pos.X).toBe(M.PAD + M.NODE.X + M.COL_GAP)
		t.expect(a.pos.Y).toBe(A.y + M.HEADER + 10)
		-- the lane's rows are aligned to its own top, negative rows included
		t.expect(A.nodes[3].pos.X).toBe(b.pos.X)
		local byId = {}
		for _, lane in out.lanes do
			for _, box in lane.nodes do
				byId[box.id] = box
			end
		end
		t.expect(byId.d.pos.Y < byId.c.pos.Y).toBe(true)
		t.expect(out.size.X).toBe(M.PAD * 2 + 2 * M.NODE.X + M.COL_GAP)
		t.expect(out.size.Y).toBe(B.y + B.height + M.PAD)
		for _, box in byId do
			t.expect(box.pos.X >= 0 and box.pos.Y >= 0).toBe(true)
			t.expect(box.pos.X + box.size.X <= out.size.X + 1e-6).toBe(true)
			t.expect(box.pos.Y + box.size.Y <= out.size.Y + 1e-6).toBe(true)
		end
	end)

	t.test("layout: empty tree still has a usable size", function()
		local out = M.layout({})
		t.expect(out.size).toEqual(Vector2.new(M.PAD * 2, M.PAD * 2))
		t.expect(#out.lanes).toBe(0)
	end)

	t.test("clampPan: centred when smaller, bounded when larger", function()
		local centred = M.clampPan(v(500, 500), v(400, 300), v(200, 100), 1)
		t.expect(centred).toEqual(v(100, 100))
		local big = M.clampPan(v(9999, 9999), v(400, 300), v(800, 600), 1)
		t.expect(big.X).toBe(0)
		t.expect(big.Y).toBe(0)
		big = M.clampPan(v(-9999, -9999), v(400, 300), v(800, 600), 1)
		t.expect(big.X).toBe(-400)
		t.expect(big.Y).toBe(-300)
	end)

	t.test("zoomAbout: the point under the pointer stays put", function()
		local pan, at = v(-100, -50), v(200, 100)
		local before = (at - pan) / 1
		local next_ = M.zoomAbout(pan, at, 1, 2)
		local after = (at - next_) / 2
		t.expect((after - before).Magnitude).toBeCloseTo(0, 1e-6)
	end)
end
