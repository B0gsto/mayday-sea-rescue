--!strict
-- HubLandmark (PERF-BL12): the ring centre stays open water with a small beacon atoll landmark (docs/00). M_Prop_HubKit's
-- named modules go where art/source/props/M_Prop_HubKit/build.py's LAYOUT says (ring centre = origin, sea level 0). The
-- meshes are inert; invisible Parts collide for the atoll and the beacon only. No kit: nothing at all is placed.
-- WorldDressingService calls place(base) once at server start; tests/HubLandmark.spec.luau keeps the rows in the lagoon.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetIds = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("AssetIds")
)

local HubLandmark = {}

local ASSET = "M_Prop_HubKit"
local GOLD = Color3.fromHex("FFC83A")
local WET, BEACH, TOP = 1.2, 2.4, 3.6 -- the atoll's tier tops
local FOOT = TOP - 0.05 -- the beacon's y 0
local CELL = 8 -- the atoll's stepped grid (build.py disc)

-- Each module's ATT_<slot> origin in the kit strip.
HubLandmark.SLOTS = {
	L01_Atoll = "Atoll",
	L09_AtollDress = "Atoll",
	L02_Beacon = "Beacon",
	L08_BeaconLens = "Beacon",
	L10_BeaconGlass = "Beacon",
	L11_BeaconTop = "Beacon",
	L03_Wreck = "Wreck",
	L04_Buoy = "Buoy",
	L05_RockA = "RockA",
	L06_RockB = "RockB",
	L07_Raft = "Raft",
} :: { [string]: string }

export type Row = { module: string, x: number, y: number, z: number, yaw: number, scale: number }

local function fixed(module: string, y: number): Row
	return { module = module, x = 0, y = y, z = 0, yaw = 0, scale = 1 }
end

local function polar(module: string, r: number, bearing: number, yaw: number, scale: number): Row
	local a = math.rad(bearing)
	local x, z = math.round(r * math.cos(a) * 10) / 10, math.round(r * math.sin(a) * 10) / 10
	return { module = module, x = x, y = 0, z = z, yaw = yaw, scale = scale }
end

-- build.py's LAYOUT, row for row: rock yaw = bearing, raft yaw = 90 - bearing.
HubLandmark.LAYOUT = {
	fixed("L01_Atoll", 0),
	fixed("L09_AtollDress", 0),
	fixed("L02_Beacon", FOOT),
	fixed("L08_BeaconLens", FOOT),
	fixed("L10_BeaconGlass", FOOT),
	fixed("L11_BeaconTop", FOOT),
	polar("L03_Wreck", 92, 330, 35, 1),
	polar("L04_Buoy", 172, 269, 0, 1),
	polar("L04_Buoy", 215, 275, 0, 1.2),
	polar("L04_Buoy", 160, 151, 0, 1.15),
	polar("L04_Buoy", 195, 146, 0, 0.88),
	polar("L04_Buoy", 152, 323, 0, 0.9),
	polar("L04_Buoy", 184, 314, 0, 1.2),
	polar("L05_RockA", 218, 44, 44, 0.85),
	polar("L05_RockA", 229, 137, 137, 1.15),
	polar("L05_RockA", 191, 21, 21, 1),
	polar("L06_RockB", 236, 212, 212, 1.15),
	polar("L06_RockB", 198, 158, 158, 0.85),
	polar("L06_RockB", 219, 99, 99, 1),
	polar("L07_Raft", 138, 94, -4, 1),
	polar("L07_Raft", 162, 216, -126, 1),
	polar("L07_Raft", 186, 332, -242, 1),
} :: { Row }

-- The beacon's solids, from its foot: x0, y0, z0, x1, y1, z1. The door (|x| < 5.6, up to the arch's crown 14.6) stays open.
local BEACON_BOXES = {
	{ -18.4, 0, -18.4, 18.4, 2.5, 18.4 }, -- plinth, level with the plank floor
	{ -9, 0, -23.2, 9, 1.2, -18.4 }, -- door step
	{ -14.4, 2.5, 11.8, 14.4, 21, 14.4 }, -- back wall
	{ -14.4, 2.5, -11.8, -11.8, 21, 11.8 }, -- side walls
	{ 11.8, 2.5, -11.8, 14.4, 21, 11.8 },
	{ -14.4, 2.5, -14.4, -5.6, 21, -11.8 }, -- front wall, either side of the door
	{ 5.6, 2.5, -14.4, 14.4, 21, -11.8 },
	{ -5.6, 14.6, -14.4, 5.6, 21, -11.8 }, -- over the door
	{ -14.4, 21, -14.4, 14.4, 22.8, 14.4 }, -- room roof
	{ -12.4, 22.8, -12.4, 12.4, 78, 12.4 }, -- tower
	{ -22.2, 78, -22.2, 22.2, 82.2, 22.2 }, -- gallery
	{ -17, 82.2, -17, 17, 117.5, 17 }, -- lantern room and roof
	{ -7, 117.5, -7, 7, 135.7, 7 }, -- day mark
}

function HubLandmark.solid(parent: Instance, size: Vector3, cf: CFrame)
	local p = Instance.new("Part")
	p.Name = "Col"
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Parent = parent
end

local function box(
	parent: Instance,
	x0: number,
	y0: number,
	z0: number,
	x1: number,
	y1: number,
	z1: number
)
	local lo, hi = Vector3.new(x0, y0, z0), Vector3.new(x1, y1, z1)
	HubLandmark.solid(parent, hi - lo, CFrame.new((lo + hi) / 2))
end

-- One atoll tier: a box per grid row of the cells whose centre is inside `radius` (build.py disc), down to the kit's -8.
local function tier(
	parent: Instance,
	radius: number,
	top: number,
	skip: ((i: number, j: number) -> boolean)?
)
	for j = -8, 7 do
		local start: number? = nil
		for i = -8, 8 do
			local inside = i < 8
				and math.sqrt(((i + 0.5) * CELL) ^ 2 + ((j + 0.5) * CELL) ^ 2) < radius
				and not (skip and skip(i, j))
			if inside and not start then
				start = i
			elseif start and not inside then
				box(parent, start * CELL, -8, j * CELL, i * CELL, top, (j + 1) * CELL)
				start = nil
			end
		end
	end
end

-- A strip of the ramp at x: its walking surface runs from y0 at the sea end (z -74) to y1 at the beach edge (z -40).
local function rampStrip(parent: Instance, x: number, halfWidth: number, y0: number, y1: number)
	local a, b = Vector3.new(x, y0, -74), Vector3.new(x, y1, -40)
	HubLandmark.solid(
		parent,
		Vector3.new(2 * halfWidth, 2, (b - a).Magnitude),
		CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, -1, 0)
	)
end

local function collision(parent: Instance)
	tier(parent, 49, WET, function(i, j) -- the ramp's corridor stays open
		return j == -6 and i >= -2 and i <= 1
	end)
	tier(parent, 41, BEACH)
	tier(parent, 31, TOP)
	rampStrip(parent, 0, 12, -0.4, BEACH) -- planks
	for _, side in { -14, 14 } do
		rampStrip(parent, side, 2, 0.9, 3.2) -- kerbs
	end
	for _, b in BEACON_BOXES do
		box(parent, b[1], FOOT + b[2], b[3], b[4], FOOT + b[5], b[6])
	end
end

-- The code makes the lantern glow and its panes clear (build.py L08, L10).
local function finish(p: BasePart, module: string)
	if module == "L08_BeaconLens" then
		local sa = p:FindFirstChildOfClass("SurfaceAppearance")
		if sa then
			sa:Destroy()
		end
		p.Material = Enum.Material.Neon
		p.Color = GOLD
		p.CastShadow = false
		local glow = Instance.new("PointLight") -- on the lens's centre, which is ATT_Light; as the board kit's beacon
		glow.Color = GOLD
		glow.Range = 36
		glow.Brightness = 1.5
		glow.Parent = p
	elseif module == "L10_BeaconGlass" then
		p.Transparency = 0.75
		p.CastShadow = false
	end
end

-- `layout`'s kit pieces as one Persistent model round the origin, or nil if the kit lacks a module. Colliders: the
-- atoll and beacon's (when the atoll is in the layout) only. server/World/SectorSpots reuses it for its dressing.
function HubLandmark.assemble(kit: Model, layout: { Row }, name: string): Model?
	local atts = (AssetIds :: any).Attachments[ASSET]
	local m = Instance.new("Model")
	m.Name = name
	-- Persistent like the plates, bridges and day marks: seen from every plate (310-630 studs, target radius 512), and the
	-- boats' physics run on the client, so the colliders must be there too
	m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local atoll = false
	for _, row in layout do
		local src = kit:FindFirstChild(row.module, true)
		if not (src and src:IsA("BasePart")) then
			warn(`[HubLandmark] {ASSET} has no {row.module}: {name} is not placed`)
			m:Destroy()
			return nil
		end
		local origin = kit.WorldPivot * CFrame.new(atts[`ATT_{HubLandmark.SLOTS[row.module]}`])
		local rel = origin:ToObjectSpace(src.CFrame)
		local p = src:Clone()
		p.Size = src.Size * row.scale
		p.CFrame = CFrame.new(row.x, row.y, row.z)
			* CFrame.Angles(0, math.rad(row.yaw), 0)
			* (rel - rel.Position + rel.Position * row.scale)
		p.Anchored = true
		p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
		finish(p, row.module)
		p.Parent = m
		atoll = atoll or row.module == "L01_Atoll"
	end
	if atoll then
		collision(m)
	end
	return m
end

function HubLandmark.build(base: Instance, kit: Model?)
	if not kit then
		warn(`[HubLandmark] {ASSET} did not load: the lagoon stays open water`)
		return
	end
	local m = HubLandmark.assemble(kit, HubLandmark.LAYOUT, "HubLandmark")
	if m then
		m.Parent = base
	end
end

function HubLandmark.place(base: Instance)
	-- required here: AssetLoader doesn't load in Lune, and tests/HubLandmark.spec.luau runs build
	local AssetLoader =
		require(script.Parent.Parent:WaitForChild("Assets"):WaitForChild("AssetLoader"))
	HubLandmark.build(base, AssetLoader.getTemplate(ASSET, "LOD0"))
end

return HubLandmark
