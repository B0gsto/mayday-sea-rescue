-- DayClock (docs/25 G): the clock follows the server time through a 20 min cycle (2.5 min dawn, 9 min day, 2.5 min dusk,
-- 3 min night), stays continuous across the wrap, the dev offset lands on the asked hour, and midday is never warm.
return function(t)
	local D = t.load("src/shared/DayClock.luau")

	t.test("phases: 9 min day, 2.5 min dusk and dawn, 3 min night", function()
		t.expect(D.CYCLE).toBe(1200)
		t.expect(D.clockTime(0)).toBeCloseTo(5, 1e-9)
		t.expect(D.clockTime(80)).toBeCloseTo(6.5, 1e-9)
		t.expect(D.clockTime(960)).toBeCloseTo(18.25, 1e-9) -- sunset, then a 60 s blue hour
		t.expect(D.clockTime(510)).toBeCloseTo(12.5, 1e-9)
		t.expect(D.clockTime(870)).toBeCloseTo(17, 1e-9)
		t.expect(D.clockTime(1020)).toBeCloseTo(19.5, 1e-9)
		t.expect(D.clockTime(1110)).toBeCloseTo(0.25, 1e-9) -- just past midnight, mid-night
		t.expect(D.clockTime(1200 * 5000 + 510)).toBeCloseTo(12.5, 1e-6) -- server time is a Unix time
	end)

	t.test("continuous: never jumps more than a step's worth, wraps 24 -> 0 once", function()
		local last = D.clockTime(0)
		local wraps = 0
		for s = 0.5, 1200, 0.5 do
			local c = D.clockTime(s)
			local d = c - last
			if d < -12 then
				wraps += 1
				d += 24
			end
			t.expect(d >= 0 and d < 0.03).toBe(true)
			last = c
		end
		t.expect(wraps).toBe(1)
	end)

	t.test("the dev offset puts the clock on the asked hour", function()
		for _, h in { 0, 3, 5, 6.25, 12, 14, 17.5, 21, 23.75 } do
			local now = 1761600000.25
			local c = D.clockTime(now + D.offsetTo(now, h))
			t.expect((c - h + 12) % 24 - 12).toBeCloseTo(0, 1e-6) -- 23.999.. is midnight
		end
	end)

	t.test("warmth: none at midday, full at dusk and dawn", function()
		t.expect(D.warmth(9)).toBe(0)
		t.expect(D.warmth(14)).toBe(0)
		t.expect(D.warmth(15.5)).toBe(0)
		t.expect(D.warmth(17.5)).toBe(1)
		t.expect(D.warmth(6)).toBe(1)
	end)
end
