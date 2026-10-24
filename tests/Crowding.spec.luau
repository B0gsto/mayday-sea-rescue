-- Crowding (docs/20 WP-C addendum): a busy server shortens idle timers and thins traffic; player
-- craft ease apart instead of colliding.
return function(t)
	local C = t.load("src/shared/Crowding.luau")

	t.test("scale is 1 for a small server and falls to MIN at a full one", function()
		t.expect(C.scale(1)).toBe(1)
		t.expect(C.scale(C.SOLO)).toBe(1)
		t.expect(C.scale(C.FULL)).toBe(C.MIN)
		t.expect(C.scale(40)).toBe(C.MIN)
		local mid = C.scale((C.SOLO + C.FULL) / 2)
		t.expect(mid < 1 and mid > C.MIN).toBe(true)
		t.expect(C.scale(5) > C.scale(6)).toBe(true)
	end)

	t.test("apart pushes harder the deeper the overlap and never when clear", function()
		t.expect(C.apart(20, 10)).toBe(0)
		t.expect(C.apart(10, 10)).toBe(0)
		t.expect(C.apart(0, 10)).toBe(C.PUSH)
		t.expect(C.apart(5, 10)).toBe(C.PUSH / 2)
		t.expect(C.apart(2, 10) > C.apart(8, 10)).toBe(true)
		t.expect(C.apart(1, 0)).toBe(0)
		t.expect(C.apart(-1, 10)).toBe(C.PUSH) -- never more than PUSH: no launches
	end)
end
