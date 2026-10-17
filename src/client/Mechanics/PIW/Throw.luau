--!strict
-- PIW/Throw: the throw bag (docs 09 section 5.3). The bag flies by projectile physics at the
-- project gravity, the wind nudges it, and the line pays out behind it. The right throw lands
-- beyond the casualty and a little upwind, so the floating line drifts down onto them; never at
-- their head. Then the crew hauls hand over hand. Pure (Lune-tested).
local Units = require(script.Parent.Units)

local Throw = {}

Throw.LINE_LENGTH = 23 * Units.STUDS_PER_M -- 69 studs: a 23 m rescue throw line
Throw.MIN_SPEED = 14 -- studs/s, a lob
Throw.MAX_SPEED = 46 -- studs/s, a full underarm throw (about 22 m reach)
Throw.ANGLE = math.rad(30) -- release angle above the horizon
Throw.CHARGE_TIME = 1.1 -- s to full power; holding longer lets the arm sag back
Throw.WIND_ACCEL = 1.2 -- studs/s^2 per unit wind intensity on the light bag
Throw.ON_LINE = 2.5 -- studs: the line lands across them
Throw.DRIFT_ONTO = 7 -- studs: an upwind line this close drifts down onto them
Throw.HEAD = 1.6 -- studs: the bag landed on their head
Throw.HAUL_PULL = 2.2 -- studs gained per good hand-over-hand pull (0.75 m)

-- Power 0..1 from how long the throw has been charged: rises, then sags if held too long.
function Throw.charge(held: number): number
	local x = held / Throw.CHARGE_TIME
	if x <= 1 then
		return math.clamp(x, 0, 1)
	end
	return math.clamp(1 - (x - 1) * 0.8, 0.25, 1)
end

function Throw.velocity(aim: Vector3, power: number): Vector3
	local dir = Units.unitOr(aim, Vector3.new(0, 0, -1))
	local speed = Throw.MIN_SPEED + (Throw.MAX_SPEED - Throw.MIN_SPEED) * math.clamp(power, 0, 1)
	return dir * (speed * math.cos(Throw.ANGLE)) + Vector3.new(0, speed * math.sin(Throw.ANGLE), 0)
end

-- Where the bag hits the water (y = waterY) and when: y(t) = y0 + vy t - g t^2 / 2, horizontal
-- x(t) = x0 + vx t + a t^2 / 2 with the wind's push a. The line stops it at LINE_LENGTH.
function Throw.land(
	origin: Vector3,
	velocity: Vector3,
	waterY: number,
	gravity: number,
	windAccel: Vector3
): (Vector3, number, boolean)
	local g = math.max(gravity, 1)
	local h = math.max(0, origin.Y - waterY)
	local vy = velocity.Y
	local t = (vy + math.sqrt(vy * vy + 2 * g * h)) / g
	local flatV = Units.flat(velocity)
	local flatA = Units.flat(windAccel)
	local land = Units.flat(origin) + flatV * t + flatA * (0.5 * t * t)
	local fromOrigin = land - Units.flat(origin)
	local snubbed = false
	if fromOrigin.Magnitude > Throw.LINE_LENGTH then
		land = Units.flat(origin) + fromOrigin.Unit * Throw.LINE_LENGTH
		snubbed = true
	end
	return Vector3.new(land.X, waterY, land.Z), t, snubbed
end

-- Points along the flight for the Assist arc preview.
function Throw.arc(
	origin: Vector3,
	velocity: Vector3,
	gravity: number,
	windAccel: Vector3,
	tEnd: number,
	n: number
): { Vector3 }
	local pts = {}
	for i = 0, n do
		local t = tEnd * i / n
		local p = origin
			+ velocity * t
			+ Units.flat(windAccel) * (0.5 * t * t)
			- Vector3.new(0, 0.5 * gravity * t * t, 0)
		table.insert(pts, p)
	end
	return pts
end

export type Assessment = {
	result: string, -- "over" | "head" | "short" | "downwind" | "wide"
	lateral: number, -- studs from the casualty to the line
	beyond: number, -- studs the bag landed past them along the throw
}

-- Judge where the line lies: from the thrower to the landing point, against the casualty.
function Throw.assess(
	thrower: Vector3,
	landing: Vector3,
	casualty: Vector3,
	windDirection: number
): Assessment
	local o, l, c = Units.flat(thrower), Units.flat(landing), Units.flat(casualty)
	local d = l - o
	local len = math.max(d.Magnitude, 1e-3)
	local u = d / len
	local proj = (c - o):Dot(u)
	local beyond = len - proj
	local closest = o + u * math.clamp(proj, 0, len)
	local off = c - closest
	local lateral = off.Magnitude
	if (l - c).Magnitude < Throw.HEAD then
		return { result = "head", lateral = lateral, beyond = beyond }
	end
	if beyond < 1 then
		return { result = "short", lateral = lateral, beyond = beyond }
	end
	-- positive: the casualty is downwind of the line, so the line drifts down onto them
	local downwindOfLine = off:Dot(Units.windVector(windDirection))
	if lateral <= Throw.ON_LINE or (downwindOfLine > 0 and lateral <= Throw.DRIFT_ONTO) then
		return { result = "over", lateral = lateral, beyond = beyond }
	end
	if downwindOfLine <= 0 then
		return { result = "downwind", lateral = lateral, beyond = beyond }
	end
	return { result = "wide", lateral = lateral, beyond = beyond }
end

-- The throw half of the recovery score: line over them on the first throw is the Gold band.
function Throw.throwScore(throws: number, headHits: number): number
	local base = if throws <= 1
		then 1
		elseif throws == 2 then 0.6
		elseif throws == 3 then 0.35
		else 0.15
	return math.max(0, base - 0.2 * headHits)
end

-- Recovery score 0..1: half the throw, half a steady haul, a dip of their face costs a little.
function Throw.recoveryScore(throwScore: number, evenness: number, dips: number): number
	return math.clamp(0.5 * throwScore + 0.5 * evenness - 0.08 * dips, 0, 1)
end

return Throw
