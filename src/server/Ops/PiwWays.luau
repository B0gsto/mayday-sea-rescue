--!strict
-- PiwWays: how a survivor answers the boat that comes for them (docs/14 section 3), server side. Pure
-- (Lune-tested in tests/MechPIWWays.spec.luau); PiwRescue runs it.
--   idle  waits for the rescuer; once they are close and slow, the 10 s rule starts ("swim"); after
--         COME_DEADLINE idle (s.since = the arm time) they set off anyway if the rescuer is in LOST_RANGE
--   swim  swims to the rescuer, arriving within COME_DEADLINE of the trigger at the latest
--   held  reached the boat and holds on beside it until they climb aboard (auto_board)
-- Positions are flat (y ignored); speeds in studs/s.
local PiwWays = {}

PiwWays.COME_RANGE = 45 -- studs (15 m): close enough that they come to you (tune)
PiwWays.COME_DEADLINE = 10 -- s: the 10 s rule, trigger to arrival
PiwWays.STOPPED = 7 -- studs/s (about 4 kn): faster than this and they wait (prop, wake)
PiwWays.LOST_RANGE = 110 -- studs: the rescuer went off; they stop and wait again
PiwWays.SWIM_SPEED = 3 -- studs/s (1 m/s): an unhurried swim
PiwWays.GAP_BOAT = 6 -- studs from the boat's pivot while held (at the side, not in the hull)
PiwWays.GAP_SWIMMER = 3 -- studs from a swimming rescuer while held
PiwWays.FOLLOW_MAX = 45 -- studs/s: a held casualty keeps up with a towing jet ski
PiwWays.LET_GO = 30 -- studs past the gap: dragged too fast, they lose their grip

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
	if s.mode == "swim" then
		if dist <= gap then
			s.mode, s.since = "held", now
			return Vector3.zero
		end
		if dist > PiwWays.LOST_RANGE then
			s.mode = "idle"
			return Vector3.zero
		end
		local speed = PiwWays.comeSpeed(dist - gap, now - s.since, PiwWays.SWIM_SPEED)
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
