--!strict
-- WorldDressingService (I1, docs/12 section 3.2): places the production Packages in the world at run time
-- (Build.luau runs under Lune and cannot load assets):
--   * the K1 rocks and G1 plants from map/generated/props.json (tools/world/scatter_props.py, synced by Rojo as
--     ReplicatedStorage.WorldPlacements): the server publishes LOD0/1/2 templates (ReplicatedStorage.ScatterTemplates)
--     and places only the rocks' collision hulls (CELL x CELL Atomic models); ScatterController draws the meshes.
-- Workspace.Dressing attributes when done: DressingReady, DressingRocks, DressingPlants, DressingParts.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AssetLoader = require(script.Parent.Parent:WaitForChild("Assets"):WaitForChild("AssetLoader"))

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

type Row = { number }

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

local function hulls(rows: { Row }, assets: { string }, name: string): number
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = root()
	local cells: { [string]: Model } = {}
	local parts = 0
	for i, row in rows do
		local m = placeHull(assets[row[1]], row)
		if m then
			local key = `{math.floor(row[2] / CELL)}_{math.floor(row[4] / CELL)}`
			local cell = cells[key]
			if not cell then
				cell = atomic(`{name}_{key}`, folder)
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
	local parts = hulls(props.rocks or {}, props.assets, "Rocks")
	print(
		`[WorldDressing] {n} scatter assets x 3 LODs published; {#(props.rocks or {})} rock hulls ({parts} parts), {#(props.plants or {})} plants drawn by the client, in {math.floor(
			(os.clock() - t0) * 10
		) / 10} s`
	)
	return #(props.rocks or {}), #(props.plants or {}), parts
end

function WorldDressingService.Start()
	local base = root()
	local seamarks = script.Parent.Parent.World:FindFirstChild("Seamarks") -- RP-I1b-2 buoyage, Morwenna, anchor
	if seamarks then
		task.spawn((require :: any)(seamarks).place, base)
	end
	-- I2 ship batches: each owns one module in World/ with place(base); absent modules are skipped
	for _, name in
		{
			"CoastArt",
			"SkerryLight",
			"Islands", -- docs/21 archipelago: World/Islands/<Id>.luau, one per island
			"Bridges", -- docs/23 (p): the ring of neighbour bridges between the player islands
			"IslandPlates", -- WP-24: the six player islands are flat Lego baseplates, not terrain
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
