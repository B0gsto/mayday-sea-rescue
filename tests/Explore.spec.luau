-- Explore: surface swimming (Snorkel). The logbook and duck dive were cut, docs/16 C14 and C20.
return function(t)
	local Snorkel = t.require("Explore/Snorkel")

	t.test("swimming starts only in water deeper than wading", function()
		t.expect(Snorkel.shouldSwim(-2, 0, -10, false)).toBe(true)
		t.expect(Snorkel.shouldSwim(-2, 0, -3, false)).toBe(false) -- wading
		t.expect(Snorkel.shouldSwim(1, 0, -10, false)).toBe(false) -- above the surface
		t.expect(Snorkel.shouldSwim(0.5, 0, -10, true)).toBe(true) -- bobbing on a crest keeps swimming
	end)

	t.test(
		"the float spring holds the eye at the surface and dips the mask when looking down",
		function()
			t.expect(Snorkel.verticalVelocity(Snorkel.SURFACE_EYE, 0, 0)).toBeCloseTo(0, 1e-9)
			t.expect(Snorkel.verticalVelocity(-3, 0, 0) > 0).toBe(true)
			t.expect(Snorkel.floatEye(-0.9)).toBe(Snorkel.FACE_DOWN_EYE)
			t.expect(Snorkel.floatEye(0)).toBeCloseTo(Snorkel.SURFACE_EYE, 1e-9)
		end
	)
end
