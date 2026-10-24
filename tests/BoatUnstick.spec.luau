-- Boat/Unstick: a hull pinned on a wall with the throttle open frees itself after a short hold
-- (under 2 s, docs/20 WP-C), once per hold, and only while it is actually stuck.
return function(t)
	local Unstick = t.load("src/shared/Boat/Unstick.luau")
	local H = Unstick.HOLD

	t.test("pinned with throttle forward for HOLD s: exactly one nudge, well under 2 s", function()
		t.expect(H < 2).toBe(true)
		local s = Unstick.new()
		t.expect(Unstick.step(s, H * 0.5, true, 0, 1)).toBe(false)
		t.expect(Unstick.step(s, H * 0.4, true, 0.2, 0.5)).toBe(false)
		t.expect(Unstick.step(s, H * 0.2, true, 0, 1)).toBe(true)
		t.expect(Unstick.step(s, H * 0.5, true, 0, 1)).toBe(false) -- the timer restarts
	end)

	t.test("crawling under 3 km/h against the wall still counts", function()
		local s = Unstick.new()
		t.expect(Unstick.step(s, H + 0.01, true, Unstick.SPEED - 0.1, 1)).toBe(true)
	end)

	t.test("not stuck, moving, or throttle closed: the timer clears", function()
		local s = Unstick.new()
		t.expect(Unstick.step(s, H - 0.05, true, 0, 1)).toBe(false)
		t.expect(Unstick.step(s, 0.2, false, 0, 1)).toBe(false)
		t.expect(Unstick.step(s, H - 0.05, true, 0, 1)).toBe(false) -- reset: the hold starts over
		t.expect(Unstick.step(s, 0.1, true, 0, 1)).toBe(true)
		local moving = Unstick.new()
		t.expect(Unstick.step(moving, 5, true, Unstick.SPEED + 0.5, 1)).toBe(false)
		local idle = Unstick.new()
		t.expect(Unstick.step(idle, 5, true, 0, 0)).toBe(false)
		t.expect(Unstick.step(idle, 5, true, 0, -1)).toBe(false) -- reverse does not nudge
	end)
end
