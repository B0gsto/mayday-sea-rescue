-- WheelMath (docs/24 D): segment angles, the rotation that lands a segment under the pointer, the
-- eased spin (with overshoot) and the peg ticks along the way.
return function(t)
	local WheelMath = t.load("src/shared/WheelMath.luau")
	local COUNT = 12

	t.test(
		"segments sit evenly round the wheel and the spin lands each under the pointer",
		function()
			for i = 1, COUNT do
				local angle = WheelMath.segmentAngle(i, COUNT)
				t.expect(angle >= 0).toBe(true)
				t.expect(angle < 360).toBe(true)
				t.expect(angle).toBeCloseTo((i - 1) * 30)
				local rotation = WheelMath.spinAngle(i, COUNT, 0)
				t.expect(WheelMath.normalize(angle + rotation)).toBeCloseTo(WheelMath.POINTER)
				t.expect(WheelMath.segmentUnder(rotation, COUNT)).toBe(i)
			end
		end
	)

	t.test("turns add whole circles and stay non-negative", function()
		local one = WheelMath.spinAngle(3, COUNT, 4)
		local none = WheelMath.spinAngle(3, COUNT, 0)
		t.expect(one - none).toBe(1440)
		t.expect(WheelMath.spinAngle(3, COUNT, -2)).toBe(none)
		t.expect(WheelMath.segmentUnder(one, COUNT)).toBe(3)
	end)

	t.test("the spin eases out, overshoots a little, then settles on the segment", function()
		local target = WheelMath.spinAngle(7, COUNT, 5)
		local overshoot = 7
		t.expect(WheelMath.angleAt(0, target, overshoot)).toBe(0)
		t.expect(WheelMath.angleAt(1, target, overshoot)).toBeCloseTo(target)
		local peak = 0
		local last = 0
		for i = 0, 100 do
			local a = WheelMath.angleAt(i / 100, target, overshoot)
			peak = math.max(peak, a)
			if i < 80 then
				t.expect(a >= last - 0.001).toBe(true) -- monotonic on the way up
			end
			last = a
		end
		t.expect(peak > target).toBe(true)
		t.expect(peak - target < overshoot + 0.01).toBe(true)
		t.expect(WheelMath.segmentUnder(target, COUNT)).toBe(7)
	end)

	t.test("ticks count the segment boundaries the wheel passes", function()
		t.expect(WheelMath.ticksFor(0, COUNT)).toBe(0)
		t.expect(WheelMath.ticksFor(29, COUNT)).toBe(0)
		t.expect(WheelMath.ticksFor(31, COUNT)).toBe(1)
		t.expect(WheelMath.ticksFor(360 * 3 + 359, COUNT)).toBe(3 * COUNT + 11)
	end)
end
