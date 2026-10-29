--!strict
-- AudioMix: the pure mixing maths behind AudioController (Lune-tested in tests/AudioMix.spec.luau).
-- Engines layered by RPM, wind and sea beds by storm intensity, hull impacts by slam strength.

local AudioMix = {}

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Equal-power crossfade: t = 0 -> (1, 0), t = 1 -> (0, 1), constant summed power.
function AudioMix.crossfade(t: number): (number, number)
	local x = clamp01(t) * math.pi * 0.5
	return math.cos(x), math.sin(x)
end

AudioMix.IDLE_RPM = 0.14 -- normalised idle

-- Target normalised RPM (idle..1) of a waterjet or outboard. The prop or impeller slips at low
-- speed, so RPM follows the throttle more than the hull speed; it over-revs when the intake or
-- prop leaves the water (contact low, throttle open).
function AudioMix.boatTargetRpm(throttle: number, speedFrac: number, contact: number): number
	local thr = clamp01(math.abs(throttle))
	local spd = clamp01(math.abs(speedFrac))
	local rpm = AudioMix.IDLE_RPM
		+ (1 - AudioMix.IDLE_RPM) * (0.72 * thr + 0.28 * spd * thr + 0.18 * spd)
	if thr > 0.3 and contact < 0.35 then
		rpm += 0.25 * (1 - contact / 0.35) * thr -- airborne / ventilating: the engine flares
	end
	return math.clamp(rpm, AudioMix.IDLE_RPM, 1)
end

-- Engine response: revs rise faster than they fall (inertia and load). Returns the new RPM.
function AudioMix.followRpm(current: number, target: number, dt: number): number
	local rate = if target > current then 5 else 2.2
	local k = 1 - math.exp(-rate * math.max(dt, 0))
	return current + (target - current) * k
end

export type EngineLayers = {
	low: number, -- volume factor of the low / idle layer
	high: number, -- volume factor of the high layer
	lowPitch: number,
	highPitch: number,
}

-- Two-layer engine: the low layer carries idle and cruise, the high layer takes over past ~55%
-- RPM. Pitch scales each layer around its recorded RPM; throttle (load) adds level.
function AudioMix.engineLayers(rpm: number, throttle: number): EngineLayers
	local r = clamp01(rpm)
	local t = clamp01((r - 0.35) / 0.45)
	local low, high = AudioMix.crossfade(t)
	local load = 0.7 + 0.3 * clamp01(math.abs(throttle))
	return {
		low = low * load,
		high = high * load,
		lowPitch = lerp(0.82, 1.3, clamp01(r / 0.8)),
		highPitch = lerp(0.8, 1.18, clamp01((r - 0.35) / 0.65)),
	}
end

export type WindLayers = { light: number, strong: number, gale: number }

-- Wind layers from the storm intensity (0..1) and the apparent wind from the player's own speed
-- (studs/s): standing on a planing RIB in a calm is still a fresh breeze in the ears.
function AudioMix.wind(intensity: number, apparentSpeed: number): WindLayers
	local i = clamp01(intensity)
	local rush = clamp01(math.abs(apparentSpeed) / 70)
	local e = clamp01(i + 0.45 * rush * (1 - i))
	local light = 0.45 + 0.55 * clamp01(1 - math.abs(e - 0.2) / 0.5)
	if e > 0.7 then
		light *= clamp01(1 - (e - 0.7) / 0.3) * 0.6 + 0.4
	end
	local strong = clamp01(1 - math.abs(e - 0.6) / 0.4)
	local gale = clamp01((e - 0.6) / 0.35)
	return { light = light, strong = strong, gale = gale }
end

export type SeaLayers = { harbour: number, open: number, storm: number }

-- Sea beds from the storm intensity, the zone's shelter (0 open sea .. 1 inner harbour) and how
-- close the listener is to the surface (1 at it, 0 high above or inland).
function AudioMix.sea(intensity: number, shelter: number, nearness: number): SeaLayers
	local i = clamp01(intensity)
	local s = clamp01(shelter)
	local n = clamp01(nearness)
	local stormy = clamp01((i - 0.25) / 0.6) * (1 - 0.6 * s)
	return {
		harbour = n * s * (1 - 0.5 * stormy),
		open = n * (1 - s) * (1 - stormy) + n * 0.25 * s,
		storm = n * stormy,
	}
end

-- 1 at the surface, 0 at `fadeHeight` studs above it (and below the surface: 0, underwater
-- uses its own bed).
function AudioMix.nearness(heightAboveSurface: number, fadeHeight: number): number
	if heightAboveSurface < 0 then
		return 0
	end
	return clamp01(1 - heightAboveSurface / math.max(fadeHeight, 1))
end

-- A hull impact from Simulator telemetry.slam (studs/s of vertical impact this step). Returns
-- nil below the threshold, else the volume and pitch (a heavier slam is lower).
function AudioMix.slam(slam: number, threshold: number): (number?, number?)
	if slam < threshold then
		return nil, nil
	end
	local s = clamp01((slam - threshold) / (threshold * 5))
	return 0.35 + 0.65 * s, lerp(1.1, 0.8, s)
end

-- Hull water loops by speed fraction: lapping when slow, bow wash in displacement, wake rush
-- when planing.
function AudioMix.hullWater(speedFrac: number, planing: number): (number, number, number)
	local v = clamp01(math.abs(speedFrac))
	local lap = clamp01(1 - v / 0.15)
	local wash = clamp01(v / 0.15) * clamp01(1 - planing)
	local wake = clamp01(planing) * (0.5 + 0.5 * v)
	return lap, wash, wake
end

-- Seconds until the next random event, given a uniform draw u in [0, 1).
function AudioMix.gap(minGap: number, maxGap: number, u: number): number
	return minGap + (maxGap - minGap) * clamp01(u)
end

-- Gulls go quiet (they sit it out) as a storm builds.
function AudioMix.gullChance(intensity: number): number
	return clamp01(1 - intensity / 0.6)
end

export type MusicState = {
	loading: boolean, -- the loading screen is up
	debrief: boolean,
	operation: boolean, -- a rescue underway
	radio: boolean, -- the driven boat's shanty radio is on: it is the music
	night: boolean,
	nearHome: boolean, -- by the ring islands (AudioMix.nearHome)
}

-- The music cue that should play (nil = none). Event cues first, then the calm ones.
function AudioMix.musicCue(s: MusicState): string?
	if s.loading then
		return "Music_Loading"
	elseif s.debrief then
		return "Music_Debrief"
	elseif s.operation then
		return "Music_Operation"
	elseif s.radio then
		return nil
	elseif s.night and s.nearHome then -- the night bed belongs to the islands; open sea keeps the sea theme
		return "Music_Island_Night"
	end
	return if s.nearHome then "Music_Island_Day" else "Music_Sea"
end

local CALM = { Music_Island_Day = true, Music_Island_Night = true, Music_Sea = true }

-- Minimum hold: a calm cue gives way to another calm cue only after `hold` s, so hovering at a zone
-- edge (or a dawn/dusk change mid-track) doesn't flip the music; event cues and silence switch at once.
function AudioMix.holdCue(current: string?, held: number, want: string?, hold: number): string?
	if current and want and CALM[current] and CALM[want] and held < hold then
		return current
	end
	return want
end

-- Hysteresis on the island / sea edge: inside `enter` studs is near, past `leave` is not.
function AudioMix.nearHome(dist: number, wasNear: boolean, enter: number, leave: number): boolean
	return dist < (if wasNear then leave else enter)
end

return AudioMix
