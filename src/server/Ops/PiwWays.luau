--!strict
-- PiwWays: how a Person in the Water casualty answers the three rescue ways (docs/14 section 3),
-- server side. Pure (Lune-tested in tests/MechPIWWays.spec.luau); PiwRescue runs it.
--   idle  waits for the rescuer; once they are close and slow, the 10 s rule starts ("swim"); after
--         COME_DEADLINE idle (s.since = the arm time) they set off anyway if the rescuer is in LOST_RANGE
--   swim  swims to the rescuer, arriving within COME_DEADLINE of the trigger at the latest
--   line  holds a throw line that landed near them and is pulled in (same deadline)
--   held  has hold of the boat or the rescuer and follows them (drag)
-- Positions are flat (y ignored); speeds in studs/s.
local PiwWays = {}

PiwWays.COME_RANGE = 45 -- studs (15 m): close enough that they come to you (tune)
PiwWays.COME_DEADLINE = 10 -- s: the 10 s rule, trigger to arrival
PiwWays.STOPPED = 7 -- studs/s (about 4 kn): faster than this and they wait (prop, wake)
PiwWays.LOST_RANGE = 110 -- studs: the rescuer went off; they stop and wait again
PiwWays.SWIM_SPEED = 3 -- studs/s (1 m/s): an unhurried swim
PiwWays.HAUL_SPEED = 5 -- studs/s: hauled in on the line
PiwWays.GAP_BOAT = 6 -- studs from the boat's pivot while held (at the side, not in the hull)
PiwWays.GAP_SWIMMER = 3 -- studs from a swimming rescuer while held
PiwWays.FOLLOW_MAX = 45 -- studs/s: a held casualty keeps up with a towing jet ski
PiwWays.LET_GO = 30 -- studs past the gap: dragged too fast, they lose their grip
PiwWays.GRAB_RANGE = 9 -- studs past the gap: in arm's reach (server check)
PiwWays.LINE_REACH = 75 -- studs: a 23 m throw line plus the arm (server check)
PiwWays.THROW_NEAR = 8 -- studs from them: they can reach the bag (server check)

export type State = { mode: string, since: number }

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function PiwWays.new(): State
	return { mode = "idle", since = 0 }
end

function PiwWays.gap(onBoat: boolean): number
	return if onBoat then PiwWays.GAP_BOAT else PiwWays.GAP_SWIMMER
end

-- Speed that keeps the 10 s promise: a normal swim, faster when the clock is running out.
function PiwWays.comeSpeed(dist: number, sinceTrigger: number, base: number): number
	local left = math.max(PiwWays.COME_DEADLINE - 1 - sinceTrigger, 0.25) -- 1 s spare
	return math.max(base, math.max(dist, 0) / left)
end

-- Server checks for the client's claims (never trust the client).
function PiwWays.canGrab(rescuer: Vector3, casualty: Vector3, onBoat: boolean): boolean
	return (flat(rescuer) - flat(casualty)).Magnitude <= PiwWays.gap(onBoat) + PiwWays.GRAB_RANGE
end

function PiwWays.throwHits(thrower: Vector3, landing: Vector3, casualty: Vector3): boolean
	return (flat(landing) - flat(thrower)).Magnitude <= PiwWays.LINE_REACH
		and (flat(landing) - flat(casualty)).Magnitude <= PiwWays.THROW_NEAR
end

-- Starts a way the server has validated: "line" (a throw hit) or "held" (grabbed).
function PiwWays.begin(s: State, mode: string, now: number)
	if s.mode == "held" then
		return -- already holding on: a throw changes nothing
	end
	s.mode = mode
	s.since = now
end

-- One tick: the casualty's flat velocity toward the rescuer (zero while waiting).
function PiwWays.step(
	s: State,
	now: number,
	casualty: Vector3,
	rescuer: Vector3,
	rescuerSpeed: number,
	onBoat: boolean,
	dt: number
): Vector3
	local to = flat(rescuer) - flat(casualty)
	local dist = to.Magnitude
	local dir = if dist > 1e-3 then to / dist else Vector3.zero
	local gap = PiwWays.gap(onBoat)
	if s.mode == "idle" then
		-- close and slow, or the rescuer is in sight and the 10 s since the arm (s.since) ran out
		local waited = now - s.since >= PiwWays.COME_DEADLINE and dist <= PiwWays.LOST_RANGE
		if (dist <= PiwWays.COME_RANGE and rescuerSpeed <= PiwWays.STOPPED) or waited then
			s.mode, s.since = "swim", now
		end
		return Vector3.zero
	end
	if s.mode == "swim" or s.mode == "line" then
		if dist <= gap then
			s.mode, s.since = "held", now
			return Vector3.zero
		end
		if s.mode == "swim" and dist > PiwWays.LOST_RANGE then
			s.mode = "idle"
			return Vector3.zero
		end
		local base = if s.mode == "line" then PiwWays.HAUL_SPEED else PiwWays.SWIM_SPEED
		local speed = PiwWays.comeSpeed(dist - gap, now - s.since, base)
		return dir * math.min(speed, (dist - gap) / math.max(dt, 1e-3))
	end
	-- held: close the gap behind the rescuer, never overshooting it; torn away, they let go
	if dist > gap + PiwWays.LET_GO then
		s.mode = "idle"
		return Vector3.zero
	end
	if dist <= gap then
		return Vector3.zero
	end
	return dir * math.min(PiwWays.FOLLOW_MAX, (dist - gap) / math.max(dt, 1e-3))
end

return PiwWays
