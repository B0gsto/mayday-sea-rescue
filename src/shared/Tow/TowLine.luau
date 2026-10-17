--!strict
-- TowLine: pure tow physics (docs 09 section 6, steps 6 to 9). No Instances, so the client
-- mechanics (take_strain, tow, alongside) and the server (src/server/Tow/TowMotion) run the same
-- model and tests/MechTow.spec.luau runs it under Lune.
--
-- Everything inside is SI (metres, kg, newtons); the API takes and returns studs (1 m = 3 studs,
-- docs 05 section 4.1) so callers never convert.
--
-- The line is an elastic nylon spring-damper (k = EA / L: a longer line is softer, so it absorbs
-- snatch loads, which is why the tow is stepped out in big seas). It only pulls when taut. A hull
-- that surfs down a wave towards the tug lets the line go slack; when it comes taut again at
-- speed the damper term and the spring overshoot give the snatch load, roughly v * sqrt(k * m).
-- The towed hull is a point mass with a heading: displacement resistance rising steeply past hull
-- speed (1.34 * sqrt(LWL ft) knots), a keel (lateral drag much higher than forward), wind leeway,
-- the wave face pushing it down-slope, and a bow tow point that turns it to follow the line. With
-- no bridle on a single weak point the tow sheers (yaws) under load.
--
-- Tension is reported normalised: 1.0 = the line's working limit. Bands: slack < 0.015, green
-- < 0.7, amber < 0.9, red >= 0.9. The line parts on a spike >= PART_SPIKE or red held RED_HOLD s.

local TowLine = {}

TowLine.STUDS_PER_M = 3
TowLine.GRAVITY = 9.81 -- m/s^2 (Workspace.Gravity 29.43 studs/s^2)
TowLine.KNOT = 0.5144 -- m/s
TowLine.GREEN = 0.7 -- tune
TowLine.AMBER = 0.9 -- tune
TowLine.SLACK = 0.015 -- below this the line hangs in the water
TowLine.PART_SPIKE = 1.15 -- tune
TowLine.RED_HOLD = 1.0 -- seconds, docs 09 step 7 (tune)
TowLine.EA = 134000 -- N, effective axial stiffness of a 14 mm nylon tow line (tune)
TowLine.WORKING_LOAD = 12000 -- N, the "1.0" of the gauge: the weakest link (cleat, worn line)
TowLine.LINE_ZETA = 0.15 -- nylon hysteresis, fraction of critical
TowLine.MAX_SUBSTEP = 1 / 120

local S = TowLine.STUDS_PER_M

export type Env = {
	windX: number?, -- wind velocity, studs/s (the casualty drifts at about 4% of it, leeway)
	windZ: number?,
	slopeX: number?, -- water surface slope dY/dX at the casualty (Waves.gradientAt)
	slopeZ: number?,
}

export type Line = {
	length: number, -- m, hitch to bow
	mass: number, -- kg, towed hull
	lwl: number, -- m
	hullSpeed: number, -- m/s
	bridle: boolean,
	strongPoint: boolean,
	-- hull state (m, m/s, radians; heading is the angle of the hull's forward in XZ: fwd = (sin, cos))
	x: number,
	z: number,
	vx: number,
	vz: number,
	heading: number,
	yawRate: number,
	-- outputs
	distance: number, -- m, hitch to bow
	tensionN: number,
	tension: number, -- normalised
	peak: number,
	slack: boolean,
	redHeld: number,
	snatch: number, -- largest normalised jump this step (0 when none)
	parted: boolean,
	time: number,
}

local function clamp(x: number, a: number, b: number): number
	return if x < a then a elseif x > b then b else x
end

-- Displacement hull speed from the waterline length in studs; returns studs/s.
function TowLine.hullSpeed(lwlStuds: number): number
	local ft = lwlStuds / S * 3.281
	return 1.34 * math.sqrt(math.max(ft, 0)) * TowLine.KNOT * S
end

-- A safe towing speed (studs/s): well under hull speed, slower in a big sea (tune).
function TowLine.safeSpeed(hullSpeedStuds: number, intensity: number): number
	return hullSpeedStuds * (0.8 - 0.35 * clamp(intensity, 0, 1))
end

-- Dominant wavelength (studs) of a Waves.WaveParams: the largest-amplitude component.
function TowLine.dominantWavelength(
	params: { amplitude: { number }, k: { number }, count: number }
): number
	local best, bestAmp = 64, -1
	for i = 1, params.count do
		if params.amplitude[i] > bestAmp and params.k[i] > 0 then
			bestAmp = params.amplitude[i]
			best = 2 * math.pi / params.k[i]
		end
	end
	return best
end

-- Recommended hitch-to-bow length (studs) so both boats ride the same part of the wave: centre
-- spacing a whole number of wavelengths, and never shorter than the minimum for the sea state
-- (about 15 m in a flat calm up to 40 m in a storm, the catenary absorbs the snatch). Tune.
function TowLine.recommendedLength(
	wavelength: number,
	intensity: number,
	towerLength: number,
	casualtyLength: number
): (number, number)
	local minLen = (15 + 25 * clamp(intensity, 0, 1)) * S
	local hulls = (towerLength + casualtyLength) / 2
	local n = math.max(1, math.ceil((minLen + hulls) / math.max(wavelength, 1)))
	return n * wavelength - hulls, n
end

-- How far the boats are out of step: 0 = both on the same phase, 0.5 = one on a crest, the
-- other in a trough. spacing = centre to centre along the wave direction (studs).
function TowLine.stepError(spacing: number, wavelength: number): number
	local f = (spacing / math.max(wavelength, 1)) % 1
	return math.min(f, 1 - f)
end

function TowLine.inStep(spacing: number, wavelength: number): boolean
	return TowLine.stepError(spacing, wavelength) <= 0.12
end

function TowLine.band(t: number): string
	if t < TowLine.SLACK then
		return "slack"
	elseif t < TowLine.GREEN then
		return "green"
	elseif t < TowLine.AMBER then
		return "amber"
	end
	return "red"
end

-- Sag (studs) at the middle of the line, for drawing it: a slack line hangs in a curve and lies
-- in the water; a taut one is nearly straight (catenary w L^2 / 8T, w about 2 N/m wet).
function TowLine.sag(lengthStuds: number, distanceStuds: number, tensionN: number): number
	local L, d = lengthStuds / S, distanceStuds / S
	if d < L then
		return math.sqrt(math.max(0, L * L - d * d)) * 0.5 * S
	end
	return clamp(2 * d * d / (8 * math.max(tensionN, 50)), 0, d * 0.25) * S
end

type LineOpts = {
	lengthStuds: number,
	massKg: number?,
	lwlStuds: number?,
	bridle: boolean?,
	strongPoint: boolean?,
	x: number?, -- hull centre, studs
	z: number?,
	heading: number?,
}

function TowLine.new(o: LineOpts): Line
	local lwl = (o.lwlStuds or 14) / S
	local line: Line = {
		length = math.max(o.lengthStuds / S, 3),
		mass = o.massKg or 1500,
		lwl = lwl,
		hullSpeed = TowLine.hullSpeed(lwl * S) / S,
		bridle = o.bridle == true,
		strongPoint = o.strongPoint ~= false,
		x = (o.x or 0) / S,
		z = (o.z or 0) / S,
		vx = 0,
		vz = 0,
		heading = o.heading or 0,
		yawRate = 0,
		distance = 0,
		tensionN = 0,
		tension = 0,
		peak = 0,
		slack = true,
		redHeld = 0,
		snatch = 0,
		parted = false,
		time = 0,
	}
	return line
end

function TowLine.setLength(line: Line, lengthStuds: number)
	line.length = math.max(lengthStuds / S, 3)
end

-- Steady-tow resistance (N) of the hull at speed v (m/s): rises with the sixth power of the
-- speed-length ratio past hull speed (the hull climbs its own bow wave).
function TowLine.resistance(line: Line, v: number): number
	local r = v / math.max(line.hullSpeed, 0.1)
	return 300 * v * math.abs(v) * (1 + r ^ 6)
end

local function bowOf(line: Line): (number, number)
	local half = line.lwl / 2
	return line.x + math.sin(line.heading) * half, line.z + math.cos(line.heading) * half
end

function TowLine.bowPosition(line: Line): (number, number)
	local bx, bz = bowOf(line)
	return bx * S, bz * S
end

function TowLine.hullPosition(line: Line): (number, number)
	return line.x * S, line.z * S
end

local function substep(
	line: Line,
	hx: number,
	hz: number,
	hvx: number,
	hvz: number,
	dt: number,
	env: Env
)
	local bx, bz = bowOf(line)
	local dx, dz = hx - bx, hz - bz
	local d = math.sqrt(dx * dx + dz * dz)
	local ux, uz = 0, 0
	if d > 1e-4 then
		ux, uz = dx / d, dz / d
	end
	local k = TowLine.EA / line.length
	local stretch = d - line.length
	local force = 0
	if stretch > 0 then
		-- separation rate: the hitch moving away from the bow along the line
		local fwdx, fwdz = math.sin(line.heading), math.cos(line.heading)
		local half = line.lwl / 2
		local bvx = line.vx + line.yawRate * half * fwdz
		local bvz = line.vz - line.yawRate * half * fwdx
		local rate = (hvx - bvx) * ux + (hvz - bvz) * uz
		local c = 2 * TowLine.LINE_ZETA * math.sqrt(k * line.mass)
		force = math.max(0, k * stretch + c * rate)
	end
	line.distance = d
	line.tensionN = force
	-- forces on the hull
	local fx, fz = force * ux, force * uz
	local fwdx, fwdz = math.sin(line.heading), math.cos(line.heading)
	local driftX = (env.windX or 0) / S * 0.04
	local driftZ = (env.windZ or 0) / S * 0.04
	local rvx, rvz = line.vx - driftX, line.vz - driftZ
	local vf = rvx * fwdx + rvz * fwdz
	local vl = rvx * fwdz - rvz * fwdx
	local rf = TowLine.resistance(line, vf)
	local rl = 300 * 8 * vl * math.abs(vl) + 400 * vl -- keel
	fx -= rf * fwdx + rl * fwdz
	fz -= rf * fwdz - rl * fwdx
	-- the wave face pushes the hull down-slope (surfing towards the tug on the back of a wave)
	local g = TowLine.GRAVITY
	fx -= line.mass * g * (env.slopeX or 0) * 0.6
	fz -= line.mass * g * (env.slopeZ or 0) * 0.6
	line.vx += fx / line.mass * dt
	line.vz += fz / line.mass * dt
	line.x += line.vx * dt
	line.z += line.vz * dt
	-- yaw: the bow tow point turns the hull into the line; a weak single point lets it sheer
	local want = math.atan2(ux, uz)
	local err = (want - line.heading + math.pi) % (2 * math.pi) - math.pi
	local inertia = line.mass * line.lwl * line.lwl / 12
	local torque = force * line.lwl * 0.5 * math.sin(err) - 2.5 * inertia * line.yawRate
	if not line.bridle and force > 0 then
		torque += math.sin(line.time * 0.9) * force * line.lwl * 0.12
	end
	line.yawRate += torque / inertia * dt
	line.heading += line.yawRate * dt
end

-- Advances the tow by dt. Hitch position and velocity in studs and studs/s (the tug's TowHitch).
-- Returns the line (outputs updated). Once parted it stops pulling until `rejoin`.
function TowLine.step(
	line: Line,
	hitchX: number,
	hitchZ: number,
	hitchVx: number,
	hitchVz: number,
	dt: number,
	env: Env?
): Line
	local e: Env = env or {}
	local hx, hz, hvx, hvz = hitchX / S, hitchZ / S, hitchVx / S, hitchVz / S
	local before = line.tension
	local n = math.max(1, math.ceil(dt / TowLine.MAX_SUBSTEP))
	local h = dt / n
	local peak = 0
	for _ = 1, n do
		line.time += h
		if line.parted then
			substep(line, line.x + 1e3, line.z, 0, 0, 0, e) -- outputs only
			line.tensionN = 0
			-- free drift
			line.vx *= 1 - 0.5 * h
			line.vz *= 1 - 0.5 * h
			line.x += line.vx * h
			line.z += line.vz * h
		else
			substep(line, hx, hz, hvx, hvz, h, e)
		end
		peak = math.max(peak, line.tensionN)
	end
	local workingLoad = TowLine.WORKING_LOAD * (if line.strongPoint then 1 else 0.55)
	line.tension = if line.parted then 0 else peak / workingLoad
	line.slack = line.tension < TowLine.SLACK and line.distance < line.length
	line.snatch = if line.tension - before > 0.25 then line.tension - before else 0
	line.peak = math.max(line.peak, line.tension)
	if line.tension >= TowLine.AMBER then
		line.redHeld += dt
	else
		line.redHeld = 0
	end
	if
		not line.parted and (line.tension >= TowLine.PART_SPIKE or line.redHeld >= TowLine.RED_HOLD)
	then
		line.parted = true
		line.redHeld = 0
	end
	return line
end

-- After a parted line has been re-passed.
function TowLine.rejoin(line: Line)
	line.parted = false
	line.redHeld = 0
	line.tension = 0
	line.tensionN = 0
end

-- Steady towing tension (normalised) at speed v studs/s, for hints and tests.
function TowLine.steadyTension(line: Line, speedStuds: number): number
	return TowLine.resistance(line, speedStuds / S) / TowLine.WORKING_LOAD
end

return TowLine
