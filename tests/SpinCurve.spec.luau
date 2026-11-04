-- SpinCurve: the reference's speed table lands inside the server's wedge from any start angle.
return function(t)
	local WheelMath = t.load("src/shared/WheelMath.luau")
	local C = t.load("src/shared/SpinCurve.luau")
	local SpinRules = t.load("src/shared/SpinRules.luau")

	t.test("lands inside the chosen wedge from any start, barely scaled", function()
		for segment = 1, C.COUNT do
			for _, start in { 0, 37.5, 90, 181, -720.25, 5000.5, -1 } do
				for _, off in { -11, -3, 0, 7, 11 } do
					local curve = C.build(start, segment, off)
					t.expect(curve.at(0)).toBeCloseTo(start)
					t.expect(WheelMath.segmentUnder(curve.final, C.COUNT)).toBe(segment)
					t.expect(WheelMath.segmentUnder(curve.at(C.T_END), C.COUNT)).toBe(segment)
					local miss = WheelMath.normalize(
						curve.final - WheelMath.spinAngle(segment, C.COUNT, 0) + 180
					) - 180
					t.expect(math.abs(miss - off) < 1e-6).toBe(true)
					t.expect(math.abs(curve.scale - 1) < 0.03).toBe(true)
				end
			end
		end
	end)

	t.test("winds back, peaks at the table's speed, and only crawls at the end", function()
		local curve = C.build(0, 7, 0)
		local h = 1 / 120
		local peak, low = 0, 0
		for i = 0, math.floor(C.T_END / h) - 1 do
			local v = (curve.at((i + 1) * h) - curve.at(i * h)) / h
			peak, low = math.max(peak, v), math.min(low, v)
		end
		t.expect(math.abs(peak - C.MAX_SPEED) < 120).toBe(true)
		t.expect(low < -180).toBe(true)
		t.expect(curve.at(C.T_RELEASE) < 0).toBe(true) -- still behind the start at the release
		t.expect(math.abs(C.table(C.SPIN_KEYS, 6.5)) < 15).toBe(true)
	end)

	t.test("the claws slam on the reference's beats", function()
		for _, at in C.T_SLAM do
			t.expect(C.table(C.CLAW_KEYS, at) > 1).toBe(true)
		end
		t.expect(C.table(C.CLAW_KEYS, 1)).toBe(0)
	end)

	t.test("the dive falls the whole way and calms by the plunge's end", function()
		local before = C.dive(C.T_BREAK - 0.01)
		t.expect(before.fall).toBe(0)
		local at = C.dive(C.T_PLUNGE)
		t.expect(at.fall).toBeCloseTo(C.FALL_H)
		t.expect(at.depth).toBe(1)
		t.expect(at.speed).toBe(0)
	end)

	t.test("every wedge has a tier", function()
		t.expect(#SpinRules.WEDGES).toBe(C.COUNT)
		for _, id in SpinRules.WEDGES do
			local tier = C.tier((SpinRules.prize(id) :: any).rarity)
			t.expect(C.BUILD_DUR[tier] ~= nil).toBe(true)
		end
	end)
end
