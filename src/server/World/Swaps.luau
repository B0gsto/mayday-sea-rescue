--!strict
-- Swaps: greybox -> production Package swaps placed at run time by WorldDressingService (I1, docs/12 section 3.2).
-- One entry per building. map/Build.luau still builds the greybox (tagged GREYBOX, attribute AssetSwap = <key>);
-- when every asset of an entry loads, the greybox is destroyed and the Packages take its place, else it stays.
--
--   greybox   path under Workspace.Map of the greybox model it replaces
--   pivot     the shared authored pivot of all the entry's assets (they are built in one frame)
--   shell     assets of the exterior model  (Workspace.Dressing.<key>, ModelStreamingMode Atomic)
--   interior  assets of the interior model  (Workspace.Dressing.<key>Interior, Atomic, streams on its own)
--   door      optional auto door: parts swung about a hinge attachment when a character comes near
--             (roll = true: a roller door, the parts roll up into their head instead of swinging)
--   hide      true: the greybox is kept as an invisible collider instead of destroyed (other services read it)
--   rig       optional module in this folder: rig.apply(shell1, interior1, interior2, interior3) (lights, glass)

export type Swap = {
	greybox: { string },
	pivot: CFrame,
	shell: { string },
	interior: { string }?,
	door: {
		asset: string,
		parts: { string },
		hinge: string,
		trigger: string,
		angle: number,
		roll: boolean?,
	}?,
	hide: boolean?,
	ground: number?, -- the pivot Y follows the highest terrain within this many studs (WorldDressingService)
	pad: { number }?, -- {x0, y0, x1, y1} asset-frame metres (Blender X, Y): terrain filled up to the pivot under it
	rig: string?,
	lod: string?,
	collide: boolean?, -- false: the uploads' _COL hulls stay off (single-mesh hulls fill door gaps)
	colliders: { { number } }?, -- invisible boxes {x0, y0, z0, x1, y1, z1} in the asset frame, metres
	ramps: { { number } }?, -- {x0, x1, yLow, zLow, yHigh, zHigh}: a stair ramp across x, metres
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubLayout = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("HubLayout")
)

local STATION_DY = 0.175 -- M_Bld_Station build.py (H2) recentres the upload: off.y (ATT_BoatHall sits at y 0)

-- station collider boxes in build.py metres -> the upload's frame (Y shifted by the recentring offset)
local function station(boxes: { { number } }): { { number } }
	for _, b in boxes do
		b[2] += STATION_DY
		b[5] += STATION_DY
	end
	return boxes
end

local Swaps: { [string]: Swap } = {
	-- H1 lifeboat station as the Coastguard HQ on the hub (docs/23 (k); art/source/buildings/M_Bld_Station/build.py):
	-- greybox Map.Hub.Station on HubLayout's HQ lot, pivot at the lot centre, the gables and bay door toward the
	-- hub harbour.
	Station = {
		greybox = { "Hub", "Station" },
		pivot = HubLayout.Hub.lots.HQ.cframe,
		shell = { "M_Bld_Station" },
		ground = 24, -- sit the floor on the terrain top
		-- the roller bay door (its own mesh) rolls up into the hood when someone comes near; the boat hall
		-- behind it is the walk-in space (the crew doors' leaves are baked into the Details mesh: closed)
		door = {
			asset = "M_Bld_Station",
			parts = { "M_Bld_Station_BayDoor_LOD0" },
			hinge = "ATT_BayDoorTop",
			trigger = "ATT_BayDoor",
			angle = 0,
			roll = true,
		},
		rig = "StationRig", -- door lamp, floods and the GlassLit panes: on at night / in a storm
		-- walkable collision from build.py (metres, X across, -Y sea front, Z up; the upload is recentred by
		-- +0.175 m in Y, added by station()): hall walls with the 6 x 4.6 m bay door gap (x -8.25..-2.25) and the
		-- 1 x 2.8 m back door gap (out to the yard), the
		-- granite hall floor, the crew wing (no interior: solid from the partition), the watch-room bay, an
		-- eaves cap. The upload's hull is one mesh, so it stays off.
		collide = false,
		colliders = station({
			{ -9.25, -7.6, -0.4, -1.0, 7.6, 0.08 }, -- hall floor (granite flags)
			{ -8.25, -8.1, -0.4, -2.25, -7.6, 0.08 }, -- bay door threshold
			{ -9.75, -8.1, 0, -9.25, 8.1, 7 }, -- hall west wall
			{ -9.75, 7.6, 0, -8.0, 8.1, 7 }, -- hall back wall, west of the back door
			{ -7.0, 7.6, 0, -1.0, 8.1, 7 }, -- hall back wall, east of the back door
			{ -8.0, 7.6, 2.8, -7.0, 8.1, 7 }, -- over the back door (x -8.0..-7.0: out to the yard and the VIP ladder)
			{ -9.75, -8.1, 0, -8.25, -7.6, 7 }, -- front wall west of the bay door
			{ -8.25, -8.1, 4.6, -2.25, -7.6, 7 }, -- over the bay door (roll hood)
			{ -2.25, -8.1, 0, -1.0, -7.6, 7 }, -- front wall east of the bay door
			{ -1.0, -8.1, 0, 9.75, 8.1, 7 }, -- partition + crew wing
			{ 2.5, -8.95, 3.5, 7.5, -8.1, 6.4 }, -- watch-room bay
			{ -10.0, -8.4, 7, 10.0, 8.4, 7.3 }, -- eaves cap (keeps the camera out of the roof void)
		}),
	},
}

return Swaps
