--!strict
-- RaceRules (docs/16 K15): the NPC racer is pressure, not a wall. Pure, Lune-tested in
-- tests/RaceRules.spec.luau. No services and no Roblox types beyond Vector3.
--
-- The racer casts off only after a head start sized so a player who drives straight there in the
-- craft they have (base stats included) needs at most FAIR of the racer's time. It runs at SPEED,
-- below every base craft. Both take the same water route: in or out of the basin goes through the
-- harbour mouth (the breakwater is never cut). After a lost race the next GRACE calls have no racer.
local RaceRules = {}

RaceRules.SPEED = 40 -- studs/s (48 km/h): under the base lifeboat (46), RIB (62) and jet ski (69) -- tune
RaceRules.FAIR = 0.7 -- the player needs at most this share of the racer's time -- tune
RaceRules.CRUISE = 0.55 -- of top speed a new player averages (run-up, waves, turns) -- tune
RaceRules.BOARD = 6 -- s: from rest up to speed, braking alongside and the steady hold before the climb -- tune
RaceRules.LAUNCH = 15 -- s for a player on foot to reach a bay and cast off -- tune
RaceRules.WALK = 16 -- studs/s on foot (Humanoid WalkSpeed)
RaceRules.MIN_DELAY = 8 -- s: the racer always idles at the bays this long, siren on -- tune
RaceRules.ALONGSIDE = 30 -- studs: a player boat this close when the racer arrives was there first -- tune
RaceRules.GRACE = 2 -- calls with no racer after losing one -- tune
RaceRules.START = Vector3.new(-70, 0, 120) -- off the launch bays, in the basin
-- the gap between the breakwater heads (x -30..30, z 352..368): one waypoint each side of it
RaceRules.INNER_MOUTH = Vector3.new(0, 0, 330)
RaceRules.OUTER_MOUTH = Vector3.new(0, 0, 400)

-- Inside the breakwater (the basin, its arms at x +-320 and heads at z 368).
function RaceRules.inside(p: Vector3): boolean
	return p.Z < 368 and math.abs(p.X) < 328
end

-- Waypoints from `from` to `to` by water (excluding `from`, ending at `to`).
function RaceRules.route(from: Vector3, to: Vector3): { Vector3 }
	local a, b = RaceRules.inside(from), RaceRules.inside(to)
	if a == b then
		return { to }
	elseif a then
		return { RaceRules.INNER_MOUTH, RaceRules.OUTER_MOUTH, to }
	end
	return { RaceRules.OUTER_MOUTH, RaceRules.INNER_MOUTH, to }
end

-- Flat length of a route starting at `from`.
function RaceRules.length(from: Vector3, route: { Vector3 }): number
	local total, at = 0, from
	for _, p in route do
		total += Vector3.new(p.X - at.X, 0, p.Z - at.Z).Magnitude
		at = p
	end
	return total
end

-- Seconds a player needs: `distance` by water at CRUISE of `topSpeed` plus BOARD, and on foot the
-- walk to the bays (`walk` studs) and the cast-off.
function RaceRules.playerSeconds(
	distance: number,
	topSpeed: number,
	onFoot: boolean,
	walk: number?
): number
	local s = RaceRules.BOARD + distance / math.max(topSpeed * RaceRules.CRUISE, 1)
	if onFoot then
		s += RaceRules.LAUNCH + (walk or 0) / RaceRules.WALK
	end
	return s
end

-- Seconds after the accept before the racer casts off: it arrives at playerSeconds / FAIR.
function RaceRules.delay(playerSeconds: number, racerDistance: number): number
	return math.max(
		RaceRules.MIN_DELAY,
		playerSeconds / RaceRules.FAIR - racerDistance / RaceRules.SPEED
	)
end

return RaceRules
