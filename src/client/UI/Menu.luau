--!strict
-- Menu: the kit left button bar and the six windows (Shop, Quests, Album, Companion, Crew,
-- Settings), plus the separate Boat-to-me call on the right. Mounted once by HudController.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationEffects = require(Shared:WaitForChild("MonetizationEffects"))
local Net = require(Shared:WaitForChild("Net"))
local QuestData = require(Shared:WaitForChild("Quests"):WaitForChild("Data"))
local Telemetry = require(script.Parent.Parent:WaitForChild("Telemetry"))

local Layout = require(script.Parent:WaitForChild("Layout"))
local Kit = script.Parent:WaitForChild("Kit")
local Album = require(script.Parent:WaitForChild("Panels"):WaitForChild("Album"))
local BoatCard = require(script.Parent:WaitForChild("BoatCard"))
local Companion = require(script.Parent:WaitForChild("Panels"):WaitForChild("Companion"))
local Crew = require(script.Parent:WaitForChild("Panels"):WaitForChild("Crew"))
local IconButton = require(Kit:WaitForChild("IconButton"))
local Quests = require(script.Parent:WaitForChild("Panels"):WaitForChild("Quests"))
local SettingsPanel = require(script.Parent:WaitForChild("SettingsPanel"))
local Shop = require(script.Parent:WaitForChild("Panels"):WaitForChild("Shop"))
local Style = require(Kit:WaitForChild("Style"))
local Theme = require(Kit:WaitForChild("Theme"))

local player = Players.LocalPlayer
local S = Theme.Size
local BUTTONS = {
	{ name = "Shop", label = "Shop", icon = "shop", color = "yellow" },
	{ name = "Quests", label = "Quests", icon = "quests", color = "orange" },
	{ name = "Album", label = "Album", icon = "album", color = "pink" },
	{ name = "Companion", label = "Buddy", icon = "companion", color = "purple" },
	{ name = "Crew", label = "Crew", icon = "crew", color = "teal" },
	{ name = "Settings", label = "Settings", icon = "settings", color = "blue" },
}

local Menu = {}

local gui: ScreenGui? = nil
local canvas: Frame? = nil
local bar: Frame? = nil
local boat: IconButton.IconButton? = nil
local panels: { [string]: any } = {}
local buttons: { [string]: IconButton.IconButton } = {}
local current: string? = nil
local mounted = false

local function chrome(on: boolean)
	if bar then
		bar.Visible = on
	end
	if boat then
		boat.root.Visible = on
	end
end

local function focusPanel(name: string)
	if not UserInputService.GamepadEnabled then
		return
	end
	local p = panels[name]
	if not p then
		return
	end
	for _, d in p.root:GetDescendants() do
		if d:IsA("GuiButton") and d.Selectable and d.Visible and d.Active ~= false then
			GuiService.SelectedObject = d
			return
		end
	end
end

function Menu.isOpen(): boolean
	return current ~= nil
end

function Menu.isAnyPanelOpen(): boolean
	return current ~= nil
end

local function noteClosed()
	current = nil
	if not Layout.coldOpen() and player:GetAttribute("CinematicPlaying") ~= true then
		chrome(true)
	end
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
	noteClosed()
end

function Menu.open(name: string)
	if not mounted then
		return
	end
	if Layout.coldOpen() or player:GetAttribute("CinematicPlaying") == true then
		return
	end
	local p = panels[name]
	if not p then
		return
	end
	if current == name then
		Menu.close()
		return
	end
	if current then
		local old = panels[current]
		current = nil
		if old then
			old.close()
		end
	end
	current = name
	chrome(false)
	p.open()
	Telemetry.shop("PhoneOpened")
	task.defer(focusPanel, name)
end

function Menu.openBoat(id: string)
	local card = panels.Boat
	if not card then
		return
	end
	card.setId(id)
	Menu.open("Boat")
end

function Menu.toggle(name: string)
	if current == name then
		Menu.close()
	else
		Menu.open(name)
	end
end

local function quick(): boolean
	local ends = player:GetAttribute("DayPass_QuickLaunch")
	return MonetizationEffects.passActive(
		player:GetAttribute("Pass_QuickLaunch") == true,
		if type(ends) == "number" then ends else nil,
		Workspace:GetServerTimeNow()
	)
end

local function buildBoat(parent: Frame)
	local b: IconButton.IconButton
	local sending = false
	b = IconButton.new(parent, {
		icon = "boat_to_me",
		label = "Boat",
		color = "green",
		onActivate = function()
			if sending or b.root.Active == false then
				return
			end
			sending = true
			b.root.Active = false
			local text = b.root:FindFirstChild("Label")
			if text and text:IsA("TextLabel") then
				text.Text = "…"
			end
			task.spawn(function()
				local ok, done, result = pcall(function()
					return Net.func("RequestVehicle"):InvokeServer(nil, false, true)
				end)
				sending = false
				if ok and done then
					return
				end
				local why = if ok and type(result) == "string" then result else "Try again"
				if text and text:IsA("TextLabel") then
					text.Text = if why == "Cooldown" then "Wait" else "Try again"
				end
				task.delay(1.6, function()
					if text and text:IsA("TextLabel") then
						text.Text = "Boat"
					end
				end)
			end)
		end,
	})
	b.root.Name = "BoatToMe"
	b.root.AnchorPoint = Vector2.new(1, 0.5)
	b.root.Position = UDim2.new(1, -S.margin, 0.5, 0)
	boat = b

	local function paint()
		if sending then
			return
		end
		local last = player:GetAttribute("BoatToMeAt")
		local now = Workspace:GetServerTimeNow()
		local cooldown = MonetizationEffects.BOAT_TO_ME_COOLDOWN
		local left = if quick()
			then 0
			else math.max(0, (if type(last) == "number" then last else 0) + cooldown - now)
		b.root.Active = left <= 0
		local text = b.root:FindFirstChild("Label")
		if text and text:IsA("TextLabel") and text.Text ~= "Try again" then
			text.Text = if left > 0 then `{math.ceil(left)}s` else "Boat"
		end
	end
	paint()
	RunService.Heartbeat:Connect(function()
		if b.root.Visible then
			paint()
		end
	end)
end

local function questBadge()
	local n = 0
	for _, npc in QuestData.Npcs do
		if player:GetAttribute(`QuestOffer_{npc.id}`) then
			n += 1
		end
	end
	local q = buttons.Quests
	if q then
		q.setBadge(if n > 0 then n else nil)
	end
end

function Menu.mount()
	if mounted then
		return
	end
	mounted = true
	SettingsPanel.mount()

	local playerGui = player:WaitForChild("PlayerGui")
	local g = Instance.new("ScreenGui")
	g.Name = "Menu"
	g.ResetOnSpawn = false
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.DisplayOrder = 30
	Layout.prepare(g)
	gui = g
	g.Parent = playerGui
	local c = Style.canvas(g)
	canvas = c

	local b = Instance.new("Frame")
	b.Name = "ButtonBar"
	b.BackgroundTransparency = 1
	b.AnchorPoint = Vector2.new(0, 0.5)
	b.Position = UDim2.new(0, S.margin, 0.5, 0)
	b.Parent = c
	bar = b
	local grid = Instance.new("UIGridLayout")
	grid.Name = "Grid"
	grid.FillDirection = Enum.FillDirection.Vertical
	grid.CellSize = UDim2.fromOffset(S.icon, S.icon + S.iconLabel)
	grid.CellPadding = UDim2.fromOffset(S.iconGap, S.iconGap)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = b

	for i, info in BUTTONS do
		local btn = IconButton.new(b, {
			icon = info.icon,
			label = info.label,
			color = info.color,
			onActivate = function()
				Menu.toggle(info.name)
			end,
		})
		btn.root.LayoutOrder = i
		buttons[info.name] = btn
	end

	local function fitBar()
		local vp, scale = Style.metrics(b)
		local rows =
			math.max(1, math.floor(vp.Y * 0.86 / scale / (S.icon + S.iconLabel + S.iconGap)))
		local cols = math.ceil(#BUTTONS / rows)
		grid.FillDirectionMaxCells = rows
		grid.CellSize = UDim2.fromOffset(S.icon, S.icon + S.iconLabel)
		b.Size = UDim2.fromOffset(
			cols * S.icon + (cols - 1) * S.iconGap,
			math.min(rows, #BUTTONS) * (S.icon + S.iconLabel)
				+ (math.min(rows, #BUTTONS) - 1) * S.iconGap
		)
	end
	fitBar()
	c:GetAttributeChangedSignal("KitScale"):Connect(fitBar)

	buildBoat(c)

	panels = {
		Boat = BoatCard.new(c, noteClosed),
		Shop = Shop.new(c, noteClosed),
		Quests = Quests.new(c, noteClosed),
		Album = Album.new(c, noteClosed),
		Companion = Companion.new(c, noteClosed),
		Crew = Crew.new(c, noteClosed),
		Settings = SettingsPanel.newPanel(c, noteClosed),
	}

	local function visible()
		return not Layout.coldOpen() and player:GetAttribute("CinematicPlaying") ~= true
	end
	local function applyVisible()
		if not visible() then
			Menu.close()
		end
		chrome(visible() and current == nil)
	end
	Layout.onColdOpen(function()
		applyVisible()
	end)
	player:GetAttributeChangedSignal("CinematicPlaying"):Connect(applyVisible)
	applyVisible()

	questBadge()
	player.AttributeChanged:Connect(function(name)
		if string.sub(name, 1, 10) == "QuestOffer" then
			questBadge()
		end
	end)

	ContextActionService:BindActionAtPriority(
		"Menu_Keys",
		function(_, state, input)
			if state ~= Enum.UserInputState.Begin or UserInputService:GetFocusedTextBox() then
				return Enum.ContextActionResult.Pass
			end
			if input.KeyCode == Enum.KeyCode.ButtonB then
				if current then
					Menu.close()
					return Enum.ContextActionResult.Sink
				end
				return Enum.ContextActionResult.Pass
			end
			if not visible() then
				return Enum.ContextActionResult.Pass
			end
			if input.KeyCode == Enum.KeyCode.P then
				Menu.toggle("Shop")
				return Enum.ContextActionResult.Sink
			end
			if input.KeyCode == Enum.KeyCode.ButtonStart then
				Menu.toggle("Settings")
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end,
		false,
		Enum.ContextActionPriority.High.Value + 10,
		Enum.KeyCode.P,
		Enum.KeyCode.ButtonStart,
		Enum.KeyCode.ButtonB
	)
end

function Menu.gui(): ScreenGui?
	return gui
end

function Menu.canvas(): Frame?
	return canvas
end

return Menu
