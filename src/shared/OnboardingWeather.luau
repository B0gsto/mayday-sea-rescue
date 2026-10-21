--!strict
-- OnboardingWeather: how a new player's local weather holds calm through the cold open and blends
-- back into the server's weather once it ends (G81). Pure, Lune-tested (tests/OnboardingWeather.spec.luau).
--
-- `active` is the ColdOpenActive player attribute; `done` is ColdOpenDone; `age` is seconds since
-- the client started. target() covers the join race (the cold open starts a moment after spawn)
-- without leaving a brand-new profile calm forever if it never starts.
--
-- The client (WeatherController) turns the calm level into Lighting attribute
-- LocalStormIntensity, which the ocean, boat physics and audio read instead of
-- Weather.getIntensity, so the whole local scene agrees on the held sea.

local OnboardingWeather = {}

OnboardingWeather.BLEND = 5 -- s the sea eases back to the server's storm after the cold open
OnboardingWeather.PENDING = 10 -- s a not-yet-done profile counts as "cold open about to start"

-- 1 = fully calm, 0 = the server's weather.
function OnboardingWeather.target(active: boolean, done: boolean, age: number): number
	if active or (not done and age < OnboardingWeather.PENDING) then
		return 1
	end
	return 0
end

-- Move `level` toward `target` at BLEND seconds for a full 1 -> 0 change (linear, clamped).
function OnboardingWeather.step(level: number, target: number, dt: number): number
	local from = math.clamp(level, 0, 1)
	local to = math.clamp(target, 0, 1)
	local move = math.max(dt, 0) / OnboardingWeather.BLEND
	local d = to - from
	if math.abs(d) <= move then
		return to
	end
	return from + (if d > 0 then move else -move)
end

-- The storm intensity this client should use.
function OnboardingWeather.localIntensity(server: number, level: number): number
	return math.clamp(server, 0, 1) * (1 - math.clamp(level, 0, 1))
end

return OnboardingWeather
