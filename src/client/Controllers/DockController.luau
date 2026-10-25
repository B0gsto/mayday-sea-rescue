--!strict
-- DockController (docs/23 (j) rule 4, WP-14c): the owner of a plot sees the blueprint table's paper
-- sheets (built by DockService, one per available upgrade) with a prompt each; one opens the price
-- card: the level icon, a Cash button (coin + amount; lock + rank badge when the rank is too low,
-- greyed when Cash is short) and a Robux button (Roblox's live price; greyed while the product has no
-- id). B / the X button / walking off closes. Locked sheets are greyed with a padlock (DockService).
-- On a buy the pieces already exist in their final state; Dock_Build tells this controller to play the
-- Lego build beat (shared/BuildSeq): each piece drops from ~6-10 studs up, staggered, with a snap and a
-- squash, then a dust puff, client-side tweens only.
-- Reads player attributes DockPlot, DockLevel, DockHangar / DockSubPen (DockService)
-- and the PlayerDataChanged snapshot.
-- Paint booth (docs/23 d.3, WP-13): sitting in a craft inside your own Lv 3+ booth (DockConfig.PAINT_BOOTH)
-- opens the paint card: a swatch strip and the existing cosmetic pickers for Livery and Decal (the same rows
-- as the phone's Settings). Leaving the booth or B / the X button closes it until the next visit.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildSeq = require(Shared:WaitForChild("BuildSeq"))
local DockBlueprints = require(Shared:WaitForChild("DockBlueprints"))
local DockConfig = require(Shared:WaitForChild("Config"):WaitForChild("DockConfig"))
local MonetizationConfig = require(Shared:WaitForChild("Config"):WaitForChild("MonetizationConfig"))
local Net = require(Shared:WaitForChild("Net"))
local ProductShelves = require(Shared:WaitForChild("ProductShelves"))
local ProgressionConfig = require(Shared:WaitForChild("Config"):WaitForChild("ProgressionConfig"))
local UiImages = require(Shared:WaitForChild("Config"):WaitForChild("UiImages"))

local UI = script.Parent.Parent:WaitForChild("UI")
local AudioController = require(script.Parent:WaitForChild("AudioController"))
local CashBurst = require(UI:WaitForChild("CashBurst"))
local CosmeticPicker = require(UI:WaitForChild("CosmeticPicker"))
local Glyph = require(UI:WaitForChild("Glyph"))
local HudTheme = require(UI:WaitForChild("HudTheme"))
local InputGlyph = require(UI:WaitForChild("InputGlyph"))

local DockController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local C = HudTheme.Colors
local ROBUX_GREEN = Color3.fromHex("2F9E5B")

local snapshot: { [string]: any } = {}
local shownCount: number? = nil -- level + buildings owned, for the purchase beat

type Item = number | string -- a dock level, or a DockConfig.Buildings key
local livePrice: { [number]: number } = {}

type Card = {
	gui: ScreenGui,
	house: Frame,
	number: TextLabel,
	word: TextLabel,
	cash: TextButton,
	cashRow: Frame,
	robux: TextButton,
	robuxLabel: TextLabel,
}
local card: Card? = nil
local cardLevel: Item? = nil

local function itemOf(key: Item): DockConfig.Level
	return if type(key) == "number" then DockConfig.Levels[key] else DockConfig.Buildings[key]
end
local modal: InputGlyph.Modal

local function close()
	if card then
		card.gui.Enabled = false
	end
	cardLevel = nil
	modal.close()
end

local function shake(b: GuiObject)
	local at = b.Position
	b.Position = at + UDim2.fromOffset(8, 0)
	TweenService:Create(b, TweenInfo.new(0.3, Enum.EasingStyle.Elastic), { Position = at }):Play()
	AudioController.play("UI_Fail")
end

local function lockIcon(parent: Instance, px: number)
	local f = Instance.new("Frame")
	f.Name = "Lock"
	f.Size = UDim2.fromOffset(px, px)
	f.BackgroundTransparency = 1
	f.Parent = parent
	local shackle = Glyph.bar(f, Vector2.new(0.5, 0.5), Vector2.new(0.5, 0.32), 0, C.textDim, 1)
	shackle.BackgroundTransparency = 1
	local s = Instance.new("UIStroke")
	s.Color, s.Thickness = C.textDim, 3
	s.Parent = shackle
	Glyph.bar(f, Vector2.new(0.76, 0.5), Vector2.new(0.5, 0.68), 0, C.textDim, 0.2)
end

local function row(parent: Instance): Frame
	local r = Instance.new("Frame")
	r.Name = "Row"
	r.Size = UDim2.fromScale(1, 1)
	r.BackgroundTransparency = 1
	r.Parent = parent
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = r
	return r
end

local function text(parent: Instance, s: string, color: Color3, order: number): TextLabel
	local l = Instance.new("TextLabel")
	l.AutomaticSize = Enum.AutomaticSize.X
	l.Size = UDim2.fromOffset(0, 30)
	l.BackgroundTransparency = 1
	l.Font = HudTheme.NumberFont
	l.TextSize = HudTheme.scaled(26)
	l.TextColor3 = color
	l.Text = s
	l.LayoutOrder = order
	l.Parent = parent
	return l
end

local function buy(level: Item)
	local remote = Net.init():WaitForChild("Dock_Upgrade", 5) :: RemoteFunction?
	if not remote or not card then
		return
	end
	local ok = remote:InvokeServer(level)
	if ok then
		close() -- the build beat plays; the sheet disappears
	elseif card then
		shake(card.cash)
	end
end

local function build(): Card
	local gui = Instance.new("ScreenGui")
	gui.Name = "DockCard"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 30
	gui.Enabled = false
	gui.Parent = playerGui
	local panel = HudTheme.panel("Card", UDim2.fromOffset(260, 236), gui)
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -110)
	panel.BackgroundTransparency = HudTheme.PromptTransparency
	HudTheme.padding(panel, 14)
	HudTheme.skin(panel)

	-- the level icon: a house with the level number
	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.fromScale(0.5, 0)
	icon.Size = UDim2.fromOffset(64, 64)
	icon.BackgroundTransparency = 1
	icon.Parent = panel
	local house = Instance.new("Frame")
	house.Size = UDim2.fromScale(1, 1)
	house.BackgroundTransparency = 1
	house.Parent = icon
	Glyph.draw("home", house, C.accent)
	local number = Instance.new("TextLabel")
	number.Name = "Level"
	number.AnchorPoint = Vector2.new(0.5, 0.5)
	number.Position = UDim2.fromScale(0.5, 0.68)
	number.Size = UDim2.fromScale(0.5, 0.4)
	number.BackgroundTransparency = 1
	number.Font = HudTheme.NumberFont
	number.TextScaled = true
	number.TextColor3 = C.panel
	number.Parent = icon
	local word = Instance.new("TextLabel")
	word.Name = "Word"
	word.AnchorPoint = Vector2.new(0.5, 0)
	word.Position = UDim2.fromScale(0.5, 0)
	word.Size = UDim2.fromOffset(150, 56)
	word.BackgroundTransparency = 1
	word.Font = HudTheme.HeaderFont
	word.TextScaled = true
	word.TextColor3 = C.accent
	word.Parent = panel

	local closeButton = HudTheme.button("Close", "X", UDim2.fromOffset(34, 34), panel)
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.fromScale(1, 0)
	closeButton.BackgroundColor3 = C.panelLight
	closeButton.Activated:Connect(close)

	local cash = HudTheme.button("Cash", "", UDim2.new(1, 0, 0, HudTheme.MinButtonHeight), panel)
	cash.Position = UDim2.fromOffset(0, 76)
	local robux = HudTheme.button("Robux", "", UDim2.new(1, 0, 0, HudTheme.MinButtonHeight), panel)
	robux.Position = UDim2.fromOffset(0, 76 + HudTheme.MinButtonHeight + 10)
	local robuxLabel = text(row(robux), "", C.text, 1)

	local c: Card = {
		gui = gui,
		house = house,
		number = number,
		word = word,
		cash = cash,
		cashRow = row(cash),
		robux = robux,
		robuxLabel = robuxLabel,
	}
	cash.Activated:Connect(function()
		if cardLevel and cash:GetAttribute("Live") then
			buy(cardLevel)
		elseif cardLevel then
			shake(cash)
		end
	end)
	robux.Activated:Connect(function()
		local lv = cardLevel and itemOf(cardLevel)
		local item = lv and MonetizationConfig.Products[lv.product]
		if item and item.id ~= 0 then
			MarketplaceService:PromptProductPurchase(player, item.id)
			close()
		else
			shake(robux)
		end
	end)
	return c
end

local function paint()
	local c, level = card, cardLevel
	if not c or not level then
		return
	end
	local lv = itemOf(level)
	local word = if type(level) == "string" then DockBlueprints.WORDS[level] else nil
	c.number.Text = if word then "" else tostring(level)
	c.house.Visible = word == nil
	c.word.Text = word or ""
	for _, child in c.cashRow:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	local rank = snapshot.rankIndex or 1
	local need = DockConfig.rankIndex(lv.rank)
	local cash = snapshot.cash or 0
	local live = rank >= need and cash >= lv.cash
	c.cash:SetAttribute("Live", live)
	c.cash.BackgroundColor3 = if live then C.accent else C.locked
	if rank < need then
		lockIcon(c.cashRow, 26)
		local badge = Instance.new("TextLabel")
		badge.AutomaticSize = Enum.AutomaticSize.X
		badge.Size = UDim2.fromOffset(0, 28)
		badge.BackgroundColor3 = C.panelLight
		badge.Font = HudTheme.LabelFont
		badge.TextSize = HudTheme.scaled(16)
		badge.TextColor3 = C.text
		badge.Text = ProgressionConfig.Ranks[need].displayName
		badge.LayoutOrder = 2
		HudTheme.corner(badge, 14)
		HudTheme.padding(badge, 6)
		badge.Parent = c.cashRow
	else
		if not live then
			lockIcon(c.cashRow, 26)
		end
		local coin = Instance.new("ImageLabel")
		coin.Size = UDim2.fromOffset(28, 28)
		coin.BackgroundTransparency = 1
		coin.Image = UiImages.Hud.Coin
		coin.LayoutOrder = 1
		coin.Parent = c.cashRow
		text(c.cashRow, HudTheme.formatNumber(lv.cash), if live then C.text else C.textDim, 2)
	end
	local item = MonetizationConfig.Products[lv.product]
	local id = item and item.id or 0
	local price = livePrice[id] or lv.robux
	c.robuxLabel.Text = `{ProductShelves.ROBUX} {HudTheme.formatNumber(price)}`
	c.robux.BackgroundColor3 = if id ~= 0 then ROBUX_GREEN else C.locked
	c.robuxLabel.TextColor3 = if id ~= 0 then C.text else C.textDim
	if id ~= 0 and not livePrice[id] then
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(id, Enum.InfoType.Product)
			end)
			if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
				livePrice[id] = info.PriceInRobux
				paint()
			end
		end)
	end
end

local function open(level: Item)
	card = card or build()
	cardLevel = level
	paint()
	local c = card :: Card
	c.gui.Enabled = true
	modal.open(c.cash)
	AudioController.play("UI_Click")
end

-- One blueprint sheet (built by DockService on the owner's plot): the owner's own prompt opens the card.
local function bindSheet(sheet: Model)
	local item = sheet:GetAttribute("DockItem")
	if item == nil then
		return
	end
	local at = sheet:FindFirstChild("Sheet")
	if at and at:FindFirstChildOfClass("ProximityPrompt") then
		return -- already bound
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = (sheet:GetAttribute("Label") or "Blueprints") :: string
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = if at and at:IsA("BasePart") then at else sheet
	prompt.Triggered:Connect(function()
		open(item :: Item)
	end)
	prompt.PromptHidden:Connect(function()
		if cardLevel == item then
			close()
		end
	end)
end

-- The owner's sheets: rebuilt by DockService when the level or buildings change.
local promptBounds: { RBXScriptConnection } = {}
local function bindBlueprints()
	for _, c in promptBounds do
		c:Disconnect()
	end
	promptBounds = {}
	local plot = player:GetAttribute("DockPlot")
	if type(plot) ~= "number" then
		return
	end
	local marina = Workspace:FindFirstChild("Marina")
	local pm = marina and marina:FindFirstChild(`Plot{plot}`)
	if not pm then
		return
	end
	local function bindModel(bp: Model)
		for _, sheet in bp:GetChildren() do
			if sheet:IsA("Model") then
				bindSheet(sheet)
			end
		end
		table.insert(
			promptBounds,
			bp.ChildAdded:Connect(function(sheet: Instance)
				if sheet:IsA("Model") then
					bindSheet(sheet)
				end
			end)
		)
	end
	table.insert(
		promptBounds,
		pm.ChildAdded:Connect(function(child: Instance)
			if child:IsA("Model") and child.Name == "Blueprints" then
				bindModel(child)
			end
		end)
	)
	local bp = pm:FindFirstChild("Blueprints")
	if bp and bp:IsA("Model") then
		bindModel(bp :: Model)
	end
end

-- The Lego build beat (WP-14c): each part of a freshly built model drops from above with a stagger,
-- lands with a squash and a snap, then a dust puff. Client tweens only; the server owns the final
-- positions, so skipping this (a missed event) just shows the finished building.
local function snapSound(at: Vector3)
	AudioController.play("UI_Click", at, 0.5)
end

local function dustPuff(at: Vector3)
	local p = Instance.new("Part")
	p.Name = "BuildDust"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = at
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(230, 222, 205))
	e.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 8) })
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(0.6, 1.1)
	e.Speed = NumberRange.new(6, 14)
	e.SpreadAngle = Vector2.new(90, 90)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, -4, 0)
	e.Drag = 2
	e.Enabled = false
	e.Parent = p
	p.Parent = Workspace
	e:Emit(25)
	game:GetService("Debris"):AddItem(p, 3)
end

local function playBuild(model: Model)
	local parts: { BasePart } = {}
	local ys: { number } = {}
	local base = Vector3.zero
	local minY = math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			table.insert(ys, d.CFrame.Y)
			base += d.Position * Vector3.new(1, 0, 1)
			minY = math.min(minY, d.CFrame.Y)
		end
	end
	if #parts == 0 then
		return
	end
	base /= #parts
	local at = Vector3.new(base.X, minY, base.Z)
	local plan = BuildSeq.plan(ys, math.random(0, 1_000_000))
	local last = 0
	for _, step in plan do
		local part = parts[step.i]
		local final = part.CFrame
		part.CFrame = final + Vector3.new(0, step.drop, 0)
		local tween = TweenService:Create(
			part,
			TweenInfo.new(
				0.45,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In,
				0,
				false,
				step.delay
			),
			{ CFrame = final }
		)
		last = math.max(last, step.delay + 0.45)
		tween.Completed:Connect(function()
			if tween.PlaybackState ~= Enum.PlaybackState.Cancelled then
				snapSound(final.Position)
				local size = part.Size
				TweenService
					:Create(part, TweenInfo.new(0.07), { Size = size * Vector3.new(1, 0.82, 1) })
					:Play()
				TweenService:Create(
					part,
					TweenInfo.new(
						0.07,
						Enum.EasingStyle.Quad,
						Enum.EasingDirection.Out,
						0,
						false,
						0.07
					),
					{ Size = size }
				):Play()
			end
		end)
		tween:Play()
	end
	task.delay(last + 0.3, function()
		dustPuff(at)
	end)
end

-- A purchase (a level or building landed, seen through the attributes): the till and the coin burst.
local function refresh()
	local level = player:GetAttribute("DockLevel")
	if type(level) ~= "number" then
		return
	end
	local count = level
	for _, key in DockConfig.BUILDINGS do
		if player:GetAttribute("Dock" .. key) == true then
			count += 1
		end
	end
	if shownCount and count > shownCount then
		AudioController.play("Chandlery_Till")
		local view = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize
			or Vector2.new(800, 600)
		CashBurst.playAt(playerGui, view / 2, 0, false)
	end
	shownCount = count
end

type Booth = { gui: ScreenGui, pickers: { CosmeticPicker.Picker } }
local booth: Booth? = nil
local inBooth = false
local boothModal: InputGlyph.Modal

local function closeBooth()
	if booth then
		booth.gui.Enabled = false
	end
	boothModal.close()
end

local BOOTH_SWATCHES = {
	Color3.fromRGB(214, 86, 20),
	Color3.fromRGB(201, 162, 74),
	Color3.fromRGB(40, 150, 142),
	Color3.fromRGB(79, 98, 117),
	Color3.fromRGB(226, 85, 122),
}

local function buildBooth(): Booth
	local gui = Instance.new("ScreenGui")
	gui.Name = "PaintBoothCard"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 30
	gui.Enabled = false
	gui.Parent = playerGui
	local panel = HudTheme.panel("Card", UDim2.fromOffset(360, 168), gui)
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -110)
	panel.BackgroundTransparency = HudTheme.PromptTransparency
	HudTheme.padding(panel, 14)
	HudTheme.skin(panel)
	-- the header is the paint itself: a strip of swatches
	local strip = Instance.new("Frame")
	strip.Name = "Swatches"
	strip.Size = UDim2.new(1, -44, 0, 26)
	strip.BackgroundTransparency = 1
	strip.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.Parent = strip
	for _, c in BOOTH_SWATCHES do
		local sw = Instance.new("Frame")
		sw.Size = UDim2.fromOffset(34, 26)
		sw.BackgroundColor3 = c
		sw.BorderSizePixel = 0
		HudTheme.corner(sw, 6)
		sw.Parent = strip
	end
	local closeButton = HudTheme.button("Close", "X", UDim2.fromOffset(34, 34), panel)
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.fromScale(1, 0)
	closeButton.BackgroundColor3 = C.panelLight
	closeButton.Activated:Connect(closeBooth)
	local rows = Instance.new("Frame")
	rows.Name = "Rows"
	rows.Position = UDim2.fromOffset(0, 42)
	rows.Size = UDim2.new(1, 0, 1, -42)
	rows.BackgroundTransparency = 1
	rows.Parent = panel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = rows
	return {
		gui = gui,
		pickers = {
			CosmeticPicker.new(rows, "Livery", { layoutOrder = 1 }),
			CosmeticPicker.new(rows, "Decal", { layoutOrder = 2 }),
		},
	}
end

local function openBooth()
	booth = booth or buildBooth()
	local b = booth :: Booth
	for _, picker in b.pickers do
		picker.refresh()
	end
	b.gui.Enabled = true
	boothModal.open(b.pickers[1].first)
	AudioController.play("UI_Click")
end

-- seated (driving or aboard) with the seat inside your own booth
local function boothCheck()
	local level, b = player:GetAttribute("DockLevel"), player:GetAttribute("BayCFrame")
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local now = false
	if seat and type(level) == "number" and level >= 3 and typeof(b) == "CFrame" then
		local zone = DockConfig.PAINT_BOOTH
		local d = ((b :: CFrame) * zone.cf):PointToObjectSpace(seat.Position)
		local h = zone.size / 2
		now = math.abs(d.X) <= h.X and math.abs(d.Y) <= h.Y and math.abs(d.Z) <= h.Z
	end
	if now ~= inBooth then
		inBooth = now
		if now then
			openBooth()
		else
			closeBooth()
		end
	end
end

function DockController.Init()
	modal = InputGlyph.modal("DockCard", close)
	boothModal = InputGlyph.modal("PaintBooth", closeBooth)
end

function DockController.Start()
	Net.event("PlayerDataChanged").OnClientEvent:Connect(function(data: any)
		if type(data) == "table" then
			snapshot = data
			paint()
		end
	end)
	task.spawn(function()
		local getData = Net.init():WaitForChild("Progression_GetData", 30) :: RemoteFunction?
		local ok, data = pcall(function()
			return getData and getData:InvokeServer()
		end)
		if ok and type(data) == "table" then
			snapshot = data
		end
	end)
	player:GetAttributeChangedSignal("DockLevel"):Connect(refresh)
	for _, key in DockConfig.BUILDINGS do
		player:GetAttributeChangedSignal("Dock" .. key):Connect(refresh)
	end
	refresh()
	-- the Lego build beat, from DockService (the model is already in its final state)
	local buildEvent = Net.init():WaitForChild("Dock_Build", 30) :: RemoteEvent?
	if buildEvent then
		buildEvent.OnClientEvent:Connect(function(payload: any)
			local plot, name, parent =
				payload and payload.plot, payload and payload.name, payload and payload.parent
			if type(plot) ~= "number" or type(name) ~= "string" then
				return
			end
			task.spawn(function()
				local marina = Workspace:WaitForChild("Marina", 5)
				local pm = marina and marina:WaitForChild(`Plot{plot}`, 5)
				if not pm then
					return
				end
				local holder = if typeof(parent) == "string" then pm:WaitForChild(parent, 3) else pm
				local model = holder and holder:WaitForChild(name, 3)
				if model and model:IsA("Model") then
					playBuild(model)
				end
			end)
		end)
	end
	-- the blueprint prompts on my own plot: the plot and sheets may stream in after the claim, and
	-- out and back again (bindSheet skips sheets that already have their prompt)
	task.spawn(function()
		while true do
			if type(player:GetAttribute("DockPlot")) == "number" then
				bindBlueprints()
			end
			task.wait(3)
		end
	end)
	task.spawn(function()
		while true do
			boothCheck()
			task.wait(0.25)
		end
	end)
end

return DockController
