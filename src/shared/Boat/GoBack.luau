--!strict
-- Boat/GoBack (docs/30 section 1): the rules of the Go back button, pure (tests/GoBack.spec.luau). The server
-- (VehicleService) validates every press with them; GoBackController shows the button by the same rule.
local ColdOpen = require(script.Parent.ColdOpen)

local GoBack = {}

GoBack.CHARGE = 1.5 -- s from the press to the landing -- tune
GoBack.LAND_HOLD = 0.3 -- s the hull stays anchored at home: the pivot reaches every client before one owns it again
GoBack.COOLDOWN = 2 -- s between presses: longer than CHARGE + LAND_HOLD
GoBack.CHARGE_FOV = 30 -- degrees the camera widens over the charge -- tune

export type State = {
	driving: boolean, -- in the craft's DriverSeat
	coldOpenDone: boolean,
	survivors: number, -- aboard this craft
	testRide: boolean,
	at: Vector3, -- the craft
	bay: any, -- the driver's berth (player attribute BayCFrame)
}

-- Why this press does nothing, or nil when it goes.
function GoBack.refusal(s: State): string?
	if not s.driving then
		return "NotDriving"
	elseif s.testRide then
		return "TestRide"
	elseif not s.coldOpenDone and s.survivors <= 0 then
		return "ColdOpen" -- the first rescue comes first
	elseif not ColdOpen.dropOff(s.bay) then
		return "NoHome"
	elseif ColdOpen.atDropOff(s.at, s.bay) then
		return "Home"
	end
	return nil
end

-- The rate limit: last is the os.clock of the last press that counted, nil for none.
function GoBack.ready(last: number?, now: number): boolean
	return last == nil or now - last >= GoBack.COOLDOWN
end

return GoBack
