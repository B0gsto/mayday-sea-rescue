--!strict
-- Ops/Board: when a person in the water climbs aboard (auto_board and the free-roam AmbientRescueService,
-- 2026-10-21), and who may see and board a mission casualty (the Victim model's PrivateTo attribute).
-- Pure; Lune-tested in tests/AutoBoard.spec.luau.
local Board = {}

Board.REACH = 14 -- studs from the hull side; wide enough to catch them passing at speed -- tune
Board.STEADY_SPEED = 10 -- studs/s: the heli winch and the sub pick-up still need a slow hover -- tune
Board.STEADY_TILT = 22 -- degrees of pitch or roll
Board.HOLD = 0.6 -- s close and steady before they climb (heli winch and sub only; boats take them at once)
-- The pick-up ring (PickupRingController): drawn on the water round a survivor, sized to the reach.
Board.RING = 12 -- studs, radius from the survivor to the hull centre -- tune

-- May they climb aboard now? docs/24 A: a boat takes them at any speed and tilt;
-- gap is from the hull side.
function Board.ready(gap: number, room: boolean): boolean
	return room and gap <= Board.REACH
end

-- Bigger craft. The ring is the boarding reach measured from the hull centre (the server's gap is from
-- the side: half the root's X).
function Board.ringFor(halfBeam: number): number
	return math.max(Board.RING, Board.REACH + halfBeam)
end

-- A hands-off helm within NUDGE_ANGLE of a survivor inside OUTER gets up to NUDGE of helm toward them.
Board.OUTER = 220 -- studs -- tune
Board.NUDGE_ANGLE = 40 -- degrees off the bow -- tune
Board.NUDGE = 0.35 -- of full helm, never more: the player still steers -- tune

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
