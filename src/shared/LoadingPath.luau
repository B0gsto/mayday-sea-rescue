--!strict
-- LoadingPath: the loading screen's camera (src/first/LoadingScreen): a slow orbit high over the ring of
-- islands (round the lagoon at its centre, docs/23 (p)) while loading, then one eased flight that spirals down to
-- the player's island and sweeps past their name sign to a finish pose behind the character (or the cold-open jet
-- ski).
--   orbit(center, angle), spiral(x, ring, island, angle), approach(x, from, sweep, look, finish),
--   flyover(t, ring, island, angle, sweep, look, finish): t 0..1 eased once over the whole flight
local LoadingPath = {}

-- ~62 degrees down from ~740 studs: the whole ring (1,260 studs across) in frame
LoadingPath.START_HEIGHT = 650
LoadingPath.START_RADIUS = 350
LoadingPath.END_RADIUS = 70
LoadingPath.END_HEIGHT = 55
LoadingPath.TURNS = 1.25
LoadingPath.TRAVEL_SHARE = 0.6 -- of the spiral spent moving from the ring centre to the island
LoadingPath.SPIRAL_SHARE = 0.8
LoadingPath.ORBIT_SPEED = math.rad(6)
LoadingPath.FOV = 62

local TAU = math.pi * 2

local function smoothstep(t: number): number
	local x = math.clamp(t, 0, 1)
	return x * x * (3 - 2 * x)
end

local function tilt(center: Vector3, angle: number, radius: number, height: number): CFrame
	local eye = center + Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
	return CFrame.lookAt(eye, center)
end

function LoadingPath.ease(t: number): number
	return smoothstep(t)
end

function LoadingPath.orbit(center: Vector3, angle: number): CFrame
	return tilt(center, angle, LoadingPath.START_RADIUS, LoadingPath.START_HEIGHT)
end

-- spiral and approach take a linear 0..1; flyover eases once so the seam never stops the camera
function LoadingPath.spiral(x: number, ring: Vector3, island: Vector3, angle: number): CFrame
	-- cross to the island first and stay high doing it, then drop in circling it
	local center = ring:Lerp(island, math.min(1, x / LoadingPath.TRAVEL_SHARE))
	local radius = LoadingPath.START_RADIUS
		+ (LoadingPath.END_RADIUS - LoadingPath.START_RADIUS) * x
	local height = LoadingPath.START_HEIGHT
		+ (LoadingPath.END_HEIGHT - LoadingPath.START_HEIGHT) * x * x
	return tilt(center, angle + LoadingPath.TURNS * TAU * x, radius, height)
end

function LoadingPath.approach(
	x: number,
	from: CFrame,
	sweep: Vector3,
	look: Vector3,
	finish: CFrame
): CFrame
	local toLook = finish.Position + finish.LookVector * 12
	local fromLook = from.Position + from.LookVector * 40
	local control = sweep * 2 - (from.Position + finish.Position) * 0.5

	local a = from.Position:Lerp(control, x)
	local b = control:Lerp(finish.Position, x)
	local eye = a:Lerp(b, x)

	local lookControl = look * 2 - (fromLook + toLook) * 0.5
	local l0 = fromLook:Lerp(lookControl, x)
	local l1 = lookControl:Lerp(toLook, x)
	local target = l0:Lerp(l1, x)
	return CFrame.lookAt(eye, target)
end

function LoadingPath.flyover(
	t: number,
	ring: Vector3,
	island: Vector3,
	angle: number,
	sweep: Vector3,
	look: Vector3,
	finish: CFrame
): CFrame
	local e = smoothstep(t)
	local split = LoadingPath.SPIRAL_SHARE
	if e <= split then
		return LoadingPath.spiral(e / split, ring, island, angle)
	end
	local from = LoadingPath.spiral(1, ring, island, angle)
	return LoadingPath.approach((e - split) / (1 - split), from, sweep, look, finish)
end

return table.freeze(LoadingPath)
