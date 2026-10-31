--!strict
-- TestRide (mon REVIEW #7): tap a locked Robux-only boat on your boat board and ride it for SECONDS in your own
-- bay, once a UTC day per boat. Pure rules (tests/TestRide.spec.luau). Server: server/Dock/BoatBoard (checks,
-- the ride loop), VehicleService (lends the craft, turns it back at the edge, sails it home), ProgressionService
-- (no ride Cash), OperationService (no calls). Client: BoatBoardController (the tap, timer, buoy ring, the card).
-- Player attributes while riding (server-set): TestRide = vehicle id, TestRideEnds = server unix end second,
-- TestRideAt = the bay centre (Vector3).

local TestRide = {}

TestRide.SECONDS = 60
TestRide.RADIUS = 110 -- studs from your berth: the buoy ring; past it the boat is turned back -- tune
TestRide.EDGE = 0.8 -- a boat past the ring is set back at this share of RADIUS, bow home
TestRide.COOLDOWN = 2 -- seconds between requests per player
TestRide.FLAG = "testRides" -- data.flags: { [vehicleId] = the UTC day it was last ridden }

export type Check = {
	passOnly: boolean, -- ProgressionConfig.Vehicles[id].passOnly
	passReady: boolean, -- its GamePass is on sale (ready, id > 0)
	owned: boolean,
	need: string?, -- the building it still needs (Robux never skips the order, so neither does a ride)
	lastDay: number?, -- flags.testRides[id]
	today: number,
	sinceAsk: number, -- seconds since this player's last request
	riding: boolean, -- already on a test ride
	busy: boolean, -- on a call, or the board's crane is busy
}

function TestRide.day(unix: number): number
	return math.floor(unix / 86400)
end

-- -> ok, why ("NotTryable" | "Owned" | "Needs" | "Cooldown" | "Riding" | "Busy" | "Today")
function TestRide.check(c: Check): (boolean, string?)
	if not (c.passOnly and c.passReady) then
		return false, "NotTryable"
	elseif c.owned then
		return false, "Owned"
	elseif c.need then
		return false, "Needs"
	elseif c.sinceAsk < TestRide.COOLDOWN then
		return false, "Cooldown"
	elseif c.riding then
		return false, "Riding"
	elseif c.busy then
		return false, "Busy"
	elseif c.lastDay == c.today then
		return false, "Today"
	end
	return true, nil
end

-- flags.testRides with `id` marked ridden today (a fresh table; junk entries dropped)
function TestRide.mark(flag: any, id: string, today: number): { [string]: number }
	local out = {}
	if type(flag) == "table" then
		for k, v in flag do
			if type(k) == "string" and type(v) == "number" then
				out[k] = v
			end
		end
	end
	out[id] = today
	return out
end

function TestRide.lastDay(flag: any, id: string): number?
	local v = if type(flag) == "table" then flag[id] else nil
	return if type(v) == "number" then v else nil
end

-- Cash a ride could earn is dropped while riding (rescues); crew pay, spins, quests and streaks still land.
function TestRide.blocksCash(reason: string): boolean
	return reason == "AmbientRescue" or string.sub(reason, 1, 3) == "Op:"
end

function TestRide.outside(pos: Vector3, centre: Vector3): boolean
	local d = Vector3.new(pos.X - centre.X, 0, pos.Z - centre.Z)
	return d.Magnitude > TestRide.RADIUS
end

-- Where a boat past the ring is set back: on its bearing at EDGE * RADIUS, at its own height
function TestRide.turnBack(pos: Vector3, centre: Vector3): Vector3
	local d = Vector3.new(pos.X - centre.X, 0, pos.Z - centre.Z)
	if d.Magnitude < 1e-3 then
		return pos
	end
	local at = centre + d.Unit * TestRide.RADIUS * TestRide.EDGE
	return Vector3.new(at.X, pos.Y, at.Z)
end

return TestRide
