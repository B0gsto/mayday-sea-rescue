-- TalkPose: a quest giver's head look and talk gestures.
return function(t)
	local P = t.load("src/client/Controllers/Talk/TalkPose.luau")

	t.test("looks left, up and clamps", function()
		local yaw, pitch = P.look(Vector3.new(-1, 0, -1))
		t.expect(yaw).toBeCloseTo(45, 1e-6)
		t.expect(pitch).toBeCloseTo(0, 1e-6)
		local y2, p2 = P.look(Vector3.new(-10, 10, 0.1))
		t.expect(y2).toBe(65)
		t.expect(p2).toBe(25)
	end)

	t.test("no look behind or straight above", function()
		t.expect(P.look(Vector3.new(0, 0, 5))).toBe(nil)
		t.expect(P.look(Vector3.new(0, 5, 0))).toBe(nil)
	end)

	t.test("gestures rise and settle back to nothing", function()
		for i = 1, #P.GESTURES do
			t.expect(next(P.gesture(i, 0))).toBe(nil)
			t.expect(next(P.gesture(i, P.GESTURES[i].dur))).toBe(nil)
			t.expect(next(P.gesture(i, P.GESTURES[i].dur * 0.25)) ~= nil).toBe(true)
		end
		t.expect(P.gesture(5, 0.2).Neck.X).toBeCloseTo(P.gesture(1, 0.2).Neck.X, 1e-9) -- wraps round
	end)

	t.test("turns split the look between neck and waist", function()
		local out = P.turns(50, 10, 0, false, nil, 0)
		t.expect(out.Neck.Y).toBeCloseTo(35, 1e-6)
		t.expect(out.Neck.X).toBeCloseTo(10, 1e-6)
		t.expect(out.Waist.Y).toBeCloseTo(15, 1e-6)
	end)
end
