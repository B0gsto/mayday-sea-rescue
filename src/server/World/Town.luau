--!strict
-- Town: the cities of WorldConfig.Towns (tools/world/layout.py TOWNS), built at server start by WorldDressingService:
--   Town.paint()      synchronous, before Street.start: terrain tints (TINT, naturalGround island-wide in the
--                     background), terrain under each town's grid roads -> Asphalt, a
--                     `footway` band each side -> Concrete (pavement + parking strip), block interiors -> plain Grass
--                     (the bake's straw / heath / olive turf dither read as snow patches in town)
--   Town.place(base)  Workspace.Dressing.Town.<id>: one Atomic M_Bld_Cottage_0n per TownLayout lot (render colour
--                     on the Walls via the "Render" attribute + CottageRig: lit windows, chimney smoke), _COL hull
--                     on; a lot whose ground is not level within 1.5 studs is skipped (never on a slope). Lots
--                     with `floors` are code-built TownBuildings terraces (on a plinth: slopes to 8 studs), plus
--                     the TownLayout.LANDMARKS (hotel, customs house, market hall); gardens get outshuts, washing
--                     lines and trees; the residential blocks a gravel back lane.
-- Grid roads are axis-aligned, so Region3 repaints are exact. shortcut: a rotated town needs per-segment wedges.
-- Every non-shop lot gets a walled front garden (frontGarden); "gap" lots are all garden.
-- Folder attributes: TownCottages, TownTerraces, TownSkipped, TownGardens, TownGaps.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AssetLoader = require(script.Parent.Parent:WaitForChild("Assets"):WaitForChild("AssetLoader"))
local CottageRig = require(script.Parent:WaitForChild("CottageRig"))
local StreetFurniture = require(script.Parent:WaitForChild("StreetFurniture"))
local Swaps = require(script.Parent:WaitForChild("Swaps"))
local TownBuildings = require(script.Parent:WaitForChild("TownBuildings"))
local TownLayout = require(script.Parent:WaitForChild("TownLayout"))
local WorldConfig = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("WorldConfig")
)

local Town = {}

local SOFT = {
	Enum.Material.Grass,
	Enum.Material.LeafyGrass,
	Enum.Material.Snow, -- TurfStraw slot
	Enum.Material.WoodPlanks, -- TurfOlive slot
	Enum.Material.Ground,
	Enum.Material.Mud,
	Enum.Material.Pavement,
	Enum.Material.Brick, -- TurfWorn slot
}

local function replace(x0: number, z0: number, x1: number, z1: number, y: number, to: Enum.Material)
	local region = Region3.new(
		Vector3.new(math.min(x0, x1), y - 8, math.min(z0, z1)),
		Vector3.new(math.max(x0, x1), y + 4, math.max(z0, z1))
	):ExpandToGrid(4)
	for _, from in SOFT do
		if from ~= to then
			Workspace.Terrain:ReplaceMaterial(region, 4, from, to)
		end
	end
end

local function townRoads(id: string): { any }
	local out = {}
	for _, r in WorldConfig.Roads do
		if (r :: any).town == id then
			table.insert(out, r)
		end
	end
	return out
end

-- Terrain draws the built-in materials (MaterialService has no terrain slot overrides: the live client failed to load
-- those variants and drew flat MaterialColors, white town ground). These tints make them read: dark asphalt, light grey
-- pavement, real grass. The bake's off-label slots (Snow = straw turf, WoodPlanks = olive turf, Brick = worn turf,
-- Glacier / Ice = dune / wrack sand, Sandstone = wet sand) would show planks, bricks and ice, so naturalGround()
-- repaints them island-wide.
local TINT: { [string]: { number } } = {
	Asphalt = { 62, 64, 68 },
	Concrete = { 176, 174, 168 },
	Pavement = { 150, 146, 136 },
	Cobblestone = { 128, 122, 112 },
	Grass = { 100, 118, 64 }, -- olive, not lawn green
	LeafyGrass = { 116, 120, 70 }, -- clover / weed patches (Town.paint)
	Ground = { 110, 96, 70 },
	Mud = { 74, 60, 46 },
	Sand = { 205, 187, 148 }, -- warm Cornish sand (#CDBB94)
	Sandstone = { 168, 150, 114 },
	Salt = { 176, 160, 124 },
	Limestone = { 165, 158, 140 },
	Rock = { 112, 114, 116 },
	Slate = { 88, 92, 92 },
	Basalt = { 68, 68, 72 },
	CrackedLava = { 100, 96, 90 },
	-- until naturalGround() reaches them: their replacement's tint
	Snow = { 122, 128, 74 },
	WoodPlanks = { 100, 118, 64 },
	Brick = { 110, 96, 70 },
	Glacier = { 205, 187, 148 },
	Ice = { 205, 187, 148 },
}
local NATURAL: { [Enum.Material]: Enum.Material } = {
	[Enum.Material.Snow] = Enum.Material.LeafyGrass,
	[Enum.Material.WoodPlanks] = Enum.Material.Grass,
	[Enum.Material.Brick] = Enum.Material.Ground,
	[Enum.Material.Glacier] = Enum.Material.Sand,
	[Enum.Material.Ice] = Enum.Material.Sand,
	[Enum.Material.Sandstone] = Enum.Material.Sand,
}

local function naturalGround()
	local half, tile = WorldConfig.Terrain.halfExtent, 256
	local tiles = {}
	for x = -half, half - 1, tile do
		for z = -half, half - 1, tile do
			table.insert(tiles, Vector2.new(x, z))
		end
	end
	-- nearest the town first
	table.sort(tiles, function(a, b)
		return a.Magnitude < b.Magnitude
	end)
	for _, t in tiles do
		-- beaches and land only (Y -40..232); about 280k voxels a call
		local region =
			Region3.new(Vector3.new(t.X, -40, t.Y), Vector3.new(t.X + tile, 232, t.Y + tile))
		for from, to in NATURAL do
			Workspace.Terrain:ReplaceMaterial(region, 4, from, to)
		end
		task.wait()
	end
end

function Town.paint()
	for name, c in TINT do
		Workspace.Terrain:SetMaterialColor(
			(Enum.Material :: any)[name],
			Color3.fromRGB(c[1], c[2], c[3])
		)
	end
	task.spawn(naturalGround)
	-- the bake's verge gravel smears onto the station forecourt (x -212..12): pave it
	Workspace.Terrain:ReplaceMaterial(
		Region3.new(Vector3.new(-212, -4, -100), Vector3.new(12, 8, -20)):ExpandToGrid(4),
		4,
		Enum.Material.Pavement,
		Enum.Material.Concrete
	)
	-- boatyard (x -310..-230): smooth terrain renders the baked Y 4 ground about 2 studs high and over the quay wall;
	-- clear it above the apron (Y 6) and above sea level seaward of the quay line (z 4)
	Workspace.Terrain:FillBlock(
		CFrame.new(-280, 14, -12),
		Vector3.new(100, 16, 32),
		Enum.Material.Air
	)
	Workspace.Terrain:FillBlock(
		CFrame.new(-280, 11, 17),
		Vector3.new(100, 22, 26),
		Enum.Material.Air
	)
	for _, town in WorldConfig.Towns do
		local y = town.origin.Y
		local _, zs = TownLayout.lines(town :: any)
		for _, b in TownLayout.blocks(town :: any) do
			replace(b[1], b[2], b[3], b[4], y, Enum.Material.Grass)
			for k = 1, 4 do -- clover and weed patches: the mown grass is never one even green
				local u, v = TownLayout.hash(b[1] + k, b[2]), TownLayout.hash(b[3], b[4] + k)
				local px, pz = b[1] + u * (b[3] - b[1]), b[2] + v * (b[4] - b[2])
				local r = 4 + 6 * TownLayout.hash(px, pz)
				Workspace.Terrain:ReplaceMaterial(
					Region3.new(
						Vector3.new(px - r, y - 8, pz - r),
						Vector3.new(px + r, y + 4, pz + r)
					)
						:ExpandToGrid(4),
					4,
					Enum.Material.Grass,
					Enum.Material.LeafyGrass
				)
			end
			if b[4] < zs[2] then -- north of the first street: back-to-back gardens, a gravel back lane between
				local mid = (b[2] + b[4]) / 2
				replace(b[1] + 52, mid - 3, b[3] - 52, mid + 3, y, Enum.Material.Pavement)
			end
		end
		local passes: { { half: number, to: Enum.Material } } = {
			-- carriageway first: the footway pass then only reaches what is still soft
			{ half = town.width / 2, to = Enum.Material.Asphalt },
			{ half = town.width / 2 + town.footway, to = Enum.Material.Concrete },
		}
		-- the south road (Harbour Road) gets the same footways, so its lamps and parked cars stand on paving
		local paved = townRoads(town.id)
		for _, r in WorldConfig.Roads do
			if r.id == "HarbourRoad" then
				table.insert(paved, r)
			end
		end
		for _, pass in passes do
			for _, r in paved do
				for i = 1, #r.points - 1 do
					local a, b = r.points[i], r.points[i + 1]
					local h = pass.half
					replace(
						math.min(a.X, b.X) - h,
						math.min(a.Z, b.Z) - h,
						math.max(a.X, b.X) + h,
						math.max(a.Z, b.Z) + h,
						y,
						pass.to
					)
				end
			end
		end
		-- the bake's quayside setts (x -180..180, z -62..-20) covered the north half of Harbour Road with a voxel
		-- saw-tooth seam: asphalt the whole carriageway (2 studs past the kerb, under Street's footway band) and pave
		-- the forecourts behind it like the other footways
		for _, r in WorldConfig.Roads do
			if r.id == "HarbourRoad" then
				for i = 1, #r.points - 1 do
					local a, b = r.points[i], r.points[i + 1]
					local h = r.width / 2 + 2
					Workspace.Terrain:ReplaceMaterial(
						Region3.new(
							Vector3.new(math.min(a.X, b.X) - h, y - 8, math.min(a.Z, b.Z) - h),
							Vector3.new(math.max(a.X, b.X) + h, y + 4, -20) -- not the quay kit's setts (z -8..4)
						):ExpandToGrid(4),
						4,
						Enum.Material.Cobblestone,
						Enum.Material.Asphalt
					)
				end
			end
		end
		Workspace.Terrain:ReplaceMaterial(
			Region3.new(Vector3.new(-184, y - 8, -64), Vector3.new(184, y + 4, -20)):ExpandToGrid(4),
			4,
			Enum.Material.Cobblestone,
			Enum.Material.Concrete
		)
	end
end

-- the six Swaps cottages keep their lots (Ambient residents stand at their doors)
local function swapRects(): { TownLayout.Rect }
	local out: { TownLayout.Rect } = {}
	for key, spec in Swaps do
		if string.match(key, "^House%d$") then
			local p = spec.pivot.Position
			table.insert(out, { p.X - 14, p.Z - 9, p.X + 14, p.Z + 9 })
		end
	end
	return out
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { Workspace.Terrain }

-- the ground Y under the lot when it is level (smooth terrain renders the Y 4 platform near Y 6), else nil
local function level(lot: TownLayout.Lot, y: number): number?
	local r = lot.rect
	local lo, hi = math.huge, -math.huge
	for _, c in
		{
			{ r[1], r[2] },
			{ r[3], r[2] },
			{ r[1], r[4] },
			{ r[3], r[4] },
			{ (r[1] + r[3]) / 2, (r[2] + r[4]) / 2 },
		}
	do
		local hit =
			Workspace:Raycast(Vector3.new(c[1], y + 200, c[2]), Vector3.new(0, -400, 0), params)
		if not hit then
			return nil
		end
		lo, hi = math.min(lo, hit.Position.Y), math.max(hi, hit.Position.Y)
	end
	return if hi - lo <= 1.5 then hi else nil
end

-- the lowest and highest ground under a rect (corners + centre)
local function span(r: TownLayout.Rect, y: number): (number, number)
	local lo, hi = math.huge, -math.huge
	for _, c in
		{
			{ r[1], r[2] },
			{ r[3], r[2] },
			{ r[1], r[4] },
			{ r[3], r[4] },
			{ (r[1] + r[3]) / 2, (r[2] + r[4]) / 2 },
		}
	do
		local hit =
			Workspace:Raycast(Vector3.new(c[1], y + 200, c[2]), Vector3.new(0, -400, 0), params)
		local gy = if hit then hit.Position.Y else y
		lo, hi = math.min(lo, gy), math.max(hi, gy)
	end
	return lo, hi
end

local function ground(x: number, z: number, y: number): number
	local hit = Workspace:Raycast(Vector3.new(x, y + 200, z), Vector3.new(0, -400, 0), params)
	return if hit then hit.Position.Y else y
end

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	mat: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local STONE = Color3.fromRGB(138, 132, 120) -- Cornish granite walling
local SHED = Color3.fromRGB(96, 74, 52)
-- MaterialService overrides Slate / WoodPlanks / Concrete / Brick for terrain: Parts use Granite, Wood, RoofShingles
local SLATE = Color3.fromRGB(44, 48, 54)
local CLOTHES =
	{ Color3.fromRGB(230, 230, 236), Color3.fromRGB(60, 90, 150), Color3.fromRGB(196, 70, 64) }
-- garden: a granite back wall and one side wall; every third gets a timber shed in the back corner
local function garden(
	parent: Instance,
	n: number,
	g: TownLayout.Rect,
	lot: TownLayout.Lot,
	y: number
)
	local f = lot.face
	local cx, cz = (g[1] + g[3]) / 2, (g[2] + g[4]) / 2
	local alongX = f.X == 0 -- street rows: gardens run back in z, walls along x
	local w, d =
		if alongX then g[3] - g[1] else g[4] - g[2], if alongX then g[4] - g[2] else g[3] - g[1]
	local backDir = -f -- from the house toward the garden's far end
	local far = Vector3.new(cx, y, cz) + backDir * (d / 2 - 0.5)
	local yaw = if alongX then 0 else math.pi / 2
	part(
		parent,
		`Wall{n}`,
		Vector3.new(w, 3, 1),
		CFrame.new(far + Vector3.yAxis * 1.5) * CFrame.Angles(0, yaw, 0),
		STONE,
		Enum.Material.Granite
	)
	local side = Vector3.new(f.Z, 0, -f.X) -- along the row
	local sideAt = Vector3.new(cx, y + 1.5, cz) + side * (w / 2 - 0.5)
	part(
		parent,
		`Side{n}`,
		Vector3.new(1, 3, d),
		CFrame.new(sideAt) * CFrame.Angles(0, yaw, 0),
		STONE,
		Enum.Material.Granite
	)
	local wood = Color3.fromRGB(110, 92, 72)
	if n % 2 == 0 then -- a back extension (lean-to outshut) against the house on the far side from the shed
		local od = math.min(7, d - 1) -- outshut depth
		local at = Vector3.new(cx, y, cz) - backDir * (d / 2 - od / 2) + side * (w / 4)
		local rot = CFrame.Angles(0, math.atan2(-backDir.X, -backDir.Z), 0) -- local -Z = out into the garden
		part(
			parent,
			`Outshut{n}`,
			Vector3.new(w / 2 - 1, 8, od),
			CFrame.new(at + Vector3.yAxis * 4) * rot,
			lot.render == "White" and Color3.fromRGB(236, 232, 222) or Color3.fromRGB(218, 210, 192),
			Enum.Material.Plaster
		)
		local roof = Instance.new("WedgePart")
		roof.Name = `OutshutRoof{n}`
		roof.Anchored, roof.CanCollide, roof.CanQuery = true, false, false
		roof.Size = Vector3.new(w / 2 - 0.4, 2.6, od + 0.6)
		roof.CFrame = CFrame.new(at + Vector3.yAxis * 9.3) * rot
		roof.Color, roof.Material = SLATE, Enum.Material.RoofShingles
		roof.Parent = parent
		part(
			parent,
			`OutshutGlass{n}`,
			Vector3.new(3, 3.6, 0.2),
			CFrame.new(at + Vector3.yAxis * 4.6) * rot * CFrame.new(0, 0, -od / 2 - 0.05),
			Color3.fromRGB(38, 48, 58),
			Enum.Material.Glass
		)
	end
	if n % 4 == 1 then -- washing line across the garden: two posts, the line, three things pegged out
		local a = Vector3.new(cx, y, cz) + side * (w / 2 - 2.5)
		local b = Vector3.new(cx, y, cz) - side * (w / 2 - 2.5)
		for k, p in { a, b } do
			part(
				parent,
				`LinePost{n}_{k}`,
				Vector3.new(0.3, 6, 0.3),
				CFrame.new(p + Vector3.yAxis * 3),
				wood,
				Enum.Material.Wood
			)
		end
		part(
			parent,
			`Line{n}`,
			Vector3.new(0.06, 0.06, (a - b).Magnitude),
			CFrame.lookAt((a + b) / 2 + Vector3.yAxis * 5.8, a + Vector3.yAxis * 5.8),
			Color3.fromRGB(220, 220, 220),
			Enum.Material.SmoothPlastic
		)
		for k = 1, 3 do
			local at = b:Lerp(a, k / 4) + Vector3.yAxis * 4.7
			part(
				parent,
				`Washing{n}_{k}`,
				Vector3.new(1.8, 2.2, 0.08),
				CFrame.lookAt(at, at + backDir),
				CLOTHES[k],
				Enum.Material.Fabric
			)
		end
	end
	if n % 4 == 2 then -- a garden tree in the far corner
		local at = far - backDir * 3 + side * (w / 2 - 3)
		local trunk = part(
			parent,
			`Trunk{n}`,
			Vector3.new(9, 1, 1),
			CFrame.new(at + Vector3.yAxis * 4.5) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(84, 66, 50),
			Enum.Material.Wood
		)
		trunk.Shape = Enum.PartType.Cylinder
		for k, c in { { 0, 10, 0, 9 }, { 1.5, 12.5, -1, 6.5 } } do
			local crown = part(
				parent,
				`Crown{n}_{k}`,
				Vector3.one * c[4],
				CFrame.new(at + Vector3.new(c[1], c[2], c[3])),
				Color3.fromRGB(62, 94, 50),
				Enum.Material.Grass
			)
			crown.Shape = Enum.PartType.Ball
		end
	end
	if n % 3 == 0 and d >= 10 then
		local at = far - backDir * 4.5 - side * (w / 2 - 4.5)
		part(
			parent,
			`Shed{n}`,
			Vector3.new(6, 6, 7),
			CFrame.new(at + Vector3.yAxis * 3) * CFrame.Angles(0, yaw, 0),
			SHED,
			Enum.Material.Wood
		)
		part(
			parent,
			`ShedRoof{n}`,
			Vector3.new(7, 0.4, 8),
			CFrame.new(at + Vector3.yAxis * 6.3)
				* CFrame.Angles(0, yaw, 0)
				* CFrame.Angles(math.rad(8), 0, 0),
			SLATE,
			Enum.Material.RoofShingles
		)
	end
end

-- front gardens (TownLayout.FRONT between the pavement and the house): a granite wall or a Cornish hedge (stone
-- base, turf top) along the pavement with a painted gate opposite the door, a flagged path, a low party wall,
-- hydrangea / fuchsia shrubs, now and then a cabbage palm; `tree`: a street tree (outer rows, about one per 60
-- studs). A "gap" lot is all garden (pavement to the lot's back) with a tree. Parts go in the house's own Model
-- (`m`, Atomic) so they stream with it.
local HEDGE = Color3.fromRGB(84, 104, 56)
local LEAF = Color3.fromRGB(58, 84, 46)
local FLOWERS = {
	Color3.fromRGB(96, 124, 196), -- hydrangea blue
	Color3.fromRGB(214, 132, 176), -- hydrangea pink
	Color3.fromRGB(236, 234, 238), -- white
	Color3.fromRGB(176, 40, 66), -- fuchsia
	Color3.fromRGB(146, 120, 188), -- lavender
	LEAF,
}
local GATES = {
	Color3.fromRGB(236, 234, 226),
	Color3.fromRGB(34, 70, 52),
	Color3.fromRGB(30, 52, 86),
	Color3.fromRGB(96, 74, 52),
}
-- door x (asset local) of M_Bld_Cottage_01..06 (assets/fbx/*/attachments.json ATT_Door)
local COTTAGE_DOOR = { 0, 9, 4.8, 0, 2.16, 4.5 }

local function tree(m: Instance, at: Vector3, scale: number)
	local h = 9 * scale
	local trunk = part(
		m,
		"TreeTrunk",
		Vector3.new(h, 1.1 * scale, 1.1 * scale),
		CFrame.new(at + Vector3.yAxis * h / 2) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(84, 70, 56),
		Enum.Material.Wood
	)
	trunk.Shape = Enum.PartType.Cylinder
	local green = LEAF:Lerp(Color3.fromRGB(96, 116, 58), TownLayout.hash(at.X, at.Z))
	for k, c in { { 0, 1.1, 0, 9 }, { 1.8, 1.35, -1.2, 6.5 }, { -1.6, 1.25, 1.4, 6 } } do
		local crown = part(
			m,
			"TreeCrown",
			Vector3.one * c[4] * scale,
			CFrame.new(at + Vector3.new(c[1] * scale, h * c[2], c[3] * scale)),
			if k == 2 then green:Lerp(Color3.new(1, 1, 0.8), 0.08) else green,
			Enum.Material.Grass
		)
		crown.Shape = Enum.PartType.Ball
		crown.CanCollide = false
	end
end

-- a Cornish cabbage palm: a slim leaning trunk and a burst of strap leaves
local function palm(m: Instance, at: Vector3, n: number)
	local h = 7 + (n % 3)
	local lean = CFrame.new(at) * CFrame.Angles(math.rad(4 + n % 5), math.rad(n * 47), 0)
	local trunk = part(
		m,
		"PalmTrunk",
		Vector3.new(h, 0.7, 0.7),
		lean * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(110, 96, 80),
		Enum.Material.Wood
	)
	trunk.Shape = Enum.PartType.Cylinder
	local top = lean * CFrame.new(0, h, 0)
	for k = 0, 6 do
		local leaf = part(
			m,
			"PalmLeaf",
			Vector3.new(0.5, 3.8, 0.12),
			top
				* CFrame.Angles(0, k * 2 * math.pi / 7, 0)
				* CFrame.Angles(math.rad(if k % 2 == 0 then 30 else 75), 0, 0)
				* CFrame.new(0, 1.8, 0),
			Color3.fromRGB(104, 124, 66),
			Enum.Material.Grass
		)
		leaf.CanCollide = false
	end
end

-- `zf`: the garden's inner edge (local z: the house front, or the lot back for a gap); y: the house floor
local function frontGarden(
	m: Instance,
	lot: TownLayout.Lot,
	n: number,
	y: number,
	doorX: number,
	zf: number,
	big: boolean
)
	local w, D = lot.w, TownLayout.DEPTH
	local at = CFrame.new(lot.cf.X, y, lot.cf.Z) * lot.cf.Rotation
	local zw = -D / 2 - lot.front + 0.5 -- wall centre: on the pavement's back edge
	local gy = ground((at * CFrame.new(0, 0, zw)).X, (at * CFrame.new(0, 0, zw)).Z, y)
	local base = math.min(gy, y) - 0.6
	local hedge = n % 3 == 0
	local top = y + (if hedge then 2 else 2.4)
	local g0, g1 = doorX - 1.8, doorX + 1.8 -- the gate gap
	for _, seg in { { -w / 2, g0 }, { g1, w / 2 } } do
		local len = seg[2] - seg[1]
		if len > 0.6 then
			local x = (seg[1] + seg[2]) / 2
			part(
				m,
				"GardenWall",
				Vector3.new(len, top - base, 1),
				at * CFrame.new(x, (top + base) / 2 - y, zw),
				STONE,
				Enum.Material.Granite
			)
			if hedge then
				part(
					m,
					"HedgeTop",
					Vector3.new(len, 1.1, 1.5),
					at * CFrame.new(x, top - y + 0.45, zw),
					HEDGE,
					Enum.Material.Grass
				)
			else
				part(
					m,
					"Coping",
					Vector3.new(len, 0.35, 1.3),
					at * CFrame.new(x, top - y + 0.17, zw),
					STONE:Lerp(Color3.new(1, 1, 1), 0.15),
					Enum.Material.Granite
				)
			end
		end
	end
	part(
		m,
		"Gate",
		Vector3.new(3.2, 2.4, 0.2),
		at * CFrame.new(doorX, 1.4, zw),
		GATES[n % #GATES + 1],
		Enum.Material.Wood
	)
	local depth = zf - (zw + 0.5)
	part(
		m,
		"GardenPath",
		Vector3.new(2.4, 0.3, depth),
		at * CFrame.new(doorX, 0.05, zw + 0.5 + depth / 2),
		Color3.fromRGB(150, 146, 138),
		Enum.Material.Granite
	)
	part(
		m,
		"PartyWall",
		Vector3.new(0.8, 1.8, depth),
		at * CFrame.new(-w / 2 + 0.4, 0.9, zw + 0.5 + depth / 2),
		STONE,
		Enum.Material.Granite
	)
	-- shrubs on the wider side of the path, against the wall
	local sx = if doorX < 0 then 1 else -1
	local room = w / 2 - doorX * sx - 2
	for k = 1, 2 do
		local sz = 2.4 + TownLayout.hash(n, k) * 1.4
		local x = doorX + sx * (2 + room * (k - 0.5) / 2)
		x = math.clamp(x, -w / 2 + 1.6, w / 2 - 1.6)
		local shrub = part(
			m,
			"Shrub",
			Vector3.new(sz * 1.3, sz, sz),
			at * CFrame.new(x, sz * 0.35, zw + 1.6),
			FLOWERS[(n + k * 2) % #FLOWERS + 1],
			Enum.Material.Grass
		)
		shrub.Shape = Enum.PartType.Ball
		shrub.CanCollide = false
	end
	local spot = (at * CFrame.new(
		math.clamp(doorX + sx * w, -w / 2 + 2.5, w / 2 - 2.5), -- the corner away from the path
		0,
		(zw + zf) / 2
	)).Position
	if big then
		tree(m, spot, 1.1)
	elseif n % 5 == 1 then
		palm(m, spot, n)
	end
end

-- Chapel Square (the TOWNS keep rect {x0, z0, x1, z1} at the Fore Street / Chapel Hill corner): cobbled square,
-- a granite chapel with a pinnacled tower facing Fore Street, benches, a bin, a red post box and phone box.
-- shortcut: code-built placeholder until a chapel asset exists; swap for the asset then.
local function chapelSquare(parent: Instance, r: TownLayout.Rect, y0: number): Model
	local sq = Instance.new("Model")
	sq.Name = "ChapelSquare"
	sq.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	sq.Parent = parent
	replace(r[1], r[2], r[3], r[4], y0, Enum.Material.Cobblestone)
	local y = ground((r[1] + r[3]) / 2, (r[2] + r[4]) / 2, y0)
	local cx, back = r[3] - 30, r[2] + 4 -- nave x centre, north (back) end
	local L, W, H = 40, 24, 22
	local navC = CFrame.new(cx, y + H / 2, back + L / 2)
	part(sq, "Nave", Vector3.new(W, H, L), navC, STONE, Enum.Material.Granite)
	local s = (W / 2 + 1) * math.sqrt(2)
	part(
		sq,
		"Roof",
		Vector3.new(s, s, L + 2),
		CFrame.new(cx, y + H, back + L / 2) * CFrame.Angles(0, 0, math.rad(45)),
		SLATE,
		Enum.Material.RoofShingles
	)
	local DRESS = STONE:Lerp(Color3.new(1, 1, 1), 0.25) -- dressed granite: surrounds, sills, courses
	-- plinth and eaves cornice round the nave
	part(
		sq,
		"Plinth",
		Vector3.new(W + 0.8, 1.6, L + 0.8),
		navC * CFrame.new(0, -H / 2 + 0.6, 0),
		DRESS,
		Enum.Material.Granite
	)
	for side = -1, 1, 2 do
		part(
			sq,
			"Cornice",
			Vector3.new(1, 1, L + 1),
			CFrame.new(cx + side * (W / 2 + 0.3), y + H - 0.5, back + L / 2),
			DRESS,
			Enum.Material.Granite
		)
	end
	-- round-headed lancets in dressed surrounds, with sills (one surround / glass / head part serves both sides)
	for i = 1, 3 do
		local z = back + i * L / 4
		part(
			sq,
			"Surround",
			Vector3.new(W + 0.6, 10, 4.6),
			CFrame.new(cx, y + 9.6, z),
			DRESS,
			Enum.Material.Granite
		)
		part(
			sq,
			"Window",
			Vector3.new(W + 0.8, 9, 3.2),
			CFrame.new(cx, y + 9.8, z),
			Color3.fromRGB(40, 52, 66),
			Enum.Material.Glass
		)
		part(
			sq,
			"WindowHead",
			Vector3.new(W + 0.6, 4.6, 4.6),
			CFrame.new(cx, y + 14.6, z),
			DRESS,
			Enum.Material.Granite
		).Shape =
			Enum.PartType.Cylinder
		part(
			sq,
			"WindowHeadGlass",
			Vector3.new(W + 0.8, 3.2, 3.2),
			CFrame.new(cx, y + 14.3, z),
			Color3.fromRGB(40, 52, 66),
			Enum.Material.Glass
		).Shape =
			Enum.PartType.Cylinder
		part(
			sq,
			"Sill",
			Vector3.new(W + 1.4, 0.5, 5.2),
			CFrame.new(cx, y + 4.6, z),
			DRESS,
			Enum.Material.Granite
		)
	end
	local T, TH = 13, 48
	local tz = back + L + T / 2
	part(
		sq,
		"Tower",
		Vector3.new(T, TH, T),
		CFrame.new(cx, y + TH / 2, tz),
		STONE,
		Enum.Material.Granite
	)
	-- string courses, a parapet, a round-headed doorway in a dressed surround, louvred belfry openings each side
	for _, h in { 14, 27, TH - 4 } do
		part(
			sq,
			"Course",
			Vector3.new(T + 0.8, 0.8, T + 0.8),
			CFrame.new(cx, y + h, tz),
			DRESS,
			Enum.Material.Granite
		)
	end
	part(
		sq,
		"Parapet",
		Vector3.new(T + 0.8, 1.4, T + 0.8),
		CFrame.new(cx, y + TH - 0.2, tz),
		DRESS,
		Enum.Material.Granite
	)
	part(
		sq,
		"DoorSurround",
		Vector3.new(7, 10, 0.6),
		CFrame.new(cx, y + 5, tz + T / 2 + 0.2),
		DRESS,
		Enum.Material.Granite
	)
	part(
		sq,
		"DoorArch",
		Vector3.new(0.6, 7, 7),
		CFrame.new(cx, y + 10, tz + T / 2 + 0.2) * CFrame.Angles(0, math.rad(90), 0),
		DRESS,
		Enum.Material.Granite
	).Shape =
		Enum.PartType.Cylinder
	part(
		sq,
		"Door",
		Vector3.new(5, 9, 0.4),
		CFrame.new(cx, y + 4.5, tz + T / 2 + 0.45),
		Color3.fromRGB(70, 36, 24),
		Enum.Material.Wood
	)
	part(
		sq,
		"DoorHead",
		Vector3.new(0.4, 5, 5),
		CFrame.new(cx, y + 9, tz + T / 2 + 0.45) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(70, 36, 24),
		Enum.Material.Wood
	).Shape =
		Enum.PartType.Cylinder
	for _, ax in { Vector3.new(T + 0.2, 6, 3), Vector3.new(3, 6, T + 0.2) } do -- through-parts: 4 openings from 2
		part(
			sq,
			"Belfry",
			ax,
			CFrame.new(cx, y + TH - 9, tz),
			Color3.fromRGB(30, 30, 32),
			Enum.Material.Wood
		)
		part(
			sq,
			"BelfrySurround",
			ax
				+ Vector3.new(
					if ax.X > ax.Z then 0.4 else 1.4,
					1.4,
					if ax.X > ax.Z then 1.4 else 0.4
				),
			CFrame.new(cx, y + TH - 8.3, tz),
			DRESS,
			Enum.Material.Granite
		)
	end
	part(
		sq,
		"ClockRing",
		Vector3.new(0.3, 6.2, 6.2),
		CFrame.new(cx, y + TH - 17, tz + T / 2 + 0.05) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(30, 34, 40),
		Enum.Material.Metal
	).Shape =
		Enum.PartType.Cylinder
	part(
		sq,
		"Clock",
		Vector3.new(0.3, 5, 5),
		CFrame.new(cx, y + TH - 17, tz + T / 2 + 0.15) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(236, 232, 220),
		Enum.Material.SmoothPlastic
	).Shape =
		Enum.PartType.Cylinder
	for k, hand in { { 1.9, -60 }, { 2.4, 0 } } do
		part(
			sq,
			`Hand{k}`,
			Vector3.new(0.25, hand[1], 0.1),
			CFrame.new(cx, y + TH - 17, tz + T / 2 + 0.35)
				* CFrame.Angles(0, 0, math.rad(hand[2]))
				* CFrame.new(0, hand[1] / 2 - 0.2, 0),
			Color3.fromRGB(24, 24, 26),
			Enum.Material.Metal
		)
	end
	for i = -1, 1, 2 do
		for j = -1, 1, 2 do
			part(
				sq,
				"Pinnacle",
				Vector3.new(1.6, 6, 1.6),
				CFrame.new(cx + i * (T / 2 - 0.8), y + TH + 3, tz + j * (T / 2 - 0.8)),
				STONE,
				Enum.Material.Granite
			)
		end
	end
	-- red post box (pillar) and phone box on the Fore Street pavement edge of the square
	local fz = r[4] - 3
	local post = part(
		sq,
		"PostBox",
		Vector3.new(4.4, 2.2, 2.2),
		CFrame.new(r[1] + 6, y + 2.2, fz) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(190, 24, 28),
		Enum.Material.SmoothPlastic
	)
	post.Shape = Enum.PartType.Cylinder -- a cylinder's axis is X: the 90 degree roll stands it up
	part(
		sq,
		"PhoneBox",
		Vector3.new(3.4, 8.4, 3.4),
		CFrame.new(r[1] + 12, y + 4.2, fz),
		Color3.fromRGB(190, 24, 28),
		Enum.Material.SmoothPlastic
	)
	part(
		sq,
		"PhoneBoxCap",
		Vector3.new(3.8, 0.8, 3.8),
		CFrame.new(r[1] + 12, y + 8.8, fz),
		Color3.fromRGB(170, 20, 24),
		Enum.Material.SmoothPlastic
	)
	local props: { { any } } = {
		{ "M_Road_Bench", Vector3.new(cx - 14, 0, tz + 4), 90 },
		{ "M_Road_Bench", Vector3.new(cx + 14, 0, tz + 4), -90 },
		{ "M_Road_Bench", Vector3.new(r[1] + 14, 0, r[2] + 30), 180 }, -- in front of the market hall
		{ "M_Road_Bench", Vector3.new(r[1] + 28, 0, r[2] + 30), 180 },
		{ "M_Road_Bin", Vector3.new(r[1] + 21, 0, r[2] + 30), 180 },
		{ "M_Road_StreetLamp", Vector3.new(r[1] + 6, 0, (r[2] + r[4]) / 2), 0 },
	}
	for _, pr in props do
		local m = StreetFurniture.build(pr[1]) or AssetLoader.cloneStatic(pr[1], "LOD0", true)
		if m then
			m:PivotTo(CFrame.new(pr[2].X, y, pr[2].Z) * CFrame.Angles(0, math.rad(pr[3]), 0))
			m.Parent = sq
		end
	end
	return sq
end

-- farmsteads (layout.py FARMS: gravel yards flattened in the bake): a granite farmhouse (a 2-storey terrace build)
-- on the yard's north side facing into it, a granite barn under a grey-green corrugated roof on its east side, and a
-- granite yard wall with a gate gap on the south. (The boatyard-shed mesh barn read as a giant white slab.)
local BARN = { len = 40, wide = 22, h = 9, pitch = 0.45, roof = Color3.fromRGB(100, 108, 102) }
local function farms(parent: Instance): number
	local folder = Instance.new("Model")
	folder.Name = "Farms"
	folder.ModelStreamingMode = Enum.ModelStreamingMode.Nonatomic
	folder.Parent = parent
	local n = 0
	for i, f in (WorldConfig :: any).Farms or {} do
		local y = ground(f.center.X, f.center.Z, f.center.Y)
		local yard = CFrame.new(f.center.X, y, f.center.Z) * CFrame.Angles(0, -math.rad(f.yaw), 0)
		local hx, hz = f.size[1] / 2, f.size[2] / 2
		local house = yard * CFrame.new(-8, 0, -hz + 12) * CFrame.Angles(0, math.pi, 0)
		local lot: any = { cf = house, w = 24, floors = 2, corner = false, shop = false, front = 0 }
		local ok, res = pcall(TownBuildings.terrace, folder, lot, 6 * i, y, y) -- n % 6 == 0: a granite front
		if ok then
			res.Name = `{f.id}_House`
			n += 1
		else
			warn(`[Town] {f.id} farmhouse: {res}`)
		end
		local barn = Instance.new("Model")
		barn.Name = `{f.id}_Barn`
		barn.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		-- barn X runs along the yard's Z; barn -Z faces into the yard
		local at = yard
			* CFrame.new(hx - BARN.wide / 2 - 4, 0, 4)
			* CFrame.Angles(0, math.pi / 2, 0)
		part(
			barn,
			"Walls",
			Vector3.new(BARN.len, BARN.h, BARN.wide),
			at * CFrame.new(0, BARN.h / 2, 0),
			STONE,
			Enum.Material.Granite
		)
		local run = BARN.wide / 2 + 1
		local rise = run * BARN.pitch
		for _, sz in { -1, 1 } do -- two corrugated slopes, their wedge ends close the gables
			local w = Instance.new("WedgePart")
			w.Name = "Roof"
			w.Anchored = true
			w.Size = Vector3.new(BARN.len + 1.6, rise, run)
			w.CFrame = at
				* CFrame.new(0, BARN.h + rise / 2, sz * run / 2)
				* CFrame.Angles(0, if sz < 0 then 0 else math.pi, 0)
			w.Color, w.Material = BARN.roof, Enum.Material.Metal
			w.Parent = barn
		end
		part(
			barn,
			"Door",
			Vector3.new(12, 9, 0.4),
			at * CFrame.new(0, 4.5, -BARN.wide / 2 - 0.2),
			SHED,
			Enum.Material.Wood
		)
		barn.Parent = folder
		n += 1
		-- the yard wall, 1.4 thick and 3.4 high on the yard's edge, a 10-stud gate gap mid-south
		local walls = Instance.new("Model")
		walls.Name = `{f.id}_YardWall`
		walls.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		local function wall(x0: number, z0: number, x1: number, z1: number)
			local len = math.max(math.abs(x1 - x0), math.abs(z1 - z0)) + 1.4
			local size = if x0 == x1 then Vector3.new(1.4, 3.4, len) else Vector3.new(len, 3.4, 1.4)
			part(
				walls,
				"Wall",
				size,
				yard * CFrame.new((x0 + x1) / 2, 1.7, (z0 + z1) / 2),
				STONE,
				Enum.Material.Granite
			)
		end
		wall(-hx, -hz, hx, -hz)
		wall(-hx, -hz, -hx, hz)
		wall(hx, -hz, hx, hz)
		wall(-hx, hz, -5, hz)
		wall(5, hz, hx, hz)
		walls.Parent = folder
	end
	return n
end

function Town.place(base: Instance)
	local root = Instance.new("Model")
	root.Name = "Town"
	root.ModelStreamingMode = Enum.ModelStreamingMode.Nonatomic
	root.Parent = base
	local placed, skipped = 0, 0
	for _, town in WorldConfig.Towns do
		local folder = Instance.new("Model")
		folder.Name = town.id
		folder.ModelStreamingMode = Enum.ModelStreamingMode.Nonatomic
		folder.Parent = root
		local lots = TownLayout.lots(
			town :: any,
			swapRects(),
			TownLayout.southZ(town :: any, WorldConfig.Roads :: any)
		)
		for v = 1, #TownLayout.COTTAGES do
			task.spawn(AssetLoader.getTemplate, string.format("M_Bld_Cottage_%02d", v), "LOD0")
		end
		local placedLots: { TownLayout.Lot }, ys: { [TownLayout.Lot]: number } = {}, {}
		local extras = Instance.new("Model")
		extras.Name = "Streetscape" -- gardens, shopfronts, Chapel Square
		extras.ModelStreamingMode = Enum.ModelStreamingMode.Nonatomic
		extras.Parent = folder
		local terraces, gaps = 0, 0
		local D = TownLayout.DEPTH
		for n, lot in lots do
			-- front-garden trees: about one lot in three (one per 60-odd studs), seeded by position
			local big = TownLayout.hash(math.floor(lot.cf.X / 4) + 0.3, math.floor(lot.cf.Z / 4))
				< 0.3
			if lot.kind == "gap" then -- a walled garden from the pavement to the lot's back, a tree in it
				local lo, hi = span(lot.rect, town.origin.Y)
				if hi - lo <= 8 then
					local gm = Instance.new("Model")
					gm.Name = `Gap{n}`
					gm.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
					gm.Parent = extras
					frontGarden(gm, lot, n, hi, 0, D / 2, true)
					part(
						gm,
						"BackWall",
						Vector3.new(lot.w, 3.2, 1),
						CFrame.new(lot.cf.X, hi, lot.cf.Z)
							* lot.cf.Rotation
							* CFrame.new(0, 1, D / 2 - 0.5),
						STONE,
						Enum.Material.Granite
					)
					gaps += 1
				end
				continue
			end
			-- a cottage lot on uneven ground becomes a 2-storey code-built house (no gaps in the street face); lots
			-- with a kind are always code-built
			local y0 = if lot.floors or lot.kind then nil else level(lot, town.origin.Y)
			if not lot.floors and not y0 then
				lot = table.clone(lot)
				lot.floors = 2
			end
			if lot.floors then -- code-built terrace: stands on a plinth, so slopes up to 8 studs are fine
				local lo, hi = span(lot.rect, town.origin.Y)
				if hi - lo <= 8 then
					local ok, res = pcall(TownBuildings.terrace, folder, lot, n, lo, hi)
					if ok then
						terraces += 1
						table.insert(placedLots, lot)
						ys[lot] = hi
						if lot.kind == "garage" then -- a granite-paved forecourt instead of a garden
							part(
								res,
								"Forecourt",
								Vector3.new(lot.w, 0.3, lot.front),
								CFrame.new(lot.cf.X, hi, lot.cf.Z)
									* lot.cf.Rotation
									* CFrame.new(0, 0.05, -D / 2 - lot.front / 2),
								Color3.fromRGB(132, 130, 124),
								Enum.Material.Granite
							)
						elseif lot.front > 0 then
							local doorX = if lot.kind == "chapel" then 0 else -lot.w / 4
							frontGarden(res, lot, n, hi, doorX, -D / 2, big)
						end
					else
						warn(`[Town] {town.id} terrace {n}: {res}`)
					end
				else
					skipped += 1
				end
				continue
			end
			local y = y0
			local model = if y then AssetLoader.cloneStatic(lot.asset, "LOD0", true) else nil
			if model then
				model.Name = `Cottage{n}`
				model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
				model:SetAttribute("Render", lot.render)
				-- perf: real PointLights on every third terrace, chimney smoke on every fourth (Neon panes all glow)
				model:SetAttribute("RigLights", n % 3 == 0)
				model:SetAttribute("RigSmoke", n % 4 == 0)
				model:PivotTo(lot.cf + Vector3.new(0, (y :: number) - lot.cf.Y, 0))
				model.Parent = folder
				local ok, err = pcall(CottageRig.apply, model)
				if not ok then
					warn(`[Town] {town.id} cottage {n}: rig failed: {err}`)
				end
				-- the rig's slate greys read pale from above: the terraces' dark Delabole slates
				local slate = TownBuildings.SLATES[n % #TownBuildings.SLATES + 1]
				for _, d in model:GetDescendants() do
					if d:IsA("MeshPart") and string.find(d.Name, "_Roof_", 1, true) then
						d.Color = slate
					end
				end
				local v = tonumber(string.sub(lot.asset, -2)) :: number
				frontGarden(model, lot, n, y :: number, COTTAGE_DOOR[v] or 0, -D / 2, big)
				placed += 1
				table.insert(placedLots, lot)
				ys[lot] = y :: number
			else
				skipped += 1
			end
		end
		local gardens = TownLayout.gardens(town :: any, placedLots, swapRects())
		local gm = Instance.new("Model")
		gm.Name = "Gardens"
		gm.Parent = extras
		for n, g in gardens do
			garden(gm, n, g.rect, g.lot, ys[g.lot] or town.origin.Y)
		end
		root:SetAttribute("TownGardens", #gardens)
		root:SetAttribute("TownTerraces", terraces)
		root:SetAttribute("TownGaps", gaps)
		local lms: { TownLayout.Landmark } = TownLayout.LANDMARKS[town.id] or {}
		for _, lm in lms do
			local lo, hi = span(lm.rect, town.origin.Y)
			local ok, err = pcall(TownBuildings.landmark, extras, lm, lo, hi)
			if not ok then
				warn(`[Town] {town.id} {lm.kind}: {err}`)
			end
		end
		local sq: TownLayout.Rect = town.keep[#town.keep] -- the last keep rect (layout.py TOWNS)
		local ok, err = pcall(chapelSquare, extras, sq, town.origin.Y)
		if not ok then
			warn(`[Town] {town.id} chapel square: {err}`)
		end
	end
	root:SetAttribute("TownFarmBuildings", farms(root))
	root:SetAttribute("TownCottages", placed)
	root:SetAttribute("TownSkipped", skipped)
	print(
		`[Town] {placed} cottages, {root:GetAttribute("TownTerraces")} terraces, {skipped} lots skipped`
	)
end

return Town
