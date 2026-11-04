-- Boat/Unstick: a hull pinned on a wall with the throttle (or helm) in use frees itself after a short hold
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
	end)

	t.test(
		"after a push the hull's own drive and helm leave the wall; no second push meanwhile",
		function()
			local fwd, right = Vector3.new(0, 0, -1), Vector3.new(1, 0, 0)
			local s = Unstick.new()
			-- head-on, nothing steered: bears right and backs off, whatever the player holds
			t.expect(Unstick.push(s, -fwd, fwd, right, 0)).toBe(1)
			local throttle, steer = Unstick.input(s, 1, 0)
			t.expect(throttle).toBe(-Unstick.BACK_THROTTLE)
			t.expect(steer).toBe(-1) -- astern the helm is reversed: the bow still goes right
			t.expect(Unstick.step(s, Unstick.BACK_TIME * 0.5, true, 0, 1)).toBe(false)
			t.expect(Unstick.step(s, Unstick.BACK_TIME * 0.6, true, 0, 1)).toBe(false) -- over: player's again
			t.expect((Unstick.input(s, 1, 0))).toBe(1)
			t.expect(Unstick.step(s, H - 0.05, true, 0, 1)).toBe(false) -- a new full HOLD before any repeat
			t.expect(Unstick.step(s, 0.1, true, 0, 1)).toBe(true)
		end
	)

	t.test(
		"a slanted wall swings the bow away from it; astern or alongside drives right",
		function()
			local fwd, right = Vector3.new(0, 0, -1), Vector3.new(1, 0, 0)
			local s = Unstick.new()
			t.expect(Unstick.push(s, (right - fwd).Unit, fwd, right, -1)).toBe(1) -- the wall's normal wins over the helm
			t.expect(Unstick.push(s, (-right - fwd).Unit, fwd, right, 1)).toBe(-1)
			Unstick.push(s, fwd, fwd, right, 0) -- stern on the wall: ahead
			t.expect((Unstick.input(s, -1, 0))).toBe(Unstick.BACK_THROTTLE)
			Unstick.push(s, right, fwd, right, 0) -- alongside: the player's throttle
			t.expect((Unstick.input(s, 1, 0))).toBe(1)
			t.expect((Unstick.input(nil, 0.3, 0))).toBe(0.3)
		end
	)

	t.test("backing or turning into the wall nudges too (the slip)", function()
		t.expect(Unstick.step(Unstick.new(), H + 0.01, true, 0, -1)).toBe(true)
		t.expect(Unstick.step(Unstick.new(), H + 0.01, true, -1, -0.5)).toBe(true)
	end)
end
