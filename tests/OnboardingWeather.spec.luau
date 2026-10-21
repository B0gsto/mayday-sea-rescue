-- OnboardingWeather: the cold open holds the local weather calm, then eases back into the
-- server's weather over BLEND seconds.
return function(t)
	local O = t.load("src/shared/OnboardingWeather.luau")

	t.test("the cold open, and the spawn before its attribute arrives, are calm", function()
		t.expect(O.target(true, false, 0)).toBe(1)
		t.expect(O.target(true, true, 0)).toBe(1) -- active wins even if the flag raced in early
		t.expect(O.target(false, false, 0)).toBe(1) -- new profile, cold open still starting
		t.expect(O.target(false, false, O.PENDING - 0.01)).toBe(1)
	end)

	t.test("a returning player and a cold open that never starts are not calm", function()
		t.expect(O.target(false, true, 0)).toBe(0) -- returning player
		t.expect(O.target(false, false, O.PENDING)).toBe(0) -- never started: stop holding
		t.expect(O.target(false, true, 120)).toBe(0)
	end)

	t.test("the level eases 1 to 0 over exactly BLEND seconds", function()
		local level = 1
		local dt = 0.1
		for _ = 1, math.floor(O.BLEND / dt + 0.5) - 1 do
			level = O.step(level, 0, dt)
		end
		t.expect(level).toBeCloseTo(dt / O.BLEND, 1e-6) -- one step left
		level = O.step(level, 0, dt)
		t.expect(level).toBeCloseTo(0, 1e-9)
		t.expect(O.step(0, 0, 10)).toBe(0)
	end)

	t.test("the level also rises when a cold open starts again", function()
		t.expect(O.step(0, 1, O.BLEND / 2)).toBeCloseTo(0.5, 1e-9)
		t.expect(O.step(0.9, 1, 10)).toBe(1)
		t.expect(O.step(1, 1, 1)).toBe(1)
	end)

	t.test("local intensity is the server's scaled by the held calm", function()
		t.expect(O.localIntensity(1, 1)).toBe(0)
		t.expect(O.localIntensity(1, 0.5)).toBeCloseTo(0.5, 1e-9)
		t.expect(O.localIntensity(1, 0)).toBe(1)
		t.expect(O.localIntensity(0.4, 0)).toBeCloseTo(0.4, 1e-9)
		t.expect(O.localIntensity(0, 1)).toBe(0)
		t.expect(O.localIntensity(1.5, 0)).toBe(1) -- server value clamped
		t.expect(O.localIntensity(1, 2)).toBe(0) -- level clamped
	end)
end
