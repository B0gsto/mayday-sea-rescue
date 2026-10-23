--!strict
-- SkerryLight: a greybox granite tower on the west head of Skerry Isle, tall enough to read from the
-- harbour (dressing only since the lighthouse missions were cut, docs/16 C15). Tagged Lighthouse /
-- LighthouseLens; StreetController finds ATT_Light and turns the Fl(2) beam at night. Persistent streaming: it is
-- the isle's landmark from Calm Bay and the harbour mouth, well past the streaming radius.
-- WorldDressingService calls SkerryLight.place(base) once at server start.
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local SkerryLight = {}

local POSITION = Vector3.new(1520, 30, 1700)
local STEEL = Color3.fromRGB(62, 68, 72)
local PAINT = Color3.fromRGB(226, 226, 218)

local function groundAt(x: number, z: number, fallback: number): number
	local hit = Workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0))
	return if hit and hit.Position.Y > -20 then hit.Position.Y else fallback
end

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Shape = shape or Enum.PartType.Block
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function SkerryLight.place(_base: Instance?)
	if Workspace:FindFirstChild("SkerryLight") then
		return
	end
	local x, z = POSITION.X, POSITION.Z
	local baseY = groundAt(x, z, POSITION.Y)
	local base = Vector3.new(x, baseY, z)
	local model = Instance.new("Model")
	model.Name = "SkerryLight"
	model:SetAttribute("LightId", "SkerryLight")
	-- the granite plinth reaches 4 studs into the rock (uneven ground), the tower stands on its top
	local bottom = part(
		model,
		"Base",
		Vector3.new(22, 9, 22),
		CFrame.new(base + Vector3.new(0, 0.5, 0)),
		Color3.fromRGB(122, 120, 114),
		Enum.Material.Granite
	)
	local up = CFrame.Angles(0, 0, math.pi / 2) -- a Part cylinder's axis is its X
	local towerY = 5
	local segment = 16 -- 64-stud tower, 14 to 9.5 wide: reads from Calm Bay (a 9-wide one vanished at 450 studs)
	for i = 0, 3 do
		local height = 14 - i * 1.5
		part(
			model,
			`Tower{i + 1}`,
			Vector3.new(segment, height, height),
			CFrame.new(base + Vector3.new(0, towerY + segment * (i + 0.5), 0)) * up,
			if i % 2 == 0 then PAINT else Color3.fromRGB(172, 44, 38),
			Enum.Material.Plaster,
			Enum.PartType.Cylinder
		)
	end
	local lampY = base.Y + towerY + segment * 4 + 4
	local lens = part(
		model,
		"Lens",
		Vector3.new(10, 10, 10),
		CFrame.new(Vector3.new(x, lampY + 1.5, z)),
		Color3.fromRGB(214, 220, 212),
		Enum.Material.Glass,
		Enum.PartType.Ball
	)
	lens.CanCollide = false
	CollectionService:AddTag(lens, "LighthouseLens")
	local att = Instance.new("Attachment")
	att.Name = "ATT_Light"
	att.Parent = lens
	part(
		model,
		"Roof",
		Vector3.new(4, 14, 14),
		CFrame.new(Vector3.new(x, lampY + 8, z)) * up,
		Color3.fromRGB(172, 44, 38),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	local gallery = part(
		model,
		"Gallery",
		Vector3.new(1, 17, 17),
		CFrame.new(Vector3.new(x, lampY - 4, z)) * up,
		STEEL,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	gallery.CanCollide = false
	model.PrimaryPart = bottom
	model.WorldPivot = CFrame.new(base)
	CollectionService:AddTag(model, "Lighthouse")
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = Workspace
end

return SkerryLight
