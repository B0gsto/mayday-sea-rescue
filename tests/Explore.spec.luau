-- Explore: surface swimming (Snorkel). The logbook and duck dive were cut, docs/16 C14 and C20.
return function(t)
	local Snorkel = t.require("Explore/Snorkel")

	t.test("swimming starts only in water deeper than wading", function()
		t.expect(Snorkel.shouldSwim(-2, 0, -10, false)).toBe(true)
		t.expect(Snorkel.shouldSwim(-2, 0, -3, false)).toBe(false) -- wading
		t.expect(Snorkel.shouldSwim(1, 0, -10, false)).toBe(false) -- above the surface
		t.expect(Snorkel.shouldSwim(0.5, 0, -10, true)).toBe(true) -- bobbing on a crest keeps swimming
		-- the wade line has hysteresis: a wave at the line does not flip swim / wade
		local d = Snorkel.WADE_DEPTH + Snorkel.WADE_HYSTERESIS / 2
		t.expect(Snorkel.shouldSwim(-2, 0, -d, false)).toBe(false)
		t.expect(Snorkel.shouldSwim(-2, 0, -d, true)).toBe(true)
	end)

	t.test(
		"a swimmer's move is level at the same stick strength, whatever the camera pitch",
		function()
			local flat = Snorkel.flatMove(Vector3.new(0, -0.6, -0.8))
			t.expect(flat.Y).toBe(0)
			t.expect(flat.Z).toBeCloseTo(-1, 1e-6)
			t.expect(Snorkel.flatMove(Vector3.new(0.3, 0.4, 0)).X).toBeCloseTo(0.5, 1e-6) -- half stick
			t.expect(Snorkel.flatMove(Vector3.new(0, -1, 0)).Magnitude).toBe(0) -- straight down: no heading
		end
	)

	t.test(
		"the float spring holds the eye at the surface and dips the mask when looking down",
		function()
			t.expect(Snorkel.verticalVelocity(Snorkel.SURFACE_EYE, 0, 0)).toBeCloseTo(0, 1e-9)
			t.expect(Snorkel.verticalVelocity(-3, 0, 0) > 0).toBe(true)
			t.expect(Snorkel.floatEye(-0.9)).toBe(Snorkel.FACE_DOWN_EYE)
			t.expect(Snorkel.floatEye(0)).toBeCloseTo(Snorkel.SURFACE_EYE, 1e-9)
			t.expect(Snorkel.verticalVelocity(Snorkel.SURFACE_EYE, 0, 0, 0.2) > 0).toBe(true)
		end
	)

	t.test("a stroke surges on the pull and averages the swim speed", function()
		local pull, lift = Snorkel.stroke(0)
		local glide = Snorkel.stroke(0.5)
		t.expect(pull > 1 and glide < 1).toBe(true)
		t.expect(lift).toBeCloseTo(Snorkel.BOB, 1e-9)
		local sum = 0
		for i = 0, 99 do
			sum += (Snorkel.stroke(i / 100))
		end
		t.expect(sum / 100).toBeCloseTo(1, 1e-6)
	end)
end
