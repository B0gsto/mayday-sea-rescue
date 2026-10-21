--!strict
-- Boat/Unstick: when a hull stays pinned against a quay or breakwater with the throttle open,
-- nudge it off after a few seconds (BoatController supplies the contact and the normal).
local Unstick = {}

Unstick.HOLD = 3 -- s pinned before the nudge -- tune
Unstick.SPEED = 1 -- studs/s under which the hull counts as pinned -- tune
Unstick.NUDGE = 4 -- studs/s pushed away from the contact -- tune

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
