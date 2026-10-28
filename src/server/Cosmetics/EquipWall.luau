--!strict
-- EquipWall (server cosmetic feature, G28): the station livery wall by the spawn. Five swatch
-- panels (Livery, Decal, Wake, Light bar, Title) each carry a ProximityPrompt that cycles the
-- player's owned options for that slot and equips the next one through CosmeticsService (earned
-- rewards included; in-world shop context, no menu). Everything is code-built and non-colliding.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))

local NAME = "StationLiveryWall"
local AT = Vector3.new(-52, 4, -14)
local FACING = 0 -- front faces +Z, toward the spawn

local SLOTS = {
	{
		slot = "Livery",
		label = "Paint",
		color = Color3.fromRGB(214, 86, 20),
		accent = Color3.fromRGB(38, 40, 44),
	},
	{
		slot = "Decal",
		label = "Decal",
		color = Color3.fromRGB(30, 60, 88),
		accent = Color3.fromRGB(214, 170, 74),
	},
	{
		slot = "Wake",
		label = "Wake",
		color = Color3.fromRGB(40, 150, 142),
		accent = Color3.fromRGB(226, 236, 232),
	},
	{
		slot = "LightBar",
		label = "Lights",
		color = Color3.fromRGB(28, 82, 255),
		accent = Color3.fromRGB(232, 238, 255),
	},
	{
		slot = "Title",
		label = "Title",
		color = Color3.fromRGB(44, 86, 120),
		accent = Color3.fromRGB(214, 170, 74),
	},
}

local EquipWall = {}
EquipWall.Priority = 40

local service: any = nil

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function cycle(player: Player, slot: string)
	local current = service.Equipped(player, slot)
	local id = Cosmetics.cycle(slot, current, function(key: string): boolean
		return service.Owns(player, key)
	end, 1)
	if id and id ~= current then
		service.Equip(player, slot, id)
	end
end

local function build()
	if Workspace:FindFirstChild(NAME) then
		return
	end
	local hit = Workspace:Raycast(AT + Vector3.new(0, 20, 0), Vector3.new(0, -40, 0))
	local y = if hit then hit.Position.Y else AT.Y
	local at = CFrame.new(AT.X, y, AT.Z) * CFrame.Angles(0, FACING, 0)

	local model = Instance.new("Model")
	model.Name = NAME
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	local board = part(
		model,
		"Board",
		Vector3.new(8.4, 4.4, 0.35),
		at * CFrame.new(0, 2.6, 0),
		Color3.fromRGB(42, 52, 58),
		Enum.Material.WoodPlanks
	)
	model.PrimaryPart = board
	part(
		model,
		"Shelf",
		Vector3.new(8.8, 0.18, 1.1),
		at * CFrame.new(0, 0.55, 0.35),
		Color3.fromRGB(96, 66, 42),
		Enum.Material.Wood
	)
	for _, x in { -4.3, 4.3 } do
		part(
			model,
			"Post",
			Vector3.new(0.24, 5.6, 0.24),
			at * CFrame.new(x, 2.8, 0),
			Color3.fromRGB(96, 66, 42),
			Enum.Material.Wood
		)
	end
	part(
		model,
		"Lamp",
		Vector3.new(8.0, 0.16, 0.16),
		at * CFrame.new(0, 4.9, 0.25),
		Color3.fromRGB(255, 238, 200),
		Enum.Material.Neon
	)

	for i, entry in SLOTS do
		local x = (i - 3) * 1.55
		part(
			model,
			"Panel" .. entry.slot,
			Vector3.new(1.24, 1.7, 0.14),
			at * CFrame.new(x, 2.7, 0.24),
			entry.color,
			Enum.Material.SmoothPlastic
		)
		part(
			model,
			"Stripe" .. entry.slot,
			Vector3.new(1.24, 0.28, 0.16),
			at * CFrame.new(x, 2.04, 0.25), -- bottom 0.05 over the panel's (2.0 left 0.01)
			entry.accent,
			Enum.Material.SmoothPlastic
		)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Equip_" .. entry.slot
		prompt.ActionText = entry.label
		prompt.ObjectText = "Livery wall"
		prompt.HoldDuration = 0.15
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.UIOffset = Vector2.new(0, (i - 3) * 42)
		prompt.Triggered:Connect(function(player: Player)
			cycle(player, entry.slot)
		end)
		prompt.Parent = board
	end

	model.Parent = Workspace
end

function EquipWall.Init(cosmeticsService: any)
	service = cosmeticsService
end

function EquipWall.Start()
	task.spawn(build)
end

return EquipWall
