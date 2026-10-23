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
-- Folder attributes: TownCottages, TownTerraces, TownSkipped, TownGardens.

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
	Grass = { 98, 128, 62 },
	LeafyGrass = { 122, 128, 74 },
	Ground = { 110, 96, 70 },
	Mud = { 74, 60, 46 },
	Sand = { 196, 178, 138 },
	Sandstone = { 170, 150, 112 },
	Salt = { 176, 160, 124 },
	Limestone = { 165, 158, 140 },
	Rock = { 112, 114, 116 },
	Slate = { 88, 92, 92 },
	Basalt = { 68, 68, 72 },
	CrackedLava = { 100, 96, 90 },
	-- until naturalGround() reaches them: their replacement's tint
	Snow = { 122, 128, 74 },
	WoodPlanks = { 98, 128, 62 },
	Brick = { 110, 96, 70 },
	Glacier = { 196, 178, 138 },
	Ice = { 196, 178, 138 },
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
local SLATE = Color3.fromRGB(66, 72, 80)
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
		local at = Vector3.new(cx, y, cz) - backDir * (d / 2 - 3.5) + side * (w / 4)
		local rot = CFrame.Angles(0, math.atan2(-backDir.X, -backDir.Z), 0) -- local -Z = out into the garden
		part(
			parent,
			`Outshut{n}`,
			Vector3.new(w / 2 - 1, 8, 7),
			CFrame.new(at + Vector3.yAxis * 4) * rot,
			lot.render == "White" and Color3.fromRGB(236, 232, 222) or Color3.fromRGB(218, 210, 192),
			Enum.Material.Plaster
		)
		local roof = Instance.new("WedgePart")
		roof.Name = `OutshutRoof{n}`
		roof.Anchored, roof.CanCollide, roof.CanQuery = true, false, false
		roof.Size = Vector3.new(w / 2 - 0.4, 2.6, 7.6)
		roof.CFrame = CFrame.new(at + Vector3.yAxis * 9.3) * rot
		roof.Color, roof.Material = SLATE, Enum.Material.RoofShingles
		roof.Parent = parent
		part(
			parent,
			`OutshutGlass{n}`,
			Vector3.new(3, 3.6, 0.2),
			CFrame.new(at + Vector3.yAxis * 4.6) * rot * CFrame.new(0, 0, -3.55),
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
	if n % 5 == 2 then -- a garden tree in the far corner
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
	if n % 3 == 0 then
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
	for i = 1, 3 do
		for side = -1, 1, 2 do
			part(
				sq,
				"Window",
				Vector3.new(0.4, 9, 3.4),
				CFrame.new(cx + side * (W / 2 + 0.1), y + 10, back + i * L / 4),
				Color3.fromRGB(40, 52, 66),
				Enum.Material.Glass
			)
		end
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
	part(
		sq,
		"Door",
		Vector3.new(5, 9, 0.4),
		CFrame.new(cx, y + 4.5, tz + T / 2 + 0.1),
		Color3.fromRGB(70, 36, 24),
		Enum.Material.Wood
	)
	part(
		sq,
		"Belfry",
		Vector3.new(3, 6, 0.4),
		CFrame.new(cx, y + TH - 9, tz + T / 2 + 0.1),
		Color3.fromRGB(30, 30, 32),
		Enum.Material.Wood
	)
	part(
		sq,
		"Clock",
		Vector3.new(0.3, 5, 5),
		CFrame.new(cx, y + TH - 17, tz + T / 2 + 0.1) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(236, 232, 220),
		Enum.Material.SmoothPlastic
	).Shape =
		Enum.PartType.Cylinder
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

-- farmsteads (layout.py FARMS: gravel yards flattened in the bake): a farmhouse on the yard's north side facing
-- into it and the boatyard shed as a barn on its east side
local function farms(parent: Instance): number
	local folder = Instance.new("Model")
	folder.Name = "Farms"
	folder.ModelStreamingMode = Enum.ModelStreamingMode.Nonatomic
	folder.Parent = parent
	local n = 0
	for i, f in (WorldConfig :: any).Farms or {} do
		local yard = CFrame.new(f.center.X, 0, f.center.Z) * CFrame.Angles(0, -math.rad(f.yaw), 0)
		local y = ground(f.center.X, f.center.Z, f.center.Y)
		local pieces: { { any } } = {
			{
				string.format("M_Bld_Cottage_%02d", (i % #TownLayout.COTTAGES) + 1),
				Vector3.new(-8, 0, -f.size[2] / 2 + 12),
				math.pi,
			},
			{ "M_Bld_BoatyardShed", Vector3.new(f.size[1] / 2 - 18, 0, 4), -math.pi / 2 },
		}
		for k, pc in pieces do
			local m = AssetLoader.cloneStatic(pc[1], "LOD0", true)
			if m then
				m.Name = `{f.id}_{if k == 1 then "House" else "Barn"}`
				m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
				m:PivotTo(
					(yard * CFrame.new(pc[2]) * CFrame.Angles(0, pc[3], 0)) + Vector3.new(0, y, 0)
				)
				m.Parent = folder
				if k == 1 then
					m:SetAttribute("Render", TownLayout.RENDERS[(i % #TownLayout.RENDERS) + 1])
					pcall(CottageRig.apply, m)
				end
				n += 1
			end
		end
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
		local terraces = 0
		for n, lot in lots do
			-- a cottage lot on uneven ground becomes a 2-storey code-built house (no gaps in the street face)
			local y0 = if lot.floors then nil else level(lot, town.origin.Y)
			if not lot.floors and not y0 then
				lot = table.clone(lot)
				lot.floors = 2
			end
			if lot.floors then -- code-built terrace: stands on a plinth, so slopes up to 8 studs are fine
				local lo, hi = span(lot.rect, town.origin.Y)
				if hi - lo <= 8 then
					local ok, err = pcall(TownBuildings.terrace, folder, lot, n, lo, hi)
					if ok then
						terraces += 1
						table.insert(placedLots, lot)
						ys[lot] = hi
					else
						warn(`[Town] {town.id} terrace {n}: {err}`)
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
