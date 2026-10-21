--!strict
-- GullPath (G76): the pure flight path of an ambient herring gull (WildlifeController, tests/Wildlife.spec.luau).
-- A loop is a circle or a figure-eight around `centre` with a slow altitude drift; `at` gives the gull's CFrame:
-- nose along the velocity (forward -Z, the authored axis), banked into the turn from the lateral acceleration.
local GullPath = {}

export type Loop = {
	centre: Vector3, -- Y is the mean altitude
	radius: number,
	speed: number, -- studs/s along a circle
	dir: number, -- 1 or -1
	eight: boolean,
	phase: number, -- radians
	drift: number, -- studs of slow altitude change
}

local G = 35 -- studs/s^2: the lateral acceleration that would bank 45 degrees (tune: smaller banks harder)
local MAX_BANK = math.rad(40)
local H = 0.05 -- s, finite-difference step

function GullPath.pos(l: Loop, t: number): Vector3
	local a = l.phase + l.dir * t * l.speed / l.radius
	local y = l.centre.Y + l.drift * math.sin(t * 0.13 + l.phase)
	if l.eight then
		return Vector3.new(
			l.centre.X + l.radius * math.sin(a),
			y,
			l.centre.Z + 0.6 * l.radius * math.sin(2 * a)
		)
	end
	return Vector3.new(l.centre.X + l.radius * math.cos(a), y, l.centre.Z + l.radius * math.sin(a))
end

function GullPath.at(l: Loop, t: number): CFrame
	local p0, p1, p2 = GullPath.pos(l, t - H), GullPath.pos(l, t), GullPath.pos(l, t + H)
	local cf = CFrame.lookAt(p1, p1 + (p2 - p0))
	local lateral = ((p2 - 2 * p1 + p0) / (H * H)):Dot(cf.RightVector)
	-- turning left (lateral < 0) rolls the right wing up: the inner wing drops
	return cf * CFrame.Angles(0, 0, math.clamp(math.atan(-lateral / G), -MAX_BANK, MAX_BANK))
end

return GullPath
