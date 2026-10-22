--!strict
-- AmbientPlan (RP-NPC1, docs/14 section 5): the pure rules behind the client's ambient town (AmbientController):
-- caps per quality tier, the weather / night routine, the pavement and lane routes from WorldConfig.Roads and the
-- static spots (residents, fishermen, shoppers, families, tourists) from WorldConfig, AssetIds and the quay layout.
-- Unit-tested in tests/Ambient.spec.luau (which also checks the spots against the server's Harbour layout).
--
--   AmbientPlan.CAPS[tier]                      { people, cars, radius }  tier = "low" | "medium" | "high"
--   AmbientPlan.carCap(tier, laneStuds, share) number  cars for the lane length inside the ring
--   AmbientPlan.routine(state, night)          { street, beach, quay, indoor, cars }  share 0..1 of each zone kept
--   AmbientPlan.routes()                        { Route }   pavements (both sides of every road but the slipway) and
--                                                           lanes (right-hand traffic, both ways, asphalt roads)
--   AmbientPlan.sample(route, s)               (pos, dir)  position and travel direction at arc length s (XZ)
--   AmbientPlan.nextLane(lanes, i)             number      the lane a car takes at the end of lane i
--   AmbientPlan.junctionStops(lanes, junctions) { {Stop} }  per lane, the RoadNet junctions it enters: where the car
--                                                           leaves the lane (stop line) and every exit (no U-turn)
--   AmbientPlan.turn(a, s0, b, s1)             Route       smooth path from lane a at s0 to lane b at s1
--   AmbientPlan.spots()                         { Spot }    the static NPC spots (Y = map hint; the caller ray-casts)
--   AmbientPlan.keep(i, share)                  boolean     deterministic: spot i stays out at this share
--   AmbientPlan.distToPolyline(p, points)      number      XZ distance
local AssetIds = require(script.Parent.Parent.Config.AssetIds)
local WorldConfig = require(script.Parent.Parent.Config.WorldConfig)

local AmbientPlan = {}

export type Route = {
	kind: string, -- "pavement" | "lane"
	road: string,
	points: { Vector3 },
	cum: { number }, -- arc length (XZ) at each point
	length: number,
}
export type Exit = { lane: number, s: number } -- join lane `lane` at arc length s
export type Stop = { at: number, exits: { Exit } } -- leave the lane at arc length `at` (the stop line)
export type Spot = {
	pos: Vector3,
	yaw: number, -- radians, the rig's -Z faces this way (CFrame.Angles(0, yaw, 0))
	role: string, -- NpcOutfits role
	pose: string, -- "Idle" | "Wave" | "Sit"
	zone: string, -- "street" | "beach" | "quay" | "indoor"
	kid: boolean?,
}

-- people = ambient humans at once, cars = traffic, radius = spawn / despawn ring round the player (studs).
-- An R15 rig is about 100 instances: high = ~2k instances, well inside the docs/10 section 6.7 20k budget.
-- RP-P1 trimmed the caps by about 15%: the crowd was not the frame-time cost, but it is free margin.
AmbientPlan.CAPS = {
	-- cars: town has ~4500 studs of lane inside the medium ring, so 18 is one per ~250 (12 left roads empty for 30 s)
	low = { people = 5, cars = 10, radius = 220 },
	medium = { people = 10, cars = 18, radius = 300 },
	high = { people = 18, cars = 28, radius = 380 },
}

-- Traffic scales with the road network: one car per LANE_PER_CAR studs of lane inside the ring, up to the tier cap.
AmbientPlan.LANE_PER_CAR = 140 -- tune
function AmbientPlan.carCap(tier: { cars: number }, laneStuds: number, share: number): number
	return math.floor(math.min(tier.cars, laneStuds / AmbientPlan.LANE_PER_CAR) * share + 0.5)
end

AmbientPlan.PAVEMENT = 1.5 -- studs beyond the road edge (the Chandlery front is 3 off Harbour Road)
AmbientPlan.NO_WALK = { SandsSlipway = true } -- never on the slipway
AmbientPlan.CAR_SURFACE = "Asphalt"

-- Storms send people indoors and empty the beach and the quay; night thins the street and clears the beach.
local ROUTINE: { [string]: { street: number, beach: number, quay: number, indoor: number, cars: number } } =
	{
		Calm = { street = 1, beach = 1, quay = 1, indoor = 1, cars = 1 },
		Warning = { street = 0.6, beach = 0.3, quay = 0.4, indoor = 1, cars = 0.8 },
		Storm = { street = 0, beach = 0, quay = 0, indoor = 1, cars = 0.5 },
		Clearing = { street = 0.6, beach = 0.3, quay = 0.6, indoor = 1, cars = 0.8 },
	}
local NIGHT = { street = 0.35, beach = 0, quay = 0.5, indoor = 1, cars = 0.5 }

function AmbientPlan.routine(state: string, night: boolean)
	local r = ROUTINE[state] or ROUTINE.Calm
	if not night then
		return table.clone(r)
	end
	return {
		street = math.min(r.street, NIGHT.street),
		beach = math.min(r.beach, NIGHT.beach),
		quay = math.min(r.quay, NIGHT.quay),
		indoor = math.min(r.indoor, NIGHT.indoor),
		cars = math.min(r.cars, NIGHT.cars),
	}
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function route(kind: string, road: string, points: { Vector3 }): Route
	local cum, s = { 0 }, 0
	for i = 2, #points do
		s += (flat(points[i]) - flat(points[i - 1])).Magnitude
		cum[i] = s
	end
	return { kind = kind, road = road, points = points, cum = cum, length = s }
end

-- the polyline `d` studs to the right of travel (negative = left), Y kept; repeated points dropped
local function offset(raw: { Vector3 }, d: number): { Vector3 }
	local points = {}
	for _, p in raw do
		if #points == 0 or flat(p - points[#points]).Magnitude > 1e-3 then
			table.insert(points, p)
		end
	end
	local out = {}
	for i, p in points do
		local a, b = points[math.max(i - 1, 1)], points[math.min(i + 1, #points)]
		local dir = flat(b - a).Unit
		table.insert(out, p + Vector3.new(-dir.Z, 0, dir.X) * d)
	end
	return out
end

local function reversed<T>(list: { T }): { T }
	local out = {}
	for i = #list, 1, -1 do
		table.insert(out, list[i])
	end
	return out
end

function AmbientPlan.routes(): { Route }
	local out = {}
	-- the quay promenade behind the coping: walkers and dog walkers pass the station slipway
	local x0, x1 =
		AmbientPlan.QUAY_X0 + 2,
		AmbientPlan.QUAY_X0 + AmbientPlan.QUAY_SLOTS * AmbientPlan.QUAY_GRID - 2
	local z = AmbientPlan.QUAY_FACE_Z - 4.5
	table.insert(out, route("pavement", "Quay", { Vector3.new(x0, 4, z), Vector3.new(x1, 4, z) }))
	for _, road in WorldConfig.Roads do
		if not AmbientPlan.NO_WALK[road.id] then
			local d = road.width / 2 + AmbientPlan.PAVEMENT
			table.insert(out, route("pavement", road.id, offset(road.points, d)))
			table.insert(out, route("pavement", road.id, offset(road.points, -d)))
		end
		if road.surface == AmbientPlan.CAR_SURFACE and not AmbientPlan.NO_WALK[road.id] then
			-- drive on the right: a quarter width right of the centre line, each way
			table.insert(out, route("lane", road.id, offset(road.points, road.width / 4)))
			table.insert(out, route("lane", road.id, offset(reversed(road.points), road.width / 4)))
		end
	end
	return out
end

function AmbientPlan.sample(r: Route, s: number): (Vector3, Vector3)
	local pts, cum = r.points, r.cum
	s = math.clamp(s, 0, r.length)
	for i = 2, #pts do
		if s <= cum[i] or i == #pts then
			local seg = cum[i] - cum[i - 1]
			local t = if seg > 0 then (s - cum[i - 1]) / seg else 0
			return pts[i - 1]:Lerp(pts[i], t), flat(pts[i] - pts[i - 1]).Unit
		end
	end
	return pts[1], Vector3.zAxis
end

-- the lane that starts where lane i ends (the road continues), else lane i's own reverse (U-turn)
function AmbientPlan.nextLane(lanes: { Route }, i: number): number
	local last = flat(lanes[i].points[#lanes[i].points])
	local back = i
	for j, l in lanes do
		if j ~= i then
			local first = flat(l.points[1])
			if l.road ~= lanes[i].road and (first - last).Magnitude < 25 then
				return j
			elseif l.road == lanes[i].road then
				back = j
			end
		end
	end
	return back
end

-- XZ distance and arc length of the nearest point of route r to p
local function locate(r: Route, p: Vector3): (number, number)
	local q, best, bestS = flat(p), math.huge, 0
	for i = 2, #r.points do
		local a, b = flat(r.points[i - 1]), flat(r.points[i])
		local ab = b - a
		local t = if ab.Magnitude > 0 then math.clamp((q - a):Dot(ab) / ab:Dot(ab), 0, 1) else 0
		local d = (q - (a + ab * t)).Magnitude
		if d < best then
			best, bestS = d, r.cum[i - 1] + ab.Magnitude * t
		end
	end
	return best, bestS
end

function AmbientPlan.junctionStops(lanes: { Route }, junctions: { any }): { { Stop } }
	local out = {}
	for i, l in lanes do
		local list: { Stop } = {}
		for _, j in junctions do
			local d, s = locate(l, j.pos)
			local _, dir = AmbientPlan.sample(l, s)
			local inArm = nil
			for _, a in j.arms do
				if a.road == l.road and a.dir:Dot(dir) < -0.7 then
					inArm = a
				end
			end
			if inArm and d < j.radius then
				local exits = {}
				for _, b in j.arms do
					if b ~= inArm then
						-- the lane of b's road leaving the junction along b
						for k, m in lanes do
							if m.road == b.road then
								local dk, sk = locate(m, j.pos)
								local _, dk2 = AmbientPlan.sample(m, sk)
								if
									dk < j.radius
									and dk2:Dot(b.dir) > 0.7
									and sk + b.stop < m.length
								then
									table.insert(exits, { lane = k, s = sk + b.stop })
								end
							end
						end
					end
				end
				if #exits > 0 then
					table.insert(list, { at = math.max(0, s - inArm.stop), exits = exits })
				end
			end
		end
		table.sort(list, function(x, y)
			return x.at < y.at
		end)
		out[i] = list
	end
	return out
end

-- cubic Bezier: turning, both handles reach toward the corner where the two lane lines meet (a right turn hugs the
-- kerb, a left turn swings wide across the junction); parallel lanes (straight on, or a turn-round loop onto the
-- reverse lane) get handles along the travel direction
function AmbientPlan.turn(a: Route, s0: number, b: Route, s1: number): Route
	local p0, d0 = AmbientPlan.sample(a, s0)
	local p1, d1 = AmbientPlan.sample(b, s1)
	local w = flat(p1 - p0)
	local den = d0.X * d1.Z - d0.Z * d1.X
	local c0, c1
	if math.abs(den) > 0.3 then
		local t = (w.X * d1.Z - w.Z * d1.X) / den
		local corner = p0 + d0 * t
		corner = Vector3.new(corner.X, (p0.Y + p1.Y) / 2, corner.Z)
		c0, c1 = p0:Lerp(corner, 0.55), p1:Lerp(corner, 0.55)
	else
		local h = if d0:Dot(d1) > 0 then w.Magnitude / 3 else math.max(w.Magnitude, 8)
		c0, c1 = p0 + d0 * h, p1 - d1 * h
	end
	local pts = {}
	for i = 0, 10 do
		local t = i / 10
		local u = 1 - t
		table.insert(
			pts,
			p0 * (u * u * u) + c0 * (3 * u * u * t) + c1 * (3 * u * t * t) + p1 * (t * t * t)
		)
	end
	return route("turn", "", pts)
end

function AmbientPlan.distToPolyline(p: Vector3, points: { Vector3 }): number
	local q, best = flat(p), math.huge
	for i = 2, #points do
		local a, b = flat(points[i - 1]), flat(points[i])
		local ab = b - a
		local t = if ab.Magnitude > 0 then math.clamp((q - a):Dot(ab) / ab:Dot(ab), 0, 1) else 0
		best = math.min(best, (q - (a + ab * t)).Magnitude)
	end
	return best
end

local function yawToward(from: Vector3, to: Vector3): number
	local d = flat(to - from)
	return math.atan2(-d.X, -d.Z)
end

-- Data the static spots come from (sources named; nothing here is a free-floating hand placement):
-- map/Build.luau House1..6 spots = Swaps cottage pivots (yawed 180: ATT_Door local -Z faces +Z, the harbour)
AmbientPlan.HOUSES = {
	Vector3.new(-150, 4, -192),
	Vector3.new(-60, 4, -192),
	Vector3.new(90, 4, -192),
	Vector3.new(130, 4, -192),
	Vector3.new(260, 4, -192),
	Vector3.new(310, 4, -192),
}
-- Harbour.QUAY straight slots with straight neighbours, clear of the slipway (1-3), the dock gangway (7), the pier
-- root (8-9), the steps (13-14), every ladder bay and the hospital gangway (35); checked in tests/Ambient.spec.luau
AmbientPlan.FISH_SLOTS = { 20, 26, 32, 37 }
AmbientPlan.QUAY_X0, AmbientPlan.QUAY_GRID, AmbientPlan.QUAY_FACE_Z = -182, 9, 4
AmbientPlan.QUAY_SLOTS = 41
-- the Chandlery shop floor (map/Build.luau buildChandlery x -74..-14, z -78..-42) under its ceiling lights
AmbientPlan.SHOP =
	{ Vector3.new(-56, 4.2, -58), Vector3.new(-34, 4.2, -60), Vector3.new(-46, 4.2, -52) }
-- the Harbour Light (map/Build.luau buildLighthouse base x 44, wallTop 6, wallFar 360) on the east breakwater head
AmbientPlan.LIGHTHOUSE = Vector3.new(44, 6, 360)

function AmbientPlan.spots(): { Spot }
	local out: { Spot } = {}
	-- residents at their front doors, every other house a neighbour chatting at the gate
	for n, base in AmbientPlan.HOUSES do
		local att = (AssetIds.Attachments :: any)[string.format("M_Bld_Cottage_%02d", n)]
		local door = if att and att.ATT_Door then att.ATT_Door else Vector3.new(0, 0, -8)
		local front = base + Vector3.new(-door.X, 0, -door.Z + 3) -- yaw 180: local (x, z) -> world (-x, -z)
		table.insert(
			out,
			{ pos = front, yaw = math.pi, role = "Passenger", pose = "Idle", zone = "street" }
		)
		if n % 2 == 1 then
			local gate = front + Vector3.new(3, 0, 2.5)
			table.insert(out, {
				pos = gate,
				yaw = yawToward(gate, front),
				role = "Passenger",
				pose = "Wave",
				zone = "street",
			})
			out[#out - 1].yaw = yawToward(front, gate)
		end
	end
	-- fishermen on the quay coping, looking out to sea (+Z)
	for _, slot in AmbientPlan.FISH_SLOTS do
		local x = AmbientPlan.QUAY_X0 + AmbientPlan.QUAY_GRID * (slot - 0.5)
		table.insert(out, {
			pos = Vector3.new(x, 4, AmbientPlan.QUAY_FACE_Z - 1.5),
			yaw = math.pi,
			role = "Boater",
			pose = "Idle",
			zone = "quay",
		})
	end
	-- browsing the Chandlery (indoors: storms leave them be)
	for i, p in AmbientPlan.SHOP do
		table.insert(
			out,
			{ pos = p, yaw = i * 2.1, role = "Passenger", pose = "Idle", zone = "indoor" }
		)
	end
	-- families on Haven Sands: on the dry sand, landward of the waterline (toward the car park)
	local beach = WorldConfig.Beaches[1]
	local carPark = WorldConfig.CarParks[1].center
	local along = flat(beach.to - beach.from)
	local n = Vector3.new(-along.Unit.Z, 0, along.Unit.X)
	if n:Dot(flat(carPark - beach.from)) < 0 then
		n = -n
	end
	for i, t in { 0.12, 0.26, 0.4, 0.68, 0.82 } do
		local p = beach.from:Lerp(beach.to, t) + n * 40
		local sea = p - n * 10
		table.insert(
			out,
			{ pos = p, yaw = yawToward(p, sea), role = "Swimmer", pose = "Idle", zone = "beach" }
		)
		local kid = p + along.Unit * 3 - n * 2
		table.insert(out, {
			pos = kid,
			yaw = yawToward(kid, sea),
			role = "Swimmer",
			pose = if i % 2 == 0 then "Wave" else "Idle",
			zone = "beach",
			kid = true,
		})
	end
	-- tourists photographing the Harbour Light from along the breakwater head (east of it)
	for i, dx in { 18, 24, 30 } do
		local p = AmbientPlan.LIGHTHOUSE + Vector3.new(dx, 0, (i - 2) * 3)
		table.insert(out, {
			pos = p,
			yaw = yawToward(p, AmbientPlan.LIGHTHOUSE),
			role = "Passenger",
			pose = if i == 2 then "Wave" else "Idle",
			zone = "quay",
		})
	end
	return out
end

-- a stable hash per spot so the same people stay out as the share changes (no flicker)
function AmbientPlan.keep(i: number, share: number): boolean
	local x = math.sin(i * 12.9898 + 78.233) * 43758.5453
	return x - math.floor(x) < share
end

return AmbientPlan
