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
--                     lines and trees; the residential blocks a gravel back lane. TownLayout.uses blocks get a
--                     churchyard (St Petroc's, the tallest tower), the town green, a car park and market, allotments,
--                     the board school grounds (USE_BUILDERS). The last street's outer row gets hedged back gardens
--                     (rowGardens) and Town.Outskirts softens the grid's edge into the country (see outskirts()).
-- Grid roads are axis-aligned, so Region3 repaints are exact. shortcut: a rotated town needs per-segment wedges.
-- Every non-shop lot gets a walled front garden (frontGarden); "gap" lots are all garden.
-- Folder attributes: TownCottages, TownTerraces, TownSkipped, TownGardens, TownGaps, TownOutskirts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AssetLoader = require(script.Parent.Parent:WaitForChild("Assets"):WaitForChild("AssetLoader"))
local CarPaint = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CarPaint"))
local CottageRig = require(script.Parent:WaitForChild("CottageRig"))
local StreetFurniture = require(script.Parent:WaitForChild("StreetFurniture"))
local StreetLayout = require(script.Parent:WaitForChild("StreetLayout"))
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
	Asphalt = { 138, 134, 126 }, -- the built-in texture is dark: 62,64,68 drew a black, textureless road (docs/17 N10)
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
		local uses = TownLayout.uses(town :: any)
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
			local used = false
			for _, u in uses do
				used = used
					or (
						u.rect[1] > b[1]
						and u.rect[1] < b[3]
						and u.rect[2] > b[2]
						and u.rect[2] < b[4]
					)
			end
			if b[4] < zs[2] and not used then -- north of the first street: back-to-back gardens, a gravel lane
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
-- garden: a granite back wall and one side wall; every third gets a timber shed in the back corner, every other a
-- patio or a lean-to outshut, a tree in one in three and in every long garden, veg beds, greenhouses
local SHED_PAINT =
	{ SHED, Color3.fromRGB(70, 96, 72), Color3.fromRGB(56, 46, 40), Color3.fromRGB(86, 104, 120) }
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
	if n % 3 == 1 or d >= 25 then -- a garden tree in the far corner (every long garden has one)
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
	if n % 3 == 0 then -- a shed in the far corner: a small one in the short back-lane yards
		local big = d >= 10
		local sz = if big then Vector3.new(6, 6, 7) else Vector3.new(4.4, 5, 3.8)
		local at = far - backDir * (sz.Z / 2 + 0.6) - side * (w / 2 - sz.X / 2 - 1)
		part(
			parent,
			`Shed{n}`,
			sz,
			CFrame.new(at + Vector3.yAxis * sz.Y / 2) * CFrame.Angles(0, yaw, 0),
			SHED_PAINT[n % #SHED_PAINT + 1],
			Enum.Material.Wood
		)
		part(
			parent,
			`ShedRoof{n}`,
			Vector3.new(sz.X + 1, 0.4, sz.Z + 1),
			CFrame.new(at + Vector3.yAxis * (sz.Y + 0.3))
				* CFrame.Angles(0, yaw, 0)
				* CFrame.Angles(math.rad(8), 0, 0),
			SLATE,
			Enum.Material.RoofShingles
		)
	end
	local rot = CFrame.Angles(0, yaw, 0)
	if n % 2 == 1 then -- a flagged patio by the back door (the even ones have the outshut there)
		local at = Vector3.new(cx, y, cz) - backDir * (d / 2 - 1.6)
		part(
			parent,
			`Patio{n}`,
			Vector3.new(w - 2, 0.25, 3),
			CFrame.new(at + Vector3.yAxis * 0.1) * rot,
			Color3.fromRGB(156, 150, 140),
			Enum.Material.Granite
		).CanCollide =
			false
	end
	if d >= 18 or n % 5 == 3 then -- a vegetable bed across the middle, two rows coming up
		local deep = math.min(d * 0.3, 8)
		local at = Vector3.new(cx, y, cz) + backDir * (if d >= 18 then d * 0.1 else 0)
		part(
			parent,
			`VegBed{n}`,
			Vector3.new(w * 0.55, 0.3, deep),
			CFrame.new(at + Vector3.yAxis * 0.1) * rot,
			Color3.fromRGB(78, 60, 44),
			Enum.Material.Fabric
		).CanCollide =
			false
		part(
			parent,
			`Veg{n}`,
			Vector3.new(w * 0.5, 0.8, deep * 0.25),
			CFrame.new(at + Vector3.yAxis * 0.5) * rot * CFrame.new(0, 0, -deep * 0.2),
			Color3.fromRGB(88, 128, 62),
			Enum.Material.Grass
		).CanCollide =
			false
	end
	if d >= 25 and n % 2 == 0 then -- a lean-to greenhouse against the side wall of the long gardens
		local at = Vector3.new(cx, y, cz) + backDir * (d * 0.22) + side * (w / 2 - 2.4)
		local gh = part(
			parent,
			`Greenhouse{n}`,
			Vector3.new(3.6, 5, 7),
			CFrame.new(at + Vector3.yAxis * 2.5) * rot,
			Color3.fromRGB(196, 214, 210),
			Enum.Material.Glass
		)
		gh.Transparency = 0.45
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

-- green: the crown colour (default a seeded leaf green); low: a squat crown on a short trunk (yews)
local function tree(m: Instance, at: Vector3, scale: number, green: Color3?, low: boolean?)
	local h = (if low then 4.5 else 9) * scale
	local trunk = part(
		m,
		"TreeTrunk",
		Vector3.new(h, 1.1 * scale, 1.1 * scale),
		CFrame.new(at + Vector3.yAxis * h / 2) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(84, 70, 56),
		Enum.Material.Wood
	)
	trunk.Shape = Enum.PartType.Cylinder
	local g: Color3 = green or LEAF:Lerp(Color3.fromRGB(96, 116, 58), TownLayout.hash(at.X, at.Z))
	if low then
		h *= 1.6 -- the crown sits on the short trunk, a bulk down to the ground
	end
	for k, c in { { 0, 1.1, 0, 9 }, { 1.8, 1.35, -1.2, 6.5 }, { -1.6, 1.25, 1.4, 6 } } do
		local crown = part(
			m,
			"TreeCrown",
			Vector3.one * c[4] * scale,
			CFrame.new(at + Vector3.new(c[1] * scale, h * c[2], c[3] * scale)),
			if k == 2 then g:Lerp(Color3.new(1, 1, 0.8), 0.08) else g,
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

-- an M_Bld_Cottage_0n asset at cf, stood at y: render set, CottageRig (lit windows, smoke), dark slate roof
local function cottage(
	parent: Instance,
	asset: string,
	render: string,
	cf: CFrame,
	n: number,
	y: number
): Model?
	local model = AssetLoader.cloneStatic(asset, "LOD0", true)
	if not model then
		return nil
	end
	model.Name = `Cottage{n}`
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("Render", render)
	-- perf: real PointLights on every third terrace, chimney smoke on every fourth (Neon panes all glow)
	model:SetAttribute("RigLights", n % 3 == 0)
	model:SetAttribute("RigSmoke", n % 4 == 0)
	model:PivotTo(cf + Vector3.new(0, y - cf.Y, 0))
	model.Parent = parent
	local ok, err = pcall(CottageRig.apply, model)
	if not ok then
		warn(`[Town] cottage {n}: rig failed: {err}`)
	end
	-- the rig's slate greys read pale from above: the terraces' dark Delabole slates
	local slate = TownBuildings.SLATES[n % #TownBuildings.SLATES + 1]
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") and string.find(d.Name, "_Roof_", 1, true) then
			d.Color = slate
		end
	end
	return model
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
	local w, D = lot.w, lot.depth or TownLayout.DEPTH
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

-- street furniture { asset, at (x, _, z), yaw degrees } stood on the ground at y
local function furnish(m: Instance, list: { { any } }, y: number)
	for _, pr in list do
		local f = StreetFurniture.build(pr[1]) or AssetLoader.cloneStatic(pr[1], "LOD0", true)
		if f then
			f:PivotTo(CFrame.new(pr[2].X, y, pr[2].Z) * CFrame.Angles(0, math.rad(pr[3]), 0))
			f.Parent = m
		end
	end
end

-- church: a granite nave (plinth, eaves cornices, slate roof, round-headed lancets in dressed surrounds through both
-- sides) and a tower at its +Z end facing +Z (string courses, parapet, round-headed door, louvred belfry, clock,
-- corner pinnacles), in frame `f` (origin on the ground at the nave's centre, the nave along local Z). Options:
-- battlements on the tower; a chancel (narrower, lower) at the -Z end.
type ChurchSpec = {
	L: number,
	W: number,
	H: number,
	T: number,
	TH: number,
	battlements: boolean?,
	chancel: boolean?,
	stone: Color3?, -- walling colour (default STONE)
}
local DRESS = STONE:Lerp(Color3.new(1, 1, 1), 0.25) -- dressed granite: surrounds, sills, courses
local function church(m: Instance, f: CFrame, o: ChurchSpec)
	local L, W, H, T, TH = o.L, o.W, o.H, o.T, o.TH
	local stone = o.stone or STONE
	local G = Enum.Material.Granite
	local navC = f * CFrame.new(0, H / 2, 0)
	part(m, "Nave", Vector3.new(W, H, L), navC, stone, G)
	local function roof(w: number, len: number, at: CFrame)
		local s = (w / 2 + 1) * math.sqrt(2)
		part(
			m,
			"Roof",
			Vector3.new(s, s, len),
			at * CFrame.Angles(0, 0, math.rad(45)),
			SLATE,
			Enum.Material.RoofShingles
		)
	end
	roof(W, L + 2, f * CFrame.new(0, H, 0))
	-- plinth and eaves cornice round the nave
	part(
		m,
		"Plinth",
		Vector3.new(W + 0.8, 1.6, L + 0.8),
		navC * CFrame.new(0, -H / 2 + 0.6, 0),
		DRESS,
		G
	)
	for side = -1, 1, 2 do
		part(
			m,
			"Cornice",
			Vector3.new(1, 1, L + 1),
			f * CFrame.new(side * (W / 2 + 0.3), H - 0.5, 0),
			DRESS,
			G
		)
	end
	-- round-headed lancets in dressed surrounds, with sills (one surround / glass / head part serves both sides)
	local glass = Color3.fromRGB(40, 52, 66)
	local nw = math.floor(L / 12)
	for i = 1, nw do
		local at = f * CFrame.new(0, 0, -L / 2 + i * L / (nw + 1))
		part(m, "Surround", Vector3.new(W + 0.6, 10, 4.6), at * CFrame.new(0, 9.6, 0), DRESS, G)
		part(
			m,
			"Window",
			Vector3.new(W + 0.8, 9, 3.2),
			at * CFrame.new(0, 9.8, 0),
			glass,
			Enum.Material.Glass
		)
		part(m, "WindowHead", Vector3.new(W + 0.6, 4.6, 4.6), at * CFrame.new(0, 14.6, 0), DRESS, G).Shape =
			Enum.PartType.Cylinder
		part(
			m,
			"WindowHeadGlass",
			Vector3.new(W + 0.8, 3.2, 3.2),
			at * CFrame.new(0, 14.3, 0),
			glass,
			Enum.Material.Glass
		).Shape =
			Enum.PartType.Cylinder
		part(m, "Sill", Vector3.new(W + 1.4, 0.5, 5.2), at * CFrame.new(0, 4.6, 0), DRESS, G)
	end
	if o.chancel then
		local CL, CW, CH = 16, W - 6, H - 5
		local cc = f * CFrame.new(0, 0, -L / 2 - CL / 2 + 0.5)
		part(m, "Chancel", Vector3.new(CW, CH, CL), cc * CFrame.new(0, CH / 2, 0), stone, G)
		roof(CW, CL + 1, cc * CFrame.new(0, CH, 0))
		part(
			m,
			"EastWindow",
			Vector3.new(6, 11, 0.4),
			cc * CFrame.new(0, 9, -CL / 2 - 0.1),
			glass,
			Enum.Material.Glass
		)
		part(
			m,
			"EastSurround",
			Vector3.new(7.6, 12.6, 0.3),
			cc * CFrame.new(0, 9, -CL / 2 - 0.02),
			DRESS,
			G
		)
	end
	local tz = L / 2 + T / 2
	local tw = f * CFrame.new(0, 0, tz) -- tower base centre
	part(m, "Tower", Vector3.new(T, TH, T), tw * CFrame.new(0, TH / 2, 0), stone, G)
	for _, h in { math.round(TH * 0.29), math.round(TH * 0.5625), TH - 4 } do
		part(m, "Course", Vector3.new(T + 0.8, 0.8, T + 0.8), tw * CFrame.new(0, h, 0), DRESS, G)
	end
	part(
		m,
		"Parapet",
		Vector3.new(T + 0.8, 1.4, T + 0.8),
		tw * CFrame.new(0, TH - 0.2, 0),
		DRESS,
		G
	)
	local face = T / 2
	part(m, "DoorSurround", Vector3.new(7, 10, 0.6), tw * CFrame.new(0, 5, face + 0.2), DRESS, G)
	local turn = CFrame.Angles(0, math.rad(90), 0)
	part(m, "DoorArch", Vector3.new(0.6, 7, 7), tw * CFrame.new(0, 10, face + 0.2) * turn, DRESS, G).Shape =
		Enum.PartType.Cylinder
	local oak = Color3.fromRGB(70, 36, 24)
	part(
		m,
		"Door",
		Vector3.new(5, 9, 0.4),
		tw * CFrame.new(0, 4.5, face + 0.45),
		oak,
		Enum.Material.Wood
	)
	part(
		m,
		"DoorHead",
		Vector3.new(0.4, 5, 5),
		tw * CFrame.new(0, 9, face + 0.45) * turn,
		oak,
		Enum.Material.Wood
	).Shape =
		Enum.PartType.Cylinder
	for _, ax in { Vector3.new(T + 0.2, 6, 3), Vector3.new(3, 6, T + 0.2) } do -- through-parts: 4 openings from 2
		part(
			m,
			"Belfry",
			ax,
			tw * CFrame.new(0, TH - 9, 0),
			Color3.fromRGB(30, 30, 32),
			Enum.Material.Wood
		)
		part(
			m,
			"BelfrySurround",
			ax
				+ Vector3.new(
					if ax.X > ax.Z then 0.4 else 1.4,
					1.4,
					if ax.X > ax.Z then 1.4 else 0.4
				),
			tw * CFrame.new(0, TH - 8.3, 0),
			DRESS,
			G
		)
	end
	local ck = tw * CFrame.new(0, TH - 17, face)
	part(
		m,
		"ClockRing",
		Vector3.new(0.3, 6.2, 6.2),
		ck * CFrame.new(0, 0, 0.05) * turn,
		Color3.fromRGB(30, 34, 40),
		Enum.Material.Metal
	).Shape =
		Enum.PartType.Cylinder
	part(
		m,
		"Clock",
		Vector3.new(0.3, 5, 5),
		ck * CFrame.new(0, 0, 0.15) * turn,
		Color3.fromRGB(236, 232, 220),
		Enum.Material.SmoothPlastic
	).Shape =
		Enum.PartType.Cylinder
	for k, hand in { { 1.9, -60 }, { 2.4, 0 } } do
		part(
			m,
			`Hand{k}`,
			Vector3.new(0.25, hand[1], 0.1),
			ck
				* CFrame.new(0, 0, 0.35)
				* CFrame.Angles(0, 0, math.rad(hand[2]))
				* CFrame.new(0, hand[1] / 2 - 0.2, 0),
			Color3.fromRGB(24, 24, 26),
			Enum.Material.Metal
		)
	end
	local ph = if o.battlements then 9 else 6 -- Cornish towers: tall crocketed pinnacles over battlements
	for i = -1, 1, 2 do
		for j = -1, 1, 2 do
			part(
				m,
				"Pinnacle",
				Vector3.new(1.6, ph, 1.6),
				tw * CFrame.new(i * (T / 2 - 0.8), TH + ph / 2, j * (T / 2 - 0.8)),
				stone,
				G
			)
		end
	end
	if o.battlements then
		for k = 0, 3 do -- two merlons a side between the pinnacles
			local side = tw * CFrame.Angles(0, k * math.pi / 2, 0)
			for _, x in { -T / 6, T / 6 } do
				part(
					m,
					"Merlon",
					Vector3.new(2, 2.2, 1),
					side * CFrame.new(x, TH + 1.6, T / 2 - 0.1),
					DRESS,
					G
				)
			end
		end
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
	local L, T = 40, 13
	church(sq, CFrame.new(cx, y, back + L / 2), { L = L, W = 24, H = 22, T = T, TH = 48 })
	local tz = back + L + T / 2
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
	furnish(sq, props, y)
	return sq
end

-- Whole-block uses (TownLayout.uses): a churchyard, the town green, a car park with market stalls, allotments and
-- a board school, each one Atomic Model in its block. r = the block inside its pavements.
local G = Enum.Material.Granite
local GRAVEL = Color3.fromRGB(176, 166, 144)
local WHITE_LINE = Color3.fromRGB(232, 232, 226)

-- a ridged roof of two wedges: ridge along local X at height h + rise in frame `at`, eaves run studs out each side
local function gable(
	m: Instance,
	at: CFrame,
	len: number,
	run: number,
	rise: number,
	h: number,
	color: Color3
)
	for _, sz in { -1, 1 } do
		local w = Instance.new("WedgePart")
		w.Name = "Roof"
		w.Anchored = true
		w.Size = Vector3.new(len, rise, run)
		w.CFrame = at
			* CFrame.new(0, h + rise / 2, sz * run / 2)
			* CFrame.Angles(0, if sz < 0 then 0 else math.pi, 0)
		w.Color, w.Material = color, Enum.Material.RoofShingles
		w.Parent = m
	end
end

-- a flat Part strip on the ground from a to b (XZ), `wide` across
local function strip(
	m: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	wide: number,
	y: number,
	color: Color3
)
	local p = part(
		m,
		name,
		Vector3.new(wide, 0.3, (b - a).Magnitude),
		CFrame.lookAt(Vector3.new(a.X, y + 0.05, a.Z), Vector3.new(b.X, y + 0.05, b.Z))
			* CFrame.new(0, 0, -(b - a).Magnitude / 2),
		color,
		G
	)
	p.CanCollide = false
	return p
end

-- a boundary round rect w: granite wall `h` high with coping, or a Cornish hedge (stone faced, turf top); rail: a
-- painted railing panel and posts on top. gaps[side] = { {centre, width} } (1 north, 2 south, 3 west, 4 east)
local function boundary(
	m: Instance,
	w: TownLayout.Rect,
	y: number,
	h: number,
	hedge: boolean,
	gaps: { [number]: { { number } } },
	rail: Color3?
)
	local runs = {
		{ w[1], w[2], w[3], w[2] },
		{ w[1], w[4], w[3], w[4] },
		{ w[1], w[2], w[1], w[4] },
		{ w[3], w[2], w[3], w[4] },
	}
	for side, run in runs do
		local alongX = run[2] == run[4]
		local a, b = if alongX then run[1] else run[2], if alongX then run[3] else run[4]
		local segs, pos = {}, a
		local cuts: { { number } } = table.clone(gaps[side] or {})
		table.sort(cuts, function(p, q)
			return p[1] < q[1]
		end)
		for _, g in cuts do
			table.insert(segs, { pos, math.max(pos, g[1] - g[2] / 2) })
			pos = math.max(pos, g[1] + g[2] / 2)
		end
		table.insert(segs, { pos, b })
		for _, s in segs do
			local len = s[2] - s[1]
			if len > 0.5 then
				local mid = (s[1] + s[2]) / 2
				local at = if alongX
					then Vector3.new(mid, y, run[2])
					else Vector3.new(run[1], y, mid)
				local function box(y0: number, y1: number, thick: number): (Vector3, CFrame)
					return if alongX
						then Vector3.new(len, y1 - y0, thick)
						else Vector3.new(thick, y1 - y0, len),
						CFrame.new(at + Vector3.yAxis * (y0 + y1) / 2)
				end
				local sz, cf = box(-0.6, h, if hedge then 2 else 1.2)
				part(m, "Wall", sz, cf, STONE, G)
				if hedge then
					sz, cf = box(h, h + 1.4, 2.4)
					local top = part(m, "HedgeTop", sz, cf, HEDGE, Enum.Material.Grass)
					top.CanCollide = false
				else
					sz, cf = box(h, h + 0.35, 1.5)
					part(m, "Coping", sz, cf, STONE:Lerp(Color3.new(1, 1, 1), 0.15), G)
				end
				if rail then
					sz, cf = box(h + 0.35, h + 3.6, 0.15)
					local panel = part(m, "Railing", sz, cf, rail, Enum.Material.Metal)
					panel.Transparency = 0.55
					for k = 0, math.floor(len / 8) do
						local t = s[1] + math.min(k * 8, len)
						local p = if alongX
							then Vector3.new(t, y, run[2])
							else Vector3.new(run[1], y, t)
						part(
							m,
							"RailPost",
							Vector3.new(0.4, 3.8, 0.4),
							CFrame.new(p + Vector3.yAxis * (h + 2.1)),
							rail,
							Enum.Material.Metal
						)
					end
				end
			end
		end
	end
end

-- seeded 0..1 for item k of a use
local function rnd(a: number, k: number): number
	return TownLayout.hash(a * 0.731 + k * 1.37, k * 0.29 + a)
end

local function useModel(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = parent
	return m
end

-- St Petroc's: a battlemented west tower (the town's tallest), nave, chancel and south porch in a walled
-- churchyard; a slate-roofed lychgate on Church Street, a flagged path, dark yews, rows of headstones (east-facing),
-- crosses and chest tombs.
local YEW = Color3.fromRGB(38, 58, 42)
local PALE = Color3.fromRGB(176, 170, 156) -- St Petroc's: pale dressed granite, it reads against the slate roofs
local STONES = {
	Color3.fromRGB(150, 146, 136),
	Color3.fromRGB(122, 120, 112),
	Color3.fromRGB(168, 164, 152),
	Color3.fromRGB(136, 138, 120), -- lichen
}
local function churchyard(parent: Instance, r: TownLayout.Rect, y0: number)
	local m = useModel(parent, "Churchyard")
	local cx, cz = (r[1] + r[3]) / 2, (r[2] + r[4]) / 2
	local y = ground(cx, cz, y0)
	local w = { r[1] + 1, r[2] + 1, r[3] - 1, r[4] - 1 }
	local nx, nz = cx + 4, cz - 5 -- nave centre
	local L, W = 48, 24
	local gx = nx - 6 -- lychgate and porch line
	boundary(m, w, y, 3.4, false, { [2] = { { gx, 7 } } })
	-- nave along x: local +Z (the tower) to the west, local +X (the porch) to the south
	local f = CFrame.new(nx, y, nz) * CFrame.Angles(0, -math.pi / 2, 0)
	church(
		m,
		f,
		{ L = L, W = W, H = 24, T = 16, TH = 90, battlements = true, chancel = true, stone = PALE }
	)
	-- St Piran's flag (white cross on black) over the tower: the skyline marker from the ridge and the air
	local top = f * CFrame.new(0, 90 + 1, L / 2 + 8)
	part(
		m,
		"Flagpole",
		Vector3.new(0.4, 14, 0.4),
		top * CFrame.new(0, 7, 0),
		Color3.fromRGB(236, 234, 226),
		Enum.Material.Metal
	)
	local flag = top
		* CFrame.new(0, 12, 0)
		* CFrame.Angles(0, math.rad(90), 0)
		* CFrame.new(3.4, 0, 0)
	part(
		m,
		"Flag",
		Vector3.new(6.4, 4, 0.1),
		flag,
		Color3.fromRGB(20, 20, 22),
		Enum.Material.Fabric
	)
	part(
		m,
		"FlagCross",
		Vector3.new(6.4, 0.8, 0.14),
		flag,
		Color3.fromRGB(240, 240, 236),
		Enum.Material.Fabric
	)
	part(
		m,
		"FlagCross",
		Vector3.new(0.8, 4, 0.14),
		flag,
		Color3.fromRGB(240, 240, 236),
		Enum.Material.Fabric
	)
	local porch = f * CFrame.new(W / 2 + 4, 0, 6)
	part(m, "Porch", Vector3.new(8, 10, 9), porch * CFrame.new(0, 5, 0), STONE, G)
	gable(m, porch, 9, 5.2, 3.6, 10, SLATE)
	part(
		m,
		"PorchDoor",
		Vector3.new(0.3, 7.4, 4),
		porch * CFrame.new(4.05, 3.7, 0),
		Color3.fromRGB(30, 26, 24),
		Enum.Material.Wood
	)
	-- lychgate: two granite piers, a timber beam and a slate roof over the gap
	for s = -1, 1, 2 do
		part(
			m,
			"GatePier",
			Vector3.new(1.6, 6.4, 1.6),
			CFrame.new(gx + s * 4.3, y + 3, w[4]),
			STONE,
			G
		)
	end
	part(
		m,
		"GateBeam",
		Vector3.new(10.2, 0.8, 1.4),
		CFrame.new(gx, y + 6.4, w[4]),
		Color3.fromRGB(92, 72, 52),
		Enum.Material.Wood
	)
	gable(m, CFrame.new(gx, y, w[4]), 11, 2.8, 2.6, 6.8, SLATE)
	local pz = (f * CFrame.new(W / 2 + 8, 0, 0)).Z -- the porch's outer face
	strip(
		m,
		"Path",
		Vector3.new(gx, 0, w[4]),
		Vector3.new(gx, 0, pz),
		3.4,
		y,
		Color3.fromRGB(150, 146, 138)
	)
	local yews = {
		Vector3.new(gx - 8, y, w[4] - 6),
		Vector3.new(gx + 8, y, w[4] - 6),
		Vector3.new(w[1] + 9, y, w[2] + 9),
		Vector3.new(w[3] - 9, y, w[2] + 9),
		Vector3.new(w[1] + 9, y, w[4] - 9),
		Vector3.new(w[3] - 11, y, w[4] - 8),
		Vector3.new(nx + 30, y, w[2] + 7),
	}
	for k, at in yews do
		tree(m, at, 1.15 + rnd(at.X, k) * 0.35, YEW, true)
	end
	-- headstones on a 5.5 x 7 grid, clear of the church (+4), the path and the yews; about a third left as grass
	local n = 0
	local x0, x1 = nx - L / 2 - 16 - 4, nx + L / 2 + 16 + 4 -- tower and chancel ends
	for gz = w[2] + 5, w[4] - 5, 7 do
		for gxk = w[1] + 4, w[3] - 4, 5.5 do
			local skip = (gxk > x0 and gxk < x1 and gz > nz - W / 2 - 5 and gz < pz + 4)
				or (math.abs(gxk - gx) < 4.5 and gz > nz)
				or rnd(gxk, gz) < 0.32
			for _, yw in yews do
				skip = skip or (Vector3.new(gxk, y, gz) - yw).Magnitude < 7
			end
			if not skip then
				n += 1
				local k = rnd(gz, gxk)
				local c = STONES[n % #STONES + 1]
				local at = CFrame.new(gxk + (k - 0.5) * 1.6, y, gz)
					* CFrame.Angles(0, (k - 0.5) * 0.2, (k - 0.5) * 0.14) -- old stones lean
				if k < 0.55 then -- upright headstone, facing east
					local hgt = 2.2 + k * 1.4
					part(
						m,
						"Headstone",
						Vector3.new(0.4, hgt, 1.5 + k),
						at * CFrame.new(0, hgt / 2 - 0.3, 0),
						c,
						G
					)
				elseif k < 0.75 then -- cross
					part(m, "Cross", Vector3.new(0.45, 3.4, 0.5), at * CFrame.new(0, 1.4, 0), c, G)
					part(
						m,
						"CrossBar",
						Vector3.new(0.45, 0.45, 1.8),
						at * CFrame.new(0, 2.3, 0),
						c,
						G
					)
				elseif k < 0.88 then -- slate headstone, darker and thinner
					part(
						m,
						"Headstone",
						Vector3.new(0.25, 3, 1.7),
						at * CFrame.new(0, 1.2, 0),
						Color3.fromRGB(66, 70, 76),
						G
					)
				else -- chest tomb with a lid
					part(m, "Tomb", Vector3.new(5.4, 1.8, 2.6), at * CFrame.new(1.5, 0.6, 0), c, G)
					part(
						m,
						"TombLid",
						Vector3.new(5.9, 0.35, 3.1),
						at * CFrame.new(1.5, 1.65, 0),
						c,
						G
					)
				end
			end
		end
	end
	furnish(m, {
		{ "M_Road_Bench", Vector3.new(gx + 5, 0, w[4] - 14), -90 },
		{ "M_Road_Bench", Vector3.new(gx - 5, 0, w[4] - 14), 90 },
	}, y)
	m:SetAttribute("Headstones", n)
end

-- the town green: a Cornish hedge with corner and south openings, gravel diagonals crossing at a bandstand, a
-- granite war memorial (wheel cross) and a round flower bed either side, big trees round the edge, benches, lamps
local function green(parent: Instance, r: TownLayout.Rect, y0: number)
	local m = useModel(parent, "TownGreen")
	local cx, cz = (r[1] + r[3]) / 2, (r[2] + r[4]) / 2
	local y = ground(cx, cz, y0)
	local w = { r[1] + 1.5, r[2] + 1.5, r[3] - 1.5, r[4] - 1.5 }
	local O = 12 -- corner openings
	boundary(m, w, y, 1.6, true, {
		[1] = { { w[1], O }, { w[3], O } },
		[2] = { { w[1], O }, { w[3], O }, { cx, 6 } },
		[3] = { { w[2], O }, { w[4], O } },
		[4] = { { w[2], O }, { w[4], O } },
	})
	local c = Vector3.new(cx, 0, cz)
	local corners = {
		Vector3.new(w[1], 0, w[2]),
		Vector3.new(w[3], 0, w[4]),
		Vector3.new(w[3], 0, w[2]),
		Vector3.new(w[1], 0, w[4]),
	}
	for k = 1, 3, 2 do
		strip(m, "Path", corners[k], corners[k + 1], 4, y, GRAVEL)
	end
	strip(m, "Path", Vector3.new(cx, 0, w[4]), c, 3.4, y, GRAVEL)
	local mx = 44 -- memorial / flower bed offset from the centre
	strip(m, "Path", c - Vector3.xAxis * mx, c + Vector3.xAxis * mx, 3, y, GRAVEL)
	local up = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder's axis is X: stand it up
	part(m, "Circle", Vector3.new(0.3, 28, 28), CFrame.new(cx, y + 0.08, cz) * up, GRAVEL, G).CanCollide =
		false
	-- bandstand: granite drum, eight cream iron columns, red frieze, octagonal copper roof, gilt finial
	part(m, "Drum", Vector3.new(2.6, 16, 16), CFrame.new(cx, y + 1.0, cz) * up, STONE, G)
	part(m, "Step", Vector3.new(4, 1.2, 2.4), CFrame.new(cx, y + 0.3, cz + 8.6), STONE, G)
	local iron = Color3.fromRGB(232, 228, 212)
	for k = 0, 7 do
		local a = k * math.pi / 4 + math.pi / 8
		part(
			m,
			"Column",
			Vector3.new(8, 0.6, 0.6),
			CFrame.new(cx + math.cos(a) * 7, y + 6.3, cz + math.sin(a) * 7) * up,
			iron,
			Enum.Material.Metal
		).Shape =
			Enum.PartType.Cylinder
	end
	part(
		m,
		"Frieze",
		Vector3.new(1.4, 16.4, 16.4),
		CFrame.new(cx, y + 10.9, cz) * up,
		Color3.fromRGB(150, 36, 40),
		Enum.Material.Metal
	).Shape =
		Enum.PartType.Cylinder
	local copper = Color3.fromRGB(86, 128, 110)
	for k = 0, 1 do
		TownBuildings.pyramid(
			m,
			CFrame.new(cx, y + 11.5, cz) * CFrame.Angles(0, k * math.pi / 4, 0),
			13.2,
			5.4,
			copper,
			Enum.Material.Metal
		)
	end
	part(
		m,
		"Finial",
		Vector3.one * 1.2,
		CFrame.new(cx, y + 17.2, cz),
		Color3.fromRGB(206, 164, 64),
		Enum.Material.Metal
	).Shape =
		Enum.PartType.Ball
	-- war memorial (west): three steps, a plinth with a poppy wreath, a tall wheel-headed cross facing the street
	local mc = CFrame.new(cx - mx, y, cz)
	local dress = STONE:Lerp(Color3.new(1, 1, 1), 0.2)
	part(m, "Paving", Vector3.new(11, 0.3, 11), mc * CFrame.new(0, 0.1, 0), GRAVEL, G)
	for k, s in { 7.4, 5.8, 4.2 } do
		part(
			m,
			"MemorialStep",
			Vector3.new(s, 0.8, s),
			mc * CFrame.new(0, k * 0.8 - 0.3, 0),
			dress,
			G
		)
	end
	part(m, "Plinth", Vector3.new(2.8, 3.8, 2.8), mc * CFrame.new(0, 4.2, 0), dress, G)
	part(m, "Shaft", Vector3.new(1.1, 9, 0.9), mc * CFrame.new(0, 10.6, 0), dress, G)
	part(m, "CrossArm", Vector3.new(3.8, 1, 0.9), mc * CFrame.new(0, 13.4, 0), dress, G)
	part(
		m,
		"Wheel",
		Vector3.new(0.7, 2.9, 2.9),
		mc * CFrame.new(0, 13.4, 0) * CFrame.Angles(0, math.rad(90), 0),
		dress,
		G
	).Shape =
		Enum.PartType.Cylinder
	part(
		m,
		"Wreath",
		Vector3.new(0.4, 1.8, 1.8),
		mc * CFrame.new(0, 3.6, 1.55) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(178, 28, 36),
		Enum.Material.Fabric
	).Shape =
		Enum.PartType.Cylinder
	-- flower bed (east): a round bed of mixed bedding
	local fc = Vector3.new(cx + mx, y, cz)
	part(
		m,
		"Bed",
		Vector3.new(0.5, 11, 11),
		CFrame.new(fc + Vector3.yAxis * 0.1) * up,
		Color3.fromRGB(74, 58, 42),
		Enum.Material.Fabric
	)
	for k = 0, 6 do
		local a = k * math.pi * 2 / 7
		local p = fc + Vector3.new(math.cos(a) * 3.4, 0.7, math.sin(a) * 3.4)
		local b = part(
			m,
			"Bedding",
			Vector3.new(2.6, 1.4, 2.6),
			CFrame.new(p),
			FLOWERS[k % #FLOWERS + 1],
			Enum.Material.Grass
		)
		b.Shape, b.CanCollide = Enum.PartType.Ball, false
	end
	-- parkland trees round the edge, clear of the paths
	local function clear(p: Vector3): boolean
		local function off(a: Vector3, b: Vector3): number
			local d = b - a
			local t = math.clamp((p - a):Dot(d) / d:Dot(d), 0, 1)
			return (p - (a + d * t)).Magnitude
		end
		return off(corners[1], corners[2]) > 9
			and off(corners[3], corners[4]) > 9
			and off(Vector3.new(cx, 0, w[4]), c) > 8
			and off(c - Vector3.xAxis * mx, c + Vector3.xAxis * mx) > 9
	end
	local trees = 0
	for t = 0, 1, 0.07 do
		for _, p in
			{
				Vector3.new(w[1] + (w[3] - w[1]) * t, 0, w[2] + 7),
				Vector3.new(w[1] + (w[3] - w[1]) * t, 0, w[4] - 7),
				Vector3.new(w[1] + 7, 0, w[2] + (w[4] - w[2]) * t),
				Vector3.new(w[3] - 7, 0, w[2] + (w[4] - w[2]) * t),
			}
		do
			if clear(p) and rnd(p.X, p.Z) < 0.55 then
				trees += 1
				tree(m, Vector3.new(p.X, y, p.Z), 1.4 + rnd(p.Z, p.X) * 0.6)
			end
		end
	end
	furnish(m, {
		{ "M_Road_Bench", Vector3.new(cx, 0, cz - 16), 180 },
		{ "M_Road_Bench", Vector3.new(cx - 18, 0, cz + 4), 0 },
		{ "M_Road_Bench", Vector3.new(cx + 18, 0, cz + 4), 0 },
		{ "M_Road_Bin", Vector3.new(cx + 3.5, 0, w[4] - 4), 0 },
		{ "M_Road_StreetLamp", Vector3.new(cx - 3.5, 0, w[4] - 6), 0 },
		{ "M_Road_StreetLamp", Vector3.new(cx + 3.5, 0, cz + 18), 0 },
	}, y)
	m:SetAttribute("Trees", trees)
end

-- the Fore Street car park and market: tarmac, a dwarf wall with two openings on Fore Street, two rows of white-lined
-- bays (parked cars), striped market stalls with produce on the east side, a pay machine, trees along the street
local CAR_IDS = { "M_Road_ParkedCar_01", "M_Road_ParkedCar_02", "M_Road_ParkedCar_03" }
local STALLS = {
	Color3.fromRGB(176, 40, 44),
	Color3.fromRGB(40, 80, 140),
	Color3.fromRGB(44, 110, 70),
	Color3.fromRGB(214, 160, 40),
}
local PRODUCE = {
	Color3.fromRGB(226, 120, 36),
	Color3.fromRGB(96, 150, 60),
	Color3.fromRGB(186, 40, 48),
	Color3.fromRGB(230, 200, 70),
	Color3.fromRGB(200, 200, 210),
	Color3.fromRGB(120, 70, 120),
}
local function market(parent: Instance, r: TownLayout.Rect, y0: number)
	local m = useModel(parent, "MarketCarPark")
	replace(r[1], r[2], r[3], r[4], y0, Enum.Material.Asphalt)
	local cx, cz = (r[1] + r[3]) / 2, (r[2] + r[4]) / 2
	local y = ground(cx, cz, y0)
	local w = { r[1] + 1, r[2] + 1, r[3] - 1, r[4] - 1 }
	local carGate, footGate = w[1] + 26, w[3] - 26
	boundary(
		m,
		w,
		y,
		1.4,
		false,
		{ [2] = { { carGate, 16 }, { footGate, 10 } }, [4] = { { cz, 8 } } }
	)
	-- bays: 8 wide, 14 deep; the north row noses to the wall, the second row across a 15-stud aisle
	local cars = 0
	local split = cx - 2 -- car park west of this x, market east
	for row, bz in { w[2] + 8, w[2] + 37 } do
		local x = w[1] + 3
		local k = 0
		while x + 8 <= split do
			part(
				m,
				"BayLine",
				Vector3.new(0.3, 0.06, 13),
				CFrame.new(x, y + 0.04, bz),
				WHITE_LINE,
				Enum.Material.SmoothPlastic
			)
			if rnd(x, row) > 0.3 then
				local id = CAR_IDS[(k + row) % #CAR_IDS + 1]
				local car = AssetLoader.cloneStatic(id, "LOD0", true)
				if car then
					CarPaint.apply(car, id, k * 3 + row)
					car:PivotTo(
						CFrame.new(x + 4, y, bz)
							* CFrame.Angles(0, if row == 1 then 0 else math.pi, 0)
					)
					car.Parent = m
					cars += 1
				end
			end
			x += 8
			k += 1
		end
		part(
			m,
			"BayLine",
			Vector3.new(0.3, 0.06, 13),
			CFrame.new(x, y + 0.04, bz),
			WHITE_LINE,
			Enum.Material.SmoothPlastic
		)
	end
	part(
		m,
		"PayMachine",
		Vector3.new(1.4, 5, 1),
		CFrame.new(carGate + 10, y + 2.5, w[4] - 2),
		Color3.fromRGB(60, 64, 72),
		Enum.Material.Metal
	)
	part(
		m,
		"PayMachineHood",
		Vector3.new(1.8, 0.4, 1.5),
		CFrame.new(carGate + 10, y + 5.2, w[4] - 2),
		Color3.fromRGB(30, 90, 150),
		Enum.Material.SmoothPlastic
	)
	-- stalls: two rows facing across a central aisle, a striped awning each
	local n = 0
	for row, sz in { w[2] + 9, w[4] - 15 } do
		local yaw = if row == 1 then math.pi else 0 -- local -Z (the front) toward the aisle
		local x = split + 8
		while x + 5 <= w[3] - 2 do
			n += 1
			local at = CFrame.new(x, y, sz) * CFrame.Angles(0, yaw, 0)
			local col = STALLS[n % #STALLS + 1]
			part(
				m,
				"Counter",
				Vector3.new(9, 3, 2.4),
				at * CFrame.new(0, 1.5, -2.2),
				col:Lerp(Color3.new(1, 1, 1), 0.55),
				Enum.Material.Fabric
			)
			for _, p in { { -4.4, -3.4 }, { 4.4, -3.4 }, { -4.4, 3.4 }, { 4.4, 3.4 } } do
				part(
					m,
					"Post",
					Vector3.new(0.3, 8, 0.3),
					at * CFrame.new(p[1], 4, p[2]),
					Color3.fromRGB(200, 200, 204),
					Enum.Material.Metal
				)
			end
			for k = 0, 2 do -- stripes: colour, white, colour
				part(
					m,
					"Awning",
					Vector3.new(3.2, 0.2, 8),
					at * CFrame.new(-3.2 + k * 3.2, 7.9, 0) * CFrame.Angles(math.rad(-9), 0, 0),
					if k == 1 then Color3.fromRGB(240, 238, 230) else col,
					Enum.Material.Fabric
				)
			end
			part(
				m,
				"Valance",
				Vector3.new(9.6, 0.9, 0.15),
				at * CFrame.new(0, 6.9, -4.05),
				col,
				Enum.Material.Fabric
			)
			for k = 0, 2 do
				part(
					m,
					"Produce",
					Vector3.new(2.4, 0.8, 1.6),
					at * CFrame.new(-2.8 + k * 2.8, 3.4, -2.2),
					PRODUCE[(n * 3 + k) % #PRODUCE + 1],
					Enum.Material.Fabric
				)
			end
			x += 12
		end
	end
	for _, tx in { w[1] + 6, carGate + 16, footGate - 12, w[3] - 6 } do
		tree(m, Vector3.new(tx, y, w[4] - 5), 1.2)
	end
	m:SetAttribute("Cars", cars)
	m:SetAttribute("Stalls", n)
end

-- allotments: a Cornish hedge with a gate on Trelawney Road, a grass track and cross path, 16 dug plots (8 x 20)
-- of soil with crop rows, sheds, greenhouses, water butts and compost bins; one or two left overgrown
local SHEDS = {
	Color3.fromRGB(70, 110, 76),
	Color3.fromRGB(214, 220, 206),
	Color3.fromRGB(56, 46, 40),
	Color3.fromRGB(76, 94, 112),
	SHED,
}
local CROPS =
	{ Color3.fromRGB(96, 150, 60), Color3.fromRGB(122, 172, 70), Color3.fromRGB(78, 132, 72) }
local function allotments(parent: Instance, r: TownLayout.Rect, y0: number)
	local m = useModel(parent, "Allotments")
	local cx, cz = (r[1] + r[3]) / 2, (r[2] + r[4]) / 2
	local y = ground(cx, cz, y0)
	local w = { r[1] + 1.5, r[2] + 1.5, r[3] - 1.5, r[4] - 1.5 }
	boundary(m, w, y, 2.2, true, { [2] = { { cx, 7 } } })
	-- the five-bar gate, swung open
	part(
		m,
		"Gate",
		Vector3.new(6, 3.4, 0.25),
		CFrame.new(cx - 3.5, y + 1.9, w[4])
			* CFrame.Angles(0, math.rad(-70), 0)
			* CFrame.new(3, 0, 0),
		Color3.fromRGB(140, 128, 108),
		Enum.Material.Wood
	)
	local plots = 0
	local xs = {}
	for k = 0, 3 do
		table.insert(xs, cx - 52 + k * 12)
		table.insert(xs, cx + 8 + k * 12)
	end
	for _, z0 in { cz - 25, cz + 3 } do
		for _, x0 in xs do
			local h = rnd(x0, z0)
			plots += 1
			local pc = Vector3.new(x0 + 4, y, z0 + 10)
			if h < 0.1 then -- overgrown: brambles
				for k = 1, 3 do
					local b = part(
						m,
						"Bramble",
						Vector3.one * (3 + k),
						CFrame.new(pc + Vector3.new((k - 2) * 2.5, 1, (k - 2) * 5)),
						Color3.fromRGB(52, 70, 44),
						Enum.Material.Grass
					)
					b.Shape, b.CanCollide = Enum.PartType.Ball, false
				end
				continue
			end
			-- a soil Part, not terrain paint: 8-stud plots smear to grass at the 4-stud voxel grid from the air
			part(
				m,
				"Soil",
				Vector3.new(8, 0.3, 20),
				CFrame.new(pc + Vector3.yAxis * 0.08),
				if h < 0.4 then Color3.fromRGB(70, 54, 40) else Color3.fromRGB(98, 78, 56),
				Enum.Material.Fabric
			).CanCollide =
				false
			local rows = 1 + math.floor(rnd(z0, x0) * 3)
			for k = 1, rows do
				part(
					m,
					"Crops",
					Vector3.new(1.3, 0.9 + (k % 2) * 0.5, 13),
					CFrame.new(pc + Vector3.new(-2.6 + (k - 1) * 2.6, 0.4, 2)),
					CROPS[(plots + k) % #CROPS + 1],
					Enum.Material.Grass
				).CanCollide =
					false
			end
			local nearPath = if z0 < cz then z0 + 20 else z0 -- the plot end on the cross path
			local s = if z0 < cz then -1 else 1 -- from the path into the plot
			if plots % 5 == 4 then -- bean canes: two rows of runner beans
				for _, bx in { -2.2, 2.2 } do
					part(
						m,
						"Beans",
						Vector3.new(0.5, 5, 12),
						CFrame.new(pc + Vector3.new(bx, 2.5, -2)),
						Color3.fromRGB(84, 128, 56),
						Enum.Material.Grass
					).CanCollide =
						false
				end
			end
			if plots % 2 == 0 then -- shed at the path end
				local at = CFrame.new(x0 + 4, y, nearPath + s * 3)
				local col = SHEDS[plots % #SHEDS + 1]
				part(
					m,
					"Shed",
					Vector3.new(5.4, 5.6, 4.4),
					at * CFrame.new(0, 2.8, 0),
					col,
					Enum.Material.Wood
				)
				part(
					m,
					"ShedRoof",
					Vector3.new(6.2, 0.35, 5.2),
					at * CFrame.new(0, 5.8, 0) * CFrame.Angles(math.rad(10 * s), 0, 0),
					Color3.fromRGB(40, 40, 44),
					Enum.Material.RoofShingles
				)
			elseif plots % 5 == 1 then -- greenhouse
				local g = part(
					m,
					"Greenhouse",
					Vector3.new(5.4, 5, 6.6),
					CFrame.new(x0 + 4, y + 2.5, nearPath + s * 4),
					Color3.fromRGB(196, 214, 210),
					Enum.Material.Glass
				)
				g.Transparency = 0.45
				part(
					m,
					"GreenhouseRidge",
					Vector3.new(0.3, 0.3, 6.8),
					CFrame.new(x0 + 4, y + 5.1, nearPath + s * 4),
					Color3.fromRGB(236, 236, 232),
					Enum.Material.SmoothPlastic
				)
			end
			if plots % 2 == 0 then
				part(
					m,
					"WaterButt",
					Vector3.new(3, 2.2, 2.2),
					CFrame.new(x0 + 7, y + 1.5, nearPath + s * 1.5)
						* CFrame.Angles(0, 0, math.rad(90)),
					Color3.fromRGB(36, 50, 40),
					Enum.Material.SmoothPlastic
				).Shape =
					Enum.PartType.Cylinder
			end
			if plots % 4 == 3 then
				part(
					m,
					"Compost",
					Vector3.new(3, 2.4, 3),
					CFrame.new(x0 + 6, y + 1.2, nearPath + s * 17),
					SHED,
					Enum.Material.Wood
				)
			end
		end
	end
	m:SetAttribute("Plots", plots)
end

-- the board school: the granite school itself is a TownLayout landmark (TownBuildings "School") on the north side;
-- here the tarmac playground with a painted court and hopscotch, swings and a climbing frame with a slide on the
-- grass, a prefab classroom, a wall with green railings and a gate on Trelawney Road, trees
local function school(parent: Instance, r: TownLayout.Rect, y0: number)
	local m = useModel(parent, "SchoolGrounds")
	local cx, cz = (r[1] + r[3]) / 2, (r[2] + r[4]) / 2
	local y = ground(cx, cz, y0)
	local w = { r[1] + 1, r[2] + 1, r[3] - 1, r[4] - 1 }
	boundary(m, w, y, 1.4, false, { [2] = { { cx - 20, 8 } } }, Color3.fromRGB(36, 70, 50))
	local px1 = w[3] - 30 -- the playground runs to here; grass play area beyond
	replace(w[1] + 2, cz, px1, w[4] - 2, y0, Enum.Material.Asphalt)
	-- court lines
	local ccx, ccz, cw, cd = (w[1] + px1) / 2 - 6, (cz + w[4]) / 2 + 1, 54, 22
	local function line(x: number, z: number, sx: number, sz: number, col: Color3?)
		part(
			m,
			"CourtLine",
			Vector3.new(sx, 0.06, sz),
			CFrame.new(x, y + 0.16, z),
			col or WHITE_LINE,
			Enum.Material.SmoothPlastic
		).CanCollide =
			false
	end
	-- the court on a green sports surface: it reads as a school from the air
	part(
		m,
		"Court",
		Vector3.new(cw + 3, 0.2, cd + 3),
		CFrame.new(ccx, y + 0.02, ccz),
		Color3.fromRGB(58, 118, 84),
		Enum.Material.SmoothPlastic
	).CanCollide =
		false
	line(ccx, ccz - cd / 2, cw, 0.4)
	line(ccx, ccz + cd / 2, cw, 0.4)
	line(ccx - cw / 2, ccz, 0.4, cd)
	line(ccx + cw / 2, ccz, 0.4, cd)
	line(ccx - cw / 6, ccz, 0.4, cd)
	line(ccx + cw / 6, ccz, 0.4, cd)
	-- hopscotch: 1, 2-1, 2-1-2 squares in four colours
	local hop =
		{ { 0, 0 }, { 0, 1 }, { -0.5, 2 }, { 0.5, 2 }, { 0, 3 }, { -0.5, 4 }, { 0.5, 4 }, { 0, 5 } }
	local paint = {
		Color3.fromRGB(230, 196, 60),
		Color3.fromRGB(200, 60, 60),
		Color3.fromRGB(60, 110, 190),
		Color3.fromRGB(70, 160, 90),
	}
	for k, h in hop do
		line(ccx + cw / 2 + 8 + h[1] * 2.6, w[4] - 5 - h[2] * 2.6, 2.4, 2.4, paint[k % #paint + 1])
	end
	-- swings: an A-frame each end, top bar, two seats on chains
	local sw = CFrame.new(px1 + 10, y, cz + 8)
	local frame = Color3.fromRGB(40, 90, 150)
	for _, ex in { -5, 5 } do
		for _, lean in { -1, 1 } do
			part(
				m,
				"SwingLeg",
				Vector3.new(0.4, 7.6, 0.4),
				sw * CFrame.new(ex, 3.6, lean * 1.1) * CFrame.Angles(math.rad(lean * 16), 0, 0),
				frame,
				Enum.Material.Metal
			)
		end
	end
	part(
		m,
		"SwingBar",
		Vector3.new(10.6, 0.4, 0.4),
		sw * CFrame.new(0, 7.3, 0),
		frame,
		Enum.Material.Metal
	)
	for _, sx in { -2.4, 2.4 } do
		part(
			m,
			"Seat",
			Vector3.new(1.8, 0.25, 0.8),
			sw * CFrame.new(sx, 1.8, 0),
			Color3.fromRGB(30, 30, 32),
			Enum.Material.SmoothPlastic
		)
		for _, cxk in { -0.8, 0.8 } do
			part(
				m,
				"Chain",
				Vector3.new(0.08, 5.4, 0.08),
				sw * CFrame.new(sx + cxk, 4.5, 0),
				Color3.fromRGB(150, 150, 156),
				Enum.Material.Metal
			).CanCollide =
				false
		end
	end
	-- climbing frame: four posts, a deck, a pitched roof, a yellow slide down to the south
	local cf = CFrame.new(px1 + 14, y, w[4] - 9)
	local wood = Color3.fromRGB(150, 112, 74)
	for _, p in { { -2.6, -2.6 }, { 2.6, -2.6 }, { -2.6, 2.6 }, { 2.6, 2.6 } } do
		part(
			m,
			"FramePost",
			Vector3.new(0.5, 8, 0.5),
			cf * CFrame.new(p[1], 4, p[2]),
			wood,
			Enum.Material.Wood
		)
	end
	part(m, "Deck", Vector3.new(6, 0.4, 6), cf * CFrame.new(0, 3.6, 0), wood, Enum.Material.Wood)
	gable(m, cf, 6.4, 3.4, 1.8, 8, Color3.fromRGB(180, 50, 50))
	part(
		m,
		"Slide",
		Vector3.new(2, 0.3, 8.4),
		cf
			* CFrame.new(-6.6, 2, 0)
			* CFrame.Angles(0, math.rad(90), 0)
			* CFrame.Angles(math.rad(-25), 0, 0),
		Color3.fromRGB(236, 196, 50),
		Enum.Material.SmoothPlastic
	)
	-- prefab classroom on blocks (north-east corner) and trees
	local pc = CFrame.new(w[3] - 15, y, w[2] + 9)
	part(
		m,
		"Classroom",
		Vector3.new(24, 8.4, 11),
		pc * CFrame.new(0, 4.9, 0),
		Color3.fromRGB(176, 196, 170),
		Enum.Material.Plaster
	)
	part(
		m,
		"ClassroomRoof",
		Vector3.new(24.8, 0.5, 11.8),
		pc * CFrame.new(0, 9.3, 0),
		Color3.fromRGB(70, 74, 78),
		Enum.Material.Metal
	)
	part(
		m,
		"ClassroomGlass",
		Vector3.new(18, 3.2, 11.2),
		pc * CFrame.new(0, 5.6, 0),
		Color3.fromRGB(38, 48, 58),
		Enum.Material.Glass
	)
	for _, t in
		{
			{ w[1] + 6, w[4] - 6 },
			{ w[1] + 5, cz + 10 },
			{ w[3] - 6, w[4] - 6 },
			{ px1 + 2, cz - 6 },
		}
	do
		tree(m, Vector3.new(t[1], y, t[2]), 1.3)
	end
end

local USE_BUILDERS: { [string]: (Instance, TownLayout.Rect, number) -> () } = {
	Churchyard = churchyard,
	Green = green,
	Market = market,
	Allotments = allotments,
	School = school,
}

-- farmsteads (layout.py FARMS: gravel yards flattened in the bake): a granite farmhouse (a 2-storey terrace build)
-- on the yard's north side facing into it, a granite barn under a grey-green corrugated roof on its east side, and a
-- granite yard wall with a gate gap on the south. (The boatyard-shed mesh barn read as a giant white slab.)
local BARN = { len = 40, wide = 22, h = 9, pitch = 0.45, roof = Color3.fromRGB(100, 108, 102) }
-- a granite barn (spec len x wide x h) under a corrugated roof of two wedges (their ends close the gables), a timber
-- door on its -Z side; `at` on the ground at its centre
local function barn(parent: Instance, name: string, at: CFrame, b: typeof(BARN)): Model
	local m = Instance.new("Model")
	m.Name = name
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	part(
		m,
		"Walls",
		Vector3.new(b.len, b.h, b.wide),
		at * CFrame.new(0, b.h / 2, 0),
		STONE,
		Enum.Material.Granite
	)
	local run = b.wide / 2 + 1
	local rise = run * b.pitch
	for _, sz in { -1, 1 } do
		local w = Instance.new("WedgePart")
		w.Name = "Roof"
		w.Anchored = true
		w.Size = Vector3.new(b.len + 1.6, rise, run)
		w.CFrame = at
			* CFrame.new(0, b.h + rise / 2, sz * run / 2)
			* CFrame.Angles(0, if sz < 0 then 0 else math.pi, 0)
		w.Color, w.Material = b.roof, Enum.Material.Metal
		w.Parent = m
	end
	part(
		m,
		"Door",
		Vector3.new(math.min(12, b.len / 3), b.h, 0.4),
		at * CFrame.new(0, b.h / 2, -b.wide / 2 - 0.2),
		SHED,
		Enum.Material.Wood
	)
	m.Parent = parent
	return m
end

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
		-- barn X runs along the yard's Z; barn -Z faces into the yard
		barn(
			folder,
			`{f.id}_Barn`,
			yard * CFrame.new(hx - BARN.wide / 2 - 4, 0, 4) * CFrame.Angles(0, math.pi / 2, 0),
			BARN
		)
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

-- Outskirts: Port Haven's grid would end in a hard rectangle on its flat platform, so the town bleeds into the
-- country round it: a ragged ribbon of bungalows, cottages and villas on the outer side of the edge streets
-- (St4's north side, Av1's west side, Av7's east side), cottages, a Bethel chapel and a hill farm strung up
-- TownLane (Chapel Hill), two smallholdings, a caravan park on the east side toward Haven Sands, and small irregular
-- fields between them (ploughed / meadow / pasture terrain paint) inside Cornish hedges (the RoadsShore
-- M_Road_CornishHedge kit, ground-following), with field gates, hedgerow trees and windbreaks. Nothing goes inside
-- the grid, on a road, or near a gameplay point. Each house: front garden (frontGarden) and a hedged back garden.
-- house kinds: cottage (M_Bld_Cottage_0n `v`, code-built house if the ground is not level), bungalow (1 storey),
-- house (2 storeys), endon, chapel. look: the point the front faces. lane: { s, side (1 east), off } on TownLane.
type OutHouse = {
	kind: string,
	w: number,
	d: number?,
	v: number?,
	at: { number }?,
	look: { number }?,
	lane: { number }?,
}
local OUT_HOUSES: { OutHouse } = {
	-- outlying cottages on the hill behind the town, facing down to it
	{ kind = "house", w = 22, at = { -186, -664 }, look = { -186, -500 } },
	{ kind = "house", w = 24, at = { 250, -722 }, look = { 250, -500 } },
	{ kind = "house", w = 22, at = { -330, -684 }, look = { -330, -500 } },
	-- Av1's west side and Av7's east side
	{ kind = "bungalow", w = 24, at = { -577, -215 }, look = { -540, -215 } },
	{ kind = "house", w = 20, at = { -578, -248 }, look = { -540, -248 } },
	{ kind = "house", w = 22, at = { -578, -318 }, look = { -540, -318 } },
	{ kind = "bungalow", w = 24, at = { -577, -432 }, look = { -540, -432 } },
	{ kind = "bungalow", w = 24, at = { 597, -362 }, look = { 560, -362 } },
	{ kind = "house", w = 22, at = { 598, -395 }, look = { 560, -395 } },
	{ kind = "bungalow", w = 24, at = { 597, -462 }, look = { 560, -462 } },
	{ kind = "bungalow", w = 26, at = { 597, -528 }, look = { 560, -528 } },
	-- up Chapel Hill (TownLane), set back behind front gardens; the steep middle stretch is left to the fields
	{ kind = "cottage", v = 4, w = 22, lane = { 52, 1, 25 } },
	{ kind = "bungalow", w = 24, lane = { 80, -1, 25 } },
	{ kind = "house", w = 22, lane = { 114, 1, 26 } },
	{ kind = "house", w = 20, lane = { 236, -1, 26 } },
	{ kind = "bungalow", w = 24, lane = { 272, 1, 25 } },
	{ kind = "house", w = 24, lane = { 286, -1, 27 } },
	{ kind = "endon", w = 16, d = 22, lane = { 300, 1, 28 } },
	{ kind = "chapel", w = 24, d = 30, lane = { 324, -1, 30 } },
	-- smallholdings
	{ kind = "house", w = 24, at = { -672, -282 }, look = { -672, -200 } },
	{ kind = "house", w = 22, at = { 652, -424 }, look = { 560, -424 } },
}

-- fields: corners { x, z } in order round, paint = the ground material (nil: leave the pasture), gate = the edge
-- (k: corner k to k + 1) that gets a field gate
local GROUND, MEADOW = Enum.Material.Ground, Enum.Material.LeafyGrass
local OUT_FIELDS: { { corners: { { number } }, paint: Enum.Material?, gate: number? } } = {
	-- north, behind St4's back gardens (the town's parts end at z -547)
	{
		corners = {
			{ -592, -530 },
			{ -528, -532 },
			{ -526, -578 },
			{ -432, -580 },
			{ -424, -648 },
			{ -592, -640 },
		},
		paint = GROUND,
		gate = 1,
	},
	{ corners = { { -418, -582 }, { -268, -576 }, { -262, -646 }, { -412, -652 } }, gate = 1 },
	{
		corners = { { -252, -578 }, { -104, -584 }, { -100, -646 }, { -248, -650 } },
		paint = MEADOW,
		gate = 4,
	},
	{
		corners = { { -92, -588 }, { -14, -585 }, { 24, -658 }, { -10, -700 }, { -90, -652 } },
		paint = GROUND,
		gate = 2,
	},
	{
		corners = { { 22, -670 }, { 74, -728 }, { 98, -772 }, { 48, -806 }, { -8, -716 } },
		gate = 1,
	},
	{
		corners = { { 132, -592 }, { 304, -578 }, { 312, -650 }, { 224, -702 }, { 178, -648 } },
		paint = GROUND,
		gate = 2,
	},
	{ corners = { { 322, -580 }, { 456, -574 }, { 460, -644 }, { 324, -654 } }, gate = 4 },
	{
		corners = {
			{ 468, -576 },
			{ 536, -574 },
			{ 542, -538 },
			{ 592, -536 },
			{ 596, -636 },
			{ 470, -646 },
		},
		paint = MEADOW,
		gate = 5,
	},
	-- west and east of the grid
	{
		corners = { { -612, -162 }, { -760, -168 }, { -765, -262 }, { -612, -258 } },
		paint = GROUND,
		gate = 4,
	},
	{
		corners = { { -618, -372 }, { -768, -366 }, { -772, -462 }, { -620, -458 } },
		paint = MEADOW,
		gate = 4,
	},
	{ corners = { { -612, -470 }, { -770, -476 }, { -776, -575 }, { -608, -580 } }, gate = 4 },
	{
		corners = { { 614, -338 }, { 738, -334 }, { 736, -392 }, { 676, -396 } },
		paint = MEADOW,
		gate = 1,
	},
	{
		corners = { { 612, -510 }, { 742, -506 }, { 746, -580 }, { 610, -588 } },
		paint = GROUND,
		gate = 1,
	},
}

-- farm sheds { x, z, yaw degrees, len, wide }; farmyards painted Ground { x0, z0, x1, z1 }
local OUT_BARNS = {
	{ -360, -612, 4, 34, 16 },
	{ 52, -745, 35, 34, 16 },
	{ -725, -318, 90, 40, 22 },
	{ -690, -352, 0, 26, 12 },
	{ 708, -440, 90, 40, 22 },
	{ 690, -492, 0, 26, 12 },
	{ 420, -612, -6, 28, 14 },
}
local OUT_YARDS = { { -705, -340, -640, -300 }, { 640, -480, 690, -440 } }
-- the caravan park beside Av7 toward Haven Sands: hedged rect { x0, z0, x1, z1 }, a gravel track in from Av7's
-- footway at z `track`, rows of static caravans either side of it
local CARAVANS =
	{ rect = { 612, -322, 736, -174 }, track = -248, rows = { -200, -224, -272, -296 } }
-- windbreaks { x0, z0, x1, z1, trees } (dark pines)
local WINDBREAKS = {
	{ 616, -330, 734, -330, 7 },
	{ -778, -480, -780, -570, 5 },
	{ 476, -652, 590, -644, 6 },
	{ -760, -270, -760, -360, 4 },
}
-- copses on the slopes behind the town { x, z, trees, radius }
local COPSES = {
	{ -470, -700, 6, 26 },
	{ -150, -722, 5, 22 },
	{ 395, -700, 7, 28 },
	{ 560, -690, 4, 18 },
	{ -660, -620, 6, 24 },
	{ 700, -620, 5, 22 },
	{ -20, -780, 4, 18 },
}
local PINE = Color3.fromRGB(44, 64, 46)
local CARAVAN_TRIM = {
	Color3.fromRGB(64, 112, 150),
	Color3.fromRGB(120, 132, 92),
	Color3.fromRGB(150, 110, 70),
	Color3.fromRGB(96, 98, 104),
}

local HEDGE_ASSET, HEDGE_LEN = "M_Road_CornishHedge", 15 -- the kit's module is 15 studs long (local X)

-- Cornish hedge modules from a to b (XZ), each pitched to the ground at its two ends (as RoadsShore.hedgePiece);
-- skip(k, n): leave module k of n out (a gate gap)
local function hedgeLine(
	m: Instance,
	a: Vector3,
	b: Vector3,
	skip: ((number, number) -> boolean)?
): number
	local d = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local len = d.Magnitude
	if len < 4 then
		return 0
	end
	local n = math.max(1, math.ceil(len / HEDGE_LEN))
	local step, dir = len / n, d.Unit
	local yaw = math.atan2(dir.Z, -dir.X) -- local -X along dir
	local placed = 0
	for k = 1, n do
		if not (skip and skip(k, n)) then
			local c = Vector3.new(a.X, 0, a.Z) + dir * (step * (k - 0.5))
			local p0, p1 = c - dir * step / 2, c + dir * step / 2
			local y0, y1 = ground(p0.X, p0.Z, 10), ground(p1.X, p1.Z, 10)
			local piece = AssetLoader.cloneStatic(HEDGE_ASSET, "LOD0")
			if piece then
				-- local +X is -dir, so a positive roll lifts the p0 end
				piece:PivotTo(
					CFrame.new(c.X, (y0 + y1) / 2 + 0.02, c.Z)
						* CFrame.Angles(0, yaw, 0)
						* CFrame.Angles(0, 0, math.atan2(y0 - y1, step))
				)
				piece.Parent = m
				placed += 1
			end
		end
	end
	return placed
end

-- a field gate (M_Road_FieldGate) standing in a hedge gap at c, along dir
local function fieldGate(m: Instance, c: Vector3, dir: Vector3)
	local g = AssetLoader.cloneStatic("M_Road_FieldGate", "LOD0")
	if g then
		g:PivotTo(
			CFrame.new(c.X, ground(c.X, c.Z, 10) + 0.02, c.Z)
				* CFrame.Angles(0, math.atan2(dir.Z, -dir.X), 0)
		)
		g.Parent = m
	end
end

-- paint the terrain inside a polygon (XZ corners) with `mat`: 4-stud scanlines inset 4 from the edges, cut in
-- 32-stud runs so each region follows the slope
local PAINT_FROM = { Enum.Material.Grass, Enum.Material.LeafyGrass, Enum.Material.Ground }
local function paintPolygon(corners: { Vector3 }, mat: Enum.Material)
	local z0, z1 = math.huge, -math.huge
	for _, c in corners do
		z0, z1 = math.min(z0, c.Z), math.max(z1, c.Z)
	end
	for z = z0 + 4, z1 - 4, 4 do
		local xs = {}
		for i, a in corners do
			local b = corners[i % #corners + 1]
			if (a.Z <= z) ~= (b.Z <= z) then
				table.insert(xs, a.X + (z - a.Z) / (b.Z - a.Z) * (b.X - a.X))
			end
		end
		table.sort(xs)
		for i = 1, #xs - 1, 2 do
			local x, x1 = xs[i] + 4, xs[i + 1] - 4
			while x < x1 do
				local xe = math.min(x + 32, x1)
				local gy = ground((x + xe) / 2, z, 10)
				local region =
					Region3.new(Vector3.new(x, gy - 10, z - 2), Vector3.new(xe, gy + 8, z + 2))
						:ExpandToGrid(4)
				for _, from in PAINT_FROM do
					if from ~= mat then
						Workspace.Terrain:ReplaceMaterial(region, 4, from, mat)
					end
				end
				x = xe
			end
		end
	end
end

-- a static caravan: long body on local X, a coloured band, window strip, pale roof, skirt, drawbar at -X, steps at -Z
local function caravan(m: Instance, cf: CFrame, k: number)
	local SP = Enum.Material.SmoothPlastic
	part(
		m,
		"Body",
		Vector3.new(24, 7, 9),
		cf * CFrame.new(0, 4.6, 0),
		Color3.fromRGB(232, 230, 220),
		SP
	)
	part(
		m,
		"Roof",
		Vector3.new(24.4, 0.5, 9.4),
		cf * CFrame.new(0, 8.3, 0),
		Color3.fromRGB(196, 196, 190),
		SP
	)
	part(
		m,
		"Band",
		Vector3.new(24.1, 0.9, 9.1),
		cf * CFrame.new(0, 2.6, 0),
		CARAVAN_TRIM[k % #CARAVAN_TRIM + 1],
		SP
	)
	local glass = part(
		m,
		"Windows",
		Vector3.new(18, 1.8, 9.1),
		cf * CFrame.new(1, 5.6, 0),
		Color3.fromRGB(40, 48, 56),
		Enum.Material.Glass
	)
	glass.Reflectance = 0.15
	part(
		m,
		"Skirt",
		Vector3.new(23, 1.2, 8.4),
		cf * CFrame.new(0, 0.6, 0),
		Color3.fromRGB(110, 110, 106),
		SP
	)
	part(
		m,
		"Drawbar",
		Vector3.new(3, 0.5, 2),
		cf * CFrame.new(-13.4, 1.2, 0),
		Color3.fromRGB(70, 70, 72),
		Enum.Material.Metal
	)
	part(
		m,
		"Steps",
		Vector3.new(2.4, 1.2, 1.6),
		cf * CFrame.new(4, 0.6, -5.2),
		STONE,
		Enum.Material.Granite
	)
end

-- a timber shed with a felt gable roof on the ground at p, turned like `rot`
local function gardenShed(m: Instance, p: Vector3, rot: CFrame)
	local sc = CFrame.new(p.X, ground(p.X, p.Z, 10), p.Z) * rot
	part(m, "Shed", Vector3.new(6, 5, 5), sc * CFrame.new(0, 2.5, 0), SHED, Enum.Material.Wood)
	gable(m, sc, 6.6, 3, 1.4, 5, Color3.fromRGB(60, 64, 60))
end

-- a hedged plot behind a house, in frame `at` (local +Z away from the street): the back hedge at z1 across x0..x1,
-- side hedges from z0 out to z1; a tree in every other one (k), a timber shed in every third
local function backPlot(
	m: Instance,
	at: CFrame,
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	k: number
)
	local function w(x: number, z: number): Vector3
		return at * Vector3.new(x, 0, z)
	end
	hedgeLine(m, w(x0, z0), w(x0, z1))
	hedgeLine(m, w(x0, z1), w(x1, z1))
	hedgeLine(m, w(x1, z1), w(x1, z0))
	if k % 2 == 0 then
		local p = w(x1 - (x1 - x0) * 0.22, z1 - 6)
		tree(m, Vector3.new(p.X, ground(p.X, p.Z, 10), p.Z), 1 + (k % 3) * 0.15)
	end
	if k % 3 == 1 then
		gardenShed(m, w(x0 + 5, z1 - 5), at.Rotation)
	end
end

-- The row on the town's last street (St4's north side) backs straight onto the fields: hedged back gardens in runs
-- of two or three houses at seeded depths (one run in five has none), the hedge between two runs as long as the
-- deeper garden, trees and sheds in some. Returns the number of runs.
local function rowGardens(parent: Instance, lots: { TownLayout.Lot }, zEdge: number): number
	local row: { TownLayout.Lot } = {}
	for _, lot in lots do
		if lot.cf.Z < zEdge and lot.face.Z > 0.5 then
			table.insert(row, lot)
		end
	end
	table.sort(row, function(a, b)
		return a.cf.X < b.cf.X
	end)
	local runs = {}
	local i = 1
	while i <= #row do
		local j = i
		local size = 2 + math.floor(TownLayout.hash(row[i].cf.X, 3.7) * 2)
		while
			j < #row
			and j - i + 1 < size
			and row[j + 1].cf.X - row[j + 1].w / 2 - (row[j].cf.X + row[j].w / 2) < 4
		do
			j += 1
		end
		local zb = math.huge -- the deepest house back (north = -Z)
		for k = i, j do
			zb = math.min(zb, row[k].cf.Z - row[k].depth / 2)
		end
		local hs = TownLayout.hash(row[i].cf.X, 9.1)
		table.insert(runs, {
			x0 = row[i].cf.X - row[i].w / 2,
			x1 = row[j].cf.X + row[j].w / 2,
			zb = zb,
			g = if hs < 0.2 then 0 else 12 + hs * 22,
			hs = hs,
		})
		i = j + 1
	end
	local m = Instance.new("Model")
	m.Name = "RowGardens"
	m.ModelStreamingMode = Enum.ModelStreamingMode.Nonatomic
	m.Parent = parent
	for k, r in runs do
		local gm = Instance.new("Model")
		gm.Name = `RowGarden{k}`
		gm.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		gm.Parent = m
		local prev, nxt = runs[k - 1], runs[k + 1]
		local zb = r.zb
		if r.g > 0 then
			hedgeLine(gm, Vector3.new(r.x0, 0, zb - r.g), Vector3.new(r.x1, 0, zb - r.g))
		end
		-- the left boundary: shared with an adjacent run (as deep as the deeper of the two), else this run's own
		if prev and r.x0 - prev.x1 < 4 then
			local len = math.max(r.g, prev.g)
			local x = (prev.x1 + r.x0) / 2
			if len > 0 then
				hedgeLine(
					gm,
					Vector3.new(x, 0, math.max(zb, prev.zb)),
					Vector3.new(x, 0, math.min(zb - r.g, prev.zb - prev.g))
				)
			end
		elseif r.g > 0 then
			hedgeLine(gm, Vector3.new(r.x0, 0, zb), Vector3.new(r.x0, 0, zb - r.g))
		end
		if r.g > 0 and not (nxt and nxt.x0 - r.x1 < 4) then
			hedgeLine(gm, Vector3.new(r.x1, 0, zb), Vector3.new(r.x1, 0, zb - r.g))
		end
		if r.g > 16 and r.hs > 0.35 then
			local x, z = r.x1 - 7, zb - r.g + 7
			tree(gm, Vector3.new(x, ground(x, z, 10), z), 1.1 + r.hs * 0.4)
		end
		if r.g > 16 and r.hs < 0.6 then
			gardenShed(gm, Vector3.new(r.x0 + 6, 0, zb - r.g + 5), CFrame.Angles(0, math.pi, 0))
		end
	end
	return #runs
end

local function outskirts(parent: Instance): number
	local root = Instance.new("Model")
	root.Name = "Outskirts"
	root.ModelStreamingMode = Enum.ModelStreamingMode.Nonatomic
	root.Parent = parent
	local lane: { Vector3 } = {}
	for _, r in WorldConfig.Roads do
		if r.id == "TownLane" then
			lane = r.points
		end
	end
	local count = 0
	local function v(c: { number }): Vector3
		return Vector3.new(c[1], 0, c[2])
	end
	local houses = Instance.new("Model")
	houses.Name = "Houses"
	houses.ModelStreamingMode = Enum.ModelStreamingMode.Nonatomic
	houses.Parent = root
	for i, h in OUT_HOUSES do
		local n = 900 + i * 7 -- seeds the terrace style / render / garden so neighbours differ
		local d = h.d or (if h.kind == "cottage" then TownLayout.DEPTH else 14)
		local c, look
		if h.lane then
			local s = StreetLayout.walk(lane, 1e6, h.lane[1], h.lane[1])[1]
			if not s then
				continue
			end
			c = StreetLayout.offset(s, h.lane[2], h.lane[3] + d / 2)
			look = s.pos
		else
			c, look = v(h.at :: { number }), v(h.look :: { number })
		end
		local cf = CFrame.lookAt(Vector3.new(c.X, 0, c.Z), Vector3.new(look.X, 0, look.Z)) -- -Z: the front
		local lo, hi = math.huge, -math.huge
		for _, o in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 }, { 0, 0 } } do
			local p = cf * Vector3.new(o[1] * h.w / 2, 0, o[2] * d / 2)
			local gy = ground(p.X, p.Z, 10)
			lo, hi = math.min(lo, gy), math.max(hi, gy)
		end
		if hi - lo > 8 then
			warn(`[Town] outskirts house {i}: ground too steep ({hi - lo})`)
			continue
		end
		local lot: any = {
			cf = cf,
			w = h.w,
			depth = d,
			floors = if h.kind == "bungalow" then 1 else 2,
			corner = false,
			shop = false,
			front = if h.kind == "chapel" then 4 else 6,
			kind = if h.kind == "endon" or h.kind == "chapel" then h.kind else nil,
		}
		local model: Instance? = nil
		local asset = h.kind == "cottage" and hi - lo <= 1.5
		if asset then
			local id = string.format("M_Bld_Cottage_%02d", h.v :: number)
			model = cottage(houses, id, TownLayout.RENDERS[i % #TownLayout.RENDERS + 1], cf, n, hi)
		end
		if not model then
			asset = false
			local ok, res = pcall(TownBuildings.terrace, houses, lot, n, lo, hi)
			if not ok then
				warn(`[Town] outskirts house {i}: {res}`)
				continue
			end
			model = res
		end
		local m = model :: Instance
		m.Name = `Out_{h.kind}{i}`
		local doorX = if asset
			then COTTAGE_DOOR[h.v :: number] or 0
			elseif h.kind == "chapel" then 0
			else -h.w / 4
		frontGarden(m, lot, n, hi, doorX, -d / 2, i % 3 == 0)
		if h.kind ~= "chapel" then
			local at = CFrame.new(c.X, hi, c.Z) * cf.Rotation
			backPlot(m, at, -h.w / 2 - 3, h.w / 2 + 3, d / 2, d / 2 + 22, i)
		end
		count += 1
	end
	local fields = Instance.new("Model")
	fields.Name = "Fields"
	fields.ModelStreamingMode = Enum.ModelStreamingMode.Nonatomic
	fields.Parent = root
	for i, f in OUT_FIELDS do
		local m = Instance.new("Model")
		m.Name = `Field{i}`
		m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		m.Parent = fields
		local cs: { Vector3 } = {}
		for _, c in f.corners do
			table.insert(cs, v(c))
		end
		local paint = f.paint
		if paint then
			local ok, err = pcall(function()
				paintPolygon(cs, paint)
			end)
			if not ok then
				warn(`[Town] outskirts field {i} paint: {err}`)
			end
		end
		for k, a in cs do
			local b = cs[k % #cs + 1]
			if k == f.gate then
				local nn = math.max(1, math.ceil((b - a).Magnitude / HEDGE_LEN))
				local gap = math.ceil(nn / 2)
				hedgeLine(m, a, b, function(j: number): boolean
					return j == gap
				end)
				fieldGate(m, a + (b - a) * ((gap - 0.5) / nn), (b - a).Unit)
			else
				hedgeLine(m, a, b)
			end
			-- hedgerow trees: on every other corner, and now and then along the bank
			local len = (b - a).Magnitude
			for t = 3, len - 3, 40 do
				if
					(t == 3 and (i + k) % 2 == 0)
					or (t > 3 and TownLayout.hash(a.X + t, a.Z + i) < 0.3)
				then
					local p = a + (b - a).Unit * t
					tree(
						m,
						Vector3.new(p.X, ground(p.X, p.Z, 10), p.Z),
						1.1 + TownLayout.hash(p.X, k) * 0.5
					)
				end
			end
		end
		count += 1
		task.wait()
	end
	for i, b in OUT_BARNS do
		local gy = ground(b[1], b[2], 10)
		local spec = {
			len = b[4],
			wide = b[5],
			h = if b[5] > 16 then 9 else 7,
			pitch = 0.4,
			roof = BARN.roof,
		}
		barn(
			root,
			`OutBarn{i}`,
			CFrame.new(b[1], gy, b[2]) * CFrame.Angles(0, math.rad(b[3]), 0),
			spec
		)
		count += 1
	end
	for _, y in OUT_YARDS do
		pcall(
			paintPolygon,
			{ v({ y[1], y[2] }), v({ y[3], y[2] }), v({ y[3], y[4] }), v({ y[1], y[4] }) },
			GROUND
		)
	end
	-- the caravan park: hedge with an entrance on the track, caravans with their doors to the track
	local cp = Instance.new("Model")
	cp.Name = "CaravanPark"
	cp.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	cp.Parent = root
	local r = CARAVANS.rect
	local corners = { v({ r[1], r[2] }), v({ r[3], r[2] }), v({ r[3], r[4] }), v({ r[1], r[4] }) }
	for k, a in corners do
		local b = corners[k % 4 + 1]
		hedgeLine(cp, a, b, function(j: number, n: number): boolean
			return k == 4 and math.abs(a.Z + (b.Z - a.Z) * (j - 0.5) / n - CARAVANS.track) < 9
		end)
	end
	local ty = ground(600, CARAVANS.track, 10)
	strip(
		cp,
		"Track",
		Vector3.new(584, 0, CARAVANS.track),
		Vector3.new(r[3] - 6, 0, CARAVANS.track),
		9,
		ty,
		GRAVEL
	)
	for k, z in CARAVANS.rows do
		for j = 0, 3 do
			local x = r[1] + 18 + j * 30 + (if k % 2 == 0 then 6 else 0)
			local yaw = if z < CARAVANS.track then math.pi else 0
			caravan(cp, CFrame.new(x, ground(x, z, 10), z) * CFrame.Angles(0, yaw, 0), k * 4 + j)
		end
	end
	count += 1
	for i, wb in WINDBREAKS do
		local m = Instance.new("Model")
		m.Name = `Windbreak{i}`
		m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		m.Parent = root
		for k = 0, wb[5] - 1 do
			local t = k / math.max(1, wb[5] - 1)
			local x, z = wb[1] + (wb[3] - wb[1]) * t, wb[2] + (wb[4] - wb[2]) * t
			tree(m, Vector3.new(x, ground(x, z, 10), z), 1.5 + TownLayout.hash(x, z) * 0.4, PINE)
		end
	end
	for i, c in COPSES do
		local m = Instance.new("Model")
		m.Name = `Copse{i}`
		m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		m.Parent = root
		for k = 1, c[3] do
			local a, d = k * 2.4 + i, c[4] * math.sqrt(TownLayout.hash(i, k))
			local x, z = c[1] + math.cos(a) * d, c[2] + math.sin(a) * d
			local crown = if k % 3 == 0 then YEW else nil
			tree(m, Vector3.new(x, ground(x, z, 10), z), 1.4 + TownLayout.hash(k, i) * 0.7, crown)
		end
	end
	return count
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
		for n, lot in lots do
			local D = lot.depth
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
			local model = if y then cottage(folder, lot.asset, lot.render, lot.cf, n, y) else nil
			if model then
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
		local _, zs = TownLayout.lines(town :: any)
		local rOk, rRes = pcall(rowGardens, extras, placedLots, zs[#zs])
		if not rOk then
			warn(`[Town] {town.id} row gardens: {rRes}`)
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
		for _, u in TownLayout.uses(town :: any) do
			local uok, uerr = pcall(USE_BUILDERS[u.kind] :: any, extras, u.rect, town.origin.Y)
			if not uok then
				warn(`[Town] {town.id} {u.kind}: {uerr}`)
			end
		end
	end
	root:SetAttribute("TownFarmBuildings", farms(root))
	local oOk, oRes = pcall(outskirts, root)
	if not oOk then
		warn(`[Town] outskirts: {oRes}`)
	end
	root:SetAttribute("TownOutskirts", if oOk then oRes else 0)
	root:SetAttribute("TownCottages", placed)
	root:SetAttribute("TownSkipped", skipped)
	print(
		`[Town] {placed} cottages, {root:GetAttribute("TownTerraces")} terraces, {skipped} lots skipped`
	)
end

return Town
