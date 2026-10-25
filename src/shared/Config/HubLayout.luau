--!strict
-- HubLayout (docs/23 (k), WP-18): where things go on the hub island and the six player islands. Pure data, built
-- from WorldConfig.Hub (generated from tools/world/layout.py, so it always matches the terrain bake). Lune-safe.
--
-- Frames: an island's `frame` is CFrame.lookAt(centre, centre + facing) on its plateau (Y = plateauY), `facing` the
-- unit vector out from the hub (the hub's: toward its harbour). Lots are { cframe, size }: cframe on the ground at
-- the lot centre, LookVector = the building's front; size = Vector2 (width along RightVector, depth along
-- LookVector). Berths are CFrames at sea level, LookVector = bow (pointing out to sea).
--
--   HubLayout.Hub       { center, frame, spawn, lots = { HQ, CallBoard, ShopCounter }, dropOff }
--   HubLayout.Islands   { Island } in WorldConfig order (Plot1..Plot6); HubLayout.byId[id]
--   HubLayout.Bridges   { Bridge } hub -> island; HubLayout.deckY(bridge, t) deck top at t (0 hub end, 1 island end)
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

local BRIDGE = {
	hubR = 120, -- deck ends this far from the hub centre
	islandBack = 90, -- and this far behind an island's centre (both on the plateau)
	towerHubR = 185, -- towers on the rims, so the span between them is all water
	towerIslandBack = 145,
	apexY = 50, -- deck top at mid-span: underside 48.8 over the sea, every boat and the helicopter pass under
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

-- the hub: harbour on its forward face, the HQ facing it across a plaza, the spawn on the plaza facing the HQ door
do
	local frame = frameAt(Hub.center, Hub.bearing)
	HubLayout.Hub = {
		center = Hub.center,
		frame = frame,
		spawn = at(frame, 0, 30, 180),
		lots = {
			HQ = lot(frame, 0, -20, 0, 64, 44), -- the Coastguard station
			CallBoard = lot(frame, -45, 20, -90, 12, 3),
			ShopCounter = lot(frame, 45, 20, 90, 20, 10),
		},
		dropOff = at(frame, 0, 110, 0, 0).Position, -- sea level, in the harbour
	}
end

-- a player island, in its local frame (right, fwd; fwd = out from the hub, the cove's mouth). The cove is the
-- notch (|right| < 45, fwd > 30); the bridge lands on the back (fwd < 0). Buildings stand on the plateau.
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
