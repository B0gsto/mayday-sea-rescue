--!strict
-- Swaps: greybox -> production Package swaps placed at run time by WorldDressingService (I1, docs/12 section 3.2).
-- One entry per building. map/Build.luau still builds the greybox (tagged GREYBOX, attribute AssetSwap = <key>);
-- when every asset of an entry loads, the greybox is destroyed and the Packages take its place, else it stays.
--
--   greybox   path under Workspace.Map of the greybox model it replaces
--   pivot     the shared authored pivot of all the entry's assets (they are built in one frame)
--   shell     assets of the exterior model  (Workspace.Dressing.<key>, ModelStreamingMode Atomic)
--   interior  assets of the interior model  (Workspace.Dressing.<key>Interior, Atomic, streams on its own)
--   prompts   greybox PromptAnchor marker -> asset attachment it moves to (the client needs a BasePart anchor)
--   door      optional auto door: parts swung about a hinge attachment when a character comes near
--             (roll = true: a roller door, the parts roll up into their head instead of swinging)
--   hide      true: the greybox is kept as an invisible collider instead of destroyed (other services read it)
--   rig       optional module in this folder: rig.apply(shell1, interior1, interior2, interior3) (lights, glass)

export type Swap = {
	greybox: { string },
	pivot: CFrame,
	shell: { string },
	interior: { string }?,
	prompts: { [string]: { marker: string, asset: string, attachment: string } }?,
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
	rig: string?,
	lod: string?,
	collide: boolean?, -- false: the uploads' _COL hulls stay off (single-mesh hulls fill door gaps)
	colliders: { { number } }?, -- invisible boxes {x0, y0, z0, x1, y1, z1} in the asset frame, metres
	ramps: { { number } }?, -- {x0, x1, yLow, zLow, yHigh, zHigh}: a stair ramp across x, metres
}

local LAND = 4 -- GameConfig.LandTopY (quay and town ground)
local STATION_DY = 0.175 -- M_Bld_Station build.py (H2) recentres the upload: off.y (ATT_BoatHall sits at y 0)

-- station collider boxes in build.py metres -> the upload's frame (Y shifted by the recentring offset)
local function station(boxes: { { number } }): { { number } }
	for _, b in boxes do
		b[2] += STATION_DY
		b[5] += STATION_DY
	end
	return boxes
end

-- M_Bld_Slipway build.py: slope K = DROP / RUN; the stepped retaining walls (H2) along both kerbs, 3 m bays
-- from the apron (y 3) to WEND (y -12), inner face WX0 = 3.663 m, 0.52 m thick with the coping, top 0.68 m
-- over the slope at each bay's upper end
local SLIP_K = (10 / 3) / 22
local function slipwayWalls(boxes: { { number } }): { { number } }
	for _, sx in { -1, 1 } do
		for ya = 3, -9, -3 do
			local yb = if ya == 3 then 0 else ya - 3
			local top = math.min(ya, 0) * SLIP_K + 0.68
			local x0, x1 = sx * 3.663, sx * 4.183
			table.insert(boxes, { math.min(x0, x1), yb, -4.5, math.max(x0, x1), ya, top })
		end
	end
	return boxes
end

local Swaps: { [string]: Swap } = {
	-- H2 Port Haven Chandlery (art/source/buildings/M_Bld_Chandlery_Ext/layout.py: pivot at the greybox centre,
	-- yawed 180 degrees so the shopfront faces Harbour Road, +Z; the greybox counter maps to ATT_Counter)
	Chandlery = {
		greybox = { "PortHaven", "Chandlery" },
		pivot = CFrame.new(-44, LAND, -60) * CFrame.Angles(0, math.pi, 0),
		shell = { "M_Bld_Chandlery_Ext" },
		interior = { "M_Bld_Chandlery_Int", "M_Prop_Chandlery", "M_Prop_Chandlery_Stock" },
		prompts = {
			ShopCounter = {
				marker = "CounterPrompt",
				asset = "M_Bld_Chandlery_Int",
				attachment = "ATT_Counter",
			},
		},
		door = {
			asset = "M_Bld_Chandlery_Ext",
			parts = { "M_Bld_Chandlery_Ext_Door_LOD0", "M_Bld_Chandlery_Ext_DoorGlass_LOD0" },
			hinge = "ATT_DoorHinge",
			trigger = "ATT_Door",
			angle = 95, -- opens inward (layout.DOOR: hinge at x -8.0, +Blender Z = +Y here)
		},
		rig = "ChandleryRig",
		-- walkable collision from layout.py (Blender frame metres: X frontage, -Y front, Z up): shell walls
		-- with the door gap (DOOR x -8.0..-6.8, 2.3 m), floors, the loft with its stairwell, counter, gondola,
		-- chart table; the stair as a ramp. The uploads' hulls are single meshes, so they stay off.
		collide = false,
		colliders = {
			{ -10, -6, -0.4, 10, 6, 0.15 }, -- ground floor
			{ -10, -6, 0, -8.0, -5.45, 6 }, -- front wall west of the door
			{ -8.0, -6, 2.45, -6.8, -5.45, 6 }, -- over the door
			{ -6.8, -6, 0, 10, -5.45, 6 }, -- front wall + bay glazing
			{ -10, 5.45, 0, 10, 6, 6 }, -- back wall
			{ -10, -6, 0, -9.45, 6, 6 }, -- west gable
			{ 9.45, -6, 0, 10, 6, 6 }, -- east gable
			{ -9.45, -5.45, 3.05, 8.3, 5.45, 3.35 }, -- loft floor (west of the stairwell)
			{ 8.3, -5.45, 3.05, 9.45, -1.4, 3.35 }, -- loft landing (front of the stairwell)
			{ 0.7, 0.6, 0.15, 7.3, 1.25, 1.15 }, -- counter
			{ -6.0, -1.5, 0.15, -1.6, -0.3, 1.55 }, -- gondola
			{ -3.2, 3.6, 0.15, -1.4, 4.6, 1.0 }, -- chart table
			{ -10, -6, 6, 10, 6, 6.3 }, -- ceiling cap (keeps the camera out of the roof void)
		},
		ramps = { { 8.3, 9.45, 4.9, 0.15, -1.4, 3.35 } },
	},
	-- H1 lifeboat station (art/source/buildings/M_Bld_Station/build.py: the greybox Station x -140..-80,
	-- z -90..-40, pivot at its centre yawed 180 degrees so the gables face the sea, +Z). The greybox has no
	-- PromptAnchor markers (the BoatDesk kiosk on the quay is its own model), so no prompts move.
	Station = {
		greybox = { "PortHaven", "Station" },
		pivot = CFrame.new(-110, LAND, -65) * CFrame.Angles(0, math.pi, 0),
		shell = { "M_Bld_Station" },
		-- the town terrain reads about 2 studs above LandTopY here (5.8 .. 6.0): sit the floor on it
		ground = 24,
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
		-- +0.175 m in Y, added by station()): hall walls with the 6 x 4.6 m bay door gap (x -8.25..-2.25), the
		-- granite hall floor, the crew wing (no interior: solid from the partition), the watch-room bay, an
		-- eaves cap. The upload's hull is one mesh, so it stays off.
		collide = false,
		colliders = station({
			{ -9.25, -7.6, -0.4, -1.0, 7.6, 0.08 }, -- hall floor (granite flags)
			{ -8.25, -8.1, -0.4, -2.25, -7.6, 0.08 }, -- bay door threshold
			{ -9.75, -8.1, 0, -9.25, 8.1, 7 }, -- hall west wall
			{ -9.75, 7.6, 0, -1.0, 8.1, 7 }, -- hall back wall
			{ -9.75, -8.1, 0, -8.25, -7.6, 7 }, -- front wall west of the bay door
			{ -8.25, -8.1, 4.6, -2.25, -7.6, 7 }, -- over the bay door (roll hood)
			{ -2.25, -8.1, 0, -1.0, -7.6, 7 }, -- front wall east of the bay door
			{ -1.0, -8.1, 0, 9.75, 8.1, 7 }, -- partition + crew wing
			{ 2.5, -8.95, 3.5, 7.5, -8.1, 6.4 }, -- watch-room bay
			{ -10.0, -8.4, 7, 10.0, 8.4, 7.3 }, -- eaves cap (keeps the camera out of the roof void)
		}),
	},
	-- H1 slipway (art/source/buildings/M_Bld_Slipway/build.py: pivot at the ramp head on the quay edge, yawed
	-- 180 degrees so the ramp runs down to +Z). Map.Slipways.StationSlipway stays as the hidden ramp surface:
	-- its top face is the asset's 22 m x 3.33 m slope (1:6.6), and VehicleService, OperationService,
	-- NpcService and DogService read its CFrame (launch stand, Aggie and the crew at the head).
	Slipway = {
		greybox = { "Slipways", "StationSlipway" },
		hide = true,
		pivot = CFrame.new(-165, LAND, 4) * CFrame.Angles(0, math.pi, 0),
		shell = { "M_Bld_Slipway" },
		collide = false, -- the hull is one mesh (ramp prism + walls + winch house): boxes below instead
		colliders = slipwayWalls({
			{ -1.5, 4.0, 0, 1.5, 7.0, 3.1 }, -- winch house (behind the head, on the quay)
		}),
		-- H2 toe: the greybox slab ends 22 m down the slope; the ramp runs on to y -30 (3.2 m under the sea)
		ramps = {
			{ -3.333, 3.333, -21.5, -21.5 * SLIP_K, -30.0, -30.0 * SLIP_K },
			-- the kerbs (0.33 m x 0.2 m) on the head apron and down the slope to the toe
			{ -3.663, -3.333, 3.0, 0.2, 0.0, 0.2 },
			{ 3.333, 3.663, 3.0, 0.2, 0.0, 0.2 },
			{ -3.663, -3.333, 0.0, 0.2, -30.0, 0.2 - 30.0 * SLIP_K },
			{ 3.333, 3.663, 0.0, 0.2, -30.0, 0.2 - 30.0 * SLIP_K },
		},
	},
}

return Swaps
