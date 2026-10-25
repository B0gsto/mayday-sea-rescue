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
	-- H1 slipway (art/source/buildings/M_Bld_Slipway/build.py: pivot at the ramp head on the quay edge, yawed
	-- 180 degrees so the ramp runs down to +Z). Map.Slipways.StationSlipway stays as the hidden ramp surface:
	-- its top face is the asset's 22 m x 3.33 m slope (1:6.6), and VehicleService, OperationService,
	-- NpcService and DogService read its CFrame (launch stand, Aggie and the crew at the head).
	Slipway = {
		greybox = { "Slipways", "StationSlipway" },
		hide = true,
		pivot = CFrame.new(-165, LAND, 4) * CFrame.Angles(0, math.pi, 0),
		shell = { "M_Bld_Slipway" },
		rig = "SharedSetsRig", -- ramp, weedy toe, walls and rock armour: tinted, not plain white
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
	-- H5 hospital (art/source/buildings/M_Bld_Hospital/build.py: 30 x 15 m block on its rear terrace, quay wall
	-- and pontoon; origin at the base under the pontoon, front (entrance porch) local -Z). The greybox
	-- Map.PortHaven.Hospital is 60 x 40 studs at x 100..160, z -140..-100; the asset is 90 x 45 studs, so its
	-- pivot sits at the greybox base centre, yawed 180 degrees: the entrance faces the harbour and the built rear
	-- pontoon runs north behind the building. DropOff_Hospital is the Harbour kit pontoon pad at x 130 (unchanged).
	Hospital = {
		greybox = { "PortHaven", "Hospital" },
		pivot = CFrame.new(130, LAND, -120) * CFrame.Angles(0, math.pi, 0),
		shell = { "M_Bld_Hospital" },
		-- the town terrain meshes about 2 studs above LandTopY here: sit the plinth on it
		ground = 24,
		rig = "SharedSetsRig", -- the shared texture sets AssetLoader cannot see from the hospital's folder
	},
	-- H4 harbourmaster's office (10 x 8 m) replacing the greybox desk stand-in: pivot at the desk's quay base,
	-- yawed 180 degrees so the door and the storm queue board face the water.
	Harbourmaster = {
		greybox = { "PortHaven", "HarbourmasterDesk" },
		pivot = CFrame.new(-9, LAND, -8) * CFrame.Angles(0, math.pi, 0),
		shell = { "M_Bld_Harbourmaster" },
		rig = "SharedSetsRig", -- shared Station Granite / Chandlery Slate / BldTrim sets
	},
}

return Swaps
