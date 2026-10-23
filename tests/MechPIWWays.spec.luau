-- MechPIW ways (docs/14 section 3): the survivor's answer to the boat on the server (the 10 s rule,
-- holding on beside the boat).
return function(t)
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

	t.test("held: they follow at the gap and let go when torn away", function()
		local s = W.new()
		s.mode = "held"
		local v = W.step(s, 0, Vector3.new(10, 0, 0), Vector3.zero, 20, false, 0.1)
		t.expect(v.X < 0).toBe(true)
		t.expect(v.Magnitude * 0.1 <= 10 - W.GAP_SWIMMER + 1e-6).toBe(true) -- no overshoot
		t.expect(W.step(s, 0, Vector3.new(2, 0, 0), Vector3.zero, 0, false, 0.1).Magnitude).toBe(0)
		W.step(s, 2, Vector3.new(W.GAP_BOAT + W.LET_GO + 1, 0, 0), Vector3.zero, 40, true, 0.1)
		t.expect(s.mode).toBe("idle")
	end)
end
