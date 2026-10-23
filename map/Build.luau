-- Build-time map, run by tools/build-map.luau under Lune (NOT shipped as a script).
-- Called as build(game, ctx); ctx.require loads shared modules (GameConfig, WorldConfig) through the require shim.
-- Globals: Instance, Vector3, CFrame, Color3, Enum, game, workspace.
-- Lune limits: no physics, no Terrain editing, no Model:PivotTo. New Parts default to Studs
-- surfaces and Anchored = false, so the part() helper sets both.
--
-- Terrain: Lune cannot write voxels, but it can move a whole Terrain instance. map/terrain/Terrain.rbxm (written in
-- Studio by tools/world/studio_terrain.py from the bake in map/generated, see tools/world/README.md) is parented into
-- Workspace as-is (SmoothGrid + PhysicsGrid). Without it the old part-built OceanFloor and land are built instead.
--
-- Builds Workspace.Map (sea level Y = 0, no Terrain water: the ocean is a client mesh):
--   OceanFloor   (fallback only) sand base, top at Y = -40
--   PortHaven    quay, station, dock with launch bays Bay1..Bay4, hospital, houses (land and hill only as fallback),
--                the Chandlery (walk-in store, dressing)
--   DropOffs     DropOff_Hospital, DropOff_Dock (water-level pads, attribute DropOff)
--   Breakwater   two arms enclosing Calm Bay; the 60-stud gap is Harbour Mouth
--   Slipways     the station slipway (concrete ramp into the harbour)
--   HavenSands   lifeguard tower, parked NPC ambulance (handover), car park sign
--   Seabed       wrecks and finds from WorldConfig.POIs (Morwenna, the mail seaplane, the Admiralty anchor)
--   WorldPoints  invisible markers with attributes: launch, vehicle spawn, handover, discoveries (Discoverable)
--   HarbourLight lighthouse greybox on the east breakwater head
-- and Workspace.Zones (invisible, non-collide cylinders with attribute Zone = "<id>", from GameConfig).
-- Spawn is on the quay.

local SMOOTH = Enum.SurfaceType.Smooth
local M = Enum.Material

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local COLORS = {
	sand = rgb(214, 196, 150),
	seabed = rgb(150, 140, 110),
	grass = rgb(106, 140, 82),
	concrete = rgb(170, 170, 165),
	stone = rgb(120, 120, 118),
	wood = rgb(120, 90, 60),
	white = rgb(236, 236, 230),
	red = rgb(196, 48, 40),
	roof = rgb(70, 72, 80),
	bay = rgb(255, 200, 40),
	dropoff = rgb(60, 200, 110),
	glass = rgb(255, 240, 180),
	signBlue = rgb(0, 82, 160),
}
local HOUSE_COLORS = {
	rgb(226, 120, 96),
	rgb(240, 200, 110),
	rgb(110, 160, 200),
	rgb(150, 200, 160),
	rgb(230, 230, 220),
	rgb(200, 140, 180),
}

local function part(props: { [string]: any }): Part
	local className = props.ClassName or "Part"
	local p = Instance.new(className)
	p.Anchored = true
	p.TopSurface = SMOOTH
	p.BottomSurface = SMOOTH
	p.Material = M.SmoothPlastic
	for key, value in props do
		if key ~= "ClassName" and key ~= "Parent" and key ~= "Attributes" then
			p[key] = value
		end
	end
	if props.Attributes then
		for name, value in props.Attributes do
			p:SetAttribute(name, value)
		end
	end
	p.Parent = props.Parent
	return p
end

-- A box given its min and max corners (handy for greybox layout).
local function box(
	parent: Instance,
	name: string,
	min: Vector3,
	max: Vector3,
	color: Color3,
	material: any?
): Part
	return part({
		Name = name,
		Size = max - min,
		CFrame = CFrame.new((min + max) / 2),
		Color = color,
		Material = material or M.SmoothPlastic,
		Parent = parent,
	})
end

local function folder(parent: Instance, name: string, className: string?): Instance
	local f = Instance.new(className or "Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function buildOceanFloor(map: Instance, floorY: number)
	local model = folder(map, "OceanFloor", "Model")
	local tile = 2048
	for ix = -1, 0 do
		for iz = -1, 0 do
			part({
				Name = "OceanFloor",
				Size = Vector3.new(tile, 4, tile),
				CFrame = CFrame.new((ix + 0.5) * tile, floorY - 2, (iz + 0.5) * tile),
				Color = COLORS.seabed,
				Material = M.Sand,
				Parent = model,
			})
		end
	end
end

local function buildHouse(
	parent: Instance,
	name: string,
	base: Vector3,
	size: Vector3,
	color: Color3
)
	local model = folder(parent, name, "Model")
	box(
		model,
		"Body",
		base - Vector3.new(size.X / 2, 0, size.Z / 2),
		base + Vector3.new(size.X / 2, size.Y, size.Z / 2),
		color
	)
	-- gable roof: two wedges back to back along X
	local roofH = size.X * 0.35
	local top = base.Y + size.Y
	for side = -1, 1, 2 do
		part({
			ClassName = "WedgePart",
			Name = "Roof",
			Size = Vector3.new(size.Z + 1, roofH, size.X / 2 + 0.5),
			CFrame = CFrame.new(base.X + side * (size.X / 4 + 0.25), top + roofH / 2, base.Z)
				* CFrame.Angles(0, side * math.pi / 2, 0),
			Color = COLORS.roof,
			Parent = model,
		})
	end
	box(
		model,
		"Door",
		base + Vector3.new(-1.5, 0, size.Z / 2),
		base + Vector3.new(1.5, 7, size.Z / 2 + 0.2),
		COLORS.wood
	)
end

-- White text on the +Z (street) face of a hospital sign board.
local function hospitalSign(board: Part, text: string)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 1
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = gui
end

local function buildPortHaven(map: Instance, landTop: number, floorY: number, hasTerrain: boolean)
	local town = folder(map, "PortHaven", "Model")
	-- land the town sits on (north of the quay) and a hill behind it: Terrain when it is baked
	local land = if hasTerrain then Instance.new("Folder") else town
	box(
		land,
		"Land",
		Vector3.new(-600, floorY, -500),
		Vector3.new(600, landTop, -20),
		COLORS.grass,
		M.Grass
	)
	box(
		land,
		"Hill",
		Vector3.new(-600, landTop, -500),
		Vector3.new(600, landTop + 30, -360),
		COLORS.grass,
		M.Grass
	)
	part({
		ClassName = "WedgePart",
		Name = "HillSlope",
		Size = Vector3.new(1200, 30, 60),
		-- tall side toward -Z (the hill), sloping down toward the town
		CFrame = CFrame.new(0, landTop + 15, -330) * CFrame.Angles(0, math.pi, 0),
		Color = COLORS.grass,
		Material = M.Grass,
		Parent = land,
	})

	-- quay: concrete harbour front, z -20..4
	box(
		town,
		"Quay",
		Vector3.new(-180, floorY, -20),
		Vector3.new(180, landTop, 4),
		COLORS.concrete,
		M.Concrete
	)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "QuaySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.TopSurface = SMOOTH
	spawn.BottomSurface = SMOOTH
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(-60, landTop + 0.5, -8)
	spawn.Color = rgb(176, 170, 160) -- quay stone, not a white slab (r2 art review)
	spawn.Material = M.Granite
	spawn.Parent = town

	-- coast guard station by the dock
	local station = folder(town, "Station", "Model")
	box(
		station,
		"Building",
		Vector3.new(-140, landTop, -90),
		Vector3.new(-80, landTop + 24, -40),
		COLORS.white
	)
	box(
		station,
		"Roof",
		Vector3.new(-142, landTop + 24, -92),
		Vector3.new(-78, landTop + 26, -38),
		COLORS.red
	)
	box(
		station,
		"Doors",
		Vector3.new(-120, landTop, -40),
		Vector3.new(-100, landTop + 14, -39.6),
		COLORS.red
	)
	box(
		station,
		"Tower",
		Vector3.new(-90, landTop + 26, -60),
		Vector3.new(-80, landTop + 40, -50),
		COLORS.white
	)

	-- dock: a pier from the quay out into Calm Bay, deck at Y = 3
	local dock = folder(town, "Dock", "Model")
	box(dock, "Deck", Vector3.new(-118, 2, 4), Vector3.new(-102, 3, 104), COLORS.wood, M.WoodPlanks)
	for z = 14, 104, 18 do
		for _, x in { -117, -103 } do
			part({
				Name = "Piling",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(2 - floorY + 2, 1.6, 1.6),
				CFrame = CFrame.new(x, (2 + floorY) / 2, z) * CFrame.Angles(0, 0, math.pi / 2),
				Color = COLORS.wood,
				Material = M.Wood,
				Parent = dock,
			})
		end
	end
	-- launch bays on the east side of the dock, on the water, facing out to sea (+Z)
	for i = 1, 4 do
		local z = 4 + i * 22 - 8
		part({
			Name = `Bay{i}`,
			Size = Vector3.new(12, 0.4, 18),
			CFrame = CFrame.new(-95, 0.2, z) * CFrame.Angles(0, math.pi, 0),
			Color = COLORS.bay,
			-- spawn marker only (VehicleService reads its CFrame): never drawn over the boat/water
			Transparency = 1,
			CastShadow = false,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
			Parent = dock,
			Attributes = { LaunchBay = true, BayIndex = i, AllowedVehicles = "JetSki,RIB,Lifeboat" },
		})
		box(
			dock,
			`Bay{i}Bollard`,
			Vector3.new(-102.5, 3, z - 0.5),
			Vector3.new(-101.5, 4.5, z + 0.5),
			COLORS.bay
		)
	end

	-- hospital up from the quay, east side, with an ambulance bay on the quay
	local hospital = folder(town, "Hospital", "Model")
	box(
		hospital,
		"Building",
		Vector3.new(100, landTop, -140),
		Vector3.new(160, landTop + 20, -100),
		COLORS.white
	)
	-- no red cross anywhere (a protected emblem, docs/05): a white "H" on blue and the name board
	local hBoard = box(
		hospital,
		"SignH",
		Vector3.new(125, landTop + 8, -99.8),
		Vector3.new(135, landTop + 18, -99.4),
		COLORS.signBlue
	)
	hospitalSign(hBoard, "H")
	local nameBoard = box(
		hospital,
		"SignName",
		Vector3.new(112, landTop + 3.5, -99.8),
		Vector3.new(148, landTop + 6.5, -99.4),
		COLORS.signBlue
	)
	hospitalSign(nameBoard, "COTTAGE HOSPITAL")
	box(
		hospital,
		"Ambulance",
		Vector3.new(124, landTop, -14),
		Vector3.new(136, landTop + 6, -6),
		COLORS.white
	)

	local houses = folder(town, "Houses")
	local spots = {
		Vector3.new(-150, landTop, -192),
		Vector3.new(-60, landTop, -192),
		Vector3.new(90, landTop, -192),
		Vector3.new(130, landTop, -192),
		Vector3.new(260, landTop, -192),
		Vector3.new(310, landTop, -192),
	}
	for i, spot in spots do
		buildHouse(
			houses,
			`House{i}`,
			spot,
			Vector3.new(18 + (i % 3) * 4, 12 + (i % 2) * 6, 16),
			HOUSE_COLORS[i]
		)
	end

	return town
end

local function buildDropOffs(map: Instance)
	local drop = folder(map, "DropOffs")
	part({
		Name = "DropOff_Hospital",
		Size = Vector3.new(24, 0.4, 16),
		CFrame = CFrame.new(130, 0.2, 12),
		Color = COLORS.dropoff,
		Transparency = 0.5,
		CanCollide = false,
		Parent = drop,
		Attributes = { DropOff = "Hospital" },
	})
	part({
		Name = "DropOff_Dock",
		Size = Vector3.new(12, 0.4, 20),
		CFrame = CFrame.new(-125, 0.2, 92),
		Color = COLORS.dropoff,
		Transparency = 0.5,
		CanCollide = false,
		Parent = drop,
		Attributes = { DropOff = "Dock" },
	})
end

local function buildBreakwater(map: Instance, floorY: number, mouthHalf: number)
	local wall = folder(map, "Breakwater", "Model")
	local top, w, far = 6, 16, 360
	for side = -1, 1, 2 do
		local tag = if side < 0 then "West" else "East"
		local x = side * 320
		box(
			wall,
			`{tag}Arm`,
			Vector3.new(x - w / 2, floorY, -20),
			Vector3.new(x + w / 2, top, far + w / 2),
			COLORS.stone,
			M.Slate
		)
		local inner, outer = side * mouthHalf, x
		box(
			wall,
			`{tag}Head`,
			Vector3.new(math.min(inner, outer), floorY, far - w / 2),
			Vector3.new(math.max(inner, outer), top, far + w / 2),
			COLORS.stone,
			M.Slate
		)
	end
	return top, far
end

local function buildBeach(map: Instance, landTop: number)
	local beach = folder(map, "Beach", "Model")
	-- sand slopes from the land edge (z = -20, Y = landTop) down under the water toward +Z
	part({
		ClassName = "WedgePart",
		Name = "Sand",
		Size = Vector3.new(128, landTop + 8, 120),
		CFrame = CFrame.new(248, (landTop - 8) / 2, 40) * CFrame.Angles(0, math.pi, 0),
		Color = COLORS.sand,
		Material = M.Sand,
		Parent = beach,
	})
	box(
		beach,
		"LifeguardHut",
		Vector3.new(230, landTop, -60),
		Vector3.new(242, landTop + 9, -50),
		COLORS.red
	)
end

local function buildLighthouse(map: Instance, base: Vector3)
	local lh = folder(map, "HarbourLight", "Model")
	local segment = 10
	for i = 0, 3 do
		part({
			Name = `Tower{i + 1}`,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(segment, 10 - i, 10 - i),
			CFrame = CFrame.new(base + Vector3.new(0, segment * (i + 0.5), 0))
				* CFrame.Angles(0, 0, math.pi / 2),
			Color = if i % 2 == 0 then COLORS.white else COLORS.red,
			Parent = lh,
		})
	end
	local lampY = base.Y + segment * 4
	local lamp = box(
		lh,
		"Lantern",
		base + Vector3.new(-3, segment * 4, -3),
		base + Vector3.new(3, segment * 4 + 6, 3),
		COLORS.glass,
		M.Neon
	)
	lamp.Transparency = 0.2
	local light = Instance.new("PointLight")
	light.Range = 60
	light.Brightness = 2
	light.Color = COLORS.glass
	light.Parent = lamp
	box(
		lh,
		"Cap",
		base + Vector3.new(-4, segment * 4 + 6, -4),
		Vector3.new(base.X + 4, lampY + 8, base.Z + 4),
		COLORS.red
	)
end

local function buildZones(zonesFolder: Instance, zones: { any })
	for _, zone in zones do
		local height = 400
		part({
			Name = zone.id,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, zone.radius * 2, zone.radius * 2),
			CFrame = CFrame.new(zone.center) * CFrame.Angles(0, 0, math.pi / 2),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Parent = zonesFolder,
			Attributes = {
				Zone = zone.id,
				DisplayName = zone.displayName,
				Radius = zone.radius,
				Shelter = zone.shelter,
				Priority = zone.priority,
			},
		})
	end
end

local function loadTerrain(ws: Instance, ctx: any): boolean
	local path = "map/terrain/Terrain.rbxm"
	if not (ctx.exists and ctx.exists(path)) then
		return false
	end
	local terrain = ctx.readModel(path)[1]
	assert(terrain and terrain.ClassName == "Terrain", `{path} must hold one Terrain instance`)
	local old = ws:FindFirstChildOfClass("Terrain")
	if old then
		old:Destroy()
	end
	terrain.Name = "Terrain"
	terrain.Parent = ws
	return true
end

-- An invisible, non-colliding marker part carrying attributes (for code).
local function marker(
	parent: Instance,
	name: string,
	pos: Vector3,
	attributes: { [string]: any }
): Part
	return part({
		Name = name,
		Size = Vector3.new(4, 4, 4),
		CFrame = CFrame.new(pos),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = parent,
		Attributes = attributes,
	})
end

-- A part placed in a local frame (origin, yaw) given its centre offset, size and extra rotation.
local function piece(
	parent: Instance,
	frame: CFrame,
	name: string,
	offset: Vector3,
	size: Vector3,
	rot: CFrame?,
	color: Color3,
	material: any,
	shape: any?
): Part
	return part({
		Name = name,
		Shape = shape or Enum.PartType.Block,
		Size = size,
		CFrame = frame * CFrame.new(offset) * (rot or CFrame.new()),
		Color = color,
		Material = material,
		Parent = parent,
	})
end

local OAK, RUST, HULL = rgb(66, 56, 44), rgb(96, 62, 44), rgb(128, 134, 126)

-- Morwenna (1902 trading schooner, 28 x 7 m): keel, broken oak ribs, stem and stern posts, a few strakes,
-- the windlass with its anchor chain and the ship's bell (attribute Bell).
local function buildSchooner(model: Instance, frame: CFrame, length: number, beam: number)
	local half = length / 2
	piece(
		model,
		frame,
		"Keel",
		Vector3.new(0, 0.2, 0),
		Vector3.new(2, 2, length - 6),
		nil,
		OAK,
		M.Wood
	)
	local k = 0
	for z = -half + 5, half - 5, 5.2 do
		k += 1
		local w = beam / 2 * math.sqrt(math.max(1 - (z / half) ^ 2, 0.05))
		for side = -1, 1, 2 do
			local broken = (k * 7 + side * 3) % 5 == 0
			local ribH = (if broken then 3 else 8 - math.abs(z) / 12) + (k % 3)
			piece(
				model,
				frame,
				"Floor",
				Vector3.new(side * w * 0.45, 0.8, z),
				Vector3.new(w * 0.9, 1, 1.2),
				nil,
				OAK,
				M.Wood
			)
			if not (k % 6 == 0 and side == 1) then
				piece(
					model,
					frame,
					"Rib",
					Vector3.new(side * (w - 0.6), ribH / 2 + 0.6, z),
					Vector3.new(1.2, ribH, 1.2),
					CFrame.Angles(0, 0, -side * 0.28),
					OAK,
					M.Wood
				)
			end
		end
	end
	piece(
		model,
		frame,
		"Stem",
		Vector3.new(0, 5, half - 2),
		Vector3.new(1.6, 11, 1.6),
		CFrame.Angles(0.35, 0, 0),
		OAK,
		M.Wood
	)
	piece(
		model,
		frame,
		"Sternpost",
		Vector3.new(0, 4, -half + 2),
		Vector3.new(1.6, 9, 1.6),
		CFrame.Angles(-0.15, 0, 0),
		OAK,
		M.Wood
	)
	for i = 0, 3 do
		piece(
			model,
			frame,
			"Strake",
			Vector3.new(-beam / 2 + 1.5 + i * 0.4, 1.5 + i * 1.8, -4 + i * 3),
			Vector3.new(0.5, 1.6, length * (0.55 - i * 0.08)),
			CFrame.Angles(0, 0, 0.3),
			rgb(78, 66, 52),
			M.WoodPlanks
		)
	end
	piece(
		model,
		frame,
		"Windlass",
		Vector3.new(0, 3, half - 10),
		Vector3.new(9, 2.6, 2.6),
		nil,
		OAK,
		M.Wood,
		Enum.PartType.Cylinder
	)
	for side = -1, 1, 2 do
		piece(
			model,
			frame,
			"Bitt",
			Vector3.new(side * 5, 2.5, half - 10),
			Vector3.new(1.4, 5, 1.4),
			nil,
			OAK,
			M.Wood
		)
	end
	for i = 0, 15 do
		piece(
			model,
			frame,
			"ChainLink",
			Vector3.new(1.5 + math.sin(i * 0.5) * 2, 0.4, half - 8 + i * 1.5),
			Vector3.new(0.5, if i % 2 == 0 then 1 else 0.5, 1.7),
			nil,
			RUST,
			M.CorrodedMetal
		)
	end
	local bell = piece(
		model,
		frame,
		"Bell",
		Vector3.new(3.5, 0.9, 14),
		Vector3.new(1.6, 1.6, 1.6),
		nil,
		rgb(92, 112, 84),
		M.Metal,
		Enum.PartType.Ball
	)
	bell:SetAttribute("Bell", true)
end

-- The 1960s mail seaplane (an Otter-sized single-engine floatplane, 13 x 17.7 m): fuselage, high wing with a
-- broken tip, tail, engine and propeller, one float on its struts and the other torn off beside it.
local function buildSeaplane(model: Instance, frame: CFrame, length: number, span: number)
	local f = frame * CFrame.new(0, 6.5, 0) * CFrame.Angles(0, 0, 0.12)
	piece(
		model,
		f,
		"Fuselage",
		Vector3.new(0, 0, 2),
		Vector3.new(5.5, 6.5, length * 0.58),
		nil,
		HULL,
		M.Metal
	)
	piece(
		model,
		f,
		"TailCone",
		Vector3.new(0, 0.8, -length * 0.36),
		Vector3.new(3, 4, length * 0.3),
		nil,
		HULL,
		M.Metal
	)
	piece(
		model,
		f,
		"Windscreen",
		Vector3.new(0, 2, length * 0.3 - 1),
		Vector3.new(5, 2, 0.3),
		CFrame.Angles(-0.5, 0, 0),
		rgb(40, 50, 52),
		M.Glass
	)
	piece(
		model,
		f,
		"Cowling",
		Vector3.new(0, 0, length * 0.33 + 2),
		Vector3.new(4, 5.5, 5.5),
		CFrame.Angles(0, math.pi / 2, 0),
		rgb(70, 72, 70),
		M.CorrodedMetal,
		Enum.PartType.Cylinder
	)
	for b = 0, 2 do
		piece(
			model,
			f,
			"Blade",
			Vector3.new(0, 0, length * 0.33 + 4.3),
			Vector3.new(0.6, 9, 0.3),
			CFrame.Angles(0, 0, b * 2.094),
			rgb(50, 50, 50),
			M.Metal
		)
	end
	piece(
		model,
		f,
		"WingLeft",
		Vector3.new(-span / 4 - 1, 3.6, 4),
		Vector3.new(span / 2 - 2, 0.8, 7),
		nil,
		HULL,
		M.Metal
	)
	piece(
		model,
		f,
		"WingRight",
		Vector3.new(span / 4 - 3, 3.6, 4),
		Vector3.new(span / 2 - 6, 0.8, 7),
		nil,
		HULL,
		M.Metal
	)
	piece(
		model,
		frame,
		"WingTip",
		Vector3.new(span / 2 - 2, 1, 3),
		Vector3.new(6, 0.8, 6),
		CFrame.Angles(0.2, 0.4, 0.5),
		HULL,
		M.Metal
	)
	piece(
		model,
		f,
		"Fin",
		Vector3.new(0, 4.5, -length * 0.46),
		Vector3.new(0.5, 7, 5),
		nil,
		HULL,
		M.Metal
	)
	piece(
		model,
		f,
		"Tailplane",
		Vector3.new(0, 2, -length * 0.46),
		Vector3.new(15, 0.5, 4),
		nil,
		HULL,
		M.Metal
	)
	piece(
		model,
		f,
		"FloatLeft",
		Vector3.new(-6, -5.6, 3),
		Vector3.new(3, 3, length * 0.66),
		nil,
		rgb(150, 150, 140),
		M.Metal
	)
	piece(
		model,
		f,
		"StrutFront",
		Vector3.new(-4, -2.8, 9),
		Vector3.new(0.5, 5, 0.5),
		CFrame.Angles(0, 0, -0.4),
		HULL,
		M.Metal
	)
	piece(
		model,
		f,
		"StrutRear",
		Vector3.new(-4, -2.8, -3),
		Vector3.new(0.5, 5, 0.5),
		CFrame.Angles(0, 0, -0.4),
		HULL,
		M.Metal
	)
	piece(
		model,
		frame,
		"FloatRight",
		Vector3.new(14, 1.4, -6),
		Vector3.new(3, 3, length * 0.66),
		CFrame.Angles(0.05, 0.6, 1.2),
		rgb(150, 150, 140),
		M.Metal
	)
end

-- An Admiralty-pattern anchor lying on its side: shank, stock, arms, flukes and ring.
local function buildAnchor(model: Instance, frame: CFrame, length: number)
	local f = frame * CFrame.new(0, 0.9, 0)
	piece(
		model,
		f,
		"Shank",
		Vector3.new(0, 0, 0),
		Vector3.new(1.2, 1.2, length),
		nil,
		RUST,
		M.CorrodedMetal
	)
	piece(
		model,
		f,
		"Stock",
		Vector3.new(0, 0.4, length / 2 - 1.2),
		Vector3.new(length * 0.85, 0.9, 0.9),
		CFrame.Angles(0, 0, 0.08),
		RUST,
		M.CorrodedMetal
	)
	piece(
		model,
		f,
		"Ring",
		Vector3.new(0, 0, length / 2 + 0.8),
		Vector3.new(0.4, 2.4, 2.4),
		nil,
		RUST,
		M.CorrodedMetal,
		Enum.PartType.Cylinder
	)
	for side = -1, 1, 2 do
		local arm = CFrame.new(side * 2.4, 0, -length / 2 + 2.2) * CFrame.Angles(0, side * 0.9, 0)
		piece(
			model,
			f * arm,
			"Arm",
			Vector3.new(0, 0, 0),
			Vector3.new(1, 1, 6),
			nil,
			RUST,
			M.CorrodedMetal
		)
		piece(
			model,
			f * arm,
			"Fluke",
			Vector3.new(0, 0, 3),
			Vector3.new(2.8, 0.4, 2.4),
			nil,
			RUST,
			M.CorrodedMetal
		)
	end
end

local function buildSeabed(map: Instance, points: Instance, world: any)
	local seabed = folder(map, "Seabed")
	for _, poi in world.POIs do
		local frame = CFrame.new(poi.position) * CFrame.Angles(0, math.rad(poi.yaw), 0)
		local model: Instance? = nil
		if poi.id == "Morwenna" then
			model = folder(seabed, poi.id, "Model")
			buildSchooner(
				model :: Instance,
				frame * CFrame.new(0, -1, 0) * CFrame.Angles(0, 0, -0.14),
				poi.length,
				poi.beam
			)
		elseif poi.id == "MailSeaplane" then
			model = folder(seabed, poi.id, "Model")
			buildSeaplane(model :: Instance, frame * CFrame.new(0, -1.5, 0), poi.length, poi.beam)
		elseif poi.id == "AdmiraltyAnchor" then
			model = folder(seabed, poi.id, "Model")
			buildAnchor(model :: Instance, frame * CFrame.new(0, -0.4, 0), poi.length)
		end
		local attrs = {
			Discoverable = true,
			DiscoveryId = poi.id,
			DisplayName = poi.name,
			Kind = poi.kind,
			Era = poi.era,
			Blurb = poi.blurb,
			DiscoverRadius = math.max(poi.length, 40),
		}
		if model then
			for k, v in attrs do
				model:SetAttribute(k, v)
			end
		end
		marker(points, `Discovery_{poi.id}`, poi.position + Vector3.new(0, 2, 0), attrs)
	end
end

local function buildShore(map: Instance, points: Instance, world: any)
	local slips = folder(map, "Slipways", "Model")
	-- station slipway: 20-stud concrete ramp from the quay (Y 4) down to 2 m under water
	local run, drop = 66, 10
	part({
		Name = "StationSlipway",
		Size = Vector3.new(20, 1, math.sqrt(run * run + drop * drop)),
		CFrame = CFrame.new(-165, (4 - 6) / 2 - 0.5, 4 + run / 2)
			* CFrame.Angles(math.atan2(drop, run), 0, 0),
		Color = COLORS.concrete,
		Material = M.Concrete,
		Parent = slips,
		Attributes = { Slipway = "Station" },
	})
	local sands = folder(map, "HavenSands", "Model")
	for _, pt in world.Points do
		marker(
			points,
			pt.id,
			pt.position + Vector3.new(0, 2, 0),
			{ PointKind = pt.kind, PointId = pt.id }
		)
		if pt.kind == "LifeguardTower" then
			local base = pt.position
			for _, c in
				{
					Vector3.new(-3.5, 0, -3.5),
					Vector3.new(3.5, 0, -3.5),
					Vector3.new(-3.5, 0, 3.5),
					Vector3.new(3.5, 0, 3.5),
				}
			do
				box(
					sands,
					"Leg",
					base + c - Vector3.new(0.4, 2, 0.4),
					base + c + Vector3.new(0.4, 9, 0.4),
					COLORS.white
				)
			end
			box(
				sands,
				"LifeguardHut",
				base + Vector3.new(-5, 9, -5),
				base + Vector3.new(5, 17, 5),
				COLORS.red
			)
			box(
				sands,
				"Roof",
				base + Vector3.new(-5.5, 17, -5.5),
				base + Vector3.new(5.5, 17.6, 5.5),
				COLORS.white
			)
			box(
				sands,
				"FlagPole",
				base + Vector3.new(6, 0, 0),
				base + Vector3.new(6.4, 24, 0.4),
				COLORS.white
			)
			box(
				sands,
				"FlagRed",
				base + Vector3.new(6.4, 21.5, 0),
				base + Vector3.new(10.4, 23.5, 0.2),
				COLORS.red
			)
			box(
				sands,
				"FlagYellow",
				base + Vector3.new(6.4, 19.5, 0),
				base + Vector3.new(10.4, 21.5, 0.2),
				COLORS.bay
			)
			-- Handover: no greybox; LandVehicleService parks the real ambulance there (it landed on this box's roof)
		end
	end
	for _, cp in world.CarParks do
		marker(
			points,
			cp.id,
			cp.center + Vector3.new(0, 2, 0),
			{ PointKind = "CarPark", PointId = cp.id, DisplayName = cp.name }
		)
	end
end

-- A SurfaceGui sign on one face of a board part.
local function sign(board: Part, text: string, face: any, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 1
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	-- P2: TextScaled came back false in play from the Lune-built place (8 px text), so size it explicitly too
	local w = if face == Enum.NormalId.Left or face == Enum.NormalId.Right
		then board.Size.Z
		else board.Size.X
	label.TextSize = math.floor(math.min(board.Size.Y * 30 * 0.75, w * 30 / (#text * 0.62)))
	label.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
	label.TextColor3 = color
	label.Parent = gui
end

local function ceilingLight(parent: Instance, pos: Vector3, range: number)
	local lamp = part({
		Name = "CeilingLight",
		Size = Vector3.new(4, 0.3, 1.2),
		CFrame = CFrame.new(pos),
		Color = rgb(255, 244, 220),
		Material = M.Neon,
		CastShadow = false,
		Parent = parent,
	})
	local light = Instance.new("PointLight")
	light.Range = range
	light.Brightness = 1.2
	light.Color = rgb(255, 236, 205)
	light.Shadows = true
	light.Parent = lamp
end

-- A clothes rail: two uprights, a top rail and hanging drysuits / lifejackets (1 m = 3 studs).
local function gearRack(
	parent: Instance,
	name: string,
	from: Vector3,
	to: Vector3,
	colors: { Color3 }
)
	local rack = folder(parent, name, "Model")
	local steel = rgb(150, 154, 160)
	local h = 6 -- 2 m rail
	for _, p in { from, to } do
		box(
			rack,
			"Upright",
			p - Vector3.new(0.15, 0, 0.15),
			p + Vector3.new(0.15, h, 0.15),
			steel,
			M.Metal
		)
		box(
			rack,
			"Foot",
			p - Vector3.new(0.9, 0, 0.9),
			p + Vector3.new(0.9, 0.2, 0.9),
			steel,
			M.Metal
		)
	end
	local railMin = Vector3.new(math.min(from.X, to.X), from.Y + h - 0.2, math.min(from.Z, to.Z))
	local railMax = Vector3.new(math.max(from.X, to.X), from.Y + h, math.max(from.Z, to.Z))
	box(
		rack,
		"Rail",
		railMin - Vector3.new(0.1, 0, 0.1),
		railMax + Vector3.new(0.1, 0, 0.1),
		steel,
		M.Metal
	)
	local span = to - from
	local length = span.Magnitude
	local along = span.Unit
	local count = math.floor(length / 1.4) - 1
	for i = 1, count do
		local c = from + along * (i * length / (count + 1))
		local at = c + Vector3.new(0, h - 1.7, 0)
		part({
			Name = "Garment",
			-- 0.6 m wide, 0.9 m long, hung flat across the rail (thin along it)
			Size = Vector3.new(1.8, 2.8, 0.5),
			CFrame = CFrame.lookAt(at, at + along),
			Color = colors[(i - 1) % #colors + 1],
			Material = M.Fabric,
			Parent = rack,
		})
	end
end

-- Port Haven Chandlery (docs 10 section 1.2, docs 04 section 1.1): the walk-in store next to the
-- station on Harbour Road. 20 x 12 m (60 x 36 studs), two floors: the shop with the gear counter,
-- racks and shelves below, the fitting loft (mirror, mannequins) above, reached by a stair ramp.
-- The door faces the road and the quay, about 45 studs from the station door and 35 from the spawn.
-- Docs 10 gives its centre as (+40, -20) from the station; the greybox station is not yet re-laid
-- on the docs origin, so the shop sits beside the greybox station in the same relation instead.
local function buildChandlery(parent: Instance, g: number)
	local shop = folder(parent, "Chandlery", "Model")
	-- greybox: the server's WorldDressingService swaps it for the H2 Packages (src/server/World/Swaps.luau)
	-- once they load; it stays (and works) when they fail
	shop:AddTag("GREYBOX")
	shop:SetAttribute("AssetSwap", "Chandlery")
	local render = rgb(234, 230, 216) -- painted render
	local navy = rgb(28, 50, 86)
	local slate = rgb(62, 66, 74)
	local oak = rgb(140, 104, 70)
	local glass = rgb(170, 200, 210)
	local x0, x1, z0, z1 = -74, -14, -78, -42 -- z0 back (north), z1 front (south, the road)
	local floor1, top = 13, 25 -- first-floor slab underside and wall top, above ground

	box(shop, "Floor", Vector3.new(x0, g - 2, z0), Vector3.new(x1, g + 0.2, z1), oak, M.WoodPlanks)
	-- walls (1 stud = 0.33 m thick)
	box(
		shop,
		"BackWall",
		Vector3.new(x0, g, z0),
		Vector3.new(x1, g + top, z0 + 1),
		render,
		M.Concrete
	)
	box(
		shop,
		"WestWall",
		Vector3.new(x0, g, z0 + 1),
		Vector3.new(x0 + 1, g + top, z1 - 1),
		render,
		M.Concrete
	)
	box(
		shop,
		"EastWall",
		Vector3.new(x1 - 1, g, z0 + 1),
		Vector3.new(x1, g + top, z1 - 1),
		render,
		M.Concrete
	)
	-- front, ground floor: door opening x -68..-62 (2 m wide, 3 m high), shop window x -58..-20
	local fz0, fz1 = z1 - 1, z1
	box(
		shop,
		"FrontWest",
		Vector3.new(x0, g, fz0),
		Vector3.new(-68, g + floor1, fz1),
		render,
		M.Concrete
	)
	box(
		shop,
		"OverDoor",
		Vector3.new(-68, g + 9.5, fz0),
		Vector3.new(-62, g + floor1, fz1),
		render,
		M.Concrete
	)
	box(
		shop,
		"Pier",
		Vector3.new(-62, g, fz0),
		Vector3.new(-58, g + floor1, fz1),
		render,
		M.Concrete
	)
	box(shop, "Sill", Vector3.new(-58, g, fz0), Vector3.new(-20, g + 3, fz1), navy, M.WoodPlanks)
	local window = box(
		shop,
		"ShopWindow",
		Vector3.new(-58, g + 3, fz0 + 0.35),
		Vector3.new(-20, g + 10, fz1 - 0.35),
		glass,
		M.Glass
	)
	window.Transparency = 0.6
	box(
		shop,
		"WindowHead",
		Vector3.new(-58, g + 10, fz0),
		Vector3.new(-20, g + floor1, fz1),
		render,
		M.Concrete
	)
	box(
		shop,
		"FrontEast",
		Vector3.new(-20, g, fz0),
		Vector3.new(x1, g + floor1, fz1),
		render,
		M.Concrete
	)
	box(
		shop,
		"FrontUpper",
		Vector3.new(x0, g + floor1, fz0),
		Vector3.new(x1, g + top, fz1),
		render,
		M.Concrete
	)
	-- door frame and the fascia sign over the window
	box(
		shop,
		"DoorPostW",
		Vector3.new(-68.6, g, fz1),
		Vector3.new(-68, g + 10, fz1 + 0.4),
		navy,
		M.Wood
	)
	box(
		shop,
		"DoorPostE",
		Vector3.new(-62, g, fz1),
		Vector3.new(-61.4, g + 10, fz1 + 0.4),
		navy,
		M.Wood
	)
	box(
		shop,
		"DoorLintel",
		Vector3.new(-68.6, g + 9.5, fz1),
		Vector3.new(-61.4, g + 10.1, fz1 + 0.4),
		navy,
		M.Wood
	)
	local fascia = box(
		shop,
		"Fascia",
		Vector3.new(-59, g + 10.4, fz1),
		Vector3.new(-19, g + 12.8, fz1 + 0.4),
		navy,
		M.Wood
	)
	sign(fascia, "PORT HAVEN CHANDLERY", Enum.NormalId.Back, rgb(255, 214, 120))
	box(
		shop,
		"StringCourse",
		Vector3.new(x0, g + floor1, fz1),
		Vector3.new(x1, g + floor1 + 0.6, fz1 + 0.3),
		navy,
		M.Wood
	)
	-- upper windows (fitting loft), proud of the wall
	for _, wx in { -66, -50, -34 } do
		local w = box(
			shop,
			"LoftWindow",
			Vector3.new(wx, g + 16, fz1),
			Vector3.new(wx + 8, g + 22, fz1 + 0.2),
			rgb(70, 90, 105),
			M.Glass
		)
		w.Transparency = 0.3
		box(
			shop,
			"LoftSill",
			Vector3.new(wx - 0.4, g + 15.6, fz1),
			Vector3.new(wx + 8.4, g + 16, fz1 + 0.5),
			navy,
			M.Wood
		)
	end

	-- first floor (fitting loft): slab with a stairwell along the east wall (x -21..-15, z -77..-56)
	box(
		shop,
		"LoftFloor",
		Vector3.new(x0 + 1, g + floor1, z0 + 1),
		Vector3.new(-21, g + floor1 + 1, z1 - 1),
		oak,
		M.WoodPlanks
	)
	box(
		shop,
		"LoftLanding",
		Vector3.new(-21, g + floor1, -56),
		Vector3.new(x1 - 1, g + floor1 + 1, z1 - 1),
		oak,
		M.WoodPlanks
	)
	box(
		shop,
		"StairRailing",
		Vector3.new(-21.4, g + floor1 + 1, -77),
		Vector3.new(-21, g + floor1 + 4, -56),
		navy,
		M.Wood
	)
	local rise = floor1 + 1 - 0.2
	part({
		ClassName = "WedgePart",
		Name = "Stair",
		-- low end at the back wall, rising toward the front onto the landing (tall side +Z)
		Size = Vector3.new(6, rise, 21),
		CFrame = CFrame.new(-18, g + 0.2 + rise / 2, -66.5),
		Color = oak,
		Material = M.WoodPlanks,
		Parent = shop,
	})

	-- roof: slate pitch along X over a flat deck
	box(
		shop,
		"RoofDeck",
		Vector3.new(x0 - 1, g + top, z0 - 1),
		Vector3.new(x1 + 1, g + top + 1, z1 + 1),
		slate,
		M.Slate
	)
	local mid = (z0 + z1) / 2
	local half = (z1 - z0) / 2 + 1
	part({
		ClassName = "WedgePart",
		Name = "RoofBack",
		Size = Vector3.new(x1 - x0 + 2, 6, half),
		CFrame = CFrame.new((x0 + x1) / 2, g + top + 4, mid - half / 2),
		Color = slate,
		Material = M.Slate,
		Parent = shop,
	})
	part({
		ClassName = "WedgePart",
		Name = "RoofFront",
		Size = Vector3.new(x1 - x0 + 2, 6, half),
		CFrame = CFrame.new((x0 + x1) / 2, g + top + 4, mid + half / 2)
			* CFrame.Angles(0, math.pi, 0),
		Color = slate,
		Material = M.Slate,
		Parent = shop,
	})
	box(
		shop,
		"Chimney",
		Vector3.new(-70, g + top, -66),
		Vector3.new(-66, g + top + 10, -62),
		render,
		M.Brick
	)

	-- ground floor: the gear counter, shelves behind it, racks and a gondola
	box(
		shop,
		"Counter",
		Vector3.new(-42, g + 0.2, -65),
		Vector3.new(-22, g + 3.5, -62),
		navy,
		M.Wood
	)
	box(
		shop,
		"CounterTop",
		Vector3.new(-42.3, g + 3.5, -65.3),
		Vector3.new(-21.7, g + 3.8, -61.7),
		oak,
		M.WoodPlanks
	)
	box(
		shop,
		"Till",
		Vector3.new(-26, g + 3.8, -64.5),
		Vector3.new(-24, g + 5, -63),
		rgb(40, 40, 44),
		M.Metal
	)
	box(
		shop,
		"LogbookOnCounter",
		Vector3.new(-35, g + 3.8, -64),
		Vector3.new(-32.6, g + 3.95, -62.4),
		rgb(120, 40, 36),
		M.Fabric
	)
	box(
		shop,
		"ShelfBack",
		Vector3.new(-44, g + 0.2, -77),
		Vector3.new(-22, g + 10, -76.6),
		oak,
		M.WoodPlanks
	)
	for _, sx in { -44, -33.2, -22.4 } do
		box(
			shop,
			"ShelfSide",
			Vector3.new(sx, g + 0.2, -77),
			Vector3.new(sx + 0.4, g + 10, -74.8),
			oak,
			M.Wood
		)
	end
	local stock = {
		rgb(255, 120, 30),
		rgb(250, 210, 60),
		rgb(40, 90, 160),
		rgb(200, 50, 40),
		rgb(60, 150, 90),
	}
	for level, sy in { 1, 3.5, 6, 8.5 } do
		box(
			shop,
			"Shelf",
			Vector3.new(-44, g + sy, -76.6),
			Vector3.new(-22, g + sy + 0.2, -74.8),
			oak,
			M.WoodPlanks
		)
		for i = 0, 5 do
			local bx = -43 + i * 3.4 + (level % 2) * 0.8
			box(
				shop,
				"Stock",
				Vector3.new(bx, g + sy + 0.2, -76.3),
				Vector3.new(bx + 1.6, g + sy + 1.4, -75.2),
				stock[(i + level) % #stock + 1],
				M.SmoothPlastic
			)
		end
	end
	gearRack(shop, "RackWest", Vector3.new(-71.5, g + 0.2, -75), Vector3.new(-71.5, g + 0.2, -50), {
		rgb(255, 110, 20),
		rgb(250, 200, 40),
		rgb(28, 50, 86),
		rgb(200, 40, 36),
	})
	gearRack(shop, "RackMid", Vector3.new(-62, g + 0.2, -72), Vector3.new(-50, g + 0.2, -72), {
		rgb(40, 40, 46),
		rgb(255, 110, 20),
		rgb(60, 120, 170),
	})
	-- gondola: a double-sided 1.2 m shelf unit with lifebuoys and rope coils
	box(
		shop,
		"Gondola",
		Vector3.new(-62, g + 0.2, -60),
		Vector3.new(-48, g + 3.8, -56),
		oak,
		M.WoodPlanks
	)
	for i = 0, 3 do
		part({
			Name = "RopeCoil",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.8, 2.2, 2.2),
			CFrame = CFrame.new(-60 + i * 3.4, g + 4.2, -58) * CFrame.Angles(0, 0, math.pi / 2),
			Color = if i % 2 == 0 then rgb(230, 220, 190) else rgb(220, 90, 40),
			Material = M.Fabric,
			Parent = shop,
		})
	end
	for i = 0, 2 do
		part({
			Name = "Lifebuoy",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.5, 2.6, 2.6),
			-- hung flat on the west wall above the rack (axis along X)
			CFrame = CFrame.new(x0 + 1.3, g + 8.5, -70 + i * 8),
			Color = rgb(240, 90, 30),
			Material = M.SmoothPlastic,
			Parent = shop,
		})
	end
	ceilingLight(shop, Vector3.new(-56, g + floor1 - 0.2, -64), 30)
	ceilingLight(shop, Vector3.new(-32, g + floor1 - 0.2, -64), 30)
	ceilingLight(shop, Vector3.new(-56, g + floor1 - 0.2, -50), 24)

	-- fitting loft: a full-length mirror and two mannequins
	local lf = g + floor1 + 1
	local mirror = box(
		shop,
		"Mirror",
		Vector3.new(x0 + 1, lf + 0.5, -62),
		Vector3.new(x0 + 1.3, lf + 7, -56),
		rgb(200, 210, 215),
		M.Glass
	)
	mirror.Reflectance = 0.6
	for i, mx in { -56, -46 } do
		box(
			shop,
			"MannequinBase",
			Vector3.new(mx - 1, lf, -72),
			Vector3.new(mx + 1, lf + 0.3, -70),
			slate,
			M.Metal
		)
		box(
			shop,
			"MannequinBody",
			Vector3.new(mx - 0.9, lf + 2.3, -71.5),
			Vector3.new(mx + 0.9, lf + 5, -70.5),
			stock[i],
			M.Fabric
		)
		box(
			shop,
			"MannequinLegs",
			Vector3.new(mx - 0.6, lf + 0.3, -71.3),
			Vector3.new(mx + 0.6, lf + 2.3, -70.7),
			navy,
			M.Fabric
		)
		part({
			Name = "MannequinHead",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1, 1, 1),
			CFrame = CFrame.new(mx, lf + 5.6, -71),
			Color = rgb(230, 225, 215),
			Material = M.SmoothPlastic,
			Parent = shop,
		})
	end
	ceilingLight(shop, Vector3.new(-48, g + top - 0.2, -62), 30)
	return shop
end

-- Harbourmaster's desk (docs/04 sections 1.1 and 5, RP-M3): a greybox stand-in on the quay just east
-- of the Chandlery until the H4 office building exists. A desk with a brass storm barometer behind it
-- and a chalkboard by the side panel showing the server's storm queue (StormBoard: the client writes
-- its Sign.Text from ReplicatedStorage.Weather SummonQueue). Dressing only: storms are sold in the phone Store.
local function buildHarbourmasterDesk(parent: Instance, g: number)
	local desk = folder(parent, "HarbourmasterDesk", "Model")
	local navy = rgb(28, 50, 86)
	local brass = rgb(176, 140, 72)
	local x0, x1, zb, zf = -14, -4, -18, -12 -- back wall (north) and desk front (south, the water)
	box(
		desk,
		"BackWall",
		Vector3.new(x0, g, zb - 1),
		Vector3.new(x1, g + 10, zb),
		COLORS.white,
		M.Concrete
	)
	box(
		desk,
		"SideWest",
		Vector3.new(x0, g, zb),
		Vector3.new(x0 + 1, g + 10, zf),
		COLORS.white,
		M.Concrete
	)
	box(
		desk,
		"SideEast",
		Vector3.new(x1 - 1, g, zb),
		Vector3.new(x1, g + 10, zf),
		COLORS.white,
		M.Concrete
	)
	box(
		desk,
		"Desk",
		Vector3.new(x0 + 1, g, zf - 1.5),
		Vector3.new(x1 - 1, g + 3.5, zf),
		navy,
		M.Wood
	)
	box(
		desk,
		"DeskTop",
		Vector3.new(x0 + 0.8, g + 3.5, zf - 1.7),
		Vector3.new(x1 - 0.8, g + 3.8, zf + 0.4),
		COLORS.wood,
		M.WoodPlanks
	)
	box(
		desk,
		"Canopy",
		Vector3.new(x0 - 1, g + 10, zb - 2),
		Vector3.new(x1 + 1, g + 10.6, zf + 3),
		navy,
		M.SmoothPlastic
	)
	local board = box(
		desk,
		"SignBoard",
		Vector3.new(x0 + 1, g + 10.6, zf + 2.4),
		Vector3.new(x1 - 1, g + 12.6, zf + 2.8),
		navy,
		M.Wood
	)
	sign(board, "HARBOURMASTER", Enum.NormalId.Back, COLORS.white)
	-- the storm barometer: a brass case with a white dial on the back wall, behind the desk
	local cx = (x0 + x1) / 2
	part({
		Name = "Barometer",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 3, 3),
		CFrame = CFrame.new(cx, g + 7, zb + 0.2) * CFrame.Angles(0, math.pi / 2, 0),
		Color = brass,
		Material = M.Metal,
		Parent = desk,
	})
	part({
		Name = "BarometerDial",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.1, 2.4, 2.4),
		CFrame = CFrame.new(cx, g + 7, zb + 0.45) * CFrame.Angles(0, math.pi / 2, 0),
		Color = rgb(236, 230, 214),
		Material = M.SmoothPlastic,
		Parent = desk,
	})
	-- the storm queue chalkboard on the outside of the east side panel, facing the quay
	local chalk = box(
		desk,
		"StormBoard",
		Vector3.new(x1, g + 3, zf - 4.5),
		Vector3.new(x1 + 0.3, g + 7, zf - 0.5),
		rgb(34, 40, 38),
		M.Slate
	)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign"
	gui.Face = Enum.NormalId.Right
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 1
	gui.Parent = chalk
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(0.9, 0.85)
	label.Position = UDim2.fromScale(0.05, 0.075)
	label.BackgroundTransparency = 1
	label.Text = "STORM QUEUE\nNone waiting"
	label.TextScaled = true
	label.FontFace = Font.new("rbxasset://fonts/families/PatrickHand.json")
	label.TextColor3 = rgb(226, 226, 216)
	label.Parent = gui
	return desk
end

-- Instance streaming (I1): the gameplay map (Map, Zones) stays Persistent, so every client script that reads
-- Workspace.Map works as before; the run-time dressing (WorldDressingService: the Chandlery Packages, the K1 rocks and
-- G1 plants from map/generated/props.json) lives in Workspace.Dressing as Atomic models that stream by distance.
-- Every greybox model that remains carries the CollectionService tag GREYBOX.
local function setupStreaming(ws: any, map: Instance, zones: Instance)
	ws.StreamingEnabled = true
	ws.StreamingMinRadius = 384
	-- RP-P1: 1024 is the docs/10 section 6.7 Low-tier budget. The radius is a place setting, not
	-- scriptable at run time (the engine marks StreamingTargetRadius Not Scriptable), so one value
	-- serves every tier; 2048 streamed about 40% more parts at Haven Sands for no phone budget.
	ws.StreamingTargetRadius = 1024
	ws.StreamOutBehavior = Enum.StreamOutBehavior.LowMemory
	map.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	zones.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	for _, d in map:GetDescendants() do
		if d:IsA("Model") then
			d.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		end
	end
	local town = map:FindFirstChild("PortHaven")
	for _, root in { town, map:FindFirstChild("HarbourLight"), map:FindFirstChild("Breakwater") } do
		for _, child in if root then root:GetChildren() else {} do
			if child:IsA("Model") or child:IsA("Folder") then
				child:AddTag("GREYBOX")
			end
		end
	end
end

return function(place: any, ctx: any)
	local GameConfig = ctx.require("Config/GameConfig")
	local WorldConfig = ctx.require("Config/WorldConfig")
	local ws = place:GetService("Workspace")
	local landTop, floorY = GameConfig.LandTopY, GameConfig.OceanFloorY

	ws:SetAttribute("SeaLevel", GameConfig.SeaLevel)
	local hasTerrain = loadTerrain(ws, ctx)
	ws:SetAttribute("WorldTerrain", hasTerrain)
	local map = folder(ws, "Map", "Model")
	if not hasTerrain then
		buildOceanFloor(map, floorY)
	end
	local town = buildPortHaven(map, landTop, floorY, hasTerrain)
	buildChandlery(town, landTop)
	buildHarbourmasterDesk(town, landTop)
	buildDropOffs(map)
	local wallTop, wallFar = buildBreakwater(map, floorY, 30)
	if not hasTerrain then
		buildBeach(map, landTop)
	end
	buildLighthouse(map, Vector3.new(44, wallTop, wallFar))
	local points = folder(map, "WorldPoints")
	buildShore(map, points, WorldConfig)
	buildSeabed(map, points, WorldConfig)
	local zones = folder(ws, "Zones", "Model")
	buildZones(zones, GameConfig.Zones)
	setupStreaming(ws, map, zones)
end
