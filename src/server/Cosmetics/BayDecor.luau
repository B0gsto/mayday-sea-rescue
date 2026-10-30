--!strict
-- BayDecor (server cosmetic feature, G28): every owned bay decoration is placed at a fixed slot
-- on the player's own jetty at the marina (DockService berth frame, docs/23 d.2). Decor keys come from CosmeticLoadout.decor
-- (stock decor_*); parts are code-built, anchored and non-colliding.
-- Rebuilt when the earned flags change ("CosOwned"), removed on leave.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CosmeticLoadout = require(Shared:WaitForChild("CosmeticLoadout"))

local Services = script.Parent.Parent:WaitForChild("Services")
local DataService = require(Services:WaitForChild("DataService"))
local DockService = require(Services:WaitForChild("DockService"))

local NAME = "BayDecor"
-- G38: one tidy row along the jetty finger's water edge (Marina.JETTY x -17..-9), 2.5 studs apart, max 8,
-- between the returning player's spot and the quay. The pieces face the berth; nothing is stacked.
local SLOTS = {}
for i = 1, 8 do
	table.insert(SLOTS, Vector3.new(-10.5, 0, 8 + (i - 1) * 2.5))
end
local FACE_WATER = CFrame.Angles(0, -math.pi / 2, 0)
local WOOD = Color3.fromRGB(112, 84, 58)
local IRON = Color3.fromRGB(54, 58, 62)
local GREEN = Color3.fromRGB(54, 106, 62)
local CREW_BLUE = Color3.fromRGB(38, 68, 112)
local BRASS = Color3.fromRGB(226, 186, 96)

local BayDecor = {}
BayDecor.Priority = 80

local models: { [Player]: Model } = {}

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
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function lantern(model: Model, at: CFrame)
	part(
		model,
		"Post",
		Vector3.new(0.18, 3.2, 0.18),
		at * CFrame.new(0, 1.6, 0),
		WOOD,
		Enum.Material.Wood
	)
	local lamp = part(
		model,
		"Lantern",
		Vector3.new(0.62, 0.78, 0.62),
		at * CFrame.new(0, 3.1, 0),
		Color3.fromRGB(244, 198, 118),
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(250, 206, 140)
	light.Brightness = 1.6
	light.Range = 12
	light.Shadows = false
	light.Parent = lamp
	part(
		model,
		"Cap",
		Vector3.new(0.36, 0.12, 0.36),
		at * CFrame.new(0, 3.54, 0),
		IRON,
		Enum.Material.Metal
	)
end

local function bell(model: Model, at: CFrame)
	part(
		model,
		"Post",
		Vector3.new(0.16, 2.5, 0.16),
		at * CFrame.new(0, 1.25, 0),
		WOOD,
		Enum.Material.Wood
	)
	part(
		model,
		"Bracket",
		Vector3.new(0.9, 0.12, 0.12),
		at * CFrame.new(0.35, 2.45, 0),
		IRON,
		Enum.Material.Metal
	)
	part(
		model,
		"Bell",
		Vector3.new(0.72, 0.72, 0.72),
		at * CFrame.new(0.75, 2.1, 0),
		Color3.fromRGB(214, 170, 82),
		Enum.Material.Metal,
		Enum.PartType.Ball
	)
	part(
		model,
		"Clapper",
		Vector3.new(0.16, 0.16, 0.16),
		at * CFrame.new(0.75, 1.72, 0),
		IRON,
		Enum.Material.Metal,
		Enum.PartType.Ball
	)
end

local function wreath(model: Model, at: CFrame)
	part(
		model,
		"Stand",
		Vector3.new(0.16, 2.2, 0.16),
		at * CFrame.new(0, 1.1, 0),
		WOOD,
		Enum.Material.Wood
	)
	local centre = at * CFrame.new(0, 2.1, 0)
	for i = 0, 7 do
		local a = i * math.pi / 4
		part(
			model,
			"Leaf",
			Vector3.new(0.34, 0.34, 0.34),
			centre * CFrame.new(math.cos(a) * 0.62, math.sin(a) * 0.62, 0),
			GREEN,
			Enum.Material.Grass,
			Enum.PartType.Ball
		)
	end
	for i = 0, 2 do
		local a = i * 2.1
		part(
			model,
			"Berry",
			Vector3.new(0.16, 0.16, 0.16),
			centre * CFrame.new(math.cos(a) * 0.62, math.sin(a) * 0.62, 0.16),
			Color3.fromRGB(168, 46, 44),
			Enum.Material.SmoothPlastic,
			Enum.PartType.Ball
		)
	end
end

local function flag(model: Model, at: CFrame)
	part(
		model,
		"Pole",
		Vector3.new(0.16, 4.6, 0.16),
		at * CFrame.new(0, 2.3, 0),
		WOOD,
		Enum.Material.Wood
	)
	part(
		model,
		"Flag",
		Vector3.new(1.9, 1.15, 0.06),
		at * CFrame.new(1.02, 3.8, 0),
		Color3.fromRGB(176, 54, 50),
		Enum.Material.Fabric
	)
	part(
		model,
		"Hoist",
		Vector3.new(0.1, 1.15, 0.16), -- 0.05 proud of the flag's faces (0.08 left 0.01)
		at * CFrame.new(0.08, 3.8, 0),
		Color3.fromRGB(236, 228, 208),
		Enum.Material.Fabric
	)
end

local function crew(model: Model, at: CFrame)
	part(
		model,
		"Pole",
		Vector3.new(0.16, 4.8, 0.16),
		at * CFrame.new(0, 2.4, 0),
		WOOD,
		Enum.Material.Wood
	)
	part(
		model,
		"Pennant",
		Vector3.new(1.75, 1.05, 0.06),
		at * CFrame.new(0.95, 4.1, 0),
		CREW_BLUE,
		Enum.Material.Fabric
	)
	part(
		model,
		"Hoist",
		Vector3.new(0.12, 1.05, 0.16), -- 0.05 proud of the flag's faces (0.08 left 0.01)
		at * CFrame.new(0.12, 4.1, 0),
		BRASS,
		Enum.Material.Fabric
	)
	part(
		model,
		"Mark",
		Vector3.new(0.46, 0.46, 0.08),
		at * CFrame.new(0.98, 4.1, 0),
		BRASS,
		Enum.Material.Metal,
		Enum.PartType.Ball
	)
	part(
		model,
		"Ball",
		Vector3.new(0.18, 0.18, 0.18),
		at * CFrame.new(0, 4.85, 0),
		BRASS,
		Enum.Material.Metal,
		Enum.PartType.Ball
	)
end

local function shelf(model: Model, at: CFrame)
	for _, x in { -0.9, 0.9 } do
		part(
			model,
			"Post",
			Vector3.new(0.18, 2.1, 0.18),
			at * CFrame.new(x, 1.05, 0),
			WOOD,
			Enum.Material.Wood
		)
	end
	part(
		model,
		"Shelf",
		Vector3.new(2.2, 0.16, 0.85),
		at * CFrame.new(0, 2.05, 0),
		Color3.fromRGB(168, 142, 108),
		Enum.Material.Wood
	)
	part(
		model,
		"Pot",
		Vector3.new(0.52, 0.44, 0.52),
		at * CFrame.new(-0.5, 2.34, 0),
		Color3.fromRGB(150, 82, 58),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	for i = 0, 3 do
		local a = i * math.pi / 2
		part(
			model,
			"Leaf",
			Vector3.new(0.52, 0.7, 0.18),
			at * CFrame.new(-0.5 + math.cos(a) * 0.16, 2.76, math.sin(a) * 0.16),
			GREEN,
			Enum.Material.Grass
		)
	end
	part(
		model,
		"Bottle",
		Vector3.new(0.3, 0.8, 0.3),
		at * CFrame.new(0.55, 2.52, 0),
		Color3.fromRGB(70, 96, 94),
		Enum.Material.Glass,
		Enum.PartType.Cylinder
	)
end

local function signals(model: Model, at: CFrame)
	for _, x in { -0.9, 0.9 } do
		part(
			model,
			"Pole",
			Vector3.new(0.14, 3.4, 0.14),
			at * CFrame.new(x, 1.7, 0),
			WOOD,
			Enum.Material.Wood
		)
	end
	local palette = {
		Color3.fromRGB(66, 96, 148),
		Color3.fromRGB(214, 186, 92),
		Color3.fromRGB(226, 222, 208),
		Color3.fromRGB(104, 142, 110),
	}
	for i = 1, 4 do
		part(
			model,
			"Signal",
			Vector3.new(0.66, 0.72, 0.06),
			at * CFrame.new(-0.62 + (i - 1) * 0.42, 3.0 - (i % 2) * 0.3, 0),
			palette[i],
			Enum.Material.Fabric
		)
	end
	part(
		model,
		"Line",
		Vector3.new(1.95, 0.05, 0.05),
		at * CFrame.new(0, 3.3, 0),
		IRON,
		Enum.Material.SmoothPlastic
	)
end

local BUILD: { [string]: (Model, CFrame) -> () } = {
	["stock:decor_lantern"] = lantern,
	["stock:decor_bell"] = bell,
	["stock:decor_wreath"] = wreath,
	["stock:decor_flag"] = flag,
	["stock:decor_shelf"] = shelf,
	["stock:decor_signals"] = signals,
	["group:crew"] = crew,
}

local function remove(player: Player)
	local old = models[player]
	if old then
		old:Destroy()
		models[player] = nil
	end
end

local function build(player: Player)
	remove(player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local keys = CosmeticLoadout.show(data.flags).decor
	if #keys == 0 then
		return
	end
	local bay = DockService.GetBerth(player)
	if not bay then
		return -- no island (full server): nowhere to stand the decor
	end
	local origin = bay.CFrame
	local model = Instance.new("Model")
	model.Name = NAME
	for i, key in keys do
		local make = BUILD[key]
		local slot = SLOTS[i]
		if make and slot then
			local base = origin * CFrame.new(slot.X, 0, slot.Z)
			local hit =
				Workspace:Raycast(base.Position + Vector3.new(0, 20, 0), Vector3.new(0, -40, 0))
			local y = if hit then hit.Position.Y else origin.Y + 3
			local at = CFrame.new(base.Position.X, y, base.Position.Z)
				* origin.Rotation
				* FACE_WATER
			part(
				model,
				"Pad",
				Vector3.new(2.2, 0.12, 2.2),
				at * CFrame.new(0, 0.06, 0),
				WOOD,
				Enum.Material.Wood
			)
			make(model, at * CFrame.new(0, 0.14, 0))
		end
	end
	model:SetAttribute("Owner", player.UserId)
	model.Parent = Workspace
	models[player] = model
end

function BayDecor.Init() end

local ownedHooks: { [Player]: RBXScriptConnection } = {}

function BayDecor.Start()
	DataService.OnLoaded(function(player: Player)
		build(player)
		if ownedHooks[player] then -- a reload (DataDev "rejoin") must not stack a second hook
			ownedHooks[player]:Disconnect()
		end
		ownedHooks[player] = player:GetAttributeChangedSignal("CosOwned"):Connect(function()
			build(player)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		ownedHooks[player] = nil
		remove(player)
	end)
end

return BayDecor
