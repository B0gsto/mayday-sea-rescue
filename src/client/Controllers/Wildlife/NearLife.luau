--!strict
-- NearLife (life1, "make the sea feel alive near the player"): the pure rules for the life that gathers round
-- the local player (SeaLifeController: fish jumps, dolphins bow-riding a fast boat; WildlifeController: gulls
-- trailing a boat overhead, gulls on posts lifting off as you pass, a curious seal that dives from a fast boat).
-- Lune-tested (tests/NearLife.spec.luau).
local NearLife = {}

NearLife.FAST = 38 -- studs/s (~25 knots): dolphins come to the bow, seals dive, perched gulls lift off -- tune
NearLife.SLOW = 12 -- studs/s: a seal surfaces to look at a boat this slow -- tune
NearLife.ARRIVE = 3 -- s for a bow-riding dolphin to swim in from the side

local WORDS = { "pile", "piling", "bollard", "post" }

-- The local player this frame (NearLife.update, client only): position, flat heading and speed, and whether
-- aboard something at sea level (a hull, not the helicopter).
NearLife.me =
	{ ok = false, pos = Vector3.zero, dir = Vector3.new(0, 0, -1), speed = 0, boat = false }

function NearLife.update()
	local me = NearLife.me
	local char = game:GetService("Players").LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		me.ok = false
		return
	end
	local seat = hum and hum.SeatPart
	local body: BasePart = seat or root
	local v = body.AssemblyLinearVelocity
	local flat = Vector3.new(v.X, 0, v.Z)
	me.ok, me.pos, me.speed = true, body.Position, flat.Magnitude
	if me.speed > 2 then
		me.dir = flat.Unit
	end
	me.boat = seat ~= nil and body.Position.Y < 12
end

-- Whether a part's name reads as something a gull stands on.
function NearLife.perchName(name: string): boolean
	local n = string.lower(name)
	for _, w in WORDS do
		if string.find(n, w, 1, true) then
			return true
		end
	end
	return false
end

-- A flat point `dist` studs from `origin`, `angle` radians off `forward` (any forward; flat -Z when there is none).
function NearLife.around(origin: Vector3, forward: Vector3, angle: number, dist: number): Vector3
	local f = Vector3.new(forward.X, 0, forward.Z)
	f = if f.Magnitude > 1e-3 then f.Unit else Vector3.new(0, 0, -1)
	return Vector3.new(origin.X, 0, origin.Z)
		+ CFrame.Angles(0, angle, 0):VectorToWorldSpace(f) * dist
end

-- `from` moved toward `goal` by at most `step` studs.
function NearLife.toward(from: Vector3, goal: Vector3, step: number): Vector3
	local d = goal - from
	return if d.Magnitude <= step then goal else from + d.Unit * step
end

-- The top centre of a part a gull can stand on (a pile, piling, bollard or post: narrow, upright-ish, top
-- above the sea), or nil. Works for cylinders laid along X too: extents are taken in world axes.
function NearLife.perchTop(name: string, cf: CFrame, size: Vector3): Vector3?
	if not NearLife.perchName(name) then
		return nil
	end
	local function ext(axis: Vector3): number
		return math.abs(cf.XVector:Dot(axis)) * size.X
			+ math.abs(cf.YVector:Dot(axis)) * size.Y
			+ math.abs(cf.ZVector:Dot(axis)) * size.Z
	end
	local h, w, d = ext(Vector3.yAxis), ext(Vector3.xAxis), ext(Vector3.zAxis)
	local top = cf.Position.Y + h / 2
	if h < 1 or w > 4 or d > 4 or top < 1.5 then
		return nil
	end
	return Vector3.new(cf.Position.X, top, cf.Position.Z)
end

-- Bow-riding dolphin `i` (1: port, 2: starboard) relative to the boat (X right, Y depth below the surface, Z
-- ahead), `age` s after it was called in and `out` (0..1) through peeling away: swims in from wide astern,
-- under the surface, holds a bow wave off the bow, then peels outward and down.
function NearLife.bow(i: number, age: number, out: number): Vector3
	local side = if i == 1 then -1 else 1
	local k = math.clamp(age / NearLife.ARRIVE, 0, 1)
	k = k * k * (3 - 2 * k)
	local x = side * (6 + 34 * (1 - k) + 30 * out)
	local z = 6 + 3 * i - 46 * (1 - k) - 20 * out
	return Vector3.new(x, -0.9 - 4 * math.max(out, 1 - k), z)
end

return NearLife
