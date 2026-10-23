-- Explore: snorkelling / duck dives (Snorkel). The logbook (Discovery) was cut, docs/16 C14.
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
			t.expect(Snorkel.verticalVelocity("surface", Snorkel.SURFACE_EYE, 0, -20, 0, 0))
				.toBeCloseTo(0, 1e-9)
			t.expect(Snorkel.verticalVelocity("surface", -3, 0, -20, 0, 0) > 0).toBe(true)
			t.expect(Snorkel.floatEye(-0.9)).toBe(Snorkel.FACE_DOWN_EYE)
			t.expect(Snorkel.floatEye(0)).toBeCloseTo(Snorkel.SURFACE_EYE, 1e-9)
		end
	)

	t.test(
		"a duck dive pushes down, stops at 5 m or the seabed, and surfaces out of breath",
		function()
			t.expect(Snorkel.verticalVelocity("dive", 0.4, 0, -40, 0, 0, 0.1) < 0).toBe(true)
			-- below the depth limit it climbs back
			t.expect(Snorkel.verticalVelocity("dive", -18, 0, -40, -1, 1, 5) > 0).toBe(true)
			-- over a shallow seabed the floor clearance wins
			t.expect(Snorkel.verticalVelocity("dive", -6, 0, -7, -1, 1, 5) > 0).toBe(true)
			-- looking down and swimming forward goes down
			t.expect(Snorkel.verticalVelocity("dive", -6, 0, -40, -0.7, 1, 5) < 0).toBe(true)
			local b = Snorkel.BREATH
			for _ = 1, 300 do
				b = Snorkel.stepBreath(b, true, 0.1)
			end
			t.expect(b).toBe(0)
			t.expect(Snorkel.nextMode("dive", 10, 0, false, false)).toBe("ascend")
			t.expect(Snorkel.nextMode("ascend", 0.1, 0, false, false)).toBe("surface")
			t.expect(Snorkel.nextMode("surface", 0, 2, true, false)).toBe("surface") -- not enough breath
			t.expect(Snorkel.nextMode("surface", 0, Snorkel.BREATH, true, false)).toBe("dive")
			t.expect(Snorkel.stepBreath(0, false, 2) > 0).toBe(true)
			t.expect(Snorkel.speed("surface", 1) > Snorkel.speed("surface", 0)).toBe(true)
		end
	)
end
