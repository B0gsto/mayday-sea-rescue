--!strict
-- Ops/Board: when a person in the water climbs aboard (auto_board and the free-roam AmbientRescueService,
-- 2026-10-21), and who may see and board a mission casualty (the Victim model's PrivateTo attribute).
-- Pure; Lune-tested in tests/AutoBoard.spec.luau.
local Board = {}

Board.REACH = 10 -- studs from the hull side
Board.STEADY_SPEED = 10 -- studs/s (about 6 knots): forgiving (docs/23 e.1) -- tune
Board.STEADY_TILT = 22 -- degrees of pitch or roll
Board.HOLD = 0.6 -- s close and steady before they climb
Board.RAM_SPEED = 14 -- studs/s
Board.CONTACT = 4 -- studs from the hull side
Board.BUMP_GAP = 2 -- s between bumps
-- docs/23 e.1: a ram knocks them back only once you own a boathouse (the DockBoathouse attribute): new
-- players are never punished for a clumsy first pick-up.
-- The pick-up ring (docs/23 e.1, PickupRingController): drawn on the water round a survivor; a craft with room
-- eases its throttle so it is down to ASSIST_SPEED by the ring and holds it inside, under STEADY_SPEED.
Board.RING = 12 -- studs, radius from the survivor to the hull centre -- tune
Board.ASSIST_SPEED = 7 -- studs/s inside the ring -- tune
-- 0.4 / 2: a jet ski at full throttle reaches the ring edge at <= 8 studs/s even with the hull half airborne
-- (0.6 / 6 arrived at ~12: the brake loses grip on the chop, tests/AutoBoard.spec's sim)
Board.ASSIST_SPAN = 2 -- studs/s over the allowed speed for full brake
Board.ASSIST_BRAKE_SHARE = 0.4 -- of the craft's brakeDecel counted on when slowing for the ring

-- May they climb aboard now?
function Board.ready(gap: number, speed: number, tiltDeg: number, room: boolean): boolean
	return room
		and gap <= Board.REACH
		and speed <= Board.STEADY_SPEED
		and tiltDeg <= Board.STEADY_TILT
end

-- May a ram knock them back? `veteran` = the rescuer's DockBoathouse attribute (nil: a new player)
function Board.knocks(veteran: any): boolean
	return veteran == true
end

-- Did the boat just run into them (hard enough to knock them back, for a veteran)?
function Board.rammed(gap: number, speed: number, veteran: any): boolean
	return Board.knocks(veteran) and gap <= Board.CONTACT and speed >= Board.RAM_SPEED
end

-- The throttle a craft with room gets near a survivor (docking assist). dist: hull centre to them (flat);
-- closing: speed toward them; forward: speed along the bow; brakeDecel: the craft's studs/s^2 of brake.
-- Outside the ring only closing speed counts (passing by is never braked) and is capped to what still
-- slows to ASSIST_SPEED at the ring edge; inside, forward speed is held at ASSIST_SPEED. Never adds throttle.
function Board.assistThrottle(
	input: number,
	dist: number,
	closing: number,
	forward: number,
	brakeDecel: number
): number
	local out = math.max(0, dist - Board.RING)
	local allowed =
		math.sqrt(Board.ASSIST_SPEED ^ 2 + 2 * brakeDecel * Board.ASSIST_BRAKE_SHARE * out)
	local speed = if out > 0 then closing else forward
	return math.min(input, math.clamp((allowed - speed) / Board.ASSIST_SPAN, -1, 1))
end

-- Bigger craft (playtest 2026-10-26: a RIB at full throttle circled a ring 3 times). The ring is the
-- boarding reach measured from the hull centre (the server's gap is from the side: half the root's X).
function Board.ringFor(halfBeam: number): number
	return math.max(Board.RING, Board.REACH + halfBeam)
end

-- Turning toward a survivor inside OUTER eases the craft to a speed whose turning circle passes through
-- their ring; a hands-off helm within NUDGE_ANGLE of them gets up to NUDGE of helm toward them.
Board.OUTER = 220 -- studs: about a full-throttle RIB's turning circle -- tune
Board.NUDGE_ANGLE = 40 -- degrees off the bow -- tune
Board.NUDGE = 0.35 -- of full helm, never more: the player still steers -- tune

-- The fastest speed whose turning circle (tangent to the bow) passes within `ring` of a point `dist` off
-- at `sinB` (|sin| of its bearing off the bow). The circle is max(minRadius, v / yawRate, v^2 / lateralAccel).
-- math.huge when already heading through the ring; ASSIST_SPEED when it sits inside the tightest circle.
function Board.turnSpeed(
	dist: number,
	sinB: number,
	ring: number,
	yawRate: number,
	minRadius: number,
	lateralAccel: number
): number
	local miss = dist * sinB - ring
	if miss <= 0 then
		return math.huge
	end
	local r = (dist * dist - ring * ring) / (2 * miss) -- the widest circle that still reaches the ring
	if r < minRadius then
		return Board.ASSIST_SPEED
	end
	return math.max(Board.ASSIST_SPEED, math.min(yawRate * r, math.sqrt(lateralAccel * r)))
end

-- Hands-off helm nudge toward a survivor `bearingDeg` off the bow (positive: to starboard / right).
function Board.nudge(steer: number, bearingDeg: number, dist: number): number
	if steer ~= 0 or dist > Board.OUTER or math.abs(bearingDeg) > Board.NUDGE_ANGLE then
		return steer
	end
	return math.clamp(bearingDeg / Board.NUDGE_ANGLE * 2, -1, 1) * Board.NUDGE
end

function Board.hasRoom(model: Model?): boolean
	local cap = model and model:GetAttribute("Capacity")
	local count = model and model:GetAttribute("SurvivorCount")
	return type(cap) ~= "number" or (tonumber(count) or 0) < cap
end

-- Big calls: may this track take (claim, board) the casualty? Not yet home, not lifted, and unclaimed or
-- already its own, so a crew boards whichever survivor it reaches and never one another crew is fetching.
function Board.mayTake(c: { [string]: any }, trackId: string): boolean
	return not c.delivered and not c.takenOver and (c.claimedBy == nil or c.claimedBy == trackId)
end

-- PrivateTo: the mission crew's UserIds as " 1 2 " (RescueService sets it; cleared once aboard).
function Board.privateList(userIds: { number }): string
	return ` {table.concat(userIds, " ")} `
end

-- May this player see and board the casualty? nil = public (free-roam swimmers, big calls).
function Board.mayAct(privateTo: any, userId: number): boolean
	return type(privateTo) ~= "string" or string.find(privateTo, ` {userId} `, 1, true) ~= nil
end

return Board
