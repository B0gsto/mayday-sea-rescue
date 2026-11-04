--!strict
-- Boat/GoBack (docs/30 section 1): the rules of the Go back button, pure (tests/GoBack.spec.luau). The server
-- (VehicleService) validates every press with them; GoBackController shows the button by the same rule.
local ColdOpen = require(script.Parent.ColdOpen)
local UpgradeStation = require(script.Parent.Parent.UpgradeStation)

local GoBack = {}

GoBack.CHARGE = 1.5 -- s from the press to the landing -- tune
GoBack.LAND_HOLD = 0.3 -- s the hull stays anchored at home: the pivot reaches every client before one owns it again
GoBack.COOLDOWN = 2 -- s between presses: longer than CHARGE + LAND_HOLD
GoBack.CHARGE_FOV = 30 -- degrees the camera widens over the charge -- tune
GoBack.BAY_RADIUS = 60 -- studs round the Upgrade Station's landing: already there, no button -- tune

-- Is `at` in the bay Go back lands in? It lies straight out from the berth (`bay`: its CFrame, seaward along -Z).
local function inBay(at: Vector3, bay: any): boolean
	if typeof(bay) ~= "CFrame" then
		return false
	end
	local p = (bay * CFrame.new(0, 0, -UpgradeStation.LANDING_OUT)).Position
	return Vector3.new(at.X - p.X, 0, at.Z - p.Z).Magnitude <= GoBack.BAY_RADIUS
end

-- Home for the button, the first trip and the long pick-up reach: the drop-off zone or the bay.
function GoBack.isHome(at: Vector3, bay: any): boolean
	return ColdOpen.atDropOff(at, bay) or inBay(at, bay)
end

-- The boat level's extra pick-up studs (up to 198). Near home they don't count: from the bay they would board the
-- cove-mouth swimmers (AmbientMix.HOME_CLEAR out), and Go back would pay for them with no trip at all.
GoBack.REACH_HOME = 320 -- studs from the berth: AmbientMix.HOME_CLEAR (tests/GoBack.spec)
function GoBack.reachAt(at: Vector3, bay: any, reach: number): number
	local p = ColdOpen.dropOff(bay)
	local home = p ~= nil and Vector3.new(at.X - p.X, 0, at.Z - p.Z).Magnitude < GoBack.REACH_HOME
	return if home then 0 else reach
end

export type State = {
	driving: boolean, -- in the craft's DriverSeat
	coldOpenDone: boolean,
	survivors: number, -- aboard this craft
	testRide: boolean,
	at: Vector3, -- the craft
	bay: any, -- the driver's berth (player attribute BayCFrame)
	spinning: boolean?, -- the prize wheel's sequence is running (server attribute WheelSpinning)
}

-- Why this press does nothing, or nil when it goes.
function GoBack.refusal(s: State): string?
	if not s.driving then
		return "NotDriving"
	elseif s.spinning then
		return "Spinning"
	elseif s.testRide then
		return "TestRide"
	elseif not s.coldOpenDone and s.survivors <= 0 then
		return "ColdOpen" -- the first rescue comes first
	elseif not ColdOpen.dropOff(s.bay) then
		return "NoHome"
	elseif GoBack.isHome(s.at, s.bay) then
		return "Home"
	end
	return nil
end

-- The rate limit: last is the os.clock of the last press that counted, nil for none.
function GoBack.ready(last: number?, now: number): boolean
	return last == nil or now - last >= GoBack.COOLDOWN
end

return GoBack
