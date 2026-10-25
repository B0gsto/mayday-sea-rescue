--!strict
-- Companion panel: Bosun first, then every rescued pet. A live portrait, a recovery meter while a
-- pet is still at the sanctuary, and one tap to choose the companion (PetController.choose).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetRules = require(Shared:WaitForChild("PetRules"))
local WildlifeRig = require(Shared:WaitForChild("WildlifeRig"))

local Client = script.Parent.Parent.Parent
local PetController = require(Client:WaitForChild("Controllers"):WaitForChild("PetController"))

local Kit = script.Parent.Parent:WaitForChild("Kit")
local Panel = require(Kit:WaitForChild("Panel"))
local Style = require(Kit:WaitForChild("Style"))
local Theme = require(Kit:WaitForChild("Theme"))

local player = Players.LocalPlayer
local S = Theme.Size
local Companion = {}

local function portrait(parent: Frame, model: Model?)
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Portrait"
	vp.Size = UDim2.fromScale(1, 1)
	vp.BackgroundTransparency = 1
	vp.Ambient = Color3.fromRGB(150, 156, 170)
	vp.LightColor = Color3.fromRGB(255, 244, 228)
	vp.LightDirection = Vector3.new(-0.4, -1, -0.6)
	vp.Parent = parent
	if not model then
		local box = Instance.new("Frame")
		box.BackgroundTransparency = 1
		box.AnchorPoint = Vector2.new(0.5, 0.5)
		box.Position = UDim2.fromScale(0.5, 0.5)
		box.Size = UDim2.fromScale(0.6, 0.6)
		box.Parent = parent
		Style.icon(box, "companion")
		return vp
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = 0
			d.Anchored = true
		elseif d:IsA("BillboardGui") then
			d:Destroy()
		end
	end
	model.Parent = vp
	local box, size = model:GetBoundingBox()
	local reach = math.max(size.X, size.Y, size.Z)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	local eye = box * Vector3.new(reach * 0.7, reach * 0.45, -reach * 1.9)
	cam.CFrame = CFrame.lookAt(eye, box.Position)
	cam.Parent = vp
	vp.CurrentCamera = cam
	return vp
end

local function bosunCopy(): Model?
	local folder = Workspace:FindFirstChild("Bosun")
	local dog = folder and folder:FindFirstChild(`Bosun_{player.UserId}`)
	if not (dog and dog:IsA("Model")) then
		return nil
	end
	local old = dog.Archivable
	dog.Archivable = true
	local copy = dog:Clone()
	dog.Archivable = old
	return copy
end

function Companion.new(canvas: Frame, onClose: () -> ())
	local panel = Panel.new(canvas, {
		title = "Pet",
		icon = "companion",
		size = Vector2.new(720, 560),
		onClose = onClose,
	})
	local cards: { { id: number, root: ImageButton, tick: Frame, meter: Frame, fill: Frame } } = {}

	local function paint()
		local view = PetController.view()
		local rows: { any } = if view then view.pets else {}
		local current = player:GetAttribute("CompanionPet")
		for _, card in cards do
			local row = nil
			for _, r in rows do
				if r.id == card.id then
					row = r
				end
			end
			local ready = card.id == PetRules.BOSUN or (row ~= nil and row.ready)
			card.tick.Visible = if card.id == PetRules.BOSUN
				then current == nil
				else current == card.id
			card.meter.Visible = not ready
			card.fill.Size = UDim2.fromScale(if row then row.progress else 0, 1)
			card.root.Active = ready
			card.root.ImageTransparency = if ready then 0 else 0.35
		end
	end

	local function rebuild()
		for _, c in panel.body:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		table.clear(cards)
		local view = PetController.view()
		local rows: { any } = if view then view.pets else {}
		local host = Instance.new("Frame")
		host.BackgroundTransparency = 1
		host.Size = UDim2.fromScale(1, 0)
		host.AutomaticSize = Enum.AutomaticSize.Y
		host.Parent = panel.body
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.fromOffset(290, 190)
		grid.CellPadding = UDim2.fromOffset(12, 12)
		grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = host

		local entries = {
			{
				id = PetRules.BOSUN,
				label = "Bosun",
				model = bosunCopy(),
			},
		}
		for _, r in rows do
			table.insert(
				entries,
				{ id = r.id, label = r.label, model = WildlifeRig.build(r.species, r.rare) }
			)
		end
		for order, e in entries do
			local card = Style.button(host, UDim2.fromOffset(290, 190))
			card.Name = "Companion_" .. e.id
			card.LayoutOrder = order
			local _, face =
				Style.block(card, Style.grad(if e.id == PetRules.BOSUN then "orange" else "teal"))
			local art = Instance.new("Frame")
			art.BackgroundColor3 = Color3.new(1, 1, 1)
			art.BackgroundTransparency = 0.72
			art.Position = UDim2.fromOffset(12, 12)
			art.Size = UDim2.fromOffset(130, 150)
			Style.corner(art, S.cornerSmall)
			art.Parent = face
			portrait(art, e.model)
			local name = Style.label(face, e.label, Theme.Text.heading)
			name.Position = UDim2.fromOffset(154, 16)
			name.Size = UDim2.new(1, -166, 0, 40)
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.TextWrapped = false
			name.TextTruncate = Enum.TextTruncate.AtEnd
			local hint = Style.label(
				face,
				if e.id == PetRules.BOSUN then "First mate" else "Companion",
				Theme.Text.small
			)
			hint.Position = UDim2.fromOffset(154, 58)
			hint.Size = UDim2.new(1, -166, 0, 28)
			hint.TextXAlignment = Enum.TextXAlignment.Left
			local tick = Instance.new("Frame")
			tick.AnchorPoint = Vector2.new(1, 1)
			tick.Position = UDim2.new(1, -12, 1, -12)
			tick.Size = UDim2.fromOffset(44, 44)
			tick.BackgroundTransparency = 1
			tick.Visible = false
			tick.Parent = face
			Style.icon(tick, "daily")
			local meter = Instance.new("Frame")
			meter.AnchorPoint = Vector2.new(0, 1)
			meter.Position = UDim2.new(0, 154, 1, -26)
			meter.Size = UDim2.new(1, -210, 0, 14)
			meter.BackgroundColor3 = Theme.Colors.ink
			meter.Visible = false
			meter.Parent = face
			Style.corner(meter, 7)
			local fill = Instance.new("Frame")
			fill.Size = UDim2.fromScale(0, 1)
			fill.BackgroundColor3 = Theme.Grad.buy.bottom
			fill.Parent = meter
			Style.corner(fill, 7)
			Style.press(card, function()
				local row = nil
				for _, r in rows do
					if r.id == e.id then
						row = r
					end
				end
				if e.id ~= PetRules.BOSUN and not (row and row.ready) then
					return
				end
				PetController.choose(e.id)
			end)
			table.insert(cards, { id = e.id, root = card, tick = tick, meter = meter, fill = fill })
		end
		paint()
	end

	rebuild()
	PetController.onChange(function()
		if panel.isOpen() then
			rebuild()
		end
	end)
	player:GetAttributeChangedSignal("CompanionPet"):Connect(function()
		if panel.isOpen() then
			paint()
		end
	end)

	return {
		open = function()
			panel.open()
			rebuild()
		end,
		close = panel.close,
		isOpen = panel.isOpen,
		root = panel.root,
	}
end

return Companion
