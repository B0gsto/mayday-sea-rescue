-- Boat/Unstick: a hull pinned on a quay/breakwater with the throttle open frees itself after a
-- short hold, once, and only while it is actually stuck.
return function(t)
	local Unstick = t.load("src/shared/Boat/Unstick.luau")

	t.test("pinned with throttle forward for 3 s: exactly one nudge", function()
		local s = Unstick.new()
		t.expect(Unstick.step(s, 1, true, 0, 1)).toBe(false)
		t.expect(Unstick.step(s, 1, true, 0.2, 0.5)).toBe(false)
		t.expect(Unstick.step(s, 1.1, true, 0, 1)).toBe(true)
		t.expect(Unstick.step(s, 1, true, 0, 1)).toBe(false) -- the timer restarts
	end)

	t.test("not stuck, moving, or throttle closed: the timer clears", function()
		local s = Unstick.new()
		t.expect(Unstick.step(s, 2.9, true, 0, 1)).toBe(false)
		t.expect(Unstick.step(s, 0.2, false, 0, 1)).toBe(false)
		t.expect(Unstick.step(s, 2.9, true, 0, 1)).toBe(false) -- reset: 2.9 s is not 3 s
		t.expect(Unstick.step(s, 0.1, true, 0, 1)).toBe(true)
		local moving = Unstick.new()
		t.expect(Unstick.step(moving, 5, true, 1.5, 1)).toBe(false)
		local idle = Unstick.new()
		t.expect(Unstick.step(idle, 5, true, 0, 0)).toBe(false)
		t.expect(Unstick.step(idle, 5, true, 0, -1)).toBe(false) -- reverse does not nudge
	end)
end
