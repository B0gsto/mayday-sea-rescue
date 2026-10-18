--!strict
-- PyroMath (FX2): pure timing for the distress pyrotechnics drawn by PyroController.
-- Real figures (SOLAS / LSA Code ch. III; Pains Wessex and Ikaros product sheets, verify):
--   red hand flare        15 000 cd, burns 60 s
--   red parachute rocket  30 000 cd, fired to 300 m, burns 40 s, falls at 5 m/s or less
-- 1 m = 3 studs (docs/12 1.4).

local PyroMath = {}

PyroMath.STUDS_PER_M = 3
PyroMath.HAND = table.freeze({
	seconds = 60,
	lightRange = 20, -- studs: the flare lights the hand, the hull and the water round it
	lightBrightness = 6,
})
PyroMath.PARACHUTE = table.freeze({
	apogee = 300 * 3, -- studs above the launch point
	climbSeconds = 6, -- rocket motor to apogee (about 50 m/s average)
	burnSeconds = 40,
	fallSpeed = 5 * 3, -- studs/s under the canopy
	lightRange = 60,
	lightBrightness = 10,
})

-- Height above the launch point at time t (s) after firing, and whether the star is burning.
-- The rocket climbs with an ease-out (motor burn-out, then coast), the star ignites at apogee and
-- drifts down at the canopy speed for its burn time; afterwards it is out.
function PyroMath.parachuteHeight(t: number): (number, boolean)
	local P = PyroMath.PARACHUTE
	if t <= 0 then
		return 0, false
	end
	if t < P.climbSeconds then
		local u = t / P.climbSeconds
		return P.apogee * (1 - (1 - u) * (1 - u)), false
	end
	local burn = t - P.climbSeconds
	local h = math.max(P.apogee - P.fallSpeed * burn, 0)
	return h, burn < P.burnSeconds and h > 0
end

-- Total time from firing until the star is out.
function PyroMath.parachuteSeconds(): number
	local P = PyroMath.PARACHUTE
	return P.climbSeconds + math.min(P.burnSeconds, P.apogee / P.fallSpeed)
end

-- Light flicker factor 0.75..1.15 at time t: two incommensurate sines plus a seeded phase, so
-- several flares never pulse together. Stays well under 3 flashes/s of large change (accessibility).
function PyroMath.flicker(t: number, seed: number): number
	local a = math.sin(t * 13.7 + seed * 1.91)
	local b = math.sin(t * 7.3 + seed * 0.57)
	return 0.95 + 0.12 * a + 0.08 * b
end

return PyroMath
