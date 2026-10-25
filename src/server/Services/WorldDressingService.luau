--!strict
-- WorldDressingService (I1, docs/12 section 3.2): places the production Packages in the world at run time
-- (Build.luau runs under Lune and cannot load assets):
--   * building swaps from src/server/World/Swaps.luau: greybox -> Packages at the shared pivot, the shell and
--     the interior as separate Atomic models in Workspace.Dressing,
--     an auto door, the building's light rig; the greybox stays when any asset fails to load;
--   * the K1 rocks and G1 plants from map/generated/props.json (tools/world/scatter_props.py, synced by Rojo as
--     ReplicatedStorage.WorldPlacements): the server publishes LOD0/1/2 templates (ReplicatedStorage.ScatterTemplates)
--     and places only the rocks' collision hulls (CELL x CELL Atomic models); ScatterController draws the meshes.
-- Workspace.Dressing attributes when done: DressingReady, DressingRocks, DressingPlants, DressingParts.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AssetLoader = require(script.Parent.Parent:WaitForChild("Assets"):WaitForChild("AssetLoader"))
local Swaps = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("Swaps"))

local WorldDressingService = {}
WorldDressingService.Priority = 60

local CELL = 256 -- studs per streaming cell of scattered props
local YIELD_EVERY = 150

local dressing: Model? = nil

local function root(): Model
	if dressing and dressing.Parent then
		return dressing
	end
	local m = Instance.new("Model")
	m.Name = "Dressing"
	m.ModelStreamingMode = Enum.ModelStreamingMode.Nonatomic
	m.Parent = Workspace
	dressing = m
	return m
end

local function atomic(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = parent
	return m
end

local function findAttachment(model: Model, name: string): Attachment?
	local a = model:FindFirstChild(name, true)
	return if a and a:IsA("Attachment") then a else nil
end

local function findPath(base: Instance, path: { string }): Instance?
	local node: Instance? = base
	for _, n in path do
		node = node and node:FindFirstChild(n)
	end
	return node
end

-- Swings the door parts about the hinge when a character is within reach of the trigger point
-- (spec.roll: a roller door, each part shrinks up into its own top edge, the roll hood, instead).
local function autoDoor(
	model: Model,
	spec: {
		parts: { string },
		hinge: string,
		trigger: string,
		angle: number,
		roll: boolean?,
	}
)
	local hinge = findAttachment(model, spec.hinge)
	local trigger = findAttachment(model, spec.trigger)
	if not (hinge and trigger) then
		warn(`[WorldDressing] door: {spec.hinge} / {spec.trigger} missing on {model.Name}`)
		return
	end
	local axis = CFrame.new(hinge.WorldPosition)
	local parts: { { part: BasePart, closed: { [string]: any }, open: { [string]: any } } } = {}
	local swing = CFrame.Angles(0, math.rad(spec.angle), 0)
	for _, name in spec.parts do
		local p = model:FindFirstChild(name, true)
		if p and p:IsA("BasePart") then
			p.CanCollide = false
			local closed: { [string]: any } = { CFrame = p.CFrame }
			local open: { [string]: any } = { CFrame = axis * swing * axis:Inverse() * p.CFrame }
			if spec.roll then
				-- the part's local axis closest to world up is its height; keep 4 % of it at the top edge
				local up = p.CFrame:VectorToObjectSpace(Vector3.yAxis)
				local a = Vector3.new(math.abs(up.X), math.abs(up.Y), math.abs(up.Z))
				local mask = if a.X >= a.Y and a.X >= a.Z
					then Vector3.xAxis
					elseif a.Y >= a.Z then Vector3.yAxis
					else Vector3.zAxis
				local h = (p.Size * mask).Magnitude
				closed.Size = p.Size
				open.Size = p.Size - mask * h * 0.96
				open.CFrame = p.CFrame + Vector3.new(0, h * 0.48, 0)
			end
			table.insert(parts, { part = p, closed = closed, open = open })
		end
	end
	if #parts == 0 then
		return
	end
	local where = trigger.WorldPosition
	local info = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local isOpen = false
	task.spawn(function()
		while model.Parent do
			local near = false
			for _, plr in Players:GetPlayers() do
				local char = plr.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if hrp and hrp:IsA("BasePart") and (hrp.Position - where).Magnitude < 11 then
					near = true
					break
				end
			end
			if near ~= isOpen then
				isOpen = near
				for _, d in parts do
					TweenService:Create(d.part, info, if near then d.open else d.closed):Play()
				end
			end
			task.wait(0.25)
		end
	end)
end

-- layout metres (Blender X, Y, Z up) -> asset-frame studs (-x, z, y) * 3, then the swap pivot
local function toLocal(x: number, y: number, z: number): Vector3
	return Vector3.new(-x * 3, z * 3, y * 3)
end

local function collider(parent: Instance, name: string, cf: CFrame, size: Vector3)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = true
	p.CanQuery = true
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.CFrame = cf
	p:AddTag(AssetLoader.COLLISION_TAG)
	p.Parent = parent
end

local function addColliders(model: Model, spec: Swaps.Swap)
	local boxes: { { number } } = spec.colliders or {}
	for i, b in boxes do
		local lo, hi = toLocal(b[1], b[2], b[3]), toLocal(b[4], b[5], b[6])
		local size =
			Vector3.new(math.abs(hi.X - lo.X), math.abs(hi.Y - lo.Y), math.abs(hi.Z - lo.Z))
		collider(model, `Collision_{i}`, spec.pivot * CFrame.new((lo + hi) / 2), size)
	end
	local ramps: { { number } } = spec.ramps or {}
	for i, r in ramps do
		local a = toLocal((r[1] + r[2]) / 2, r[3], r[4])
		local b = toLocal((r[1] + r[2]) / 2, r[5], r[6])
		local width = math.abs(r[2] - r[1]) * 3
		local mid = (a + b) / 2
		-- a thin slab whose top surface runs from a to b
		local cf = CFrame.lookAt(mid, b) * CFrame.new(0, -0.3, 0)
		collider(model, `Ramp_{i}`, spec.pivot * cf, Vector3.new(width, 0.6, (b - a).Magnitude + 1))
	end
end

-- spec.ground: the pivot's Y follows the terrain top under the footprint (the highest of a grid of terrain
-- raycasts within `ground` studs of the pivot), so no terrain shows through the floor; the authored Y stays
-- when nothing is hit.
local function grounded(spec: Swaps.Swap): Swaps.Swap
	local reach = spec.ground
	if not reach then
		return spec
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local top: number? = nil
	for i = -2, 2 do
		for j = -2, 2 do
			local at = (spec.pivot * CFrame.new(i * reach / 2, 0, j * reach / 2)).Position
			local hit =
				Workspace:Raycast(at + Vector3.new(0, 40, 0), Vector3.new(0, -80, 0), params)
			if hit and (not top or hit.Position.Y > top) then
				top = hit.Position.Y
			end
		end
	end
	if not top then
		return spec
	end
	local out = table.clone(spec)
	out.pivot = spec.pivot + Vector3.new(0, top - spec.pivot.Y, 0)
	return out
end

-- spec.pad: raises the terrain under the footprint rectangle to the (grounded) pivot, so the plinth meets the
-- ground all round on uneven voxel ground (the town's height field sits exactly on a voxel boundary). Measured in
-- Studio: over a full voxel, a voxel of occupancy o meshes at its centre + 4 * o in a smooth material (Grass: 0.1 ->
-- +0.4 studs), but the WoodPlanks slot meshes blocky (empty above full: the voxel top, 2 studs low; any occupancy: a
-- full block, 2 studs high). So each column in the rectangle gets at least (top - centre) / 4 + PAD_EPS (+0.16
-- studs, so every column meshes) in its layers, never lowered, and blocky or empty voxels there take the smooth
-- material under the pivot (Grass if that is blocky too).
local VOXEL = 4
local PAD_EPS = 0.04
local BLOCKY: { [Enum.Material]: boolean } = { [Enum.Material.WoodPlanks] = true }
local function padTerrain(spec: Swaps.Swap)
	local r = spec.pad
	if not r then
		return
	end
	local terrain = Workspace.Terrain
	local a = spec.pivot * toLocal(r[1], r[2], 0)
	local b = spec.pivot * toLocal(r[3], r[4], 0)
	local top = spec.pivot.Y
	local y0 = math.floor((top - VOXEL) / VOXEL) * VOXEL
	local region = Region3.new(
		Vector3.new(math.min(a.X, b.X), y0, math.min(a.Z, b.Z)),
		Vector3.new(math.max(a.X, b.X), top + VOXEL, math.max(a.Z, b.Z))
	):ExpandToGrid(VOXEL)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { terrain }
	local hit = Workspace:Raycast(
		spec.pivot.Position + Vector3.new(0, 40, 0),
		Vector3.new(0, -80, 0),
		params
	)
	local fill = if hit
			and hit.Material ~= Enum.Material.Air
			and not BLOCKY[hit.Material]
		then hit.Material
		else Enum.Material.Grass
	local materials, occupancy = terrain:ReadVoxels(region, VOXEL)
	local bottom = region.CFrame.Position.Y - region.Size.Y / 2
	local n = occupancy.Size -- the tables carry a Size field: index them numerically
	for ix = 1, n.X do
		for iy = 1, n.Y do
			local want = math.clamp((top - (bottom + (iy - 0.5) * VOXEL)) / VOXEL + PAD_EPS, 0, 1)
			for iz = 1, n.Z do
				local m = materials[ix][iy][iz]
				if want > 0 and (m == Enum.Material.Air or BLOCKY[m]) then
					materials[ix][iy][iz] = fill
				end
				if want > occupancy[ix][iy][iz] then
					occupancy[ix][iy][iz] = want
				end
			end
		end
	end
	terrain:WriteVoxels(region, VOXEL, materials, occupancy)
end

local function swap(key: string, authored: Swaps.Swap): boolean
	local spec = grounded(authored)
	local map = Workspace:FindFirstChild("Map")
	local greybox = map and findPath(map, spec.greybox)
	local lod = spec.lod or "LOD0"
	local shellModels: { Model } = {}
	local interiorModels: { Model } = {}
	local all = table.clone(spec.shell)
	local interiorAssets: { string } = spec.interior or {}
	for _, a in interiorAssets do
		table.insert(all, a)
	end
	for _, asset in all do -- load in parallel, then clone
		task.spawn(AssetLoader.getTemplate, asset, lod)
	end
	for i, asset in all do
		local m = AssetLoader.cloneStatic(asset, lod, spec.collide ~= false)
		if not m then
			warn(`[WorldDressing] {key}: {asset} did not load; keeping the greybox`)
			for _, done in shellModels do
				done:Destroy()
			end
			for _, done in interiorModels do
				done:Destroy()
			end
			return false
		end
		m:PivotTo(spec.pivot)
		table.insert(if i <= #spec.shell then shellModels else interiorModels, m)
	end
	padTerrain(spec)
	local base = root()
	local shell = atomic(key, base)
	shell:SetAttribute("SwappedFrom", table.concat(spec.greybox, "."))
	for _, m in shellModels do
		m.Parent = shell
	end
	local interior = if #interiorModels > 0 then atomic(`{key}Interior`, base) else nil
	for _, m in interiorModels do
		m.Parent = interior
	end
	addColliders(shell, spec)
	shell.WorldPivot = spec.pivot
	if interior then
		interior.WorldPivot = spec.pivot
	end
	local byName: { [string]: Model } = {}
	for _, m in shellModels do
		byName[m:GetAttribute("Asset") :: string] = m
	end
	for _, m in interiorModels do
		byName[m:GetAttribute("Asset") :: string] = m
	end
	if spec.door and byName[spec.door.asset] then
		autoDoor(byName[spec.door.asset], spec.door)
	end
	if spec.rig then
		local mod = script.Parent.Parent.World:FindFirstChild(spec.rig)
		if mod and mod:IsA("ModuleScript") then
			local ok, err = pcall(function()
				local rig = (require :: any)(mod)
				rig.apply(shellModels[1], interiorModels[1], interiorModels[2], interiorModels[3])
			end)
			if not ok then
				warn(`[WorldDressing] {key}: rig {spec.rig} failed: {err}`)
			end
		end
	end
	if greybox and spec.hide then
		-- kept for the services that read its geometry: invisible, still the collider
		for _, d in { greybox, table.unpack(greybox:GetDescendants()) } do
			if d:IsA("BasePart") then
				d.Transparency = 1
				d.CastShadow = false
			elseif d:IsA("Decal") or d:IsA("Texture") or d:IsA("SurfaceAppearance") then
				d:Destroy()
			end
		end
		greybox:SetAttribute("SwappedTo", key)
	elseif greybox then
		local folder = greybox.Parent
		greybox:Destroy()
		-- a greybox group emptied by its swaps (Map.PortHaven.Houses, tagged GREYBOX) goes too
		if folder and folder:IsA("Folder") and #folder:GetChildren() == 0 then
			folder:Destroy()
		end
	end
	print(`[WorldDressing] {key}: swapped in {#all} assets`)
	return true
end

type Row = { number }

-- The client draws the scattered props (src/client/Controllers/ScatterController.luau: per-cell LOD0/1/2 by
-- camera distance, density by graphics quality). The server publishes the templates for it and keeps only the
-- rocks' invisible _COL hulls (boats and characters collide; nothing to render, almost nothing to stream).
local LODS = { "LOD0", "LOD1", "LOD2" }

-- Client copy of a template: visual parts and their wet SurfaceVariants (hulls and tags dropped), with the LOD0 bounds
-- the client needs to bury every LOD at the same height: BaseMinY / BaseSizeY / WaterlineY (studs, scale 1).
local function publish(asset: string, lod: string, folder: Folder, base: Model?): Model?
	local t = AssetLoader.getTemplate(asset, lod)
	if not t then
		return nil
	end
	local m = t:Clone()
	m.Name = `{asset}_{lod}`
	for _, d in m:GetDescendants() do
		-- SurfaceVariants stay: ScatterController swaps the plants to their wet maps in storms / wet look-dev
		-- shots (stripped, dry marram sat on darkened wet sand at the same tone and vanished from view)
		if d:IsA("BasePart") and d:HasTag(AssetLoader.COLLISION_TAG) then
			d:Destroy()
		end
	end
	for _, d in m:GetDescendants() do
		for _, tag in d:GetTags() do
			d:RemoveTag(tag)
		end
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	local ref = base or m
	ref:PivotTo(CFrame.identity)
	local cf, size = ref:GetBoundingBox()
	local att = findAttachment(ref, "ATT_Waterline")
	m:SetAttribute("BaseMinY", cf.Position.Y - size.Y / 2)
	m:SetAttribute("BaseSizeY", size.Y)
	m:SetAttribute("WaterlineY", if att then att.WorldPosition.Y else 0)
	local parts = 0
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	m:SetAttribute("Parts", parts) -- the client waits until every part has replicated
	m.Parent = folder
	return m
end

local function publishTemplates(assets: { string }, used: { [number]: boolean }): number
	local existing = ReplicatedStorage:FindFirstChild("ScatterTemplates")
	local folder: Folder = if existing and existing:IsA("Folder")
		then existing
		else Instance.new("Folder")
	folder.Name = "ScatterTemplates"
	for i in used do
		for _, lod in LODS do
			task.spawn(AssetLoader.getTemplate, assets[i], lod)
		end
	end
	local n, count = 0, 0
	for i in used do
		local base = publish(assets[i], "LOD0", folder, nil)
		if base then
			n += 1
			count += 1
		end
		for k = 2, #LODS do
			if publish(assets[i], LODS[k], folder, base) then
				count += 1
			end
		end
	end
	-- a big folder reaches the client over several frames: it waits for Count templates before drawing
	folder:SetAttribute("Count", count)
	folder.Parent = ReplicatedStorage -- parented last: the client starts once every template is in
	return n
end

-- Server rock: the _COL hull alone (invisible), at the same transform the client draws the mesh with.
local function placeHull(asset: string, row: Row): Model?
	local m = AssetLoader.cloneStatic(asset, "LOD2", true)
	if not m then
		return nil
	end
	local x, y, z, yaw, tx, tz, s, b =
		row[2], row[3], row[4], row[5], row[6], row[7], row[8], row[9]
	m:PivotTo(CFrame.identity)
	local cf, size = m:GetBoundingBox() -- LOD2 bounds as the fallback; LOD0 values come from the template
	local minY, sizeY = cf.Position.Y - size.Y / 2, size.Y
	local water = 0
	local pub = ReplicatedStorage:FindFirstChild("ScatterTemplates")
	local p = pub and pub:FindFirstChild(`{asset}_LOD0`)
	if p then
		minY, sizeY = p:GetAttribute("BaseMinY") :: number, p:GetAttribute("BaseSizeY") :: number
		water = p:GetAttribute("WaterlineY") :: number
	end
	local hull = false
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d:HasTag(AssetLoader.COLLISION_TAG) then
			hull = true
		end
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			if hull and not d:HasTag(AssetLoader.COLLISION_TAG) then
				d:Destroy()
			else
				d.Transparency = 1
				d.CastShadow = false
				for _, k in d:GetChildren() do
					if k:IsA("SurfaceAppearance") or k:IsA("Configuration") then
						k:Destroy()
					end
				end
			end
		end
	end
	s = s or 1
	if math.abs(s - 1) > 1e-3 then
		m:ScaleTo(s)
	end
	local lift = if b and b < 0 then -water * s else -minY * s - (b or 0) * sizeY * s
	m:PivotTo(
		CFrame.new(x, y + lift, z)
			* CFrame.Angles(math.rad(tx or 0), 0, math.rad(tz or 0))
			* CFrame.Angles(0, math.rad(yaw or 0), 0)
	)
	return m
end

local function hulls(rows: { Row }, assets: { string }): number
	local folder = Instance.new("Folder")
	folder.Name = "Rocks"
	folder.Parent = root()
	local cells: { [string]: Model } = {}
	local parts = 0
	for i, row in rows do
		local m = placeHull(assets[row[1]], row)
		if m then
			local key = `{math.floor(row[2] / CELL)}_{math.floor(row[4] / CELL)}`
			local cell = cells[key]
			if not cell then
				cell = atomic(`Rocks_{key}`, folder)
				cells[key] = cell
			end
			for _, d in m:GetChildren() do
				d.Parent = cell
				if d:IsA("BasePart") then
					parts += 1
				end
			end
			m:Destroy()
		end
		if i % YIELD_EVERY == 0 then
			task.wait()
		end
	end
	return parts
end

local function scatterAll()
	local data = ReplicatedStorage:FindFirstChild("WorldPlacements")
	if not (data and data:IsA("ModuleScript")) then
		warn(
			"[WorldDressing] ReplicatedStorage.WorldPlacements missing (run tools/world/scatter_props.py)"
		)
		return 0, 0, 0
	end
	local props = (require :: any)(data)
	local t0 = os.clock()
	local used: { [number]: boolean } = {}
	for _, group in { props.rocks or {}, props.plants or {} } do
		for _, row in group do
			used[row[1]] = true
		end
	end
	local n = publishTemplates(props.assets, used)
	local parts = hulls(props.rocks or {}, props.assets)
	print(
		`[WorldDressing] {n} scatter assets x 3 LODs published; {#(props.rocks or {})} rock hulls ({parts} parts), {#(props.plants or {})} plants drawn by the client, in {math.floor(
			(os.clock() - t0) * 10
		) / 10} s`
	)
	return #(props.rocks or {}), #(props.plants or {}), parts
end

function WorldDressingService.Start()
	local base = root()
	local Street = require(script.Parent.Parent.World:WaitForChild("Street")) :: any -- I1b-3 streets, Harbour Light
	for key, spec in Street.swaps do
		Swaps[key] = spec
	end
	for key, spec in Swaps do
		local ok, err = pcall(swap, key, spec)
		if not ok or err ~= true then
			warn(`[WorldDressing] swap {key} failed: {err}`)
		end
	end
	local hOk, hErr = pcall(require(script.Parent.Parent.World:WaitForChild("Harbour")).apply, base) -- RP-I1b-1
	if not hOk then
		warn(`[WorldDressing] harbour failed: {hErr}`)
	end
	local seamarks = script.Parent.Parent.World:FindFirstChild("Seamarks") -- RP-I1b-2 buoyage, Morwenna, anchor
	if seamarks then
		task.spawn((require :: any)(seamarks).place, base)
	end
	-- the cities (WorldConfig.Towns): road / pavement terrain first, so Street's junction fill and kerbs see it
	local Town = require(script.Parent.Parent.World:WaitForChild("Town")) :: any
	local tOk, tErr = pcall(Town.paint)
	if not tOk then
		warn(`[WorldDressing] town paint failed: {tErr}`)
	end
	task.spawn(Street.start)
	-- I2 ship batches: each owns one module in World/ with place(base); absent modules are skipped
	for _, name in
		{
			"Town",
			"TownExtras",
			"RoadsShore",
			"CoastArt",
			"SeabedLife",
			"SkerryLight",
			"StationYard",
			"Islands", -- docs/21 archipelago: World/Islands/<Id>.luau, one per island
			"Bridges", -- docs/23 (k): the hub -> player island suspension bridges
		}
	do
		local mod = script.Parent.Parent.World:FindFirstChild(name)
		if mod then
			task.spawn((require :: any)(mod).place, base)
		end
	end
	local ok, rocks, plants, parts = pcall(scatterAll)
	if not ok then
		warn(`[WorldDressing] scatter failed: {rocks}`)
	else
		base:SetAttribute("DressingRocks", rocks)
		base:SetAttribute("DressingPlants", plants)
		base:SetAttribute("DressingParts", parts)
	end
	base:SetAttribute("DressingReady", true)
	CollectionService:AddTag(base, "WorldDressing")
end

return WorldDressingService
