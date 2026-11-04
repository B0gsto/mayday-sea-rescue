--!strict
-- Boat/SeaEdge (docs/30): the world's edge is a soft turn, not a teleport. Past MapRadius the helm eases over until the
-- bow points back in; the player keeps the throttle and the wheel once headed home. Pure; BoatController applies it.
-- VehicleRecovery.lost only fires past MARGIN, which a boat turning at its level's radius never reaches.
local SeaEdge = {}

SeaEdge.BAND = 150 -- studs past the line until the turn is full lock -- tune
SeaEdge.MARGIN = 1500 -- studs past the line where a hull counts as lost: BAND + the widest turning circle, and plenty
SeaEdge.HOME_DOT = 0.5 -- headed within 60 degrees of the centre: the wheel is the player's again

-- The steer (-1 left .. 1 right, Buoyancy.steerTorque) for a hull at `cf`.
function SeaEdge.steer(cf: CFrame, steer: number, mapRadius: number): number
	local p = cf.Position
	local out = Vector3.new(p.X, 0, p.Z)
	local over = out.Magnitude - mapRadius
	if over <= 0 then
		return steer
	end
	local home = -out.Unit
	local look = cf.LookVector
	local forward = Vector3.new(look.X, 0, look.Z)
	if forward.Magnitude < 1e-3 then
		return steer
	end
	forward = forward.Unit
	if forward:Dot(home) >= SeaEdge.HOME_DOT then
		return steer
	end
	-- +Y yaw is left: home lies left when forward x home points up
	local toward = if forward:Cross(home).Y > 0 then -1 else 1
	return steer + (toward - steer) * math.min(over / SeaEdge.BAND, 1)
end

return SeaEdge
