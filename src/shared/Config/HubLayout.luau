--!strict
-- HubLayout (docs/23 (p), WP-27): where things go on the six player islands, a tight ring round an open lagoon (no
-- island at the centre). Pure data, built from WorldConfig.Ring (generated from tools/world/layout.py). Lune-safe.
--
-- Frames: an island's `frame` is CFrame.lookAt(centre, centre + facing) on its plate (Y = plateauY), `facing` the
-- unit vector out from the ring centre (the berth cove opens that way, to the open sea). Lots are { cframe, size }:
-- cframe on the ground at the lot centre, LookVector = the building's front; size = Vector2 (width along
-- RightVector, depth along LookVector). Berths are CFrames at sea level, LookVector = bow (pointing out to sea).
--
--   HubLayout.Center    the lagoon's centre (on the plate level); calls are measured from it
--   HubLayout.Islands   { Island } in WorldConfig order (Plot1..Plot6); HubLayout.byId[id]
--   Island.quest        { pontoon, slots } the quest pontoon (deck-top CFrame, LookVector out to sea, size
--                       QUEST_PONTOON) and the quest boats' mooring spots (sea level, LookVector = bow, toward the
--                       plate); boats sail in along -facing from out at sea. The quest tablet stands on lots.QuestTablet
--   HubLayout.Bridges   { Bridge } island i -> island i + 1 (a full ring); HubLayout.deckY(bridge, t) deck top at t
--   HubLayout.IslandPlate the Lego plate footprint (WP-24: the islands are not terrain); onPlate / plateContains
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

local HubLayout = {}
HubLayout.PlateauY = Y
HubLayout.Center = Ring.center
HubLayout.Ring = Ring.radius
HubLayout.IslandRadius = Ring.islandRadius
HubLayout.Notch = { island = Ring.islandNotch }

-- WP-24: a player island is a flat Lego plate built from Parts (src/server/World/IslandPlates.luau), a chamfered
-- square within the island's radius with a U cut-out (the berth notch, from WorldConfig.Ring.islandNotch) where the
-- berths are. `rects` are island-frame { r0, r1, f0, f1 } along right / fwd (frame:PointToObjectSpace's (X, -Z));
-- the plate top is at Y, the green slab `thick` studs below it. The rects are disjoint, inside |right|, |fwd| <=
-- edge, and leave the notch open (|right| < halfWidth, fwd > head). tests/HubLayout.spec.luau checks lots and bridges.
local CHAMFER = 47
local EDGE = Ring.islandRadius -- 160
local NOTCH = Ring.islandNotch
HubLayout.IslandPlate = {
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

-- a world point on island `isl`'s plate
function HubLayout.onPlate(isl: Island, worldX: number, worldZ: number): boolean
	local l = isl.frame:PointToObjectSpace(Vector3.new(worldX, Y, worldZ))
	return HubLayout.plateContains(l.X, -l.Z)
end

-- island-frame (right, fwd) inside the plate's rects
function HubLayout.plateContains(right: number, fwd: number): boolean
	for _, r in HubLayout.IslandPlate.rects do
		if right >= r[1] and right <= r[2] and fwd >= r[3] and fwd <= r[4] then
			return true
		end
	end
	return false
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
HubLayout.BRIDGE = BRIDGE

-- The quest pontoon (docs/23 (p)): off the front-left wing (clear of the berth cove), out to sea.
HubLayout.QUEST_PONTOON = Vector2.new(6, 36) -- width, length
HubLayout.QUEST_DECK_Y = Y - 1 -- a step down from the plate

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
		PaintBooth = lot(frame, 88, 20, 90, 30, 30),
		Helipad = lot(frame, -85, -40, 0, 40, 40),
		Hangar = lot(frame, -88, 35, 180, 40, 34), -- doors toward the helipad
		SubPen = lot(frame, -22, 80, 0, 30, 56, 0), -- over the cove water
		Jetty = lot(frame, 0, 68, 0, 10, 70, Y), -- along the cove centre from the quay
		BlueprintTable = lot(frame, 0, 42, 180, 6, 3, Y), -- on the jetty, by the quay
		CrewQuarters = lot(frame, 80, -60, -90, 40, 30),
		LifeguardTower = lot(frame, 125, -45, -90, 10, 10), -- on the beach
		Spare1 = lot(frame, -45, -95, 180, 32, 32),
		Spare2 = lot(frame, 45, -95, 180, 32, 32),
		Spare3 = lot(frame, 0, 8, 0, 40, 24), -- between the station and the cove
		QuestTablet = lot(frame, -100, 150, 180, 4, 3), -- on the wing by the quest pontoon, screen to the plate
	}
	lots.Helipad.clearRadius = 45 -- rotor clearance round the pad centre
	return lots
end

HubLayout.Islands = {} :: { Island }
HubLayout.byId = {} :: { [string]: Island }
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
				160 + HubLayout.QUEST_PONTOON.Y / 2,
				0,
				HubLayout.QUEST_DECK_Y
			),
			slots = { -- either side of the pontoon, bow in
				at(frame, -93, 171, 180, 0),
				at(frame, -77, 179, 180, 0),
				at(frame, -93, 189, 180, 0),
			},
		},
	}
	table.insert(HubLayout.Islands, island)
	HubLayout.byId[row.id] = island
end

HubLayout.Bridges = {} :: { Bridge }
for i, a in HubLayout.Islands do
	local b = HubLayout.Islands[i % #HubLayout.Islands + 1]
	local bis = (a.facing + b.facing).Unit -- the bisector between the two islands, out from the centre
	local mid = Vector3.new(HubLayout.Center.X, Y, HubLayout.Center.Z) + bis * BRIDGE.axisR
	local dir = Vector3.new(a.center.X - b.center.X, 0, a.center.Z - b.center.Z).Unit -- toward a
	table.insert(HubLayout.Bridges, {
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
function HubLayout.deckY(bridge: Bridge, t: number): number
	local s = math.abs(math.clamp(t, 0, 1) - 0.5) * (bridge.to - bridge.from).Magnitude
	local g, c = BRIDGE.grade, BRIDGE.crest
	return bridge.apexY - (if s < c then g * s * s / (2 * c) else g * (s - c / 2))
end

-- deck centre-line point at t (0 island a's end, 1 island b's end)
function HubLayout.deckAt(bridge: Bridge, t: number): Vector3
	local p = bridge.from:Lerp(bridge.to, t)
	return Vector3.new(p.X, HubLayout.deckY(bridge, t), p.Z)
end

return table.freeze(HubLayout)
