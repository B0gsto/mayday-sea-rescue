--!strict
-- Street (I1b-3): Port Haven's streets and the Harbour Light, placed at run time after the building swaps
-- (WorldDressingService hooks Street.swaps into its swap list and spawns Street.start()).
--
--   * Road surfaces (R1a + POL1-B, art/source/roads/INTEGRATION.md): the roads are terrain, so the surfaces come
--     through the terrain slots in MaterialService (art/source/roads/wire_roads.py): Asphalt -> RoadAsphaltWorn,
--     Cobblestone (the quayside setts the bake paints on Harbour Road, x -180..180) -> RoadHarbourCobbles, Pavement ->
--     RoadGravelTrack. The bake paints the Haven Head farm track Ground; start() repaints it Pavement (gravel).
--   * UK markings on the asphalt (white paint strips 5 mm proud, following the ray-cast terrain): centre dashes on
--     the Coast Road, the High Road and Harbour Road's asphalt ends, edge lines on the Coast Road and High Road.
--   * Granite kerbs (Granite + MaterialVariant RoadKerbGranite, 125 mm upstand) along the town edge of Harbour Road
--     and both sides of Chapel Hill, dropped at the station apron / slipway, junctions, doors and prompts.
--   * R1a street furniture (AssetLoader.cloneStatic): M_Road_StreetLamp every ~28 m on Harbour Road (the quay side in
--     town, alternate sides beyond) and Chapel Hill, warm SpotLights at ATT_Light (shadows on Harbour Road) with the
--     Lens Neon at night / in a storm; benches on the quay facing the harbour with bins beside them and by the
--     Chandlery; bollards along the quay edge of Harbour Road. Every spot skips the carriageways, doors, prompt
--     markers, the slipway and the station apron, and anything solid already there.
--   * The Harbour Light (H6 M_Bld_HarbourLight) replaces Map.HarbourLight and the lifeguard tower (H6
--     M_Bld_LifeguardTower) the Haven Sands greybox through Street.swaps; Street.apply is their rig: _Glass Glass,
--     the Light's _Lens plain for the client beam, the tower's red-over-yellow flag at ATT_Flag (waved by the client,
--     src/client/Controllers/StreetController.luau, which also turns the Harbour Light's Fl(2) W 10s beam).
-- Placement rules in StreetLayout (pure). Workspace.Dressing.Street attributes when done: StreetReady, StreetLamps,
-- StreetBenches, StreetBins, StreetBollards, StreetKerbs, StreetMarkings, StreetTrackCells.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AssetLoader = require(script.Parent.Parent:WaitForChild("Assets"):WaitForChild("AssetLoader"))
local ChandleryRig = require(script.Parent:WaitForChild("ChandleryRig"))
local CottageLights = require(script.Parent:WaitForChild("CottageLights"))
local StreetLayout = require(script.Parent:WaitForChild("StreetLayout"))
local Swaps = require(script.Parent:WaitForChild("Swaps"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Discovery = require(Shared:WaitForChild("Explore"):WaitForChild("Discovery"))
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
local KERB_TINT = Color3.fromRGB(236, 236, 232)
local MARK, GAP = 12, 15 -- centre dash 4 m mark, 5 m gap (TSM diagram 1004, <= 40 mph: verify)
local LINE_W = 0.3 -- 100 mm
local KERB = { seg = 5.4, w = 0.9, h = 0.75, up = 0.375 } -- two 0.9 m stones, 125 mm upstand
local QUAY = { x0 = -180, x1 = 180, z = -20, edge = 4 } -- the quay apron in front of Harbour Road (Build.luau)
local SETTS = { -180, -62, 180, -20 } -- the bake's quayside Cobblestone rect (tools/world/gen_terrain.py)
local KEEP_OUT: { StreetLayout.Rect } = {
	{ -185, -46, -72, 8 }, -- the station apron, the boat's road crossing and the slipway head
}

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
	local plaque = shell:FindFirstChild("ATT_Plaque", true)
	local entry = Discovery.get("HarbourLightHistory")
	if plaque and plaque:IsA("Attachment") and entry then
		local off = (plaque.WorldPosition - entry.position).Magnitude
		shell:SetAttribute("PlaqueOffset", math.floor(off * 10) / 10)
		if off > 3 then
			warn(
				`[Street] Harbour Light plaque at {plaque.WorldPosition} is {off} studs from the logbook POI {entry.position}`
			)
		end
	end
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
	local function add(pos: Vector3, r: number)
		table.insert(out, { pos = pos, r = r })
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
				add(d.WorldPosition, 7)
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
	params: RaycastParams
): number
	local n = 0
	for _, seg in segs do
		local a = ground(seg.a, params)
		local b = ground(seg.b, params)
		if a and b and math.abs(a.Y - b.Y) < 4 then
			local p = strip(parent, name, a, b, LINE_W, 0.03) -- top 5 mm (0.016) + clearance over the chord
			p.Material = Enum.Material.SmoothPlastic
			p.Color = PAINT
			n += 1
		end
	end
	return n
end

local function onAsphalt(seg: StreetLayout.Seg): boolean
	return not (StreetLayout.inRect(seg.a, SETTS) or StreetLayout.inRect(seg.b, SETTS))
end

local function markings(parent: Instance): number
	local params = terrainParams()
	local n = 0
	for _, id in { "CoastRoadEast", "HighRoad", "HarbourRoad" } do
		local road = roadById(id)
		if road then
			local dashes = {}
			for _, seg in StreetLayout.dashes(road.points, MARK, GAP) do
				if onAsphalt(seg) then
					table.insert(dashes, seg)
				end
			end
			n += paint(parent, dashes, "CentreDash", params)
			if id ~= "HarbourRoad" then
				local d = road.width / 2 - 0.75 -- line centre 0.25 m in from the edge
				for _, side in { -1, 1 } do
					n += paint(
						parent,
						StreetLayout.chain(road.points, 16, side, d),
						"EdgeLine",
						params
					)
				end
			end
			task.wait()
		end
	end
	return n
end

local function kerbs(parent: Instance, block: { StreetLayout.Blocker }): number
	local params = terrainParams()
	local lane = roadById("TownLane")
	local harbour = roadById("HarbourRoad")
	local runs: { { road: any, side: number, from: number, to: number } } = {}
	if harbour then
		table.insert(runs, { road = harbour, side = -1, from = 380, to = 740 }) -- x -180..180, the town (north) edge
	end
	if lane then
		for _, side in { -1, 1 } do
			table.insert(runs, { road = lane, side = side, from = 10, to = 240 }) -- up Chapel Hill to the last cottages
		end
	end
	local n = 0
	for _, run in runs do
		local d = run.road.width / 2 + KERB.w / 2
		local samples = StreetLayout.walk(run.road.points, KERB.seg, run.from, run.to)
		for i = 1, #samples - 1 do
			local a0 = StreetLayout.offset(samples[i], run.side, d)
			local b0 = StreetLayout.offset(samples[i + 1], run.side, d)
			local mid0 = (a0 + b0) / 2
			local junction = false
			for _, other in WorldConfig.Roads do
				if
					other ~= run.road
					and StreetLayout.distToPolyline(mid0, other.points) < other.width / 2 + 4
				then
					junction = true
				end
			end
			if
				not junction
				and StreetLayout.clear(mid0, block, KEEP_OUT)
				and harbour
				and StreetLayout.distToPolyline(mid0, harbour.points) >= harbour.width / 2
			then
				local a, b = ground(a0, params), ground(b0, params)
				if a and b and math.abs(a.Y - b.Y) < 3 then
					local p = strip(parent, "Kerb", a, b, KERB.w, KERB.up - KERB.h / 2)
					p.Size = Vector3.new(KERB.w, KERB.h, p.Size.Z)
					p.Material = Enum.Material.Granite
					p.MaterialVariant = "RoadKerbGranite"
					p.Color = KERB_TINT
					p.CastShadow = true
					n += 1
				end
			end
		end
	end
	return n
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
	local m = AssetLoader.cloneStatic(asset, "LOD0", true)
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
	local runs = {
		{ id = "HarbourRoad", start = 30, shadows = true },
		{ id = "TownLane", start = 40, shadows = false },
	}
	for _, run in runs do
		local road = roadById(run.id)
		if road then
			for i, s in StreetLayout.walk(road.points, LAMP.spacing, run.start) do
				local quay = run.id == "HarbourRoad" and s.pos.X > QUAY.x0 and s.pos.X < QUAY.x1
				local side = if quay then 1 else (if i % 2 == 0 then 1 else -1)
				for _, shift in { 0, 8, -8, 16, -16 } do
					local moved = StreetLayout.walk(road.points, 1, s.s + shift, s.s + shift)[1]
					if moved then
						local at = StreetLayout.offset(moved, side, road.width / 2 + LAMP.out)
						local toward = StreetLayout.offset(moved, -side, 1)
							- StreetLayout.offset(moved, side, 1)
						local yaw = StreetLayout.lampYaw(toward.Unit)
						local got = place(
							parent,
							"M_Road_StreetLamp",
							at,
							yaw,
							Vector3.new(2, 12, 2),
							block,
							params
						)
						if got then
							table.insert(out, { model = got.model, shadows = run.shadows })
							table.insert(block, { pos = got.pos, r = 3 })
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
	local benches, bins, bollards = 0, 0, 0
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
	-- bollards along the quay edge of Harbour Road (east of the station apron), 4 m centres
	for x = -68, QUAY.x1 - 2, 12 do
		local at = Vector3.new(x, 4, QUAY.z + 0.8)
		if place(parent, "M_Road_Bollard", at, 0, Vector3.new(1, 2.4, 1), block, params) then
			bollards += 1
		end
	end
	return benches, bins, bollards
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
	for _, a in { "M_Road_StreetLamp", "M_Road_Bench", "M_Road_Bin", "M_Road_Bollard" } do
		task.spawn(AssetLoader.getTemplate, a, "LOD0")
	end
	local cells = step("track", repaintTrack)
	local marks = step("markings", function()
		return markings(sub("Markings"))
	end)
	local block = blockers()
	local nKerbs = step("kerbs", function()
		return kerbs(sub("Kerbs"), block)
	end)
	local params = solidParams()
	local furniture = sub("Furniture")
	local lampList: { Lamp } = {}
	step("lamps", function()
		lampList = lamps(furniture, block, params)
		rigLamps(lampList)
	end)
	local benches, bins, bollards = step("quay", function()
		return quayFurniture(furniture, block, params)
	end)
	m:SetAttribute("StreetLamps", #lampList)
	m:SetAttribute("StreetBenches", benches)
	m:SetAttribute("StreetBins", bins)
	m:SetAttribute("StreetBollards", bollards)
	m:SetAttribute("StreetKerbs", nKerbs)
	m:SetAttribute("StreetMarkings", marks)
	m:SetAttribute("StreetTrackCells", cells)
	m:SetAttribute("StreetReady", true)
	print(
		`[Street] {#lampList} lamps, {benches} benches, {bins} bins, {bollards} bollards, {nKerbs} kerbs, {marks} markings, track {cells} cells in {math.floor(
			(os.clock() - t0) * 10
		) / 10} s`
	)
end

return Street
