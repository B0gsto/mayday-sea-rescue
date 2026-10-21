--!strict
-- Decals (server cosmetic feature, G28): the earned hull-side badge (slot "Decal",
-- src/shared/Config/Cosmetics/Decal.luau) on the owner's boat. Code-made: a thin plate welded just
-- outside each side of the hull with a SurfaceGui roundel and a 1-2 character mark (no uploads).
-- Applied on VehicleSpawned and on the Decal choice change; "None" removes it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local LiveryPaint = require(Shared:WaitForChild("LiveryPaint"))

local SLOT = "Decal"
local NAME = "CosmeticDecal"
local PLATE = Vector3.new(0.07, 1.55, 3.8)

local Decals = {}
Decals.Priority = 90

local service: any = nil
local vehicles: { [Player]: { [Model]: boolean } } = {}

local function hullOf(model: Model): BasePart?
	-- the RIB's tubes are the side above the waterline (the GRP hull is mostly submerged)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and string.find(d.Name, "Tubes") then
			local rule = LiveryPaint.meshRule(d.Name)
			if rule and rule.role == "primary" then
				return d
			end
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and string.find(d.Name, "Hull") then
			local rule = LiveryPaint.meshRule(d.Name)
			if rule and (rule.role == "secondary" or rule.role == "primary") then
				return d
			end
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local role = LiveryPaint.attrRole(d:GetAttribute("Paint"))
			if role == "secondary" or (role == "primary" and string.find(d.Name, "Hull")) then
				return d
			end
		end
	end
	return nil
end

local function plate(parent: Model, hull: BasePart, side: number, option: any): Part
	local size = hull.Size
	local at = hull.CFrame
		* CFrame.new(side * (size.X / 2 + PLATE.X / 2 + 0.02), size.Y * 0.04, -size.Z * 0.02)
	local p = Instance.new("Part")
	p.Name = if side > 0 then "BadgeRight" else "BadgeLeft"
	p.Size = PLATE
	p.CFrame = at
	p.Color = option.color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.Parent = parent
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hull
	weld.Part1 = p
	weld.Parent = p

	-- physical roundel: a painted badge that reads even where a SurfaceGui is culled
	local outward = p.CFrame.RightVector * side
	local roundels = {
		{ thickness = 0.09, diameter = 1.05, color = option.ring },
		{ thickness = 0.12, diameter = 0.76, color = option.markColor },
	}
	for _, spec in roundels do
		local disc = Instance.new("Part")
		disc.Name = "Roundel"
		disc.Shape = Enum.PartType.Cylinder
		disc.Size = Vector3.new(spec.thickness, spec.diameter, spec.diameter)
		disc.CFrame = p.CFrame + outward * (0.06 + spec.thickness / 2)
		disc.Color = spec.color
		disc.Material = Enum.Material.SmoothPlastic
		disc.Anchored = false
		disc.CanCollide = false
		disc.CanQuery = false
		disc.CanTouch = false
		disc.Massless = true
		disc.CastShadow = false
		disc.Parent = parent
		local discWeld = Instance.new("WeldConstraint")
		discWeld.Part0 = p
		discWeld.Part1 = disc
		discWeld.Parent = disc
	end

	local gui = Instance.new("SurfaceGui")
	gui.Face = if side > 0 then Enum.NormalId.Right else Enum.NormalId.Left
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true -- the hull mesh can sit proud of its bounding box; the badge stays legible
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 70
	gui.MaxDistance = 250
	gui.Parent = p

	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.44, 0.5)
	ring.Size = UDim2.fromScale(0.7, 0.9)
	ring.BackgroundColor3 = option.ring
	ring.BorderSizePixel = 0
	ring.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = ring

	local mark = Instance.new("TextLabel")
	mark.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.Position = UDim2.fromScale(0.5, 0.5)
	mark.Size = UDim2.fromScale(0.76, 0.74)
	mark.BackgroundTransparency = 1
	mark.Font = Enum.Font.GothamBold
	mark.TextScaled = true
	mark.Text = option.mark
	mark.TextColor3 = option.markColor
	mark.Parent = ring

	local stripe = Instance.new("Frame")
	stripe.Position = UDim2.fromScale(0.82, 0.24)
	stripe.Size = UDim2.fromScale(0.14, 0.52)
	stripe.BackgroundColor3 = option.ring
	stripe.BorderSizePixel = 0
	stripe.Parent = gui
	return p
end

function Decals.apply(model: Model, id: string?)
	local old = model:FindFirstChild(NAME)
	if old then
		old:Destroy()
	end
	local option = if id then Cosmetics.option(SLOT, id) else nil
	if not option or type(option.mark) ~= "string" then
		return
	end
	local hull = hullOf(model)
	if not hull then
		return
	end
	local badge = Instance.new("Model")
	badge.Name = NAME
	plate(badge, hull, 1, option)
	plate(badge, hull, -1, option)
	badge.Parent = model
end

local function track(player: Player, model: Model)
	local set = vehicles[player]
	if not set then
		set = {}
		vehicles[player] = set
	end
	set[model] = true
	model.Destroying:Connect(function()
		local mine = vehicles[player]
		if mine then
			mine[model] = nil
		end
	end)
	local id = service.Equipped(player, SLOT)
	Decals.apply(model, id)
	task.defer(function()
		if model.Parent then
			Decals.apply(model, service.Equipped(player, SLOT))
		end
	end)
end

function Decals.Init(s: any)
	service = s
end

function Decals.Start()
	service.VehicleSpawned:Connect(function(player: Player, model: Model, _kind: string?)
		if player and model then
			track(player, model)
		end
	end)
	service.Changed:Connect(function(player: Player, slot: string, id: string)
		if slot ~= SLOT then
			return
		end
		for model in (vehicles[player] or {}) :: { [Model]: boolean } do
			if model.Parent then
				Decals.apply(model, id)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		vehicles[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		local model = service.VehicleOf(player)
		if model then
			track(player, model)
		end
	end
end

return Decals
