-- Build-time map, run by tools/build-map.luau under Lune (NOT shipped as a script).
-- Called as build(game, ctx); ctx.require loads shared modules (GameConfig, WorldConfig) through the require shim.
-- Globals: Instance, Vector3, CFrame, Color3, Enum, game, workspace.
-- Lune limits: no physics, no Terrain editing, no Model:PivotTo. New Parts default to Studs
-- surfaces and Anchored = false, so the part() helper sets both.
--
-- Terrain: Lune cannot write voxels, but it can move a whole Terrain instance. map/terrain/Terrain.rbxm (written in
-- Studio by tools/world/studio_terrain.py from the bake in map/generated, see tools/world/README.md) is parented into
-- Workspace as-is (SmoothGrid + PhysicsGrid). Without it only the part-built OceanFloor is built (no land).
--
-- Builds Workspace.Map (sea level Y = 0, no Terrain water: the ocean is a client mesh):
--   OceanFloor   (fallback only) sand base, top at Y = -40
--   Hub          the hub island's spawn, Coastguard HQ greybox, call board, shop counter and quay (buildHub)
--   DropOffs     DropOff_Dock, the hub drop-off pad (water level, attribute DropOff)
--   Seabed       wrecks and finds from WorldConfig.POIs (Morwenna, the mail seaplane, the Admiralty anchor)
--   WorldPoints  invisible discovery markers with attributes (Discoverable)
-- and Workspace.Zones (invisible, non-collide cylinders with attribute Zone = "<id>", from GameConfig).

local SMOOTH = Enum.SurfaceType.Smooth
local M = Enum.Material

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local COLORS = {
	seabed = rgb(150, 140, 110),
	wood = rgb(120, 90, 60),
	white = rgb(236, 236, 230),
	red = rgb(196, 48, 40),
	roof = rgb(70, 72, 80),
	dropoff = rgb(60, 200, 110),
	glass = rgb(255, 240, 180),
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

-- An image on one face of a board (the call icon, the Store icon).
local function decal(board: Part, image: string, face: any)
	local d = Instance.new("Decal")
	d.Texture = image
	d.Face = face
	d.Parent = board
end

-- The hub (docs/23 (k), WP-19a): a small coastguard hub, not a town. Everything sits on HubLayout's lots; the hub
-- frame looks out of the harbour (+Z), so (right, fwd) here are HubLayout's (right, fwd) and world x = -right.
--   Hub.HubSpawn      the newcomer spawn on the plaza, facing the HQ door
--   Hub.Station       greybox Coastguard HQ (Swaps.Station puts M_Bld_Station on it; StationRig adds the radio)
--   Hub.CallBoard     noticeboard with the call icon (tag CallBoard)
--   Hub.ShopCounter   solid counter with the Store icon; its prompt (tag ShopCounter) opens the phone Store
--   Hub.Quay          plaza paving, quay coping, bollards, the green drop-off band, benches, flags, lamps
--   DropOffs.DropOff_Dock  the hub drop-off pad in the harbour (attribute DropOff = "Dock")
local function buildHub(map: Instance, H: any, ui: any)
	local hub = folder(map, "Hub", "Model")
	local function at(right: number, fwd: number, y: number?, yaw: number?): CFrame
		return H.Hub.frame * CFrame.new(right, y or 0, -fwd) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	end
	local function block(
		parent: Instance,
		name: string,
		size: Vector3,
		cf: CFrame,
		color: Color3,
		mat: any?,
		extra: { [string]: any }?
	): Part
		local props: { [string]: any } = {
			Name = name,
			Size = size,
			CFrame = cf,
			Color = color,
			Material = mat or M.SmoothPlastic,
			Parent = parent,
		}
		for k, v in extra or {} do
			props[k] = v
		end
		return part(props)
	end
	local STONE, COPING = rgb(176, 170, 160), rgb(206, 200, 188)
	local NAVY, ORANGE, IRON = rgb(30, 48, 86), rgb(255, 107, 26), rgb(40, 42, 46)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.TopSurface = SMOOTH
	spawn.BottomSurface = SMOOTH
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = H.Hub.spawn + Vector3.new(0, 0.05, 0)
	spawn.Color = STONE
	spawn.Material = M.Granite
	spawn.Parent = hub

	-- greybox HQ: white hall, red roof, red bay door on the harbour face
	local lot = H.Hub.lots.HQ
	local station = folder(hub, "Station", "Model")
	local w, d = lot.size.X - 4, lot.size.Y
	block(station, "Building", Vector3.new(w, 24, d), lot.cframe * CFrame.new(0, 12, 0), COLORS.white)
	block(station, "Roof", Vector3.new(w + 4, 2, d + 4), lot.cframe * CFrame.new(0, 25, 0), COLORS.red)
	block(station, "Doors", Vector3.new(20, 14, 0.4), lot.cframe * CFrame.new(-10, 7, -d / 2 - 0.2), COLORS.red)
	block(station, "Tower", Vector3.new(10, 14, 10), lot.cframe * CFrame.new(20, 33, 0), COLORS.white)

	-- the quay: plaza paving from the HQ front to the harbour head, coping round the harbour, bollards
	local quay = folder(hub, "Quay", "Model")
	local notch = H.Notch.hub
	local function bollard(right: number, fwd: number)
		block(quay, "Bollard", Vector3.new(1.6, 1.4, 1.4), at(right, fwd, 0.8) * CFrame.Angles(0, 0, math.pi / 2), IRON, M.Metal, { Shape = Enum.PartType.Cylinder })
	end
	block(quay, "Plaza", Vector3.new(124, 1, notch.head - 2), at(0, notch.head / 2 + 1, -0.45), STONE, M.Granite)
	block(quay, "CopingHead", Vector3.new(notch.halfWidth * 2 + 4, 0.6, 2), at(0, notch.head - 1.5, 0.3), COPING, M.Granite)
	for _, s in { -1, 1 } do
		local x = s * (notch.halfWidth + 1.5)
		local len = H.HubRadius - notch.head - 12
		block(quay, "CopingSide", Vector3.new(2, 0.6, len), at(x, notch.head + len / 2, 0.3), COPING, M.Granite)
		for k = 0, 2 do
			bollard(x, notch.head + 18 + k * 26)
		end
	end
	-- the drop-off berth: two bollards and a green band on the coping at the harbour head (the pad's colour)
	bollard(-12, notch.head - 4)
	bollard(12, notch.head - 4)
	block(quay, "DropOffBand", Vector3.new(20, 0.08, 2), at(0, notch.head - 1.5, 0.64), COLORS.dropoff, M.SmoothPlastic, { CanCollide = false })
	-- life ring on a post by the steps
	block(quay, "RingPost", Vector3.new(0.4, 5, 0.4), at(notch.halfWidth - 4, notch.head - 4, 2.5), COLORS.white)
	block(quay, "LifeRing", Vector3.new(0.6, 3, 3), at(notch.halfWidth - 4, notch.head - 3.6, 3.6, 90), ORANGE, M.SmoothPlastic, { Shape = Enum.PartType.Cylinder })

	-- benches facing the harbour along the plaza sides
	for _, spot in { { -30, 60 }, { 30, 60 }, { -30, 82 }, { 30, 82 } } do
		local cf = at(spot[1], spot[2]) -- front (+fwd) to the harbour, the back rest behind
		block(quay, "Bench", Vector3.new(6, 0.4, 1.8), cf * CFrame.new(0, 1.6, 0), COLORS.wood, M.Wood)
		block(quay, "BenchBack", Vector3.new(6, 1.6, 0.3), cf * CFrame.new(0, 2.8, 0.9), COLORS.wood, M.Wood)
		for _, x in { -2.5, 2.5 } do
			block(quay, "BenchLeg", Vector3.new(0.4, 1.4, 1.6), cf * CFrame.new(x, 0.7, 0), IRON, M.Metal)
		end
	end

	-- lamps round the plaza (warm, always on: placeholder, no day/night rig)
	for _, spot in { { -56, 12 }, { 56, 12 }, { -56, 50 }, { 56, 50 }, { -44, 96 }, { 44, 96 } } do
		block(quay, "LampPost", Vector3.new(0.5, 11, 0.5), at(spot[1], spot[2], 5.5), IRON, M.Metal)
		local head = block(quay, "LampHead", Vector3.new(1.4, 1.2, 1.4), at(spot[1], spot[2], 11.4), COLORS.glass, M.Neon)
		local light = Instance.new("PointLight")
		light.Range = 26
		light.Brightness = 1.4
		light.Color = rgb(255, 196, 140)
		light.Shadows = false
		light.Parent = head
	end

	-- flags: two by the HQ front (coastguard orange and navy), one tall at the harbour head
	for _, f in { { -40, 6, 20, ORANGE }, { 40, 6, 20, NAVY }, { -notch.halfWidth - 8, notch.head - 6, 30, COLORS.red } } do
		local h = f[3]
		block(quay, "FlagPole", Vector3.new(0.5, h, 0.5), at(f[1], f[2], h / 2), COLORS.white)
		block(quay, "Flag", Vector3.new(6.5, 4, 0.05), at(f[1] + 3.5, f[2], h - 2.4), f[4], M.Fabric, { CanCollide = false })
	end

	-- call board: a framed noticeboard on two posts, the call icon on its face, pinned notes
	local cb = H.Hub.lots.CallBoard
	local board = folder(hub, "CallBoard", "Model")
	board:AddTag("CallBoard")
	for _, x in { -5.4, 5.4 } do
		block(board, "Post", Vector3.new(0.6, 9, 0.6), cb.cframe * CFrame.new(x, 4.5, 0), COLORS.wood, M.Wood)
	end
	block(board, "Board", Vector3.new(10.4, 6, 0.5), cb.cframe * CFrame.new(0, 5.6, 0), rgb(176, 132, 84), M.Wood)
	block(board, "Header", Vector3.new(11, 1.2, 0.7), cb.cframe * CFrame.new(0, 9.1, 0), COLORS.red)
	block(board, "Cap", Vector3.new(12, 0.4, 1.6), cb.cframe * CFrame.new(0, 9.9, 0), COLORS.roof)
	local icon = block(board, "Icon", Vector3.new(3.6, 3.6, 0.1), cb.cframe * CFrame.new(-2.6, 5.6, -0.3), COLORS.white, M.SmoothPlastic, { CanCollide = false })
	decal(icon, ui.Hud.MissionPiw, Enum.NormalId.Front)
	for i, note in { { 1.2, 6.6, -6 }, { 3.6, 6.2, 5 }, { 1.6, 4.2, 3 }, { 3.8, 4.0, -4 } } do
		block(board, "Note", Vector3.new(1.8, 2.2, 0.05), cb.cframe * CFrame.new(note[1], note[2], -0.28) * CFrame.Angles(0, 0, math.rad(note[3])), if i % 2 == 0 then COLORS.white else COLORS.glass, M.SmoothPlastic, { CanCollide = false })
	end

	-- shop counter: a solid counter under a striped awning, the Store icon over it; the prompt opens the phone Store
	local sc = H.Hub.lots.ShopCounter
	local shop = folder(hub, "ShopCounter", "Model")
	local sw, sd = sc.size.X, sc.size.Y
	local counter = block(shop, "Counter", Vector3.new(sw - 4, 3.6, 2.4), sc.cframe * CFrame.new(0, 1.8, -sd / 2 + 1.6), COLORS.white)
	block(shop, "CounterTop", Vector3.new(sw - 3, 0.3, 3), sc.cframe * CFrame.new(0, 3.75, -sd / 2 + 1.6), COLORS.wood, M.Wood)
	block(shop, "Kiosk", Vector3.new(sw, 12, sd - 4), sc.cframe * CFrame.new(0, 6, 2), NAVY)
	for k = 0, 4 do
		block(shop, "Awning", Vector3.new(sw / 5, 0.3, 4), sc.cframe * CFrame.new(-sw / 2 + sw / 10 + k * sw / 5, 9.6, -3) * CFrame.Angles(math.rad(-15), 0, 0), if k % 2 == 0 then COLORS.white else COLORS.red, M.Fabric)
	end
	local sign = block(shop, "Sign", Vector3.new(5, 5, 0.3), sc.cframe * CFrame.new(0, 13, -1.2), COLORS.white)
	decal(sign, ui.Phone.Store, Enum.NormalId.Front)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ActionText = "Shop"
	prompt.ObjectText = ""
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:AddTag("ShopCounter")
	prompt.Parent = counter

	-- the hub drop-off pad, in the harbour off the quay head
	local drop = folder(map, "DropOffs")
	part({
		Name = "DropOff_Dock",
		Size = Vector3.new(20, 0.4, 16),
		CFrame = CFrame.new(H.Hub.dropOff + Vector3.new(0, 0.2, 0)),
		Color = COLORS.dropoff,
		Transparency = 0.5,
		CanCollide = false,
		Parent = drop,
		Attributes = { DropOff = "Dock" },
	})
end

-- Instance streaming (I1): the gameplay map (Map, Zones) stays Persistent, so every client script that reads
-- Workspace.Map works as before; the run-time dressing (WorldDressingService: the building Packages, the K1 rocks and
-- G1 plants from map/generated/props.json) lives in Workspace.Dressing as Atomic models that stream by distance.
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
end

return function(place: any, ctx: any)
	local GameConfig = ctx.require("Config/GameConfig")
	local WorldConfig = ctx.require("Config/WorldConfig")
	local ws = place:GetService("Workspace")
	ws:SetAttribute("SeaLevel", GameConfig.SeaLevel)
	local hasTerrain = loadTerrain(ws, ctx)
	ws:SetAttribute("WorldTerrain", hasTerrain)
	local map = folder(ws, "Map", "Model")
	if not hasTerrain then
		buildOceanFloor(map, GameConfig.OceanFloorY)
	end
	buildHub(map, ctx.require("Config/HubLayout"), ctx.require("Config/UiImages"))
	local points = folder(map, "WorldPoints")
	buildSeabed(map, points, WorldConfig)
	local zones = folder(ws, "Zones", "Model")
	buildZones(zones, GameConfig.Zones)
	setupStreaming(ws, map, zones)
end
