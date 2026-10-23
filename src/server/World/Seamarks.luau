--!strict
-- Seamarks (RP-I1b-2): places the HP2b buoyage and the S1a / POL2 seabed finds at run time (WorldDressingService
-- calls Seamarks.place(Workspace.Dressing) once at server start).
--
--   * buoys and nav marks from Shared.SeamarkRules.Marks: one Atomic model each, Workspace.Dressing.Seamarks.<id>,
--     ATT_WaterLine (the authored pivot) on the sea surface, anchored, the _COL hull colliding. Tag "Seamark",
--     attributes SeamarkId, Light (characteristic), DisplayName. The client (SeamarkController) bobs and tilts the
--     visual copy with Waves and drives the *_Lens Neon / PointLight flash at night and in a storm;
--   * the Morwenna (M_Sea_Morwenna): pivot (base) 5.21 studs under the terrain surface at the WorldConfig POI, no
--     greybox roll, the frame clones of MorwennaRibs (instances.json), the kelp DoubleSided with AlphaMode
--     Transparency, the ship's bell (M_Sea_Bell) hung by its crown ATT_Bell at the wreck's ATT_Bell;
--   * the Admiralty anchor (M_Sea_AdmiraltyAnchor): pivot 2.46 studs under the terrain (placement.json).
--   The greybox Map.Seabed.Morwenna / AdmiraltyAnchor is destroyed once its asset is in (kept if the load fails);
--   the discovery attributes move to the new model. The models sit on the WorldConfig.POIs position, yaw and footprint.
-- Workspace.Dressing.Seamarks attributes when done: SeamarksPlaced (marks), SeamarksWreck, SeamarksAnchor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AssetLoader = require(script.Parent.Parent:WaitForChild("Assets"):WaitForChild("AssetLoader"))
local MorwennaRibs = require(script.Parent:WaitForChild("MorwennaRibs"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local SeamarkRules = require(Shared:WaitForChild("SeamarkRules"))
local WorldConfig = require(Shared:WaitForChild("Config"):WaitForChild("WorldConfig"))

local Seamarks = {}

Seamarks.TAG = "Seamark"
local ANCHOR_BELOW = 2.464 -- assets/fbx/M_Sea_AdmiraltyAnchor/M_Sea_AdmiraltyAnchor.placement.json

local function atomic(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = parent
	return m
end

local function poi(id: string): any
	for _, p in WorldConfig.POIs do
		if p.id == id then
			return p
		end
	end
	return nil
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { Workspace.Terrain }
rayParams.IgnoreWater = true

-- the terrain surface at (x, z), or `fallback` (the WorldConfig bake height) where nothing is hit
local function surfaceY(x: number, z: number, fallback: number): number
	local hit = Workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), rayParams)
	return if hit then hit.Position.Y else fallback
end

local function findAttachment(model: Model, name: string): Attachment?
	local a = model:FindFirstChild(name, true)
	return if a and a:IsA("Attachment") then a else nil
end

-- the greybox model of a POI: its discovery attributes go to the asset, then it goes
local function retire(id: string, into: Model)
	local map = Workspace:FindFirstChild("Map")
	local seabed = map and map:FindFirstChild("Seabed")
	local grey = seabed and seabed:FindFirstChild(id)
	if not grey then
		return
	end
	for k, v in grey:GetAttributes() do
		into:SetAttribute(k, v)
	end
	into:SetAttribute("SwappedFrom", `Map.Seabed.{id}`)
	grey:Destroy()
end

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

-- Frame clones (MorwennaRibs.rows, studs from the LOD0 bounding-box centre frame): the masters are in the upload;
-- the box-centre frame is recovered from each master (its world position minus its row offset, the wreck's
-- rotation), so the clones land exactly where the export put them whatever the import's centring.
local function ribs(model: Model, pivot: CFrame): number
	local rot = pivot.Rotation
	local masters: { [string]: { part: BasePart, centre: CFrame, turn: CFrame } } = {}
	for _, row in MorwennaRibs.rows do
		if row.master then
			local part = model:FindFirstChild(`{row.mesh}_LOD0`, true)
			if part and part:IsA("BasePart") then
				local centre = CFrame.new(part.Position - rot:VectorToWorldSpace(v3(row.pos))) * rot
				masters[row.mesh] =
					{ part = part, centre = centre, turn = rot:Inverse() * part.CFrame.Rotation }
			end
		end
	end
	local n = 0
	for i, row in MorwennaRibs.rows do
		local m = masters[row.mesh]
		if not row.master and m then
			local c = m.part:Clone()
			c.Name = `{row.mesh}_LOD0_{i}`
			c.Size = m.part.Size * v3(row.size)
			c.CFrame = m.centre
				* CFrame.fromMatrix(v3(row.pos), v3(row.right), v3(row.up), v3(row.back))
				* m.turn
			c.Parent = m.part.Parent
			n += 1
		end
	end
	return n
end

local function kelp(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") and string.find(d.Name, "_Kelp_", 1, true) then
			local ok = pcall(function()
				(d :: any).DoubleSided = true
			end)
			if not ok then
				warn(
					"[Seamarks] Morwenna kelp: DoubleSided is not writable at run time (back faces culled)"
				)
			end
			local sa = d:FindFirstChildOfClass("SurfaceAppearance")
			if sa and sa.AlphaMode ~= Enum.AlphaMode.Transparency then
				pcall(function()
					sa.AlphaMode = Enum.AlphaMode.Transparency
				end)
			end
		end
	end
end

local function placeWreck(base: Instance): boolean
	local p = poi("Morwenna")
	local model = p and AssetLoader.cloneStatic("M_Sea_Morwenna", "LOD0", true)
	if not p or not model then
		warn("[Seamarks] M_Sea_Morwenna did not load; keeping the greybox")
		return false
	end
	local x, z = p.position.X, p.position.Z
	local pivot = CFrame.new(x, surfaceY(x, z, p.position.Y) - MorwennaRibs.terrainAboveBase, z)
		* CFrame.Angles(0, math.rad(p.yaw), 0)
	model:PivotTo(pivot)
	local holder = atomic("Morwenna", base)
	model.Parent = holder
	local clones = ribs(model, pivot)
	kelp(model)
	local hang = findAttachment(model, "ATT_Bell")
	local bell = AssetLoader.cloneStatic("M_Sea_Bell", "LOD0", false)
	if bell and hang then
		local crown = findAttachment(bell, "ATT_Bell")
		local fromCrown = if crown
			then crown.WorldCFrame:ToObjectSpace(bell:GetPivot())
			else CFrame.new(0, -0.936, 0)
		bell:PivotTo(hang.WorldCFrame * fromCrown)
		bell.Parent = holder
	else
		warn(`[Seamarks] the Morwenna bell was not hung (bell {bell}, ATT_Bell {hang})`)
	end
	holder.WorldPivot = pivot
	retire("Morwenna", holder)
	print(
		`[Seamarks] Morwenna placed: base Y {math.floor(pivot.Y * 100) / 100}, {clones} frame clones`
	)
	return true
end

local function placeAnchor(base: Instance): boolean
	local p = poi("AdmiraltyAnchor")
	local model = p and AssetLoader.cloneStatic("M_Sea_AdmiraltyAnchor", "LOD0", true)
	if not p or not model then
		warn("[Seamarks] M_Sea_AdmiraltyAnchor did not load; keeping the greybox")
		return false
	end
	local x, z = p.position.X, p.position.Z
	local pivot = CFrame.new(x, surfaceY(x, z, p.position.Y) - ANCHOR_BELOW, z)
		* CFrame.Angles(0, math.rad(p.yaw), 0)
	model:PivotTo(pivot)
	local holder = atomic("AdmiraltyAnchor", base)
	model.Parent = holder
	holder.WorldPivot = pivot
	retire("AdmiraltyAnchor", holder)
	return true
end

local function placeMarks(folder: Instance): number
	local sea = Workspace:GetAttribute("SeaLevel")
	local seaY = if type(sea) == "number" then sea else WorldConfig.SeaLevel
	for _, m in SeamarkRules.Marks do -- load the templates in parallel, then clone
		task.spawn(AssetLoader.getTemplate, m.asset, "LOD0")
	end
	local n = 0
	for _, m in SeamarkRules.Marks do
		local model = AssetLoader.cloneStatic(m.asset, "LOD0", true)
		if model then
			local holder = atomic(m.id, folder)
			model:PivotTo(CFrame.new(m.x, seaY, m.z) * CFrame.Angles(0, math.rad(m.yaw), 0))
			model.Parent = holder
			holder.WorldPivot = model:GetPivot()
			holder:SetAttribute("SeamarkId", m.id)
			holder:SetAttribute("DisplayName", m.name)
			holder:SetAttribute("Asset", m.asset)
			holder:SetAttribute("SeaY", seaY)
			if m.light then
				holder:SetAttribute("Light", m.light)
			end
			holder:AddTag(Seamarks.TAG)
			n += 1
		else
			warn(`[Seamarks] {m.id}: {m.asset} did not load`)
		end
	end
	return n
end

function Seamarks.place(base: Instance)
	local folder = Instance.new("Model")
	folder.Name = "Seamarks"
	folder.ModelStreamingMode = Enum.ModelStreamingMode.Nonatomic
	folder.Parent = base
	local okW, wreck = pcall(placeWreck, base)
	local okA, anchor = pcall(placeAnchor, base)
	local okM, marks = pcall(placeMarks, folder)
	if not (okW and okA and okM) then
		warn(`[Seamarks] failed: wreck {wreck}, anchor {anchor}, marks {marks}`)
	end
	folder:SetAttribute("SeamarksWreck", okW and wreck == true)
	folder:SetAttribute("SeamarksAnchor", okA and anchor == true)
	folder:SetAttribute("SeamarksPlaced", if okM then marks else 0)
	print(`[Seamarks] {if okM then marks else 0} of {#SeamarkRules.Marks} marks placed`)
end

return Seamarks
