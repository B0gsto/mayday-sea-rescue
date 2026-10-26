--!strict
-- Menu (docs/23 (m), WP-23c): the left button column and its kit panels. Mounted once by HudController.
--   Grid (HudLayout "menu" region: 2 icon columns above the thumbstick): Shop, Quests,
--   Album, Pet, Crew, Settings, Map and Boat (Boat to me: the server's cooldown rule with the Mechanics' shorter wait, drawn as
--   a ring of ticks; Quick Launch shows the bolt and skips it). Each opens a centred kit Panel; Map
--   opens the full map (MapController, also M).
--   Keys: P Shop, gamepad Start Settings, D-pad Left focuses the column (D-pad moves, A presses),
--   B closes the open panel or leaves the column.
--   LocalPlayer attribute MenuOpen mirrors "a panel is up" (Waypoint and the pager hide under it).
--   Menu.open(name) / Menu.close() / Menu.toggle(name) / Menu.openBoat(vehicleId) / Menu.isOpen()
--   Menu.openBoard(rack): a craft board's list (Panels/Board), from its BoardOpen prompt
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationEffects = require(Shared:WaitForChild("MonetizationEffects"))
local Net = require(Shared:WaitForChild("Net"))
local QuestData = require(Shared:WaitForChild("Quests"):WaitForChild("Data"))
local QuestRules = require(Shared:WaitForChild("Quests"):WaitForChild("Rules"))
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
	{ name = "Settings", label = "Settings", icon = "settings", color = "blue" },
	{ name = "Map", label = "Map", icon = "map", color = "green" },
	{ name = "Boat", label = "Boat", icon = "boat_to_me", color = "red" },
}

local Menu = {}

local bar: Frame? = nil
local chip: GuiObject? = nil -- the quest tracker (HudLayout "quest"): icon, place, distance; tap opens Quests
local panels: { [string]: any } = {}
local buttons: { [string]: IconButton.IconButton } = {}
local current: string? = nil
local mounted = false
local pulseName: string? = nil

-- docs/24 E: a pulsing ring on the one button the tutorial asks for, and nothing else.
local function startPulse(root: GuiObject, name: string)
	local ring = Instance.new("Frame")
	ring.Name = "PulseRing"
	ring.BackgroundTransparency = 1
	ring.Position = UDim2.fromOffset(-4, -4)
	ring.Size = UDim2.new(1, 8, 1, 8)
	ring.Parent = root
	Style.corner(ring, Theme.Size.corner + 8)
	local stroke = Style.stroke(ring, 4, true)
	stroke.Color = GOLD
	local scale = Instance.new("UIScale")
	scale.Name = "PulseScale"
	scale.Parent = ring
	task.spawn(function()
		while root.Parent and pulseName == name do
			TweenService:Create(
				scale,
				TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ Scale = 1.1 }
			):Play()
			TweenService:Create(
				stroke,
				TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ Transparency = 0.35 }
			):Play()
			task.wait(0.5)
			TweenService:Create(
				scale,
				TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ Scale = 1 }
			):Play()
			TweenService:Create(
				stroke,
				TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ Transparency = 0 }
			):Play()
			task.wait(0.5)
		end
		ring:Destroy()
	end)
end

function Menu.pulse(name: string?)
	pulseName = name
	if name then
		local b = buttons[name]
		if b and not b.root:FindFirstChild("PulseRing") then
			startPulse(b.root, name)
		end
	end
end

local function shown(): boolean
	return not Layout.coldOpen() and player:GetAttribute("CinematicPlaying") ~= true
end

local function chrome()
	if bar then
		bar.Visible = shown() and current == nil
	end
	if chip then
		chip.Visible = shown()
			and current == nil
			and player:GetAttribute("MapOpen") ~= true
			and QuestData.byId[player:GetAttribute("QuestId") :: any] ~= nil
	end
	player:SetAttribute("MenuOpen", current ~= nil)
end

local function focusFirst(root: Instance)
	if not UserInputService.GamepadEnabled then
		return
	end
	for _, d in root:GetDescendants() do
		if d:IsA("GuiButton") and d.Selectable and d.Visible then
			GuiService.SelectedObject = d
			return
		end
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
	p.open()
	Telemetry.shop("MenuOpened") -- a menu panel opened
	task.defer(focusFirst, p.root)
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

-- Seated in a craft (the server answers "Occupied"): the Boat tile rests grey and wordless, no error.
local function aboard(): boolean
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	local craft = seat and seat:FindFirstAncestorWhichIsA("Model")
	while craft and craft:GetAttribute("VehicleId") == nil do
		craft = craft:FindFirstAncestorWhichIsA("Model")
	end
	return craft ~= nil
end

-- The Boat button's extras: a ring of ticks round the tile that fills back up over the cooldown
-- (the tile greys while it waits), a gold bolt with Quick Launch. Press: your craft comes to you.
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
	local bolt = Instance.new("TextLabel")
	bolt.Name = "Bolt"
	bolt.BackgroundTransparency = 1
	bolt.Text = "⚡"
	bolt.TextScaled = true
	bolt.TextColor3 = GOLD
	bolt.AnchorPoint = Vector2.new(1, 0)
	bolt.Position = UDim2.new(1, 6, 0, -8)
	bolt.Size = UDim2.fromScale(0.42, 0.42)
	bolt.ZIndex = 4
	Style.stroke(bolt, 2.5)
	bolt.Parent = tile
	local label = b.root:FindFirstChild("Label") :: TextLabel
	local waiting: boolean? = nil
	local sending = false
	local flash = 0
	local function paint()
		local left, cooldown = boatWait()
		local wait = left > 0
		local seated = aboard()
		if (wait or seated) ~= waiting then
			waiting = wait or seated
			Style.recolor(holder, Style.grad(if waiting then "disabled" else "red"))
		end
		local lit = math.floor((1 - left / cooldown) * #ticks)
		for i, t in ticks do
			t.Visible = wait and i <= lit
		end
		bolt.Visible = quick()
		if os.clock() > flash then
			label.Text = if sending
				then "…"
				elseif wait then `{math.ceil(left)}s`
				elseif seated then ""
				else "Boat"
		end
	end
	RunService.Heartbeat:Connect(function()
		if b.root.Visible and b.root:IsDescendantOf(game) then
			paint()
		end
	end)
	return function()
		if sending or boatWait() > 0 or aboard() then
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

-- the quest cards you can act on now (the tablet's rows: an offer you can accept, a quest ready to hand in)
local function questBadge()
	local n = 0
	for _, r in QuestTablet.rows(true) do
		if r.ready and r.action ~= "drop" then
			n += 1
		end
	end
	local q = buttons.Quests
	if q then
		q.setBadge(if n > 0 then n else nil)
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
		Settings = SettingsPanel.newPanel(c, noteClosed),
	}
	local boards: { [string]: string } =
		{ BoatBoard = "Boats", HangarBoard = "Helicopter", SubBoard = "Submarine" }
	for rack, title in boards do
		panels["Board_" .. rack] = Board.new(c, noteClosed, rack, title, Menu.openBoat)
	end
	buildChip(Layout.region(g, "quest"))

	local function applyShown()
		if not shown() then
			Menu.close()
		end
		chrome()
	end
	Layout.onColdOpen(applyShown)
	player:GetAttributeChangedSignal("CinematicPlaying"):Connect(applyShown)
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
