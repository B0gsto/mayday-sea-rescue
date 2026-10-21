--!strict
-- Ops/Board: when a person in the water climbs aboard (auto_board and the free-roam AmbientRescueService,
-- 2026-10-21), and who may see and board a mission casualty (the Victim model's PrivateTo attribute).
-- Pure; Lune-tested in tests/AutoBoard.spec.luau.
local Board = {}

Board.REACH = 10 -- studs from the hull side
Board.STEADY_SPEED = 6 -- studs/s (about 4 knots): forgiving
Board.STEADY_TILT = 22 -- degrees of pitch or roll
Board.HOLD = 0.6 -- s close and steady before they climb
Board.RAM_SPEED = 14 -- studs/s
Board.CONTACT = 4 -- studs from the hull side
Board.BUMP_GAP = 2 -- s between bumps

-- May they climb aboard now?
function Board.ready(gap: number, speed: number, tiltDeg: number, room: boolean): boolean
	return room
		and gap <= Board.REACH
		and speed <= Board.STEADY_SPEED
		and tiltDeg <= Board.STEADY_TILT
end

-- Did the boat just run into them?
function Board.rammed(gap: number, speed: number): boolean
	return gap <= Board.CONTACT and speed >= Board.RAM_SPEED
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
