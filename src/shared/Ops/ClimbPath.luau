--!strict
-- Ops/ClimbPath: a boarded survivor's climb from the water onto a hull, in the hull's frame. The server
-- (VehicleService.Climb) and every client (CasualtyController, on its own copy of the driver-owned hull)
-- run the same path. Pure; Lune-tested in tests/ClimbPath.spec.luau.
local ClimbPath = {}

ClimbPath.SECONDS = 1.3 -- s: the whole climb -- tune
local EDGE = 0.8 -- studs out from the hull side at the top of the climb
local DROP = 1.6 -- studs below the seat, at the hull side
local HOP = 1.2 -- studs over the gunwale
local SIDE_AT = 0.45 -- of the climb: out to the side, then up and in over the rest

-- The survivor's pivot at `t` of the climb, in world space. `start` and `seat` are in hull space.
function ClimbPath.at(
	hull: CFrame,
	start: Vector3,
	side: number,
	halfBeam: number,
	seat: CFrame,
	t: number
): CFrame
	t = math.clamp(t, 0, 1)
	local here = hull * CFrame.new(start)
	local slot = hull * seat
	local edge = slot + hull.RightVector * side * (halfBeam + EDGE) - Vector3.new(0, DROP, 0)
	if t < SIDE_AT then
		return here:Lerp(edge, t / SIDE_AT)
	end
	return edge:Lerp(slot, (t - SIDE_AT) / (1 - SIDE_AT))
		+ Vector3.new(0, math.sin((t - SIDE_AT) / (1 - SIDE_AT) * math.pi) * HOP, 0)
end

return ClimbPath
