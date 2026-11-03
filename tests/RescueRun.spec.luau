-- RescueRun (docs/29 C): the tiers, the 75 s window, pay before the delivery counts, the pick-up boost.
return function(t)
	local RescueRun = t.load("src/shared/RescueRun.luau")

	t.test("tiers: x1, x1.25 at 3, x1.5 at 6, x2 at 10 (cap)", function()
		local want =
			{ [0] = 1, [2] = 1, [3] = 1.25, [5] = 1.25, [6] = 1.5, [9] = 1.5, [10] = 2, [99] = 2 }
		for count, mult in want do
			t.expect(RescueRun.multiplierFor(count)).toBe(mult)
		end
	end)

	t.test("a delivery counts after its own pay", function()
		local st = RescueRun.new()
		RescueRun.pickup(st, 0)
		t.expect(RescueRun.current(st, 1)).toBe(1)
		RescueRun.delivered(st, 3, 1)
		t.expect(RescueRun.current(st, 2)).toBe(1.25)
	end)

	t.test("it ends 75 s after the last pick-up or delivery, and restarts from zero", function()
		local st = RescueRun.new()
		RescueRun.delivered(st, 6, 0)
		t.expect(RescueRun.current(st, 74.9)).toBe(1.5)
		t.expect(RescueRun.current(st, 75)).toBe(1)
		RescueRun.pickup(st, 70) -- a pick-up in time keeps it
		t.expect(RescueRun.current(st, 144)).toBe(1.5)
		RescueRun.delivered(st, 1, 200) -- too late: a new run
		t.expect(st.count).toBe(1)
		t.expect(RescueRun.current(st, 201)).toBe(1)
	end)

	t.test("finish ends the run at once (the pirates' hit)", function()
		local st = RescueRun.new()
		RescueRun.delivered(st, 10, 0)
		t.expect(RescueRun.current(st, 1)).toBe(2)
		RescueRun.finish(st)
		t.expect(RescueRun.current(st, 1)).toBe(1)
		t.expect(st.count).toBe(0)
	end)

	t.test("the boost lasts until its timestamp; a missing attribute is no boost", function()
		t.expect(RescueRun.boostAt(10, 9.9)).toBe(RescueRun.BOOST_MULT)
		t.expect(RescueRun.boostAt(10, 10)).toBe(1)
		t.expect(RescueRun.boostAt(nil, 0)).toBe(1)
	end)

	t.test("the helicopter and the sub reach the boosted top speed", function()
		local Flight = t.load("src/shared/Heli/Flight.luau")
		local Dive = t.load("src/shared/Sub/Dive.luau")
		local spec = Flight.spec("RescueHelicopter")
		local s = Flight.new(0)
		local input = { forward = 1, strafe = 0, yaw = 0, lift = 0, boost = 1.25 }
		for _ = 1, 600 do
			Flight.step(s, input, spec, 100, 0, Vector3.zero, 1 / 30)
		end
		t.expect(s.velocity.Magnitude).toBeCloseTo(spec.forwardSpeed * 1.25, 0)
		local d = Dive.new(0)
		d.boost = 1.25
		for _ = 1, 600 do
			Dive.step(d, 1, 0, 0, 0, 0, -100, 1 / 30)
		end
		t.expect(d.speed).toBeCloseTo(Dive.TOP_SPEED * 1.25, 0)
	end)
end
