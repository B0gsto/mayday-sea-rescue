--!strict
-- LoadingPath: the loading screen's camera (src/first/LoadingScreen): a slow orbit high over the ring of
-- islands (round the lagoon at its centre, docs/23 (p)) behind the loading overlay; when it lifts the view is
-- already the normal third-person camera behind the player (docs/25 J: no orbit, no stop at the spawn point).
--   orbit(center, angle)
local LoadingPath = {}

-- ~62 degrees down from ~740 studs: the whole ring in frame
LoadingPath.START_HEIGHT = 650
-- the camera over this height is inside / above Terrain.Clouds (a blank pale frame): the loading screen hides them
LoadingPath.CLOUD_BASE = 400
LoadingPath.START_RADIUS = 350
LoadingPath.ORBIT_SPEED = math.rad(6)
LoadingPath.FOV = 62

local function tilt(center: Vector3, angle: number, radius: number, height: number): CFrame
	local eye = center + Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
	return CFrame.lookAt(eye, center)
end

function LoadingPath.orbit(center: Vector3, angle: number): CFrame
	return tilt(center, angle, LoadingPath.START_RADIUS, LoadingPath.START_HEIGHT)
end

return table.freeze(LoadingPath)
