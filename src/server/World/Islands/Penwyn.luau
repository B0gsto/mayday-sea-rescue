--!strict
-- Penwyn (docs/21 §2.2): the Cornish fishing village island, the second home port. Islands/init.luau calls
-- place(base, island) with the WorldConfig.Islands row; the terrain is baked (village pad flat at Y 5 behind the
-- dredged basin, the hill peaking at the landmark). Built here, code-first with the town and harbour kits:
--   * harbour: the HP1 quay kit along the basin's west face (x -4228), a kit jetty from the landing to the dock
--     (island.dock: boats stop at its head; B3's DropOff pad), two granite arms with a parapet enclosing the basin
--     (mouth east), the harbour light on the north head (tagged Lighthouse: StreetController's night beam), a slipway
--     south of the south arm, crabbers / trawlers / punts at moorings and alongside, a lobster-pot buoy field;
--   * quay clutter (HP2a props: pots, nets, fish boxes, rope, lifebuoys, bollards with gulls), lanterns that glow at
--     night (CottageRig), benches;
--   * the village: TownBuildings terraces facing the harbour (the Pilchard Inn on the corner, shops), Fore Street
--     west to the hill with a Bethel chapel, a square and Cornish hedges, three rows of cottages stepping up the hill
--     on level lanes with granite retaining walls, the steep ope climbing between them;
--   * the hill: a footpath to the white tower windmill (the landmark, Persistent, sails turning on a motor hinge),
--     the stamp post (StampPost, Island attribute; B2 hooks it) and the lookout bench (Viewpoint) over the harbour.
-- Ground heights come from Terrain raycasts. Workspace.Dressing.Penwyn attribute PenwynParts = instance count.
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local World = script.Parent.Parent
local AssetLoader = require(World.Parent:WaitForChild("Assets"):WaitForChild("AssetLoader"))
local CottageRig = require(World:WaitForChild("CottageRig"))
local StreetFurniture = require(World:WaitForChild("StreetFurniture"))
local TownBuildings = require(World:WaitForChild("TownBuildings"))

local M = {}

local Mat = Enum.Material
local GRANITE = Color3.fromRGB(138, 134, 126)
local GRANITE_DARK = Color3.fromRGB(104, 101, 96)
local COBBLE = Color3.fromRGB(124, 116, 104)
local PATH = Color3.fromRGB(136, 122, 100)
local WHITE = Color3.fromRGB(240, 238, 230)
local IRON = Color3.fromRGB(30, 34, 36)
local HEDGE = Color3.fromRGB(86, 112, 62)
local RED = Color3.fromRGB(176, 44, 38)
local BRASS = Color3.fromRGB(200, 160, 72)

local QX = -4228 -- quay face (east-facing) along the basin's west edge
local DEPTH = 16 -- TownBuildings cottage depth
local EAST = -math.pi / 2 -- yaw: a lot / kit piece whose front (-Z) faces +X
local SOUTH = math.pi
local NORTH = 0

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { Workspace.Terrain }

local function ground(x: number, z: number): number
	local hit = Workspace:Raycast(Vector3.new(x, 500, z), Vector3.new(0, -700, 0), rayParams)
	return if hit then hit.Position.Y else 0
end

-- max / min ground over an axis-aligned rect (3 x 3 samples)
local function span(x0: number, z0: number, x1: number, z1: number): (number, number)
	local hi, lo = -math.huge, math.huge
	for i = 0, 2 do
		for j = 0, 2 do
			local y = ground(x0 + (x1 - x0) * i / 2, z0 + (z1 - z0) * j / 2)
			hi, lo = math.max(hi, y), math.min(lo, y)
		end
	end
	return hi, lo
end

local function group(parent: Instance, name: string, mode: Enum.ModelStreamingMode?): Model
	local m = Instance.new("Model")
	m.Name = name
	m.ModelStreamingMode = mode or Enum.ModelStreamingMode.Atomic
	m.Parent = parent
	return m
end

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	mat: Enum.Material,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.Shape = shape or Enum.PartType.Block
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CastShadow = size.X * size.Y * size.Z > 60
	p.Parent = parent
	return p
end

local function deco(p: Part): Part -- trim: no collision, no queries
	p.CanCollide = false
	p.CanQuery = false
	return p
end

local UP = CFrame.Angles(0, 0, math.pi / 2) -- a Part cylinder's axis is its X: this stands it upright

local function column(
	parent: Instance,
	name: string,
	dia: number,
	y0: number,
	y1: number,
	x: number,
	z: number,
	c: Color3,
	mat: Enum.Material
): Part
	return part(
		parent,
		name,
		Vector3.new(y1 - y0, dia, dia),
		CFrame.new(x, (y0 + y1) / 2, z) * UP,
		c,
		mat,
		Enum.PartType.Cylinder
	)
end

-- an asset clone (static, collides) at cf, or nil when it did not load
local function asset(parent: Instance, name: string, cf: CFrame): Model?
	local ok, m = pcall(AssetLoader.cloneStatic, name, "LOD0", true)
	if not ok or not m then
		return nil
	end
	-- shortcut: no rain-wet swap on Penwyn's props and boats (halves their instances for the island's 3,000 budget)
	for _, d in m:GetDescendants() do
		if d.Name == "SurfaceVariants" then
			d:Destroy()
		end
	end
	m:PivotTo(cf)
	m.Parent = parent
	return m
end

local function at(x: number, y: number, z: number, yaw: number): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0)
end

-- a paved strip along pts (each segment a tilted slab): a Pebble skin on a Granite body reaching down to the lowest
-- ground beside it (on a slope its downhill face is the retaining wall); `low` = the downhill side for a parapet
local function ribbon(
	parent: Instance,
	pts: { Vector3 },
	width: number,
	skin: Color3,
	low: Vector3?
)
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local len = (b - a).Magnitude
		local mid = (a + b) / 2
		local cf = CFrame.lookAt(mid, b)
		local r = cf.RightVector * (width / 2)
		local _, lo = span(
			math.min(a.X - r.X, b.X + r.X),
			math.min(a.Z - r.Z, b.Z + r.Z),
			math.max(a.X - r.X, b.X + r.X),
			math.max(a.Z - r.Z, b.Z + r.Z)
		)
		local d = math.max(1.2, mid.Y - lo + 1.5)
		part(
			parent,
			"Skin",
			Vector3.new(width, 0.3, len + 0.4),
			cf * CFrame.new(0, -0.15, 0),
			skin,
			Mat.Pebble
		)
		part(
			parent,
			"Body",
			Vector3.new(width + 0.6, d, len + 0.6),
			cf * CFrame.new(0, -0.3 - d / 2, 0),
			GRANITE,
			Mat.Granite
		)
		if low and d > 2.5 then
			local s = if cf.RightVector:Dot(low) > 0 then 1 else -1
			part(
				parent,
				"Parapet",
				Vector3.new(1.2, 2.6, len + 0.6),
				cf * CFrame.new(s * (width / 2 + 0.3), 1.3, 0),
				GRANITE,
				Mat.Granite
			)
		end
	end
end

-- points every `step` studs along a polyline of (x, z), Y = the highest ground across `width` + lift (never below `floor`)
local function track(xz: { Vector2 }, step: number, width: number, floor: number): { Vector3 }
	local out: { Vector3 } = {}
	for i = 1, #xz - 1 do
		local a, b = xz[i], xz[i + 1]
		local n = math.max(1, math.ceil((b - a).Magnitude / step))
		for k = 0, if i == #xz - 1 then n else n - 1 do
			local p = a:Lerp(b, k / n)
			local d = (b - a).Unit
			local side = Vector2.new(-d.Y, d.X) * (width / 2)
			local y = math.max(
				ground(p.X, p.Y),
				ground(p.X + side.X, p.Y + side.Y),
				ground(p.X - side.X, p.Y - side.Y)
			)
			table.insert(out, Vector3.new(p.X, math.max(y + 0.35, floor), p.Y))
		end
	end
	return out
end

---------------------------------------------------------------------------------------------------- the village

local houseCount = 0

-- one TownBuildings terrace house; centre (x, z), front facing yaw; floor at the highest ground under its front edge
local function house(
	parent: Instance,
	x: number,
	z: number,
	yaw: number,
	w: number,
	n: number,
	o: { [string]: any }?
)
	local opts: { [string]: any } = o or {}
	local d = opts.depth or DEPTH
	local cf = at(x, 0, z, yaw)
	local f0 = cf * CFrame.new(-w / 2, 0, -d / 2)
	local f1 = cf * CFrame.new(w / 2, 0, -d / 2)
	local b1 = cf * CFrame.new(w / 2, 0, d / 2)
	local hi = math.max(
		ground(f0.X, f0.Z),
		ground(f1.X, f1.Z),
		ground((f0.X + f1.X) / 2, (f0.Z + f1.Z) / 2)
	)
	local _, lo =
		span(math.min(f0.X, b1.X), math.min(f0.Z, b1.Z), math.max(f0.X, b1.X), math.max(f0.Z, b1.Z))
	local lot = {
		cf = cf,
		w = w,
		depth = d,
		kind = opts.kind,
		floors = opts.floors,
		corner = opts.corner or false,
		shop = opts.shop or false,
	}
	houseCount += 1
	local ok, err = pcall(TownBuildings.terrace, parent, lot :: any, n, math.min(lo, hi), hi)
	if not ok then
		warn(`[Penwyn] house {n}: {err}`)
	end
end

-- a row of houses along z from z0 (north edge), fronts facing `yaw` at x (centre line)
local function row(
	parent: Instance,
	x: number,
	z0: number,
	yaw: number,
	lots: { { any } },
	n0: number
): number
	local z = z0
	local n = n0
	for _, l in lots do
		local w = l[1]
		house(parent, x, z + w / 2, yaw, w, l[2] or n, l[3])
		z += w
		n += 1
	end
	return n
end

-- the same along x from x0 (east edge) going west, fronts facing `yaw`, centre line z
local function rowWest(
	parent: Instance,
	x0: number,
	z: number,
	yaw: number,
	lots: { { any } },
	n0: number
): number
	local x = x0
	local n = n0
	for _, l in lots do
		local w = l[1]
		house(parent, x - w / 2, z, yaw, w, l[2] or n, l[3])
		x -= w
		n += 1
	end
	return n
end

local function palm(parent: Instance, p: Vector3, n: number)
	local h = 8 + n % 3
	local lean = CFrame.new(p) * CFrame.Angles(math.rad(4 + n % 5), math.rad(n * 47), 0)
	deco(
		part(
			parent,
			"PalmTrunk",
			Vector3.new(h, 0.8, 0.8),
			lean * CFrame.new(0, h / 2, 0) * UP,
			Color3.fromRGB(110, 96, 80),
			Mat.Wood,
			Enum.PartType.Cylinder
		)
	)
	local top = lean * CFrame.new(0, h, 0)
	for k = 0, 6 do
		deco(
			part(
				parent,
				"PalmLeaf",
				Vector3.new(0.5, 4.2, 0.12),
				top
					* CFrame.Angles(0, k * 2 * math.pi / 7, 0)
					* CFrame.Angles(math.rad(if k % 2 == 0 then 35 else 75), 0, 0)
					* CFrame.new(0, 2, 0),
				Color3.fromRGB(104, 124, 66),
				Mat.Fabric
			)
		)
	end
end

local function village(root: Model, padY: number)
	local houses = group(root, "Houses", Enum.ModelStreamingMode.Nonatomic)
	-- the harbour front: two blocks facing the quay, the Pilchard Inn on the Fore Street corner, shops below
	local front = QX - 40 - DEPTH / 2
	row(houses, front, -398, EAST, {
		{ 18, 30, { floors = 3 } },
		{ 16, 31, { floors = 2 } },
		{ 20, 20, { shop = true } },
		{ 14, 33, { floors = 3 } },
		{ 18, 2, { kind = "pub", shop = true, corner = true } },
	}, 0)
	row(houses, front, -288, EAST, {
		{ 18, 13, { shop = true, corner = true } },
		{ 14, 34, { floors = 3 } },
		{ 20, 11, { shop = true } },
		{ 16, 35, { floors = 2 } },
		{ 18, 36, { floors = 3 } },
	}, 0)
	-- Fore Street: both sides west of the front row, then the chapel and the square
	local fx = front - DEPTH / 2 - 6
	rowWest(houses, fx, -308 - DEPTH / 2, SOUTH, {
		{ 16, 37 },
		{ 18, 22, { shop = true } },
		{ 14, 38, { floors = 2 } },
		{ 20, 39 },
	}, 0)
	rowWest(houses, fx, -292 + DEPTH / 2, NORTH, {
		{ 18, 42, { floors = 2 } },
		{ 14, 43 },
	}, 0)
	house(houses, -4428, -308 - 15, SOUTH, 22, 48, { kind = "chapel", depth = 30 })
	-- the hill: three rows on level lanes (front east, over the lane), rows far enough apart to read over the roofs
	local hill = {
		{
			x = -4797,
			floors = 3,
			clusters = {
				{ z = -440, w = { 16, 18, 16 } },
				{ z = -380, w = { 18, 16, 18, 14 } },
				{ z = -286, w = { 16, 14, 18, 18 } },
			},
		},
		{
			x = -4867,
			floors = 2,
			clusters = { { z = -362, w = { 16, 18, 16 } }, { z = -288, w = { 16, 18, 16 } } },
		},
		{
			x = -4952,
			floors = 2,
			clusters = { { z = -332, w = { 20 } }, { z = -288, w = { 16, 18 } } },
		},
	}
	-- the slope round the village is turf, not the bake's bare rock (cottage gardens; the summit stays rocky)
	local region = Region3.new(Vector3.new(-5080, 0, -480), Vector3.new(-4740, 160, -120))
		:ExpandToGrid(4)
	for _, from in { Mat.Rock, Mat.Slate, Mat.Basalt } do
		Workspace.Terrain:ReplaceMaterial(region, 4, from, Mat.Grass)
	end
	local lanes = group(root, "Lanes", Enum.ModelStreamingMode.Nonatomic)
	local n = 50
	local crossings: { [number]: number } = {} -- lane x -> its height where the ope crosses (z -300)
	for r, h in hill do
		local lane, floors = h.x, h.floors
		local zMin, zMax = math.huge, -math.huge
		for _, c in h.clusters do
			local lots: { { any } } = {}
			local z = c.z
			for i, w in c.w do
				-- endon cottages on the upper rows (2 storeys keep the next row in view); a mix lower down
				local kind = if floors == 2 or (i + r) % 3 == 0 then "endon" else nil
				table.insert(
					lots,
					{ w, n, { kind = kind, floors = if (i + n) % 2 == 0 then 3 else 2 } } :: { any }
				)
				n += 1
				z += w
			end
			row(houses, lane - 5 - DEPTH / 2, c.z, EAST, lots, 0)
			zMin, zMax = math.min(zMin, c.z), math.max(zMax, z)
		end
		local pts =
			track({ Vector2.new(lane, zMin - 4), Vector2.new(lane, zMax + 4) }, 16, 10, padY + 0.2)
		ribbon(group(lanes, `Row{r}`), pts, 10, COBBLE, Vector3.xAxis)
		local y = 0
		for _, q in pts do
			y = math.max(y, if math.abs(q.Z + 300) < 17 then q.Y else 0)
		end
		crossings[lane] = y
	end
	-- Fore Street (flat) and the ope climbing the hill between the rows, then the footpath to the windmill
	local fore = group(lanes, "ForeStreet")
	ribbon(
		fore,
		{ Vector3.new(QX - 38, padY + 0.25, -300), Vector3.new(-4700, padY + 0.25, -300) },
		16,
		COBBLE
	)
	local ope = group(lanes, "Ope")
	local climb = track({ Vector2.new(-4700, -300), Vector2.new(-4965, -300) }, 10, 8, padY + 0.25)
	for i, q in climb do -- meet each row lane flush
		for x, y in crossings do
			if math.abs(q.X - x) < 6 then
				climb[i] = Vector3.new(q.X, y, q.Z)
			end
		end
	end
	ribbon(ope, climb, 8, COBBLE)
	local path = group(lanes, "Footpath")
	ribbon(
		path,
		track({
			Vector2.new(-4965, -300),
			Vector2.new(-5040, -318),
			Vector2.new(-5120, -316),
			Vector2.new(-5195, -300),
			Vector2.new(-5250, -268),
			Vector2.new(-5282, -252),
		}, 14, 6, padY),
		6,
		PATH
	)
	-- the quay apron and the chapel square
	local apron = group(lanes, "Apron")
	part(
		apron,
		"Apron",
		Vector3.new(QX - 9 - (front + DEPTH / 2), 0.3, 206),
		CFrame.new((QX - 9 + front + DEPTH / 2) / 2, padY + 0.1, -300),
		COBBLE,
		Mat.Pebble
	)
	local square = group(root, "ChapelSquare")
	part(
		square,
		"Paving",
		Vector3.new(44, 0.3, 26),
		CFrame.new(-4424, padY + 0.1, -279),
		COBBLE,
		Mat.Pebble
	)
	part(
		square,
		"CrossBase",
		Vector3.new(4, 2, 4),
		CFrame.new(-4424, padY + 1, -276),
		GRANITE,
		Mat.Granite
	)
	part(
		square,
		"CrossShaft",
		Vector3.new(1.2, 8, 1.2),
		CFrame.new(-4424, padY + 6, -276),
		GRANITE,
		Mat.Granite
	)
	deco(
		part(
			square,
			"CrossArm",
			Vector3.new(4, 1.2, 1.2),
			CFrame.new(-4424, padY + 8.4, -276),
			GRANITE,
			Mat.Granite
		)
	)
	palm(square, Vector3.new(-4440, padY, -270), 1)
	palm(square, Vector3.new(-4408, padY, -268), 2)
	local bench = StreetFurniture.build("M_Road_Bench")
	if bench then
		bench:PivotTo(at(-4424, padY + 0.25, -270, NORTH))
		bench.Parent = square
	end
	-- Cornish hedges (granite with a turf top) line Fore Street out to the hill and split the pad into small fields
	local hedges = group(root, "Hedges")
	for _, h in
		{
			{ -4460, -309, -4700, -309 },
			{ -4460, -291, -4700, -291 },
			{ -4640, -500, -4640, -312 },
			{ -4640, -288, -4640, -110 },
			{ -4460, -420, -4720, -420 },
			{ -4440, -180, -4720, -180 },
		}
	do
		local a, b = Vector3.new(h[1], padY, h[2]), Vector3.new(h[3], padY, h[4])
		local cf = CFrame.lookAt((a + b) / 2, b)
		local len = (b - a).Magnitude
		part(
			hedges,
			"Hedge",
			Vector3.new(2.4, 3.4, len),
			cf * CFrame.new(0, 1.7, 0),
			GRANITE_DARK,
			Mat.Granite
		)
		deco(
			part(
				hedges,
				"HedgeTop",
				Vector3.new(2.8, 1.2, len),
				cf * CFrame.new(0, 3.9, 0),
				HEDGE,
				Mat.Fabric
			)
		)
	end
	-- the net-drying ground behind the north hedge
	local nets = group(root, "NetGround")
	for i = 0, 3 do
		column(
			nets,
			"NetPole",
			0.5,
			padY,
			padY + 9,
			-4520 - i * 26,
			-350,
			Color3.fromRGB(96, 80, 62),
			Mat.Wood
		)
		if i < 3 then
			local net = deco(
				part(
					nets,
					"Net",
					Vector3.new(24, 6.5, 0.15),
					CFrame.new(-4533 - i * 26, padY + 5.4, -350) * CFrame.Angles(math.rad(6), 0, 0),
					Color3.fromRGB(46, 74, 70),
					Mat.Fabric
				)
			)
			net.Transparency = 0.35
		end
	end
end

---------------------------------------------------------------------------------------------------- the harbour

-- a granite harbour arm along a centreline: core from the seabed to the deck, a seaward parapet, a round head
local function arm(parent: Model, pts: { Vector3 }, inward: number, padY: number)
	local W = 14
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local len = (b - a).Magnitude
		local cf = CFrame.lookAt((a + b) / 2, b)
		local floor = -26
		part(
			parent,
			"Core",
			Vector3.new(W, padY - floor, len + W / 2),
			cf * CFrame.new(0, (padY + floor) / 2 - cf.Y, 0),
			GRANITE,
			Mat.Granite
		)
		-- local +X is the side `inward` points to (harbour side); the parapet runs on the other (seaward) edge
		local side = -inward
		part(
			parent,
			"Parapet",
			Vector3.new(2.6, 3.6, len + 2.6),
			cf * CFrame.new(side * (W / 2 - 1.3), padY + 1.8 - cf.Y, 0),
			GRANITE_DARK,
			Mat.Granite
		)
		deco(
			part(
				parent,
				"Coping",
				Vector3.new(3.2, 0.5, len + 3.2),
				cf * CFrame.new(side * (W / 2 - 1.3), padY + 3.85 - cf.Y, 0),
				GRANITE,
				Mat.Granite
			)
		)
		-- the harbour-side coping: dressed granite kerb proud of the face
		deco(
			part(
				parent,
				"InnerCoping",
				Vector3.new(1.6, 0.8, len + 1),
				cf * CFrame.new(inward * (W / 2 - 0.5), padY + 0.1 - cf.Y, 0),
				GRANITE_DARK,
				Mat.Granite
			)
		)
	end
	local head = pts[#pts]
	column(parent, "Head", 18, -26, padY, head.X, head.Z, GRANITE, Mat.Granite)
	deco(
		column(
			parent,
			"HeadCoping",
			19,
			padY - 0.6,
			padY + 0.3,
			head.X,
			head.Z,
			GRANITE_DARK,
			Mat.Granite
		)
	)
end

-- the harbour light on the north head: white tower, red band and cap, lantern (StreetController turns its beam)
local function harbourLight(parent: Instance, p: Vector3)
	local m = Instance.new("Model")
	m.Name = "PenwynHarbourLight"
	m:SetAttribute("LightId", "PenwynHarbour")
	local base = column(m, "Base", 9, p.Y, p.Y + 3, p.X, p.Z, GRANITE_DARK, Mat.Granite)
	column(m, "Tower", 6.5, p.Y + 3, p.Y + 19, p.X, p.Z, WHITE, Mat.Plaster)
	deco(column(m, "Band", 6.7, p.Y + 12, p.Y + 15, p.X, p.Z, RED, Mat.Plaster))
	deco(column(m, "Gallery", 9, p.Y + 19, p.Y + 19.6, p.X, p.Z, IRON, Mat.Metal))
	local lens = deco(
		part(
			m,
			"Lens",
			Vector3.new(4, 4, 4),
			CFrame.new(p + Vector3.new(0, 21.6, 0)),
			Color3.fromRGB(214, 220, 212),
			Mat.Glass,
			Enum.PartType.Ball
		)
	)
	CollectionService:AddTag(lens, "LighthouseLens")
	local att = Instance.new("Attachment")
	att.Name = "ATT_Light"
	att.Parent = lens
	deco(column(m, "Cap", 5.4, p.Y + 23.4, p.Y + 24.6, p.X, p.Z, RED, Mat.SmoothPlastic))
	deco(
		part(
			m,
			"Finial",
			Vector3.new(1, 1, 1),
			CFrame.new(p + Vector3.new(0, 25.2, 0)),
			IRON,
			Mat.Metal,
			Enum.PartType.Ball
		)
	)
	m.PrimaryPart = base
	CollectionService:AddTag(m, "Lighthouse")
	m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	m.Parent = parent
end

-- quay lanterns on iron posts: the panes are CottageRig glow parts (Neon at night)
local function lanterns(parent: Instance, spots: { Vector3 })
	local m = Instance.new("Model")
	m.Name = "Lanterns"
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	for i, p in spots do
		local post = column(m, "LampPost", 0.5, p.Y, p.Y + 10, p.X, p.Z, IRON, Mat.Metal)
		if i == 1 then
			m.PrimaryPart = post
		end
		deco(
			part(
				m,
				"Lamp_GlassLit_",
				Vector3.new(1.3, 1.8, 1.3),
				CFrame.new(p + Vector3.new(0, 11, 0)),
				Color3.fromRGB(26, 31, 36),
				Mat.Glass
			)
		)
		deco(
			part(
				m,
				"LampCap",
				Vector3.new(1.8, 0.5, 1.8),
				CFrame.new(p + Vector3.new(0, 12.1, 0)),
				IRON,
				Mat.Metal
			)
		)
		if i % 2 == 1 then
			local a = Instance.new("Attachment")
			a.Name = `ATT_Lamp_Window_{i}`
			a.Parent = post
			a.WorldPosition = p + Vector3.new(0, 11, 0)
		end
	end
	m.Parent = parent
	CottageRig.apply(m)
end

local function harbour(root: Model, island: any, padY: number, seaY: number)
	local h = group(root, "Harbour", Enum.ModelStreamingMode.Nonatomic)
	local jz = island.dock.Z
	-- the basin's west edge pokes above the sea at the quay's ends: cut it back to the dredged floor
	Workspace.Terrain:FillBlock(CFrame.new(QX + 22, 0, -300), Vector3.new(44, 24, 176), Mat.Air)
	-- quay: core block, kit faces (north and south runs either side of the jetty root), the jetty, its head
	local quay = group(h, "Quay")
	part(
		quay,
		"QuayCore",
		Vector3.new(10, padY + 14, 184),
		CFrame.new(QX - 5.5, (padY - 14) / 2 - 0.1, -300),
		GRANITE,
		Mat.Granite
	)
	local jetty = group(h, "Jetty")
	local jEnd = island.dock.X - 13
	part(
		jetty,
		"JettyCore",
		Vector3.new(jEnd - QX + 4, padY + 14, 17),
		CFrame.new((QX + jEnd) / 2 - 2, (padY - 14) / 2 - 0.1, jz),
		GRANITE,
		Mat.Granite
	)
	local kits: { { any } } = {}
	local function run(z0: number, kinds: string)
		for i = 1, #kinds do
			local c = string.sub(kinds, i, i)
			table.insert(
				kits,
				{
					if c == "L" then "M_Hbr_QuayKit_LadderBay" else "M_Hbr_QuayKit_Straight",
					at(QX, padY + 0.04, z0 + 9 * (i - 0.5), EAST),
					quay,
				} :: { any }
			)
		end
	end
	run(jz - 81, "SSSLSSSS")
	run(jz + 9, "SSSSLSSS")
	local slots = math.floor((jEnd - QX) / 9)
	for s = 1, slots do
		local x = QX + 9 * (s - 0.5)
		table.insert(
			kits,
			{ "M_Hbr_QuayKit_Straight", at(x, padY + 0.04, jz - 9, math.atan2(0, 1)), jetty } :: { any }
		)
		table.insert(
			kits,
			{
				if s == 3 then "M_Hbr_QuayKit_LadderBay" else "M_Hbr_QuayKit_Straight",
				at(x, padY + 0.04, jz + 9, math.atan2(0, -1)),
				jetty,
			} :: { any }
		)
	end
	table.insert(
		kits,
		{ "M_Hbr_QuayKit_Head", at(QX + 9 * slots, padY + 0.04, jz, EAST), jetty } :: { any }
	)
	-- the drop-off berth: yellow edge at the jetty head (boats stop at island.dock, just off it)
	deco(
		part(
			jetty,
			"BerthEdge",
			Vector3.new(0.6, 0.12, 17),
			CFrame.new(QX + 9 * slots - 0.6, padY + 0.12, jz),
			Color3.fromRGB(232, 190, 40),
			Mat.SmoothPlastic
		)
	)
	-- arms: north and south, root at the quay ends, dog-legged to the mouth (east)
	local north = group(h, "NorthArm")
	local south = group(h, "SouthArm")
	local nPts = {
		Vector3.new(QX - 2, 0, jz - 88),
		Vector3.new(-4070, 0, jz - 114),
		Vector3.new(-3998, 0, jz - 66),
	}
	local sPts = {
		Vector3.new(QX - 2, 0, jz + 88),
		Vector3.new(-4070, 0, jz + 114),
		Vector3.new(-3998, 0, jz + 66),
	}
	arm(north, nPts, 1, padY)
	arm(south, sPts, -1, padY)
	harbourLight(root, Vector3.new(nPts[3].X, padY, nPts[3].Z))
	-- the south head: a green day-mark beacon
	column(
		south,
		"Beacon",
		1.2,
		padY,
		padY + 14,
		sPts[3].X,
		sPts[3].Z,
		Color3.fromRGB(40, 110, 64),
		Mat.Metal
	)
	deco(
		part(
			south,
			"BeaconTop",
			Vector3.new(3, 3, 3),
			CFrame.new(sPts[3].X, padY + 15, sPts[3].Z),
			Color3.fromRGB(40, 140, 70),
			Mat.SmoothPlastic,
			Enum.PartType.Ball
		)
	)
	-- the slipway: south of the south arm, from the pad down the natural beach into the sea
	local slip = group(h, "Slipway")
	local sp = track({ Vector2.new(QX - 20, jz + 128), Vector2.new(QX + 70, jz + 128) }, 15, 12, -7)
	for i, p in sp do
		sp[i] = Vector3.new(
			p.X,
			math.min(p.Y, padY + 0.25, if i > 1 then sp[i - 1].Y else math.huge),
			p.Z
		)
	end
	ribbon(slip, sp, 12, Color3.fromRGB(160, 156, 148))

	-- the kit pieces and props load in parallel (the greybox cores stand if one fails)
	-- quay clutter: { asset, x, z, stack level, yaw }; stacks share x, z (the first copy measures the height)
	local props: { { any } } = {}
	for _, s in
		{
			{ "M_Hbr_LobsterPot_01", QX - 12, -384, 0, 0.2 },
			{ "M_Hbr_LobsterPot_01", QX - 12, -384, 1, 0.5 },
			{ "M_Hbr_LobsterPot_01", QX - 12, -384, 2, 0.1 },
			{ "M_Hbr_LobsterPot_02", QX - 15, -379, 0, 1.4 },
			{ "M_Hbr_LobsterPot_02", QX - 15, -379, 1, 1.1 },
			{ "M_Hbr_NetPile", QX - 8, -360, 0, 0.6 },
			{ "M_Hbr_FishBox_01", QX - 13, -334, 0, 0 },
			{ "M_Hbr_FishBox_01", QX - 13, -334, 1, 0.15 },
			{ "M_Hbr_FishBox_01", QX - 13, -334, 2, -0.1 },
			{ "M_Hbr_FishBox_02", QX - 13, -329, 0, 0.3 },
			{ "M_Hbr_Rope_Coil", QX - 4, -322, 0, 0 },
			{ "M_Hbr_LifebuoyStation", QX - 3, -314, 0, EAST },
			{ "M_Hbr_LifebuoyStation", QX - 3, -286, 0, EAST },
			{ "M_Hbr_FishBox_02", QX - 12, -266, 0, 0.2 },
			{ "M_Hbr_FishBox_02", QX - 12, -266, 1, 0 },
			{ "M_Hbr_LobsterPot_02", QX - 14, -255, 0, 0.4 },
			{ "M_Hbr_LobsterPot_02", QX - 14, -255, 1, 0.9 },
			{ "M_Hbr_LobsterPot_02", QX - 14, -255, 2, 0.2 },
			{ "M_Hbr_LobsterPot_01", QX - 10, -250, 0, 2.1 },
			{ "M_Hbr_NetPile", QX - 8, -232, 0, 2.6 },
			{ "M_Hbr_Rope_Coil", QX - 4, -224, 0, 0 },
			-- the north pad by the arm root: pot stacks and nets waiting for the boats
			{ "M_Hbr_LobsterPot_01", QX - 24, -428, 0, 0.3 },
			{ "M_Hbr_LobsterPot_01", QX - 24, -428, 1, 0.6 },
			{ "M_Hbr_LobsterPot_02", QX - 28, -434, 0, 1.2 },
			{ "M_Hbr_LobsterPot_02", QX - 28, -434, 1, 1.5 },
			{ "M_Hbr_NetPile", QX - 36, -440, 0, 1.2 },
			-- the jetty head (the drop-off berth): a lifebuoy and a fish box
			{ "M_Hbr_LifebuoyStation", jEnd - 6, jz - 7, 0, SOUTH },
			{ "M_Hbr_FishBox_01", jEnd - 14, jz + 5, 0, 0.4 },
		} :: { { any } }
	do
		table.insert(
			props,
			{ s[1], at(s[2], padY, s[3], s[5]), if s[2] > QX then jetty else quay, s[4] } :: { any }
		)
	end
	local bollards: { CFrame } = {}
	for z = jz - 76, jz + 76, 38 do
		if math.abs(z - jz) > 12 then
			table.insert(bollards, CFrame.new(QX - 1.6, padY, z))
		end
	end
	for s = 1, slots - 1, 2 do
		table.insert(bollards, CFrame.new(QX + 9 * s, padY, jz - 7.4))
		table.insert(bollards, CFrame.new(QX + 9 * s, padY, jz + 7.4))
	end
	local names: { [string]: boolean } = { M_Hbr_Bollard_01 = true, M_Ani_HerringGull = true }
	for _, k in kits do
		names[k[1]] = true
	end
	for _, p in props do
		names[p[1]] = true
	end
	for _, b in { "M_Veh_MooredBoat_01", "M_Veh_MooredBoat_02", "M_Veh_MooredBoat_03" } do
		names[b] = true
	end
	for n in names do
		task.spawn(AssetLoader.getTemplate, n, "LOD0")
	end
	for _, k in kits do
		asset(k[3], k[1], k[2])
	end
	local stackH: { [string]: number } = {}
	for _, p in props do
		local name, cf, parent, level = p[1], p[2], p[3], p[4]
		local h0 = stackH[name]
		local m = asset(parent, name, cf + Vector3.new(0, (h0 or 0) * level, 0))
		if m and not h0 then
			stackH[name] = m:GetExtentsSize().Y
			if level > 0 then
				m:PivotTo(cf + Vector3.new(0, stackH[name] * level, 0))
			end
		end
	end
	local gulls = 0
	for i, cf in bollards do
		local b = asset(quay, "M_Hbr_Bollard_01", cf)
		if b and i % 3 == 1 then
			local bcf, size = b:GetBoundingBox()
			local ok, g = pcall(AssetLoader.cloneStatic, "M_Ani_HerringGull", "LOD0", false)
			if ok and g then
				g:PivotTo(at(cf.X, bcf.Y + size.Y / 2, cf.Z, i * 1.3))
				g.Parent = quay
				gulls += 1
			end
		end
	end
	-- boats: alongside the quay and the jetty, swinging on moorings (clear of the mouth-to-dock lane), outside
	local boats = group(h, "Boats", Enum.ModelStreamingMode.Nonatomic)
	for _, b in
		{
			{ "M_Veh_MooredBoat_02", QX + 6, jz - 55, 0 },
			{ "M_Veh_MooredBoat_02", QX + 26, jz - 14.5, -90 },
			{ "M_Veh_MooredBoat_03", -4128, jz - 89, -81 },
			{ "M_Veh_MooredBoat_02", -4118, jz + 58, 100 },
			{ "M_Veh_MooredBoat_01", -4150, jz - 52, 70 },
		} :: { { any } }
	do
		local m = group(boats, "Boat")
		asset(m, b[1], at(b[2], seaY, b[3], math.rad(b[4])))
	end
	-- the lobster-pot field off the north arm: orange floats with a flag
	local pots = group(h, "PotBuoys")
	for i, p in
		{
			{ -3880, -560 },
			{ -3846, -604 },
			{ -3816, -546 },
			{ -3866, -646 },
			{ -3800, -612 },
			{ -3832, -690 },
		}
	do
		local x, z = p[1], jz + 300 + p[2]
		deco(
			part(
				pots,
				"Float",
				Vector3.new(1.8, 1.8, 1.8),
				CFrame.new(x, seaY + 0.4, z),
				Color3.fromRGB(236, 110, 34),
				Mat.SmoothPlastic,
				Enum.PartType.Ball
			)
		)
		deco(column(pots, "Dan", 0.2, seaY, seaY + 5, x, z, IRON, Mat.Metal))
		deco(
			part(
				pots,
				"Flag",
				Vector3.new(0.05, 1, 1.4),
				CFrame.new(x, seaY + 4.4, z + 0.7) * CFrame.Angles(0, i, 0),
				if i % 2 == 0 then Color3.fromRGB(30, 30, 34) else RED,
				Mat.Fabric
			)
		)
	end
	-- lanterns along the apron and on the jetty, benches facing the boats
	local spots: { Vector3 } = {}
	for z = jz - 80, jz + 80, 32 do
		table.insert(spots, Vector3.new(QX - 6, padY, z + 6))
	end
	table.insert(spots, Vector3.new(jEnd - 3, padY, jz + 7))
	lanterns(quay, spots)
	for _, z in { jz - 26, jz + 26 } do
		local bench = StreetFurniture.build("M_Road_Bench")
		if bench then
			bench:PivotTo(at(QX - 10, padY + 0.25, z, EAST))
			bench.Parent = quay
		end
	end
	root:SetAttribute("PenwynGulls", gulls)
end

---------------------------------------------------------------------------------------------------- the hill

-- the landmark: a white Cornish tower mill, its sails (canvas on lattice stocks) turning to the east on a motor hinge
local function windmill(root: Model, p: Vector3)
	local m = Instance.new("Model")
	m.Name = "PenwynWindmill"
	local y0 = p.Y - 3
	local plinth = column(m, "Plinth", 28, y0 - 4, y0 + 4, p.X, p.Z, GRANITE, Mat.Granite)
	local seg, y = 11.5, y0 + 4
	for i = 0, 3 do
		column(
			m,
			`Tower{i + 1}`,
			24 - i * 2.2,
			y + seg * i,
			y + seg * (i + 1) + 0.05,
			p.X,
			p.Z,
			WHITE,
			Mat.Plaster
		)
	end
	local top = y + seg * 4
	-- the gallery (the lookout ring), door, windows (lit at night through CottageRig)
	deco(
		column(m, "Gallery", 31, y + 22.6, y + 23.2, p.X, p.Z, Color3.fromRGB(70, 60, 50), Mat.Wood)
	)
	for k = 0, 11 do
		local a = k * math.pi / 6
		deco(
			part(
				m,
				"Rail",
				Vector3.new(0.3, 3, 8.2),
				CFrame.new(p.X + math.cos(a) * 15.3, y + 24.7, p.Z + math.sin(a) * 15.3)
					* CFrame.Angles(0, -a, 0),
				IRON,
				Mat.Metal
			)
		)
	end
	local east = Vector3.new(1, 0, 0)
	deco(
		part(
			m,
			"Door",
			Vector3.new(0.6, 8, 5),
			CFrame.new(p + east * 11.8 + Vector3.new(0, y + 4 - p.Y, 0)),
			Color3.fromRGB(30, 52, 86),
			Mat.Wood
		)
	)
	deco(
		part(
			m,
			"DoorHead",
			Vector3.new(1, 1.2, 7),
			CFrame.new(p + east * 11.9 + Vector3.new(0, y + 8.6 - p.Y, 0)),
			GRANITE,
			Mat.Granite
		)
	)
	for k, wy in { 16, 28, 38 } do
		local r = (24 - 2.2 * math.floor(wy / seg)) / 2 + 0.1
		local a = if k == 2 then 0.5 else -0.35
		local c = Vector3.new(p.X + math.cos(a) * r, y + wy, p.Z + math.sin(a) * r)
		deco(
			part(
				m,
				"Mill_GlassLit_",
				Vector3.new(2.4, 3.6, 0.6),
				CFrame.lookAt(c, c + (c - Vector3.new(p.X, c.Y, p.Z))),
				Color3.fromRGB(26, 31, 36),
				Mat.Glass
			)
		)
	end
	-- the cap: a dark dome with a finial
	deco(column(m, "CapRing", 18.6, top, top + 1.6, p.X, p.Z, Color3.fromRGB(52, 54, 58), Mat.Wood))
	deco(
		part(
			m,
			"Cap",
			Vector3.new(17, 17, 17),
			CFrame.new(p.X, top + 1.2, p.Z),
			Color3.fromRGB(48, 50, 54),
			Mat.RoofShingles,
			Enum.PartType.Ball
		)
	)
	deco(
		part(
			m,
			"Finial",
			Vector3.new(1.6, 1.6, 1.6),
			CFrame.new(p.X, top + 10.4, p.Z),
			BRASS,
			Mat.Metal,
			Enum.PartType.Ball
		)
	)
	-- windshaft (anchored) and the sails' hub (unanchored, hinged, everything else welded to it)
	local hubAt = Vector3.new(p.X + 18, top + 1.5, p.Z)
	local shaft = deco(
		part(
			m,
			"Windshaft",
			Vector3.new(18, 2.2, 2.2),
			CFrame.new(hubAt - Vector3.new(9, 0, 0)),
			Color3.fromRGB(60, 50, 40),
			Mat.Wood,
			Enum.PartType.Cylinder
		)
	)
	local hub = part(
		m,
		"Hub",
		Vector3.new(2.4, 3.6, 3.6),
		CFrame.new(hubAt + Vector3.new(1.2, 0, 0)),
		Color3.fromRGB(46, 40, 34),
		Mat.Wood,
		Enum.PartType.Cylinder
	)
	local wood = Color3.fromRGB(92, 74, 56)
	local sails: { Part } = {}
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		local dir = Vector3.new(0, math.cos(a), math.sin(a))
		local perp = Vector3.new(0, -math.sin(a), math.cos(a))
		local o = hubAt + Vector3.new(1.4, 0, 0)
		table.insert(
			sails,
			part(
				m,
				"Stock",
				Vector3.new(0.9, 0.9, 40),
				CFrame.fromMatrix(o + dir * 19, Vector3.xAxis, perp),
				wood,
				Mat.Wood
			)
		)
		local canvas = part(
			m,
			"Canvas",
			Vector3.new(0.25, 7, 28),
			CFrame.fromMatrix(o + dir * 23 + perp * 4 + Vector3.new(0.4, 0, 0), Vector3.xAxis, perp),
			Color3.fromRGB(232, 222, 198),
			Mat.Fabric
		)
		table.insert(sails, canvas)
		for b = 0, 2 do
			table.insert(
				sails,
				part(
					m,
					"Bar",
					Vector3.new(0.5, 8.4, 0.5),
					CFrame.fromMatrix(
						o + dir * (12 + b * 11) + perp * 4 + Vector3.new(0.7, 0, 0),
						Vector3.xAxis,
						perp
					),
					wood,
					Mat.Wood
				)
			)
		end
	end
	for _, s in sails do
		s.CanCollide, s.CanQuery, s.Massless, s.Anchored = false, false, true, false
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = hub, s
		w.Parent = s
	end
	hub.CanCollide, hub.CanQuery, hub.Anchored = false, false, false
	hub.CustomPhysicalProperties = PhysicalProperties.new(50, 0.3, 0.5)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(9, 0, 0)
	a0.Parent = shaft
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(-1.2, 0, 0)
	a1.Parent = hub
	local hinge = Instance.new("HingeConstraint")
	hinge.Attachment0, hinge.Attachment1 = a0, a1
	hinge.ActuatorType = Enum.ActuatorType.Motor
	hinge.AngularVelocity = 0.3
	hinge.MotorMaxTorque = 1e9
	hinge.Parent = hub
	m.PrimaryPart = plinth
	m:ScaleTo(1.4) -- the island mark: at 1x the tower read as a speck from the open sea
	m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	m.Parent = root
	pcall(hub.SetNetworkOwner, hub, nil)
	CottageRig.apply(m)
end

-- the stamp post (B2 hooks it): a granite post with a sloping brass plate
local function stampPost(root: Model, p: Vector3)
	local m = group(root, "StampPost")
	m:SetAttribute("Island", "Penwyn")
	local post = part(
		m,
		"Post",
		Vector3.new(1.6, 4.2, 1.6),
		CFrame.new(p + Vector3.new(0, 1.6, 0)),
		GRANITE,
		Mat.Granite
	)
	deco(
		part(
			m,
			"Plate",
			Vector3.new(1.9, 0.2, 1.6),
			CFrame.new(p + Vector3.new(0, 3.85, 0)) * CFrame.Angles(math.rad(-25), 0, 0),
			BRASS,
			Mat.Metal
		)
	).Reflectance =
		0.25
	deco(
		part(
			m,
			"Boss",
			Vector3.new(0.12, 0.9, 0.9),
			CFrame.new(p + Vector3.new(0, 4.0, 0.1)) * CFrame.Angles(math.rad(-25), 0, 0) * UP,
			Color3.fromRGB(160, 120, 50),
			Mat.Metal,
			Enum.PartType.Cylinder
		)
	)
	m.PrimaryPart = post
	CollectionService:AddTag(m, "StampPost")
end

-- the lookout: a bench and a brass telescope facing the harbour
local function viewpoint(root: Model, x: number, z: number)
	local m = group(root, "Viewpoint")
	m:SetAttribute("Island", "Penwyn")
	local y = ground(x, z)
	part(m, "Pad", Vector3.new(14, 1, 9), CFrame.new(x, y - 0.3, z), COBBLE, Mat.Pebble)
	local bench = StreetFurniture.build("M_Road_Bench")
	if bench then
		bench:PivotTo(at(x, y + 0.2, z, EAST))
		bench.Parent = m
	end
	column(m, "ScopePost", 0.5, y, y + 3.6, x + 3, z - 4.5, IRON, Mat.Metal)
	deco(
		part(
			m,
			"Scope",
			Vector3.new(2.4, 0.5, 0.5),
			CFrame.new(x + 3.4, y + 4, z - 4.5) * CFrame.Angles(0, 0, math.rad(12)),
			BRASS,
			Mat.Metal,
			Enum.PartType.Cylinder
		)
	).Reflectance =
		0.2
	CollectionService:AddTag(m, "Viewpoint")
end

-- waymark posts along the footpath (the coast-path post: oak with a yellow arrow)
local function waymarks(root: Model, pts: { Vector2 })
	local m = group(root, "Waymarks")
	for _, p in pts do
		local y = ground(p.X, p.Y)
		part(
			m,
			"Waymark",
			Vector3.new(0.8, 4, 0.8),
			CFrame.new(p.X, y + 1.8, p.Y),
			Color3.fromRGB(120, 92, 62),
			Mat.Wood
		)
		deco(
			part(
				m,
				"Arrow",
				Vector3.new(0.85, 0.5, 0.5),
				CFrame.new(p.X, y + 3.2, p.Y),
				Color3.fromRGB(236, 196, 40),
				Mat.SmoothPlastic
			)
		)
	end
end

function M.place(base: Instance, island: any)
	local padY: number = island.pads[1].y
	local sea = Workspace:GetAttribute("SeaLevel")
	local seaY = if type(sea) == "number" then sea else 0
	local root = group(base, "Penwyn", Enum.ModelStreamingMode.Nonatomic)
	local function step(name: string, fn: () -> ())
		local ok, err = pcall(fn :: any)
		if not ok then
			warn(`[Penwyn] {name} failed: {err}`)
		end
	end
	step("windmill", function()
		windmill(
			root,
			Vector3.new(
				island.landmark.X,
				ground(island.landmark.X, island.landmark.Z),
				island.landmark.Z
			)
		)
	end)
	step("stamp", function()
		stampPost(
			root,
			Vector3.new(island.stamp.X, ground(island.stamp.X, island.stamp.Z), island.stamp.Z)
		)
	end)
	step("viewpoint", function()
		viewpoint(root, -5198, -314)
		waymarks(
			root,
			{ Vector2.new(-4970, -306), Vector2.new(-5080, -326), Vector2.new(-5190, -294) }
		)
	end)
	step("village", function()
		village(root, padY)
	end)
	step("harbour", function()
		harbour(root, island, padY, seaY)
	end)
	root:SetAttribute("PenwynHouses", houseCount)
	root:SetAttribute("PenwynParts", #root:GetDescendants())
end

return M
