--!strict
-- Street (I1b-3): Port Haven's streets and the Harbour Light, placed at run time after the building swaps
-- (WorldDressingService hooks Street.swaps into its swap list and spawns Street.start()).
--
--   * Road surfaces: the roads are terrain in the built-in Asphalt / Cobblestone (the quayside setts on Harbour Road,
--     x -180..180) / Pavement (gravel), tinted by Town.paint (no MaterialService slot overrides: the live client did
--     not load them). The bake paints the Haven Head farm track Ground; start() repaints it Pavement (gravel).
--   * Markings (white paint strips 5 mm proud, following the ray-cast terrain): two lanes on every Asphalt road,
--     centre dashes and edge lines, broken at junctions; at each RoadNet junction stop lines and, where all roads are
--     asphalt, three-aspect traffic lights cycled on the server clock (Shared/RoadNet, traffic keeps right).
--   * Granite kerbs (plain Granite, light warm grey; the RoadKerbGranite variant failed live, 125 mm upstand) along the town edge of Harbour Road (backed by a flush footway band hiding the terrain seam)
--     and both sides of Chapel Hill, dropped at the station apron / slipway, junctions, doors and prompts.
--   * R1a street furniture (AssetLoader.cloneStatic): M_Road_StreetLamp every ~28 m on Harbour Road (the quay side in
--     town, alternate sides beyond) and Chapel Hill, warm SpotLights at ATT_Light (shadows on Harbour Road) with the
--     Lens Neon at night / in a storm; benches on the quay facing the harbour with bins beside them and by the
--     Chandlery (no bollards: the quay apron is driven on). Every spot skips the carriageways, doors, prompt
--     markers, the slipway and the station apron, and anything solid already there.
--   * The Harbour Light (H6 M_Bld_HarbourLight) replaces Map.HarbourLight and the lifeguard tower (H6
--     M_Bld_LifeguardTower) the Haven Sands greybox through Street.swaps; Street.apply is their rig: _Glass Glass,
--     the Light's _Lens plain for the client beam, the tower's red-over-yellow flag at ATT_Flag (waved by the client,
--     src/client/Controllers/StreetController.luau, which also turns the Harbour Light's Fl(2) W 10s beam).
--   * Town streets (map pass 2, docs/17 P0 3): one side of every grid street parks in painted bays, a lay-by off the
--     30-stud carriageway with the kerb stepped out behind it (Harbour Road's town side too, west of the station and
--     east of the Chandlery); the other side and the junction approaches get double yellows. Slate-grey granite
--     flagstones (Parts: the terrain Concrete band reads as pale gravel) run kerb to house front; lamps every 56 studs
--     on the no-parking side with a bin at every other one. Fore Street: planters, benches, A-boards, hanging baskets
--     on the lamps and bunting across the shops. Road wear (P2 18): worn paint, patched asphalt, gully gratings and
--     manhole covers.
--   * Parked cars (G73): M_Road_ParkedCar_01..03 in the bays (about 3 in 10 left empty) and the Haven Sands car park,
--     facing the flow of the lane beside them.
-- Placement rules in StreetLayout (pure). Workspace.Dressing.Street attributes when done: StreetReady, StreetLamps,
-- StreetBenches, StreetBins, StreetParkedCars, StreetBays, StreetKerbs, StreetMarkings, StreetTrackCells, StreetWear,
-- StreetForeStreet.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AssetLoader = require(script.Parent.Parent:WaitForChild("Assets"):WaitForChild("AssetLoader"))
local ChandleryRig = require(script.Parent:WaitForChild("ChandleryRig"))
local CottageLights = require(script.Parent:WaitForChild("CottageLights"))
local StreetFurniture = require(script.Parent:WaitForChild("StreetFurniture"))
local StreetLayout = require(script.Parent:WaitForChild("StreetLayout"))
local Swaps = require(script.Parent:WaitForChild("Swaps"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local RoadNet = require(Shared:WaitForChild("RoadNet"))
local Weather = require(Shared:WaitForChild("Weather"))
local WorldConfig = require(Shared:WaitForChild("Config"):WaitForChild("WorldConfig"))

local Street = {}

Street.LIGHTHOUSE_TAG = "HarbourLight"
Street.LENS_TAG = "HarbourLightLens"

-- H6 M_Bld_HarbourLight on the east breakwater head (map/Build.luau buildLighthouse base: x 44, wallTop 6, wallFar
-- 360). The door (asset -Z) faces the harbour and the town; ATT_Plaque lands at (40.5, 11.1, 355.8), the logbook POI.
Street.swaps = {
	HarbourLight = {
		greybox = { "HarbourLight" },
		pivot = CFrame.new(44, 6, 360),
		shell = { "M_Bld_HarbourLight" },
		rig = "Street",
	},
	-- H6 M_Bld_LifeguardTower on Haven Sands (WorldConfig.Points HavenSandsTower, the Build.luau greybox: legs, hut,
	-- roof, flag pole and flags loose in Map.HavenSands). Yawed 180 degrees so the front (asset -Z: lookout, sign,
	-- stairs) faces the sea (+Z, the Haven Sands slipway); the pivot follows the sand under it.
	LifeguardTower = {
		greybox = { "HavenSands", "LifeguardHut" },
		pivot = CFrame.new(1010, 3.8, 250) * CFrame.Angles(0, math.pi, 0),
		shell = { "M_Bld_LifeguardTower" },
		ground = 10,
		rig = "Street",
	},
} :: { [string]: Swaps.Swap }

Street.TOWER_GREYBOX = { "Leg", "Roof", "FlagPole", "FlagRed", "FlagYellow" } -- the rest of the tower greybox
Street.FLAG_TAG = "BeachFlag"
Street.FLAG = { length = 4.5, height = 3, strips = 6 } -- studs: a 1.5 x 1.0 m red-over-yellow lifeguard flag

local LAMP = { spacing = 84, out = 1.6, angle = 110, range = 40, brightness = 2.5 } -- ~28 m, studs
local LAMP_3000K = Color3.fromRGB(255, 180, 107)
local LENS_ON = Color3.fromRGB(255, 214, 170)
local PAINT = Color3.fromRGB(232, 232, 226)
local KERB_TINT = Color3.fromRGB(168, 162, 152) -- light warm granite (236 read as pure white)
local MARK, GAP = 12, 15 -- centre dash 4 m mark, 5 m gap (TSM diagram 1004, <= 40 mph: verify)
local LINE_W = 0.3 -- 100 mm
local CATS_EYE = 54 -- studs (18 m, rural UK spacing)
local rng = Random.new(1729) -- paint wear, patches: the same street every run
local PAVED = {
	[Enum.Material.Concrete] = true,
	[Enum.Material.Asphalt] = true,
	[Enum.Material.Cobblestone] = true,
}
local KERB = { seg = 5.4, w = 0.9, h = 0.75, up = 0.375 } -- two 0.9 m stones, 125 mm upstand
-- parking bays: `len` kerb segments (16.2 studs, a 14-stud car) by `d` deep off the carriageway, none within `clear`
-- of a crossing road's edge; Granite tinted like the terrain asphalt (Parts cannot use Asphalt, TerrainOnly)
local BAY = { len = 3, d = 6.2, clear = 14, tint = Color3.fromRGB(64, 66, 70) }
local YELLOW = Color3.fromRGB(224, 176, 36)
local FLAG = { row = 4, back = 0.5, tint = Color3.fromRGB(100, 103, 106) } -- flags to footway + back (house front)
local FORE = "PortHaven_St1" -- Fore Street: the shops
local TOWN_LAMP = 56 -- studs between town lamps (one side)
-- Harbour Road's town-side footway: flush granite paving (Parts, straight edges) over the terrain's ragged asphalt /
-- paving seam, the kerb on its road edge; non-colliding, so the boat's road crossing and doors stay flat
local FOOTWAY = { w = 8, lift = 0.08, tint = Color3.fromRGB(150, 147, 140) }
local QUAY = { x0 = -180, x1 = 180, z = -20, edge = 4 } -- the quay apron in front of Harbour Road (Build.luau)
local KEEP_OUT: { StreetLayout.Rect } = {
	{ -185, -46, -72, 8 }, -- the station apron, the boat's road crossing and the slipway head
}
-- the lanes run through the station stretch of Harbour Road (the boat's road crossing is left plain: the yellow
-- hatched KEEP CLEAR box read as garish), broken only at a zebra crossing either side of the station
local ZEBRA_X = { -190, -62 } -- west of the slipway; between the station and the Chandlery, by the spawn
local MARK_OUT: { StreetLayout.Rect } = {}
for _, x in ZEBRA_X do
	table.insert(MARK_OUT, { x - 6, -46, x + 6, 8 })
end

local function roadById(id: string): any
	for _, r in WorldConfig.Roads do
		if r.id == id then
			return r
		end
	end
	return nil
end

local function plain(p: BasePart)
	for _, c in p:GetChildren() do
		if
			c:IsA("SurfaceAppearance") or (c:IsA("Configuration") and c.Name == "SurfaceVariants")
		then
			c:Destroy()
		end
	end
	CollectionService:RemoveTag(p, "HasWetVariant")
end

-- The red-over-yellow flag at ATT_Flag: `strips` vertical cloth strips (red top half, yellow bottom half) hung
-- from the halyard; the client (StreetController) waves them downwind. Built pointing +X from the hoist.
local function beachFlag(shell: Model, att: Attachment): Model
	local f = Instance.new("Model")
	f.Name = "BeachFlag"
	local w = Street.FLAG.length / Street.FLAG.strips
	local top = att.WorldPosition
	for i = 1, Street.FLAG.strips do
		for half, color in { Color3.fromRGB(200, 30, 30), Color3.fromRGB(246, 196, 0) } do
			local p = Instance.new("Part")
			p.Name = `Flag{i}_{half}`
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Material = Enum.Material.Fabric
			p.Color = color
			p.Size = Vector3.new(w + 0.02, Street.FLAG.height / 2, 0.04)
			p.CFrame = CFrame.new(
				top + Vector3.new((i - 0.5) * w, -Street.FLAG.height / 4 * (2 * half - 1), 0)
			)
			p:SetAttribute("Strip", i)
			p:SetAttribute("Half", half)
			p.Parent = f
		end
	end
	f:SetAttribute("HoistX", top.X)
	f:SetAttribute("HoistY", top.Y)
	f:SetAttribute("HoistZ", top.Z)
	f:AddTag(Street.FLAG_TAG)
	f.Parent = shell
	return f
end

local function glass(d: BasePart)
	plain(d)
	d.Material = Enum.Material.Glass
	d.Color = Color3.fromRGB(70, 84, 90)
	d.Transparency = 0.45
	d.Reflectance = 0.2
	d.CastShadow = false
end

local function lifeguardTower(shell: Model)
	for _, d in shell:GetDescendants() do
		if d:IsA("BasePart") and string.find(d.Name, "_Glass", 1, true) then
			glass(d)
		end
	end
	local sands = Workspace:FindFirstChild("Map")
		and (Workspace :: any).Map:FindFirstChild("HavenSands")
	local at = shell:GetPivot().Position
	if sands then
		for _, d in sands:GetChildren() do
			if
				d:IsA("BasePart")
				and table.find(Street.TOWER_GREYBOX, d.Name)
				and (Vector3.new(d.Position.X - at.X, 0, d.Position.Z - at.Z)).Magnitude < 16
			then
				d:Destroy()
			end
		end
	end
	local att = shell:FindFirstChild("ATT_Flag", true)
	if att and att:IsA("Attachment") then
		beachFlag(shell, att)
	else
		warn("[Street] M_Bld_LifeguardTower has no ATT_Flag: no beach flag")
	end
end

-- The rig of the Street.swaps buildings (WorldDressingService calls rig.apply(shell) after the pivot is set).
function Street.apply(shell: Model)
	if shell:GetAttribute("Asset") == "M_Bld_LifeguardTower" then
		lifeguardTower(shell)
		return
	end
	for _, d in shell:GetDescendants() do
		if d:IsA("BasePart") then
			if string.find(d.Name, "_Glass", 1, true) then
				glass(d)
			elseif string.find(d.Name, "_Lens", 1, true) then
				plain(d) -- the client drives Material / Color (Neon flashes at night, glass by day)
				d.Material = Enum.Material.Glass
				d.Color = Color3.fromRGB(214, 220, 212)
				d.Transparency = 0.1
				d.CastShadow = false
				d:AddTag(Street.LENS_TAG)
			end
		end
	end
	shell:AddTag(Street.LIGHTHOUSE_TAG)
end

-- ---------------------------------------------------------------- queries

local street: Model? = nil

local function terrainParams(): RaycastParams
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Include
	p.FilterDescendantsInstances = { Workspace.Terrain }
	return p
end

local function solidParams(): RaycastParams
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	local skip: { Instance } = { (street :: any) :: Instance }
	local zones = Workspace:FindFirstChild("Zones")
	if zones then
		table.insert(skip, zones)
	end
	p.FilterDescendantsInstances = skip
	return p
end

-- the ground under p, searching from `above` studs over the baked height down to `below` under it
local function ground(p: Vector3, params: RaycastParams, above: number?, below: number?): Vector3?
	local up = above or 6
	local hit = Workspace:Raycast(
		p + Vector3.new(0, up, 0),
		Vector3.new(0, -(up + (below or 12)), 0),
		params
	)
	return hit and hit.Position
end

-- lamps and parked cars stand on paving only (town footways), never on verges or open country
local function paved(p: Vector3): boolean
	local hit = Workspace:Raycast(p + Vector3.new(0, 8, 0), Vector3.new(0, -20, 0), terrainParams())
	return hit ~= nil and PAVED[hit.Material] == true
end

local function occupied(cf: CFrame, size: Vector3): boolean
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = { (street :: any) :: Instance, Workspace.Terrain }
	for _, part in Workspace:GetPartBoundsInBox(cf, size, op) do
		if part.CanCollide or part.Transparency < 0.95 then
			return true
		end
	end
	return false
end

-- prompt markers, doors, spawns, drop-offs, launch bays and world points (radius in studs)
local function blockers(): { StreetLayout.Blocker }
	local out: { StreetLayout.Blocker } = {}
	local roots: { Instance } = {}
	for _, n in { "Map", "Dressing" } do
		local r = Workspace:FindFirstChild(n)
		if r then
			table.insert(roots, r)
		end
	end
	local function add(pos: Vector3, r: number, cars: boolean?)
		table.insert(out, { pos = pos, r = r, cars = cars })
	end
	for _, root in roots do
		for _, d in root:GetDescendants() do
			if d:IsA("ProximityPrompt") then
				local h = d.Parent
				if h and h:IsA("BasePart") then
					add(h.Position, 9)
				elseif h and h:IsA("Attachment") then
					add(h.WorldPosition, 9)
				end
			elseif d:IsA("SpawnLocation") then
				add(d.Position, 10)
			elseif d:IsA("Attachment") and string.sub(d.Name, 1, 8) == "ATT_Door" then
				add(d.WorldPosition, 7, true) -- a car may park in front of a plain front door
			elseif d:IsA("Attachment") and string.sub(d.Name, 1, 11) == "ATT_BayDoor" then
				add(d.WorldPosition, 14)
			elseif d:IsA("BasePart") then
				local n = d.Name
				if
					string.find(n, "Prompt", 1, true)
					or string.find(n, "Anchor", 1, true)
					or string.find(n, "DropOff", 1, true)
					or string.match(n, "^Bay%d$")
					or (d.Parent and d.Parent.Name == "WorldPoints")
				then
					add(d.Position, 8 + math.max(d.Size.X, d.Size.Z) / 2)
				end
			end
		end
	end
	return out
end

-- ---------------------------------------------------------------- terrain: the farm track to gravel

local function repaintTrack(): number
	local track = roadById("HavenHeadTrack")
	if not track then
		return 0
	end
	local n = 0
	for _, s in StreetLayout.walk(track.points, 4) do
		local p = s.pos
		local region = Region3.new(p - Vector3.new(4, 8, 4), p + Vector3.new(4, 4, 4))
			:ExpandToGrid(4)
		Workspace.Terrain:ReplaceMaterial(region, 4, Enum.Material.Ground, Enum.Material.Pavement)
		n += 1
		if n % 60 == 0 then
			task.wait()
		end
	end
	return n
end

-- ---------------------------------------------------------------- markings and kerbs

local function strip(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	width: number,
	lift: number
): BasePart
	local mid = (a + b) / 2 + Vector3.new(0, lift, 0)
	local len = (b - a).Magnitude
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = Vector3.new(width, 0.1, len)
	p.CFrame = CFrame.lookAt(mid, mid + (b - a))
	p.Parent = parent
	return p
end

local function paint(
	parent: Instance,
	segs: { StreetLayout.Seg },
	name: string,
	params: RaycastParams,
	width: number?,
	colour: Color3?
): number
	local n = 0
	for _, seg in segs do
		local a = ground(seg.a, params)
		local b = ground(seg.b, params)
		if a and b and math.abs(a.Y - b.Y) < 4 then
			local p = strip(parent, name, a, b, width or LINE_W, 0.03) -- top 5 mm (0.016) + clearance over the chord
			p.Material = Enum.Material.SmoothPlastic
			-- worn: every stretch a little faded, some scuffed through to the asphalt
			local wear = rng:NextNumber()
			p.Color = (colour or PAINT):Lerp(Color3.fromRGB(150, 148, 140), wear * 0.25)
			p.Transparency = if wear > 0.8 then 0.35 else wear * 0.15
			n += 1
		end
	end
	return n
end

-- Two lanes on every asphalt road (drive on the right): centre dashes and edge lines, stopping at junction boxes
-- (RoadNet) and the zebras.
local JUNCTIONS = RoadNet.junctions(WorldConfig.Roads)

local function laneSegs(segs: { StreetLayout.Seg }): { StreetLayout.Seg }
	local out = {}
	for _, seg in segs do
		if
			RoadNet.clear(JUNCTIONS, seg.a)
			and RoadNet.clear(JUNCTIONS, seg.b)
			and StreetLayout.clear(seg.a, {}, MARK_OUT)
			and StreetLayout.clear(seg.b, {}, MARK_OUT)
		then
			table.insert(out, seg)
		end
	end
	return out
end

-- Harbour Road's centreline sample nearest x (the station stretch runs west-east)
local function roadAt(road: any, x: number): StreetLayout.Sample?
	local best: StreetLayout.Sample? = nil
	for _, c in StreetLayout.walk(road.points, 1) do
		if not best or math.abs(c.pos.X - x) < math.abs(best.pos.X - x) then
			best = c
		end
	end
	return best
end

-- the zebra crossings either side of the station
local function stationPaint(parent: Instance, params: RaycastParams): number
	local road = roadById("HarbourRoad")
	if not road then
		return 0
	end
	local n = 0
	for _, x in ZEBRA_X do
		local z = roadAt(road, x)
		if z and RoadNet.clear(JUNCTIONS, z.pos) then
			local across = z.dir:Cross(Vector3.yAxis)
			local bars = {}
			for v = -(road.width / 2 - 1.5), road.width / 2 - 1.5, 3 do
				local mid = z.pos + across * v
				table.insert(bars, { a = mid - z.dir * 3.5, b = mid + z.dir * 3.5 })
			end
			n += paint(parent, bars, "Zebra", params, 1.5)
		end
	end
	return n
end

local function markings(parent: Instance): number
	local params = terrainParams()
	local n = 0
	for _, road in WorldConfig.Roads do
		if road.surface == "Asphalt" then
			n += paint(
				parent,
				laneSegs(StreetLayout.dashes(road.points, MARK, GAP)),
				"CentreDash",
				params
			)
			if not (road :: any).town and road.id ~= "HarbourRoad" then -- countryside: cat's eyes, no lamps
				for _, c in StreetLayout.walk(road.points, CATS_EYE) do
					local g = ground(c.pos, params)
					if g and RoadNet.clear(JUNCTIONS, g) then
						local e =
							strip(parent, "CatsEye", g - c.dir * 0.2, g + c.dir * 0.2, 0.5, 0.06)
						e.Size = Vector3.new(0.5, 0.15, 0.4)
						e.Material = Enum.Material.SmoothPlastic
						e.Color = PAINT
						e.Reflectance = 0.6
						n += 1
					end
				end
			end
			local d = road.width / 2 - 0.75 -- line centre 0.25 m in from the edge
			local sides: { number } = if (road :: any).town then {} else { -1, 1 }
			for _, side in sides do
				n += paint(
					parent,
					laneSegs(StreetLayout.chain(road.points, 8, side, d)),
					"EdgeLine",
					params
				)
			end
			task.wait()
		end
	end
	return n + stationPaint(parent, params)
end

-- ---------------------------------------------------------------- junctions and traffic lights

local LAMP_COLOURS: { [string]: Color3 } = {
	red = Color3.fromRGB(255, 45, 30),
	amber = Color3.fromRGB(255, 165, 0),
	green = Color3.fromRGB(40, 255, 130),
}
local SOFT = {
	Enum.Material.Grass,
	Enum.Material.LeafyGrass,
	Enum.Material.Ground,
	Enum.Material.Mud,
	Enum.Material.Sand,
}

type Head = {
	j: RoadNet.Junction,
	group: number,
	lamps: { [string]: BasePart },
	light: PointLight,
	state: string?,
}

local function signalPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function setHead(h: Head, state: string)
	for name, p in h.lamps do
		local on = name == state
		p.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
		p.Color = if on
			then LAMP_COLOURS[name]
			else LAMP_COLOURS[name]:Lerp(Color3.new(0, 0, 0), 0.8)
	end
	h.light.Color = LAMP_COLOURS[state]
	h.state = state
end

-- a three-aspect signal on the near (right) side of the incoming lane, facing the traffic that stops at its line
local function signal(parent: Instance, j: RoadNet.Junction, arm: RoadNet.Arm, foot: Vector3): Head
	local m = Instance.new("Model")
	m.Name = "TrafficLight"
	local dark = Color3.fromRGB(30, 31, 33)
	local pole = signalPart(
		m,
		"Pole",
		Vector3.new(0.5, 11, 0.5),
		CFrame.new(foot + Vector3.new(0, 5.5, 0)),
		dark
	)
	pole.CanCollide = true
	pole.Material = Enum.Material.Metal
	local at = foot + Vector3.new(0, 9.4, 0)
	local cf = CFrame.lookAt(at, at + arm.dir) -- front (-Z) toward the oncoming cars
	signalPart(m, "Housing", Vector3.new(1.3, 3.9, 0.8), cf, dark)
	signalPart(m, "Backboard", Vector3.new(2.5, 5.1, 0.1), cf * CFrame.new(0, 0, 0.45), dark)
	-- the back is galvanised steel with two clamp straps: a black back read as a blank sign board (docs/17 N7)
	local galv = Color3.fromRGB(146, 150, 148)
	signalPart(m, "BackPlate", Vector3.new(2.5, 5.1, 0.04), cf * CFrame.new(0, 0, 0.52), galv).Material =
		Enum.Material.Metal
	for _, y in { 1.7, -1.7 } do
		signalPart(m, "Bracket", Vector3.new(0.9, 0.3, 0.12), cf * CFrame.new(0, y, 0.6), galv).Material =
			Enum.Material.Metal
	end
	-- the white border is a rim on the front face only: a white plate behind the board read as a blank sign board
	-- from the back (map pass 2, docs/17 P0 6)
	for _, rim in
		{
			{ Vector3.new(2.5, 0.16, 0.04), Vector3.new(0, 2.47, 0) },
			{ Vector3.new(2.5, 0.16, 0.04), Vector3.new(0, -2.47, 0) },
			{ Vector3.new(0.16, 5.1, 0.04), Vector3.new(1.17, 0, 0) },
			{ Vector3.new(0.16, 5.1, 0.04), Vector3.new(-1.17, 0, 0) },
		}
	do
		signalPart(
			m,
			"Border",
			rim[1],
			cf * CFrame.new(rim[2] + Vector3.new(0, 0, 0.38)),
			Color3.new(1, 1, 1)
		)
	end
	local lamps: { [string]: BasePart } = {}
	for i, name in { "red", "amber", "green" } do
		local lamp = signalPart(
			m,
			"Lamp_" .. name,
			Vector3.new(0.3, 1, 1),
			cf * CFrame.new(0, 1.25 * (2 - i), -0.4) * CFrame.Angles(0, math.pi / 2, 0), -- disc faces -Z
			LAMP_COLOURS[name]
		)
		lamp.Shape = Enum.PartType.Cylinder
		lamp.CastShadow = false
		lamps[name] = lamp
	end
	local light = Instance.new("PointLight")
	light.Range, light.Brightness = 10, 1.5
	light.Parent = m:FindFirstChild("Housing")
	m.Parent = parent
	return { j = j, group = arm.group, lamps = lamps, light = light, state = nil }
end

local function junctions(parent: Instance): ({ Head }, number)
	local params = terrainParams()
	local solid = solidParams()
	local heads: { Head } = {}
	for _, j in JUNCTIONS do
		local hit = Workspace:Raycast(j.pos + Vector3.new(0, 6, 0), Vector3.new(0, -18, 0), params)
		if hit then
			-- the bake paints each road on its own: fill the junction corners with the road's surface
			-- shortcut: an axis-aligned square of the junction radius, fine for the town; use arm wedges for skewed city junctions
			local r = j.radius
			local region = Region3.new(
				hit.Position - Vector3.new(r, 6, r),
				hit.Position + Vector3.new(r, 2, r)
			):ExpandToGrid(4)
			for _, soft in SOFT do
				Workspace.Terrain:ReplaceMaterial(region, 4, soft, hit.Material)
			end
		end
		for _, arm in j.arms do
			local c, across = RoadNet.incoming(arm)
			paint(
				parent,
				{ { a = c + across * 0.3, b = c + across * (arm.width / 2 - 0.4) } },
				"StopLine",
				params,
				0.9
			)
			local foot = if j.signals
				then ground(c + across * (arm.width / 2 + 1.5), solid)
				else nil
			if foot then
				table.insert(heads, signal(parent, j, arm, foot))
			end
		end
	end
	if #heads > 0 then
		task.spawn(function()
			while parent.Parent do
				local now = Workspace:GetServerTimeNow()
				for _, h in heads do
					local state = RoadNet.light(h.j, h.group, now)
					if state ~= h.state then
						setHead(h, state)
					end
				end
				task.wait(0.2)
			end
		end)
	end
	return heads, #JUNCTIONS
end

-- the side of a town street that parks: odd-numbered streets and avenues on the right (+1), even on the left
local function baySide(r: any): number
	local n = tonumber(string.match(r.id, "%d+$")) or 1
	return if n % 2 == 1 then 1 else -1
end

-- Harbour Road parks on its town side west of the station and east of the Chandlery (arc length from the west end)
local HARBOUR_BAYS = { { 40, 330 }, { 670, 830 } }

-- who owns a junction corner's paving: Harbour Road, then the streets; the avenues' flags stop at their footways
local function rank(r: any): number
	return if r.id == "HarbourRoad" then 2 elseif string.find(r.id, "_St", 1, true) then 1 else 0
end

local BOXES: { [any]: { number } } = {} -- road -> XZ bounds, to skip far roads in the paving test
for _, r in WorldConfig.Roads do
	local b = { math.huge, math.huge, -math.huge, -math.huge }
	for _, p in r.points do
		b = { math.min(b[1], p.X), math.min(b[2], p.Z), math.max(b[3], p.X), math.max(b[4], p.Z) }
	end
	BOXES[r] = b
end

local TOWN = WorldConfig.Towns[1] :: any
local FOOT = (if TOWN then TOWN.width / 2 + TOWN.footway else 23) + FLAG.back -- road centre to the paving's back

-- may `road`'s paving cover p: off the station apron, off every other carriageway and its kerb, and off the
-- footway of a road that owns the corner
local function paveClear(p: Vector3, road: any): boolean
	if not StreetLayout.clear(p, {}, KEEP_OUT) then
		return false
	end
	for _, o in WorldConfig.Roads do
		local b = BOXES[o]
		if
			o ~= road
			and p.X > b[1] - 30
			and p.X < b[3] + 30
			and p.Z > b[2] - 30
			and p.Z < b[4] + 30
		then
			local d = StreetLayout.distToPolyline(p, o.points)
			if d < o.width / 2 + KERB.w or (rank(o) > rank(road) and d < FOOT) then
				return false
			end
		end
	end
	return true
end

-- the clear part of the a..b span (both ends tested, a blocked end pulled in by bisection), or nil
local function clip(a: Vector3, b: Vector3, road: any): (Vector3?, Vector3?)
	local ca, cb = paveClear(a, road), paveClear(b, road)
	if ca and cb then
		return a, b
	elseif not ca and not cb then
		return nil, nil
	end
	local good, bad = if ca then a else b, if ca then b else a
	local lo, hi = 0, 1
	for _ = 1, 6 do
		local m = (lo + hi) / 2
		if paveClear(good:Lerp(bad, m), road) then
			lo = m
		else
			hi = m
		end
	end
	local edge = good:Lerp(bad, lo)
	if (edge - good).Magnitude < 0.5 then
		return nil, nil
	end
	return if ca then good else edge, if ca then edge else good
end

type Bay = { pos: Vector3, dir: Vector3, side: number }
type Run =
	{ road: any, side: number, from: number, to: number, bays: { { number } }, town: boolean }

-- Kerbs, paving, bays and edge paint along every kerbed run (Harbour Road's town side, Chapel Hill, the town grid).
-- Returns the kerb count and the bays (centre, travel dir, side) for parkedCars.
local function kerbs(parent: Instance, block: { StreetLayout.Blocker }): (number, { Bay })
	local params = terrainParams()
	local lane = roadById("TownLane")
	local harbour = roadById("HarbourRoad")
	local carsOk: { StreetLayout.Blocker } = {}
	for _, b in block do
		if not b.cars then
			table.insert(carsOk, b)
		end
	end
	local runs: { Run } = {}
	if harbour then -- the town (north) edge, end to end
		table.insert(runs, {
			road = harbour,
			side = -1,
			from = 0,
			to = math.huge,
			bays = HARBOUR_BAYS,
			town = false,
		})
	end
	if lane then
		for _, side in { -1, 1 } do -- up Chapel Hill to the last cottages
			table.insert(
				runs,
				{ road = lane, side = side, from = 10, to = 240, bays = {}, town = false }
			)
		end
	end
	for _, r in WorldConfig.Roads do
		if (r :: any).town then -- city grid streets: both kerbs, the whole length (junction gaps below)
			for _, side in { -1, 1 } do
				local bays = if side == baySide(r) then { { 0, math.huge } } else {}
				table.insert(
					runs,
					{ road = r, side = side, from = 0, to = math.huge, bays = bays, town = true }
				)
			end
		end
	end
	local keeps: { StreetLayout.Rect } = if TOWN then TOWN.keep else {}
	local n = 0
	local out: { Bay } = {}
	for _, run in runs do
		local road = run.road
		local e = road.width / 2
		local samples = StreetLayout.walk(road.points, KERB.seg, run.from, run.to)
		local segs = #samples - 1
		local function at(i: number, d: number): Vector3
			return StreetLayout.offset(samples[i], run.side, d)
		end
		local function mid(i: number, d: number): Vector3
			return (at(i, d) + at(i + 1, d)) / 2
		end
		-- a flat Granite slab along segment i from d0 to d1 off the centre, its top `top` over the ground
		local function slab(
			name: string,
			i: number,
			d0: number,
			d1: number,
			top: number,
			thick: number
		): BasePart?
			local a = ground(at(i, (d0 + d1) / 2), params)
			local b = ground(at(i + 1, (d0 + d1) / 2), params)
			if not (a and b and math.abs(a.Y - b.Y) < 3) then
				return nil
			end
			local p = strip(parent, name, a, b, d1 - d0, top - thick / 2)
			p.Size = Vector3.new(d1 - d0, thick, p.Size.Z)
			p.Material = Enum.Material.Granite
			return p
		end
		-- a strip across the run at sample j from d0 to d1 off the centre, nudged `shift` along the road
		local function across(
			name: string,
			j: number,
			d0: number,
			d1: number,
			w: number,
			shift: number
		): BasePart?
			local dir = samples[j].dir * shift
			local a, b = ground(at(j, d0) + dir, params), ground(at(j, d1) + dir, params)
			if not (a and b) then
				return nil
			end
			return strip(parent, name, a, b, w, 0.03)
		end
		-- a bay's end at sample j (sgn -1 its start, +1 its end): a white tick, and the kerb's return to the road
		-- edge where the bays stop
		local function bayEnd(j: number, sgn: number, last: boolean)
			local t = across("BayEnd", j, e, e + BAY.d - 0.2, LINE_W, -sgn * LINE_W)
			if t then
				t.Material = Enum.Material.SmoothPlastic
				t.Color = PAINT
			end
			local kb = if last
				then across("KerbReturn", j, e, e + BAY.d + KERB.w, KERB.w, sgn * KERB.w / 2)
				else nil
			if kb then
				kb.Size = Vector3.new(KERB.w, KERB.h, kb.Size.Z)
				kb.CFrame += Vector3.new(0, KERB.up - KERB.h / 2 - 0.03, 0)
				kb.Material = Enum.Material.Granite
				kb.Color = KERB_TINT
				kb.CastShadow = true
			end
		end
		local junction: { boolean } = {}
		local ok: { boolean } = {}
		for i = 1, segs do
			local k = mid(i, e + KERB.w / 2)
			local near = math.huge -- studs beyond the nearest crossing road's edge
			for _, other in WorldConfig.Roads do
				if other ~= road then
					near = math.min(
						near,
						StreetLayout.distToPolyline(k, other.points) - other.width / 2
					)
				end
			end
			junction[i] = near < 4
			local inRange = false
			for _, r in run.bays do
				inRange = inRange or (samples[i].s >= r[1] and samples[i + 1].s <= r[2])
			end
			local c = mid(i, e + BAY.d / 2)
			local keep = false
			for _, r in keeps do
				keep = keep or StreetLayout.inRect(c, r)
			end
			ok[i] = inRange
				and near >= BAY.clear
				and not keep
				and StreetLayout.clear(c, carsOk, KEEP_OUT)
				and paved(c)
		end
		local bay = StreetLayout.bays(ok, BAY.len)
		for i = 1, segs do
			local inBay = bay[i] ~= nil
			local kd = if inBay then e + BAY.d else e -- the kerb's road face
			-- paving behind the kerb: Harbour Road's footway band (one granite strip), else flagstones out to the
			-- house fronts in rows of about FLAG.row, each stone a shade off its neighbours, hairline joints
			if road == harbour or run.town then
				local d0, d1 = kd + KERB.w / 2, if run.town then FOOT else e + FOOTWAY.w
				local rows = if run.town
					then math.max(1, math.floor((d1 - d0) / FLAG.row + 0.5))
					else 1
				local w = (d1 - d0) / rows
				local joint = if run.town then 0.06 else 0
				for r = 1, rows do
					local c = d0 + (r - 0.5) * w
					local a, b = clip(at(i, c), at(i + 1, c), road)
					local ga = if a then ground(a, params) else nil
					local gb = if b then ground(b, params) else nil
					if ga and gb and math.abs(ga.Y - gb.Y) < 3 then
						local dir = (gb - ga).Unit * (if run.town then 0 else 0.3) -- overlap the next slab round bends
						local f = strip(
							parent,
							if run.town then "Flag" else "Footway",
							ga - dir,
							gb + dir,
							w,
							0
						)
						f.Size = Vector3.new(w - joint, 0.4, f.Size.Z - joint)
						f.CFrame += Vector3.new(0, FOOTWAY.lift - 0.2, 0)
						f.Material = Enum.Material.Granite
						if run.town then
							local j = rng:NextNumber(-1, 1)
							local toward = if j > 0
								then Color3.fromRGB(132, 128, 120)
								else Color3.fromRGB(72, 76, 82)
							f.Color = FLAG.tint:Lerp(toward, math.abs(j) * 0.4)
						else
							f.Color = FOOTWAY.tint
						end
					end
				end
			end
			if not junction[i] then
				if
					StreetLayout.clear(
						mid(i, kd + KERB.w / 2),
						if inBay then carsOk else block,
						KEEP_OUT
					)
					and harbour
					and StreetLayout.distToPolyline(mid(i, kd + KERB.w / 2), harbour.points)
						>= harbour.width / 2
				then
					local p = slab("Kerb", i, kd, kd + KERB.w, KERB.up, KERB.h)
					if p then
						p.Color = KERB_TINT
						p.CastShadow = true
						n += 1
					end
				end
				if inBay then
					local p = slab("Bay", i, e - 0.3, e + BAY.d + 0.1, 0.05, 0.2)
					if p then
						p.Color = BAY.tint
					end
					if run.town then -- the bay's carriageway edge, over the asphalt / bay seam
						local l = slab("BayLine", i, e - 0.35, e - 0.05, 0.08, 0.1)
						if l then
							l.Material = Enum.Material.SmoothPlastic
							l.Color = PAINT
						end
					end
					if bay[i - 1] ~= bay[i] then
						bayEnd(i, -1, bay[i - 1] == nil)
						local c = (at(i + 1, e + BAY.d / 2) + at(i + 2, e + BAY.d / 2)) / 2 -- the middle segment's mid
						table.insert(out, { pos = c, dir = samples[i].dir, side = run.side })
					end
					if bay[i + 1] == nil then
						bayEnd(i + 1, 1, true)
					end
				elseif run.town then -- no waiting: double yellows along the kerb
					for _, d in { e - 0.45, e - 1.05 } do
						local l = slab("Yellow", i, d - LINE_W / 2, d + LINE_W / 2, 0.08, 0.1)
						if l then
							l.Material = Enum.Material.SmoothPlastic
							local wear = rng:NextNumber()
							l.Color = YELLOW:Lerp(Color3.fromRGB(170, 150, 100), wear * 0.3)
							l.Transparency = wear * 0.15
						end
					end
				end
			end
			if i % 40 == 0 then
				task.wait()
			end
		end
	end
	return n, out
end

-- ---------------------------------------------------------------- furniture

type Placed = { model: Model, pos: Vector3 }

local function place(
	parent: Instance,
	asset: string,
	at: Vector3,
	yaw: number,
	footprint: Vector3,
	block: { StreetLayout.Blocker },
	params: RaycastParams
): Placed?
	if not StreetLayout.clear(at, block, KEEP_OUT) then
		return nil
	end
	for _, r in WorldConfig.Roads do
		if StreetLayout.distToPolyline(at, r.points) < r.width / 2 + 0.6 then
			return nil
		end
	end
	local g = ground(at, params, 8, 10)
	if not g or g.Y < 1 then
		return nil
	end
	local cf = CFrame.new(g) * CFrame.Angles(0, yaw, 0)
	if occupied(cf + Vector3.new(0, 0.5 + footprint.Y / 2, 0), footprint) then
		return nil
	end
	local m = StreetFurniture.build(asset) or AssetLoader.cloneStatic(asset, "LOD0", true)
	if not m then
		return nil
	end
	m:PivotTo(cf)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = parent
	return { model = m, pos = g }
end

type Lamp = { model: Model, shadows: boolean }

local function lamps(
	parent: Instance,
	block: { StreetLayout.Blocker },
	params: RaycastParams
): { Lamp }
	local out: { Lamp } = {}
	local runs: { { id: string, start: number, shadows: boolean, spacing: number, side: number? } } =
		{
			{ id = "HarbourRoad", start = 30, shadows = true, spacing = LAMP.spacing },
			{ id = "TownLane", start = 40, shadows = false, spacing = LAMP.spacing },
		}
	for _, r in WorldConfig.Roads do
		if (r :: any).town then -- the side without bays
			table.insert(
				runs,
				{ id = r.id, start = 30, shadows = false, spacing = TOWN_LAMP, side = -baySide(r) }
			)
		end
	end
	for _, run in runs do
		local road = roadById(run.id)
		if road then
			for i, s in StreetLayout.walk(road.points, run.spacing, run.start) do
				local quay = run.id == "HarbourRoad" and s.pos.X > QUAY.x0 and s.pos.X < QUAY.x1
				local parking = false -- Harbour Road's town-side bays: the lamp goes to the sea side
				for _, r in HARBOUR_BAYS do
					parking = parking
						or (run.id == "HarbourRoad" and s.s > r[1] - 16 and s.s < r[2] + 16)
				end
				local side = run.side
					or (if quay or parking then 1 else (if i % 2 == 0 then 1 else -1))
				for _, shift in { 0, 8, -8, 16, -16 } do
					local moved = StreetLayout.walk(road.points, 1, s.s + shift, s.s + shift)[1]
					if moved then
						local at = StreetLayout.offset(moved, side, road.width / 2 + LAMP.out)
						local toward = StreetLayout.offset(moved, -side, 1)
							- StreetLayout.offset(moved, side, 1)
						local yaw = StreetLayout.lampYaw(toward.Unit)
						local got = if paved(at)
							then place(
								parent,
								"M_Road_StreetLamp",
								at,
								yaw,
								Vector3.new(2, 12, 2),
								block,
								params
							)
							else nil
						if got then
							table.insert(out, { model = got.model, shadows = run.shadows })
							table.insert(block, { pos = got.pos, r = 3 })
							if run.side and i % 2 == 0 then -- town: a bin by every other lamp
								local bin = place(
									parent,
									"M_Road_Bin",
									at + moved.dir * 3.2,
									StreetLayout.faceYaw(-toward),
									Vector3.new(2, 3, 2),
									block,
									params
								)
								if bin then
									table.insert(block, { pos = bin.pos, r = 2 })
								end
							end
							if run.id == FORE then -- a hanging basket on a bracket, pavement side
								local away = -toward.Unit
								local hook = got.pos + away * 1.5 + Vector3.new(0, 8.8, 0)
								local arm = strip(
									got.model,
									"BasketArm",
									got.pos + Vector3.new(0, 8.6, 0),
									hook,
									0.16,
									0
								)
								arm.Size = Vector3.new(0.16, 0.16, arm.Size.Z)
								arm.Material = Enum.Material.Metal
								arm.Color = Color3.fromRGB(24, 26, 26)
								local b = StreetFurniture.build("HangingBasket")
								if b then
									b:PivotTo(CFrame.new(hook) * CFrame.Angles(0, i, 0))
									b.Parent = got.model
								end
							end
							break
						end
					end
				end
			end
		end
	end
	return out
end

local function quayFurniture(
	parent: Instance,
	block: { StreetLayout.Blocker },
	params: RaycastParams
)
	local benches, bins = 0, 0
	-- benches on the quay apron facing the harbour (the bench front is asset -Z: yaw 180 turns it to +Z, the sea)
	for _, x in { -34, 8, 48, 88, 128, 166 } do
		local at = Vector3.new(x, 4, QUAY.edge - 6)
		local b = place(parent, "M_Road_Bench", at, math.pi, Vector3.new(6, 3, 2.4), block, params)
		if b then
			benches += 1
			table.insert(block, { pos = b.pos, r = 4 })
			local bin = place(
				parent,
				"M_Road_Bin",
				at + Vector3.new(4.6, 0, 0),
				math.pi,
				Vector3.new(2, 3, 2),
				block,
				params
			)
			if bin then
				bins += 1
				table.insert(block, { pos = bin.pos, r = 2 })
			end
		end
	end
	-- bins by the Chandlery's gables, on the footway behind the kerb (shopfront x -74..-14, front z -42)
	for _, at in { Vector3.new(-11, 4, -41.4), Vector3.new(-77, 4, -41.4) } do
		local bin = place(parent, "M_Road_Bin", at, math.pi, Vector3.new(2, 3, 2), block, params)
		if bin then
			bins += 1
			table.insert(block, { pos = bin.pos, r = 2 })
		end
	end
	-- no bollards: the quay apron in front of Harbour Road is driven on and parked on (playtest: a pole in the road)
	return benches, bins
end

-- Parked cars (G73): static M_Road_ParkedCar_0N in the kerbs() bays (off the carriageway, parallel to it) and in
-- the Haven Sands car park, facing the flow of the lane beside them (right-hand traffic: forward along the road on
-- its right side, backward on its left); place() drops the ones by a prompt or lamp and keeps them off the station
-- apron and drivable lanes; front doors do not stop a car (Blocker.cars).
local CAR_IDS = { "M_Road_ParkedCar_01", "M_Road_ParkedCar_02", "M_Road_ParkedCar_03" }
local EMPTY_BAY = 0.3 -- share of bays left free

-- yaw of a car parked on `side` (+1 right of the road's point order) facing the traffic flow there
local function kerbYaw(dir: Vector3, side: number): number
	return StreetLayout.faceYaw(dir) + (if side < 0 then math.pi else 0)
end
local CAR_SIZE = Vector3.new(6, 6, 14)

local function parkedCars(
	parent: Instance,
	block: { StreetLayout.Blocker },
	params: RaycastParams,
	bays: { Bay }
): number
	local n = 0
	local carsOk: { StreetLayout.Blocker } = {}
	for _, b in block do
		if not b.cars then
			table.insert(carsOk, b)
		end
	end
	local function park(at: Vector3, yaw: number): boolean
		local asset = CAR_IDS[rng:NextInteger(1, #CAR_IDS)]
		local got = if paved(at)
			then place(parent, asset, at, yaw, CAR_SIZE, carsOk, params)
			else nil
		if not got then
			return false
		end
		n += 1
		got.model.Name = `ParkedCar_{n}`
		table.insert(carsOk, { pos = got.pos, r = 8 })
		table.insert(block, { pos = got.pos, r = 8 })
		return true
	end
	for i, bay in bays do
		if rng:NextNumber() >= EMPTY_BAY then
			park(bay.pos, kerbYaw(bay.dir, bay.side))
		end
		if i % 30 == 0 then
			task.wait()
		end
	end
	-- two rows of three nose-in bays in the Haven Sands car park, aligned with its yaw
	local cp = WorldConfig.CarParks[1]
	if cp then
		local rot = CFrame.Angles(0, math.rad(cp.yaw), 0)
		for row = -1, 1, 2 do
			for col = -1, 1 do
				local at = cp.center + rot:VectorToWorldSpace(Vector3.new(col * 8, 0, row * 12))
				park(at, math.rad(cp.yaw) + (if row > 0 then math.pi else 0))
			end
		end
	end
	return n
end

-- Fore Street (the shops): planters and benches on the wide pavement between the lamps, chalkboard A-boards at the
-- shopfronts on both sides, bunting strung across the central stretch.
local BUNTING = { x0 = -230, x1 = 210, step = 64, y = 17, sag = 2.6, flag = 1.7, drop = 2.1 }
local BUNTING_COLOURS = {
	Color3.fromRGB(196, 40, 44),
	Color3.fromRGB(240, 196, 52),
	Color3.fromRGB(36, 84, 168),
	Color3.fromRGB(238, 236, 228),
	Color3.fromRGB(44, 138, 84),
}

local function flagPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	colour: Color3,
	wedge: boolean
)
	local p: BasePart = if wedge then Instance.new("WedgePart") else Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Fabric
	p.Color = colour
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
end

-- one string of pennants from a to b (house front to house front), sagging in the middle
local function bunting(parent: Instance, a: Vector3, b: Vector3): number
	local m = Instance.new("Model")
	m.Name = "Bunting"
	local along = (b - a) * Vector3.new(1, 0, 1)
	local len = along.Magnitude
	local u = along.Unit
	local count = math.floor(len / (BUNTING.flag * 1.5))
	local function point(t: number): Vector3
		return a:Lerp(b, t) - Vector3.new(0, BUNTING.sag * 4 * t * (1 - t), 0)
	end
	local prev = point(0)
	for k = 1, count do
		local t = k / count
		local p = point(t)
		local rope = CFrame.lookAt((prev + p) / 2, p)
		flagPart(
			m,
			"Rope",
			Vector3.new(0.08, 0.08, (p - prev).Magnitude + 0.05),
			rope,
			Color3.fromRGB(230, 226, 214),
			false
		)
		prev = p
		-- a pennant hangs between this point and the last: two flipped wedges, tip down at the middle
		local c = point(t - 0.5 / count)
		local colour = BUNTING_COLOURS[(k % #BUNTING_COLOURS) + 1]
		for _, sgn in { -1, 1 } do
			local z = -u * sgn -- local +Z (the wedge's upright edge) toward the pennant's middle
			local y = -Vector3.yAxis
			local x = y:Cross(z)
			local half = BUNTING.flag / 2
			local pos = c + u * sgn * half / 2 - Vector3.new(0, BUNTING.drop / 2, 0)
			flagPart(
				m,
				"Pennant",
				Vector3.new(0.05, BUNTING.drop, half),
				CFrame.fromMatrix(pos, x, y, z),
				colour,
				true
			)
		end
	end
	m.Parent = parent
	return count
end

local function foreStreet(
	parent: Instance,
	block: { StreetLayout.Blocker },
	params: RaycastParams
): number
	local road = roadById(FORE)
	if not road then
		return 0
	end
	local e = road.width / 2
	local wide = -baySide(road)
	local n = 0
	local function put(
		asset: string,
		s: number,
		side: number,
		d: number,
		yaw: number,
		size: Vector3
	): boolean
		local c = StreetLayout.walk(road.points, 1, s, s)[1]
		if not c then
			return false
		end
		local got = place(parent, asset, StreetLayout.offset(c, side, d), yaw, size, block, params)
		if got then
			n += 1
			table.insert(block, { pos = got.pos, r = 2 })
		end
		return got ~= nil
	end
	for i, c in StreetLayout.walk(road.points, TOWN_LAMP, 30) do
		local toRoad = StreetLayout.offset(c, -wide, 1) - StreetLayout.offset(c, wide, 1) -- across, toward the road
		-- the wide pavement: a planter at the kerb, a bench against the shops every other bay, facing the road
		put(
			"Planter",
			c.s + 20,
			wide,
			e + 2.4,
			StreetLayout.faceYaw(toRoad),
			Vector3.new(5.4, 2.4, 2.4)
		)
		if i % 2 == 0 then
			put(
				"M_Road_Bench",
				c.s + 36,
				wide,
				FOOT - 2.2,
				StreetLayout.faceYaw(toRoad),
				Vector3.new(6, 3, 2.4)
			)
		end
		-- A-boards at the shop doors, both sides, facing along the pavement
		put(
			"ABoard",
			c.s + 10,
			wide,
			FOOT - 1.8,
			StreetLayout.faceYaw(c.dir),
			Vector3.new(1.8, 2.8, 1.2)
		)
		put(
			"ABoard",
			c.s + 42,
			-wide,
			FOOT - 0.8,
			StreetLayout.faceYaw(-c.dir),
			Vector3.new(1.8, 2.8, 1.2)
		)
	end
	local strings = 0
	for _, c in StreetLayout.walk(road.points, BUNTING.step, 0) do
		if c.pos.X > BUNTING.x0 and c.pos.X < BUNTING.x1 then
			local ga = ground(StreetLayout.offset(c, -1, FOOT - 0.4), params)
			local gb = ground(StreetLayout.offset(c, 1, FOOT - 0.4), params)
			if ga and gb then
				bunting(
					parent,
					ga + Vector3.new(0, BUNTING.y, 0),
					gb + Vector3.new(0, BUNTING.y, 0)
				)
				strings += 1
			end
		end
	end
	return n + strings
end

-- Road wear (P2 18) on the town grid, Harbour Road and Chapel Hill: gully gratings in the gutter, a manhole cover
-- now and then, and patched asphalt (darker or paler rectangles, under the paint). Never in a junction or a zebra.
local function roadWear(parent: Instance): number
	local params = terrainParams()
	local n = 0
	local function lay(
		name: string,
		c: Vector3,
		dir: Vector3,
		size: Vector3,
		top: number,
		colour: Color3,
		mat: Enum.Material
	)
		local g = ground(c, params)
		if not g or not RoadNet.clear(JUNCTIONS, g) or not StreetLayout.clear(g, {}, MARK_OUT) then
			return
		end
		local p = strip(
			parent,
			name,
			g - dir * size.Z / 2,
			g + dir * size.Z / 2,
			size.X,
			top - size.Y / 2
		)
		p.Size = size
		p.Material = mat
		p.Color = colour
		n += 1
	end
	for _, road in WorldConfig.Roads do
		if (road :: any).town or road.id == "HarbourRoad" or road.id == "TownLane" then
			local e = road.width / 2
			for i, c in StreetLayout.walk(road.points, 37, 18) do
				local side = if i % 2 == 0 then 1 else -1
				lay(
					"Gully",
					StreetLayout.offset(c, side, e - 1.1),
					c.dir,
					Vector3.new(1.3, 0.1, 2.2),
					0.06,
					Color3.fromRGB(34, 34, 34),
					Enum.Material.Metal
				)
				if i % 4 == 1 then
					lay(
						"Manhole",
						StreetLayout.offset(c, -side, rng:NextNumber(4, 9)),
						c.dir,
						Vector3.new(2.6, 0.1, 2.6),
						0.05,
						Color3.fromRGB(46, 46, 44),
						Enum.Material.Metal
					)
				end
				if i % 3 == 0 then
					local dark = rng:NextNumber() < 0.6
					lay(
						"Patch",
						StreetLayout.offset(
							c,
							rng:NextNumber() < 0.5 and 1 or -1,
							rng:NextNumber(3, 10)
						),
						c.dir,
						Vector3.new(rng:NextNumber(4, 9), 0.1, rng:NextNumber(5, 14)),
						0.02,
						if dark then Color3.fromRGB(22, 23, 25) else Color3.fromRGB(42, 43, 46),
						Enum.Material.Granite
					)
				end
			end
			task.wait()
		end
	end
	return n
end

-- Street name plates (black on white enamel) on two short posts at a corner of each junction, facing into it. The
-- face is a Gemini image per street (docs/19-world-sign-art.md, sign_street_<id>.png): a street still "" gets no
-- plate, so no blank white board ever stands in the town.
local NAME_PLATES: { [string]: string } = {
	HarbourRoad = "rbxassetid://88878447575996",
	PortHaven_Av1 = "rbxassetid://97228817889577",
	PortHaven_Av2 = "rbxassetid://100096148369959",
	PortHaven_Av3 = "rbxassetid://107822329358872",
	PortHaven_Av4 = "rbxassetid://115766599123311",
	PortHaven_Av5 = "rbxassetid://124619086186962",
	PortHaven_Av6 = "rbxassetid://106608538637645",
	PortHaven_Av7 = "rbxassetid://136087001159758",
	PortHaven_St1 = "rbxassetid://84736448216892",
	PortHaven_St2 = "rbxassetid://97268713759394",
	PortHaven_St3 = "rbxassetid://122850744429554",
	PortHaven_St4 = "rbxassetid://121843522280106",
}
local PLATE = { w = 4.4, h = 1.1, high = 3.2 }

local function namePlates(
	parent: Instance,
	block: { StreetLayout.Blocker },
	params: RaycastParams
): number
	local n = 0
	for _, j in JUNCTIONS do
		for _, arm in j.arms do
			local art = NAME_PLATES[arm.road]
			if art and art ~= "" then
				local _, across = RoadNet.incoming(arm)
				-- the corner left of the incoming lane (the signal stands on the right), behind the kerb
				local at = j.pos + arm.dir * (arm.stop + 6) - across * (arm.width / 2 + 5)
				local g = if StreetLayout.clear(at, block, KEEP_OUT)
					then ground(at, params, 8, 10)
					else nil
				if g then
					local m = Instance.new("Model")
					m.Name = `NamePlate_{arm.road}`
					local cf = CFrame.lookAt(g, g - arm.dir) -- front (-Z) toward the junction
					local iron = Color3.fromRGB(26, 28, 28)
					for _, x in { -PLATE.w / 2 + 0.3, PLATE.w / 2 - 0.3 } do
						signalPart(
							m,
							"Post",
							Vector3.new(0.22, PLATE.high, 0.22),
							cf * CFrame.new(x, PLATE.high / 2, 0),
							iron
						)
					end
					local plate = signalPart(
						m,
						"Plate",
						Vector3.new(PLATE.w, PLATE.h, 0.12),
						cf * CFrame.new(0, PLATE.high - PLATE.h / 2, 0),
						Color3.fromRGB(236, 234, 226)
					)
					for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
						local d = Instance.new("Decal")
						d.Face = face
						d.Texture = art
						d.Parent = plate
					end
					m.Parent = parent
					table.insert(block, { pos = g, r = 3 })
					n += 1
				end
			end
		end
	end
	return n
end

-- day / night: the SpotLights and the Lens (Neon at night, its SurfaceAppearance back by day)
local function rigLamps(list: { Lamp })
	local spots: { SpotLight } = {}
	local lenses: { { part: BasePart, look: Instance? } } = {}
	for _, l in list do
		local att = l.model:FindFirstChild("ATT_Light", true)
		local host = l.model.PrimaryPart or l.model:FindFirstChildWhichIsA("BasePart", true)
		if att and att:IsA("Attachment") and host then
			local a = Instance.new("Attachment")
			a.Name = "StreetLight"
			a.Parent = host
			a.WorldCFrame = CFrame.new(att.WorldPosition) -- world-aligned: Face Bottom shines straight down
			local s = Instance.new("SpotLight")
			s.Face = Enum.NormalId.Bottom
			s.Angle = LAMP.angle
			s.Range = LAMP.range
			s.Brightness = LAMP.brightness
			s.Color = LAMP_3000K
			s.Shadows = l.shadows
			s.Enabled = false
			s.Parent = a
			table.insert(spots, s)
		end
		for _, d in l.model:GetDescendants() do
			if d:IsA("BasePart") and string.find(d.Name, "_Lens", 1, true) then
				d.CastShadow = false
				local look: Instance? = d:FindFirstChildOfClass("SurfaceAppearance")
				table.insert(lenses, { part = d, look = look })
			end
		end
	end
	local lit: boolean? = nil
	local function refresh()
		local on = CottageLights.lightsOn(ChandleryRig.preset())
		if on == lit then
			return
		end
		lit = on
		for _, s in spots do
			s.Enabled = on
		end
		for _, l in lenses do
			if on then
				l.look = l.part:FindFirstChildOfClass("SurfaceAppearance") or l.look
				if l.look then
					(l.look :: Instance).Parent = nil
				end
				l.part.Material = Enum.Material.Neon
				l.part.Color = LENS_ON
			else
				if l.look and not l.part:FindFirstChildOfClass("SurfaceAppearance") then
					(l.look :: Instance).Parent = l.part
				end
				l.part.Material = Enum.Material.SmoothPlastic
			end
		end
	end
	refresh()
	Weather.changed:Connect(refresh)
	Lighting:GetAttributeChangedSignal("WeatherBase"):Connect(refresh)
	Lighting:GetPropertyChangedSignal("ClockTime"):Connect(refresh)
	Lighting:GetPropertyChangedSignal("GeographicLatitude"):Connect(refresh)
end

function Street.start()
	local t0 = os.clock()
	local dressing = Workspace:FindFirstChild("Dressing") or Workspace
	local m = Instance.new("Model")
	m.Name = "Street"
	m.ModelStreamingMode = Enum.ModelStreamingMode.Nonatomic
	m.Parent = dressing
	street = m
	local function sub(name: string): Model
		local f = Instance.new("Model")
		f.Name = name
		f.ModelStreamingMode = Enum.ModelStreamingMode.Nonatomic
		f.Parent = m
		return f
	end
	local function step(name: string, fn: () -> ...any): ...any
		local res = table.pack(pcall(fn))
		if not res[1] then
			warn(`[Street] {name} failed: {res[2]}`)
			return 0, 0, 0
		end
		return table.unpack(res, 2, res.n)
	end
	for _, a in
		{
			"M_Road_StreetLamp",
			"M_Road_ParkedCar_01",
			"M_Road_ParkedCar_02",
			"M_Road_ParkedCar_03",
		}
	do
		task.spawn(AssetLoader.getTemplate, a, "LOD0")
	end
	local cells = step("track", repaintTrack)
	local marks = step("markings", function()
		return markings(sub("Markings"))
	end)
	local heads, nJunctions = step("junctions", function()
		return junctions(sub("Junctions"))
	end)
	local block = blockers()
	local bays: { Bay } = {}
	local nKerbs = step("kerbs", function()
		local k, b = kerbs(sub("Kerbs"), block)
		bays = b
		return k
	end)
	for _, b in bays do -- no lamp or bin in a bay (a car may: cars)
		table.insert(block, { pos = b.pos, r = 9, cars = true })
	end
	local wear = step("wear", function()
		return roadWear(sub("Wear"))
	end)
	local params = solidParams()
	local furniture = sub("Furniture")
	local lampList: { Lamp } = {}
	step("lamps", function()
		lampList = lamps(furniture, block, params)
		rigLamps(lampList)
	end)
	local benches, bins = step("quay", function()
		return quayFurniture(furniture, block, params)
	end)
	local nCars = step("parked cars", function()
		return parkedCars(furniture, block, params, bays)
	end)
	local plates = step("name plates", function()
		return namePlates(furniture, block, params)
	end)
	m:SetAttribute("StreetNamePlates", plates)
	local fore = step("fore street", function()
		return foreStreet(furniture, block, params)
	end)
	m:SetAttribute("StreetLamps", #lampList)
	m:SetAttribute("StreetBenches", benches)
	m:SetAttribute("StreetBins", bins)
	m:SetAttribute("StreetParkedCars", nCars)
	m:SetAttribute("StreetKerbs", nKerbs)
	m:SetAttribute("StreetMarkings", marks)
	m:SetAttribute("StreetJunctions", nJunctions)
	m:SetAttribute("StreetSignals", if type(heads) == "table" then #heads else 0)
	m:SetAttribute("StreetTrackCells", cells)
	m:SetAttribute("StreetBays", #bays)
	m:SetAttribute("StreetWear", wear)
	m:SetAttribute("StreetForeStreet", fore)
	m:SetAttribute("StreetReady", true)
	print(
		`[Street] {#lampList} lamps, {benches} benches, {bins} bins, {nCars} parked cars in {#bays} bays, {nKerbs} kerbs, {fore} Fore Street props, {wear} wear, {marks} markings, track {cells} cells in {math.floor(
			(os.clock() - t0) * 10
		) / 10} s`
	)
end

return Street
