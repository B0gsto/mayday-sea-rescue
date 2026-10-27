--!strict
-- LoadingPath: the loading screen's camera (src/first/LoadingScreen): a slow orbit high over the ring of
-- islands (round the lagoon at its centre, docs/23 (p)) while loading, then one straight eased hand-off from
-- wherever that orbit is to the normal third-person pose behind the player (docs/25 J: no orbit, no stop at
-- the spawn point).
--   orbit(center, angle), handoff(from, to, x)
local LoadingPath = {}

-- ~62 degrees down from ~740 studs: the whole ring in frame
LoadingPath.START_HEIGHT = 650
-- the camera over this height is inside / above Terrain.Clouds (a blank pale frame): the loading screen hides them
LoadingPath.CLOUD_BASE = 400
LoadingPath.START_RADIUS = 350
LoadingPath.ORBIT_SPEED = math.rad(6)
LoadingPath.HANDOFF_SECONDS = 1.2 -- the loading view -> behind the player tween
LoadingPath.FOV = 62

local function tilt(center: Vector3, angle: number, radius: number, height: number): CFrame
	local eye = center + Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
	return CFrame.lookAt(eye, center)
end

function LoadingPath.orbit(center: Vector3, angle: number): CFrame
	return tilt(center, angle, LoadingPath.START_RADIUS, LoadingPath.START_HEIGHT)
end

-- ease out: leaves at speed, settles on the player
function LoadingPath.handoffEase(t: number): number
	local x = math.clamp(t, 0, 1)
	return 1 - (1 - x) * (1 - x)
end

function LoadingPath.handoff(from: CFrame, to: CFrame, x: number): CFrame
	return from:Lerp(to, LoadingPath.handoffEase(x))
end

return table.freeze(LoadingPath)
