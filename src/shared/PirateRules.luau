--!strict
-- PirateRules (docs/29 D, docs/30 section 5): who gets hunted, where the pirate starts, how it steers, what shakes it and
-- when a ram lands. Pure, tests/PirateRules.spec.luau. Server: PirateService; look: PirateController.
-- Fair at any speed: spawn distance and reach scale with the hunted boat's top speed, and a ram needs the pirate on the
-- boat for longer than the hunted client's lag (its client draws the pirate at the offset the server sees, PirateController).
local Calls = script.Parent:WaitForChild("Calls")
local Config = script.Parent:WaitForChild("Config")
local RingLayout = require(Config:WaitForChild("RingLayout"))
local SeaZones = require(Calls:WaitForChild("SeaZones"))
local WorldConfig = require(Config:WaitForChild("WorldConfig"))

local PirateRules = {}

PirateRules.SPEED = 0.92 -- x the hunted boat's top speed
PirateRules.MIN_CALLS = 5 -- saved calls before any pirate
PirateRules.MAX_PER_ZONE = 2 -- pirates at once per sea zone, per server -- tune
PirateRules.ROLL_EVERY = 5 -- s between chance rolls for one player -- tune
PirateRules.COOLDOWN = 45 -- s after a chase before the next roll -- tune
PirateRules.CHASE_SECONDS = 40 -- then they give up
PirateRules.SAIL_OFF_SECONDS = 6 -- how long they stay in sight sailing off -- tune
PirateRules.ESCAPE_PAY = 1.25 -- delivery pay on Go back after a chase with no hit
PirateRules.BONUS_WINDOW = 5 -- s that pay stays on: a mission's finish pays just after its delivery
PirateRules.KNOCK_LOCK = 4 -- s a knocked survivor can't climb back: auto-board would undo the ram at once -- tune

PirateRules.MIN_SPAWN = 300 -- studs
PirateRules.SPAWN_LEAD = 5 -- s of the boat's top speed away, so the warning takes as long at any speed -- tune
PirateRules.BASE_REACH = 40 -- studs: the hull's half length and a small boat's
PirateRules.REACH_PER_SPEED = 0.04 -- studs per stud/s of top speed: covers a step at 1100 studs/s -- tune
PirateRules.CLOSE = 3 -- x reach: in here it heads straight at the boat with no turn limit
PirateRules.TURN = 1.4 -- rad/s further out: a hard turn beats it -- tune
PirateRules.MIN_AGE = 1 -- s after spawning before any ram, plus the client's lag
PirateRules.HOLD_MIN, PirateRules.HOLD_MAX = 0.2, 0.6 -- s on the boat before the ram lands
PirateRules.HOLD_PAD = 0.15 -- s: the client's smoothing, on top of its ping
PirateRules.LAG_PAUSE = 0.8 -- s of ping past which the server's view of the boat is too old to hit on
PirateRules.BOOST_SEEN = 1.05 -- x top speed: the boat is boosting (pick-up boost, Nitro)
PirateRules.THROWN = 0.7 -- x its speed while the boat boosts: the wake throws it off -- tune
PirateRules.SHAKE_LEAD = 1.5 -- s of top speed further off than its closest: shaken -- tune
PirateRules.SHAKE_MIN = 100 -- studs
PirateRules.BLIND_SECONDS = 2 -- s with land between it and the boat: shaken -- tune
PirateRules.LAND_PAD = 40 -- studs its hull stays off land and the Shallows line
PirateRules.SLIDE = 0.5 -- x its speed while sliding round land

local ZONE_CHANCE: { [number]: number } = { [2] = 0.06, [3] = 0.1, [4] = 0.15, [5] = 0.22 } -- per roll at full load -- tune

export type Who = {
	survivors: number,
	zone: number,
	calls: number,
	coldOpenDone: boolean,
	coldOpenActive: boolean,
	testRide: boolean,
	surfaceBoat: boolean, -- a hull on the water: no helis or subs
	tutorial: boolean, -- docs/30 section 4 is still running
}
export type Chase = {
	pos: Vector3,
	heading: Vector3,
	vel: Vector3,
	age: number,
	contact: number, -- s within reach
	bestGap: number,
	blind: number, -- s with land in the way
	leaving: number, -- s sailing off
}
export type Input = { boat: Vector3, vel: Vector3, top: number, ping: number, dt: number }

local CENTER = Vector3.new(RingLayout.Center.X, 0, RingLayout.Center.Z)
local SHALLOWS = SeaZones.Zones[1].outer
local circles: { { c: Vector3, r: number } } = { { c = CENTER, r = SHALLOWS } }
for _, island in WorldConfig.Islands do
	table.insert(
		circles,
		{ c = Vector3.new(island.center.X, 0, island.center.Z), r = island.radius }
	)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function turned(v: Vector3, degrees: number): Vector3
	local a = math.rad(degrees)
	local c, s = math.cos(a), math.sin(a)
	return Vector3.new(v.X * c - v.Z * s, 0, v.X * s + v.Z * c)
end

function PirateRules.eligible(w: Who): boolean
	return w.survivors > 0
		and w.zone >= 2
		and w.calls >= PirateRules.MIN_CALLS
		and w.coldOpenDone
		and not w.coldOpenActive
		and not w.testRide
		and w.surfaceBoat
		and not w.tutorial
end

-- Per roll: rises with the zone and with how full the boat is.
function PirateRules.chance(zone: number, survivors: number, capacity: number): number
	return (ZONE_CHANCE[zone] or 0)
		* (0.5 + 0.5 * math.clamp(survivors / math.max(capacity, 1), 0, 1))
end

function PirateRules.spawnDistance(top: number): number
	return math.max(PirateRules.MIN_SPAWN, top * PirateRules.SPAWN_LEAD)
end

function PirateRules.reach(top: number): number
	return PirateRules.BASE_REACH + top * PirateRules.REACH_PER_SPEED
end

-- How long the pirate stays on the boat before the ram lands: longer than the news takes to reach the client.
function PirateRules.hold(ping: number): number
	return math.clamp(ping + PirateRules.HOLD_PAD, PirateRules.HOLD_MIN, PirateRules.HOLD_MAX)
end

function PirateRules.mayHit(age: number, ping: number): boolean
	return age >= PirateRules.MIN_AGE + ping and ping < PirateRules.LAG_PAUSE
end

-- On land or inside the Shallows line (keeping the hull clear)?
function PirateRules.blocked(p: Vector3): boolean
	for _, b in circles do
		if (flat(p) - b.c).Magnitude < b.r + PirateRules.LAND_PAD then
			return true
		end
	end
	return false
end

-- Land or the Shallows between two points?
function PirateRules.sightBlocked(a: Vector3, b: Vector3): boolean
	local from, to = flat(a), flat(b)
	local line = to - from
	local len2 = line:Dot(line)
	for _, circle in circles do
		local t = if len2 > 0 then math.clamp((circle.c - from):Dot(line) / len2, 0, 1) else 0
		if (from + line * t - circle.c).Magnitude < circle.r then
			return true
		end
	end
	return false
end

-- Where it starts: off to the side and ahead, open water, a clear run to the boat. flip picks the side tried first.
-- Past about 67 degrees off the bow a 0.92x pirate can't cut a straight run off, so those are the last tried.
function PirateRules.spawnPoint(
	boat: Vector3,
	heading: Vector3,
	top: number,
	flip: boolean
): Vector3?
	local forward = flat(heading)
	forward = if forward.Magnitude > 1e-3 then forward.Unit else Vector3.new(0, 0, -1)
	local side = if flip then -1 else 1
	local at = flat(boat)
	for _, angle in { 50, 40, 60, 30, 80 } do
		for _, s in { side, -side } do
			local p = at + turned(forward, angle * s) * PirateRules.spawnDistance(top)
			if not PirateRules.blocked(p) and not PirateRules.sightBlocked(p, at) then
				return p
			end
		end
	end
	return nil
end

-- The point to steer for: where it meets a boat holding its course, or a short lead when it can't.
function PirateRules.aimPoint(from: Vector3, boat: Vector3, vel: Vector3, speed: number): Vector3
	local d = flat(boat) - flat(from)
	local v = flat(vel)
	local a = v:Dot(v) - speed * speed
	local b = 2 * d:Dot(v)
	local c = d:Dot(d)
	local t: number? = nil
	if math.abs(a) < 1e-6 then
		t = if b < 0 then -c / b else nil
	else
		local disc = b * b - 4 * a * c
		if disc >= 0 then
			local root = math.sqrt(disc)
			local t1, t2 = (-b - root) / (2 * a), (-b + root) / (2 * a)
			local low, high = math.min(t1, t2), math.max(t1, t2)
			t = if low > 0 then low elseif high > 0 then high else nil
		end
	end
	return flat(boat) + v * (t or math.min(d.Magnitude / math.max(speed, 1), 3))
end

function PirateRules.newChase(pos: Vector3, boat: Vector3, vel: Vector3, top: number): Chase
	local at = flat(pos)
	local aim = PirateRules.aimPoint(at, boat, vel, top * PirateRules.SPEED) - at
	return {
		pos = at,
		heading = if aim.Magnitude > 1e-3 then aim.Unit else Vector3.new(0, 0, -1),
		vel = Vector3.zero,
		age = 0,
		contact = 0,
		bestGap = (flat(boat) - at).Magnitude,
		blind = 0,
		leaving = 0,
	}
end

-- Moves along c.heading, sliding at SLIDE speed round land and the Shallows line (the free way nearest `toward`).
local function advance(c: Chase, distance: number, toward: Vector3, dt: number)
	local next = c.pos + c.heading * distance
	if PirateRules.blocked(next) then
		local best: Vector3? = nil
		local bestLeft = math.huge
		for _, degrees in { 45, -45, 90, -90, 135, -135 } do
			local dir = turned(c.heading, degrees)
			local spot = c.pos + dir * distance * PirateRules.SLIDE
			local left = (toward - spot).Magnitude
			if not PirateRules.blocked(spot) and left < bestLeft then
				best, bestLeft = dir, left
			end
		end
		if not best then
			c.vel = Vector3.zero
			return
		end
		c.heading = best
		next = c.pos + best * distance * PirateRules.SLIDE
	end
	c.vel = (next - c.pos) / math.max(dt, 1e-3)
	c.pos = next
end

-- One server step of the hunt. Returns why it ended: "Hit", "Timeout", "Shallows", "Shaken"; nil while it runs.
function PirateRules.step(c: Chase, input: Input): string?
	local boat, boatVel, top, dt = flat(input.boat), flat(input.vel), input.top, input.dt
	c.age += dt
	if c.age >= PirateRules.CHASE_SECONDS then
		return "Timeout"
	elseif (boat - CENTER).Magnitude < SHALLOWS then
		return "Shallows" -- never past the line
	end
	local speed = top * PirateRules.SPEED
	if boatVel.Magnitude > top * PirateRules.BOOST_SEEN then
		speed *= PirateRules.THROWN
	end
	local reach = PirateRules.reach(top)
	local toBoat = boat - c.pos
	local gap = toBoat.Magnitude
	local move = speed * dt
	if gap <= reach * PirateRules.CLOSE then
		if gap > 1e-3 then
			c.heading = toBoat.Unit
		end
		move = math.min(move, gap) -- sits on the boat, no overshoot
	else
		local aim = PirateRules.aimPoint(c.pos, boat, boatVel, speed) - c.pos
		if aim.Magnitude > 1e-3 then
			local want = aim.Unit
			local angle = math.acos(math.clamp(c.heading:Dot(want), -1, 1))
			local cross = c.heading.Z * want.X - c.heading.X * want.Z
			local side = if cross > 0 then -1 else 1
			c.heading = turned(c.heading, math.deg(math.min(angle, PirateRules.TURN * dt)) * side)
		end
	end
	advance(c, move, boat, dt)

	gap = (boat - c.pos).Magnitude
	c.bestGap = math.min(c.bestGap, gap)
	c.blind = if PirateRules.sightBlocked(c.pos, boat) then c.blind + dt else 0
	if
		c.blind >= PirateRules.BLIND_SECONDS
		or gap > c.bestGap + math.max(PirateRules.SHAKE_MIN, top * PirateRules.SHAKE_LEAD)
	then
		return "Shaken"
	end
	c.contact = if gap <= reach then c.contact + dt else 0
	if c.contact >= PirateRules.hold(input.ping) and PirateRules.mayHit(c.age, input.ping) then
		return "Hit"
	end
	return nil
end

-- One server step of sailing off, away from the boat. True when it has gone.
function PirateRules.stepSailOff(c: Chase, boat: Vector3, top: number, dt: number): boolean
	c.leaving += dt
	local away = c.pos - flat(boat)
	if away.Magnitude > 1e-3 then
		c.heading = away.Unit
	end
	advance(c, top * PirateRules.SPEED * dt, c.pos + c.heading * 1000, dt)
	return c.leaving >= PirateRules.SAIL_OFF_SECONDS
end

-- Delivery pay while the bonus stamp (server time) runs.
function PirateRules.payMult(bonusUntil: number?, now: number): number
	return if bonusUntil and now < bonusUntil then PirateRules.ESCAPE_PAY else 1
end

return PirateRules
