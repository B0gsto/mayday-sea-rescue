--!strict
-- WildlifeRig: the chunky code-built Part animals (docs/15 H4) until real art lands.
-- Shared by the server (the animal in the water, on the casualty's floater) and the client (the
-- sanctuary pens and the pet that follows you). Every part is anchored; callers move the whole
-- rig with WildlifeRig.setCFrame, which bulk-moves the parts around one pivot.
--
-- The rescue entanglement ("cut the net" / "wipe the oil" / "free the line") is one Part named
-- Entanglement in the rig; SanctuaryService drops it once the animal is aboard.

local Workspace = game:GetService("Workspace")

local Wildlife = require(script.Parent.Config.Wildlife)

export type Rig = {
	parts: { BasePart },
	offsets: { CFrame },
}

local WildlifeRig = {}

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

-- Builds one animal at the origin (its pivot on the ground, face -Z). Parent it, then place it
-- with WildlifeRig.setCFrame.
function WildlifeRig.build(speciesId: string, rare: boolean): Model?
	local spec = Wildlife.Species[speciesId]
	if not spec then
		return nil
	end
	local palette = paletteFor(speciesId, rare)
	local model = Instance.new("Model")
	model.Name = `Wildlife_{speciesId}`
	model:SetAttribute("Wildlife", speciesId)
	model:SetAttribute("WildlifeRare", rare == true)
	local rig: Rig = { parts = {}, offsets = {} }
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
		if partSpec.name == "Body" and not model.PrimaryPart then
			model.PrimaryPart = part
		end
	end
	if not model.PrimaryPart and rig.parts[1] then
		model.PrimaryPart = rig.parts[1]
	end
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
	for i, part in rig.parts do
		part.Size = part.Size * factor
		local offset = rig.offsets[i]
		rig.offsets[i] = CFrame.new(offset.Position * factor) * (offset - offset.Position)
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
