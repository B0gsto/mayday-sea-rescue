--!strict
-- CoastArt (G75): places the I2f coast and seabed art at run time. WorldDressingService.Start calls
-- CoastArt.place(Workspace.Dressing) once; the placement data and the tests are in CoastArtLayout
-- (tests/CoastArt.spec.luau).
--
-- The Needle's Eye arch stands on the GullyArch seabed; the three cliff strips continue the Haven Head faces and the
-- ledges sit at the waterline either side of the cliff-casualty shelf. Kelp fills WorldConfig.KelpBeds, the mail
-- seaplane replaces its greybox POI, and the I2d clutter (bottle field, lost pots, mooring blocks, sand ripples) lies
-- on the harbour and Calm Bay seabed.
--
-- Every piece is raycast onto the Terrain and sunk slightly, so nothing floats. A piece whose asset or ground is
-- missing is skipped with a warning (there is no greybox for these props). Folder attributes when done:
-- CoastArtArch, CoastArtSeaplane, CoastArtCliffs, CoastArtLedges, CoastArtKelp, CoastArtBottles, CoastArtPots,
-- CoastArtMooring, CoastArtRipples.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AssetIds = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("AssetIds")
) :: any
local AssetLoader = require(script.Parent.Parent:WaitForChild("Assets"):WaitForChild("AssetLoader"))
local Layout = require(script.Parent:WaitForChild("CoastArtLayout"))
local RoadsShoreLayout = require(script.Parent:WaitForChild("RoadsShoreLayout"))
local WorldConfig = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("WorldConfig")
)

local CoastArt = {}

local ATTACHMENTS = AssetIds.Attachments or {}

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { Workspace.Terrain }
rayParams.IgnoreWater = true

local function seaLevel(): number
	local sea = Workspace:GetAttribute("SeaLevel")
	return if type(sea) == "number" then sea else WorldConfig.SeaLevel
end

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

local function wet(model: Model)
	AssetLoader.setWet(model, true)
end

-- Keep one visual part of a kit (and its collision proxy), drop the rest.
local function trimTo(model: Model, keep: string, keepCol: string?)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= keep and d.Name ~= keepCol then
			d:Destroy()
		end
	end
end

-- The wanted part's translation from the kit's authored pivot, captured before trimming.
local function partOffset(model: Model, keep: string): Vector3?
	local part = model:FindFirstChild(keep, true)
	if part and part:IsA("BasePart") then
		return model:GetPivot():PointToObjectSpace(part.Position)
	end
	return nil
end

local function placeModel(
	asset: string,
	cf: CFrame,
	folder: Folder,
	name: string,
	collide: boolean,
	lod: string?
): Model?
	local m = AssetLoader.cloneStatic(asset, lod or "LOD0", collide)
	if not m then
		return nil
	end
	wet(m)
	m:PivotTo(cf)
	local holder = atomic(name, folder)
	m.Parent = holder
	holder.WorldPivot = cf
	return holder
end

-- One part of a kit, positioned by its authored offset from the kit pivot.
local function placePart(
	asset: string,
	keep: string,
	offset: Vector3,
	cf: CFrame,
	folder: Folder,
	name: string,
	collide: boolean,
	lod: string?
): Model?
	local m = AssetLoader.cloneStatic(asset, lod or "LOD0", collide)
	if not m then
		return nil
	end
	wet(m)
	m:PivotTo(cf * CFrame.new(-offset))
	trimTo(m, keep)
	local holder = atomic(name, folder)
	m.Parent = holder
	holder.WorldPivot = cf
	return holder
end

local function arch(folder: Folder): number
	local spec = Layout.Arch
	local poi: any = nil
	for _, p in WorldConfig.POIs do
		if p.id == spec.poi then
			poi = p
		end
	end
	if not poi then
		warn(`[CoastArt] no WorldConfig POI {spec.poi}`)
		return 0
	end
	-- The POI y is the gully floor (a ray down hits the greybox terrain arch at the surface). poi.yaw is the
	-- gully's bearing from +X toward +Z; the asset spans its local X, so turn it 90 degrees to span across.
	local cf = CFrame.new(poi.position.X, poi.position.Y - spec.sink, poi.position.Z)
		* CFrame.Angles(0, math.rad(90 - poi.yaw), 0)
	if not placeModel(spec.asset, cf, folder, "NeedlesEye", true) then
		warn(`[CoastArt] {spec.asset} did not load`)
		return 0
	end
	return 1
end

local function poiById(id: string): any
	for _, p in WorldConfig.POIs do
		if p.id == id then
			return p
		end
	end
	return nil
end

-- The greybox POI carries the discovery attributes; hand them to the real asset and drop the greybox.
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

local function seaplane(folder: Folder): number
	local spec = Layout.Seaplane
	local poi = poiById(spec.poi)
	if not poi then
		warn(`[CoastArt] no WorldConfig POI {spec.poi}`)
		return 0
	end
	local y = groundY(poi.position.X, poi.position.Z)
	if not y then
		warn(`[CoastArt] seaplane: no seabed under {poi.position}`)
		return 0
	end
	local cf = CFrame.new(poi.position.X, y + spec.lift, poi.position.Z)
		* CFrame.Angles(0, math.rad(poi.yaw), 0)
	local holder = placeModel(spec.asset, cf, folder, "MailSeaplane", true)
	if not holder then
		warn(`[CoastArt] {spec.asset} did not load; keeping the greybox`)
		return 0
	end
	local model = holder:FindFirstChildWhichIsA("Model")
	if model then
		retire(spec.poi, model)
	end
	return 1
end

local function rocks(
	spots: { { asset: string, x: number, z: number, yaw: number, sink: number } },
	folder: Folder,
	prefix: string
): number
	local n = 0
	for _, s in spots do
		local y = groundY(s.x, s.z)
		if y then
			local cf = CFrame.new(s.x, y - s.sink, s.z) * CFrame.Angles(0, s.yaw, 0)
			if placeModel(s.asset, cf, folder, `{prefix}_{n + 1}`, true) then
				n += 1
			end
		else
			warn(`[CoastArt] {s.asset}: no ground at {s.x}, {s.z}`)
		end
	end
	return n
end

local function kelp(folder: Folder): number
	local beds: { [string]: any } = {}
	for _, bed in WorldConfig.KelpBeds do
		beds[bed.id] = bed
	end
	local sea = seaLevel()
	local n = 0
	for _, spec in Layout.Kelp do
		local bed = beds[spec.bed]
		if not bed then
			warn(`[CoastArt] no kelp bed {spec.bed}`)
			continue
		end
		for _, p in
			RoadsShoreLayout.scatter(bed.center, bed.radius, spec.count, spec.seed, spec.inner)
		do
			if Layout.excluded(p.X, p.Z, 10) then
				continue
			end
			local y = groundY(p.X, p.Z)
			if y and y < sea - 4 and y > sea - 46 then
				local k = ((n + spec.piece - 1) % 4) + 1
				local asset = "M_Veg_Kelp_Kit"
				local holdfast = ATTACHMENTS[asset] and ATTACHMENTS[asset][`ATT_Holdfast_0{k}`]
				local cf = CFrame.new(p.X, y - 0.35, p.Z) * CFrame.Angles(0, (n + 1) * 2.399963, 0)
				if
					holdfast
					and placePart(
						asset,
						`M_Veg_Kelp_0{k}_LOD0`,
						holdfast,
						cf,
						folder,
						`Kelp_{n + 1}`,
						false,
						spec.lod
					)
				then
					n += 1
				end
			end
		end
	end
	return n
end

local function bottleField(folder: Folder): number
	local spec = Layout.BottleField
	local sea = seaLevel()
	local n = 0
	for i, p in
		RoadsShoreLayout.scatter(Vector3.new(spec.x, 0, spec.z), spec.radius, spec.count, spec.seed)
	do
		if Layout.inHarbourChannel(p.X, p.Z) or Layout.excluded(p.X, p.Z) then
			continue
		end
		local y = groundY(p.X, p.Z)
		if y and y < sea - 8 and y > sea - 30 then
			local keep = spec.keep[((i - 1) % #spec.keep) + 1]
			local cf = CFrame.new(p.X, y - 0.05, p.Z) * CFrame.Angles(0, i * 2.399963, 0)
			local m = AssetLoader.cloneStatic("M_Sea_BottleField", "LOD0", false)
			local offset = m and partOffset(m, keep)
			if m and offset then
				wet(m)
				m:PivotTo(cf * CFrame.new(-offset))
				trimTo(m, keep)
				local holder = atomic(`Bottle_{n + 1}`, folder)
				m.Parent = holder
				holder.WorldPivot = cf
				n += 1
			elseif m then
				m:Destroy()
			end
		end
	end
	return n
end

local function pots(folder: Folder): number
	local sea = seaLevel()
	local n = 0
	for _, s in Layout.Pots do
		if Layout.inHarbourChannel(s.x, s.z) or Layout.excluded(s.x, s.z) then
			continue
		end
		local y = groundY(s.x, s.z)
		if y and y < sea - 6 and y > sea - 30 then
			local cf = CFrame.new(s.x, y, s.z) * CFrame.Angles(0, s.yaw, 0)
			if placeModel("M_Sea_LostPot", cf, folder, `Pot_{n + 1}`, false) then
				n += 1
			end
		end
	end
	return n
end

local function mooringBlocks(folder: Folder): number
	local sea = seaLevel()
	local n = 0
	for _, s in Layout.MooringBlocks do
		if Layout.inHarbourChannel(s.x, s.z) or Layout.excluded(s.x, s.z) then
			continue
		end
		local y = groundY(s.x, s.z)
		if y and y < sea - 8 and y > sea - 40 then
			local cf = CFrame.new(s.x, y - 0.15, s.z) * CFrame.Angles(0, s.yaw, 0)
			if placeModel("M_Sea_MooringBlock", cf, folder, `Mooring_{n + 1}`, true) then
				n += 1
			end
		end
	end
	return n
end

local function ripples(folder: Folder): number
	local sea = seaLevel()
	local n = 0
	for _, s in Layout.Ripples do
		if Layout.excluded(s.x, s.z) then
			continue
		end
		local y = groundY(s.x, s.z)
		if y and y < sea - 5 and y > sea - 25 then
			local m = AssetLoader.cloneStatic("M_Sea_SandRipples", "LOD0", false)
			local offset = m and partOffset(m, s.keep)
			if m and offset then
				wet(m)
				local cf = CFrame.new(s.x, y + 0.04, s.z) * CFrame.Angles(0, s.yaw, 0)
				m:PivotTo(cf * CFrame.new(-offset))
				trimTo(m, s.keep)
				local holder = atomic(`Ripples_{n + 1}`, folder)
				m.Parent = holder
				holder.WorldPivot = cf
				n += 1
			elseif m then
				m:Destroy()
			end
		end
	end
	return n
end

local function try(name: string, fn: (Folder) -> number, folder: Folder): number
	local ok, n = pcall(fn, folder)
	if not ok then
		warn(`[CoastArt] {name} failed: {n}`)
		return 0
	end
	return n
end

function CoastArt.place(base: Instance)
	local folder = Instance.new("Model")
	folder.Name = "CoastArt"
	folder.ModelStreamingMode = Enum.ModelStreamingMode.Nonatomic
	folder.Parent = base
	local sections = {
		Arch = category(folder, "Arch"),
		Seaplane = category(folder, "Seaplane"),
		Cliffs = category(folder, "Cliffs"),
		Ledges = category(folder, "Ledges"),
		Kelp = category(folder, "Kelp"),
		Bottles = category(folder, "Bottles"),
		Pots = category(folder, "Pots"),
		Mooring = category(folder, "Mooring"),
		Ripples = category(folder, "Ripples"),
	}
	task.spawn(AssetLoader.getTemplate, "M_Rock_NeedlesEye", "LOD0")
	task.spawn(AssetLoader.getTemplate, Layout.Seaplane.asset, "LOD0")
	task.spawn(AssetLoader.getTemplate, "M_Sea_BottleField", "LOD0")
	task.spawn(AssetLoader.getTemplate, "M_Sea_LostPot", "LOD0")
	task.spawn(AssetLoader.getTemplate, "M_Sea_MooringBlock", "LOD0")
	task.spawn(AssetLoader.getTemplate, "M_Sea_SandRipples", "LOD0")
	for _, spec in Layout.Cliffs do
		task.spawn(AssetLoader.getTemplate, spec.asset, "LOD0")
	end
	for _, spec in Layout.Ledges do
		task.spawn(AssetLoader.getTemplate, spec.asset, "LOD0")
	end
	for _, spec in Layout.Kelp do
		task.spawn(AssetLoader.getTemplate, "M_Veg_Kelp_Kit", spec.lod)
	end
	local counts = {
		Arch = try("arch", arch, sections.Arch),
		Seaplane = try("seaplane", seaplane, sections.Seaplane),
		Cliffs = try("cliffs", function(f)
			return rocks(Layout.Cliffs, f, "Cliff")
		end, sections.Cliffs),
		Ledges = try("ledges", function(f)
			return rocks(Layout.Ledges, f, "Ledge")
		end, sections.Ledges),
		Kelp = try("kelp", kelp, sections.Kelp),
		Bottles = try("bottle field", bottleField, sections.Bottles),
		Pots = try("pots", pots, sections.Pots),
		Mooring = try("mooring blocks", mooringBlocks, sections.Mooring),
		Ripples = try("ripples", ripples, sections.Ripples),
	}
	folder:SetAttribute("CoastArtArch", counts.Arch)
	folder:SetAttribute("CoastArtSeaplane", counts.Seaplane)
	folder:SetAttribute("CoastArtCliffs", counts.Cliffs)
	folder:SetAttribute("CoastArtLedges", counts.Ledges)
	folder:SetAttribute("CoastArtKelp", counts.Kelp)
	folder:SetAttribute("CoastArtBottles", counts.Bottles)
	folder:SetAttribute("CoastArtPots", counts.Pots)
	folder:SetAttribute("CoastArtMooring", counts.Mooring)
	folder:SetAttribute("CoastArtRipples", counts.Ripples)
	print(
		`[CoastArt] arch {counts.Arch}, seaplane {counts.Seaplane}, cliffs {counts.Cliffs}, ledges {counts.Ledges}, kelp {counts.Kelp}, bottles {counts.Bottles}, pots {counts.Pots}, mooring {counts.Mooring}, ripples {counts.Ripples}`
	)
end

return CoastArt
