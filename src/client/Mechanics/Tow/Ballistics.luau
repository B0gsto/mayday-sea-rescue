--!strict
-- Ballistics: the heaving line throw (docs 09 section 6 step 4). Pure: tests/MechTow.spec.luau.
-- A heaving line is a light line with a weighted knot (a monkey's fist); the knot flies on a
-- ballistic arc at the project gravity (Workspace.Gravity 29.43 studs/s^2) and the wind pushes it
-- with a light linear drag toward the wind velocity, so the thrower has to aim off upwind.
-- Landings are judged against the casualty's deck box: across the deck between the people is a
-- hit, on (within reach of) a person is a "person" (they flinch, the grade drops), else a miss.

local Ballistics = {}

Ballistics.GRAVITY = 29.43
Ballistics.DRAG = 0.35 -- 1/s, the knot and the paying-out line catching the wind (tune)
Ballistics.MIN_SPEED = 18 -- studs/s at zero charge
Ballistics.MAX_SPEED = 52 -- studs/s at full charge: about 25 m on a calm day (tune)
Ballistics.PERSON_RADIUS = 1.6
Ballistics.LINE_LENGTH = 90 -- studs of heaving line in the coil (30 m); a throw stops there

export type Landing = {
	point: Vector3,
	time: number,
	path: { Vector3 },
	outOfLine: boolean, -- the coil ran out before it landed
}

-- Charge 0..1 (hold to charge) maps to launch speed; a real throw is underarm at 30 to 40 degrees.
function Ballistics.speedFor(charge: number): number
	local c = math.clamp(charge, 0, 1)
	return Ballistics.MIN_SPEED + (Ballistics.MAX_SPEED - Ballistics.MIN_SPEED) * c
end

function Ballistics.launchVelocity(yaw: number, pitch: number, speed: number): Vector3
	local cp = math.cos(pitch)
	return Vector3.new(-math.sin(yaw) * cp, math.sin(pitch), -math.cos(yaw) * cp) * speed
end

-- Integrates the knot until it falls to waterY (or hits the deck plane at deckY when it is over
-- the deck box). wind = wind velocity in studs/s (horizontal).
function Ballistics.simulate(
	origin: Vector3,
	velocity: Vector3,
	wind: Vector3,
	waterY: number,
	deck: { cframe: CFrame, size: Vector3 }?,
	maxTime: number?
): Landing
	local dt = 1 / 60
	local p, v = origin, velocity
	local path = { p }
	local t = 0
	local limit = maxTime or 6
	local out = false
	while t < limit do
		local accel = Vector3.new(0, -Ballistics.GRAVITY, 0)
			+ (wind - Vector3.new(v.X, 0, v.Z)) * Ballistics.DRAG
		v += accel * dt
		local nextP = p + v * dt
		t += dt
		if
			(Vector3.new(nextP.X, 0, nextP.Z) - Vector3.new(origin.X, 0, origin.Z)).Magnitude
			> Ballistics.LINE_LENGTH
		then
			out = true
			p = nextP
			break
		end
		if deck and v.Y < 0 then
			local loc = deck.cframe:PointToObjectSpace(nextP)
			local half = deck.size / 2
			if math.abs(loc.X) <= half.X and math.abs(loc.Z) <= half.Z and loc.Y <= half.Y then
				p = deck.cframe:PointToWorldSpace(Vector3.new(loc.X, half.Y, loc.Z))
				table.insert(path, p)
				break
			end
		end
		if nextP.Y <= waterY then
			local f = (p.Y - waterY) / math.max(p.Y - nextP.Y, 1e-6)
			p = p:Lerp(nextP, math.clamp(f, 0, 1))
			table.insert(path, p)
			break
		end
		p = nextP
		if #path < 400 and (#path % 3 == 0) then
			table.insert(path, p)
		end
	end
	return { point = p, time = t, path = path, outOfLine = out }
end

-- "deck" (a good throw: across the deck), "person" (hit or onto someone), "short", "long" or
-- "wide" (misses, for the crew's call-out). deck = the casualty's deck box, people = positions.
function Ballistics.judge(
	landing: Landing,
	origin: Vector3,
	deck: { cframe: CFrame, size: Vector3 },
	people: { Vector3 }
): string
	local p = landing.point
	for _, person in people do
		local flat = Vector3.new(p.X - person.X, 0, p.Z - person.Z)
		if flat.Magnitude <= Ballistics.PERSON_RADIUS and math.abs(p.Y - person.Y) < 4 then
			return "person"
		end
	end
	local loc = deck.cframe:PointToObjectSpace(p)
	local half = deck.size / 2
	-- the line lies across the deck if the knot lands on it or just beyond (the line drapes over)
	local overX = math.abs(loc.X) <= half.X + 2.5
	local overZ = math.abs(loc.Z) <= half.Z
	if overX and overZ and landing.outOfLine == false then
		return "deck"
	end
	local toDeck =
		Vector3.new(deck.cframe.Position.X - origin.X, 0, deck.cframe.Position.Z - origin.Z)
	local toLand = Vector3.new(p.X - origin.X, 0, p.Z - origin.Z)
	if toDeck.Magnitude < 1e-3 then
		return "wide"
	end
	local along = toLand:Dot(toDeck.Unit)
	local across = math.abs(toLand:Cross(toDeck.Unit).Y)
	if across > math.max(half.X, half.Z) + 2 then
		return "wide"
	end
	return if along < toDeck.Magnitude then "short" else "long"
end

-- Upwind check for the approach: the thrower should be upwind of the casualty so the line and
-- the drift both carry toward them. Returns the cosine (1 = dead upwind). wind = blowing toward.
function Ballistics.upwindness(thrower: Vector3, casualty: Vector3, wind: Vector3): number
	local fromCas = Vector3.new(thrower.X - casualty.X, 0, thrower.Z - casualty.Z)
	local w = Vector3.new(wind.X, 0, wind.Z)
	if fromCas.Magnitude < 1e-3 or w.Magnitude < 1e-3 then
		return 1
	end
	return -fromCas.Unit:Dot(w.Unit)
end

return Ballistics
