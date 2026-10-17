--!strict
-- Waves: the one shared, deterministic ocean height field. Physics (buoyancy, swimmers, the dog)
-- and the client ocean renderer both use it, so what you see is what you float on.
--
--   local params = Waves.paramsFor(intensity, zoneShelter, windAngle)  -- once per frame / state change
--   local y = Waves.heightAt(x, z, workspace:GetServerTimeNow(), params)
--   local y, normal = Waves.sampleAt(x, z, t, params)
--   local y, dydx, dydz = Waves.gradientAt(x, z, t, params)           -- allocation-free slope
--
-- Model: a sum of Waves.COUNT directional sine waves around sea level Y = 0:
--   y(x, z, t) = SEA_LEVEL + sum_i A_i * sin(k_i * (d_i . (x, z)) - w_i * t + phase_i)
-- heightAt and gradientAt allocate nothing; sampleAt only builds the returned Vector3.
-- Returned heights are world Y.
--
-- Storm blend: paramsFor lerps every wave between the CALM and STORM sets (amplitude, wavelength,
-- speed, direction) by the effective intensity = intensity * (1 - shelter). Each slot keeps
-- speed / wavelength equal in both sets, so the angular frequency w_i does not change with
-- intensity: ramping a storm never makes the wave phase jump, even at large server times.
-- Shelter (0 open sea .. 1 harbour) also damps the amplitude, so Calm Bay stays gentle.
-- Wind angle (radians) rotates the whole set: direction (cos a, sin a) in the XZ plane.

export type WaveSpec = {
	amplitude: number, -- studs
	wavelength: number, -- studs
	speed: number, -- phase speed, studs/s
	angle: number, -- radians, relative to the wind direction
	phase: number, -- radians
}

-- Struct of arrays so heightAt is a tight loop with no table lookups by name per wave.
export type WaveParams = {
	count: number,
	intensity: number, -- effective storm intensity after shelter, 0..1
	amplitude: { number },
	k: { number }, -- wavenumber 2*pi / wavelength
	omega: { number }, -- angular frequency k * speed
	dirX: { number },
	dirZ: { number },
	phase: { number },
}

local TAU = 2 * math.pi
local sin = math.sin
local cos = math.cos

local Waves = {}

Waves.SEA_LEVEL = 0
Waves.COUNT = 4
-- How much full shelter scales amplitude down (on top of cancelling the storm blend). -- tune
Waves.SHELTER_DAMPING = 0.6

-- Calm swell: about 1.25 studs total amplitude. -- tune
Waves.CALM = table.freeze({
	table.freeze({ amplitude = 0.6, wavelength = 64, speed = 8, angle = 0, phase = 0 }),
	table.freeze({ amplitude = 0.35, wavelength = 37, speed = 6.2, angle = 0.45, phase = 1.3 }),
	table.freeze({ amplitude = 0.2, wavelength = 23, speed = 4.9, angle = -0.6, phase = 2.9 }),
	table.freeze({ amplitude = 0.1, wavelength = 14, speed = 3.8, angle = 1.1, phase = 4.4 }),
} :: { WaveSpec })

-- Storm sea: about 2.7x calm amplitude (docs 02: waves x2.5), longer and more wind-aligned.
-- Keep speed / wavelength equal to the CALM slot (see the header). -- tune
Waves.STORM = table.freeze({
	table.freeze({ amplitude = 1.7, wavelength = 128, speed = 16, angle = 0, phase = 0 }),
	table.freeze({ amplitude = 0.95, wavelength = 74, speed = 12.4, angle = 0.25, phase = 1.3 }),
	table.freeze({ amplitude = 0.5, wavelength = 46, speed = 9.8, angle = -0.35, phase = 2.9 }),
	table.freeze({ amplitude = 0.25, wavelength = 28, speed = 7.6, angle = 0.7, phase = 4.4 }),
} :: { WaveSpec })

local function lerp(a: number, b: number, alpha: number): number
	return a + (b - a) * alpha
end

-- Builds wave params for a storm intensity (0 calm .. 1 full storm), a zone shelter
-- (0 open sea .. 1 fully sheltered, default 0) and a wind angle in radians (default 0 = +X).
-- Allocates: call it when the weather changes or once per frame, not per sample.
function Waves.paramsFor(intensity: number, zoneShelter: number?, windAngle: number?): WaveParams
	local shelter = math.clamp(zoneShelter or 0, 0, 1)
	local e = math.clamp(intensity, 0, 1) * (1 - shelter)
	local ampScale = 1 - Waves.SHELTER_DAMPING * shelter
	local wind = windAngle or 0
	local n = Waves.COUNT
	local params: WaveParams = {
		count = n,
		intensity = e,
		amplitude = table.create(n, 0),
		k = table.create(n, 0),
		omega = table.create(n, 0),
		dirX = table.create(n, 0),
		dirZ = table.create(n, 0),
		phase = table.create(n, 0),
	}
	for i = 1, n do
		local calm, storm = Waves.CALM[i], Waves.STORM[i]
		local k = TAU / lerp(calm.wavelength, storm.wavelength, e)
		local angle = wind + lerp(calm.angle, storm.angle, e)
		params.amplitude[i] = lerp(calm.amplitude, storm.amplitude, e) * ampScale
		params.k[i] = k
		params.omega[i] = k * lerp(calm.speed, storm.speed, e)
		params.dirX[i] = cos(angle)
		params.dirZ[i] = sin(angle)
		params.phase[i] = calm.phase
	end
	return params
end

-- World Y of the water surface at (x, z) at time t (seconds, use workspace:GetServerTimeNow()).
function Waves.heightAt(x: number, z: number, t: number, params: WaveParams): number
	local amp, k, omega = params.amplitude, params.k, params.omega
	local dirX, dirZ, phase = params.dirX, params.dirZ, params.phase
	local h = 0
	for i = 1, params.count do
		h += amp[i] * sin(k[i] * (dirX[i] * x + dirZ[i] * z) - omega[i] * t + phase[i])
	end
	return Waves.SEA_LEVEL + h
end

-- Height plus the surface slope (dY/dX, dY/dZ). Allocation-free; use it in hot physics loops.
function Waves.gradientAt(
	x: number,
	z: number,
	t: number,
	params: WaveParams
): (number, number, number)
	local amp, k, omega = params.amplitude, params.k, params.omega
	local dirX, dirZ, phase = params.dirX, params.dirZ, params.phase
	local h, gx, gz = 0, 0, 0
	for i = 1, params.count do
		local theta = k[i] * (dirX[i] * x + dirZ[i] * z) - omega[i] * t + phase[i]
		local a = amp[i]
		h += a * sin(theta)
		local slope = a * k[i] * cos(theta)
		gx += slope * dirX[i]
		gz += slope * dirZ[i]
	end
	return Waves.SEA_LEVEL + h, gx, gz
end

-- Height and the unit surface normal at (x, z, t).
function Waves.sampleAt(x: number, z: number, t: number, params: WaveParams): (number, Vector3)
	local h, gx, gz = Waves.gradientAt(x, z, t, params)
	local inv = 1 / math.sqrt(gx * gx + 1 + gz * gz)
	return h, Vector3.new(-gx * inv, inv, -gz * inv)
end

-- Upper bound on |height - SEA_LEVEL| for these params (sum of amplitudes).
function Waves.maxAmplitude(params: WaveParams): number
	local total = 0
	for i = 1, params.count do
		total += params.amplitude[i]
	end
	return total
end

return Waves
