--!strict
-- RoadsShore (I2c): places the road furniture (crash barriers, field gates, dry-stone walls, Cornish hedges, signs),
-- the hedged field boundaries off the country roads and the shore dressing (rock pools, intertidal wrack, eelgrass)
-- at run time. (The far-island proxy kit is gone: its Skerry Isle stood as a non-colliding loaf in Calm Bay at
-- (731, 704); the bake now builds Skerry Isle where it belongs.)
-- WorldDressingService calls RoadsShore.place(Workspace.Dressing) once at server start; the layout maths is pure
-- (RoadsShoreLayout, tests/RoadsShore.spec.luau).
--
-- Everything is snapped to the Terrain with raycasts (the road ribbons are meshes; the verge is Terrain). One Atomic
-- model per piece under Workspace.Dressing.RoadsShore, so streaming and LODs stay local. A piece whose asset or
-- ground is missing is skipped with a warning: there is no greybox to keep for these props.
-- Folder attributes when done: RoadsShoreBarriers, Walls, Hedges, Fields, Gates, Signs, RockPools, Wrack,
-- Eelgrass, Gravel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AssetIds = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("AssetIds")
) :: any
local AssetLoader = require(script.Parent.Parent:WaitForChild("Assets"):WaitForChild("AssetLoader"))
local Layout = require(script.Parent:WaitForChild("RoadsShoreLayout"))
local StreetLayout = require(script.Parent:WaitForChild("StreetLayout"))
local WorldConfig = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("WorldConfig")
)

local RoadsShore = {}

local ROADS: { [string]: { Vector3 } } = {}
local WIDTHS: { [string]: number } = {}
for _, r in WorldConfig.Roads do
	ROADS[r.id] = r.points
	WIDTHS[r.id] = r.width
end

local ATTACHMENTS = AssetIds.Attachments or {}

-- Havers' field walls: Coast Road fields (inland side) and the High Road moor (both sides). Runs are split around
-- the gates below, so a gate always stands in a gap.
local FIELD_WALLS = {
	{ road = "CoastRoadEast", from = 80, to = 200, side = -1, offset = 20 },
	{ road = "CoastRoadEast", from = 230, to = 380, side = -1, offset = 20 },
	{ road = "CoastRoadWest", from = 40, to = 150, side = 1, offset = 18 }, -- runs west: +1 is inland
	{ road = "HighRoad", from = 90, to = 260, side = 1, offset = 15 },
	{ road = "HighRoad", from = 300, to = 470, side = 1, offset = 15 },
	{ road = "HighRoad", from = 760, to = 830, side = -1, offset = 15 },
	{ road = "HighRoad", from = 870, to = 940, side = -1, offset = 15 },
}

local FIELD_GATES = {
	{ road = "CoastRoadEast", s = 215, side = -1, offset = 20 },
	{ road = "CoastRoadWest", s = 165, side = 1, offset = 18 },
	{ road = "HighRoad", s = 280, side = 1, offset = 15 },
	{ road = "HighRoad", s = 850, side = -1, offset = 15 },
}

-- Cornish hedge along the field side of the country roads, on the stretches between the field walls and gates and
-- clear of the junctions (Coast Road joins Harbour Road at s 0 and the Haven Head track / car park at ~503; the High
-- Road leaves Chapel Hill at s 0). Pieces are 5 m modules (M_Road_CornishHedge, local X along the bank).
local HEDGE_RUNS = {
	{ road = "CoastRoadEast", from = 388, to = 468, side = -1, offset = 16.5 },
	{ road = "CoastRoadWest", from = 180, to = 290, side = 1, offset = 16.5 },
	{ road = "CoastRoadWest", from = 30, to = 290, side = -1, offset = 16.5 },
	{ road = "HavenHeadTrack", from = 25, to = 205, side = -1, offset = 8 },
	{ road = "HavenHeadTrack", from = 250, to = 400, side = -1, offset = 8 },
	{ road = "HighRoad", from = 500, to = 700, side = 1, offset = 10.5 },
	{ road = "HighRoad", from = 980, to = 1100, side = 1, offset = 10.5 },
}
local HEDGE_PIECE = 5
local HEDGE_HALF = HEDGE_PIECE / 2

-- Field boundaries (docs/17 P1 9): hedge lines running inland off the country roads every `every` studs and a back
-- hedge `depth` out closing the fields. A piece goes only on open field ground (grass / moor, away from every road
-- and the town), so a line stops at a cliff, beach, yard or road and the back hedge leaves gaps there.
local FIELDS = {
	{ road = "HighRoad", from = 40, to = 1500, side = 1, offset = 17, depth = 110, every = 135 },
	{ road = "HighRoad", from = 40, to = 1500, side = -1, offset = 17, depth = 95, every = 160 },
	{
		road = "CoastRoadEast",
		from = 60,
		to = 470,
		side = -1,
		offset = 24,
		depth = 100,
		every = 125,
	},
	{
		road = "CoastRoadWest",
		from = 20,
		to = 290,
		side = 1,
		offset = 22,
		depth = 100,
		every = 120,
	},
}
local FIELD_GROUND = {
	[Enum.Material.Grass] = true,
	[Enum.Material.LeafyGrass] = true,
	[Enum.Material.Ground] = true,
}
local TOWN_RECT = { -600, -500, 620, 20 } -- x0, z0, x1, z1: Port Haven and its quay

-- Seaward cliff-edge barriers on Haven Head, plus the outside of the sharper bends on the Coast and High roads.
local BARRIER_RUNS = {
	{ road = "HavenHeadTrack", from = 40, to = 220, side = 1 },
	{ road = "HavenHeadTrack", from = 320, to = 520, side = 1 },
}
local BARRIER_BEND_ROADS = { "CoastRoadEast", "CoastRoadWest", "HighRoad" }

local SIGNS = {
	{ name = "Fingerpost", road = "HarbourRoad", s = -22, side = -1, offset = 19 },
	{ name = "TideBoard", road = "HarbourRoad", s = 520, side = 1, offset = 18 },
	{ name = "LaunchSign", road = "SandsSlipway", s = 20, side = 1, offset = 12 },
	{ name = "CarPark", road = "CoastRoadEast", s = -40, side = 1, offset = 19 },
	{ name = "CliffWarning", road = "HavenHeadTrack", s = 300, side = 1, offset = 11 },
}

-- docs/19 sign faces over the kit's plates, in the sign's frame (studs, the read side is -Z, art/source/roads/
-- M_Road_Sign_Kit/build.py at 3 studs a metre). at = board centre X / Y and its front Z (proud of the bolt heads),
-- size = board, aspect = image w / h (fitted inside the board, the rest in edge), back = the image's px size and the
-- x cuts of its bolt end / text / tip, redrawn on the back with the ends mirrored (see signBack).
local SIGN_ART = {
	Fingerpost = { -- the top blade (blade_a, 1.10 m), on both sides
		id = 137807483186889,
		at = Vector3.new(-1.815, 6.0675, -0.09),
		size = Vector2.new(3.3, 0.825),
		aspect = 4,
		depth = 0.18,
		edge = Color3.fromRGB(224, 223, 219),
		back = { w = 1024, h = 256, cuts = { 112, 874 } },
	},
	TideBoard = {
		id = 132912601705738,
		at = Vector3.new(0, 4.125, -0.245),
		size = Vector2.new(2.7, 3.45),
		aspect = 0.5,
		edge = Color3.fromRGB(19, 20, 24),
	},
	LaunchSign = { -- main plate + KEEP CLEAR plate
		id = 87986704526788,
		at = Vector3.new(0, 5.655, -0.3),
		size = Vector2.new(2.25, 2.04),
		aspect = 1,
		edge = Color3.fromRGB(227, 226, 222),
	},
	CarPark = {
		id = 137304008972757,
		at = Vector3.new(0, 6.36, -0.245),
		size = Vector2.new(1.8, 1.8),
		aspect = 1,
		edge = Color3.fromRGB(0, 80, 153),
	},
	CliffWarning = { -- a square yellow plate over the triangle
		id = 79975421420008,
		at = Vector3.new(0, 6.0, -0.245),
		size = Vector2.new(2.7, 2.7),
		aspect = 1,
		edge = Color3.fromRGB(233, 181, 2),
	},
}

-- Haven Sands rock pools round the WorldConfig POI, on the basalt ledges at the foot of Haven Head. Only the
-- intertidal ones are placed (ground within POOL_BAND of the sea): a pool under 10 studs of water or high on dry rock
-- read as a dark stain, and Harbour Cove's two were both under water. CoastArtLayout.Ledges dress the ledges.
local POOL_OFFSETS = {
	{ 0, 0, 0 },
	{ -34, 26, 1.1 },
	{ 36, -18, 2.2 },
	{ -12, -26, 2.9 },
	{ 18, 22, 4.1 },
	{ -40, -8, 5.0 },
}
local POOL_BAND = { -4, 3 }

-- Intertidal wrack on the rocks round the pools and the cove.
local WRACK_SPOTS = {
	{ x = 1440, z = 700, r = 55, n = 32, seed = 41 },
	{ x = 1520, z = 760, r = 38, n = 24, seed = 57 },
}
local WRACK_MATS = { "Bladder_01", "Bladder_02", "Egg_01", "Decal_01" }
local EELGRASS_COUNT = 60

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { Workspace.Terrain }
rayParams.IgnoreWater = true

local function groundY(x: number, z: number): number?
	local hit = Workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), rayParams)
	return if hit then hit.Position.Y else nil
end

local function atomic(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = parent
	return m
end

local function category(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function attachmentsOf(asset: string): { [string]: Vector3 }
	return ATTACHMENTS[asset] or {}
end

local function offsetOf(asset: string, attachment: string): Vector3
	return attachmentsOf(asset)[attachment] or Vector3.zero
end

-- A kit (signs, wrack) is several separate MeshParts on one line: keep the wanted visual and collision proxy,
-- drop the rest.
local function trimTo(model: Model, keep: string, keepCol: string?)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= keep and d.Name ~= keepCol then
			d:Destroy()
		end
	end
end

local function place(
	asset: string,
	cf: CFrame,
	folder: Instance,
	name: string,
	collide: boolean?
): Model?
	local m = AssetLoader.cloneStatic(asset, "LOD0", collide)
	if not m then
		return nil
	end
	m:PivotTo(cf)
	local holder = atomic(name, folder)
	m.Parent = holder
	holder.WorldPivot = cf
	return holder
end

local function pieceAt(asset: string, spot: Layout.Spot, folder: Folder, name: string): Model?
	local y = groundY(spot.pos.X, spot.pos.Z)
	if not y then
		return nil
	end
	return place(
		asset,
		CFrame.new(spot.pos.X, y + 0.02, spot.pos.Z) * CFrame.Angles(0, spot.yaw, 0),
		folder,
		name
	)
end

local function barriers(folder: Folder): number
	local n = 0
	for i, spec in BARRIER_RUNS do
		local pts = ROADS[spec.road]
		if pts then
			local spots = Layout.run(pts, spec.from, spec.to, spec.side, 11, 12)
			for k, spot in spots do
				if pieceAt("M_Road_CrashBarrier", spot, folder, `Barrier_{i}_{k}`) then
					n += 1
				end
			end
		end
	end
	for _, id in BARRIER_BEND_ROADS do
		local pts = ROADS[id]
		if pts then
			for k, spot in Layout.barriers(pts, { offset = WIDTHS[id] / 2 + 4, gap = 50 }) do
				if pieceAt("M_Road_CrashBarrier", spot, folder, `Barrier_{id}_{k}`) then
					n += 1
				end
			end
		end
	end
	return n
end

local function walls(folder: Folder): number
	local n = 0
	for i, spec in FIELD_WALLS do
		local pts = ROADS[spec.road]
		if pts then
			for k, spot in Layout.run(pts, spec.from, spec.to, spec.side, spec.offset, 15) do
				if pieceAt("M_Road_DryStoneWall", spot, folder, `Wall_{i}_{k}`) then
					n += 1
				end
			end
		end
	end
	return n
end

local function gates(folder: Folder): number
	local n = 0
	for i, spec in FIELD_GATES do
		local pts = ROADS[spec.road]
		local spot = pts and Layout.spot(pts, spec.s, spec.side, spec.offset)
		if spot and pieceAt("M_Road_FieldGate", spot, folder, `Gate_{i}`) then
			n += 1
		end
	end
	return n
end

-- Hedge modules follow the ground height at both ends (the bank pitches along its length, so it neither floats nor
-- steps on the climbs) and butt on their 5 m snap. `field`: only on open field ground, else nothing is placed.
local function hedgePiece(
	spot: Layout.Spot,
	folder: Instance,
	name: string,
	field: boolean?
): boolean
	local axis = Vector3.new(math.cos(spot.yaw), 0, -math.sin(spot.yaw))
	local a = spot.pos - axis * HEDGE_HALF
	local b = spot.pos + axis * HEDGE_HALF
	local ha = Workspace:Raycast(Vector3.new(a.X, 400, a.Z), Vector3.new(0, -800, 0), rayParams)
	local hb = Workspace:Raycast(Vector3.new(b.X, 400, b.Z), Vector3.new(0, -800, 0), rayParams)
	if not (ha and hb) then
		return false
	end
	local ya, yb = ha.Position.Y, hb.Position.Y
	if
		field
		and not (FIELD_GROUND[ha.Material] and FIELD_GROUND[hb.Material] and math.abs(yb - ya) < 3)
	then
		return false
	end
	local roll = math.atan2(yb - ya, HEDGE_PIECE)
	local cf = CFrame.new(spot.pos.X, (ya + yb) / 2 + 0.02, spot.pos.Z)
		* CFrame.Angles(0, spot.yaw, 0)
		* CFrame.Angles(0, 0, roll)
	return place("M_Road_CornishHedge", cf, folder, name) ~= nil
end

local function hedges(folder: Folder): number
	local n = 0
	for i, spec in HEDGE_RUNS do
		local pts = ROADS[spec.road]
		if pts then
			for k, spot in Layout.run(pts, spec.from, spec.to, spec.side, spec.offset, HEDGE_PIECE) do
				if hedgePiece(spot, folder, `Hedge_{i}_{k}`) then
					n += 1
				end
			end
		end
	end
	return n
end

-- every road centreline sampled every 8 studs, for the field hedges' keep-off test
local roadSamples: { { pos: Vector3, clear: number } }? = nil
local function nearRoad(p: Vector3): boolean
	if not roadSamples then
		local list = {}
		for id, pts in ROADS do
			for _, sm in StreetLayout.walk(pts, 8) do
				table.insert(
					list,
					{ pos = Vector3.new(sm.pos.X, 0, sm.pos.Z), clear = WIDTHS[id] / 2 + 6 }
				)
			end
		end
		roadSamples = list
	end
	for _, r in roadSamples :: { { pos: Vector3, clear: number } } do
		local dx, dz = p.X - r.pos.X, p.Z - r.pos.Z
		if dx * dx + dz * dz < r.clear * r.clear then
			return true
		end
	end
	return false
end

local function openField(spot: Layout.Spot): boolean
	local p = spot.pos
	local t = TOWN_RECT
	return not (p.X > t[1] and p.X < t[3] and p.Z > t[2] and p.Z < t[4]) and not nearRoad(p)
end

-- one Atomic model per field line (a hedge line is seen whole), so the 5 m modules stream together
local function fields(folder: Folder): number
	local n = 0
	for i, spec in FIELDS do
		local pts = ROADS[spec.road]
		if pts then
			local lines = Layout.fieldLines(
				pts,
				spec.from,
				spec.to,
				spec.side,
				spec.offset,
				spec.depth,
				spec.every,
				HEDGE_PIECE
			)
			table.insert(
				lines,
				Layout.run(
					pts,
					spec.from,
					spec.to,
					spec.side,
					spec.offset + spec.depth,
					HEDGE_PIECE
				)
			)
			for j, line in lines do
				local holder = atomic(`Field_{i}_{j}`, folder)
				local back = j == #lines
				for k, spot in line do
					local ok = openField(spot) and hedgePiece(spot, holder, `Hedge_{k}`, true)
					if ok then
						n += 1
					elseif not back then
						break -- a field line ends where the field does
					end
				end
				if #holder:GetChildren() == 0 then
					holder:Destroy()
				end
			end
		end
	end
	return n
end

-- Seen from behind, a fingerpost arm points the other way: the tip and the bolt end swap sides (mirrored strips), the
-- text between them stays readable. Negative ImageRectSize mirrors a strip, so this is a SurfaceGui, not a Decal.
local function signBack(face: BasePart, art: any)
	local b = art.back
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Back
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 100
	g.LightInfluence = 1
	local x = 0
	for _, strip in { { b.w, b.cuts[2] }, { b.cuts[1], b.cuts[2] }, { b.cuts[1], 0 } } do -- tip, text, bolts
		local share = math.abs(strip[2] - strip[1]) / b.w
		local l = Instance.new("ImageLabel")
		l.BackgroundTransparency = 1
		l.Image = `rbxassetid://{art.id}`
		l.ImageRectOffset = Vector2.new(strip[1], 0)
		l.ImageRectSize = Vector2.new(strip[2] - strip[1], b.h)
		l.Position = UDim2.fromScale(x, 0)
		l.Size = UDim2.fromScale(share, 1)
		l.Parent = g
		x += share
	end
	g.Parent = face
end

-- An opaque slab (edge colour) over the kit plate, the image on it as a Decal: the plates are faces of one kit mesh.
local function signFace(holder: Model, cf: CFrame, art: any)
	local depth = art.depth or 0.08
	local function slab(w: number, h: number, front: number): Part
		local p = Instance.new("Part")
		p.Name = "SignFace"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = art.edge
		p.Size = Vector3.new(w, h, depth)
		p.CFrame = cf * CFrame.new(art.at.X, art.at.Y, front + depth / 2)
		p.Parent = holder
		return p
	end
	local w = math.min(art.size.X, art.size.Y * art.aspect)
	local face = slab(w, w / art.aspect, art.at.Z)
	if art.size.X - w > 0.01 or art.size.Y - w / art.aspect > 0.01 then
		slab(art.size.X, art.size.Y, art.at.Z + 0.01).Name = "SignBoard" -- the fit margins, a hair behind the face
	end
	local d = Instance.new("Decal")
	d.Texture = `rbxassetid://{art.id}`
	d.Face = Enum.NormalId.Front
	d.Parent = face
	if art.back then
		signBack(face, art)
	end
end

local function signs(folder: Folder): number
	local n = 0
	for i, spec in SIGNS do
		local pts = ROADS[spec.road]
		local spot = pts and Layout.spot(pts, spec.s, spec.side, spec.offset)
		local y = spot and groundY(spot.pos.X, spot.pos.Z)
		if spot and y then
			local dir = Vector3.new(-math.cos(spot.yaw), 0, math.sin(spot.yaw))
			local right = Vector3.new(-dir.Z, 0, dir.X)
			local face = right * -spec.side
			local cf = CFrame.new(spot.pos.X, y + 0.02, spot.pos.Z)
				* CFrame.Angles(0, Layout.faceYaw(face), 0)
			local m = AssetLoader.cloneStatic("M_Road_Sign_Kit", "LOD0", true)
			if m then
				m:PivotTo(cf * CFrame.new(-offsetOf("M_Road_Sign_Kit", `ATT_{spec.name}`)))
				trimTo(m, `M_Road_Sign_{spec.name}_LOD0`, `M_Road_Sign_{spec.name}_COL`)
				local holder = atomic(`Sign_{i}_{spec.name}`, folder)
				m.Parent = holder
				holder.WorldPivot = cf
				signFace(holder, cf, SIGN_ART[spec.name])
				n += 1
			end
		else
			warn(`[RoadsShore] sign {spec.name}: no {spec.road} at s {spec.s} or no ground`)
		end
	end
	return n
end

local function rockPools(folder: Folder): number
	local n = 0
	local placements: { { x: number, z: number, yaw: number } } = {}
	local poi: any = nil
	for _, p in WorldConfig.POIs do
		if p.id == "HavenSandsRockPools" then
			poi = p
		end
	end
	if poi then
		for _, o in POOL_OFFSETS do
			table.insert(
				placements,
				{ x = poi.position.X + o[1], z = poi.position.Z + o[2], yaw = o[3] }
			)
		end
	end
	local sea = Workspace:GetAttribute("SeaLevel")
	local seaY = if type(sea) == "number" then sea else WorldConfig.SeaLevel
	for i, p in placements do
		local y = groundY(p.x, p.z)
		if y and y >= seaY + POOL_BAND[1] and y <= seaY + POOL_BAND[2] then
			local cf = CFrame.new(p.x, y - 0.35, p.z) * CFrame.Angles(0, p.yaw, 0)
			if place("M_Rock_RockPool_Kit", cf, folder, `Pool_{i}`, true) then
				n += 1
			end
		end
	end
	return n
end

local function wrack(folder: Folder): number
	local n = 0
	for _, group in WRACK_SPOTS do
		for i, p in Layout.scatter(Vector3.new(group.x, 0, group.z), group.r, group.n, group.seed) do
			local y = groundY(p.X, p.Z)
			local sea = Workspace:GetAttribute("SeaLevel")
			local seaY = if type(sea) == "number" then sea else WorldConfig.SeaLevel
			if y and y >= seaY - 3.5 and y <= seaY + 2 then
				local mat = WRACK_MATS[(n % #WRACK_MATS) + 1]
				local m = AssetLoader.cloneStatic("M_Veg_Wrack_Kit", "LOD0", false)
				if m then
					m:PivotTo(
						CFrame.new(p.X, y + 0.04, p.Z)
							* CFrame.Angles(0, (n + i) * 2.399963, 0)
							* CFrame.new(-offsetOf("M_Veg_Wrack_Kit", `ATT_Base_{mat}`))
					)
					trimTo(m, `M_Veg_Wrack_{mat}_LOD0`)
					local holder = atomic(`Wrack_{n + 1}`, folder)
					m.Parent = holder
					holder.WorldPivot = m:GetPivot()
					n += 1
				end
			end
		end
	end
	return n
end

local function eelgrass(folder: Folder): number
	local bed: any = WorldConfig.Eelgrass[1]
	if not bed then
		return 0
	end
	local sea = Workspace:GetAttribute("SeaLevel")
	local seaY = if type(sea) == "number" then sea else WorldConfig.SeaLevel
	local n = 0
	for i, p in Layout.scatter(bed.center, bed.radius, EELGRASS_COUNT, 20261019, 18) do
		local y = groundY(p.X, p.Z)
		if y and y < seaY - 0.5 and y > seaY - 9 then
			local cf = CFrame.new(p.X, y + 0.08, p.Z) * CFrame.Angles(0, i * 2.399963, 0)
			if place("M_Veg_Eelgrass_Kit", cf, folder, `Eelgrass_{n + 1}`, false) then
				n += 1
			end
		end
	end
	return n
end

-- The bake paints country verges and the West Cliff car park Pavement as gravel, but built-in Pavement draws white
-- herringbone pavers (docs/17 N6): repaint them Ground, a grey-brown gravel under Town.paint's tint (Limestone read
-- as a pale concrete slab, N14), and kerb the car park, leaving the Coast Road's mouth open. The car park also
-- takes the road's asphalt end, so the road stops at its kerb line.
local GRAVEL_ROADS = { "HighRoad", "CoastRoadWest" }
local KERB = Color3.fromRGB(168, 162, 152)

local function gravel(folder: Folder): number
	local terrain = Workspace.Terrain
	local n = 0
	for _, id in GRAVEL_ROADS do
		local half = (WIDTHS[id] or 0) / 2 + 8
		for _, s in StreetLayout.walk(ROADS[id], 8) do
			local region = Region3.new(
				s.pos - Vector3.new(half, 12, half),
				s.pos + Vector3.new(half, 12, half)
			)
			terrain:ReplaceMaterial(
				region:ExpandToGrid(4),
				4,
				Enum.Material.Pavement,
				Enum.Material.Ground
			)
			n += 1
			if n % 40 == 0 then
				task.wait()
			end
		end
	end
	local cp: any = nil
	for _, c in WorldConfig.CarParks do
		if c.id == "WestCliffViewpoint" then
			cp = c
		end
	end
	local road = ROADS.CoastRoadWest
	if not (cp and road) then
		return n
	end
	local c, hx, hz = cp.center, cp.size[1] / 2, cp.size[2] / 2
	local region =
		Region3.new(c - Vector3.new(hx + 4, 20, hz + 4), c + Vector3.new(hx + 4, 20, hz + 4))
			:ExpandToGrid(4)
	for _, from in { Enum.Material.Pavement, Enum.Material.Asphalt, Enum.Material.Concrete } do
		terrain:ReplaceMaterial(region, 4, from, Enum.Material.Ground)
	end
	-- granite kerb round the rectangle (yaw 0), 6-stud stones, a gap where the road comes in
	local mouth, gap = road[#road], (WIDTHS.CoastRoadWest or 26) / 2 + 2
	local corners = {
		Vector3.new(c.X - hx, 0, c.Z - hz),
		Vector3.new(c.X + hx, 0, c.Z - hz),
		Vector3.new(c.X + hx, 0, c.Z + hz),
		Vector3.new(c.X - hx, 0, c.Z + hz),
	}
	for i, a in corners do
		local b = corners[i % 4 + 1]
		local len = (b - a).Magnitude
		for d = 3, len - 3, 6 do
			local p = a + (b - a).Unit * d
			local y = groundY(p.X, p.Z)
			local open = math.abs(p.X - (c.X + hx)) < 1 and math.abs(p.Z - mouth.Z) < gap
			if y and not open then
				local kerb = Instance.new("Part")
				kerb.Name = "CarParkKerb"
				kerb.Anchored = true
				kerb.CanTouch = false
				kerb.Material = Enum.Material.Granite
				kerb.Color = KERB
				kerb.Size = Vector3.new(0.9, 0.9, 6)
				kerb.CFrame =
					CFrame.lookAt(Vector3.new(p.X, y + 0.2, p.Z), Vector3.new(b.X, y + 0.2, b.Z))
				kerb.Parent = folder
				n += 1
			end
		end
	end
	return n
end

local function try(name: string, fn: (Folder) -> number, folder: Folder): number
	local ok, n = pcall(fn, folder)
	if not ok then
		warn(`[RoadsShore] {name} failed: {n}`)
		return 0
	end
	return n
end

function RoadsShore.place(base: Instance)
	local folder = Instance.new("Model")
	folder.Name = "RoadsShore"
	folder.ModelStreamingMode = Enum.ModelStreamingMode.Nonatomic
	folder.Parent = base
	local sections = {
		Barriers = category(folder, "Barriers"),
		Walls = category(folder, "Walls"),
		Hedges = category(folder, "Hedges"),
		Fields = category(folder, "Fields"),
		Gates = category(folder, "Gates"),
		Signs = category(folder, "Signs"),
		RockPools = category(folder, "RockPools"),
		Wrack = category(folder, "Wrack"),
		Eelgrass = category(folder, "Eelgrass"),
		Gravel = category(folder, "Gravel"),
	}
	for _, asset in
		{
			"M_Road_CrashBarrier",
			"M_Road_FieldGate",
			"M_Road_DryStoneWall",
			"M_Road_CornishHedge",
			"M_Road_Sign_Kit",
			"M_Rock_RockPool_Kit",
			"M_Veg_Wrack_Kit",
			"M_Veg_Eelgrass_Kit",
		}
	do
		task.spawn(AssetLoader.getTemplate, asset, "LOD0")
	end
	local counts = {
		Barriers = try("barriers", barriers, sections.Barriers),
		Walls = try("walls", walls, sections.Walls),
		Hedges = try("hedges", hedges, sections.Hedges),
		Fields = try("field hedges", fields, sections.Fields),
		Gates = try("gates", gates, sections.Gates),
		Signs = try("signs", signs, sections.Signs),
		RockPools = try("rock pools", rockPools, sections.RockPools),
		Wrack = try("wrack", wrack, sections.Wrack),
		Eelgrass = try("eelgrass", eelgrass, sections.Eelgrass),
		Gravel = try("gravel", gravel, sections.Gravel),
	}
	folder:SetAttribute("RoadsShoreBarriers", counts.Barriers)
	folder:SetAttribute("RoadsShoreWalls", counts.Walls)
	folder:SetAttribute("RoadsShoreHedges", counts.Hedges)
	folder:SetAttribute("RoadsShoreFields", counts.Fields)
	folder:SetAttribute("RoadsShoreGates", counts.Gates)
	folder:SetAttribute("RoadsShoreSigns", counts.Signs)
	folder:SetAttribute("RoadsShoreRockPools", counts.RockPools)
	folder:SetAttribute("RoadsShoreWrack", counts.Wrack)
	folder:SetAttribute("RoadsShoreEelgrass", counts.Eelgrass)
	folder:SetAttribute("RoadsShoreGravel", counts.Gravel)
	print(
		`[RoadsShore] {counts.Barriers} barriers, {counts.Walls} walls, {counts.Hedges} hedge modules, {counts.Fields} field hedge modules, {counts.Gates} gates, {counts.Signs} signs, {counts.RockPools} pools, {counts.Wrack} wrack, {counts.Eelgrass} eelgrass`
	)
end

return RoadsShore
