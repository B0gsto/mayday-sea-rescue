--!strict
-- PIW/Search: datum, drift, lookout and the expanding square (docs 09 section 5.2; IAMSAR
-- Vol II style, game values). A person in the water drifts mostly with the current; their head
-- shows only on some crests, so the lookout waits for it. Pure (Lune-tested).
local Units = require(script.Parent.Units)

local Search = {}

Search.LOST_SEC = 3 -- off the target longer than this counts as losing sight
Search.ON_TARGET_DEG = 5 -- reticle within this angle of them
Search.PATTERN_RANK_INDEX = 3 -- docs 09 says Coxswain; the top rank today (tune when ranks grow)
Search.LEG_TOLERANCE = 15 -- studs from the leg for "By the Book"

-- Where the datum has drifted to after `seconds` in a current (studs/s, flat).
function Search.drifted(datum: Vector3, current: Vector3, seconds: number): Vector3
	return datum + Units.flat(current) * seconds
end

function Search.startError(start: Vector3, truePos: Vector3): number
	return math.floor(Units.flatDistance(start, truePos) + 0.5)
end

-- Expanding square: legs of s, s, 2s, 2s, 3s, 3s ... each turned 90 deg to starboard.
function Search.expandingSquare(
	start: Vector3,
	firstDir: Vector3,
	spacing: number,
	legs: number
): { Vector3 }
	local dir = Units.unitOr(firstDir, Vector3.new(0, 0, -1))
	local pts = { Units.flat(start) }
	local p = Units.flat(start)
	for i = 1, legs do
		local len = spacing * math.ceil(i / 2)
		p += dir * len
		table.insert(pts, p)
		dir = Vector3.new(-dir.Z, 0, dir.X) -- 90 deg turn (clockwise seen from above, Roblox axes)
	end
	return pts
end

local function segDistance(p: Vector3, a: Vector3, b: Vector3): number
	local ab = b - a
	local len2 = ab:Dot(ab)
	if len2 < 1e-6 then
		return (p - a).Magnitude
	end
	local t = math.clamp((p - a):Dot(ab) / len2, 0, 1)
	return (p - (a + ab * t)).Magnitude
end

function Search.distanceToPath(p: Vector3, pts: { Vector3 }): number
	local fp = Units.flat(p)
	local best = math.huge
	for i = 1, #pts - 1 do
		best = math.min(best, segDistance(fp, pts[i], pts[i + 1]))
	end
	return best
end

export type SightEnv = { storm: boolean, lowLight: boolean, strobe: boolean, smoke: boolean }

-- Range (studs) a head in the water can be picked out at.
function Search.sightRange(env: SightEnv): number
	local r = if env.storm then 150 else 300
	if env.lowLight then
		r *= 0.6
	end
	if env.strobe and (env.storm or env.lowLight) then
		r = math.max(r, 420) -- a lifejacket strobe carries far at dusk and in rain
	end
	if env.smoke and not env.lowLight then
		r = math.max(r, 500) -- orange smoke by day is seen from far off
	end
	return r
end

-- Whether their head shows at time t: the swell hides them between crests.
function Search.showsOnCrest(t: number, seed: number, env: SightEnv): boolean
	local period = if env.storm then 5.5 else 7.5
	local showing = if env.storm then 0.4 else 0.7
	if env.strobe and (env.storm or env.lowLight) and ((t * 1.0) % 1) < 0.18 then
		return true -- a strobe flash shows even in a trough's spray
	end
	local x = ((t + seed * period) / period) % 1
	return x < showing
end

function Search.visible(t: number, seed: number, distance: number, env: SightEnv): boolean
	return distance <= Search.sightRange(env) and Search.showsOnCrest(t, seed, env)
end

export type Lookout = { offFor: number, lost: number, sighted: boolean, onSeconds: number }

function Search.lookout(): Lookout
	return { offFor = 0, lost = 0, sighted = false, onSeconds = 0 }
end

-- One tick of keeping eyes on: counts a loss once each time the eyes stay off past LOST_SEC.
function Search.keepEyesOn(l: Lookout, dt: number, onTarget: boolean): boolean
	if not l.sighted then
		return false
	end
	if onTarget then
		l.offFor = 0
		l.onSeconds += dt
		return false
	end
	local before = l.offFor
	l.offFor += dt
	if before < Search.LOST_SEC and l.offFor >= Search.LOST_SEC then
		l.lost += 1
		return true
	end
	return false
end

return Search
