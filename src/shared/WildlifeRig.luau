--!strict
-- WildlifeRig: the pet animals (docs/15 H4): the low-poly M_Ani_<species> uploads (one MeshPart per
-- rig part, published in ReplicatedStorage.WildlifeTemplates by WildlifeArtService), with the chunky
-- code-built Part animal as the fallback while the meshes load or when they fail. Shared by the
-- server (the animal in the water, on the casualty's floater) and the client (the sanctuary pens
-- and the pet that follows you). Every part is anchored; callers move the whole
-- rig with WildlifeRig.setCFrame, which bulk-moves the parts around one pivot.
--
-- The rescue entanglement ("cut the net" / "wipe the oil" / "free the line") is one Part named
-- Entanglement in the rig; SanctuaryService drops it once the animal is aboard.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Wildlife = require(script.Parent.Config.Wildlife)

local WildlifeRig = {}

export type Rig = {
	parts: { BasePart },
	offsets: { CFrame },
	scale: number,
	cf: CFrame?,
}

-- The upload's MeshPart for each Species.parts entry, in rig order (build/prod/M_Pet_<species>
-- mapping.json; repeated rig names are split Left/Right, the turtle's Front/Back too).
local MESH_NODES: { [string]: { string } } = {
	SealPup = {
		"Body",
		"Belly",
		"Head",
		"Snout",
		"Nose",
		"EyeLeft",
		"EyeRight",
		"GlintLeft",
		"GlintRight",
		"FlipperLeft",
		"FlipperRight",
		"Tail",
	},
	Puffin = {
		"Body",
		"Belly",
		"Head",
		"Face",
		"Beak",
		"EyeLeft",
		"EyeRight",
		"GlintLeft",
		"GlintRight",
		"WingLeft",
		"WingRight",
		"FootLeft",
		"FootRight",
		"Tail",
	},
	Otter = {
		"Body",
		"Tummy",
		"Head",
		"Muzzle",
		"Nose",
		"EyeLeft",
		"EyeRight",
		"GlintLeft",
		"GlintRight",
		"EarLeft",
		"EarRight",
		"PawLeft",
		"PawRight",
		"Tail",
	},
	Turtle = {
		"Shell",
		"Plastron",
		"Head",
		"EyeLeft",
		"EyeRight",
		"GlintLeft",
		"GlintRight",
		"FlipperFrontLeft",
		"FlipperFrontRight",
		"FlipperBackLeft",
		"FlipperBackRight",
		"Tail",
	},
	Gull = {
		"Body",
		"Belly",
		"Head",
		"Beak",
		"EyeLeft",
		"EyeRight",
		"GlintLeft",
		"GlintRight",
		"WingLeft",
		"WingRight",
		"Tail",
		"LegLeft",
		"LegRight",
		"FootLeft",
		"FootRight",
	},
}
WildlifeRig.MESH_UPGRADE_WAIT = 60 -- seconds a block-built animal keeps looking for its mesh

local rigs: { [Model]: Rig } = setmetatable({}, { __mode = "k" }) :: any

local function newPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	shape: Enum.PartType?,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Shape = shape or Enum.PartType.Block
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function paletteFor(speciesId: string, rare: boolean): { [string]: Color3 }
	local spec = Wildlife.Species[speciesId]
	if not spec then
		return { Body = Color3.fromRGB(150, 150, 150) }
	end
	return if rare then spec.rarePalette else spec.palette
end

local function scaled(offset: CFrame, factor: number): CFrame
	return CFrame.new(offset.Position * factor) * (offset - offset.Position)
end

local function setPrimary(model: Model, rig: Rig)
	for _, part in rig.parts do
		if part.Name == "Body" then
			model.PrimaryPart = part
			return
		end
	end
	model.PrimaryPart = rig.parts[1]
end

-- Fresh copies of the species' mesh parts (rig order, named like the block parts) and their
-- rig-local offsets, or nil while the templates aren't (fully) replicated or failed to load. The
-- rare variant uses its own albedo where one was made (M_Ani_<species>_Rare), else the base texture.
local function meshParts(speciesId: string, rare: boolean): ({ BasePart }?, { CFrame }?)
	local spec = Wildlife.Species[speciesId]
	local nodes = MESH_NODES[speciesId]
	local folder = ReplicatedStorage:FindFirstChild("WildlifeTemplates")
	if not (spec and nodes and folder and #nodes == #spec.parts) then
		return nil, nil
	end
	local asset = `M_Ani_{speciesId}`
	local template = (rare and folder:FindFirstChild(asset .. "_Rare"))
		or folder:FindFirstChild(asset)
	if not (template and template:IsA("Model")) then
		return nil, nil
	end
	local found: { [string]: BasePart } = {}
	for _, d in template:GetDescendants() do
		if d:IsA("BasePart") then
			found[d.Name] = d
		end
	end
	local pivot = template:GetPivot()
	local parts, offsets = {}, {}
	for i, node in nodes do
		local source = found[node]
		local name = spec.parts[i].name
		if not source or string.sub(node, 1, #name) ~= name then
			return nil, nil
		end
		local part = source:Clone()
		part.Name = name
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		parts[i] = part
		offsets[i] = pivot:ToObjectSpace(source.CFrame)
	end
	return parts, offsets
end

-- Swaps a block-built animal's species parts for the meshes once they replicate (the pet can spawn
-- before WildlifeArtService has published them). Accessories added later keep their place.
local function upgradeWhenReady(model: Model, speciesId: string, rare: boolean)
	local deadline = os.clock() + WildlifeRig.MESH_UPGRADE_WAIT
	while os.clock() < deadline do
		task.wait(1)
		local rig = rigs[model]
		if not rig or not model.Parent then
			return
		end
		local parts, offsets = meshParts(speciesId, rare)
		if parts and offsets then
			for i, part in parts do
				rig.parts[i]:Destroy()
				part.Size *= rig.scale
				part.Parent = model
				rig.parts[i] = part
				rig.offsets[i] = scaled(offsets[i], rig.scale)
			end
			setPrimary(model, rig)
			if rig.cf then
				WildlifeRig.setCFrame(model, rig.cf)
			end
			return
		end
	end
end

-- Builds one animal at the origin (its pivot on the ground, face -Z). Parent it, then place it
-- with WildlifeRig.setCFrame.
function WildlifeRig.build(speciesId: string, rare: boolean): Model?
	local spec = Wildlife.Species[speciesId]
	if not spec then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = `Wildlife_{speciesId}`
	model:SetAttribute("Wildlife", speciesId)
	model:SetAttribute("WildlifeRare", rare == true)
	local rig: Rig = { parts = {}, offsets = {}, scale = 1 }
	local parts, offsets = meshParts(speciesId, rare)
	if parts and offsets then
		for i, part in parts do
			part.CFrame = offsets[i]
			part.Parent = model
		end
		rig.parts, rig.offsets = parts, offsets
	else
		local palette = paletteFor(speciesId, rare)
		for _, partSpec in spec.parts do
			local color = palette[partSpec.color] or palette.Body or Color3.fromRGB(150, 150, 150)
			local part = newPart(
				model,
				partSpec.name,
				partSpec.size,
				partSpec.at,
				color,
				partSpec.shape,
				partSpec.material
			)
			table.insert(rig.parts, part)
			table.insert(rig.offsets, partSpec.at)
		end
		if MESH_NODES[speciesId] then
			task.spawn(upgradeWhenReady, model, speciesId, rare)
		end
	end
	setPrimary(model, rig)
	rigs[model] = rig
	return model
end

-- The collision-free rescue dressing: a net, an oil slick or a line around the body.
function WildlifeRig.entangle(model: Model, verb: string): Part?
	local rig = rigs[model]
	if not rig then
		return nil
	end
	local part: Part
	if verb == "Wipe" then
		part = newPart(
			model,
			"Entanglement",
			Vector3.new(4.4, 0.12, 3.6),
			CFrame.new(0, 0.08, 0),
			Color3.fromRGB(22, 24, 26),
			Enum.PartType.Cylinder,
			Enum.Material.SmoothPlastic
		)
		part.CFrame = CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.pi / 2)
		part.Transparency = 0.2
	elseif verb == "Free" then
		part = newPart(
			model,
			"Entanglement",
			Vector3.new(1.9, 0.12, 2.7),
			CFrame.new(0, 1.3, 0),
			Color3.fromRGB(228, 228, 216)
		)
		part.CFrame = CFrame.new(0, 1.3, 0) * CFrame.Angles(0, 0.4, 0.16)
	else
		part = newPart(
			model,
			"Entanglement",
			Vector3.new(3.1, 0.14, 2.2),
			CFrame.new(0, 1.15, 0),
			Color3.fromRGB(46, 66, 52)
		)
		part.Transparency = 0.3
	end
	table.insert(rig.parts, part)
	table.insert(rig.offsets, part.CFrame)
	return part
end

-- Moves the whole animal: pivot at `cf` on the ground (or the sea surface).
function WildlifeRig.setCFrame(model: Model, cf: CFrame)
	local rig = rigs[model]
	if not rig then
		return
	end
	local parts = table.create(#rig.parts)
	local cframes = table.create(#rig.parts)
	for i, part in rig.parts do
		if part.Parent then
			table.insert(parts, part)
			table.insert(cframes, cf * rig.offsets[i])
		end
	end
	rig.cf = cf
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- Scales the whole animal in place (the following pet reads bigger than a pen animal). The
-- part offsets scale with it, so setCFrame keeps working.
function WildlifeRig.scale(model: Model, factor: number)
	local rig = rigs[model]
	if not rig or factor <= 0 then
		return
	end
	rig.scale *= factor
	for i, part in rig.parts do
		part.Size = part.Size * factor
		rig.offsets[i] = scaled(rig.offsets[i], factor)
	end
end

-- The rig-local offset of one built part (the vest sits on the body's offset, not the pivot).
function WildlifeRig.offsetOf(model: Model, name: string): CFrame?
	local rig = rigs[model]
	if not rig then
		return nil
	end
	for i, part in rig.parts do
		if part.Name == name then
			return rig.offsets[i]
		end
	end
	return nil
end

-- Adds one cosmetic part to the rig (the G48 life vest); it then moves with the animal.
function WildlifeRig.attach(
	model: Model,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?
): Part?
	local rig = rigs[model]
	if not rig then
		return nil
	end
	local part = newPart(model, name, size, offset, color, nil, material)
	table.insert(rig.parts, part)
	table.insert(rig.offsets, offset)
	return part
end

-- The model's local height, for billboards and prompts that sit above the animal's head.
function WildlifeRig.height(model: Model): number
	local rig = rigs[model]
	if not rig then
		return 2
	end
	local top = 0
	for i, part in rig.parts do
		local offset = rig.offsets[i]
		local half = part.Size.Y / 2
		local y = offset.Y + half
		if part.Name ~= "Entanglement" then
			top = math.max(top, y)
		end
	end
	return top
end

return WildlifeRig
