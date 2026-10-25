-- Waves: the shared wave field must be deterministic, smooth and storm-scaled.
return function(t)
	local Waves = t.load("src/shared/Waves.luau")
	local T0 = 1760000000.25 -- a realistic workspace:GetServerTimeNow() value

	local calm = Waves.paramsFor(0, 0, 0)
	local storm = Waves.paramsFor(1, 0, 0)

	t.test("same inputs give the same height (determinism)", function()
		local again = Waves.paramsFor(0.37, 0.2, 1.1)
		local params = Waves.paramsFor(0.37, 0.2, 1.1)
		for i = 0, 20 do
			local x, z, time = i * 13.7 - 120, i * -9.1 + 40, T0 + i * 0.37
			t.expect(Waves.heightAt(x, z, time, params)).toBe(Waves.heightAt(x, z, time, again))
		end
	end)

	t.test("height is continuous in space and time", function()
		local eps = 1e-3
		for _, params in { calm, storm } do
			local maxStep = 0
			for i = 0, 50 do
				local x, z, time = i * 7.3, i * -3.9, T0 + i
				local h = Waves.heightAt(x, z, time, params)
				maxStep = math.max(
					maxStep,
					math.abs(Waves.heightAt(x + eps, z, time, params) - h),
					math.abs(Waves.heightAt(x, z + eps, time, params) - h),
					math.abs(Waves.heightAt(x, z, time + eps, params) - h)
				)
			end
			t.expect(maxStep < 0.01).toBeTruthy()
		end
	end)

	t.test("ramping intensity never jumps the surface", function()
		local a = Waves.paramsFor(0.5, 0, 0.3)
		local b = Waves.paramsFor(0.5001, 0, 0.3)
		for i = 0, 20 do
			local x, z = i * 37 - 300, i * 21 - 200
			local d = Waves.heightAt(x, z, T0, a) - Waves.heightAt(x, z, T0, b)
			t.expect(math.abs(d) < 0.01).toBeTruthy()
		end
		for i = 1, Waves.COUNT do
			local c, s = Waves.CALM[i], Waves.STORM[i]
			t.expect(c.speed / c.wavelength).toBeCloseTo(s.speed / s.wavelength, 1e-3)
		end
	end)

	t.test("normal is unit length and points up", function()
		for _, params in { calm, storm, Waves.paramsFor(0.6, 0.5, 2) } do
			for i = 0, 30 do
				local _, n = Waves.sampleAt(i * 11.1, i * -5.3, T0 + i * 0.5, params)
				t.expect(n.Magnitude).toBeCloseTo(1, 1e-6)
				t.expect(n.Y > 0.5).toBeTruthy()
			end
		end
	end)

	t.test("normal matches the numeric slope", function()
		-- small t here: finite differences at T0 (~1.7e9) lose precision in the phase
		local d = 1e-4
		for i = 0, 10 do
			local x, z, time = i * 9.7, i * 4.1, i * 0.7
			local _, n = Waves.sampleAt(x, z, time, storm)
			local gx = (
				Waves.heightAt(x + d, z, time, storm) - Waves.heightAt(x - d, z, time, storm)
			) / (2 * d)
			local gz = (
				Waves.heightAt(x, z + d, time, storm) - Waves.heightAt(x, z - d, time, storm)
			) / (2 * d)
			t.expect(-n.X / n.Y).toBeCloseTo(gx, 1e-3)
			t.expect(-n.Z / n.Y).toBeCloseTo(gz, 1e-3)
		end
	end)

	t.test("calm amplitude is below storm amplitude, and shelter damps storms", function()
		t.expect(Waves.maxAmplitude(calm) < Waves.maxAmplitude(storm)).toBeTruthy()
		local peakCalm, peakStorm = 0, 0
		for i = 0, 400 do
			local x, z, time = i * 3.7, i * 2.3, T0 + i * 0.1
			peakCalm = math.max(peakCalm, math.abs(Waves.heightAt(x, z, time, calm)))
			peakStorm = math.max(peakStorm, math.abs(Waves.heightAt(x, z, time, storm)))
		end
		t.expect(peakCalm < peakStorm).toBeTruthy()
		t.expect(peakCalm <= Waves.maxAmplitude(calm) + 1e-9).toBeTruthy()
		local shelteredStorm = Waves.paramsFor(1, 0.8, 0)
		t.expect(Waves.maxAmplitude(shelteredStorm) < Waves.maxAmplitude(calm)).toBeTruthy()
	end)

	t.test("heightAt equals sampleAt height (and gradientAt height)", function()
		for _, params in { calm, storm, Waves.paramsFor(0.25, 0.4, -1) } do
			for i = 0, 30 do
				local x, z, time = i * 17.3 - 200, i * 6.7, T0 + i * 1.3
				local h = Waves.heightAt(x, z, time, params)
				local hs = Waves.sampleAt(x, z, time, params)
				local hg = Waves.gradientAt(x, z, time, params)
				t.expect(hs).toBe(h)
				t.expect(hg).toBe(h)
			end
		end
	end)

	t.test("heightAt is fast", function()
		local n = 100000
		local start = os.clock()
		local acc = 0
		for i = 1, n do
			acc += Waves.heightAt(i * 0.37, i * 0.11, T0 + i * 0.001, storm)
		end
		local elapsed = os.clock() - start
		t.expect(acc == acc).toBeTruthy() -- not NaN
		t.expectFast(elapsed, 0.5, "100k heightAt calls") -- 2x headroom: ~0.2 s normally, 0.26 s seen when parallel builders load the machine
	end)
end
