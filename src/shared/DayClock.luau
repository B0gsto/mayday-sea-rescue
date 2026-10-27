--!strict
-- DayClock (docs/25 G): the shared day/night cycle. Lighting.ClockTime is a function of the server time (plus the
-- dev offset, Workspace attribute DayClockOffset), so the server and every client agree; StormService writes it every
-- 0.5 s (it replicates) and WeatherController blends the looks by it. One 20 min cycle: a 90 s dawn, a 14 min day that
-- lingers round midday (the approved Clear look), a 90 s warm dusk and a 3 min moonlit night. Pure.

local DayClock = {}

-- (seconds into the cycle, ClockTime); linear between keys, hours past 24 wrap. -- tune
DayClock.KEYS = {
	{ 0, 5 }, -- dawn
	{ 90, 7.5 }, -- day
	{ 210, 10 },
	{ 810, 15 },
	{ 930, 17 }, -- dusk
	{ 1020, 19.5 }, -- night
	{ 1200, 29 }, -- 05:00, the next dawn
}
DayClock.CYCLE = 1200
DayClock.ON = true -- false: always midday (the pre-2026-10-27 always-sunny look), one switch for the whole cycle
DayClock.NOON = 12.5

function DayClock.clockTime(t: number): number
	if not DayClock.ON then
		return DayClock.NOON
	end
	local s = t % DayClock.CYCLE
	local keys = DayClock.KEYS
	for i = 2, #keys do
		local a, b = keys[i - 1], keys[i]
		if s < b[1] then
			return (a[2] + (b[2] - a[2]) * (s - a[1]) / (b[1] - a[1])) % 24
		end
	end
	return keys[1][2]
end

-- The offset (seconds) that puts the clock at `hour` now (the dev "clock" action).
function DayClock.offsetTo(t: number, hour: number): number
	local keys = DayClock.KEYS
	for i = 2, #keys do
		local a, b = keys[i - 1], keys[i]
		for _, h in { hour, hour + 24 } do
			if h >= a[2] and h < b[2] then
				local s = a[1] + (b[1] - a[1]) * (h - a[2]) / (b[2] - a[2])
				return (s - t) % DayClock.CYCLE
			end
		end
	end
	return 0
end

local function smoothstep(e0: number, e1: number, x: number): number
	local u = math.clamp((x - e0) / (e1 - e0), 0, 1)
	return u * u * (3 - 2 * u)
end

-- 0..1: how far the day look leans to golden hour (LightingPresets.Calm). 0 from 09:00 to 15:30, so the midday look
-- is exactly the approved one; the Night blend (by the sun) takes over after dusk.
function DayClock.warmth(clockTime: number): number
	return if clockTime >= 12
		then smoothstep(15.5, 17.25, clockTime)
		else 1 - smoothstep(7.25, 9, clockTime)
end

return DayClock
