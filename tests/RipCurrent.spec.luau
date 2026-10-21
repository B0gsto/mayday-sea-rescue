-- RipCurrent: the pure current field (docs/09 section 8.4). Direction, strength and width;
-- what it does to drifting things, to swimming against it, and to swimming across it.
return function(t)
	local R = t.load("src/shared/RipCurrent.luau")

	local F = R.HavenSands
	local DT = 1 / 30

	t.test("the field is where the Haven Sands rescue happens", function()
		t.expect(F.origin.Y).toBe(0)
		t.expect(F.direction.Y).toBe(0)
		t.expect(F.direction.Unit.X).toBeCloseTo(-0.6, 1e-6)
		t.expect(F.strength > 4 and F.strength < 12).toBeTruthy()
		t.expect(F.width > 20 and F.length > F.width).toBeTruthy()
		t.expect(R.point(F, 0, 0)).toBe(F.origin)
	end)

	t.test("zero outside the channel, strongest on the centre line", function()
		-- behind the shore end, past the sea end, and outside the band
		t.expect(R.velocityAt(F, F.origin)).toBe(Vector3.zero)
		t.expect(R.velocityAt(F, R.point(F, -10, 0))).toBe(Vector3.zero)
		t.expect(R.velocityAt(F, R.point(F, F.length + 10, 0))).toBe(Vector3.zero)
		t.expect(R.velocityAt(F, R.point(F, 100, F.width))).toBe(Vector3.zero)
		t.expect(R.velocityAt(F, R.point(F, 100, -F.width))).toBe(Vector3.zero)
		-- mid-channel: the full flow, seaward
		local v = R.velocityAt(F, R.point(F, 100, 0))
		t.expect(v.Magnitude).toBeCloseTo(F.strength, 0.01)
		t.expect(v.Unit:Dot(R.unit(F))).toBeCloseTo(1, 1e-6)
		-- half way to the edge: slower; at the edge: nothing
		local edge = R.velocityAt(F, R.point(F, 100, F.width / 2 - 0.5)).Magnitude
		t.expect(edge > 0 and edge < v.Magnitude).toBeTruthy()
		t.expect(R.velocityAt(F, R.point(F, 100, F.width / 2)).Magnitude < 0.01).toBeTruthy()
	end)

	t.test("the flow ramps in from the shore and fades out at sea", function()
		local nearShore = R.velocityAt(F, R.point(F, 5, 0)).Magnitude
		local mid = R.velocityAt(F, R.point(F, F.length * 0.4, 0)).Magnitude
		local far = R.velocityAt(F, R.point(F, F.length - 1, 0)).Magnitude
		t.expect(nearShore < mid).toBeTruthy()
		t.expect(mid).toBeCloseTo(F.strength, 0.01)
		t.expect(far < mid * 0.5).toBeTruthy()
	end)

	-- integrate a swimmer; where they get to (flat)
	local function swim(start: Vector3, heading: Vector3, speed: number, seconds: number): Vector3
		local pos = start
		for _ = 1, math.floor(seconds / DT) do
			pos += R.swimVelocity(F, pos, heading, speed) * DT
		end
		return pos
	end

	t.test("floating things are carried seaward", function()
		local start = R.point(F, 120, 0)
		local gone = swim(start, Vector3.zero, 0, 20) - start
		t.expect(gone:Dot(R.unit(F)) > 80).toBeTruthy()
		t.expect(math.abs(gone:Dot(R.shoreParallel(F))) < 1).toBeTruthy()
	end)

	t.test("swimming straight in against it barely moves", function()
		local speed = 9
		local start = R.point(F, 120, 0)
		local made = swim(start, -R.unit(F), speed, 10)
		local against = (start - made):Dot(R.unit(F))
		-- open water would be 90 studs of way on; in the rip they get a fraction of it
		t.expect(against > 0).toBeTruthy()
		t.expect(against < speed * 10 * 0.35).toBeTruthy()
	end)

	t.test("swimming parallel to the beach escapes the channel", function()
		local speed = 9
		local start = R.point(F, 120, 0)
		local half = F.width / 2
		local elapsed = 0
		local pos = start
		local crossed = 0
		while elapsed < 30 do
			pos += R.swimVelocity(F, pos, R.shoreParallel(F), speed) * DT
			elapsed += DT
			crossed = math.abs((pos - start):Dot(R.shoreParallel(F)))
			if crossed >= half then
				break
			end
		end
		-- out of the band in a few seconds, and the current is gone there
		t.expect(elapsed < 8).toBeTruthy()
		t.expect(R.velocityAt(F, pos)).toBe(Vector3.zero)
	end)
end
