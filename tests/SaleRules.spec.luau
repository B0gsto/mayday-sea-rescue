-- SaleRules: the Starter Kit "SALE" button's clock and when it shows.
return function(t)
	local R = t.load("src/shared/SaleRules.luau")

	t.test("countdown: h:mm from an hour up, m:ss under it, never negative", function()
		t.expect(R.countdown(37 * 3600 + 12 * 60 + 59)).toBe("37:12")
		t.expect(R.countdown(3600)).toBe("1:00")
		t.expect(R.countdown(3599)).toBe("59:59")
		t.expect(R.countdown(65.9)).toBe("1:05")
		t.expect(R.countdown(-5)).toBe("0:00")
	end)

	t.test("visible: only before the end time and when not owned", function()
		t.expect(R.visible(100, 99, false)).toBe(true)
		t.expect(R.visible(100, 100, false)).toBe(false)
		t.expect(R.visible(100, 50, true)).toBe(false)
		t.expect(R.visible(nil, 50, false)).toBe(false)
	end)
end
