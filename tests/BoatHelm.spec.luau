-- Boat/Helm (docs/20 WP-C): a key ramps the helm to full in RAMP s, a release centres it fast,
-- and the lock eases off at speed.
return function(t)
	local Helm = t.load("src/shared/Boat/Helm.luau")
	local function run(h: number, input: number, frac: number, seconds: number): number
		local dt = 1 / 60
		for _ = 1, math.floor(seconds / dt + 0.5) do
			h = Helm.step(h, input, frac, dt)
		end
		return h
	end

	t.test("a held key reaches full lock at RAMP, not before", function()
		t.expect(math.abs(run(0, 1, 0, Helm.RAMP) - 1) < 1e-6).toBe(true)
		local tap = run(0, 1, 0, 0.3)
		t.expect(tap > 0.7 and tap < 0.8).toBe(true) -- a 0.3 s tap is three quarters, not full
		t.expect(math.abs(run(0, -1, 0, 0.1) + 0.25) < 1e-6).toBe(true)
	end)

	t.test("letting go centres within RELEASE; reversing crosses fast then ramps", function()
		t.expect(math.abs(run(1, 0, 0, Helm.RELEASE)) < 1e-6).toBe(true)
		local h = run(1, -1, 0, Helm.RELEASE) -- back to centre at the release rate
		t.expect(math.abs(h) < 1e-6).toBe(true)
		h = run(h, -1, 0, Helm.RAMP / 2)
		t.expect(math.abs(h + 0.5) < 0.02).toBe(true)
	end)

	t.test("less lock at speed", function()
		t.expect(math.abs(run(0, 1, 1, 2) - Helm.AT_SPEED) < 1e-6).toBe(true)
		t.expect(run(0, 1, 0.5, 2) > Helm.AT_SPEED).toBe(true)
		-- slowing down while the key is held lets the helm out again
		t.expect(math.abs(run(Helm.AT_SPEED, 1, 0, 2) - 1) < 1e-6).toBe(true)
	end)
end
