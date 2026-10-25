--!strict
-- DockController (docs/23 c.3, WP-4): the next dock level as a ghost on your own plot, only you see it:
-- translucent blue pieces (shared/DockPieces) with wireframe edges and a scaffold. Walking up to it shows
-- a "Build" prompt (E / gamepad X / tap) that opens a small price card: the level icon, a Cash button
-- (coin + amount; lock + rank badge when the rank is too low, greyed when Cash is short) and a Robux
-- button (Roblox's live price; greyed while the product has no id). B / the X button / walking off closes.
-- The WP-10b buildings (garage, helipad + hangar, sub pen) get their own ghosts the same way while unowned
-- (the hangar once the Lv 3 boathouse stands); their card shows the building's word instead of the number.
-- Reads player attributes DockPlot, BayCFrame, DockLevel, DockGarage / DockHangar / DockSubPen (DockService)
-- and the PlayerDataChanged snapshot.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DockConfig = require(Shared:WaitForChild("Config"):WaitForChild("DockConfig"))
local DockPieces = require(Shared:WaitForChild("DockPieces"))
local MonetizationConfig = require(Shared:WaitForChild("Config"):WaitForChild("MonetizationConfig"))
local Net = require(Shared:WaitForChild("Net"))
local ProductShelves = require(Shared:WaitForChild("ProductShelves"))
local ProgressionConfig = require(Shared:WaitForChild("Config"):WaitForChild("ProgressionConfig"))
local UiImages = require(Shared:WaitForChild("Config"):WaitForChild("UiImages"))

local UI = script.Parent.Parent:WaitForChild("UI")
local AudioController = require(script.Parent:WaitForChild("AudioController"))
local CashBurst = require(UI:WaitForChild("CashBurst"))
local Glyph = require(UI:WaitForChild("Glyph"))
local HudTheme = require(UI:WaitForChild("HudTheme"))
local InputGlyph = require(UI:WaitForChild("InputGlyph"))
local Marina = require(Shared:WaitForChild("Marina"))

local DockController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local C = HudTheme.Colors
local GHOST = Color3.fromRGB(90, 170, 255)
local ROBUX_GREEN = Color3.fromHex("2F9E5B")

local snapshot: { [string]: any } = {}
local ghosts: { Model } = {}
local ghostKey = ""
local shownCount: number? = nil -- level + buildings owned, for the build beat
local WORDS = { Garage = "Garage", Hangar = "Helipad", SubPen = "Sub pen" }

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
	if not ok and card then
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
	Glyph.draw("home", house, GHOST)
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
	word.TextColor3 = GHOST
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
	local word = if type(level) == "string" then WORDS[level] else nil
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

-- translucent blue pieces, wire edges, a scaffold around them, and the Build prompt at `promptAt` (nil: on
-- the deck, as near the pieces' middle as the deck allows)
local function makeGhost(level: Item, m: Model, b: CFrame, promptAt: CFrame?): Model
	m.Name = "DockGhost"
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Color = GHOST
			d.Material = Enum.Material.SmoothPlastic
			d.Transparency = 0.82
			d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = false, false, false, false
			local edge = Instance.new("SelectionBox")
			edge.Adornee = d
			edge.Color3 = GHOST
			edge.LineThickness = 0.04
			edge.SurfaceTransparency = 1
			edge.Parent = d
		elseif d:IsA("Light") or d:IsA("SurfaceGui") or d:IsA("Beam") then
			d:Destroy()
		end
	end
	local box, size = m:GetBoundingBox()
	local function rod(name: string, s: Vector3, cf: CFrame)
		local p = Instance.new("Part")
		p.Name = name
		p.Size, p.CFrame, p.Color = s, cf, GHOST
		p.Material = Enum.Material.Neon
		p.Transparency = 0.6
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow =
			true, false, false, false, false
		p.Parent = m
	end
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			rod("Scaffold", Vector3.new(0.25, size.Y, 0.25), box * CFrame.new(sx * hx, 0, sz * hz))
		end
		rod("Scaffold", Vector3.new(0.25, 0.25, size.Z), box * CFrame.new(sx * hx, hy, 0))
		rod("Scaffold", Vector3.new(size.X, 0.25, 0.25), box * CFrame.new(0, hy, sx * hz))
	end

	local p = b:PointToObjectSpace(box.Position)
	local at = Instance.new("Part")
	at.Name = "BuildAt"
	at.Size = Vector3.new(1, 1, 1)
	at.CFrame = promptAt or b * CFrame.new(math.clamp(p.X, -19, 27), 5.5, math.clamp(p.Z, 30, 50))
	at.Transparency = 1
	at.Anchored, at.CanCollide, at.CanQuery, at.CanTouch = true, false, false, false
	at.Parent = m
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Build"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = at
	prompt.Triggered:Connect(function()
		open(level)
	end)
	prompt.PromptHidden:Connect(function()
		if cardLevel == level then
			close()
		end
	end)
	return m
end

local function refresh()
	local level = player:GetAttribute("DockLevel")
	local b = player:GetAttribute("BayCFrame")
	local plot = player:GetAttribute("DockPlot")
	if type(level) ~= "number" or typeof(b) ~= "CFrame" or type(plot) ~= "number" then
		return
	end
	local owned = { tostring(level) }
	for _, key in DockConfig.BUILDINGS do
		if player:GetAttribute("Dock" .. key) == true then
			table.insert(owned, key)
		end
	end
	local shown = table.concat(owned, ",")
	local count = level + #owned
	if shownCount and count > shownCount then -- a level or a building just got built: the beat
		AudioController.play("Chandlery_Till")
		local view = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize
			or Vector2.new(800, 600)
		CashBurst.playAt(playerGui, view / 2, 0, false)
	end
	shownCount = count
	local key = `{shown}:{b}`
	if key == ghostKey then
		return
	end
	ghostKey = key
	close()
	for _, g in ghosts do
		g:Destroy()
	end
	ghosts = {}
	local berth = (b :: CFrame) - Vector3.new(0, 0.2, 0)
	if level < DockConfig.MAX then
		table.insert(ghosts, makeGhost(level + 1, DockPieces.build(level + 1, berth), b))
	end
	for _, name in DockConfig.BUILDINGS do
		if not table.find(owned, name) and level >= DockConfig.Buildings[name].needs then
			local frame = if name == "Garage" then Marina.garage(plot) else berth
			local m = DockPieces.building(name, frame)
			table.insert(ghosts, makeGhost(name, m, b, frame * DockPieces.Buildings[name].buildAt))
		end
	end
	for _, g in ghosts do
		g.Parent = Workspace
	end
end

function DockController.Init()
	modal = InputGlyph.modal("DockCard", close)
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
	player:GetAttributeChangedSignal("BayCFrame"):Connect(refresh)
	player:GetAttributeChangedSignal("DockPlot"):Connect(refresh)
	for _, key in DockConfig.BUILDINGS do
		player:GetAttributeChangedSignal("Dock" .. key):Connect(refresh)
	end
	refresh()
end

return DockController
