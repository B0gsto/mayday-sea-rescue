--!strict
-- RingLayout (docs/23 (p), WP-27): where things go on the six player islands, a tight ring round an open lagoon (no
-- island at the centre). Pure data, built from WorldConfig.Ring (generated from tools/world/layout.py). Lune-safe.
--
-- Frames: an island's `frame` is CFrame.lookAt(centre, centre + facing) on its plate (Y = plateauY), `facing` the
-- unit vector out from the ring centre (the berth cove opens that way, to the open sea). Lots are { cframe, size }:
-- cframe on the ground at the lot centre, LookVector = the building's front; size = Vector2 (width along
-- RightVector, depth along LookVector). Berths are CFrames at sea level, LookVector = bow (pointing out to sea).
--
--   RingLayout.Center    the lagoon's centre (on the plate level); calls are measured from it
--   RingLayout.Islands   { Island } in WorldConfig order (Plot1..Plot6); RingLayout.byId[id]
--   Island.quest        { pontoon, slots } the quest pontoon (deck-top CFrame, LookVector out to sea, size
--                       QUEST_PONTOON) and the quest boats' mooring spots (sea level, LookVector = bow, toward the
--                       plate); boats sail in along -facing from out at sea. The quest tablet stands on lots.QuestTablet
--   RingLayout.Bridges   { Bridge } island i -> island i + 1 (a full ring); RingLayout.deckY(bridge, t) deck top at t
--   RingLayout.IslandPlate the Lego plate footprint (WP-24: the islands are not terrain); onPlate / plateContains
local WorldConfig = require(script.Parent.WorldConfig)

export type Lot = { cframe: CFrame, size: Vector2, clearRadius: number? }
export type Island = {
	id: string,
	index: number,
	bearing: number,
	center: Vector3,
	facing: Vector3,
	frame: CFrame,
	spawn: CFrame,
	berths: { Boat: CFrame, Sub: CFrame },
	lots: { [string]: Lot },
	quest: { pontoon: CFrame, slots: { CFrame } },
}
export type Bridge = {
	id: string,
	a: string, -- the island at t = 0
	b: string, -- the island at t = 1
	from: Vector3, -- deck top at a's end (on its plate)
	to: Vector3, -- deck top at b's end
	apexY: number, -- deck top at mid-span
	width: number,
}

local Ring = WorldConfig.Ring
local Y = Ring.plateauY

local RingLayout = {}
RingLayout.PlateauY = Y
RingLayout.Center = Ring.center
RingLayout.Ring = Ring.radius
RingLayout.IslandRadius = Ring.islandRadius
RingLayout.Notch = { island = Ring.islandNotch }

-- WP-24: a player island is a flat Lego plate built from Parts (src/server/World/IslandPlates.luau), a chamfered
-- square within the island's radius with a U cut-out (the berth notch, from WorldConfig.Ring.islandNotch) where the
-- berths are. `rects` are island-frame { r0, r1, f0, f1 } along right / fwd (frame:PointToObjectSpace's (X, -Z));
-- the plate top is at Y, the green slab `thick` studs below it. The rects are disjoint, inside |right|, |fwd| <=
-- edge, and leave the notch open (|right| < halfWidth, fwd > head). tests/RingLayout.spec.luau checks lots and bridges.
local CHAMFER = 47
local EDGE = Ring.islandRadius -- 160
local NOTCH = Ring.islandNotch
RingLayout.IslandPlate = {
	topY = Y,
	thick = 2,
	edge = EDGE,
	chamfer = CHAMFER,
	notch = { halfWidth = NOTCH.halfWidth, head = NOTCH.head },
	rects = {
		{ -EDGE + CHAMFER, -NOTCH.halfWidth, -EDGE + CHAMFER, EDGE - CHAMFER }, -- centre-left
		{ NOTCH.halfWidth, EDGE - CHAMFER, -EDGE + CHAMFER, EDGE - CHAMFER }, -- centre-right
		{ -NOTCH.halfWidth, NOTCH.halfWidth, -EDGE + CHAMFER, NOTCH.head }, -- centre-back
		{ -EDGE + CHAMFER, EDGE - CHAMFER, -EDGE, -EDGE + CHAMFER }, -- back edge (toward the lagoon)
		{ -EDGE, -EDGE + CHAMFER, -EDGE + CHAMFER, EDGE - CHAMFER }, -- left edge
		{ EDGE - CHAMFER, EDGE, -EDGE + CHAMFER, EDGE - CHAMFER }, -- right edge
		{ -EDGE + CHAMFER, -NOTCH.halfWidth, EDGE - CHAMFER, EDGE }, -- fwd-left wing (notch mouth)
		{ NOTCH.halfWidth, EDGE - CHAMFER, EDGE - CHAMFER, EDGE }, -- fwd-right wing
	},
}

-- docs/27 sea plates: Lego decks on pillars off the island's front edge (fwd 168 = past the trim and beach step),
-- either side of the berth channel (|right| < 40, 80 wide, straight out to sea). Island-frame rects { r0, r1, f0,
-- f1 }, deck top at Y. P1 carries the jump ramp (a wedge in the water off its outer end, angled 30 deg away from the
-- channel so a craft leaving the cove bears left onto it); P2 moors a second supply barge along its outer face.
-- Built or not, the keep-out (plates + ramp) holds no calls and the sea routes go round it. Only plates in this
-- table exist (P3+ are docs/27 later updates). tests/SeaPlates.spec.luau checks the docs/27 limits.
RingLayout.SeaPlates = {
	SeaPlate1 = { rect = { -163, -40, 168, 264 } },
	SeaPlate2 = { rect = { 40, 163, 168, 264 } },
} :: { [string]: { rect: { number } } }
RingLayout.SEA_PLATE_DECK = 1 -- deck thickness (top at Y); the pillars show 2 courses above the water
RingLayout.RAMP = { at = Vector2.new(-50, 300), yaw = 30, length = 32, width = 14, lip = 6 } -- island frame
RingLayout.SEA_KEEP_OUT = {
	RingLayout.SeaPlates.SeaPlate1.rect,
	RingLayout.SeaPlates.SeaPlate2.rect,
	{ -70, -30, 276, 324 }, -- the ramp's footprint (RAMP, turned)
}
-- With SeaPlate1 built the quest pontoon, its boats and tablet move out with the island (docs/27: P1's outer-left
-- corner), clear of the ramp and the channel: island-frame shift (right, fwd).
RingLayout.QUEST_SHIFT = Vector2.new(-20, 104)

-- island-frame (right, fwd) within `margin` of the sea plates' keep-out
local function inKeepOut(right: number, fwd: number, margin: number): boolean
	for _, r in RingLayout.SEA_KEEP_OUT do
		if
			right >= r[1] - margin
			and right <= r[2] + margin
			and fwd >= r[3] - margin
			and fwd <= r[4] + margin
		then
			return true
		end
	end
	return false
end

-- a world point within `margin` studs of any island's sea plates or ramp (built or not)
function RingLayout.nearSeaPlate(worldX: number, worldZ: number, margin: number): boolean
	for _, isl in RingLayout.Islands do
		local l = isl.frame:PointToObjectSpace(Vector3.new(worldX, Y, worldZ))
		if inKeepOut(l.X, -l.Z, margin) then
			return true
		end
	end
	return false
end

-- a world point on island `isl`'s plate
function RingLayout.onPlate(isl: Island, worldX: number, worldZ: number): boolean
	local l = isl.frame:PointToObjectSpace(Vector3.new(worldX, Y, worldZ))
	return RingLayout.plateContains(l.X, -l.Z)
end

-- island-frame (right, fwd) inside the plate's rects
function RingLayout.plateContains(right: number, fwd: number): boolean
	for _, r in RingLayout.IslandPlate.rects do
		if right >= r[1] and right <= r[2] and fwd >= r[3] and fwd <= r[4] then
			return true
		end
	end
	return false
end

-- Sea routing (playtest 2026-10-26: the home pin pointed straight across the plate, so following it beached the
-- boat 60 m out): seaRoute(from, to) -> (leg, length). `leg` is where to steer now: `to` itself, or a node of an
-- ring of nodes round the first plate (and its sea plates) the straight line crosses (its front node sits just outside the cove mouth,
-- so a berth in the cove is reached through the mouth). Legs keep ROUTE_CLEAR off the plate (its trim skirt and the
-- bridge piers stand just outside it); the nodes sit in the plates' square-notched corners, clear of the neighbours. `length` is the route's flat length. No way round (a point on
-- a plate) gives (to, straight-line length).
local ROUTE_CLEAR = 12 -- studs: hull half-width + trim + piers
local ROUTE_R, ROUTE_D = EDGE + 25, EDGE + 25 -- node offsets, island frame: side / diagonal
local OCTAGON = {
	{ 0, ROUTE_R }, -- the cove mouth, out to sea
	{ ROUTE_D, ROUTE_D },
	{ ROUTE_R, 0 },
	{ ROUTE_D, -ROUTE_D },
	{ 0, -ROUTE_R },
	{ -ROUTE_D, -ROUTE_D },
	{ -ROUTE_R, 0 },
	{ -ROUTE_D, ROUTE_D },
	-- docs/27: past the sea plates and the ramp, so a route from the cove mouth goes out the channel first
	{ 0, 350 },
	{ ROUTE_D, 350 },
	{ -ROUTE_D, 350 },
}

local OBSTACLES = table.clone(RingLayout.IslandPlate.rects) -- the plate and the sea plates' keep-out
table.move(RingLayout.SEA_KEEP_OUT, 1, #RingLayout.SEA_KEEP_OUT, #OBSTACLES + 1, OBSTACLES)

local function localOf(isl: Island, p: Vector3): Vector2
	local l = isl.frame:PointToObjectSpace(Vector3.new(p.X, Y, p.Z))
	return Vector2.new(l.X, -l.Z)
end

-- where (0..1) the segment a -> b (island frame) first comes within ROUTE_CLEAR of the plate, nil if it never does
-- (slab clipping)
local function entry(a: Vector2, b: Vector2): number?
	local d = b - a
	local best: number? = nil
	for _, r in OBSTACLES do
		local t0, t1 = 0, 1
		for _, ax in
			{
				{ a.X, d.X, r[1] - ROUTE_CLEAR, r[2] + ROUTE_CLEAR },
				{ a.Y, d.Y, r[3] - ROUTE_CLEAR, r[4] + ROUTE_CLEAR },
			}
		do
			local p, v, lo, hi = ax[1], ax[2], ax[3], ax[4]
			if math.abs(v) < 1e-9 then
				if p < lo or p > hi then
					t0 = 2
				end
			else
				local u0, u1 = (lo - p) / v, (hi - p) / v
				t0, t1 = math.max(t0, math.min(u0, u1)), math.min(t1, math.max(u0, u1))
			end
		end
		if t0 <= t1 and (not best or t0 < best) then
			best = t0
		end
	end
	return best
end

local function flatDist(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

function RingLayout.seaRoute(from: Vector3, to: Vector3, depth: number?): (Vector3, number)
	local straight = flatDist(from, to)
	local isl, first = nil :: Island?, math.huge
	for _, i in RingLayout.Islands do
		local t = entry(localOf(i, from), localOf(i, to))
		if t and t < first then
			isl, first = i, t
		end
	end
	if not isl then
		return to, straight
	end
	-- shortest path from -> octagon nodes -> to, edges that keep off this plate (Dijkstra on 10 nodes)
	local pts: { Vector2 } = { localOf(isl, from) }
	for _, o in OCTAGON do
		table.insert(pts, Vector2.new(o[1], o[2]))
	end
	table.insert(pts, localOf(isl, to))
	local n = #pts
	local dist, prev, done =
		{ [1] = 0 } :: { [number]: number }, {} :: { [number]: number }, {} :: { [number]: boolean }
	while true do
		local u, du = nil :: number?, math.huge
		for i = 1, n do
			if not done[i] and dist[i] and dist[i] < du then
				u, du = i, dist[i]
			end
		end
		if not u or u == n then
			break
		end
		done[u] = true
		for v = 2, n do
			if not done[v] and not entry(pts[u], pts[v]) then
				local dv = du + (pts[v] - pts[u]).Magnitude
				if dv < (dist[v] or math.huge) then
					dist[v], prev[v] = dv, u
				end
			end
		end
	end
	if not dist[n] then
		return to, straight
	end
	local step = n
	while prev[step] ~= 1 do
		step = prev[step]
	end
	if step == n then
		return to, dist[n]
	end
	local o = OCTAGON[step - 1]
	local node = (isl.frame * CFrame.new(o[1], 0, -o[2])).Position
	node = Vector3.new(node.X, to.Y, node.Z)
	if (depth or 0) < 2 then -- the first leg may itself cross a neighbour's plate
		local leg, len = RingLayout.seaRoute(from, node, (depth or 0) + 1)
		return leg, dist[n] - flatDist(from, node) + len
	end
	return node, dist[n]
end

-- Neighbour bridges (docs/23 (p)): straight across the gap between two plates, crossing the bisector axisR studs out
-- from the centre, where each deck enters its plate's side face just clear of the cut-out back corner (~93 studs of
-- water between the plates there). The deck climbs at `grade` (11.3 deg) from both ends to a rounded crest over
-- mid-span, so boats pass under.
local BRIDGE = {
	axisR = 400,
	half = 91, -- deck centre to each end: ~46 over the water + ~45 on the plate
	grade = 0.2,
	crest = 16, -- studs either side of mid-span the crest rounds over
	width = 12,
}
RingLayout.BRIDGE = BRIDGE

-- The quest pontoon (docs/23 (p)): off the front-left wing (clear of the berth cove), out to sea.
RingLayout.QUEST_PONTOON = Vector2.new(6, 36) -- width, length
RingLayout.QUEST_DECK_Y = Y - 1 -- a step down from the plate

local function facingOf(bearing: number): Vector3
	local b = math.rad(bearing)
	return Vector3.new(math.cos(b), 0, math.sin(b))
end

local function frameAt(center: Vector3, bearing: number): CFrame
	local c = Vector3.new(center.X, Y, center.Z)
	return CFrame.lookAt(c, c + facingOf(bearing))
end

-- a CFrame `right` / `fwd` studs from the frame origin, turned `yaw` degrees (0: same facing, 90: facing left)
local function at(frame: CFrame, right: number, fwd: number, yaw: number?, y: number?): CFrame
	local cf = frame * CFrame.new(right, 0, -fwd) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	return if y then cf - Vector3.new(0, cf.Position.Y - y, 0) else cf
end

local function lot(
	frame: CFrame,
	right: number,
	fwd: number,
	yaw: number,
	w: number,
	d: number,
	y: number?
): Lot
	return { cframe = at(frame, right, fwd, yaw, y), size = Vector2.new(w, d) }
end

-- a player island, in its local frame (right, fwd; fwd = out to sea, the cove's mouth). The cove is the plate's U
-- cut-out (|right| < 45, fwd > 30). Buildings stand on the plate.
local function islandLots(frame: CFrame): { [string]: Lot }
	local lots: { [string]: Lot } = {
		Station = lot(frame, 0, -35, 180, 60, 44), -- front toward the spawn
		Boathouse = lot(frame, 85, 62, 90, 34, 40), -- doors onto the cove
		Helipad = lot(frame, -85, -40, 0, 40, 40),
		Hangar = lot(frame, -88, 35, 180, 40, 34), -- doors toward the helipad
		SubPen = lot(frame, -22, 80, 0, 30, 56, 0), -- over the cove water
		Jetty = lot(frame, 0, 68, 0, 10, 70, Y), -- along the cove centre from the quay
		LifeguardTower = lot(frame, 125, -45, -90, 10, 10), -- on the beach
		Spare1 = lot(frame, -45, -95, 180, 32, 32),
		Spare2 = lot(frame, 45, -95, 180, 32, 32),
		Spare3 = lot(frame, 0, 8, 0, 40, 24), -- between the station and the cove
		QuestTablet = lot(frame, -100, 150, 180, 4, 3), -- on the wing by the quest pontoon, screen to the plate
	}
	lots.Helipad.clearRadius = 45 -- rotor clearance round the pad centre
	return lots
end

RingLayout.Islands = {} :: { Island }
RingLayout.byId = {} :: { [string]: Island }
for i, row in Ring.islands do
	local frame = frameAt(row.center, row.bearing)
	local island: Island = {
		id = row.id,
		index = i,
		bearing = row.bearing,
		center = Vector3.new(row.center.X, Y, row.center.Z),
		facing = facingOf(row.bearing),
		frame = frame,
		spawn = at(frame, 0, -70), -- behind the station, facing it
		berths = {
			Boat = at(frame, 22, 95, 0, 0), -- starboard of the jetty, bow out of the cove
			Sub = at(frame, -22, 80, 0, 0), -- in the sub pen
		},
		lots = islandLots(frame),
		quest = {
			pontoon = at(
				frame,
				-85,
				160 + RingLayout.QUEST_PONTOON.Y / 2,
				0,
				RingLayout.QUEST_DECK_Y
			),
			slots = { -- either side of the pontoon, bow in
				at(frame, -93, 171, 180, 0),
				at(frame, -77, 179, 180, 0),
				at(frame, -93, 189, 180, 0),
			},
		},
	}
	table.insert(RingLayout.Islands, island)
	RingLayout.byId[row.id] = island
end

RingLayout.Bridges = {} :: { Bridge }
for i, a in RingLayout.Islands do
	local b = RingLayout.Islands[i % #RingLayout.Islands + 1]
	local bis = (a.facing + b.facing).Unit -- the bisector between the two islands, out from the centre
	local mid = Vector3.new(RingLayout.Center.X, Y, RingLayout.Center.Z) + bis * BRIDGE.axisR
	local dir = Vector3.new(a.center.X - b.center.X, 0, a.center.Z - b.center.Z).Unit -- toward a
	table.insert(RingLayout.Bridges, {
		id = `Bridge{i}`,
		a = a.id,
		b = b.id,
		from = mid + dir * BRIDGE.half,
		to = mid - dir * BRIDGE.half,
		apexY = Y + BRIDGE.grade * (BRIDGE.half - BRIDGE.crest / 2),
		width = BRIDGE.width,
	})
end

-- deck top Y along a bridge: straight ramps at BRIDGE.grade from the plate at both ends, a parabolic crest over the
-- middle 2 x crest studs (the slope never passes the grade)
function RingLayout.deckY(bridge: Bridge, t: number): number
	local s = math.abs(math.clamp(t, 0, 1) - 0.5) * (bridge.to - bridge.from).Magnitude
	local g, c = BRIDGE.grade, BRIDGE.crest
	return bridge.apexY - (if s < c then g * s * s / (2 * c) else g * (s - c / 2))
end

-- deck centre-line point at t (0 island a's end, 1 island b's end)
function RingLayout.deckAt(bridge: Bridge, t: number): Vector3
	local p = bridge.from:Lerp(bridge.to, t)
	return Vector3.new(p.X, RingLayout.deckY(bridge, t), p.Z)
end

return table.freeze(RingLayout)
