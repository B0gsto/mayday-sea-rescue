--!strict
-- StockController: the rotating Chandlery stock display and its clock (docs/15 hook H3).
-- StockService publishes the shared 10-minute window; this controller builds a local shelf rack above
-- the Chandlery counter (at the ShopCounter prompt) with one slot per rolled item, a price tag, and a
-- ProximityPrompt on each item (E / X / tap: keyboard, gamepad, touch). Above it a clock board shows
-- the clock icon and `7:42` until the restock. A new window rings the brass bell and the shelves pop
-- back in. Stock counts are live for everyone; per-player limits show as LIMIT on the tag.
--
-- Remotes (under ReplicatedStorage.Net, created by StockService): Stock_State, Stock_Get, Stock_Buy.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioController = require(script.Parent.AudioController)
local StockConfig = require(Shared:WaitForChild("Config"):WaitForChild("StockConfig"))
local StockRotation = require(Shared:WaitForChild("StockRotation"))

local StockController = {}
StockController.Priority = 87

local BOARD_WIDTH = 13
local BOARD_Z = -2.9 -- behind the counter prompt
local ROWS = { 0.35, 1.95 } -- shelf ledges above the counter attachment
local COLS = { -4.5, -1.5, 1.5, 4.5 }
local WOOD = Color3.fromRGB(96, 66, 42)
local FACE = Color3.fromRGB(30, 40, 48)
local INK = Color3.fromRGB(242, 236, 218)
local GOLD = Color3.fromRGB(246, 206, 96)

type ItemView = {
	slot: number,
	model: Model,
	parts: { BasePart },
	body: BasePart,
	prompt: ProximityPrompt,
	nameLabel: TextLabel,
	priceLabel: TextLabel,
	countLabel: TextLabel,
	status: string?,
}

local stateRemote: RemoteEvent? = nil
local getFn: RemoteFunction? = nil
local buyFn: RemoteFunction? = nil
local shelf: Model? = nil
local base = Vector3.zero
local clockLabel: TextLabel? = nil
local bell: BasePart? = nil
local bellPivot: CFrame? = nil
local itemViews: { ItemView } = {}
local lastWindow: number? = nil
local deadline = 0
local nextPull = 0
local shownTime = ""
local flashUntil = 0
local buying = false
local pendingView: { [string]: any }? = nil

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

local function textLabel(
	parent: Instance,
	name: string,
	pos: UDim2,
	size: UDim2,
	font: Enum.Font,
	textSize: number,
	color: Color3
): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Position = pos
	l.Size = size
	l.BackgroundTransparency = 1
	l.Font = font
	l.TextSize = textSize
	l.TextColor3 = color
	l.Text = ""
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.Parent = parent
	return l
end

local function frame(parent: Instance, name: string, pos: UDim2, size: UDim2, color: Color3): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Position = pos
	f.Size = size
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function flash(text: string)
	local label = clockLabel
	if not label then
		return
	end
	flashUntil = os.clock() + 1.6
	shownTime = ""
	label.Text = text
	label.TextColor3 = Color3.fromRGB(244, 128, 112)
end

local function requestBuy(slot: number)
	if buying then
		return
	end
	local fn = buyFn
	if not fn then
		return
	end
	buying = true
	task.spawn(function()
		local ok, bought, reason = pcall(function()
			return fn:InvokeServer(slot)
		end)
		buying = false
		if not ok then
			flash("SHOP OFFLINE")
		elseif bought then
			AudioController.play("Chandlery_Till", base + Vector3.new(0, 1.5, BOARD_Z + 1), 1, 1)
		else
			flash(string.upper(tostring(reason or "CAN'T BUY")))
		end
	end)
end

local function swingBell()
	local b, pivot = bell, bellPivot
	if not (b and pivot) then
		return
	end
	task.spawn(function()
		for i = 1, 4 do
			local angle = if i % 2 == 1 then 0.38 else -0.3
			TweenService:Create(b, TweenInfo.new(0.18, Enum.EasingStyle.Sine), {
				CFrame = pivot * CFrame.Angles(0, 0, angle) * CFrame.new(0, -0.65, 0),
			}):Play()
			task.wait(0.2)
		end
		TweenService:Create(b, TweenInfo.new(0.25), {
			CFrame = pivot * CFrame.new(0, -0.65, 0),
		}):Play()
	end)
end

local function ringRestock()
	AudioController.play("Chandlery_Bell", base + Vector3.new(0, 5, BOARD_Z), 1, 1)
	swingBell()
end

local function clearItems()
	for _, view in itemViews do
		if view.model.Parent then
			view.model:Destroy()
		end
	end
	table.clear(itemViews)
end

local function itemStatus(view: { [string]: any }): string?
	if view.mine >= view.limit then
		return "LIMIT"
	elseif view.remaining <= 0 then
		return "SOLD"
	end
	return nil
end

local function paintTag(view: ItemView, entry: { [string]: any })
	view.nameLabel.Text = entry.name
	view.priceLabel.Text = tostring(entry.price)
	view.countLabel.Text = `x{entry.remaining}`
	view.status = itemStatus(entry)
	if view.status == "LIMIT" then
		view.priceLabel.Text = "LIMIT"
	elseif view.status == "SOLD" then
		view.priceLabel.Text = "SOLD"
	end
	view.priceLabel.TextColor3 = if view.status then Color3.fromRGB(150, 150, 146) else GOLD
	local dim = view.status ~= nil
	view.body.Transparency = if dim then 0.55 else 0
	view.prompt.Enabled = not dim
end

local function buildItem(entry: { [string]: any }, index: number)
	local item = StockConfig.Items[entry.id]
	if not item or not shelf then
		return
	end
	local row = if index <= 4 then 1 else 2
	local col = if index <= 4 then index else index - 4
	local x = base.X + COLS[col]
	local ledge = base.Y + ROWS[row]
	local z = base.Z + BOARD_Z + 0.6

	local model = Instance.new("Model")
	model.Name = `Stock_{entry.id}`
	model.Parent = shelf

	local rar = StockConfig.RarityColor[item.rarity]
	local body: Part
	if item.shape == "Cylinder" then
		body = part(
			model,
			"Item",
			Vector3.new(0.9, 1.3, 0.9),
			CFrame.new(x, ledge + 0.65, z),
			item.color,
			Enum.Material.SmoothPlastic
		)
		body.Shape = Enum.PartType.Cylinder
		body.CFrame = body.CFrame * CFrame.Angles(0, 0, math.rad(90))
	elseif item.shape == "Ball" then
		body = part(
			model,
			"Item",
			Vector3.new(1.2, 1.2, 1.2),
			CFrame.new(x, ledge + 0.6, z),
			item.color,
			Enum.Material.SmoothPlastic
		)
		body.Shape = Enum.PartType.Ball
	elseif item.shape == "Wedge" then
		body = part(
			model,
			"Item",
			Vector3.new(1.2, 0.8, 1.4),
			CFrame.new(x, ledge + 0.4, z),
			item.color,
			Enum.Material.SmoothPlastic
		)
		body.Shape = Enum.PartType.Wedge
	else
		body = part(
			model,
			"Item",
			Vector3.new(1.1, 1.1, 1.1),
			CFrame.new(x, ledge + 0.55, z),
			item.color,
			Enum.Material.SmoothPlastic
		)
	end
	local band = part(
		model,
		"Rarity",
		Vector3.new(1.4, 0.14, 1.4),
		CFrame.new(x, ledge + 0.07, z),
		rar,
		Enum.Material.Neon
	)

	local tag = part(
		model,
		"Tag",
		Vector3.new(2.7, 0.9, 0.12),
		CFrame.new(x, ledge, z + 0.95),
		Color3.fromRGB(232, 224, 202),
		Enum.Material.SmoothPlastic
	)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Tag"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 64
	gui.LightInfluence = 0.2
	gui.Parent = tag
	local panel = frame(
		gui,
		"Panel",
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 1),
		Color3.fromRGB(232, 224, 202)
	)
	panel.Position = UDim2.fromScale(0, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Color = rar
	stroke.Thickness = 3
	stroke.Parent = panel
	local nameLabel = textLabel(
		panel,
		"Name",
		UDim2.fromOffset(10, 6),
		UDim2.new(1, -20, 0, 26),
		Enum.Font.BuilderSansBold,
		20,
		Color3.fromRGB(38, 44, 50)
	)
	local priceLabel = textLabel(
		panel,
		"Price",
		UDim2.fromOffset(10, 30),
		UDim2.new(1, -20, 0, 26),
		Enum.Font.BuilderSansBold,
		22,
		GOLD
	)
	priceLabel.TextColor3 = GOLD
	local countLabel = textLabel(
		panel,
		"Count",
		UDim2.fromOffset(10, 30),
		UDim2.new(1, -20, 0, 26),
		Enum.Font.BuilderSansMedium,
		19,
		Color3.fromRGB(88, 92, 96)
	)
	countLabel.TextXAlignment = Enum.TextXAlignment.Right

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StockPrompt"
	prompt.ActionText = "Buy"
	prompt.ObjectText = item.name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Slot", entry.slot)
	prompt.Triggered:Connect(function()
		requestBuy(entry.slot)
	end)
	prompt.Parent = body

	local view: ItemView = {
		slot = entry.slot,
		model = model,
		parts = { body, band, tag },
		body = body,
		prompt = prompt,
		nameLabel = nameLabel,
		priceLabel = priceLabel,
		countLabel = countLabel,
		status = nil,
	}
	paintTag(view, entry)
	table.insert(itemViews, view)

	for _, p in view.parts do
		local size = p.Size
		p.Size = size * 0.06
		task.delay(index * 0.045, function()
			if p.Parent then
				TweenService:Create(
					p,
					TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{ Size = size }
				):Play()
			end
		end)
	end
end

local function renderItems(items: { { [string]: any } }, fresh: boolean)
	if not shelf then
		return
	end
	clearItems()
	for i, entry in items do
		buildItem(entry, i)
	end
	if fresh then
		ringRestock()
	end
end

local function apply(view: { [string]: any })
	local items = view.items
	if type(items) ~= "table" or not shelf then
		pendingView = view
		return
	end
	local fresh = lastWindow ~= nil and view.window ~= lastWindow
	if fresh or #itemViews ~= #items then
		renderItems(items, fresh)
	else
		for i, entry in items do
			local itemView = itemViews[i]
			if itemView then
				paintTag(itemView, entry)
			end
		end
	end
	lastWindow = view.window
	deadline = os.clock() + (view.secondsToRestock or StockRotation.Period)
	flashUntil = 0
	local label = clockLabel
	if label then
		label.TextColor3 = INK
		label.Text = StockRotation.formatTime(view.secondsToRestock or StockRotation.Period)
		shownTime = label.Text
	end
end

local function pull()
	local fn = getFn
	if not fn then
		return
	end
	task.spawn(function()
		local ok, view = pcall(function()
			return fn:InvokeServer()
		end)
		if ok and type(view) == "table" then
			apply(view)
		end
	end)
end

local function buildClock(parent: Instance)
	local board = part(
		parent,
		"ClockBoard",
		Vector3.new(6.6, 2.0, 0.3),
		CFrame.new(base.X, base.Y + 4.0, base.Z + BOARD_Z + 0.35),
		WOOD,
		Enum.Material.Wood
	)

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Clock"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 64
	gui.LightInfluence = 0.35
	gui.Parent = board
	local panel = frame(gui, "Panel", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), FACE)

	local clock = frame(panel, "Icon", UDim2.fromOffset(12, 8), UDim2.fromOffset(60, 60), FACE)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = clock
	local ring = Instance.new("UIStroke")
	ring.Color = INK
	ring.Thickness = 2
	ring.Parent = clock
	for i, spec in { { 18, 28 }, { 11, 115 } } do
		local hand =
			frame(clock, `Hand{i}`, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(3, spec[1]), INK)
		hand.AnchorPoint = Vector2.new(0.5, 1)
		hand.Rotation = spec[2]
	end
	local pin = frame(clock, "Pin", UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(6, 6), INK)
	pin.AnchorPoint = Vector2.new(0.5, 0.5)

	local label = textLabel(
		panel,
		"Time",
		UDim2.fromOffset(96, 0),
		UDim2.new(1, -104, 1, 0),
		Enum.Font.BuilderSansBold,
		58,
		INK
	)
	label.Text = "10:00"
	clockLabel = label

	-- a small brass bell beside the clock board, swinging on each restock
	local hang = CFrame.new(base + Vector3.new(-3.0, 3.55, BOARD_Z + 0.7))
	bellPivot = hang
	local brass = part(
		parent,
		"StockBell",
		Vector3.new(0.8, 0.9, 0.8),
		hang * CFrame.new(0, -0.65, 0),
		Color3.fromRGB(206, 160, 74),
		Enum.Material.Metal
	)
	brass.Shape = Enum.PartType.Ball
	bell = brass
end

local function build(anchor: BasePart)
	base = anchor.Position
	local model = Instance.new("Model")
	model.Name = "ChandleryStock"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	shelf = model

	local board = part(
		model,
		"BackBoard",
		Vector3.new(BOARD_WIDTH, 3.6, 0.28),
		CFrame.new(base.X, base.Y + 1.2, base.Z + BOARD_Z),
		Color3.fromRGB(58, 46, 38),
		Enum.Material.WoodPlanks
	)
	board.CanCollide = false
	for _, rowY in ROWS do
		part(
			model,
			"Ledge",
			Vector3.new(BOARD_WIDTH, 0.18, 1.5),
			CFrame.new(base.X, base.Y + rowY, base.Z + BOARD_Z + 0.65),
			WOOD,
			Enum.Material.Wood
		)
	end
	buildClock(model)
	model.Parent = Workspace

	if pendingView then
		local view = pendingView
		pendingView = nil
		apply(view)
	end
end

local function tick()
	local label = clockLabel
	if not label then
		return
	end
	if os.clock() < flashUntil then
		return
	end
	local left = deadline - os.clock()
	local text = StockRotation.formatTime(left)
	if text ~= shownTime then
		shownTime = text
		label.Text = text
		label.TextColor3 = if left <= 60 then Color3.fromRGB(246, 206, 96) else INK
	end
	if left <= 0 and os.clock() >= nextPull then
		nextPull = os.clock() + 1
		pull()
	end
end

local function findCounter(): BasePart?
	for _, d in Workspace:GetDescendants() do
		if d:IsA("ProximityPrompt") and d:GetAttribute("Panel") == "ShopCounter" then
			local parent = d.Parent
			if parent and parent:IsA("BasePart") then
				return parent
			end
		end
	end
	return nil
end

function StockController.Init()
	local net = ReplicatedStorage:WaitForChild("Net")
	stateRemote = net:WaitForChild("Stock_State", 30) :: RemoteEvent
	getFn = net:WaitForChild("Stock_Get", 30) :: RemoteFunction
	buyFn = net:WaitForChild("Stock_Buy", 30) :: RemoteFunction
	if stateRemote then
		stateRemote.OnClientEvent:Connect(function(view)
			if type(view) == "table" then
				apply(view)
			end
		end)
	end
end

function StockController.Start()
	-- RP-P1: the clock reads minutes, so refresh the SurfaceGui once a second, not every frame.
	local since = 0
	RunService.Heartbeat:Connect(function(dt)
		since += dt
		if since < 1 then
			return
		end
		since = 0
		tick()
	end)
	local anchor: BasePart? = nil
	for _ = 1, 120 do
		anchor = findCounter()
		if anchor then
			break
		end
		task.wait(0.5)
	end
	if not anchor then
		warn("[StockController] no ShopCounter prompt found; stock shelf not built")
		return
	end
	build(anchor)
	pull()
end

return StockController
