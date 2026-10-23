--!strict
-- TownExtras (I2a): free placements at server start, after the building swaps (WorldDressingService calls
-- TownExtras.place(Workspace.Dressing)):
--   * the moored boats (M_Veh_MooredBoat_01) at the visitors' moorings of Shared.SeamarkRules (one per mooring,
--     bow to the buoy, WS sea level): Workspace.Dressing.TownExtras.Mooring<N>Boat;
--   * five M_Veh_MooredBoat_02 crabbers, two M_Veh_MooredBoat_03 trawlers and four M_Veh_MooredBoat_01 punts swinging
--     at anchor in the harbour pool (TownExtrasLayout.harbourBoats), one crabber alongside the quay at z 12.5; still
--     at sea level;
--   * herring gulls (M_Ani_HerringGull, static) perched on every third quay bollard once Harbour has placed them;
--   * washing lines (code-built: posts, line, clothes pegged out) in the yards up Chapel Hill (TownLane);
--   * the boatyard: Port Haven's west block (Quay Lane / Station Hill / Fore Street, WorldConfig.Towns keep rect)
--     repainted as Concrete hardstanding; the shed (M_Bld_BoatyardShed, roller door west) on its north half and
--     the travel hoist (M_Hbr_TravelHoist) straddling a hoist dock (two concrete piers off the yard quay wall) with a
--     crabber (M_Veh_MooredBoat_02) hanging in its slings over the water, a concrete slipway (Part `Slipway`) east of it. The asset's 80 x 50 m yard slab and markings are dropped (the block is the yard).
--     The BoatDesk kiosk and its prompt are untouched.
-- Every item is pcall'd: a missing asset is skipped and the terrain stays.
-- Workspace.Dressing.TownExtras attributes when done: TownExtrasBoats, TownExtrasShed, TownExtrasHoist,
-- TownExtrasWashing; TownExtrasGulls once the bollards are in.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AssetLoader = require(script.Parent.Parent:WaitForChild("Assets"):WaitForChild("AssetLoader"))
local Layout = require(script.Parent:WaitForChild("TownExtrasLayout"))
local SharedSetsRig = require(script.Parent:WaitForChild("SharedSetsRig"))
local StreetLayout = require(script.Parent:WaitForChild("StreetLayout"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local SeamarkRules = require(Shared:WaitForChild("SeamarkRules"))
local WorldConfig = require(Shared:WaitForChild("Config"):WaitForChild("WorldConfig"))

local TownExtras = {}

local BOAT = "M_Veh_MooredBoat_01"
local CRABBER = "M_Veh_MooredBoat_02"
local TRAWLER = "M_Veh_MooredBoat_03"
local SHED = "M_Bld_BoatyardShed"
local HOIST = "M_Hbr_TravelHoist"

-- boatyard (studs, yaw as authored): the shed's open yard and roller door face west toward the hoist
local SHED_AT = CFrame.new(-300, 4, -115) -- shell box x -330..-240, z -138..-92
-- the hoist dock (Harbour.YARD_QUAY frontage, face z 4): two concrete piers run out from the quay wall and the
-- hoist straddles the bay between them (legs at local x +-11, z +-15), the crabber slung over the water; the
-- slipway goes down through the quay's slipway gap (Harbour.YARD_QUAY slots 8-9, x -254..-236) into the harbour
local HOIST_AT = CFrame.new(-281, 4, 22)
local SLUNG_Y = 9 -- the slung boat's waterline above the hoist pivot: hull hanging in the straps, keel well clear
local PIERS = { x = { -292, -270 }, width = 6, z0 = 4, z1 = 46, foot = -16 }
local APRON = { x0 = -317, x1 = -236, z0 = -14, z1 = -5 } -- behind the quay kit footprint (z -5..4), top Y 4
local SLIP =
	{ x = -245, width = 16, from = Vector3.new(0, 4, -14), to = Vector3.new(0, -10, 64), thick = 3 }
local YARD = { -361, -141, -239, -47 } -- x0, z0, x1, z1: the block inside its pavements
-- the 240 x 150 stud slab and its paint do not fit: use the terrain. The _COL hull goes too: it is one mesh with
-- that slab in it, so its convex pieces rise into the station hall next door (players floated there).
local YARD_DROP = { "_Ground_", "_Markings_", "_COL" }
-- the shed shell instead (build.py: x -20.1..10.1, y -7.6..7.6 m, up to the ridge 9.95 m), in the asset frame
local SHED_BOX = { cf = CFrame.new(15, 14.925, 0), size = Vector3.new(90.6, 29.85, 45.6) }

local terrainParams = RaycastParams.new()
terrainParams.FilterType = Enum.RaycastFilterType.Include
terrainParams.FilterDescendantsInstances = { Workspace.Terrain }

-- the highest terrain under the footprint (the town platform meshes above LandTopY): never lower the authored Y
local function grounded(cf: CFrame, reach: number): CFrame
	local top = cf.Position.Y
	for i = -1, 1 do
		for j = -1, 1 do
			local at = (cf * CFrame.new(i * reach, 0, j * reach)).Position
			local hit =
				Workspace:Raycast(at + Vector3.new(0, 40, 0), Vector3.new(0, -80, 0), terrainParams)
			if hit then
				top = math.max(top, hit.Position.Y)
			end
		end
	end
	return CFrame.new(cf.Position.X, top, cf.Position.Z) * cf.Rotation
end

local function atomic(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = parent
	return m
end

local function place(
	asset: string,
	cf: CFrame,
	name: string,
	parent: Instance,
	drop: { string }?
): boolean
	local ok, model = pcall(AssetLoader.cloneStatic, asset, "LOD0", true)
	if not ok or not model then
		warn(`[TownExtras] {name}: {asset} did not load`)
		return false
	end
	local tokens: { string } = drop or {}
	for _, tok in tokens do
		for _, child in model:GetDescendants() do
			if string.find(child.Name, tok, 1, true) then
				child:Destroy()
			end
		end
	end
	SharedSetsRig.apply(model)
	model:PivotTo(cf)
	model.Parent = atomic(name, parent)
	return true
end

local function placeBoats(parent: Instance): number
	local sea = Workspace:GetAttribute("SeaLevel")
	local seaY = if type(sea) == "number" then sea else WorldConfig.SeaLevel
	local moorings: { Layout.Mooring } = {}
	for _, m in SeamarkRules.Marks do
		if string.match(m.id, "^Mooring%d+$") then
			table.insert(moorings, { id = m.id, x = m.x, z = m.z })
		end
	end
	task.spawn(AssetLoader.getTemplate, BOAT, "LOD0")
	task.spawn(AssetLoader.getTemplate, CRABBER, "LOD0")
	task.spawn(AssetLoader.getTemplate, TRAWLER, "LOD0")
	local n = 0
	for _, boat in Layout.mooredBoats(moorings, seaY) do
		if place(BOAT, boat.cf, `{boat.id}Boat`, parent) then
			n += 1
		end
	end
	for _, boat in Layout.harbourBoats(seaY) do
		if place(boat.asset, boat.cf, `{boat.id}Boat`, parent) then
			n += 1
		end
	end
	return n
end

local GULL = "M_Ani_HerringGull"

-- a static herring gull on every third quay bollard (M_Hbr_Bollard_01/02 from Harbour; the pier-head cannon
-- bollards are the client's live perches, WildlifeController)
local function gulls(base: Instance, parent: Instance): number
	local found: { Model } = {}
	local last = -1
	for _ = 1, 30 do
		found = {}
		for _, d in base:GetDescendants() do
			local a = d:IsA("Model") and d:GetAttribute("Asset")
			if type(a) == "string" and string.match(a, "^M_Hbr_Bollard_0[12]$") then
				table.insert(found, d :: Model)
			end
		end
		if #found > 0 and #found == last then -- Harbour has finished placing them
			break
		end
		last = #found
		task.wait(2)
	end
	table.sort(found, function(a, b)
		return a:GetPivot().X < b:GetPivot().X
	end)
	local n = 0
	for i, b in found do
		if i % 3 == 1 then
			local gull = AssetLoader.cloneStatic(GULL, "LOD0", false)
			if gull then
				local bcf, bsize = b:GetBoundingBox()
				local gcf, gsize = gull:GetBoundingBox()
				local lift = gull:GetPivot().Y - (gcf.Y - gsize.Y / 2) -- the pivot above the feet
				local top = bcf.Y + bsize.Y / 2
				gull:PivotTo(CFrame.new(bcf.X, top + lift, bcf.Z) * CFrame.Angles(0, i * 1.7, 0))
				for _, d in gull:GetDescendants() do
					if d:IsA("BasePart") then
						d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
					end
				end
				gull.Parent = atomic(`Gull{n + 1}`, parent)
				n += 1
			end
		end
	end
	return n
end

-- washing lines up Chapel Hill: in the yards beside TownLane, parallel to the road, alternate sides
local WASHING = { from = 40, to = 320, step = 46, off = 27, span = 12, high = 6.5 }
local CLOTHES = {
	{ size = Vector3.new(1.6, 1.9, 0.08), colour = Color3.fromRGB(236, 236, 228) }, -- shirt
	{ size = Vector3.new(2.4, 1.5, 0.08), colour = Color3.fromRGB(70, 120, 180) }, -- towel
	{ size = Vector3.new(1.2, 2.3, 0.08), colour = Color3.fromRGB(52, 66, 96) }, -- jeans
	{ size = Vector3.new(2.6, 1.7, 0.08), colour = Color3.fromRGB(214, 92, 84) }, -- towel
	{ size = Vector3.new(1.5, 1.7, 0.08), colour = Color3.fromRGB(240, 210, 90) }, -- shirt
	{ size = Vector3.new(0.5, 0.9, 0.08), colour = Color3.fromRGB(230, 230, 230) }, -- socks
}

local function washing(parent: Instance): number
	local lane: any = nil
	for _, r in WorldConfig.Roads do
		if r.id == "TownLane" then
			lane = r
		end
	end
	if not lane then
		return 0
	end
	local function piece(
		m: Model,
		name: string,
		size: Vector3,
		cf: CFrame,
		colour: Color3,
		mat: Enum.Material
	)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = name == "Post"
		p.CanTouch = false
		p.Size = size
		p.CFrame = cf
		p.Color = colour
		p.Material = mat
		p.Parent = m
	end
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = { Workspace.Terrain }
	local n = 0
	for i, c in StreetLayout.walk(lane.points, WASHING.step, WASHING.from, WASHING.to) do
		local side = if i % 2 == 0 then 1 else -1
		local at = StreetLayout.offset(c, side, WASHING.off)
		local hit =
			Workspace:Raycast(at + Vector3.new(0, 40, 0), Vector3.new(0, -80, 0), terrainParams)
		local basis = CFrame.lookAt(Vector3.zero, c.dir)
		if hit and hit.Material ~= Enum.Material.Asphalt then
			local cf = CFrame.new(hit.Position) * basis -- local Z along the road
			local clear = #Workspace:GetPartBoundsInBox(
				cf * CFrame.new(0, 4, 0),
				Vector3.new(4, 7, WASHING.span + 4),
				op
			) == 0
			if clear then
				local m = Instance.new("Model")
				m.Name = `WashingLine{n + 1}`
				local wood = Color3.fromRGB(110, 92, 70)
				for _, z in { -WASHING.span / 2, WASHING.span / 2 } do
					piece(
						m,
						"Post",
						Vector3.new(0.3, 7, 0.3),
						cf * CFrame.new(0, 3.3, z),
						wood,
						Enum.Material.Wood
					)
				end
				piece(
					m,
					"Line",
					Vector3.new(0.05, 0.05, WASHING.span),
					cf * CFrame.new(0, WASHING.high, 0),
					Color3.fromRGB(220, 220, 214),
					Enum.Material.SmoothPlastic
				)
				local z = -WASHING.span / 2 + 1
				for k = 1, 5 do
					local cl = CLOTHES[(i + k) % #CLOTHES + 1]
					local size = cl.size
					if z + size.X > WASHING.span / 2 - 0.5 then
						break
					end
					piece(
						m,
						`Cloth{k}`,
						size,
						cf
							* CFrame.new(0, WASHING.high - size.Y / 2 - 0.05, z + size.X / 2)
							* CFrame.Angles(0, math.pi / 2, (k % 2 - 0.5) * 0.06),
						cl.colour,
						Enum.Material.Fabric
					)
					z += size.X + 0.4
				end
				m.Parent = atomic(m.Name, parent)
				n += 1
			end
		end
	end
	return n
end

function TownExtras.place(base: Instance)
	local folder = Instance.new("Model")
	folder.Name = "TownExtras"
	folder.ModelStreamingMode = Enum.ModelStreamingMode.Nonatomic
	folder.Parent = base
	local yard = Region3.new(Vector3.new(YARD[1], -4, YARD[2]), Vector3.new(YARD[3], 8, YARD[4]))
		:ExpandToGrid(4)
	for _, soft in
		{
			Enum.Material.Grass,
			Enum.Material.Snow,
			Enum.Material.WoodPlanks,
			Enum.Material.LeafyGrass,
		}
	do
		Workspace.Terrain:ReplaceMaterial(yard, 4, soft, Enum.Material.Concrete)
	end
	task.spawn(AssetLoader.getTemplate, SHED, "LOD0")
	task.spawn(AssetLoader.getTemplate, HOIST, "LOD0")
	task.spawn(AssetLoader.getTemplate, GULL, "LOD0")
	local okB, boats = pcall(placeBoats, folder)
	local shedAt = grounded(SHED_AT, 30)
	local okS, shed = pcall(place, SHED, shedAt, "BoatyardShed", folder, YARD_DROP)
	local shedModel = folder:FindFirstChild("BoatyardShed")
	if okS and shed == true and shedModel then
		local box = Instance.new("Part")
		box.Name = "ShedCollision"
		box.Anchored = true
		box.CanTouch = false
		box.CastShadow = false
		box.Transparency = 1
		box.Size = SHED_BOX.size
		box.CFrame = shedAt * SHED_BOX.cf
		box:AddTag(AssetLoader.COLLISION_TAG)
		box.Parent = shedModel
	end
	-- the yard apron, the hoist piers and the slipway: concrete Parts (smooth terrain cannot hold a crisp Y 4 edge)
	local concrete = Color3.fromRGB(150, 146, 138)
	local function slab(name: string, size: Vector3, cf: CFrame, colour: Color3?)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanTouch = false
		-- Plaster, not Concrete: MaterialService remaps Concrete to the dark pavement variant (piers read near black)
		p.Material = Enum.Material.Plaster
		p.Color = colour or concrete
		p.Size = size
		p.CFrame = cf
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = folder
		return p
	end
	local ax, az = (APRON.x0 + APRON.x1) / 2, (APRON.z0 + APRON.z1) / 2
	Workspace.Terrain:FillBlock(
		CFrame.new(ax, 10, (APRON.z0 + 4) / 2),
		Vector3.new(APRON.x1 - APRON.x0, 12, 4 - APRON.z0),
		Enum.Material.Air
	)
	slab(
		"Apron",
		Vector3.new(APRON.x1 - APRON.x0, 3, APRON.z1 - APRON.z0),
		CFrame.new(ax, 2.55, az)
	)
	local pl = PIERS.z1 - PIERS.z0
	for k, px in PIERS.x do
		local pz = (PIERS.z0 + PIERS.z1) / 2
		local h = 4 - PIERS.foot
		slab(
			`HoistPier{k}`,
			Vector3.new(PIERS.width, h, pl),
			CFrame.new(px, PIERS.foot + h / 2, pz)
		)
		-- wet stain at the tide line and a yellow safety edge along the bay side
		slab(
			`HoistPier{k}Wet`,
			Vector3.new(PIERS.width + 0.1, 2.4, pl + 0.1),
			CFrame.new(px, 0, pz),
			Color3.fromRGB(92, 96, 90)
		)
		local edge = px + (if px < HOIST_AT.X then 1 else -1) * (PIERS.width / 2 - 0.2)
		slab(
			`HoistPier{k}Edge`,
			Vector3.new(0.4, 0.06, pl),
			CFrame.new(edge, 4.03, pz),
			Color3.fromRGB(232, 184, 36)
		)
		-- rubber fenders on the bay face
		for fz = PIERS.z0 + 6, PIERS.z1 - 2, 8 do
			local fx = px + (if px < HOIST_AT.X then 1 else -1) * (PIERS.width / 2 + 0.3)
			slab(
				`HoistPier{k}Fender`,
				Vector3.new(0.6, 3, 1.2),
				CFrame.new(fx, 1.8, fz),
				Color3.fromRGB(28, 28, 30)
			)
		end
	end
	local a = Vector3.new(SLIP.x, SLIP.from.Y, SLIP.from.Z)
	local b = SLIP.to + Vector3.new(SLIP.x, 0, 0)
	local rampCF = CFrame.lookAt((a + b) / 2, b)
	local len = (b - a).Magnitude
	Workspace.Terrain:FillBlock(
		rampCF * CFrame.new(0, 5, 0),
		Vector3.new(SLIP.width + 2, 10, len),
		Enum.Material.Air
	)
	slab(
		"Slipway",
		Vector3.new(SLIP.width, SLIP.thick, len + 2),
		rampCF * CFrame.new(0, -SLIP.thick / 2, 0)
	)
	for _, sx in { -1, 1 } do -- side walls from the slip edge down to the seabed, a kerb proud of the surface
		slab(
			"SlipwayWall",
			Vector3.new(1, 12, len + 2),
			rampCF * CFrame.new(sx * (SLIP.width / 2 + 0.5), -5.6, 0),
			Color3.fromRGB(128, 125, 120)
		)
	end
	local hoistAt = HOIST_AT
	local okH, hoist = pcall(place, HOIST, hoistAt, "TravelHoist", folder)
	if okH and hoist == true then
		pcall(place, CRABBER, hoistAt + Vector3.new(0, SLUNG_Y, 0), "SlungBoat", folder)
	end
	folder:SetAttribute("TownExtrasBoats", if okB then boats else 0)
	folder:SetAttribute("TownExtrasShed", okS and shed == true)
	folder:SetAttribute("TownExtrasHoist", okH and hoist == true)
	local okW, lines = pcall(washing, folder)
	folder:SetAttribute("TownExtrasWashing", if okW then lines else 0)
	if not okW then
		warn(`[TownExtras] washing lines failed: {lines}`)
	end
	task.spawn(function()
		local okG, n = pcall(gulls, base, folder)
		folder:SetAttribute("TownExtrasGulls", if okG then n else 0)
		if not okG then
			warn(`[TownExtras] gulls failed: {n}`)
		end
	end)
	if not (okB and okS and okH) then
		warn(`[TownExtras] failed: boats {boats}, shed {shed}, hoist {hoist}`)
	end
	print(
		`[TownExtras] {if okB then boats else 0} moored boats, shed {okS and shed == true}, hoist {okH and hoist == true}`
	)
end

return TownExtras
