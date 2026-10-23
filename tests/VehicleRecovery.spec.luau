-- VehicleRecovery: a flipped, wedged or sunk vehicle resets once after its hold, never mid-jump,
-- and never twice inside the cooldown.
return function(t)
	local R = t.load("src/shared/VehicleRecovery.luau")
	local upright = { up = 1, speed = 20, throttle = 1, grounded = true }
	local onSide = { up = 0.1, speed = 0, throttle = 0, grounded = true }

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
end
