--!strict
-- Boat/Unstick: when a hull touches a wall (quay, breakwater, beach, another hull) at under 3 km/h
-- with the throttle open, push it gently off (docs/20 WP-C: free in under 2 s). BoatController
-- supplies the contact and the normal.
local Unstick = {}

Unstick.HOLD = 0.6 -- s pinned before the nudge -- tune
Unstick.SPEED = 2.5 -- studs/s (3 km/h) under which the hull counts as pinned -- tune
Unstick.NUDGE = 6 -- studs/s pushed away from the contact -- tune
Unstick.TURN = 2.5 -- rad/s the bow swings off the wall with the nudge (about 35 degrees) -- tune

export type State = { since: number? }

function Unstick.new(): State
	return {}
end

-- True once per wedge, after HOLD s of contact at under SPEED with forward throttle.
function Unstick.step(
	s: State,
	dt: number,
	wedged: boolean,
	speed: number,
	throttle: number
): boolean
	if not wedged or math.abs(speed) >= Unstick.SPEED or throttle <= 0.05 then
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

return Unstick
