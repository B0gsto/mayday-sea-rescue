-- VehicleRecovery: a flipped, wedged or sunk vehicle resets once after its hold, never mid-jump,
-- and never twice inside the cooldown.
return function(t)
	local R = t.load("src/shared/VehicleRecovery.luau")
	local upright = { up = 1, speed = 20, throttle = 1, grounded = true }
	local onSide = { up = 0.1, speed = 0, throttle = 0, grounded = true }

	t.test(
		"lost: far over or under the sea, or off the map; a heli or sub has more room",
		function()
			t.expect(R.lost(Vector3.new(0, 23510, 0), false, 7000)).toBe(true)
			t.expect(R.lost(Vector3.new(0, 1, 0), false, 7000)).toBe(false)
			t.expect(R.lost(Vector3.new(0, -30, 0), false, 7000)).toBe(true)
			t.expect(R.lost(Vector3.new(8000, 1, 0), false, 7000)).toBe(true)
			t.expect(R.lost(Vector3.new(0, 250, 0), true, 7000)).toBe(false) -- a heli at its ceiling
			t.expect(R.lost(Vector3.new(0, -160, 0), true, 7000)).toBe(false) -- a sub on the seabed
			t.expect(R.lost(Vector3.new(0, 23510, 0), true, 7000)).toBe(true)
		end
	)

	t.test("on its side for FLIP_TIME: one Flipped, then the cooldown holds", function()
		local s = R.new()
		t.expect(R.step(s, 1, 1, onSide)).toBe(nil)
		t.expect(R.step(s, 1, 2, onSide)).toBe("Flipped")
		t.expect(R.step(s, 3, 5, onSide)).toBe(nil) -- cooldown
		t.expect(R.step(s, 1, 8.5, onSide)).toBe(nil) -- cooldown over: the timer starts again
		t.expect(R.step(s, 1, 9.5, onSide)).toBe("Flipped")
	end)

	t.test("righting itself clears the flip timer; mid-air rolls never count", function()
		local s = R.new()
		t.expect(R.step(s, 1.5, 1, onSide)).toBe(nil)
		t.expect(R.step(s, 0.5, 2, upright)).toBe(nil)
		t.expect(R.step(s, 1.5, 3, onSide)).toBe(nil)
		local air = { up = -1, speed = 0, throttle = 1, grounded = false }
		local jump = R.new()
		t.expect(R.step(jump, 5, 1, air)).toBe(nil)
	end)

	t.test("throttle held while barely moving for STUCK_TIME: Stuck", function()
		local s = R.new()
		local wedged = { up = 1, speed = 0.5, throttle = -1, grounded = true }
		t.expect(R.step(s, 1.5, 1, wedged)).toBe(nil)
		t.expect(R.step(s, 0.5, 2, wedged)).toBe("Stuck")
		local parked = R.new()
		t.expect(R.step(parked, 10, 1, { up = 1, speed = 0, throttle = 0, grounded = true }))
			.toBe(nil)
		local moving = R.new()
		t.expect(R.step(moving, 10, 1, upright)).toBe(nil)
	end)

	t.test("off (in terrain, beached) for OFF_TIME: Sunk", function()
		local s = R.new()
		local sunk = { up = 1, speed = 0, throttle = 0, grounded = true, off = true }
		t.expect(R.step(s, 2, 1, sunk)).toBe(nil)
		t.expect(R.step(s, 0.5, 2, sunk)).toBe("Sunk")
	end)

	t.test("the glide starts and ends on the given frames and lifts in between", function()
		local from = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90))
		local to = CFrame.new(10, 2, 0)
		t.expect((R.path(from, to, 0).Position - from.Position).Magnitude < 1e-4).toBe(true)
		t.expect((R.path(from, to, 1).Position - to.Position).Magnitude < 1e-4).toBe(true)
		t.expect(R.path(from, to, 1).UpVector.Y > 0.999).toBe(true)
		t.expect(R.path(from, to, 0.5).Position.Y > 1 + R.GLIDE_LIFT - 0.01).toBe(true)
	end)

	t.test(
		"misplaced: an empty vehicle goes after MISPLACED_TIME; leaving the wrong medium resets",
		function()
			local s = R.new()
			local T = R.MISPLACED_TIME
			t.expect(R.misplaced(s, T - 1, 10, true, false)).toBe(false)
			t.expect(R.misplaced(s, 0.5, 11, false, false)).toBe(false) -- back afloat: the timer clears
			t.expect(R.misplaced(s, T - 0.5, 20, true, false)).toBe(false)
			t.expect(R.misplaced(s, 0.5, 21, true, false)).toBe(true)
		end
	)

	t.test(
		"misplaced: an occupied vehicle goes only after a recovery failed in this spell",
		function()
			local T = R.MISPLACED_TIME
			local s = R.new()
			t.expect(R.misplaced(s, T + 5, 100, true, true)).toBe(false) -- never tried: keep trying
			local tried = R.new()
			t.expect(R.misplaced(tried, 2.5, 10, true, true)).toBe(false)
			tried.lastAt = 10 -- the recovery fired, and the glide left it where it was
			t.expect(R.misplaced(tried, T - 2.5, 14, true, true)).toBe(true)
			local old = R.new()
			old.lastAt = 0 -- a recovery long before this spell does not count
			t.expect(R.misplaced(old, T + 1, 50, true, true)).toBe(false)
		end
	)
end
