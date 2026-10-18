--!strict
-- HarbourLightBeam: the Harbour Light's Fl(2) W 10s character (art/reference/M_Bld_HarbourLight/dims.md), pure and
-- unit-tested in tests/Street.spec.luau; drawn by src/client/Controllers/HarbourLightController.luau.
--
-- The real way: a rotating optic of two bullseye pairs, the two panels of a pair 30 degrees apart and the pairs
-- opposite each other, turning once every 20 s (18 deg/s). Each pair sweeps a viewer once per 10 s; its two panels give
-- the two flashes 30 / 18 = 1.67 s apart. A flash lasts about 0.5 s (the beam's 9 degree spread at 18 deg/s).
--
--   HarbourLightBeam.PANELS             panel bearings (degrees) relative to the optic
--   HarbourLightBeam.angle(t)           optic rotation at time t (s), degrees in [0, 360)
--   HarbourLightBeam.intensity(t, b)    0..1 flash seen from bearing b (degrees, same frame as angle)
--   HarbourLightBeam.bearing(dx, dz)    bearing (degrees) of a horizontal offset, matching angle()'s frame
--   HarbourLightBeam.lit(state, base, sunY)  on at night (WeatherBase Night or the sun down) or in a storm

local HarbourLightBeam = {}

HarbourLightBeam.PERIOD = 20 -- s per optic turn (3 rpm)
HarbourLightBeam.RATE = 360 / HarbourLightBeam.PERIOD -- deg/s
HarbourLightBeam.PANELS = { 0, 30, 180, 210 }
HarbourLightBeam.HALF_WIDTH = 4.5 -- deg: 0.5 s flash at 18 deg/s

function HarbourLightBeam.angle(t: number): number
	return (t * HarbourLightBeam.RATE) % 360
end

local function delta(a: number, b: number): number
	local d = (a - b) % 360
	return if d > 180 then 360 - d else d
end

function HarbourLightBeam.intensity(t: number, bearing: number): number
	local rot = HarbourLightBeam.angle(t)
	local best = 0
	for _, p in HarbourLightBeam.PANELS do
		local d = delta(rot + p, bearing) / HarbourLightBeam.HALF_WIDTH
		if d < 1 then
			best = math.max(best, 1 - d * d)
		end
	end
	return best
end

-- Bearing 0 is +X; it grows toward -Z, the sense of CFrame.Angles(0, rad(angle), 0) turning +X.
function HarbourLightBeam.bearing(dx: number, dz: number): number
	return math.deg(math.atan2(-dz, dx)) % 360
end

function HarbourLightBeam.lit(weatherState: string, weatherBase: string?, sunY: number): boolean
	return weatherState == "Storm" or weatherBase == "Night" or sunY < 0
end

return HarbourLightBeam
