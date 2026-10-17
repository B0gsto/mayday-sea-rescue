--!strict
-- Ops/PiwMetrics: Person in the Water metrics the server measures itself (CONTRACT.md
-- "Operations v2": serverMetrics), so a client can't fake them. Pure: positions in, numbers out.
--   onPattern (search): the share of the search the boat spent on the expanding square, built on
--     the server from the drift-corrected datum (where the casualty really is when the search
--     starts), first leg into the wind. Only Navigators of pattern rank run one; others get 1.
--   destinationRight (transport): the pad the boat reached suits the casualty. A heli case
--     (not breathing, Serious or Critical) goes to the station, where Rescue Gale One meets it.
local PiwMetrics = {}

-- Mirrors src/client/Mechanics/search.luau and Mechanics/PIW/Search.luau (keep in step).
PiwMetrics.PATTERN_RANK_INDEX = 3
PiwMetrics.SPACING = 40 -- studs, track spacing
PiwMetrics.LEGS = 8
PiwMetrics.LEG_TOLERANCE = 15 -- studs from a leg counts as on it
PiwMetrics.START_RADIUS = 30 -- the pattern clock starts once the boat reaches the start
PiwMetrics.CLOSE = 60 -- closing in on the casualty counts as on task
-- Mirrors src/client/Mechanics/transport.luau (the client calls it done within 60 of a pad).
PiwMetrics.HELI_PAD = "Dock" -- Rescue Gale One meets a heli case at the station
PiwMetrics.PAD_RANGE = 90 -- studs from a pad's centre

export type Pattern = { pts: { Vector3 }, started: boolean, on: number, total: number }

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Expanding square: legs of s, s, 2s, 2s, 3s, 3s ... each turned 90 deg to starboard.
function PiwMetrics.expandingSquare(
	start: Vector3,
	firstDir: Vector3,
	spacing: number,
	legs: number
): { Vector3 }
	local d = flat(firstDir)
	local dir = if d.Magnitude > 1e-4 then d.Unit else Vector3.new(0, 0, -1)
	local p = flat(start)
	local pts = { p }
	for i = 1, legs do
		p += dir * (spacing * math.ceil(i / 2))
		table.insert(pts, p)
		dir = Vector3.new(-dir.Z, 0, dir.X)
	end
	return pts
end

function PiwMetrics.distanceToPath(point: Vector3, pts: { Vector3 }): number
	local p = flat(point)
	local best = math.huge
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local ab = b - a
		local len2 = ab:Dot(ab)
		local t = if len2 < 1e-6 then 0 else math.clamp((p - a):Dot(ab) / len2, 0, 1)
		best = math.min(best, (p - (a + ab * t)).Magnitude)
	end
	return best
end

-- windDirection: the WindDirection attribute (the wind blows toward (cos w, 0, sin w)).
function PiwMetrics.newPattern(start: Vector3, windDirection: number): Pattern
	local into = -Vector3.new(math.cos(windDirection), 0, math.sin(windDirection))
	return {
		pts = PiwMetrics.expandingSquare(start, into, PiwMetrics.SPACING, PiwMetrics.LEGS),
		started = false,
		on = 0,
		total = 0,
	}
end

function PiwMetrics.samplePattern(pattern: Pattern, boat: Vector3, casualty: Vector3, dt: number)
	local p = flat(boat)
	if not pattern.started then
		if (p - pattern.pts[1]).Magnitude > PiwMetrics.START_RADIUS then
			return
		end
		pattern.started = true
	end
	pattern.total += dt
	if
		PiwMetrics.distanceToPath(p, pattern.pts) <= PiwMetrics.LEG_TOLERANCE
		or (p - flat(casualty)).Magnitude <= PiwMetrics.CLOSE
	then
		pattern.on += dt
	end
end

-- 0..1; 1 when no pattern was due (below pattern rank) or the search ended before the start.
function PiwMetrics.onPattern(pattern: Pattern?): number
	if not pattern or pattern.total <= 0 then
		return 1
	end
	return math.floor(pattern.on / pattern.total * 100 + 0.5) / 100
end

-- Mirrors transport.luau's needsHeli (Medical.profile: notBreathing = Unresponsive, no lifejacket).
function PiwMetrics.needsHeli(state: string, lifejacket: boolean, band: string): boolean
	return (state == "Unresponsive" and not lifejacket) or band == "Critical" or band == "Serious"
end

function PiwMetrics.destinationRight(pad: string?, needsHeli: boolean, allowed: { string }): boolean
	if not pad or not table.find(allowed, pad) then
		return false
	end
	return not needsHeli or pad == PiwMetrics.HELI_PAD
end

-- The name of the nearest pad within range of a point, or nil.
function PiwMetrics.nearestPad(
	pads: { { name: string, position: Vector3 } },
	point: Vector3
): string?
	local best: string?, bestD = nil, PiwMetrics.PAD_RANGE
	for _, pad in pads do
		local d = (flat(pad.position) - flat(point)).Magnitude
		if d <= bestD then
			best, bestD = pad.name, d
		end
	end
	return best
end

return PiwMetrics
