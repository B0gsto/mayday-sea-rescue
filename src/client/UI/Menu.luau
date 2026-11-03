--!strict
-- Menu (docs/23 (m), WP-23c): the left button column and its kit panels. Mounted once by HudController.
--   Grid (HudLayout "menu" region: 2 icon columns above the thumbstick): Shop, Quests,
--   Album, Pet, Crew, Settings, Map and Boat (Boat to me: the server's cooldown rule with the Mechanics' shorter wait, drawn as
--   a ring of ticks; Quick Launch shows the bolt and skips it) and Home (only while far from your island: back
--   on its spawn behind a quick dip to black). Each opens a centred kit Panel; Map opens the full map (MapController, also M).
--   Keys: P Shop, gamepad Start Settings, D-pad Left focuses the column (D-pad moves, A presses),
--   B closes the open panel or leaves the column.
--   LocalPlayer attribute MenuOpen mirrors "a panel is up" (Waypoint and the pager hide under it).
--   Menu.open(name) / Menu.close() / Menu.toggle(name) / Menu.openBoat(vehicleId) / Menu.isOpen()
--   Menu.openBoard(rack): a craft board's list (Panels/Board), from its BoardOpen prompt
--   Sale button (HudLayout "sale", owner mock A 2026-11-01): the Starter Kit's own icon, a tilted SALE tag and a
--   clock to MonetizationConfig saleEndsUtc (server time); hides once owned or over. Tap opens the Shop on it.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DockConfig = require(Shared:WaitForChild("Config"):WaitForChild("DockConfig"))
local MonetizationConfig = require(Shared:WaitForChild("Config"):WaitForChild("MonetizationConfig"))
local MonetizationEffects = require(Shared:WaitForChild("MonetizationEffects"))
local Net = require(Shared:WaitForChild("Net"))
local QuestData = require(Shared:WaitForChild("Quests"):WaitForChild("Data"))
local QuestRules = require(Shared:WaitForChild("Quests"):WaitForChild("Rules"))
local SaleRules = require(Shared:WaitForChild("SaleRules"))
local Stickers =
	require(Shared:WaitForChild("Config"):WaitForChild("UiImages")).Stickers :: { [string]: string }
local Client = script.Parent.Parent
local MapController = require(Client:WaitForChild("Controllers"):WaitForChild("MapController"))
local Telemetry = require(Client:WaitForChild("Telemetry"))

local UI = script.Parent
local Kit = UI:WaitForChild("Kit")
local Panels = UI:WaitForChild("Panels")
local Album = require(Panels:WaitForChild("Album"))
local Board = require(Panels:WaitForChild("Board"))
local BoatCard = require(UI:WaitForChild("BoatCard"))
local Companion = require(Panels:WaitForChild("Companion"))
local Crew = require(Panels:WaitForChild("Crew"))
local IconButton = require(Kit:WaitForChild("IconButton"))
local Layout = require(UI:WaitForChild("Layout"))
local QuestTablet = require(UI:WaitForChild("QuestTablet"))
local Quests = require(Panels:WaitForChild("Quests"))
local SettingsPanel = require(UI:WaitForChild("SettingsPanel"))
local Shop = require(Panels:WaitForChild("Shop"))
local Skills = require(Panels:WaitForChild("Skills"))
local Style = require(Kit:WaitForChild("Style"))
local Theme = require(Kit:WaitForChild("Theme"))
local Waypoint = require(UI:WaitForChild("Waypoint"))

local player = Players.LocalPlayer
local GOLD = Color3.fromHex("FFD84A")
local BUTTONS = { -- HudLayout.MENU_COUNT
	{ name = "Shop", label = "Shop", icon = "shop", color = "yellow" },
	{ name = "Quests", label = "Quests", icon = "quests", color = "orange" },
	{ name = "Album", label = "Album", icon = "album", color = "pink" },
	{ name = "Companion", label = "Pet", icon = "companion", color = "purple" },
	{ name = "Crew", label = "Crew", icon = "crew", color = "teal" },
	{ name = "Skills", label = "Skills", icon = "boost", color = "green" },
	{ name = "Settings", label = "Settings", icon = "settings", color = "blue" },
	{ name = "Map", label = "Map", icon = "map", color = "green" },
	{ name = "Boat", label = "Boat", icon = "boat_to_me", color = "red" },
	{ name = "Home", label = "Home", icon = "home", color = "blue" },
}

local Menu = {}

local bar: Frame? = nil
local chip: GuiObject? = nil -- the quest tracker (HudLayout "quest"): icon, place, distance; tap opens Quests
local SALE_KEY = "StarterKit"
local saleItem = (MonetizationConfig :: any).GamePasses[SALE_KEY]
local sale: GuiObject? = nil
local saleClock: TextLabel? = nil
local salePopped = false
local panels: { [string]: any } = {}
local buttons: { [string]: IconButton.IconButton } = {}
local current: string? = nil
local mounted = false
local pulseName: string? = nil

-- docs/24 E: on the button the tutorial asks for, the icon grows inside its tile once with a small bounce and stays
-- big until pressed. No outline ring (owner 2026-11-01), no looping pulse, no orange (owner 2026-10-28). Only the icon
-- grows: the phone's rows are too tight for the tile itself to move or grow without touching the label above.
local function startPulse(root: GuiObject, name: string)
	local art = root:FindFirstChild("Art", true) :: GuiObject?
	if not art or root:GetAttribute("TutorialCue") then
		return
	end
	root:SetAttribute("TutorialCue", true)
	local rest = art.Size
	TweenService:Create(
		art,
		TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(1, 1) }
	):Play()
	task.spawn(function()
		while root.Parent and pulseName == name do
			task.wait(0.2)
		end
		root:SetAttribute("TutorialCue", nil)
		TweenService:Create(art, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Size = rest }):Play()
	end)
end

function Menu.pulse(name: string?)
	pulseName = name
	if name then
		local b = buttons[name]
		if b then
			startPulse(b.root, name)
		end
	end
end

local function shown(): boolean
	return not Layout.coldOpen() and player:GetAttribute("CinematicPlaying") ~= true
end

local function paintSale()
	if not sale then
		return
	end
	local ends = saleItem.saleEndsUtc
	local now = Workspace:GetServerTimeNow()
	local on = shown()
		and current == nil
		and player:GetAttribute("MapOpen") ~= true
		and player:GetAttribute("BuildHidesMenu") ~= true
		and SaleRules.visible(ends, now, player:GetAttribute("Pass_" .. SALE_KEY) == true)
	if on and saleClock then
		saleClock.Text = SaleRules.countdown(ends - now)
	end
	if on and not salePopped then
		salePopped = true
		Style.pop(sale, true) -- one pop the first time it shows, never a loop
	else
		sale.Visible = on
	end
end

local function chrome()
	paintSale()
	if bar then
		bar.Visible = shown()
			and current == nil
			and player:GetAttribute("BuildHidesMenu") ~= true
			and player:GetAttribute("MapOpen") ~= true -- the full map is a panel too (its edge showed beside it)
	end
	if chip then
		chip.Visible = shown()
			and current == nil
			and player:GetAttribute("MapOpen") ~= true
			and player:GetAttribute("BuildHidesMenu") ~= true -- it sat on the build list (owner, 2026-10-28)
			and QuestData.byId[player:GetAttribute("QuestId") :: any] ~= nil
	end
	player:SetAttribute("MenuOpen", current ~= nil)
end

local function focusFirst(root: Instance)
	if not UserInputService.GamepadEnabled then
		return
	end
	-- the first button in reading order (creation order put cards rebuilt by sort, or a hidden Tabs row, first);
	-- the panel's red X only when nothing else is selectable
	local best: GuiButton? = nil
	for _, d in root:GetDescendants() do
		if d:IsA("GuiButton") and d.Selectable then
			local p: Instance? = d
			while p and p ~= root and (not p:IsA("GuiObject") or p.Visible) do
				p = p.Parent
			end
			local skip = p ~= root or (best and best.Name ~= "Close" and d.Name == "Close")
			if
				not skip
				and (
					not best
					or (best.Name == "Close" and d.Name ~= "Close")
					or Theme.readsBefore(d.AbsolutePosition, best.AbsolutePosition)
				)
			then
				best = d
			end
		end
	end
	if best then
		GuiService.SelectedObject = best
	end
end

function Menu.isOpen(): boolean
	return current ~= nil
end

-- a panel closed itself (its X): forget it and bring the column back
local function noteClosed()
	current = nil
	chrome()
end

function Menu.close()
	local name = current
	if not name then
		return
	end
	current = nil
	local p = panels[name]
	if p then
		p.close()
	end
	chrome()
end

function Menu.open(name: string)
	local p = panels[name]
	if not (mounted and p and shown()) then
		return
	end
	if name == pulseName then
		Menu.pulse(nil) -- found it (the quest reveal's cue)
	end
	if current == name then
		return
	end
	if MapController.IsOpen() then
		MapController.Close()
	end
	if current then
		local old = panels[current]
		current = nil
		old.close()
	end
	current = name
	chrome()
	Telemetry.shop("MenuOpened") -- before p.open(): its PanelOpened must land in this visit
	p.open()
	local sel = GuiService.SelectedObject
	if
		not (sel and sel:IsDescendantOf(p.root) and (not sel:IsA("GuiButton") or sel.Selectable))
	then
		task.defer(focusFirst, p.root)
	end
end

function Menu.toggle(name: string)
	if current == name then
		Menu.close()
	else
		Menu.open(name)
	end
end

function Menu.openBoat(id: string)
	local card = panels.Boat
	if card then
		card.setId(id)
		Menu.open("Boat")
	end
end

function Menu.openBoard(rack: Instance)
	local name = "Board_" .. rack.Name
	local p = panels[name]
	if p then
		p.setRack(rack)
		Menu.open(name)
	end
end

local function quick(): boolean -- the pass or its day pass (the server's rule)
	local ends = player:GetAttribute("DayPass_QuickLaunch")
	return MonetizationEffects.passActive(
		player:GetAttribute("Pass_QuickLaunch") == true,
		if type(ends) == "number" then ends else nil,
		Workspace:GetServerTimeNow()
	)
end

-- Seconds left and the full wait: VehicleService's RequestVehicle(near) rule, Mechanic included.
local function boatWait(): (number, number)
	local cooldown = MonetizationEffects.BOAT_TO_ME_COOLDOWN
		* (tonumber(player:GetAttribute("WorkerBoatScale")) or 1) -- Mechanics at work (WorkerService)
	local last = player:GetAttribute("BoatToMeAt")
	local left = MonetizationEffects.boatToMeWait(
		quick(),
		if type(last) == "number" then last else nil,
		Workspace:GetServerTimeNow(),
		cooldown
	)
	return left, cooldown
end

-- Seated in a craft (the server answers "Occupied"), or no Rescue Hut (the server answers "NoHut"): the Boat
-- tile rests grey and wordless, no error.
local function resting(): boolean
	if player:GetAttribute("DockLevelHQ") == 0 then
		return true
	end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	local craft = seat and seat:FindFirstAncestorWhichIsA("Model")
	while craft and craft:GetAttribute("VehicleId") == nil do
		craft = craft:FindFirstAncestorWhichIsA("Model")
	end
	return craft ~= nil
end

-- The Boat button's extras: a ring of ticks round the tile that fills back up over the cooldown
-- (the tile greys while it waits; Quick Launch skips the wait, so no ring). Press: your craft comes to you.
local function dressBoat(b: IconButton.IconButton)
	local tile = b.root:FindFirstChild("Tile") :: Frame
	local face = tile:FindFirstChild("Face", true) :: Frame
	local holder = tile:FindFirstChild("Block") :: Frame
	local ticks: { Frame } = {}
	for i = 1, 24 do
		local a = (i - 0.5) / 24 * 2 * math.pi
		local t = Instance.new("Frame")
		t.Name = "CooldownTick"
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.Position = UDim2.fromScale(0.5 + 0.43 * math.sin(a), 0.5 - 0.43 * math.cos(a))
		t.Size = UDim2.fromScale(0.09, 0.09)
		t.BackgroundColor3 = GOLD
		t.ZIndex = 3
		Style.corner(t, 99)
		Style.stroke(t, 1.5, true)
		t.Parent = face
		ticks[i] = t
	end
	local label = b.root:FindFirstChild("Label") :: TextLabel
	local waiting: boolean? = nil
	local sending = false
	local flash = 0
	local function paint()
		local left, cooldown = boatWait()
		local wait = left > 0
		local seated = resting()
		if (wait or seated) ~= waiting then
			waiting = wait or seated
			Style.recolor(holder, Style.grad(if waiting then "disabled" else "red"))
		end
		local lit = math.floor((1 - left / cooldown) * #ticks)
		for i, t in ticks do
			t.Visible = wait and i <= lit
		end
		if os.clock() > flash then
			label.Text = if sending then "…" elseif wait then `{math.ceil(left)}s` else "Boat"
		end
	end
	RunService.Heartbeat:Connect(function()
		if b.root.Visible and b.root:IsDescendantOf(game) then
			paint()
		end
	end)
	return function()
		if sending or boatWait() > 0 or resting() then
			return
		end
		sending = true
		task.spawn(function()
			local ok, done, why = pcall(function()
				return Net.func("RequestVehicle"):InvokeServer(nil, false, true)
			end)
			sending = false
			if not (ok and done) then
				label.Text = if ok and why == "Cooldown" then "Wait" else "Try again"
				flash = os.clock() + 1.6
			end
		end)
	end
end

-- The Home button: shown only past DockConfig.HOME_FAR from your berth (the grid closes the gap while hidden).
-- Press: dip to black, the server stands you on your island's spawn.
local function dressHome(b: IconButton.IconButton)
	local sending = false
	local function far(): boolean
		local bay = player:GetAttribute("BayCFrame")
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		return typeof(bay) == "CFrame"
			and root ~= nil
			and (root.Position - bay.Position).Magnitude > DockConfig.HOME_FAR
	end
	task.spawn(function()
		while b.root.Parent do -- until a rebuild destroys it
			b.root.Visible = sending or far()
			task.wait(0.5)
		end
	end)
	return function()
		if sending or not far() then
			return
		end
		sending = true
		player:SetAttribute("ColdOpenFade", true) -- ColdOpenFadeController paints it
		task.wait(0.3)
		pcall(function()
			Net.func("GoHome"):InvokeServer()
		end)
		task.wait(0.15)
		player:SetAttribute("ColdOpenFade", nil)
		sending = false
	end
end

-- the quest cards you can act on now (the tablet's rows: an offer you can accept, a quest ready to hand in); the
-- button itself only once quests are open (QuestService QuestsOpen, owner 2026-10-29: not at the first start)
local function questBadge()
	local n = 0
	for _, r in QuestTablet.rows(true) do
		if r.ready and r.action ~= "drop" then
			n += 1
		end
	end
	local q = buttons.Quests
	if q then
		local open = player:GetAttribute("QuestsOpen") == true
		q.root.Visible = open
		q.setBadge(if open and n > 0 then n else nil)
	end
end

-- (Re)build the column for the device's grid (HudLayout menu metrics).
local function buildBar(region: Frame)
	if bar then
		bar:Destroy()
	end
	local mm = Layout.current().menu
	local b = Instance.new("Frame")
	b.Name = "ButtonBar"
	b.BackgroundTransparency = 1
	b.Size = UDim2.fromScale(1, 1)
	b.Parent = region
	bar = b
	local grid = Instance.new("UIGridLayout")
	grid.FillDirection = Enum.FillDirection.Vertical
	grid.FillDirectionMaxCells = mm.rows
	grid.CellSize = UDim2.fromOffset(mm.icon, mm.icon + mm.label)
	grid.CellPadding = UDim2.fromOffset(mm.colGap, mm.gap)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = b
	for i, info in BUTTONS do
		local onPress: () -> ()
		local btn = IconButton.new(b, {
			icon = info.icon,
			label = info.label,
			color = info.color,
			size = mm.icon,
			labelRow = mm.label,
			onActivate = function()
				onPress()
			end,
		})
		btn.root.Name = "Menu_" .. info.name
		-- the label may use the column gap, no more (a long word shrinks instead of touching the next)
		local label = btn.root:FindFirstChild("Label") :: TextLabel
		label.Size = UDim2.new(1, mm.colGap - 2, 0, mm.label)
		btn.root.LayoutOrder = i
		buttons[info.name] = btn
		if pulseName == info.name then
			startPulse(btn.root, info.name)
		end
		if info.name == "Boat" then
			onPress = dressBoat(btn)
		elseif info.name == "Home" then
			onPress = dressHome(btn)
		elseif info.name == "Map" then
			onPress = function()
				Menu.close()
				if MapController.IsOpen() then
					MapController.Close()
				else
					MapController.Open()
				end
			end
		else
			onPress = function()
				Menu.toggle(info.name)
			end
		end
	end
	questBadge()
	chrome()
end

local function buildSale(region: Frame)
	if sale then
		sale:Destroy()
	end
	local mm = Layout.current().menu
	local side, row, pillH = mm.icon, mm.label, 30
	local btn = IconButton.new(region, {
		icon = "shop",
		label = "Starter",
		color = "blue",
		size = side,
		labelRow = row,
		onActivate = function()
			Menu.open("Shop")
			if current == "Shop" then
				panels.Shop.focus(SALE_KEY)
			end
		end,
	})
	local root = btn.root
	root.Name = "SaleButton"
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Position = UDim2.new(0.5, 0, 0, 14) -- room above for the tag
	root.Size = UDim2.new(1, 0, 0, side + row + 4 + pillH) -- the clock pill is part of the tap target
	local tile = root:FindFirstChild("Tile") :: Frame
	tile.Position = UDim2.new(0.5, -side / 2, 0, 0)
	local label = root:FindFirstChild("Label") :: TextLabel
	label.Position = UDim2.new(0.5, 0, 0, side + row + 2)
	-- the pass's own store icon over the placeholder glyph (the Shop reads it the same way)
	local face = tile:FindFirstChild("Face", true) :: Frame
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(saleItem.id, Enum.InfoType.GamePass)
		end)
		local id = if ok and type(info) == "table" then info.IconImageAssetId else nil
		if type(id) == "number" and id > 0 and face.Parent then
			local img = Instance.new("ImageLabel")
			img.Name = "PassIcon"
			img.BackgroundTransparency = 1
			img.Image = `rbxassetid://{id}`
			img.AnchorPoint = Vector2.new(0.5, 0.5)
			img.Position = UDim2.fromScale(0.5, 0.5)
			img.Size = UDim2.new(1, -6, 1, -6)
			img.ZIndex = 2
			Style.corner(img, Theme.Size.corner)
			img.Parent = face
		end
	end)

	-- the red SALE sticker, tilted on the tile's top-left corner: white rim, ink outline, red face
	local tag = Instance.new("Frame")
	tag.Name = "SaleTag"
	tag.BackgroundColor3 = Color3.new(1, 1, 1)
	tag.AnchorPoint = Vector2.new(0.5, 0.5)
	tag.Position = UDim2.new(0.5, -side / 2 + 16, 0, 2)
	tag.Size = UDim2.fromOffset(66, 30)
	tag.Rotation = -8
	tag.ZIndex = 4
	Style.corner(tag, 10)
	Style.stroke(tag, 3, true)
	local red = Instance.new("Frame")
	red.BackgroundColor3 = Color3.new(1, 1, 1)
	red.Position = UDim2.fromOffset(3, 3)
	red.Size = UDim2.new(1, -6, 1, -6)
	red.ZIndex = 4
	Style.corner(red, 8)
	Style.gradient(red, Style.grad("red"))
	red.Parent = tag
	local word = Style.label(red, "SALE", Theme.Text.small)
	word.TextWrapped = false
	word.TextScaled = true
	word.ZIndex = 5
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = Theme.Text.small
	cap.Parent = word
	tag.Parent = root

	-- the dark clock pill under the label
	local pill = Instance.new("Frame")
	pill.Name = "Clock"
	pill.BackgroundColor3 = Color3.new(1, 1, 1)
	pill.AnchorPoint = Vector2.new(0.5, 1)
	pill.Position = UDim2.fromScale(0.5, 1)
	pill.Size = UDim2.new(1, 0, 0, pillH)
	Style.corner(pill, 10)
	Style.gradient(pill, Style.grad("ink"))
	Style.stroke(pill, 2, true)
	local list = Style.list(pill, true, 4)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	local glyph = Instance.new("Frame")
	glyph.BackgroundTransparency = 1
	glyph.Size = UDim2.fromOffset(20, 20)
	glyph.LayoutOrder = 1
	glyph.Parent = pill
	Style.icon(glyph, "daily")
	local clock = Style.label(pill, "", Theme.Text.small)
	clock.TextColor3 = Color3.fromHex("FFE066")
	clock.TextWrapped = false
	clock.AutomaticSize = Enum.AutomaticSize.X
	clock.Size = UDim2.fromScale(0, 1)
	clock.LayoutOrder = 2
	pill.Parent = root

	sale, saleClock = root, clock
	root.Visible = false
	paintSale()
end

local function buildChip(region: Frame)
	local b = Style.button(region, UDim2.fromScale(1, 1))
	b.Name = "QuestChip"
	local _, face =
		Style.block(b, Style.grad("orange"), { lip = 4, radius = Theme.Size.cornerSmall })
	local art = Instance.new("Frame")
	art.BackgroundColor3 = Color3.new(1, 1, 1)
	art.BackgroundTransparency = 0.15
	Style.corner(art, 999)
	art.AnchorPoint = Vector2.new(0, 0.5)
	art.Position = UDim2.new(0, 6, 0.5, 0)
	art.Size = UDim2.fromScale(0.8, 0.8)
	art.SizeConstraint = Enum.SizeConstraint.RelativeYY
	art.Parent = face
	local place = Style.label(face, "", Theme.Text.small)
	place.AnchorPoint = Vector2.new(0, 0.5)
	place.Position = UDim2.new(0.2, 4, 0.5, 0)
	place.Size = UDim2.fromScale(0.48, 0.56)
	place.TextScaled = true
	place.TextXAlignment = Enum.TextXAlignment.Left
	local dist = Style.label(face, "", Theme.Text.small)
	dist.AnchorPoint = Vector2.new(1, 0.5)
	dist.Position = UDim2.new(1, -8, 0.5, 0)
	dist.Size = UDim2.fromScale(0.24, 0.44)
	dist.TextScaled = true
	dist.TextXAlignment = Enum.TextXAlignment.Right
	Style.press(b, function()
		Menu.open("Quests")
	end, Theme.Size.cornerSmall)
	chip = b

	local shownKey = ""
	local function paint()
		local quest = QuestData.byId[player:GetAttribute("QuestId") :: any]
		if not quest then
			return
		end
		local back = player:GetAttribute("QuestStage") == "back"
		local id, name = QuestRules.place(quest)
		if back then
			name = QuestData.npcById[quest.npc].name
		end
		local key = `{quest.id}:{back}`
		if key ~= shownKey then
			shownKey = key
			for _, ch in art:GetChildren() do
				if not ch:IsA("UICorner") then
					ch:Destroy()
				end
			end
			local sticker = Stickers[id]
			if sticker and not back then
				local img = Instance.new("ImageLabel")
				img.BackgroundTransparency = 1
				img.Image = sticker
				img.ScaleType = Enum.ScaleType.Fit
				img.Size = UDim2.fromScale(1, 1)
				img.Parent = art
			else
				Style.icon(art, "quests")
			end
			place.Text = name
		end
		local target = player:GetAttribute("QuestTarget")
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		dist.Text = if typeof(target) == "Vector3"
				and root
				and root:IsA("BasePart")
			then Waypoint.metres((root.Position - target).Magnitude)
			else ""
	end
	task.spawn(function()
		while b.Parent do
			if b.Visible then
				paint()
			end
			task.wait(0.25)
		end
	end)
	player.AttributeChanged:Connect(function(name)
		if name == "QuestId" or name == "QuestStage" then
			chrome()
			paint()
		end
	end)
	chrome()
end

function Menu.mount()
	if mounted then
		return
	end
	mounted = true
	SettingsPanel.mount()

	local g = Instance.new("ScreenGui")
	g.Name = "Menu"
	g.ResetOnSpawn = false
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.DisplayOrder = 30
	Layout.prepare(g)
	g.Parent = player:WaitForChild("PlayerGui")
	local region = Layout.region(g, "menu")
	buildBar(region)
	Layout.onMetrics(function()
		buildBar(region)
	end)

	local c = Style.canvas(g) -- the panels, in kit units over the safe area
	panels = {
		Boat = BoatCard.new(c, noteClosed),
		Shop = Shop.new(c, noteClosed),
		Quests = Quests.new(c, noteClosed),
		Album = Album.new(c, noteClosed),
		Companion = Companion.new(c, noteClosed),
		Crew = Crew.new(c, noteClosed),
		Skills = Skills.new(c, noteClosed),
		Settings = SettingsPanel.newPanel(c, noteClosed),
	}
	local boards: { [string]: string } =
		{ BoatBoard = "Boats", HangarBoard = "Helicopter", SubBoard = "Submarine" }
	for rack, title in boards do
		panels["Board_" .. rack] = Board.new(c, noteClosed, rack, title, Menu.openBoat)
	end
	buildChip(Layout.region(g, "quest"))
	local saleRegion = Layout.region(g, "sale")
	buildSale(saleRegion)
	Layout.onMetrics(function()
		buildSale(saleRegion)
	end)
	player:GetAttributeChangedSignal("Pass_" .. SALE_KEY):Connect(paintSale)
	task.spawn(function() -- the clock ticks; past saleEndsUtc the button hides
		while
			sale
			and saleItem.saleEndsUtc
			and Workspace:GetServerTimeNow() < saleItem.saleEndsUtc
		do
			task.wait(1)
			paintSale()
		end
		paintSale()
	end)

	local function applyShown()
		if not shown() then
			Menu.close()
		end
		chrome()
	end
	Layout.onColdOpen(applyShown)
	player:GetAttributeChangedSignal("CinematicPlaying"):Connect(applyShown)
	player:GetAttributeChangedSignal("BuildHidesMenu"):Connect(chrome)
	player:GetAttributeChangedSignal("MapOpen"):Connect(function()
		if player:GetAttribute("MapOpen") == true then
			Menu.close() -- M over an open panel: the map wins
		end
		chrome()
	end)
	player.AttributeChanged:Connect(function(name)
		if string.sub(name, 1, 5) == "Quest" then
			questBadge()
		end
	end)
	task.spawn(function() -- givers moor and sail off with no attribute of yours changing
		while true do
			task.wait(1)
			questBadge()
		end
	end)

	if RunService:IsStudio() then -- smoke driver: Workspace attribute MenuPanel = a panel name or "Boat:<id>" ("" closes)
		Workspace:GetAttributeChangedSignal("MenuPanel"):Connect(function()
			local name = Workspace:GetAttribute("MenuPanel")
			if type(name) == "string" and string.sub(name, 1, 5) == "Boat:" then
				Menu.openBoat(string.sub(name, 6))
			elseif type(name) == "string" and panels[name] then
				Menu.open(name)
			else
				Menu.close()
			end
		end)
	end

	ContextActionService:BindActionAtPriority(
		"Menu_Keys",
		function(_, state, input)
			if state ~= Enum.UserInputState.Begin or UserInputService:GetFocusedTextBox() then
				return Enum.ContextActionResult.Pass
			end
			local key = input.KeyCode
			if key == Enum.KeyCode.ButtonB then
				if current then
					Menu.close()
					return Enum.ContextActionResult.Sink
				end
				local sel = GuiService.SelectedObject
				if bar and sel and sel:IsDescendantOf(bar) then
					GuiService.SelectedObject = nil
					return Enum.ContextActionResult.Sink
				end
				return Enum.ContextActionResult.Pass
			end
			if not shown() or MapController.IsOpen() and key ~= Enum.KeyCode.P then
				return Enum.ContextActionResult.Pass
			end
			if key == Enum.KeyCode.P then
				Menu.toggle("Shop")
			elseif key == Enum.KeyCode.ButtonStart then
				Menu.toggle("Settings")
			elseif key == Enum.KeyCode.DPadLeft then
				if current or not bar or GuiService.SelectedObject then
					return Enum.ContextActionResult.Pass -- D-pad already moves the selection
				end
				focusFirst(bar)
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value + 10,
		Enum.KeyCode.P,
		Enum.KeyCode.ButtonStart,
		Enum.KeyCode.ButtonB,
		Enum.KeyCode.DPadLeft
	)
end

return Menu
