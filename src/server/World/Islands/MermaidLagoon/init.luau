--!strict
-- Mermaid Lagoon (docs/21 §2.2): white-sand isles round a sheltered turquoise lagoon. Islands/init.luau calls
-- place(base, island) with the WorldConfig.Islands row once the baked terrain is in. Builds, under
-- base.MermaidLagoon (Nonatomic; one Atomic model per prop so streaming stays local):
--   * DayMark (Persistent): the red-and-white day-mark on the lookout dune at island.landmark, a bench and a brass
--     telescope beside it (the viewpoint);
--   * StampPost at island.stamp (post, letterbox, brass plate; B2 hooks discovery to it);
--   * Jetty: stairs down from island.landing, a piled deck and a T-head that ends just shy of island.dock (the
--     boats' stop and rescue drop-off), bollards, lifebuoy, lamp, pennant;
--   * Cafe on island.pads[1]: striped-roof shack, deck terrace with tables and parasols, loungers on the sand;
--   * MermaidStatue: a colossal reclining marble mermaid half sunk in the lagoon (head, shoulders and shell rise
--     out of it; the water hides anything deeper than ~2 studs) among broken columns;
--   * palms and agapanthus (code-built), marram, boulders and rock pools (existing kits), basking turtles
--     (WildlifeRig), lateral buoys marking the NE entrance channel (red to port going in).
-- Every prop is raycast onto the terrain; one whose ground or asset is missing is skipped.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AssetLoader =
	require(script.Parent.Parent.Parent:WaitForChild("Assets"):WaitForChild("AssetLoader")) :: any
local Kit = require(script:WaitForChild("Kit"))
local StreetFurniture = require(script.Parent.Parent:WaitForChild("StreetFurniture")) :: any
local WildlifeRig =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WildlifeRig")) :: any

local M = {}

local WHITE = Color3.fromRGB(244, 240, 230)
local RED = Color3.fromRGB(200, 58, 52)
local TEAL = Color3.fromRGB(46, 160, 168)
local CORAL = Color3.fromRGB(236, 120, 96)
local YELLOW = Color3.fromRGB(240, 196, 72)
local PIER = Color3.fromRGB(150, 116, 82)
local PILE = Color3.fromRGB(86, 68, 52)
local IRON = Color3.fromRGB(36, 42, 40)
local BRASS = Color3.fromRGB(200, 160, 72)
local SHACK = Color3.fromRGB(164, 214, 214)

-- x, z, height, stout (Canary date palm) — on the five isles' sand, clear of the café pad and the jetty
local PALMS: { { any } } = {
	{ 368, 5046, 26 },
	{ 356, 5062, 20 },
	{ 455, 5042, 24 },
	{ 466, 5052, 19 },
	{ 472, 4978, 28 },
	{ 484, 4990, 22 },
	{ 214, 4992, 25 },
	{ 226, 5006, 20 },
	{ 186, 5040, 22 },
	{ 132, 4988, 19 },
	{ 522, 5002, 22 },
	{ 432, 4938, 23 },
	{ 330, 4926, 15, true },
	{ 262, 5050, 17, true },
	{ 900, 5480, 26 },
	{ 926, 5602, 29 },
	{ 956, 5528, 23 },
	{ 906, 5682, 22 },
	{ -332, 5560, 26 },
	{ -320, 5574, 20 },
	{ -312, 5684, 23 },
	{ -362, 5742, 20 },
	{ 640, 6162, 23 },
	{ 700, 6184, 28 },
	{ 742, 6160, 20 },
	{ -84, 6200, 25 },
	{ -22, 6214, 22 },
	{ -124, 6196, 19 },
}

local AGAPANTHUS = {
	{ 364, 5034 },
	{ 380, 5040 },
	{ 440, 5038 },
	{ 456, 5022 },
	{ 458, 4994 },
	{ 352, 4972 },
	{ 330, 5004 },
	{ 470, 4956 },
	{ 488, 4962 },
	{ 302, 4988 },
	{ 912, 5540 },
	{ -320, 5620 },
	{ 680, 6170 },
}

local TURTLES = { -- x, z, yaw (head toward the water)
	{ 846, 5500, math.pi / 2 },
	{ 842, 5566, math.pi / 2 + 0.4 },
	{ 852, 5640, math.pi / 2 - 0.3 },
	{ 660, 6104, 0 },
	{ -262, 5552, -math.pi / 2 },
	{ -40, 6140, 0.2 },
}

local ROCK_POOLS = { { 300, 4852, 0.4 }, { 248, 4862, 2.1 }, { 346, 4856, 1.2 } }

local BOULDERS = { -- x, z, asset index, scale, yaw
	{ 470, 4924, 1, 2.2, 0.3 },
	{ 482, 4934, 3, 1.8, 1.4 },
	{ 518, 4944, 2, 2.0, 2.2 },
	{ 530, 4952, 5, 1.6, 0.9 },
	{ 270, 4848, 4, 1.8, 0.2 },
	{ 322, 4846, 6, 2.0, 1.7 },
	{ 368, 4866, 1, 1.6, 2.9 },
	{ 226, 4870, 3, 1.5, 0.6 },
	{ 290, 5090, 2, 1.4, 1.1 },
}

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { Workspace.Terrain }
rayParams.IgnoreWater = true

local function groundY(x: number, z: number): number?
	local hit = Workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), rayParams)
	return if hit then hit.Position.Y else nil
end

local function model(name: string, parent: Instance, mode: Enum.ModelStreamingMode?): Model
	local m = Instance.new("Model")
	m.Name = name
	m.ModelStreamingMode = mode or Enum.ModelStreamingMode.Atomic
	m.Parent = parent
	return m
end

local function asset(
	name: string,
	cf: CFrame,
	parent: Instance,
	collide: boolean,
	scale: number?
): Model?
	local m = AssetLoader.cloneStatic(name, "LOD0", collide)
	if not m then
		return nil
	end
	AssetLoader.setWet(m, true)
	m:PivotTo(cf)
	if scale then
		m:ScaleTo(scale)
	end
	local holder = model(name, parent)
	m.Parent = holder
	holder.WorldPivot = cf
	return holder
end

local function dayMark(root: Instance, at: Vector3)
	local m = model("DayMark", root, Enum.ModelStreamingMode.Persistent)
	local foot = CFrame.new(at)
	Kit.part(
		m,
		"Plinth",
		Vector3.new(3, 9, 9),
		foot * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(150, 146, 136),
		Enum.Material.Granite,
		Enum.PartType.Cylinder
	)
	local bands, h = 10, 5
	for i = 0, bands - 1 do
		local d = 8 - i * 0.45
		Kit.part(
			m,
			"Band",
			Vector3.new(h, d, d),
			foot * CFrame.new(0, 2 + h * (i + 0.5), 0) * CFrame.Angles(0, 0, math.pi / 2),
			if i % 2 == 0 then RED else WHITE,
			Enum.Material.Plaster,
			Enum.PartType.Cylinder
		)
	end
	local top = 2 + h * bands
	Kit.part(
		m,
		"Cap",
		Vector3.new(0.6, 4.2, 4.2),
		foot * CFrame.new(0, top + 0.3, 0) * CFrame.Angles(0, 0, math.pi / 2),
		IRON,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	Kit.cyl(
		m,
		"Mast",
		at + Vector3.new(0, top, 0),
		at + Vector3.new(0, top + 7, 0),
		0.5,
		IRON,
		Enum.Material.Metal
	)
	Kit.part(
		m,
		"Topmark",
		Vector3.one * 3.2,
		foot * CFrame.new(0, top + 7.5, 0),
		RED,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	m.WorldPivot = foot
	-- the viewpoint: a bench facing the lagoon (south) and a brass telescope
	local bench = StreetFurniture.build("M_Road_Bench")
	local by = groundY(at.X + 7, at.Z + 9)
	if bench and by then
		local holder = model("LookoutBench", root)
		bench:PivotTo(CFrame.new(at.X + 7, by, at.Z + 9) * CFrame.Angles(0, math.pi + 0.3, 0))
		bench.Parent = holder
	end
	local ty = groundY(at.X - 6, at.Z + 8)
	if ty then
		local t = model("Telescope", root)
		local p = Vector3.new(at.X - 6, ty, at.Z + 8)
		Kit.cyl(t, "Post", p, p + Vector3.new(0, 3.6, 0), 0.35, IRON, Enum.Material.Metal)
		Kit.cyl(
			t,
			"Tube",
			p + Vector3.new(0, 4, -1.2),
			p + Vector3.new(0, 4.5, 1.4),
			0.6,
			BRASS,
			Enum.Material.Metal
		)
		Kit.cyl(
			t,
			"Eyepiece",
			p + Vector3.new(0, 3.9, -1.2),
			p + Vector3.new(0, 3.85, -1.7),
			0.35,
			BRASS,
			Enum.Material.Metal
		)
	end
end

local function stampPost(root: Instance, island: any)
	local at = island.stamp :: Vector3
	local y = groundY(at.X, at.Z) or at.Y
	local m = model("StampPost", root)
	m:SetAttribute("Island", island.id)
	local foot = CFrame.new(at.X, y, at.Z) * CFrame.Angles(0, math.pi, 0) -- plate faces south, the café side
	Kit.part(
		m,
		"Post",
		Vector3.new(0.9, 5, 0.9),
		foot * CFrame.new(0, 2.3, 0),
		Color3.fromRGB(120, 90, 62),
		Enum.Material.Wood
	)
	Kit.part(
		m,
		"Box",
		Vector3.new(2.2, 1.8, 1.6),
		foot * CFrame.new(0, 5.4, 0),
		TEAL,
		Enum.Material.Wood
	)
	Kit.part(
		m,
		"Lid",
		Vector3.new(2.5, 0.3, 1.9),
		foot * CFrame.new(0, 6.45, 0.1) * CFrame.Angles(-0.12, 0, 0),
		Color3.fromRGB(120, 90, 62),
		Enum.Material.Wood
	)
	local plate = Kit.part(
		m,
		"Plate",
		Vector3.new(1.5, 1.1, 0.12),
		foot * CFrame.new(0, 5.35, -0.85),
		BRASS,
		Enum.Material.Metal
	)
	plate.Reflectance = 0.15
	Kit.part(
		m,
		"Rivet",
		Vector3.new(0.1, 0.5, 0.5),
		foot * CFrame.new(0, 5.35, -0.93) * CFrame.Angles(0, math.pi / 2, 0),
		Color3.fromRGB(150, 110, 50),
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	m.PrimaryPart = plate
	m.WorldPivot = foot
end

local function jetty(root: Instance, island: any)
	local m = model("Jetty", root)
	local landing, dock = island.landing :: Vector3, island.dock :: Vector3
	local x = landing.X
	local deckY = 3.5
	local topY = groundY(x, landing.Z) or landing.Y
	-- stairs: from the dune edge down to the deck
	local steps = math.max(1, math.floor((topY - deckY) / 0.75 + 0.5))
	local rise, run = (topY - deckY) / steps, 1.6
	local z0 = landing.Z - 4
	Kit.part(
		m,
		"Landing",
		Vector3.new(8, 0.5, 6),
		CFrame.new(x, topY - 0.2, landing.Z),
		PIER,
		Enum.Material.Wood
	)
	for i = 1, steps do
		Kit.part(
			m,
			"Step",
			Vector3.new(6, 0.45, run + 0.1),
			CFrame.new(x, topY - rise * i - 0.2, z0 - run * (i - 0.5)),
			PIER,
			Enum.Material.Wood
		)
	end
	local stairEnd = z0 - run * steps
	for _, sx in { -3.3, 3.3 } do
		Kit.cyl(
			m,
			"Stringer",
			Vector3.new(x + sx, topY - 0.6, z0),
			Vector3.new(x + sx, deckY - 0.6, stairEnd),
			0.5,
			PILE,
			Enum.Material.Wood
		)
		Kit.cyl(
			m,
			"Handrail",
			Vector3.new(x + sx, topY + 2.8, z0 + 1),
			Vector3.new(x + sx, deckY + 2.8, stairEnd),
			0.3,
			WHITE,
			Enum.Material.Wood
		)
		for _, z in { z0 + 1, (z0 + stairEnd) / 2, stairEnd } do
			local yy = deckY + (topY - deckY) * (z - stairEnd) / (z0 - stairEnd)
			Kit.cyl(
				m,
				"RailPost",
				Vector3.new(x + sx, yy - 0.5, z),
				Vector3.new(x + sx, yy + 2.9, z),
				0.3,
				WHITE,
				Enum.Material.Wood
			)
		end
	end
	-- the deck: plank strips and pile bents every 12 studs
	local headZ1 = dock.Z + 6
	local headZ2 = headZ1 + 10
	local deckLen = stairEnd - headZ2
	local planks = { -3, -1, 1, 3 }
	for i, px in planks do
		local tone = if i % 2 == 0 then PIER else Color3.fromRGB(162, 126, 90)
		Kit.part(
			m,
			"Plank",
			Vector3.new(1.9, 0.4, deckLen),
			CFrame.new(x + px, deckY - 0.2, (stairEnd + headZ2) / 2),
			tone,
			Enum.Material.Wood
		)
	end
	local z = stairEnd - 2
	while z > headZ2 do
		Kit.part(
			m,
			"Bearer",
			Vector3.new(9, 0.6, 0.8),
			CFrame.new(x, deckY - 0.7, z),
			PILE,
			Enum.Material.Wood
		)
		for _, sx in { -4, 4 } do
			local gy = groundY(x + sx, z) or -8
			Kit.cyl(
				m,
				"Pile",
				Vector3.new(x + sx, gy - 1, z),
				Vector3.new(x + sx, deckY - 0.3, z),
				1.0,
				PILE,
				Enum.Material.Wood
			)
		end
		z -= 12
	end
	-- the T-head: wider, piles standing proud as mooring posts, bollards, lifebuoy, lamp and pennant
	for i = 0, 4 do
		Kit.part(
			m,
			"HeadPlank",
			Vector3.new(24, 0.4, 1.9),
			CFrame.new(x, deckY - 0.2, headZ1 + 1 + i * 2),
			if i % 2 == 0 then PIER else Color3.fromRGB(162, 126, 90),
			Enum.Material.Wood
		)
	end
	for _, sx in { -11.5, -4, 4, 11.5 } do
		for _, hz in { headZ1 + 0.6, headZ2 - 0.6 } do
			local gy = groundY(x + sx, hz) or -9
			Kit.cyl(
				m,
				"HeadPile",
				Vector3.new(x + sx, gy - 1, hz),
				Vector3.new(x + sx, deckY + 1.6, hz),
				1.1,
				PILE,
				Enum.Material.Wood
			)
		end
	end
	for _, sx in { -8, 8 } do
		Kit.part(
			m,
			"Bollard",
			Vector3.new(1.4, 1.1, 1.1),
			CFrame.new(x + sx, deckY + 0.7, headZ1 + 1.2) * CFrame.Angles(0, 0, math.pi / 2),
			IRON,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
		Kit.part(
			m,
			"BollardCap",
			Vector3.new(0.3, 1.5, 1.5),
			CFrame.new(x + sx, deckY + 1.35, headZ1 + 1.2) * CFrame.Angles(0, 0, math.pi / 2),
			IRON,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
	end
	local lampAt = Vector3.new(x + 10, deckY, headZ2 - 1.5)
	Kit.cyl(m, "LampPost", lampAt, lampAt + Vector3.new(0, 9, 0), 0.4, IRON, Enum.Material.Metal)
	local lamp = Kit.part(
		m,
		"Lamp",
		Vector3.new(1.1, 1.4, 1.1),
		CFrame.new(lampAt + Vector3.new(0, 9.6, 0)),
		Color3.fromRGB(255, 226, 160),
		Enum.Material.Neon
	)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 214, 150)
	light.Range = 22
	light.Brightness = 1.4
	light.Parent = lamp
	local flagAt = Vector3.new(x - 10, deckY, headZ2 - 1.5)
	Kit.cyl(m, "FlagPole", flagAt, flagAt + Vector3.new(0, 12, 0), 0.3, WHITE, Enum.Material.Wood)
	Kit.tri(
		m,
		flagAt + Vector3.new(0, 11.8, 0),
		flagAt + Vector3.new(0, 9.6, 0),
		flagAt + Vector3.new(4.5, 10.9, 0.4),
		TEAL,
		Enum.Material.Fabric,
		0.08
	)
	m.WorldPivot = CFrame.new(x, deckY, dock.Z)
	local buoy = asset(
		"M_Hbr_LifebuoyStation",
		CFrame.new(x - 6, deckY, headZ2 - 0.8) * CFrame.Angles(0, math.pi, 0),
		root,
		false
	)
	if not buoy then
		warn("[MermaidLagoon] lifebuoy station did not load")
	end
	asset("M_Hbr_Rope_Coil", CFrame.new(x + 5, deckY, headZ1 + 3), root, false)
end

local function cafe(root: Instance, island: any)
	local pad = island.pads[1]
	if not pad then
		return
	end
	local cx, y = (pad.min.X + pad.max.X) / 2, pad.y
	local m = model("Cafe", root)
	-- floor: one slab under the shack and its terrace
	local floorTop = y + 0.6
	Kit.part(
		m,
		"Floor",
		Vector3.new(46, 1.2, 58),
		CFrame.new(cx, y, 4993),
		Color3.fromRGB(188, 146, 100),
		Enum.Material.Wood
	)
	local sz1, sz2 = 4965, 4979 -- shack back and front
	local sx1, sx2 = cx - 11, cx + 11
	local H = 9
	local function wall(name: string, size: Vector3, pos: Vector3, colour: Color3?)
		Kit.part(m, name, size, CFrame.new(pos), colour or SHACK, Enum.Material.Wood)
	end
	wall("BackWall", Vector3.new(22, H, 0.6), Vector3.new(cx, floorTop + H / 2, sz1 + 0.3))
	wall(
		"SideWall",
		Vector3.new(0.6, H, 14),
		Vector3.new(sx1 + 0.3, floorTop + H / 2, (sz1 + sz2) / 2)
	)
	wall(
		"SideWall",
		Vector3.new(0.6, H, 14),
		Vector3.new(sx2 - 0.3, floorTop + H / 2, (sz1 + sz2) / 2)
	)
	-- counter and lintel ends 0.1, pillars 0.05 inside the side walls' faces (no shared planes)
	wall("Counter", Vector3.new(21.8, 3.6, 0.6), Vector3.new(cx, floorTop + 1.8, sz2 - 0.3))
	wall(
		"Lintel",
		Vector3.new(21.8, 1.6, 0.6),
		Vector3.new(cx, floorTop + H - 0.8, sz2 - 0.3),
		WHITE
	)
	for _, px in { sx1 + 1.05, sx2 - 1.05 } do
		wall("Pillar", Vector3.new(2, H, 0.8), Vector3.new(px, floorTop + H / 2, sz2 - 0.3), WHITE)
	end
	for _, px in { sx1, sx2 } do
		for _, pz in { sz1, sz2 } do
			wall("Corner", Vector3.new(0.8, H, 0.8), Vector3.new(px, floorTop + H / 2, pz), WHITE)
		end
	end
	Kit.part(
		m,
		"CounterTop",
		Vector3.new(19, 0.3, 2.2),
		CFrame.new(cx, floorTop + 3.75, sz2 + 0.2),
		Color3.fromRGB(222, 180, 120),
		Enum.Material.Wood
	)
	-- inside: fridge, coffee machine, shelf of bottles
	Kit.part(
		m,
		"Fridge",
		Vector3.new(3, 6, 2.4),
		CFrame.new(sx1 + 3, floorTop + 3, sz1 + 1.8),
		WHITE,
		Enum.Material.SmoothPlastic
	)
	Kit.part(
		m,
		"Coffee",
		Vector3.new(2.4, 2, 1.6),
		CFrame.new(cx + 4, floorTop + 4.9, sz2 - 1.2),
		Color3.fromRGB(170, 176, 180),
		Enum.Material.Metal
	)
	Kit.part(
		m,
		"Shelf",
		Vector3.new(10, 0.3, 1.2),
		CFrame.new(cx + 2, floorTop + 6, sz1 + 1.2),
		Color3.fromRGB(222, 180, 120),
		Enum.Material.Wood
	)
	for i, c in { CORAL, YELLOW, TEAL, Color3.fromRGB(120, 180, 90), CORAL, YELLOW } do
		Kit.part(
			m,
			"Bottle",
			Vector3.new(1.3, 0.5, 0.5),
			CFrame.new(cx - 2 + i * 1.3, floorTop + 6.8, sz1 + 1.2)
				* CFrame.Angles(0, 0, math.pi / 2),
			c,
			Enum.Material.Glass,
			Enum.PartType.Cylinder
		)
	end
	-- the striped roof (ridge along x) and gable ends
	local eave, ridge = floorTop + H, floorTop + H + 3.4
	local zc = (sz1 + sz2) / 2
	local run = (sz2 - sz1) / 2 + 1.6
	local slope = math.sqrt(run * run + 3.4 * 3.4)
	local pitch = math.atan2(3.4, run)
	local strips = 8
	local w = 25 / strips
	for i = 0, strips - 1 do
		local px = cx - 12.5 + w * (i + 0.5)
		local colour = if i % 2 == 0 then RED else WHITE
		for _, side in { -1, 1 } do
			Kit.part(
				m,
				"Roof",
				Vector3.new(w, 0.35, slope),
				CFrame.new(px, (eave + ridge) / 2 - 0.1, zc + side * run / 2)
					* CFrame.Angles(side * pitch, 0, 0),
				colour,
				Enum.Material.Fabric
			)
		end
	end
	for _, px in { sx1 + 0.3, sx2 - 0.3 } do
		Kit.tri(
			m,
			Vector3.new(px, eave, sz1),
			Vector3.new(px, eave, sz2),
			Vector3.new(px, ridge, zc),
			SHACK,
			Enum.Material.Wood,
			0.6
		)
	end
	-- awning over the serving hatch, with a scalloped valance
	for i = 0, 5 do
		local px = cx - 9 + 3 * (i + 0.5)
		local colour = if i % 2 == 0 then RED else WHITE
		Kit.part(
			m,
			"Awning",
			Vector3.new(3, 0.2, 5.4),
			CFrame.new(px, floorTop + H - 1.4, sz2 + 2.5) * CFrame.Angles(0.33, 0, 0),
			colour,
			Enum.Material.Fabric
		)
		Kit.tri(
			m,
			Vector3.new(px - 1.5, floorTop + H - 2.3, sz2 + 5.1),
			Vector3.new(px + 1.5, floorTop + H - 2.3, sz2 + 5.1),
			Vector3.new(px, floorTop + H - 3.1, sz2 + 5.1),
			colour,
			Enum.Material.Fabric,
			0.1
		)
	end
	-- the giant ice cream on the ridge: the café sign, readable from the sea
	local ice = Vector3.new(cx, ridge + 0.2, zc)
	for _, r in { 0, math.pi / 2 } do
		local d = CFrame.Angles(0, r, 0).RightVector * 1.6
		Kit.tri(
			m,
			ice,
			ice + Vector3.new(0, 4.5, 0) + d,
			ice + Vector3.new(0, 4.5, 0) - d,
			Color3.fromRGB(214, 160, 92),
			Enum.Material.Wood,
			0.2
		)
	end
	Kit.part(
		m,
		"Scoop",
		Vector3.one * 3.6,
		CFrame.new(ice + Vector3.new(0, 5.6, 0)),
		Color3.fromRGB(246, 168, 186),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	Kit.part(
		m,
		"Scoop",
		Vector3.one * 2.8,
		CFrame.new(ice + Vector3.new(0.2, 7.6, 0)),
		Color3.fromRGB(176, 230, 200),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	-- terrace: tables under parasols, string lights to two posts at the front corners
	local colours = { { TEAL, WHITE }, { CORAL, WHITE }, { YELLOW, WHITE } }
	for i, tx in { cx - 13, cx, cx + 13 } do
		local tz = if i == 2 then 5010 else 5000
		Kit.table(m, CFrame.new(tx, floorTop, tz), WHITE)
		Kit.parasol(m, Vector3.new(tx, floorTop + 2.7, tz), colours[i][1], colours[i][2])
	end
	for _, s in { -1, 1 } do
		local post = Vector3.new(cx + s * 21, floorTop, 5019)
		Kit.cyl(m, "LightPost", post, post + Vector3.new(0, 9, 0), 0.35, WHITE, Enum.Material.Wood)
		local from, to =
			Vector3.new(cx + s * 11, floorTop + H - 0.5, sz2 + 0.4), post + Vector3.new(0, 8.8, 0)
		for k = 1, 6 do
			local t = k / 7
			local sag = math.sin(t * math.pi) * 1.4
			local bulb = Kit.part(
				m,
				"Bulb",
				Vector3.one * 0.45,
				CFrame.new(from:Lerp(to, t) - Vector3.new(0, sag, 0)),
				Color3.fromRGB(255, 220, 150),
				Enum.Material.Neon,
				Enum.PartType.Ball
			)
			bulb.CanCollide = false
			if k == 3 then
				local l = Instance.new("PointLight")
				l.Color = Color3.fromRGB(255, 208, 140)
				l.Range = 18
				l.Brightness = 0.9
				l.Parent = bulb
			end
		end
	end
	m.WorldPivot = CFrame.new(cx, y, 4993)
	for i, spec in
		{
			{ name = "ABoard", x = cx + 7, z = 5021, yaw = 0.3 },
			{ name = "Planter", x = cx - 21, z = 5005, yaw = 0 },
			{ name = "Planter", x = cx + 21, z = 5005, yaw = 0 },
		}
	do
		local prop = StreetFurniture.build(spec.name)
		if prop then
			local holder = model(`{spec.name}{i}`, root)
			prop:PivotTo(
				CFrame.new(spec.x, floorTop, spec.z) * CFrame.Angles(0, math.pi + spec.yaw, 0)
			)
			prop.Parent = holder
		end
	end
	-- the beach in front: loungers in pairs under parasols, a towel or two
	local beach = model("CafeBeach", root)
	local fabrics = { TEAL, CORAL, YELLOW, TEAL, CORAL }
	for i, lx in { cx - 30, cx - 26, cx + 22, cx + 26, cx + 30 } do
		local lz = 5050 + (i % 2) * 3
		local gy = groundY(lx, lz)
		if gy then
			Kit.lounger(
				beach,
				CFrame.new(lx, gy, lz) * CFrame.Angles(0, math.pi + (i - 3) * 0.08, 0),
				fabrics[i]
			)
		end
	end
	for i, px in { cx - 28, cx + 26 } do
		local gy = groundY(px, 5058)
		if gy then
			Kit.parasol(
				beach,
				Vector3.new(px, gy, 5058),
				if i == 1 then CORAL else TEAL,
				WHITE,
				0.12
			)
		end
	end
	for i, tx in { cx - 6, cx + 4 } do
		local gy = groundY(tx, 5062)
		if gy then
			Kit.part(
				beach,
				"Towel",
				Vector3.new(2.6, 0.08, 5),
				CFrame.new(tx, gy + 0.05, 5062) * CFrame.Angles(0, 0.2 * i, 0),
				if i == 1 then YELLOW else CORAL,
				Enum.Material.Fabric
			).CanCollide =
				false
		end
	end
end

local function statue(root: Instance)
	local x, z = 300, 5265
	local gy = groundY(x, z)
	if not gy then
		return
	end
	local m = model("MermaidStatue", root)
	m:SetAttribute("ExploreSpot", "MermaidStatue")
	local scale = 4
	local y = math.min(gy - 0.4, 9 - 5.1 * scale) -- head, shoulders and shell out of the water, tail under it
	local cf = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(200), 0) -- she looks up the lagoon toward the café
	Kit.mermaid(m, cf, scale)
	-- the drowned colonnade round her: one column breaks the surface (the cue from a boat), the rest lie broken
	local stone = Color3.fromRGB(218, 222, 210)
	local function columnAt(dx: number, dz: number): Vector3?
		local cy = groundY(x + dx, z + dz)
		return if cy then Vector3.new(x + dx, cy - 0.4, z + dz) else nil
	end
	local c1 = columnAt(-30, -16)
	if c1 then
		Kit.cyl(m, "Column", c1, Vector3.new(c1.X, 4.5, c1.Z), 3.2, stone, Enum.Material.Marble)
		Kit.part(
			m,
			"Capital",
			Vector3.new(4.4, 1.2, 4.4),
			CFrame.new(c1.X, 4.9, c1.Z) * CFrame.Angles(0.1, 0.3, 0.06),
			stone,
			Enum.Material.Marble
		)
	end
	local c2 = columnAt(26, -22)
	if c2 then
		Kit.cyl(
			m,
			"FallenColumn",
			c2 + Vector3.new(-4, 0.9, 0),
			c2 + Vector3.new(4, 0.7, 3),
			1.6,
			stone,
			Enum.Material.Marble
		)
	end
	local c3 = columnAt(32, 18)
	if c3 then
		Kit.cyl(m, "Stump", c3, Vector3.new(c3.X, 2.5, c3.Z), 3, stone, Enum.Material.Marble)
	end
	local c4 = columnAt(-22, 26)
	if c4 then
		Kit.part(
			m,
			"Block",
			Vector3.new(2.6, 1.4, 2.6),
			CFrame.new(c4 + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0.2, 0.7, 0.15),
			stone,
			Enum.Material.Marble
		)
	end
	for i = 1, 4 do
		local a = i * 1.7
		local s = columnAt(math.cos(a) * 18, math.sin(a) * 18)
		if s then
			Kit.part(
				m,
				"Starfish",
				Vector3.new(1.1, 0.25, 1.1),
				CFrame.new(s + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, a, 0),
				Color3.fromRGB(236, 120, 70),
				Enum.Material.SmoothPlastic,
				Enum.PartType.Cylinder
			)
		end
	end
	m.WorldPivot = cf
end

local function buoys(root: Instance)
	-- NE entrance between the main isle and the east isle; heading in = (from -> to); IALA A: red to port
	local from, to = Vector3.new(760, 0, 5060), Vector3.new(640, 0, 5330)
	local dir = (to - from).Unit
	local port = Vector3.new(dir.Z, 0, -dir.X) -- left of the heading
	local sea = Workspace:GetAttribute("SeaLevel")
	local seaY = if type(sea) == "number" then sea else 0
	for i = 0, 2 do
		local c = from:Lerp(to, i / 2)
		for _, spec in
			{
				{ name = "M_Hbr_NavMark_Port", side = 1 },
				{ name = "M_Hbr_NavMark_Starboard", side = -1 },
			}
		do
			local p = c + port * 34 * spec.side
			asset(spec.name, CFrame.new(p.X, seaY, p.Z) * CFrame.Angles(0, i * 1.3, 0), root, true)
		end
	end
end

local function scatterAssets(root: Instance)
	local rng = Random.new(5600)
	for _, r in ROCK_POOLS do
		local gy = groundY(r[1], r[2])
		if gy then
			asset(
				"M_Rock_RockPool_Kit",
				CFrame.new(r[1], gy - 0.35, r[2]) * CFrame.Angles(0, r[3], 0),
				root,
				true
			)
		end
	end
	for _, b in BOULDERS do
		local gy = groundY(b[1], b[2])
		if gy then
			asset(
				`M_Rock_Boulder_0{b[3]}`,
				CFrame.new(b[1], gy - 0.6, b[2]) * CFrame.Angles(0, b[5], 0),
				root,
				true,
				b[4]
			)
		end
	end
	-- marram on the dunes of every isle (above the tide line, clear of the café and the day-mark)
	local isles: { { number } } = {
		{ 300, 4985, 240, 110, 20 },
		{ 930, 5560, 70, 200, 8 },
		{ -340, 5650, 70, 190, 8 },
		{ 680, 6170, 150, 60, 5 },
		{ -60, 6210, 140, 60, 5 },
	}
	local avoid =
		{ Vector3.new(405, 0, 4995), Vector3.new(300, 0, 4950), Vector3.new(500, 0, 4935) }
	for _, isle in isles do
		local placed, tries = 0, 0
		while placed < isle[5] and tries < isle[5] * 6 do
			tries += 1
			local px = isle[1] + rng:NextNumber(-1, 1) * isle[3]
			local pz = isle[2] + rng:NextNumber(-1, 1) * isle[4]
			local clear = true
			for _, a in avoid do
				if (Vector3.new(px, 0, pz) - a).Magnitude < 34 then
					clear = false
				end
			end
			local gy = if clear then groundY(px, pz) else nil
			if gy and gy > 2.5 then
				asset(
					`M_Veg_Grass_Marram_0{rng:NextInteger(1, 2)}`,
					CFrame.new(px, gy - 0.2, pz) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
					root,
					false,
					rng:NextNumber(0.9, 1.4)
				)
				placed += 1
			end
		end
	end
end

local function plants(root: Instance)
	local rng = Random.new(5601)
	for i, p in PALMS do
		local gy = groundY(p[1], p[2])
		if gy and gy > 0.5 then
			local m = model(`Palm{i}`, root)
			Kit.palm(
				m,
				Vector3.new(p[1], gy - 0.3, p[2]),
				p[3],
				rng:NextNumber(0, math.pi * 2),
				rng,
				p[4] == true
			)
			m.WorldPivot = CFrame.new(p[1], gy, p[2])
		end
	end
	for i, a in AGAPANTHUS do
		local gy = groundY(a[1], a[2])
		if gy and gy > 0.5 then
			local m = model(`Agapanthus{i}`, root)
			Kit.agapanthus(m, Vector3.new(a[1], gy, a[2]), rng)
			m.WorldPivot = CFrame.new(a[1], gy, a[2])
		end
	end
end

local function turtles(root: Instance)
	for i, t in TURTLES do
		local gy = groundY(t[1], t[2])
		local rig = WildlifeRig.build("Turtle", i == 4) -- one golden one, for the eagle-eyed
		if gy and rig then
			local holder = model(`Turtle{i}`, root)
			rig.Parent = holder
			WildlifeRig.scale(rig, 1.4)
			WildlifeRig.setCFrame(
				rig,
				CFrame.new(t[1], math.max(gy, -0.3), t[2]) * CFrame.Angles(0, t[3], 0)
			)
		elseif rig then
			rig:Destroy()
		end
	end
end

function M.place(base: Instance, island: any)
	local root = model("MermaidLagoon", base, Enum.ModelStreamingMode.Nonatomic)
	root:SetAttribute("Island", island.id)
	for _, name in
		{
			"M_Rock_RockPool_Kit",
			"M_Hbr_NavMark_Port",
			"M_Hbr_NavMark_Starboard",
			"M_Hbr_LifebuoyStation",
			"M_Hbr_Rope_Coil",
			"M_Veg_Grass_Marram_01",
			"M_Veg_Grass_Marram_02",
		}
	do
		task.spawn(AssetLoader.getTemplate, name, "LOD0")
	end
	for i = 1, 6 do
		task.spawn(AssetLoader.getTemplate, `M_Rock_Boulder_0{i}`, "LOD0")
	end
	local ok = true
	local function try(fn: any, ...: any)
		local sOk, err = pcall(fn, ...)
		if not sOk then
			ok = false
			warn(`[MermaidLagoon] {err}`)
		end
	end
	local l = island.landmark :: Vector3
	try(dayMark, root, Vector3.new(l.X, groundY(l.X, l.Z) or l.Y, l.Z))
	try(stampPost, root, island)
	try(jetty, root, island)
	try(cafe, root, island)
	try(statue, root)
	try(plants, root)
	try(turtles, root)
	try(buoys, root)
	try(scatterAssets, root)
	local parts = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	root:SetAttribute("Parts", parts)
	print(
		`[MermaidLagoon] built{if ok then "" else " (with errors)"}: {parts} parts, {#root:GetDescendants()} instances`
	)
end

return M
