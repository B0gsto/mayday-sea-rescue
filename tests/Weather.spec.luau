-- Weather: storm intensity, zones, wave params and the deterministic storm seeds.
return function(t)
	local WeatherMath = t.load("src/shared/WeatherMath.luau")
	local Weather = t.load("src/shared/Weather.luau")
	local Waves = t.require("Waves")
	local GameConfig = t.require("Config/GameConfig")
	local T0 = 1760000000.25

	t.test("defaults to Calm with intensity 0 before the server folder exists", function()
		t.expect(Weather.getState()).toBe("Calm")
		t.expect(Weather.getIntensity(T0)).toBe(0)
		local params = Weather.getWaveParams(Vector3.new(0, 0, 2000), T0)
		t.expect(params.intensity).toBe(0)
	end)

	t.test("intensity ramps smoothly and stays in 0..1", function()
		t.expect(WeatherMath.intensityFor("Calm", 30, 600)).toBe(0)
		t.expect(WeatherMath.intensityFor("Warning", 0, 60)).toBe(0)
		t.expect(WeatherMath.intensityFor("Warning", 30, 60)).toBeCloseTo(0.5, 1e-9)
		t.expect(WeatherMath.intensityFor("Warning", 60, 60)).toBe(1)
		t.expect(WeatherMath.intensityFor("Storm", 10, 180)).toBe(1)
		t.expect(WeatherMath.intensityFor("Clearing", 0, 60)).toBe(1)
		t.expect(WeatherMath.intensityFor("Clearing", 60, 60)).toBe(0)
		for _, state in { "Warning", "Clearing" } do
			local prev = WeatherMath.intensityFor(state, 0, 60)
			for i = 1, 600 do
				local v = WeatherMath.intensityFor(state, i * 0.1, 60)
				t.expect(v >= 0 and v <= 1).toBeTruthy()
				t.expect(math.abs(v - prev) < 0.01).toBeTruthy()
				prev = v
			end
		end
	end)

	t.test("state cycle and durations follow GameConfig", function()
		local s = GameConfig.Storm
		t.expect(WeatherMath.nextState("Calm")).toBe("Warning")
		t.expect(WeatherMath.nextState("Warning")).toBe("Storm")
		t.expect(WeatherMath.nextState("Storm")).toBe("Clearing")
		t.expect(WeatherMath.nextState("Clearing")).toBe("Calm")
		t.expect(WeatherMath.durationFor("Storm", false, s)).toBe(s.StormSeconds)
		t.expect(WeatherMath.durationFor("Storm", true, s)).toBe(s.GreatStormSeconds)
		t.expect(WeatherMath.durationFor("Calm", false, s)).toBe(s.CalmSeconds)
	end)

	t.test("zones resolve by priority, open sea outside", function()
		t.expect(Weather.getZoneAt(Vector3.new(0, 0, 368)).id).toBe("HarbourMouth")
		t.expect(Weather.getZoneAt(Vector3.new(0, 0, -60)).id).toBe("PortHaven")
		t.expect(Weather.getZoneAt(Vector3.new(0, 0, 190)).id).toBe("CalmBay")
		local open = Weather.getZoneAt(Vector3.new(1500, 0, 1500))
		t.expect(open.id).toBe("OpenSea")
		t.expect(open.shelter).toBe(0)
	end)

	t.test("live state from attributes drives intensity, waves and the changed signal", function()
		local seen = {}
		local connection = Weather.changed:Connect(function(state)
			table.insert(seen, state)
		end)
		Weather._apply({
			State = "Warning",
			StateStartTime = T0,
			StateDuration = 60,
			WindDirection = 1.2,
		})
		t.expect(Weather.getState()).toBe("Warning")
		t.expect(Weather.getIntensity(T0 + 30)).toBeCloseTo(0.5, 1e-9)
		Weather._apply({ State = "Storm", StateStartTime = T0 + 60, StateDuration = 180 })
		Weather._apply({ State = "Storm" }) -- same state again: no extra event
		t.expect(#seen).toBe(2)
		t.expect(seen[2]).toBe("Storm")
		connection:Disconnect()
		Weather._apply({ State = "Bogus" }) -- invalid values are ignored
		t.expect(Weather.getState()).toBe("Storm")

		local now = T0 + 100
		local sea = Vector3.new(1500, 0, 1500)
		local bay = Vector3.new(0, 0, 190)
		local openParams = Weather.getWaveParams(sea, now)
		t.expect(openParams.intensity).toBe(1)
		t.expect(Weather.getWaveParams(sea, now + 0.016)).toBe(openParams) -- cached
		t.expect(
			Waves.maxAmplitude(Weather.getWaveParams(bay, now)) < Waves.maxAmplitude(openParams)
		)
			.toBeTruthy()
		local expected = Waves.heightAt(sea.X, sea.Z, now, Waves.paramsFor(1, 0, 1.2))
		t.expect(Weather.heightAt(sea, now)).toBeCloseTo(expected, 1e-9)
		Weather._apply({ State = "Calm", StateStartTime = T0 + 400, StateDuration = 600 })
		t.expect(Weather.getIntensity(T0 + 500)).toBe(0)
	end)

	t.test("wind and lightning are deterministic per storm", function()
		t.expect(WeatherMath.windForStorm(5)).toBe(WeatherMath.windForStorm(5))
		t.expect(WeatherMath.windForStorm(5) ~= WeatherMath.windForStorm(6)).toBeTruthy()
		for id = 1, 20 do
			local w = WeatherMath.windForStorm(id)
			t.expect(w >= 0 and w < 2 * math.pi).toBeTruthy()
		end
		local a = WeatherMath.lightningStrikes(42, 180)
		local b = WeatherMath.lightningStrikes(42, 180)
		t.expect(#a > 5).toBeTruthy()
		t.expect(a).toEqual(b)
		local prev = 0
		for _, strike in a do
			t.expect(strike.time - prev >= WeatherMath.STRIKE_MIN_GAP - 1e-9).toBeTruthy()
			t.expect(strike.time < 180).toBeTruthy()
			t.expect(strike.distance >= WeatherMath.STRIKE_MIN_DISTANCE).toBeTruthy()
			prev = strike.time
		end
		t.expect(WeatherMath.lightningStrikes(43, 180)[1].time ~= a[1].time).toBeTruthy()
	end)

	t.test("rng is in [0, 1) and well spread", function()
		local nextFloat = WeatherMath.rng(1234)
		local sum = 0
		for _ = 1, 2000 do
			local v = nextFloat()
			t.expect(v >= 0 and v < 1).toBeTruthy()
			sum += v
		end
		t.expect(math.abs(sum / 2000 - 0.5) < 0.05).toBeTruthy()
	end)
end
