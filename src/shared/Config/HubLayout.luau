--!strict
-- HubLayout (docs/23 (k), WP-18): where things go on the hub island and the six player islands. Pure data, built
-- from WorldConfig.Hub (generated from tools/world/layout.py, so it always matches the terrain bake). Lune-safe.
--
-- Frames: an island's `frame` is CFrame.lookAt(centre, centre + facing) on its plateau (Y = plateauY), `facing` the
-- unit vector out from the hub (the hub's: toward its harbour). Lots are { cframe, size }: cframe on the ground at
-- the lot centre, LookVector = the building's front; size = Vector2 (width along RightVector, depth along
-- LookVector). Berths are CFrames at sea level, LookVector = bow (pointing out to sea).
--
--   HubLayout.Hub       { center, frame, spawn, lots, dropOff, clearings, questSpots } (docs/23 (l): a forest island)
--       lots = { HQ (the lookout hut), CallBoard, ShopCounter (the market stall), Harbourmaster, Campfire, Monument,
--       Jetty (the visitor jetty) }; clearings[id] = { kind, center (on the ground), radius } from the bake (outpost,
--       bridge, quest, hidden); questSpots = { { id, cframe, radius } } empty camps for WP-21b's quest NPCs, the
--       cframe at the camp centre facing the hub centre
--   HubLayout.Islands   { Island } in WorldConfig order (Plot1..Plot6); HubLayout.byId[id]
--   HubLayout.Bridges   { Bridge } hub -> island; HubLayout.deckY(bridge, t) deck top at t (0 hub end, 1 island end)
--   HubLayout.IslandPlate the Lego plate footprint (WP-24: the islands are no longer terrain); onPlate / plateContains
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
	bridge: Bridge,
}
export type Bridge = {
	id: string,
	island: string,
	from: Vector3, -- deck top at the hub end (on the hub plateau)
	to: Vector3, -- deck top at the island end
	towers: { Vector3 }, -- tower foot centres (hub side, island side), on the ground
	towerTopY: number,
	cableLowY: number, -- the main cables' lowest point (mid-span)
	apexY: number, -- deck top at mid-span
	width: number,
}

local Hub = WorldConfig.Hub
local Y = Hub.plateauY

local HubLayout = {}
HubLayout.PlateauY = Y
HubLayout.Ring = Hub.ring
HubLayout.IslandRadius = Hub.islandRadius
HubLayout.HubRadius = Hub.radius
HubLayout.Notch = { hub = Hub.notch, island = Hub.islandNotch }

-- WP-24: a player island is no longer terrain: it is a flat Lego plate built from Parts
-- (src/server/World/IslandPlates.luau), a chamfered square within the island's old radius with a U cut-out (the
-- berth notch, from WorldConfig.Hub.islandNotch) where the berths are. `rects` are island-frame { r0, r1, f0, f1 }
-- along right / fwd (frame:PointToObjectSpace's (X, -Z)); the plate top is at Y (the plateau the lots already
-- use), the green slab `thick` studs below it. The rects are disjoint, inside |right|, |fwd| <= edge, and leave
-- the notch open (|right| < halfWidth, fwd > head). tests/HubLayout.spec.luau checks lots and bridges against it.
local CHAMFER = 47
local EDGE = Hub.islandRadius -- 160: the old island's radius
HubLayout.IslandPlate = {
	topY = Y,
	thick = 2,
	edge = EDGE,
	notch = { halfWidth = Hub.islandNotch.halfWidth, head = Hub.islandNotch.head },
	rects = {
		{ -EDGE + CHAMFER, -Hub.islandNotch.halfWidth, -EDGE + CHAMFER, EDGE - CHAMFER }, -- centre-left
		{ Hub.islandNotch.halfWidth, EDGE - CHAMFER, -EDGE + CHAMFER, EDGE - CHAMFER }, -- centre-right
		{
			-Hub.islandNotch.halfWidth,
			Hub.islandNotch.halfWidth,
			-EDGE + CHAMFER,
			Hub.islandNotch.head,
		}, -- centre-back
		{ -EDGE + CHAMFER, EDGE - CHAMFER, -EDGE, -EDGE + CHAMFER }, -- back edge (the bridge lands on it)
		{ -EDGE, -EDGE + CHAMFER, -EDGE + CHAMFER, EDGE - CHAMFER }, -- left edge
		{ EDGE - CHAMFER, EDGE, -EDGE + CHAMFER, EDGE - CHAMFER }, -- right edge
		{ -EDGE + CHAMFER, -Hub.islandNotch.halfWidth, EDGE - CHAMFER, EDGE }, -- fwd-left wing (notch mouth)
		{ Hub.islandNotch.halfWidth, EDGE - CHAMFER, EDGE - CHAMFER, EDGE }, -- fwd-right wing
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

local BRIDGE = {
	hubR = 320, -- deck ends this far from the hub centre (in its bridge-head clearing)
	islandBack = HubLayout.IslandPlate.edge, -- and this far behind an island's centre (the plate's back edge)
	towerHubR = 372, -- towers on the rims, so the span between them is all water
	towerIslandBack = HubLayout.IslandPlate.edge, -- the island tower stands on the plate's back edge
	apexY = 47, -- deck top at mid-span: underside 45.8 over the sea, every boat and the helicopter pass under
	towerTopY = 74,
	cableLowY = 57,
	width = 14,
}
HubLayout.BRIDGE = BRIDGE

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

-- the hub (docs/23 (l)): a forest island; the harbour on its forward face (south), the Landing clearing at its head
-- (spawn, the lookout hut HQ facing the harbour, the call board), the market stall in a clearing beside it. The hub
-- frame looks out of the harbour (+Z), so world x = -right, z = fwd.
do
	local frame = frameAt(Hub.center, Hub.bearing)
	local head = Hub.notch.head
	local clearings = {}
	local questSpots = {}
	for _, c in Hub.clearings do
		clearings[c.id] = { kind = c.kind, center = c.center, radius = c.radius }
		if c.kind == "quest" then
			local look = Vector3.new(Hub.center.X, c.center.Y, Hub.center.Z)
			table.insert(
				questSpots,
				{ id = c.id, cframe = CFrame.lookAt(c.center, look), radius = c.radius }
			)
		end
	end
	HubLayout.Hub = {
		center = Hub.center,
		frame = frame,
		spawn = at(frame, 0, head - 32, 180), -- on the Landing, facing the lookout hut
		lots = {
			HQ = lot(frame, 0, head - 85, 0, 24, 20), -- the coastguard lookout hut, front to the harbour
			CallBoard = lot(frame, -22, head - 68, 0, 12, 3),
			ShopCounter = lot(frame, -80, head - 85, -50, 20, 10), -- the market stall, turned to the Landing
			Harbourmaster = lot(frame, 100, head + 28, 90, 18, 14), -- the shack on the west quay, door to the harbour
			Campfire = lot(frame, 15, 45, 0, 30, 30),
			Monument = lot(frame, 0, -175, 0, 16, 16),
			Jetty = lot(frame, -36, head + 48, 0, 8, 92), -- the visitor jetty along the east harbour wall
		},
		dropOff = at(frame, 0, head + 15, 0, 0).Position, -- sea level, in the harbour
		clearings = clearings,
		questSpots = questSpots,
	}
end

-- a player island, in its local frame (right, fwd; fwd = out from the hub, the cove's mouth). The cove is the
-- plate's U cut-out (|right| < 45, fwd > 30); the bridge lands on the plate's back edge (fwd = -160). Buildings
-- stand on the plate.
local function islandLots(frame: CFrame): { [string]: Lot }
	local lots: { [string]: Lot } = {
		Station = lot(frame, 0, -35, 180, 60, 44), -- front toward the bridge
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
	}
	lots.Helipad.clearRadius = 45 -- rotor clearance round the pad centre
	return lots
end

HubLayout.Islands = {} :: { Island }
HubLayout.byId = {} :: { [string]: Island }
HubLayout.Bridges = {} :: { Bridge }
for i, row in Hub.islands do
	local frame = frameAt(row.center, row.bearing)
	local facing = facingOf(row.bearing)
	local hubFrame = frameAt(Hub.center, row.bearing) -- the same bearing from the hub centre
	local bridge: Bridge = {
		id = `Bridge{i}`,
		island = row.id,
		from = at(hubFrame, 0, BRIDGE.hubR).Position,
		to = at(frame, 0, -BRIDGE.islandBack).Position,
		towers = {
			at(hubFrame, 0, BRIDGE.towerHubR).Position,
			at(frame, 0, -BRIDGE.towerIslandBack).Position,
		},
		towerTopY = BRIDGE.towerTopY,
		cableLowY = BRIDGE.cableLowY,
		apexY = BRIDGE.apexY,
		width = BRIDGE.width,
	}
	local island: Island = {
		id = row.id,
		index = i,
		bearing = row.bearing,
		center = Vector3.new(row.center.X, Y, row.center.Z),
		facing = facing,
		frame = frame,
		spawn = at(frame, 0, -70), -- off the bridge, facing the station
		berths = {
			Boat = at(frame, 22, 95, 0, 0), -- starboard of the jetty, bow out of the cove
			Sub = at(frame, -22, 80, 0, 0), -- in the sub pen
		},
		lots = islandLots(frame),
		bridge = bridge,
	}
	table.insert(HubLayout.Islands, island)
	HubLayout.byId[row.id] = island
	table.insert(HubLayout.Bridges, bridge)
end

-- deck top Y along a bridge: a sine arch from the plateau at both ends to apexY at mid-span (max grade ~11 deg)
function HubLayout.deckY(bridge: Bridge, t: number): number
	return Y + (bridge.apexY - Y) * math.sin(math.pi * math.clamp(t, 0, 1))
end

-- deck centre-line point at t (0 hub end, 1 island end)
function HubLayout.deckAt(bridge: Bridge, t: number): Vector3
	local p = bridge.from:Lerp(bridge.to, t)
	return Vector3.new(p.X, HubLayout.deckY(bridge, t), p.Z)
end

return table.freeze(HubLayout)
