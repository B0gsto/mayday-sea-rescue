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
local PriceButton = require(Kit:WaitForChild("PriceButton"))
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
	local cards: { { id: number, root: ImageButton, button: PriceButton.PriceButton, meter: Frame, fill: Frame } } =
		{}

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
			local on = if card.id == PetRules.BOSUN then current == nil else current == card.id
			-- worn: blue + gold tick; ready: green "Use"; recovering: the meter in the button's place
			card.button.setState(if on then "owned" else "buy")
			card.button.setText(if on then "Active" else "Use")
			card.button.root.Visible = ready
			local glyph = card.button.root:FindFirstChild("Glyph", true)
			if glyph and glyph:IsA("GuiObject") then
				glyph.Visible = on
			end
			card.meter.Visible = not ready
			card.fill.Size = UDim2.fromScale(if row then row.progress else 0, 1)
			card.root.Active = ready
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
		-- spin-wheel looks (docs/24 D): owned variants, one tap to wear one
		local look = Instance.new("Frame")
		look.Name = "PetVariantPicker"
		look.BackgroundTransparency = 1
		look.Size = UDim2.fromScale(1, 0) + UDim2.fromOffset(0, 56)
		look.Parent = panel.body
		local lookList = Style.list(look, true, 8)
		lookList.HorizontalAlignment = Enum.HorizontalAlignment.Center
		local owned = {}
		local variantIds: { string } = if view then view.variants else {}
		for _, id in variantIds do
			owned[id] = true
		end
		local chips: { { id: string?, label: string, color: string } } =
			{ { id = nil, label = "Natural", color = "disabled" } }
		for _, id in { "Golden", "Neon", "Rainbow", "Galaxy" } do
			table.insert(chips, { id = id, label = id, color = "purple" })
		end
		for _, chip in chips do
			local ready = chip.id == nil or owned[chip.id] == true
			-- scale-to-fit: the chips share the row, so all 5 fit the narrowest panel
			local button = Style.button(look, UDim2.new(1 / #chips, -8 + 8 / #chips, 0, 52))
			button.Name = "Variant_" .. (chip.id or "None")
			local _, face = Style.block(
				button,
				Style.grad(if ready then chip.color else "disabled"),
				{ lip = 4, radius = S.cornerSmall }
			)
			local text = Style.label(face, chip.label, Theme.Text.small)
			text.AnchorPoint = Vector2.new(0.5, 0.5)
			text.Position = UDim2.fromScale(0.5, 0.5)
			text.Size = UDim2.new(1, -10, 1, -8)
			text.TextScaled = true
			button.Active = ready
			Style.press(button, function()
				if ready then
					PetController.chooseVariant(chip.id)
				end
			end, S.cornerSmall)
			if (view and view.variant) == chip.id then
				local tick = Instance.new("Frame")
				tick.AnchorPoint = Vector2.new(1, 0)
				tick.Position = UDim2.new(1, -6, 0, 4)
				tick.Size = UDim2.fromOffset(18, 18)
				tick.BackgroundTransparency = 1
				tick.Parent = face
				Style.icon(tick, "daily")
			end
		end
		local host = Instance.new("Frame")
		host.Name = "Pets"
		host.BackgroundTransparency = 1
		host.LayoutOrder = 1
		host.Size = UDim2.fromScale(1, 0)
		host.AutomaticSize = Enum.AutomaticSize.Y
		host.Parent = panel.body
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.new(0.5, -6, 0, 300)
		grid.CellPadding = UDim2.fromOffset(12, 12)
		grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = host

		local entries = {
			{
				id = PetRules.BOSUN,
				label = "Bosun",
				rare = true,
				model = bosunCopy(),
			},
		}
		for _, r in rows do
			table.insert(entries, {
				id = r.id,
				label = r.label,
				rare = r.rare,
				model = WildlifeRig.build(r.species, r.rare),
			})
		end
		for order, e in entries do
			local card = Style.button(host, UDim2.new())
			card.Name = "Companion_" .. e.id
			card.LayoutOrder = order
			local rare = e.id == PetRules.BOSUN or e.rare == true
			local _, face = Style.block(
				card,
				Style.grad(
					if e.id == PetRules.BOSUN then "orange" elseif rare then "purple" else "teal"
				)
			)
			-- the portrait well: a gold rim for rare pets (and Bosun), white for the rest
			local art = Instance.new("Frame")
			art.BackgroundColor3 = Color3.new(1, 1, 1)
			art.BackgroundTransparency = 0.6
			art.Position = UDim2.fromOffset(12, 12)
			art.Size = UDim2.new(1, -24, 1, -134)
			Style.corner(art, S.cornerSmall)
			local rim = Instance.new("UIStroke")
			rim.Thickness = 4
			rim.Color = if rare then Color3.fromHex("FFC928") else Color3.new(1, 1, 1)
			rim.Parent = art
			art.Parent = face
			portrait(art, e.model)
			local name = Style.label(face, e.label, Theme.Text.heading)
			name.AnchorPoint = Vector2.new(0.5, 1)
			name.Position = UDim2.new(0.5, 0, 1, -82)
			name.Size = UDim2.new(1, -24, 0, 38)
			name.TextWrapped = false
			name.TextTruncate = Enum.TextTruncate.AtEnd
			local function choose()
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
			end
			local button =
				PriceButton.new(face, { price = 0, currency = "Cash", onActivate = choose })
			button.root.AnchorPoint = Vector2.new(0.5, 1)
			button.root.Position = UDim2.new(0.5, 0, 1, -10)
			button.root.Size = UDim2.new(1, -24, 0, 64)
			local meter = Instance.new("Frame")
			meter.AnchorPoint = Vector2.new(0.5, 1)
			meter.Position = UDim2.new(0.5, 0, 1, -32)
			meter.Size = UDim2.new(1, -48, 0, 20)
			meter.BackgroundColor3 = Theme.Colors.ink
			meter.Visible = false
			meter.Parent = face
			Style.corner(meter, 10)
			local fill = Instance.new("Frame")
			fill.Size = UDim2.fromScale(0, 1)
			fill.BackgroundColor3 = Theme.Grad.buy.bottom
			fill.Parent = meter
			Style.corner(fill, 10)
			Style.press(card, choose)
			table.insert(
				cards,
				{ id = e.id, root = card, button = button, meter = meter, fill = fill }
			)
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
