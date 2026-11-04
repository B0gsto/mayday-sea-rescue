--!strict
-- Boat/Unstick: when a hull touches a wall (quay, breakwater, beach, another hull) at under 3 km/h
-- with the throttle (ahead or astern) or the helm in use, push it gently off (docs/20 WP-C: free in
-- under 2 s). BoatController supplies the contact and the normal. The push alone can't free it (live v37: pairs a
-- second apart): the held throttle beat the nudge back to the wall, a fixed number against any hull's thrust. So for
-- BACK_TIME the hull's own drive and helm take it off the wall; one wedge, one push, at any speed or thrust.
local Unstick = {}

Unstick.HOLD = 0.6 -- s pinned before the nudge -- tune
Unstick.SPEED = 2.5 -- studs/s (3 km/h) under which the hull counts as pinned -- tune
Unstick.NUDGE = 6 -- studs/s pushed away from the contact -- tune
Unstick.TURN = 2.5 -- rad/s the bow swings off the wall with the nudge (about 35 degrees) -- tune

Unstick.BACK_TIME = 1 -- s the drive and helm take it off the wall: about 60 degrees of swing -- tune
Unstick.BACK_THROTTLE = 0.6 -- of the hull's own drive, away from a wall ahead or astern -- tune

export type State = { since: number?, backing: number?, drive: number, helm: number }

function Unstick.new(): State
	return { drive = 0, helm = 0 }
end

-- True once per wedge, after HOLD s of contact at under SPEED; effort is the throttle or helm in
-- use (either sign).
function Unstick.step(s: State, dt: number, wedged: boolean, speed: number, effort: number): boolean
	if s.backing then
		s.backing -= dt
		if (s.backing :: number) <= 0 then
			s.backing = nil
		end
		s.since = nil
		return false
	end
	if not wedged or math.abs(speed) >= Unstick.SPEED or math.abs(effort) <= 0.05 then
		s.since = nil
		return false
	end
	s.since = (s.since or 0) + dt
	if s.since >= Unstick.HOLD then
		s.since = nil
		return true
	end
	return false
end

-- Starts the back-off from a wall whose flat normal points out of it; returns the bow's swing (+1 = to the right, the
-- SteerFloat sign). Head-on it swings toward the side being steered, else right.
function Unstick.push(
	s: State,
	normal: Vector3,
	forward: Vector3,
	right: Vector3,
	steer: number
): number
	local side = normal:Dot(right)
	if math.abs(side) < 0.2 then
		side = if steer ~= 0 then steer else 1
	end
	local ahead = normal:Dot(forward)
	s.backing = Unstick.BACK_TIME
	s.helm = if side > 0 then 1 else -1
	-- alongside the wall the player's throttle stays: it already runs clear
	s.drive = if math.abs(ahead) < 0.5 then 0 else math.sign(ahead) * Unstick.BACK_THROTTLE
	return s.helm
end

-- The helm's input during a back-off; the player's otherwise.
function Unstick.input(s: State?, throttle: number, steer: number): (number, number)
	if not (s and s.backing) then
		return throttle, steer
	end
	-- going astern the helm works backwards (Buoyancy.steerTorque)
	return if s.drive ~= 0 then s.drive else throttle, if s.drive < 0 then -s.helm else s.helm
end

return Unstick
