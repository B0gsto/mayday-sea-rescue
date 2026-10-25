-- Sub/Dive (docs/23 (h), WP-8): floats like a slow boat, dives and rises smoothly, holds depth
-- hands-off, stays between the seabed and the surface, and picks up a diver held steady in the ring.
return function(t)
	local Dive = t.load("src/shared/Sub/Dive.luau")
	local DT = 1 / 60
	local SEA, BED = 0, -100

	-- integrates y like the physics would; returns state and y after `seconds`
	local function run(
		s,
		y: number,
		throttle: number,
		steer: number,
		dive: number,
		seconds: number,
		bed: number?
	)
		for _ = 1, math.floor(seconds / DT + 0.5) do
			Dive.step(s, throttle, steer, dive, y, SEA, bed or BED, DT)
			y += s.vy * DT
		end
		return s, y
	end
	local FLOAT = SEA - Dive.DRAFT

	t.test("hands-off at the surface it floats at its draft", function()
		local s, y = run(Dive.new(0), FLOAT + 1, 0, 0, 0, 5)
		t.expect(math.abs(y - FLOAT) < 0.05).toBe(true)
		t.expect(s.submerged).toBe(false)
	end)

	t.test("dives smoothly, then holds its depth when hands-off", function()
		local s, y = run(Dive.new(0), FLOAT, 0, 0, -1, 0.5)
		t.expect(s.vy < 0 and s.vy > -Dive.DIVE_SPEED).toBe(true) -- eases in, no jump
		s, y = run(s, y, 0, 0, -1, 6)
		t.expect(math.abs(s.vy + Dive.DIVE_SPEED) < 1e-6).toBe(true)
		t.expect(s.submerged).toBe(true)
		t.expect(s.pitch < 0).toBe(true) -- bow down on the dive
		s, y = run(s, y, 0, 0, 0, 3)
		local held = y
		s, y = run(s, y, 0, 0, 0, 10)
		t.expect(math.abs(y - held) < 1e-6).toBe(true) -- neutral buoyancy
		t.expect(math.abs(s.pitch) < 1e-6).toBe(true) -- levelled
	end)

	t.test("never goes below the seabed clearance nor above the float line", function()
		local s, y = run(Dive.new(0), FLOAT, 0, 0, -1, 60)
		t.expect(y >= BED + Dive.CLEARANCE - 0.05).toBe(true)
		t.expect(y < BED + Dive.CLEARANCE + 0.5).toBe(true)
		-- the bed rises under it: it is lifted, not buried
		s, y = run(s, y, 0, 0, 0, 10, BED + 20)
		t.expect(math.abs(y - (BED + 20 + Dive.CLEARANCE)) < 0.1).toBe(true)
		-- rising all the way ends floating at the surface
		s, y = run(s, y, 0, 0, 1, 40)
		t.expect(math.abs(y - FLOAT) < 0.1).toBe(true)
		t.expect(s.submerged).toBe(false)
	end)

	t.test("too shallow to dive: stays afloat", function()
		local _, y = run(Dive.new(0), FLOAT, 0, 0, -1, 10, SEA - 3)
		t.expect(math.abs(y - FLOAT) < 0.1).toBe(true)
	end)

	t.test("slow ahead, slower astern, turns and leans into the turn", function()
		local s = run(Dive.new(0), FLOAT, 1, 0, 0, 10)
		t.expect(math.abs(s.speed - Dive.TOP_SPEED) < 1e-6).toBe(true)
		t.expect(Dive.TOP_SPEED <= 20).toBe(true) -- calm
		s = run(s, FLOAT, -1, 0, 0, 20)
		t.expect(math.abs(s.speed + Dive.REVERSE_SPEED) < 1e-6).toBe(true)
		s = run(Dive.new(0), FLOAT, 1, 1, 0, 3)
		t.expect(s.yaw < 0).toBe(true) -- steer right = clockwise from above
		t.expect(s.roll < 0).toBe(true) -- starboard down
		s = run(s, FLOAT, 0, 0, 0, 10)
		t.expect(s.speed == 0 and s.yawRate == 0 and s.roll == 0).toBe(true)
	end)

	t.test("pick-up: inside the ring, steady, with room, held long enough", function()
		t.expect(Dive.pickupReady(5, -6, 5, 2, true)).toBe(true)
		t.expect(Dive.pickupReady(Dive.RING_RADIUS, 0, 1, 2, true)).toBe(false) -- outside
		t.expect(Dive.pickupReady(0, Dive.RING_HEIGHT + 1, 0, 2, true)).toBe(false) -- too high
		t.expect(Dive.pickupReady(0, 0, 0, 12, true)).toBe(false) -- too fast
		t.expect(Dive.pickupReady(0, 0, 0, 0, false)).toBe(false) -- full
		local held, done = 0, false
		for _ = 1, 20 do
			held, done = Dive.hold(held, true, 0.02)
		end
		t.expect(done).toBe(false)
		held, done = Dive.hold(held, false, 0.02)
		t.expect(held == 0 and not done).toBe(true)
		for _ = 1, 40 do
			held, done = Dive.hold(held, true, 0.02)
		end
		t.expect(done).toBe(true)
		t.expect(Dive.SEATS).toBe(2)
	end)
end
