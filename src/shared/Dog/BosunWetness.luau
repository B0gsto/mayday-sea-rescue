--!strict
-- BosunWetness: how soaked Bosun's coat is (0 dry .. 1 dripping), pure logic (tests/BosunMotion.spec.luau).
-- DogService steps it a few times a second and swaps the wet SurfaceAppearances (AssetLoader.setWet)
-- through the hysteresis in isWet, so the coat doesn't flicker at the threshold.
--   * in the water he is soaked within a couple of seconds;
--   * rain soaks him gradually (full storm rain: about 40 s to the wet look), never past RAIN_MAX;
--   * out of the water and the rain he dries over DRY_SECONDS (a Newfoundland's double coat is slow);
--   * climbing out he shakes off SHAKE_LOSS at once (DogController plays the shake).
local BosunWetness = {}

BosunWetness.SOAK_SECONDS = 1.5 -- water: dry to soaked
BosunWetness.RAIN_SECONDS = 40 -- full rain: dry to RAIN_MAX
BosunWetness.RAIN_MAX = 0.85
BosunWetness.DRY_SECONDS = 150 -- soaked to dry, out of the rain
BosunWetness.SHAKE_LOSS = 0.2
BosunWetness.WET_ON = 0.35 -- dry look -> wet look above this
BosunWetness.WET_OFF = 0.12 -- wet look -> dry look below this

export type Exposure = {
	submerged: boolean, -- swimming or standing in the sea
	rain: number, -- 0..1 rain on him (0 when sheltered)
}

-- The wetness after `dt` seconds of `exposure`.
function BosunWetness.step(wetness: number, dt: number, exposure: Exposure): number
	local w = math.clamp(wetness, 0, 1)
	if dt <= 0 then
		return w
	end
	if exposure.submerged then
		return math.min(1, w + dt / BosunWetness.SOAK_SECONDS)
	end
	local rain = math.clamp(exposure.rain, 0, 1)
	if rain > 0.05 then
		local cap = BosunWetness.RAIN_MAX * rain
		if w < cap then
			return math.min(cap, w + dt * rain * BosunWetness.RAIN_MAX / BosunWetness.RAIN_SECONDS)
		end
		return w -- already wetter than this rain makes him: no drying while it rains
	end
	return math.max(0, w - dt / BosunWetness.DRY_SECONDS)
end

-- The shake on climbing out of the water.
function BosunWetness.shake(wetness: number): number
	return math.max(0, wetness - BosunWetness.SHAKE_LOSS)
end

-- Whether the wet look shows, given whether it showed last time (hysteresis).
function BosunWetness.isWet(wasWet: boolean, wetness: number): boolean
	if wasWet then
		return wetness > BosunWetness.WET_OFF
	end
	return wetness >= BosunWetness.WET_ON
end

return BosunWetness
