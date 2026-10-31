-- HoldRing: the prompt cue's hold ring fills clockwise from 12 o'clock; the right half's gradient turns 0 -> 180
-- over the first half of the hold, then the left half's 180 -> 360.
return function(t)
	local HoldRing = t.load("src/client/UI/HoldRing.luau")

	t.test("the two halves turn in order and clamp at the ends", function()
		local cases = {
			{ -1, 0, 180 },
			{ 0, 0, 180 },
			{ 0.25, 90, 180 },
			{ 0.5, 180, 180 },
			{ 0.75, 180, 270 },
			{ 1, 180, 360 },
			{ 2, 180, 360 },
		}
		for _, c in cases do
			local r, l = HoldRing.rotations(c[1])
			t.expect(r).toBeCloseTo(c[2])
			t.expect(l).toBeCloseTo(c[3])
		end
	end)
end
