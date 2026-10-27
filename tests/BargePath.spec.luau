-- BargePath (docs/25 D, K4): the supply barge sails in to the mooring at BargeNext, stays 20 s, drifts off,
-- turns away from the quay and leaves; a 60 s period never shows two barges' worth of path at once.
return function(t)
	local B = t.load("src/shared/BargePath.luau")
	local P = 60

	t.test("sails in, moors at BargeNext for 20 s, then leaves", function()
		local far = (B.at(100 - B.ARRIVE, 100, P) :: CFrame).Position
		t.expect(far.Z).toBeCloseTo(B.REACH, 1e-6)
		t.expect((B.at(100, 100, P) :: CFrame).Position.Magnitude).toBeCloseTo(0, 1e-6)
		t.expect(B.moored(100, 160, P)).toBe(true) -- the server rolled BargeNext on at the mooring
		t.expect(B.moored(119.9, 160, P)).toBe(true)
		t.expect(B.moored(121, 160, P)).toBe(false)
		t.expect(B.at(100 + 59.5, 220, P)).toBeNil() -- between trips: out of sight
		t.expect(B.moored(135, 130, P)).toBe(true) -- BargeNext late to roll on: still moored
	end)

	t.test("the path is continuous and never comes back toward the quay (-X)", function()
		local last: Vector3? = nil
		for s = -B.ARRIVE, B.STAY + B.SHOVE + B.TURN + B.LEAVE - 0.1, 0.1 do
			local cf = B.at(1000 + s, if s < 0 then 1000 else 1060, P)
			t.expect(cf ~= nil).toBe(true)
			local p = (cf :: CFrame).Position
			t.expect(p.X >= -1e-6).toBe(true)
			if last then
				t.expect((p - last).Magnitude < 4).toBe(true)
			end
			last = p
		end
	end)

	t.test("crates go over the stay; the fallback mooring is the next period", function()
		t.expect(B.unloaded(105, 160, P)).toBeCloseTo(0.25, 1e-6)
		t.expect(B.unloaded(130, 160, P)).toBeNil()
		t.expect(B.fallbackNext(125, P)).toBe(180)
		t.expect(B.fallbackNext(120, P)).toBe(180)
	end)
end
