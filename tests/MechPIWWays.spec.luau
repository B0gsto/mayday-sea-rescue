-- MechPIW ways (docs/14 section 3): aim where you look, and the casualty's answer on the server
-- (the 10 s rule, the line haul, drag) plus the server's grab and throw checks.
return function(t)
	local Units = t.load("src/client/Mechanics/PIW/Units.luau")
	local Throw = t.load("src/client/Mechanics/PIW/Throw.luau")
	local W = t.load("src/server/Ops/PiwWays.luau")

	-- runs the casualty from `start` toward a still rescuer at the origin; seconds to "held"
	local function arrive(s, start: Vector3, onBoat: boolean, t0: number): number
		local cas = start
		local now, dt = t0, 1 / 30
		while s.mode ~= "held" and now - t0 < 30 do
			local v = W.step(s, now, cas, Vector3.zero, 0, onBoat, dt)
			cas += v * dt
			now += dt
		end
		return now - t0
	end

	t.test("aim: the ghost lands where the reticle meets the water (still air, level)", function()
		for _, d in { 20, 35, 50 } do
			local p = Throw.powerFor(d, Units.GRAVITY)
			local land = Throw.land(
				Vector3.zero,
				Throw.velocity(Vector3.new(0, 0, -1), p),
				0,
				Units.GRAVITY,
				Vector3.zero
			)
			t.expect(math.abs(land.Z)).toBeCloseTo(d, 0.01)
		end
		t.expect(Throw.powerFor(0, Units.GRAVITY)).toBe(0)
		t.expect(Throw.powerFor(500, Units.GRAVITY)).toBe(1)
	end)

	t.test("aim: the arc starts at the hand and ends at the landing point", function()
		local o = Vector3.new(0, 3, 0)
		local v = Throw.velocity(Vector3.new(1, 0, 0), 0.6)
		local wind = Vector3.new(0, 0, 1.2)
		local land, tEnd = Throw.land(o, v, 0, Units.GRAVITY, wind)
		local pts = Throw.arc(o, v, Units.GRAVITY, wind, tEnd, 13)
		t.expect(#pts).toBe(14)
		t.expect((pts[1] - o).Magnitude).toBeCloseTo(0, 1e-6)
		t.expect((pts[14] - land).Magnitude).toBeCloseTo(0, 0.01)
		t.expect(pts[7].Y > o.Y).toBe(true) -- it flies up first
	end)

	t.test("10 s rule: close and stopped, they reach you within 10 s from any range", function()
		for _, r in { 8, 20, W.COME_RANGE } do
			local s = W.new()
			local secs = arrive(s, Vector3.new(r, 0, 0), true, 100)
			t.expect(s.mode).toBe("held")
			t.expect(secs <= W.COME_DEADLINE).toBe(true)
		end
		-- near by, they just swim at an easy pace
		t.expect(W.comeSpeed(6, 0, W.SWIM_SPEED)).toBe(W.SWIM_SPEED)
		t.expect(W.comeSpeed(40, 8, W.SWIM_SPEED)).toBe(40)
	end)

	t.test("10 s rule: they wait while you are far or still under way", function()
		local s = W.new()
		local v = W.step(s, 0, Vector3.new(W.COME_RANGE + 5, 0, 0), Vector3.zero, 0, true, 0.1)
		t.expect(s.mode).toBe("idle")
		t.expect(v.Magnitude).toBe(0)
		W.step(s, 0, Vector3.new(20, 0, 0), Vector3.zero, W.STOPPED + 5, true, 0.1)
		t.expect(s.mode).toBe("idle")
		W.step(s, 0, Vector3.new(20, 0, 0), Vector3.zero, 0, true, 0.1)
		t.expect(s.mode).toBe("swim")
		W.step(s, 1, Vector3.new(W.LOST_RANGE + 1, 0, 0), Vector3.zero, 0, true, 0.1)
		t.expect(s.mode).toBe("idle") -- the boat went off: they wait again
	end)

	t.test(
		"10 s rule: COME_DEADLINE after the arm they set off anyway, if you are in sight",
		function()
			local s = W.new()
			s.since = 100 -- armed (PiwRescue)
			local far = Vector3.new(W.COME_RANGE + 30, 0, 0)
			W.step(s, 100 + W.COME_DEADLINE - 0.5, far, Vector3.zero, W.STOPPED + 5, true, 0.1)
			t.expect(s.mode).toBe("idle")
			W.step(
				s,
				100 + W.COME_DEADLINE,
				Vector3.new(W.LOST_RANGE + 1, 0, 0),
				Vector3.zero,
				0,
				true,
				0.1
			)
			t.expect(s.mode).toBe("idle") -- out of sight: still waiting
			W.step(s, 100 + W.COME_DEADLINE, far, Vector3.zero, W.STOPPED + 5, true, 0.1)
			t.expect(s.mode).toBe("swim")
		end
	)

	t.test("throw: a hit line hauls them in within 10 s, from the line's full reach", function()
		local s = W.new()
		W.begin(s, "line", 50)
		local secs = arrive(s, Vector3.new(0, 0, W.LINE_REACH), true, 50)
		t.expect(s.mode).toBe("held")
		t.expect(secs <= W.COME_DEADLINE).toBe(true)
	end)

	t.test("drag: held, they follow at the gap and let go when torn away", function()
		local s = W.new()
		W.begin(s, "held", 0)
		local v = W.step(s, 0, Vector3.new(10, 0, 0), Vector3.zero, 20, false, 0.1)
		t.expect(v.X < 0).toBe(true)
		t.expect(v.Magnitude * 0.1 <= 10 - W.GAP_SWIMMER + 1e-6).toBe(true) -- no overshoot
		t.expect(W.step(s, 0, Vector3.new(2, 0, 0), Vector3.zero, 0, false, 0.1).Magnitude).toBe(0)
		W.begin(s, "line", 1) -- holding on already: a throw changes nothing
		t.expect(s.mode).toBe("held")
		W.step(s, 2, Vector3.new(W.GAP_BOAT + W.LET_GO + 1, 0, 0), Vector3.zero, 40, true, 0.1)
		t.expect(s.mode).toBe("idle")
	end)

	t.test(
		"server checks: grabs need arm's reach, throws need the line and to land by them",
		function()
			local cas = Vector3.new(0, 0, 0)
			t.expect(W.canGrab(Vector3.new(W.GAP_BOAT + W.GRAB_RANGE - 0.5, 4, 0), cas, true))
				.toBe(true)
			t.expect(W.canGrab(Vector3.new(W.GAP_SWIMMER + W.GRAB_RANGE + 0.5, 0, 0), cas, false))
				.toBe(false)
			local far = Vector3.new(W.LINE_REACH + 10, 0, 0)
			t.expect(W.throwHits(Vector3.new(40, 2, 0), Vector3.new(2, 0, 0), cas)).toBe(true)
			t.expect(W.throwHits(far, Vector3.new(2, 0, 0), cas)).toBe(false) -- out of the line's reach
			t.expect(W.throwHits(Vector3.new(40, 0, 0), Vector3.new(20, 0, 0), cas)).toBe(false) -- short
		end
	)
end
