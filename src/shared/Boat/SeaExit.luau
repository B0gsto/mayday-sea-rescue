--!strict
-- Boat/SeaExit: may a rider step off the boat here? Owner 2026-11-07: no jumping off freely at sea. Yes at home (the
-- drop-off and the Upgrade Station bay), in any island's station bay, beside a deck or shore, and in the shallows.
-- Pure: VehicleExitController and OpsController's seat-jump guard feed it their raycasts (tests/SeaExit.spec.luau).
local GoBack = require(script.Parent.GoBack)
local UpgradeStation = require(script.Parent.Parent.UpgradeStation)

local SeaExit = {}

SeaExit.SHALLOW = 5 -- studs of water over the sea floor a rider can stand in (sea level is y 0) -- tune

export type Facts = {
	at: Vector3, -- the seat
	bay: any, -- the player's BayCFrame attribute
	landBeside: boolean, -- a deck or shore to stand on beside the hull
	floorY: number?, -- the sea floor under the seat (nil: deeper than the probe)
}

function SeaExit.allowed(f: Facts): boolean
	if f.landBeside or GoBack.isHome(f.at, f.bay) then
		return true
	end
	if f.floorY and f.floorY >= -SeaExit.SHALLOW then
		return true
	end
	local button = UpgradeStation.buttonAt(UpgradeStation.nearest(f.at))
	return (button - f.at).Magnitude <= UpgradeStation.USE_RANGE
end

return SeaExit
