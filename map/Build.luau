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
--   Hub          the hub forest's outposts: spawn, lookout hut HQ, call board, market stall, quay, jetty,
--                harbourmaster, campfire, monument, quest camps, hidden spots (buildHub)
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

-- The hub (docs/23 (l), WP-21a): a forest island the coastguard has only just landed on. Frontier camps in the
-- clearings (HubLayout lots / clearings, from the terrain bake): canvas, crates, rope, lanterns, rough timber; no
-- buildings. The hub frame looks out of the harbour (+Z): (right, fwd) are HubLayout's, world x = -right. The bake
-- renders every clearing at its config height (tools/world/layout.py RENDER_BIAS), so parts sit on lot Y directly.
--   Hub.HubSpawn       the newcomer spawn on the Landing, facing the lookout hut
--   Hub.Lookout        the HQ: a coastguard lookout hut and tower on a timber deck, the radio inside (tag StationRadio)
--   Hub.CallBoard      noticeboard with the call icon (tag CallBoard)
--   Hub.ShopCounter    the market stall; its counter prompt (tag ShopCounter) opens the phone Store
--   Hub.Quay           the timber landing stage at the harbour head, bollards, the green drop-off band
--   Hub.Jetty          the visitor jetty along the east harbour wall
--   Hub.Harbourmaster  the harbourmaster's shack and storm-signal mast on the west quay
--   Hub.Campfire       fire ring, log benches and a small stage (live-ops events)
--   Hub.Monument       the rescuer statue (LeaderboardService hangs the rescue board beside it), the album stamp post
--   Hub.QuestCamps     empty camps at HubLayout.Hub.questSpots (tag QuestCamp, attribute QuestSpot) for WP-21b
--   Hub.Ruin, Hub.Wreck  the hidden spots (DiscoveryConfig.Pages.Hub stickers)
--   DropOffs.DropOff_Dock  the hub drop-off pad in the harbour (attribute DropOff = "Dock")
local function buildHub(map: Instance, H: any, ui: any)
	local hub = folder(map, "Hub", "Model")
	local function at(right: number, fwd: number, y: number?, yaw: number?): CFrame
		return H.Hub.frame
			* CFrame.new(right, y or 0, -fwd)
			* CFrame.Angles(0, math.rad(yaw or 0), 0)
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
	local TIMBER, PLANK, DARK = rgb(126, 92, 60), rgb(150, 114, 74), rgb(84, 64, 46)
	local CANVAS, OLIVE, BRICKRED = rgb(214, 200, 168), rgb(118, 120, 82), rgb(160, 92, 60)
	local STONE, NAVY, ORANGE, IRON =
		rgb(128, 124, 116), rgb(30, 48, 86), rgb(255, 107, 26), rgb(40, 42, 46)
	local CYL, BALL = { Shape = Enum.PartType.Cylinder }, { Shape = Enum.PartType.Ball }
	local UP = CFrame.Angles(0, 0, math.pi / 2) -- a Cylinder's axis (X) turned upright
	local ghost = { CanCollide = false, CanQuery = false, CastShadow = false }

	-- frontier props, each at a ground CFrame (Y on the ground, LookVector = front)
	local function crate(p: Instance, cf: CFrame, s: number)
		block(p, "Crate", Vector3.new(s, s, s), cf * CFrame.new(0, s / 2, 0), PLANK, M.Wood)
		block(
			p,
			"CrateBand",
			Vector3.new(s + 0.1, s * 0.18, s + 0.1),
			cf * CFrame.new(0, s / 2, 0),
			DARK,
			M.Wood
		)
	end
	local function barrel(p: Instance, cf: CFrame)
		block(
			p,
			"Barrel",
			Vector3.new(3, 2.4, 2.4),
			cf * CFrame.new(0, 1.5, 0) * UP,
			DARK,
			M.Wood,
			CYL
		)
	end
	local function rope(p: Instance, cf: CFrame)
		block(
			p,
			"Rope",
			Vector3.new(0.6, 2.6, 2.6),
			cf * CFrame.new(0, 0.3, 0) * UP,
			rgb(196, 168, 118),
			M.Fabric,
			CYL
		)
	end
	local function lantern(p: Instance, cf: CFrame, lit: boolean?)
		block(p, "LanternPost", Vector3.new(0.4, 6, 0.4), cf * CFrame.new(0, 3, 0), DARK, M.Wood)
		block(
			p,
			"LanternArm",
			Vector3.new(0.3, 0.3, 1.4),
			cf * CFrame.new(0, 5.8, -0.6),
			DARK,
			M.Wood
		)
		local head = block(
			p,
			"Lantern",
			Vector3.new(0.8, 1, 0.8),
			cf * CFrame.new(0, 5.1, -1.2),
			rgb(255, 196, 120),
			M.Neon,
			ghost
		)
		if lit then
			local light = Instance.new("PointLight")
			light.Range = 18
			light.Brightness = 1.3
			light.Color = rgb(255, 190, 130)
			light.Shadows = false
			light.Parent = head
		end
	end
	-- an A-frame canvas tent, ridge along LookVector, open at both ends
	local function tent(p: Instance, cf: CFrame, w: number, d: number, h: number, colour: Color3)
		local slope = math.sqrt((w / 2) ^ 2 + h ^ 2)
		for _, s in { -1, 1 } do
			block(
				p,
				"Canvas",
				Vector3.new(slope, 0.2, d),
				cf
					* CFrame.new(s * w / 4, h / 2, 0)
					* CFrame.Angles(0, 0, math.atan2(h, -s * w / 2)),
				colour,
				M.Fabric
			)
		end
		block(
			p,
			"Ridge",
			Vector3.new(d + 1, 0.3, 0.3),
			cf * CFrame.new(0, h, 0) * CFrame.Angles(0, math.pi / 2, 0),
			DARK,
			M.Wood,
			CYL
		)
		for _, z in { -d / 2, d / 2 } do
			block(
				p,
				"TentPole",
				Vector3.new(0.3, h, 0.3),
				cf * CFrame.new(0, h / 2, z),
				DARK,
				M.Wood
			)
		end
	end
	-- a timber deck `hgt` high on four posts
	local function deck(p: Instance, cf: CFrame, w: number, d: number, hgt: number)
		block(p, "Deck", Vector3.new(w, 0.6, d), cf * CFrame.new(0, hgt - 0.3, 0), PLANK, M.Wood)
		for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			local px, pz = c[1] * (w / 2 - 0.5), c[2] * (d / 2 - 0.5)
			block(
				p,
				"Post",
				Vector3.new(0.9, hgt + 2, 0.9),
				cf * CFrame.new(px, hgt / 2 - 1, pz),
				DARK,
				M.Wood
			)
		end
	end
	local function bollard(p: Instance, cf: CFrame)
		block(p, "Bollard", Vector3.new(1.4, 2.4, 1.4), cf * CFrame.new(0, 1.2, 0), DARK, M.Wood)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.TopSurface = SMOOTH
	spawn.BottomSurface = SMOOTH
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = H.Hub.spawn + Vector3.new(0, -0.35, 0)
	spawn.Color = PLANK
	spawn.Material = M.Wood
	spawn.Parent = hub

	-- the HQ: a lookout hut on a timber deck, the radio on a desk inside, a lookout tower with a ladder beside it
	local hq = H.Hub.lots.HQ.cframe
	local look = folder(hub, "Lookout", "Model")
	deck(look, hq, 24, 20, 1)
	local hut = hq * CFrame.new(-4, 1, 2)
	local HW, HD, HH = 12, 9, 8
	block(
		look,
		"WallBack",
		Vector3.new(HW, HH, 0.6),
		hut * CFrame.new(0, HH / 2, HD / 2),
		TIMBER,
		M.Wood
	)
	for _, s in { -1, 1 } do
		block(
			look,
			"WallSide",
			Vector3.new(0.6, HH, HD),
			hut * CFrame.new(s * HW / 2, HH / 2, 0),
			TIMBER,
			M.Wood
		)
		block(
			look,
			"WallFront",
			Vector3.new(4, HH, 0.6),
			hut * CFrame.new(s * 4, HH / 2, -HD / 2),
			TIMBER,
			M.Wood
		)
	end
	block(
		look,
		"Lintel",
		Vector3.new(4, 1.6, 0.6),
		hut * CFrame.new(0, HH - 0.8, -HD / 2),
		TIMBER,
		M.Wood
	)
	tent(
		look,
		hut * CFrame.new(0, HH, 0) * CFrame.Angles(0, math.pi / 2, 0),
		HD + 2,
		HW + 2,
		3.5,
		NAVY
	)
	block(
		look,
		"LifeRing",
		Vector3.new(0.5, 2.6, 2.6),
		hut * CFrame.new(4, 4.5, -HD / 2 - 0.4) * CFrame.Angles(0, math.pi / 2, 0),
		ORANGE,
		M.SmoothPlastic,
		CYL
	)
	block(
		look,
		"RadioDesk",
		Vector3.new(6, 2.8, 2.4),
		hut * CFrame.new(0, 1.4, HD / 2 - 1.6),
		PLANK,
		M.Wood
	)
	local radio = block(
		look,
		"Radio",
		Vector3.new(2.4, 1.3, 1.4),
		hut * CFrame.new(-0.6, 3.45, HD / 2 - 1.6),
		IRON,
		M.Metal
	)
	radio:AddTag("StationRadio")
	block(
		look,
		"RadioDial",
		Vector3.new(1.6, 0.5, 0.1),
		hut * CFrame.new(-0.6, 3.5, HD / 2 - 2.35),
		rgb(90, 255, 140),
		M.Neon,
		ghost
	)
	block(
		look,
		"RadioMast",
		Vector3.new(0.12, 2.4, 0.12),
		hut * CFrame.new(0.4, 5, HD / 2 - 1.2),
		IRON,
		M.Metal,
		ghost
	)
	lantern(look, hut * CFrame.new(-HW / 2 - 1.6, 0, -HD / 2 - 1), true)
	local tower = hq * CFrame.new(7, 1, 3)
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		block(
			look,
			"TowerLeg",
			Vector3.new(0.9, 19, 0.9),
			tower * CFrame.new(c[1] * 3, 9.5, c[2] * 3),
			DARK,
			M.Wood
		)
	end
	block(look, "TowerFloor", Vector3.new(8, 0.6, 8), tower * CFrame.new(0, 16, 0), PLANK, M.Wood)
	for _, s in { -1, 1 } do
		block(
			look,
			"TowerRail",
			Vector3.new(8, 0.3, 0.3),
			tower * CFrame.new(0, 17.4, s * 3.85),
			DARK,
			M.Wood
		)
		block(
			look,
			"TowerRail",
			Vector3.new(0.3, 0.3, 8),
			tower * CFrame.new(s * 3.85, 17.4, 0),
			DARK,
			M.Wood
		)
	end
	tent(look, tower * CFrame.new(0, 19, 0), 9, 9, 2.4, NAVY)
	local ladder = Instance.new("TrussPart")
	ladder.Name = "Ladder"
	ladder.Anchored = true
	ladder.Size = Vector3.new(2, 16, 2)
	ladder.CFrame = tower * CFrame.new(0, 8, -5)
	ladder.Color = DARK
	ladder.Material = M.Wood
	ladder.Parent = look
	block(
		look,
		"FlagPole",
		Vector3.new(0.4, 10, 0.4),
		tower * CFrame.new(3, 24, 3),
		rgb(236, 236, 230)
	)
	block(
		look,
		"Flag",
		Vector3.new(5, 3.2, 0.05),
		tower * CFrame.new(5.6, 27.2, 3),
		ORANGE,
		M.Fabric,
		ghost
	)
	crate(look, hq * CFrame.new(-9.5, 1, -7), 2.6)
	crate(look, hq * CFrame.new(-7, 1, -8), 2)
	rope(look, hq * CFrame.new(3, 1, -7))

	-- the quay: a timber landing stage at the harbour head, bulkheads down both harbour walls, bollards
	local quay = folder(hub, "Quay", "Model")
	local notch = H.Notch.hub
	local hw = notch.halfWidth
	block(
		quay,
		"Stage",
		Vector3.new(hw * 2 + 12, 1, 12),
		at(0, notch.head - 6, -0.5),
		PLANK,
		M.Wood
	)
	block(
		quay,
		"Bulkhead",
		Vector3.new(hw * 2 + 4, 6, 1.2),
		at(0, notch.head - 0.4, -3),
		DARK,
		M.Wood
	)
	for _, s in { -1, 1 } do
		local len = H.HubRadius - notch.head - 14
		block(
			quay,
			"BulkheadSide",
			Vector3.new(1.2, 6, len),
			at(s * (hw + 0.6), notch.head + len / 2, -3),
			DARK,
			M.Wood
		)
		for k = 0, 2 do
			bollard(quay, at(s * (hw + 2.5), notch.head + 20 + k * 26))
		end
	end
	-- the drop-off berth: two bollards and a green band on the stage edge at the harbour head (the pad's colour)
	bollard(quay, at(-12, notch.head - 3))
	bollard(quay, at(12, notch.head - 3))
	block(
		quay,
		"DropOffBand",
		Vector3.new(20, 0.08, 1.6),
		at(0, notch.head - 1, 0.04),
		COLORS.dropoff,
		M.SmoothPlastic,
		ghost
	)
	block(
		quay,
		"RingPost",
		Vector3.new(0.4, 5, 0.4),
		at(hw - 6, notch.head - 4, 2.5),
		rgb(236, 236, 230)
	)
	block(
		quay,
		"LifeRing",
		Vector3.new(0.6, 3, 3),
		at(hw - 6, notch.head - 3.6, 3.6, 90),
		ORANGE,
		M.SmoothPlastic,
		CYL
	)
	lantern(quay, at(-hw + 4, notch.head - 9, 0, 180), true)
	crate(quay, at(-hw - 4, notch.head - 10), 2.4)
	barrel(quay, at(-hw - 7, notch.head - 7))

	-- the visitor jetty: a plank deck on piles along the east harbour wall
	local jl = H.Hub.lots.Jetty
	local jetty = folder(hub, "Jetty", "Model")
	local jw, jd = jl.size.X, jl.size.Y
	block(jetty, "Deck", Vector3.new(jw, 1, jd), jl.cframe * CFrame.new(0, -0.5, 0), PLANK, M.Wood)
	for z = -jd / 2 + 2, jd / 2 - 2, 12 do
		for _, s in { -1, 1 } do
			block(
				jetty,
				"Pile",
				Vector3.new(1, 16, 1),
				jl.cframe * CFrame.new(s * (jw / 2 - 0.3), -7, z),
				DARK,
				M.Wood
			)
		end
	end
	bollard(jetty, jl.cframe * CFrame.new(-jw / 2 + 1, 0, -jd / 2 + 2))
	bollard(jetty, jl.cframe * CFrame.new(jw / 2 - 1, 0, -jd / 2 + 2))
	lantern(jetty, jl.cframe * CFrame.new(jw / 2 - 1, 0, -jd / 2 + 5), true)

	-- call board: a framed noticeboard on two posts, the call icon on its face, pinned notes
	local cbf = H.Hub.lots.CallBoard.cframe
	local board = folder(hub, "CallBoard", "Model")
	board:AddTag("CallBoard")
	for _, x in { -5.4, 5.4 } do
		block(
			board,
			"Post",
			Vector3.new(0.6, 9, 0.6),
			cbf * CFrame.new(x, 4.5, 0),
			COLORS.wood,
			M.Wood
		)
	end
	block(
		board,
		"Board",
		Vector3.new(10.4, 6, 0.5),
		cbf * CFrame.new(0, 5.6, 0),
		rgb(176, 132, 84),
		M.Wood
	)
	block(board, "Header", Vector3.new(11, 1.2, 0.7), cbf * CFrame.new(0, 9.1, 0), COLORS.red)
	block(board, "Cap", Vector3.new(12, 0.4, 1.6), cbf * CFrame.new(0, 9.9, 0), COLORS.roof)
	local icon = block(
		board,
		"Icon",
		Vector3.new(3.6, 3.6, 0.1),
		cbf * CFrame.new(-2.6, 5.6, -0.3),
		COLORS.white,
		M.SmoothPlastic,
		{ CanCollide = false }
	)
	decal(icon, ui.Hud.MissionPiw, Enum.NormalId.Front)
	for i, note in { { 1.2, 6.6, -6 }, { 3.6, 6.2, 5 }, { 1.6, 4.2, 3 }, { 3.8, 4.0, -4 } } do
		block(
			board,
			"Note",
			Vector3.new(1.8, 2.2, 0.05),
			cbf * CFrame.new(note[1], note[2], -0.28) * CFrame.Angles(0, 0, math.rad(note[3])),
			if i % 2 == 0 then COLORS.white else COLORS.glass,
			M.SmoothPlastic,
			{ CanCollide = false }
		)
	end

	-- the market stall: a counter under a striped canvas awning on a timber frame, the Store icon over it; crates
	-- of stock round it. The counter's prompt opens the phone Store
	local sc = H.Hub.lots.ShopCounter
	local scf = sc.cframe
	local shop = folder(hub, "ShopCounter", "Model")
	local sw, sd = sc.size.X, sc.size.Y
	local counter = block(
		shop,
		"Counter",
		Vector3.new(sw - 4, 3.6, 2.4),
		scf * CFrame.new(0, 1.8, -sd / 2 + 1.6),
		PLANK,
		M.Wood
	)
	block(
		shop,
		"CounterTop",
		Vector3.new(sw - 3, 0.3, 3),
		scf * CFrame.new(0, 3.75, -sd / 2 + 1.6),
		DARK,
		M.Wood
	)
	block(
		shop,
		"Back",
		Vector3.new(sw, 9, 0.8),
		scf * CFrame.new(0, 4.5, sd / 2 - 0.4),
		TIMBER,
		M.Wood
	)
	for _, s in { -1, 1 } do
		block(
			shop,
			"Post",
			Vector3.new(0.7, 10, 0.7),
			scf * CFrame.new(s * (sw / 2 - 0.4), 5, -sd / 2 + 0.4),
			DARK,
			M.Wood
		)
		block(
			shop,
			"Post",
			Vector3.new(0.7, 10, 0.7),
			scf * CFrame.new(s * (sw / 2 - 0.4), 5, sd / 2 - 0.4),
			DARK,
			M.Wood
		)
	end
	for k = 0, 4 do
		block(
			shop,
			"Awning",
			Vector3.new(sw / 5, 0.3, sd + 3),
			scf
				* CFrame.new(-sw / 2 + sw / 10 + k * sw / 5, 10, -1.5)
				* CFrame.Angles(math.rad(-12), 0, 0),
			if k % 2 == 0 then CANVAS else COLORS.red,
			M.Fabric
		)
	end
	local sign = block(
		shop,
		"Sign",
		Vector3.new(5, 5, 0.3),
		scf * CFrame.new(0, 7, sd / 2 - 1),
		COLORS.white
	)
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
	crate(shop, scf * CFrame.new(-sw / 2 - 2.5, 0, 1), 3)
	crate(shop, scf * CFrame.new(-sw / 2 - 2.2, 3, 1.2) * CFrame.Angles(0, 0.4, 0), 2)
	barrel(shop, scf * CFrame.new(sw / 2 + 2.4, 0, 2))
	rope(shop, scf * CFrame.new(sw / 2 + 2.2, 0, -2.4))
	lantern(shop, scf * CFrame.new(-sw / 2 - 1.2, 0, -sd / 2 - 1.5), true)

	-- the harbourmaster's shack on the west quay: plank walls, a lean-to roof, the door to the harbour, and the
	-- storm-signal mast (a black ball on the yard: storms come from here)
	local hm = H.Hub.lots.Harbourmaster.cframe
	local shack = folder(hub, "Harbourmaster", "Model")
	local SW, SD, SH = 12, 9, 8
	block(
		shack,
		"WallBack",
		Vector3.new(SW, SH, 0.6),
		hm * CFrame.new(0, SH / 2, SD / 2),
		TIMBER,
		M.Wood
	)
	for _, s in { -1, 1 } do
		block(
			shack,
			"WallSide",
			Vector3.new(0.6, SH, SD),
			hm * CFrame.new(s * SW / 2, SH / 2, 0),
			TIMBER,
			M.Wood
		)
		block(
			shack,
			"WallFront",
			Vector3.new(4, SH, 0.6),
			hm * CFrame.new(s * 4, SH / 2, -SD / 2),
			TIMBER,
			M.Wood
		)
	end
	block(
		shack,
		"Lintel",
		Vector3.new(4, 1.6, 0.6),
		hm * CFrame.new(0, SH - 0.8, -SD / 2),
		TIMBER,
		M.Wood
	)
	block(
		shack,
		"Roof",
		Vector3.new(SW + 2, 0.5, SD + 3),
		hm * CFrame.new(0, SH + 0.7, -0.5) * CFrame.Angles(math.rad(-10), 0, 0),
		DARK,
		M.Wood
	)
	local mast = hm * CFrame.new(SW / 2 + 4, 0, -SD / 2 - 2)
	block(shack, "Mast", Vector3.new(0.6, 22, 0.6), mast * CFrame.new(0, 11, 0), rgb(236, 236, 230))
	block(shack, "Yard", Vector3.new(7, 0.4, 0.4), mast * CFrame.new(0, 19, 0), DARK, M.Wood)
	block(
		shack,
		"StormBall",
		Vector3.new(2.6, 2.6, 2.6),
		mast * CFrame.new(-2.6, 16.6, 0),
		rgb(20, 20, 22),
		M.Fabric,
		BALL
	)
	barrel(shack, hm * CFrame.new(-SW / 2 - 2, 0, -2))
	barrel(shack, hm * CFrame.new(-SW / 2 - 2.2, 0, 1))
	rope(shack, hm * CFrame.new(3, 0, -SD / 2 - 3))
	crate(shack, hm * CFrame.new(-2, 0, -SD / 2 - 3.5), 2.4)
	lantern(shack, hm * CFrame.new(-SW / 2 - 0.5, 0, -SD / 2 - 1.5), true)

	-- the campfire: a stone ring, crossed logs and a flame, log benches round it, a small plank stage behind
	local cf = H.Hub.lots.Campfire.cframe
	local camp = folder(hub, "Campfire", "Model")
	for k = 0, 9 do
		local a = k * math.pi / 5
		block(
			camp,
			"FireStone",
			Vector3.new(1.6, 1.1, 1.4),
			cf * CFrame.new(math.cos(a) * 3.2, 0.5, math.sin(a) * 3.2) * CFrame.Angles(0, -a, 0),
			STONE,
			M.Granite
		)
	end
	for _, a in { 0.4, 2.0 } do
		block(
			camp,
			"FireLog",
			Vector3.new(4.4, 0.8, 0.8),
			cf * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, a, 0),
			DARK,
			M.Wood,
			CYL
		)
	end
	local flame = block(
		camp,
		"Flame",
		Vector3.new(1.6, 2.2, 1.6),
		cf * CFrame.new(0, 1.6, 0),
		rgb(255, 140, 40),
		M.Neon,
		{ CanCollide = false, CanQuery = false, CastShadow = false, Transparency = 0.25 }
	)
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 6
	fire.Parent = flame
	local glow = Instance.new("PointLight")
	glow.Range = 28
	glow.Brightness = 1.6
	glow.Color = rgb(255, 160, 80)
	glow.Shadows = false
	glow.Parent = flame
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		block(
			camp,
			"LogBench",
			Vector3.new(6, 1.4, 1.4),
			cf
				* CFrame.new(math.cos(a) * 8, 0.6, math.sin(a) * 8)
				* CFrame.Angles(0, -a + math.pi / 2, 0),
			TIMBER,
			M.Wood,
			CYL
		)
	end
	local stage = cf * CFrame.new(0, 0, 12)
	deck(camp, stage, 16, 8, 2)
	for _, s in { -1, 1 } do
		block(
			camp,
			"BackdropPost",
			Vector3.new(0.6, 9, 0.6),
			stage * CFrame.new(s * 7.6, 4.5, 3.6),
			DARK,
			M.Wood
		)
		lantern(camp, stage * CFrame.new(s * 9.5, 0, -3) * CFrame.Angles(0, math.pi, 0), s == 1)
	end
	block(
		camp,
		"Backdrop",
		Vector3.new(15, 5, 0.2),
		stage * CFrame.new(0, 6.4, 3.6),
		CANVAS,
		M.Fabric
	)

	-- the rescuer monument: a bronze coastguard on a granite plinth; LeaderboardService hangs the board on the posts
	-- to its right, the album stamp post stands by the trail in
	local mf = H.Hub.lots.Monument.cframe
	local mon = folder(hub, "Monument", "Model")
	local statue = mf * CFrame.new(-5, 0, 0)
	local BRONZE = rgb(140, 108, 60)
	block(mon, "Plinth", Vector3.new(5, 2.4, 5), statue * CFrame.new(0, 1.2, 0), STONE, M.Granite)
	block(
		mon,
		"PlinthCap",
		Vector3.new(5.6, 0.4, 5.6),
		statue * CFrame.new(0, 2.6, 0),
		rgb(150, 146, 136),
		M.Granite
	)
	block(mon, "Legs", Vector3.new(1.8, 3.2, 1.1), statue * CFrame.new(0, 4.4, 0), BRONZE, M.Metal)
	block(mon, "Body", Vector3.new(2.4, 2.8, 1.3), statue * CFrame.new(0, 7.4, 0), BRONZE, M.Metal)
	block(
		mon,
		"Head",
		Vector3.new(1.4, 1.4, 1.4),
		statue * CFrame.new(0, 9.5, 0),
		BRONZE,
		M.Metal,
		BALL
	)
	block(
		mon,
		"Arm",
		Vector3.new(0.6, 3, 0.6),
		statue * CFrame.new(1.6, 9.4, -0.3) * CFrame.Angles(math.rad(-15), 0, math.rad(-20)),
		BRONZE,
		M.Metal
	)
	block(
		mon,
		"Lamp",
		Vector3.new(0.8, 1, 0.8),
		statue * CFrame.new(2.2, 11.2, -0.7),
		rgb(255, 196, 120),
		M.Neon,
		ghost
	)
	for _, x in { -7.2, 7.2 } do
		block(
			mon,
			"BoardPost",
			Vector3.new(0.7, 10.6, 0.7),
			mf * CFrame.new(5 + x, 5.3, 2.5),
			DARK,
			M.Wood
		)
	end
	local stamp = H.Hub.clearings.Monument.center + Vector3.new(-12, 0, 8)
	local post = folder(mon, "StampPost", "Model")
	post:SetAttribute("Island", "Hub")
	post:AddTag("StampPost")
	block(
		post,
		"Post",
		Vector3.new(1.2, 3.6, 1.2),
		CFrame.new(stamp + Vector3.new(0, 1.8, 0)),
		STONE,
		M.Granite
	)
	block(
		post,
		"Plate",
		Vector3.new(1.6, 0.2, 1.4),
		CFrame.new(stamp + Vector3.new(0, 3.7, 0)) * CFrame.Angles(math.rad(25), 0, 0),
		BRONZE,
		M.Metal
	)

	-- quest camps (WP-21b puts an NPC at each spot's cframe): a tent behind the spot, a crate, a barrel, a lantern
	local camps = folder(hub, "QuestCamps")
	for i, q in H.Hub.questSpots do
		local m = folder(camps, `QuestCamp_{q.id}`, "Model")
		m:SetAttribute("QuestSpot", q.id)
		m:AddTag("QuestCamp")
		local c = q.cframe
		tent(m, c * CFrame.new(0, 0, 7), 7, 8, 5, ({ CANVAS, OLIVE, BRICKRED })[i % 3 + 1])
		crate(m, c * CFrame.new(4.5, 0, 3) * CFrame.Angles(0, 0.3, 0), 2.4)
		barrel(m, c * CFrame.new(-4.5, 0, 3.5))
		lantern(m, c * CFrame.new(-3, 0, -2), false)
		rope(m, c * CFrame.new(3, 0, -1))
	end

	-- the hidden spots: a ruined chapel on the west hill's crown, an old wreck grown over in the north-east trees
	local ruin = folder(hub, "Ruin", "Model")
	local rc = CFrame.new(H.Hub.clearings.Ruin.center) * CFrame.Angles(0, math.rad(20), 0)
	local MOSS = rgb(78, 104, 52)
	for _, w in
		{
			{ 0, -7, 14, 5.5, 0 },
			{ -7, 0, 1.4, 7, 14 },
			{ 7, 1, 1.4, 3.5, 12 },
			{ 3, 7, 8, 2.5, 0 },
		}
	do
		local size = if w[5] > 0
			then Vector3.new(w[3], w[4], w[5])
			else Vector3.new(w[3], w[4], 1.4)
		local wcf = rc * CFrame.new(w[1], w[4] / 2 - 0.4, w[2])
		block(ruin, "Wall", size, wcf, STONE, M.Granite)
		block(
			ruin,
			"Moss",
			Vector3.new(size.X + 0.2, 0.4, size.Z + 0.2),
			wcf * CFrame.new(0, w[4] / 2, 0),
			MOSS,
			M.Grass
		)
	end
	for _, s in { -1, 1 } do
		block(
			ruin,
			"Pillar",
			Vector3.new(1.6, 9, 1.6),
			rc * CFrame.new(s * 2.6, 4.1, -7),
			STONE,
			M.Granite
		)
	end
	block(ruin, "Lintel", Vector3.new(7, 1.4, 1.6), rc * CFrame.new(0, 9.2, -7), STONE, M.Granite)
	block(
		ruin,
		"Fallen",
		Vector3.new(1.6, 7, 1.6),
		rc * CFrame.new(-2, 0.6, 3) * CFrame.Angles(math.rad(84), 0.5, 0),
		STONE,
		M.Granite
	)
	for _, b in { { 4, 3, 1.4 }, { -4, -3, 1.1 }, { 1, 4.5, 0.9 } } do
		block(
			ruin,
			"Rubble",
			Vector3.new(b[3] * 2, b[3], b[3] * 1.6),
			rc * CFrame.new(b[1], b[3] / 2 - 0.2, b[2]) * CFrame.Angles(0, b[1], 0.2),
			STONE,
			M.Granite
		)
	end

	local wreck = folder(hub, "Wreck", "Model")
	local WRECK = rgb(92, 76, 60)
	local wc = CFrame.new(H.Hub.clearings.Wreck.center)
		* CFrame.Angles(0, math.rad(-35), math.rad(14))
	block(wreck, "Keel", Vector3.new(2.4, 2, 30), wc * CFrame.new(0, 0.6, 0), DARK, M.Wood)
	for _, s in { -1, 1 } do
		block(
			wreck,
			"Strake",
			Vector3.new(0.8, 5, 26),
			wc * CFrame.new(s * 3.4, 2.8, -1) * CFrame.Angles(0, 0, s * math.rad(-22)),
			WRECK,
			M.Wood
		)
	end
	for z = -10, 10, 4 do
		for _, s in { -1, 1 } do
			block(
				wreck,
				"Rib",
				Vector3.new(0.6, 7, 0.6),
				wc * CFrame.new(s * 3.6, 4, z) * CFrame.Angles(0, 0, s * math.rad(-26)),
				DARK,
				M.Wood
			)
		end
	end
	block(
		wreck,
		"Stem",
		Vector3.new(1.2, 8, 1.2),
		wc * CFrame.new(0, 4, -15) * CFrame.Angles(math.rad(-20), 0, 0),
		DARK,
		M.Wood
	)
	block(
		wreck,
		"MastStump",
		Vector3.new(1.4, 7, 1.4),
		wc * CFrame.new(0, 4.5, 2) * CFrame.Angles(math.rad(12), 0, 0),
		WRECK,
		M.Wood
	)
	for _, g in { { -2.6, 3.2, 6, 3.4 }, { 3, 2.6, -6, 2.8 }, { 0, 1.8, 12, 3.6 } } do
		block(
			wreck,
			"Overgrowth",
			Vector3.new(g[4], g[4], g[4]),
			wc * CFrame.new(g[1], g[2], g[3]),
			MOSS,
			M.Grass,
			BALL
		)
	end

	-- the hub drop-off pad, in the harbour off the landing stage
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
