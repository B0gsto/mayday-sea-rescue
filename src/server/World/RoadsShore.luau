--!strict
-- RoadsShore (I2c): places the road furniture (crash barriers, field gates, dry-stone walls, Cornish hedges, signs)
-- and the shore dressing (rock pools, intertidal wrack, eelgrass) and the far island proxies at run time.
-- WorldDressingService calls RoadsShore.place(Workspace.Dressing) once at server start; the layout maths is pure
-- (RoadsShoreLayout, tests/RoadsShore.spec.luau).
--
-- Everything is snapped to the Terrain with raycasts (the road ribbons are meshes; the verge is Terrain). One Atomic
-- model per piece under Workspace.Dressing.RoadsShore, so streaming and LODs stay local. A piece whose asset or
-- ground is missing is skipped with a warning: there is no greybox to keep for these props.
-- Folder attributes when done: RoadsShoreBarriers, Walls, Hedges, Gates, Signs, RockPools, Wrack, Eelgrass,
-- Islands.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AssetIds = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("AssetIds")
) :: any
local AssetLoader = require(script.Parent.Parent:WaitForChild("Assets"):WaitForChild("AssetLoader"))
local Layout = require(script.Parent:WaitForChild("RoadsShoreLayout"))
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

-- Haven Sands rock pools (WorldConfig POI) and the two rocky flanks of Harbour Cove.
local POOL_OFFSETS = {
	{ 0, 0, 0 },
	{ -34, 26, 1.1 },
	{ 36, -18, 2.2 },
}
local COVE_POOLS = {
	{ x = 330, z = 60, yaw = 0.6 },
	{ x = 180, z = 60, yaw = 2.0 },
}

-- Intertidal wrack on the rocks round the pools and the cove.
local WRACK_SPOTS = {
	{ x = 1440, z = 700, r = 55, n = 32, seed = 41 },
	{ x = 1520, z = 760, r = 38, n = 24, seed = 57 },
	{ x = 330, z = 65, r = 40, n = 24, seed = 73 },
	{ x = 180, z = 65, r = 36, n = 20, seed = 91 },
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
	folder: Folder,
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

-- Hedge modules follow the road height at both ends (the bank pitches along its length, so it neither floats nor
-- steps on the climbs) and butt on their 5 m snap.
local function hedges(folder: Folder): number
	local n = 0
	for i, spec in HEDGE_RUNS do
		local pts = ROADS[spec.road]
		if pts then
			for k, spot in Layout.run(pts, spec.from, spec.to, spec.side, spec.offset, HEDGE_PIECE) do
				local axis = Vector3.new(math.cos(spot.yaw), 0, -math.sin(spot.yaw))
				local a = spot.pos - axis * HEDGE_HALF
				local b = spot.pos + axis * HEDGE_HALF
				local ya = groundY(a.X, a.Z)
				local yb = groundY(b.X, b.Z)
				if ya and yb then
					local roll = math.atan2(yb - ya, HEDGE_PIECE)
					local cf = CFrame.new(spot.pos.X, (ya + yb) / 2 + 0.02, spot.pos.Z)
						* CFrame.Angles(0, spot.yaw, 0)
						* CFrame.Angles(0, 0, roll)
					if place("M_Road_CornishHedge", cf, folder, `Hedge_{i}_{k}`) then
						n += 1
					end
				end
			end
		end
	end
	return n
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
	for _, p in COVE_POOLS do
		table.insert(placements, p)
	end
	for i, p in placements do
		local y = groundY(p.x, p.z)
		if y then
			local cf = CFrame.new(p.x, y - 0.35, p.z) * CFrame.Angles(0, p.yaw, 0)
			if place("M_Rock_RockPool_Kit", cf, folder, `Pool_{i}`, true) then
				n += 1
			end
		else
			warn(`[RoadsShore] rock pool {i}: no ground at {p.x}, {p.z}`)
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

local function islands(folder: Folder): number
	-- Authored in world space (M_Rock_IslandProxy_Kit.placements.json): the kit sits at the map origin, 1 stud low
	-- so the streamed Terrain covers it. LOD1: these are 2 to 4 km out.
	local m = AssetLoader.cloneStatic("M_Rock_IslandProxy_Kit", "LOD1", false)
	if not m then
		warn("[RoadsShore] M_Rock_IslandProxy_Kit did not load")
		return 0
	end
	m:PivotTo(CFrame.identity)
	-- Great Gale's proxy stood over the baked town (Eastgate's flat tan plane: the platform is cut below it) and
	-- squared off the map edge; the bake now closes the island's coast inside the window, so drop it
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and string.find(d.Name, "GreatGale", 1, true) then
			d:Destroy()
		end
	end
	local holder = atomic("Islands", folder)
	m.Parent = holder
	holder.WorldPivot = CFrame.identity
	return 1
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
		Gates = category(folder, "Gates"),
		Signs = category(folder, "Signs"),
		RockPools = category(folder, "RockPools"),
		Wrack = category(folder, "Wrack"),
		Eelgrass = category(folder, "Eelgrass"),
		Islands = category(folder, "Islands"),
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
	task.spawn(AssetLoader.getTemplate, "M_Rock_IslandProxy_Kit", "LOD1")
	local counts = {
		Barriers = try("barriers", barriers, sections.Barriers),
		Walls = try("walls", walls, sections.Walls),
		Hedges = try("hedges", hedges, sections.Hedges),
		Gates = try("gates", gates, sections.Gates),
		Signs = try("signs", signs, sections.Signs),
		RockPools = try("rock pools", rockPools, sections.RockPools),
		Wrack = try("wrack", wrack, sections.Wrack),
		Eelgrass = try("eelgrass", eelgrass, sections.Eelgrass),
		Islands = try("islands", islands, sections.Islands),
	}
	folder:SetAttribute("RoadsShoreBarriers", counts.Barriers)
	folder:SetAttribute("RoadsShoreWalls", counts.Walls)
	folder:SetAttribute("RoadsShoreHedges", counts.Hedges)
	folder:SetAttribute("RoadsShoreGates", counts.Gates)
	folder:SetAttribute("RoadsShoreSigns", counts.Signs)
	folder:SetAttribute("RoadsShoreRockPools", counts.RockPools)
	folder:SetAttribute("RoadsShoreWrack", counts.Wrack)
	folder:SetAttribute("RoadsShoreEelgrass", counts.Eelgrass)
	folder:SetAttribute("RoadsShoreIslands", counts.Islands)
	print(
		`[RoadsShore] {counts.Barriers} barriers, {counts.Walls} walls, {counts.Hedges} hedge modules, {counts.Gates} gates, {counts.Signs} signs, {counts.RockPools} pools, {counts.Wrack} wrack, {counts.Eelgrass} eelgrass, {counts.Islands} islands`
	)
end

return RoadsShore
