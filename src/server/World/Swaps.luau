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
--   rig       optional module in this folder: rig.apply(shell1, interior1, interior2, interior3) (lights, glass)

export type Swap = {
	greybox: { string },
	pivot: CFrame,
	shell: { string },
	interior: { string }?,
	prompts: { [string]: { marker: string, asset: string, attachment: string } }?,
	door: { asset: string, parts: { string }, hinge: string, trigger: string, angle: number }?,
	rig: string?,
	lod: string?,
	collide: boolean?, -- false: the uploads' _COL hulls stay off (single-mesh hulls fill door gaps)
	colliders: { { number } }?, -- invisible boxes {x0, y0, z0, x1, y1, z1} in the asset frame, metres
	ramps: { { number } }?, -- {x0, x1, yLow, zLow, yHigh, zHigh}: a stair ramp across x, metres
}

local LAND = 4 -- GameConfig.LandTopY (quay and town ground)

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
	-- H1 lifeboat station: still in its fix round. To swap it in, add one entry here, e.g.
	-- Station = { greybox = { "PortHaven", "Station" }, pivot = <from art/source/buildings/M_Bld_Station>,
	--             shell = { "M_Bld_Station", "M_Bld_Slipway" } },
	-- and tag nothing else: Build.luau keeps the greybox as the fallback.
}

return Swaps
