--!strict
-- Trailer rules, pure: when a boat floats off at a slipway, and the hitch angle (for the
-- reversing guide and a jackknife warning). docs 10 section 3.2.
local LandVehicleConfig = require(script.Parent.Parent.Config.LandVehicleConfig)

local Trailer = {}

Trailer.JACKKNIFE = 70 -- degrees between car and trailer where the guide warns -- tune

-- depth: studs of water above the trailer bed; speed: studs/s of the rig.
function Trailer.canLaunch(depth: number, speed: number): boolean
	return depth >= LandVehicleConfig.LaunchDepth
		and math.abs(speed) <= LandVehicleConfig.LaunchMaxSpeed
end

-- Signed hitch angle (degrees) from the car's heading to the trailer's, about +Y.
-- Positive when the trailer swings to the car's right... seen from above with -Z forward.
function Trailer.hitchAngle(carLook: Vector3, trailerLook: Vector3): number
	local a = math.atan2(-carLook.X, -carLook.Z)
	local b = math.atan2(-trailerLook.X, -trailerLook.Z)
	local d = (b - a + math.pi) % (2 * math.pi) - math.pi
	return math.deg(d)
end

-- Boat to carry: the first of LandVehicleConfig.TrailerBoats the player may use.
function Trailer.pickBoat(canUse: (string) -> boolean): string?
	for _, id in LandVehicleConfig.TrailerBoats do
		if canUse(id) then
			return id
		end
	end
	return nil
end

return Trailer
