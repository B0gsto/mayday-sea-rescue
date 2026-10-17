--!strict
-- WeatherMath: the pure, deterministic parts of the weather (no services, safe in Lune tests).
-- Weather.luau wraps these with the live attributes on ReplicatedStorage.Weather; StormService
-- uses the same timings and wind / lightning seeds, so server and every client agree.
--
--   WeatherMath.intensityFor(state, elapsed, duration)  -- 0..1, smooth (smoothstep ramps)
--   WeatherMath.zoneAt(zones, x, z)                     -- highest-priority zone containing (x, z)
--   WeatherMath.nextState(state)                        -- Calm -> Warning -> Storm -> Clearing -> Calm
--   WeatherMath.durationFor(state, isGreat, stormConfig)
--   WeatherMath.windForStorm(stormId)                   -- radians, changes every storm
--   WeatherMath.lightningStrikes(stormId, duration)     -- { {time, angle, distance} } seeded per storm

export type State = "Calm" | "Warning" | "Storm" | "Clearing"

export type ZoneLike = {
	id: string,
	center: Vector3,
	radius: number,
	shelter: number,
	priority: number,
}

export type StormTimings = {
	CalmSeconds: number,
	WarningSeconds: number,
	StormSeconds: number,
	ClearingSeconds: number,
	GreatStormSeconds: number,
}

export type Strike = {
	time: number, -- seconds after the Storm state starts
	angle: number, -- radians around the viewer
	distance: number, -- studs from the viewer
}

local TAU = 2 * math.pi

local WeatherMath = {}

WeatherMath.STATES = table.freeze({ "Calm", "Warning", "Storm", "Clearing" } :: { State })

-- Lightning: gaps between strikes in seconds. The minimum gap keeps flashes far apart
-- (accessibility: never more than one flash every few seconds). -- tune
WeatherMath.STRIKE_MIN_GAP = 6
WeatherMath.STRIKE_MAX_GAP = 16
WeatherMath.STRIKE_MIN_DISTANCE = 250 -- studs -- tune
WeatherMath.STRIKE_MAX_DISTANCE = 1400 -- studs -- tune

local NEXT: { [string]: State } = {
	Calm = "Warning",
	Warning = "Storm",
	Storm = "Clearing",
	Clearing = "Calm",
}

function WeatherMath.isState(value: any): boolean
	return value == "Calm" or value == "Warning" or value == "Storm" or value == "Clearing"
end

-- Smooth 0..1 ease (zero slope at both ends), so lighting and waves never jerk.
function WeatherMath.smoothstep(x: number): number
	local t = math.clamp(x, 0, 1)
	return t * t * (3 - 2 * t)
end

-- Storm intensity for a state that has run `elapsed` seconds of `duration`.
-- Ramps up across Warning, holds 1 in Storm, ramps down across Clearing, 0 in Calm.
function WeatherMath.intensityFor(state: string, elapsed: number, duration: number): number
	if state == "Storm" then
		return 1
	end
	local progress = if duration > 0 then elapsed / duration else 1
	if state == "Warning" then
		return WeatherMath.smoothstep(progress)
	elseif state == "Clearing" then
		return 1 - WeatherMath.smoothstep(progress)
	end
	return 0
end

function WeatherMath.nextState(state: string): State
	return NEXT[state] or "Calm"
end

function WeatherMath.durationFor(state: string, isGreat: boolean, timings: StormTimings): number
	if state == "Warning" then
		return timings.WarningSeconds
	elseif state == "Storm" then
		return if isGreat then timings.GreatStormSeconds else timings.StormSeconds
	elseif state == "Clearing" then
		return timings.ClearingSeconds
	end
	return timings.CalmSeconds
end

-- The zone containing (x, z) with the highest priority, or nil for open sea.
-- Ties keep the earlier zone in the list (GameConfig orders zones most specific first).
function WeatherMath.zoneAt(zones: { ZoneLike }, x: number, z: number): ZoneLike?
	local best: ZoneLike? = nil
	for _, zone in zones do
		local dx, dz = x - zone.center.X, z - zone.center.Z
		if dx * dx + dz * dz <= zone.radius * zone.radius then
			if best == nil or zone.priority > best.priority then
				best = zone
			end
		end
	end
	return best
end

-- Deterministic PRNG (mulberry32 on 32-bit integers). Same seed, same sequence on every
-- machine, unlike math.random. Returns a function giving floats in [0, 1).
function WeatherMath.rng(seed: number): () -> number
	local s = bit32.band(math.floor(seed) * 2654435761 + 1013904223, 0xFFFFFFFF)
	local function mul(a: number, b: number): number
		-- 32-bit multiply without losing precision in doubles: split b into 16-bit halves.
		local lo = bit32.band(b, 0xFFFF)
		local hi = bit32.rshift(b, 16)
		return bit32.band(a * lo + bit32.band(a * hi, 0xFFFF) * 65536, 0xFFFFFFFF)
	end
	return function(): number
		s = bit32.band(s + 0x6D2B79F5, 0xFFFFFFFF)
		local t = mul(bit32.bxor(s, bit32.rshift(s, 15)), bit32.bor(s, 1))
		t = bit32.bxor(
			t,
			(t + mul(bit32.bxor(t, bit32.rshift(t, 7)), bit32.bor(t, 61))) % 4294967296
		)
		return bit32.bxor(t, bit32.rshift(t, 14)) / 4294967296
	end
end

-- Wind direction (radians, 0..2pi) for a storm. Differs storm to storm, identical everywhere.
function WeatherMath.windForStorm(stormId: number): number
	local nextFloat = WeatherMath.rng(stormId * 7919 + 17)
	return nextFloat() * TAU
end

-- Lightning strikes for one Storm phase, seeded by StormId so every client sees the same ones.
-- Times are seconds after the Storm state starts; the first strike waits one minimum gap.
function WeatherMath.lightningStrikes(stormId: number, duration: number): { Strike }
	local nextFloat = WeatherMath.rng(stormId * 104729 + 3)
	local strikes: { Strike } = {}
	local minGap, maxGap = WeatherMath.STRIKE_MIN_GAP, WeatherMath.STRIKE_MAX_GAP
	local t = minGap + nextFloat() * (maxGap - minGap) * 0.5
	while t < duration - 2 do
		table.insert(strikes, {
			time = t,
			angle = nextFloat() * TAU,
			distance = WeatherMath.STRIKE_MIN_DISTANCE
				+ nextFloat()
					* (WeatherMath.STRIKE_MAX_DISTANCE - WeatherMath.STRIKE_MIN_DISTANCE),
		})
		t += minGap + nextFloat() * (maxGap - minGap)
	end
	return strikes
end

-- Quantises an intensity so wave params can be cached: 1/1024 steps move the surface by far
-- less than a millimetre-equivalent stud, but let every caller in a frame share one table.
function WeatherMath.quantize(intensity: number): number
	return math.floor(math.clamp(intensity, 0, 1) * 1024 + 0.5) / 1024
end

return WeatherMath
