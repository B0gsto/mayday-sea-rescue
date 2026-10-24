--!strict
-- PetsApp: the phone's Pets app (owner, 2026-10-24: "only 1 pet at a time"). A two-column grid of
-- big portraits: Bosun first, then every rescued pet (a live 3D ViewportFrame of the animal). Tap
-- one to make it the companion; the one out now wears a green tick. A pet still recovering is dimmed
-- with a meter and cannot be picked. Touch / mouse tap; keyboard and gamepad use the phone's
-- selection navigation (arrows / d-pad, Return / A).
--   PetsApp.mount(page: Frame) -> cleanup
--   PetsApp.icon(image: ImageLabel)   the home-screen tile until UiImages.Phone.Pets has art
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local PetRules = require(Shared:WaitForChild("PetRules"))
local WildlifeRig = require(Shared:WaitForChild("WildlifeRig"))

local Glyph = require(script.Parent:WaitForChild("Glyph"))
local HudTheme = require(script.Parent:WaitForChild("HudTheme"))
local PetController =
	require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("PetController"))

local player = Players.LocalPlayer
local C = HudTheme.Colors
local WHITE = Color3.new(1, 1, 1)
local GREEN = Color3.fromHex("30D158") -- iOS green, the "out now" tick
local ORANGE = Color3.fromHex("FF6B1A") -- Bosun's paw orange

type Card = { id: number, button: TextButton, tick: Frame, meter: Frame, fill: Frame, art: Frame }

local PetsApp = {}

local function dot(parent: Instance, size: Vector2, x: number, y: number, colour: Color3)
	Glyph.bar(parent, size, Vector2.new(x, y), 0, colour)
end

-- a paw print: one pad and four toes (scale units, fills a square parent)
local function paw(parent: Instance, colour: Color3)
	dot(parent, Vector2.new(0.42, 0.36), 0.5, 0.64, colour)
	dot(parent, Vector2.new(0.15, 0.17), 0.24, 0.42, colour)
	dot(parent, Vector2.new(0.15, 0.17), 0.4, 0.28, colour)
	dot(parent, Vector2.new(0.15, 0.17), 0.6, 0.28, colour)
	dot(parent, Vector2.new(0.15, 0.17), 0.76, 0.42, colour)
end

-- shortcut: a code-drawn tile, replace with UiImages.Phone.Pets once docs/18's icon is uploaded
function PetsApp.icon(image: ImageLabel)
	image.BackgroundTransparency = 0
	image.BackgroundColor3 = ORANGE
	HudTheme.corner(image, 15)
	local g = Instance.new("Frame")
	g.Name = "Paw"
	g.AnchorPoint = Vector2.new(0.5, 0.5)
	g.Position = UDim2.fromScale(0.5, 0.5)
	g.Size = UDim2.fromScale(0.62, 0.62)
	g.BackgroundTransparency = 1
	g.Parent = image
	paw(g, WHITE)
end

-- the portrait: a copy of the animal in a lit ViewportFrame, front three-quarter view
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
		local g = Instance.new("Frame")
		g.Size = UDim2.fromScale(0.6, 0.6)
		g.AnchorPoint = Vector2.new(0.5, 0.5)
		g.Position = UDim2.fromScale(0.5, 0.5)
		g.BackgroundTransparency = 1
		g.Parent = parent
		paw(g, WHITE)
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
	-- the animals face -Z: stand the camera ahead of the nose, a little to the side and above
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

local function petRows(): { any }
	local view = PetController.view()
	return if view then view.pets else {}
end

local function text(parent: Instance, value: string): TextLabel
	local l =
		HudTheme.label("Name", value, UDim2.new(1, -8, 0, 22), HudTheme.HeaderFont, 18, parent)
	l.AnchorPoint = Vector2.new(0.5, 1)
	l.Position = UDim2.new(0.5, 0, 1, -8)
	l.TextXAlignment = Enum.TextXAlignment.Center
	l.TextColor3 = WHITE
	l.TextScaled = false
	return l
end

function PetsApp.mount(page: Frame): () -> ()
	local conns: { RBXScriptConnection } = {}
	local cards: { Card } = {}
	local shape = ""

	local root = Instance.new("ScrollingFrame")
	root.Name = "Pets"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.ScrollBarThickness = 4
	root.ScrollingDirection = Enum.ScrollingDirection.Y
	root.CanvasSize = UDim2.new()
	root.AutomaticCanvasSize = Enum.AutomaticSize.Y
	root.Selectable = false
	root.Parent = page
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = root
	local layout = Instance.new("UIGridLayout")
	layout.CellPadding = UDim2.fromOffset(12, 12)
	layout.CellSize = UDim2.new(0.5, -12, 0, 150)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = root
	-- cells about 4:5 in the phone's design units (a 100 du probe reads the UIScale stack)
	local probe = Instance.new("Frame")
	probe.Size = UDim2.fromOffset(100, 0)
	probe.BackgroundTransparency = 1
	probe.Parent = page
	local function sizeCells()
		local du = math.max(probe.AbsoluteSize.X, 1) / 100
		local w = (root.AbsoluteSize.X / du - 12 - 12) / 2
		layout.CellSize = UDim2.new(0.5, -12, 0, math.floor(math.max(w, 80) * 1.2))
	end
	table.insert(conns, probe:GetPropertyChangedSignal("AbsoluteSize"):Connect(sizeCells))
	table.insert(conns, root:GetPropertyChangedSignal("AbsoluteSize"):Connect(sizeCells))
	sizeCells()

	local function newCard(id: number, order: number, label: string, model: Model?): Card
		local b = Instance.new("TextButton")
		b.Name = if id == PetRules.BOSUN then "Bosun" else `Pet{id}`
		b.Text = ""
		b.LayoutOrder = order
		b.AutoButtonColor = false
		b.Parent = root
		HudTheme.skin(b)
		local art = Instance.new("Frame")
		art.Name = "Art"
		art.AnchorPoint = Vector2.new(0.5, 0)
		art.Position = UDim2.fromScale(0.5, 0.06)
		art.Size = UDim2.new(0.86, 0, 1, -42)
		art.BackgroundColor3 = if id == PetRules.BOSUN then ORANGE else Color3.fromHex("2FA4E7")
		art.BackgroundTransparency = 0.6
		art.Parent = b
		HudTheme.corner(art, 16)
		portrait(art, model)
		text(b, label)

		local meter = Instance.new("Frame")
		meter.Name = "Meter"
		meter.AnchorPoint = Vector2.new(0.5, 1)
		meter.Position = UDim2.new(0.5, 0, 1, -40)
		meter.Size = UDim2.new(0.7, 0, 0, 8)
		meter.BackgroundColor3 = C.locked
		meter.Visible = false
		meter.Parent = b
		HudTheme.corner(meter, 4)
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = C.ready
		fill.Parent = meter
		HudTheme.corner(fill, 4)

		local tick = Instance.new("Frame")
		tick.Name = "Tick"
		tick.AnchorPoint = Vector2.new(1, 0)
		tick.Position = UDim2.new(1, -6, 0, 6)
		tick.Size = UDim2.fromOffset(30, 30)
		tick.BackgroundColor3 = GREEN
		tick.Visible = false
		tick.ZIndex = 3
		tick.Parent = b
		HudTheme.corner(tick, 99)
		local g = Instance.new("Frame")
		g.Size = UDim2.fromScale(1, 1)
		g.BackgroundTransparency = 1
		g.ZIndex = 3
		g.Parent = tick
		Glyph.draw("check", g, WHITE)

		local scale = Instance.new("UIScale")
		scale.Parent = b
		b.MouseButton1Down:Connect(function()
			scale.Scale = 0.95
		end)
		b.MouseButton1Up:Connect(function()
			scale.Scale = 1
		end)
		b.MouseLeave:Connect(function()
			scale.Scale = 1
		end)
		b.Activated:Connect(function()
			scale.Scale = 1
			local row = nil
			for _, r in petRows() do
				if r.id == id then
					row = r
				end
			end
			if id ~= PetRules.BOSUN and not (row and row.ready) then
				return -- still recovering
			end
			PetController.choose(id)
		end)
		return { id = id, button = b, tick = tick, meter = meter, fill = fill, art = art }
	end

	local function paint()
		local rows = petRows()
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
			card.art.BackgroundTransparency = if ready then 0.6 else 0.85
			local vp = card.art:FindFirstChild("Portrait")
			if vp and vp:IsA("ViewportFrame") then
				vp.ImageTransparency = if ready then 0 else 0.55
			end
		end
	end

	local function build()
		local rows = petRows()
		local key = ""
		for _, r in rows do
			key ..= `{r.id}:{r.species}:{r.rare};`
		end
		if key == shape and #cards > 0 then
			return paint()
		end
		shape = key
		for _, card in cards do
			card.button:Destroy()
		end
		table.clear(cards)
		local dog = Workspace:FindFirstChild("Bosun")
		local mine = dog and dog:FindFirstChild(`Bosun_{player.UserId}`)
		local name = mine and mine:GetAttribute("DogName")
		table.insert(
			cards,
			newCard(
				PetRules.BOSUN,
				0,
				if type(name) == "string" then name else "Bosun",
				bosunCopy()
			)
		)
		for i, r in rows do
			table.insert(cards, newCard(r.id, i, r.label, WildlifeRig.build(r.species, r.rare)))
		end
		paint()
	end

	table.insert(conns, PetController.onChange(build))
	table.insert(conns, player:GetAttributeChangedSignal("CompanionPet"):Connect(paint))
	build()

	return function()
		for _, c in conns do
			c:Disconnect()
		end
		probe:Destroy()
		root:Destroy()
	end
end

return PetsApp
