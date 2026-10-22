--!strict
-- Phone: the player's phone and the home of every menu (docs/14 §6, RP-PH1; playtest 2026-10-21:
-- "a portrait iPhone"). P, gamepad L1 or the phone button on the left of the HUD opens it: an
-- upright handset (thin bezel, Dynamic Island, status bar, home indicator) centred and nearly as
-- tall as the screen slides up with a spring, the screen wakes and the icons pop in; closing plays
-- it back (a short fade with reduced motion). The phone-in-hand Viewmodel loop plays and a Modal
-- backdrop frees the cursor. The home screen is stock iOS: a soft gradient wallpaper, a 4-column
-- grid of squircle icons (UiImages.Phone art, small white label) and a frosted
-- dock of 4. Every app lays out on the upright phone.
-- Apps:
--   Map, Radio, Camera   close the phone and run (MapController.Open, Radio repeat, PhotoMode)
--   Logbook, Season, Settings   the existing panels (ExplorationController's Logbook, SeasonBook,
--                        SettingsPanel): their frames are borrowed onto the phone screen
--   Events               EventBoard.buildPhone rows (EventBoardController pushes them)
--   Crew                 the crew's faces (leader ringed in brass), Invite and Leave
--   Crew Pay, Pay Rise   StationController.mountPay / mountRise (station pot and workshop)
--   Vehicles, Store      sibling modules UI/VehiclesApp, UI/StoreApp (see OPTIONAL below): each
--                        `mount(page: Frame, close: () -> ()) -> (() -> ())?` (the cleanup). A
--                        missing or broken module just leaves its icon out.
-- Back: the chevron, the home indicator, gamepad B, Backspace or Escape; at home they close it.
-- J (on foot) / gamepad L3 open the Logbook app, gamepad Start the Settings app. A red dot and a
-- bounce on the phone button: an event is on now.
--   Phone.mount(statusRegion)   HudController calls this once (the button goes in the Hud's
--                               "phone" region, HudLayout)
--   Phone.setOpen(open) / Phone.isOpen() / Phone.openApp(name) / Phone.openEvents()
--   Phone.setEventRows(rows)    EventBoardController pushes the EventCalendar rows once a second
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Client = script.Parent.Parent
local Controllers = Client:WaitForChild("Controllers")
local Comfort = require(Client:WaitForChild("Camera"):WaitForChild("Comfort"))
local EventBoard = require(script.Parent:WaitForChild("EventBoard"))
local HudTheme = require(script.Parent:WaitForChild("HudTheme"))
local InputGlyph = require(script.Parent:WaitForChild("InputGlyph"))
local Layout = require(script.Parent:WaitForChild("Layout"))
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local Viewmodel = require(Client:WaitForChild("Camera"):WaitForChild("Viewmodel"))

local C = HudTheme.Colors
local W = Color3.new(1, 1, 1)
local V = Vector2.new
local player = Players.LocalPlayer

-- the HUD button and app icons: assets/ui/phone_v2, full squircle tiles keyed by app name
local PHONE_IMAGES = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UiImages")
).Phone

-- Sibling app modules, required only if present: `mount(page, close) -> cleanup?`. Register another app by adding a row (grid order = list order).
local OPTIONAL = {
	{ module = "VehiclesApp", name = "Vehicles", label = "Vehicles" },
	{ module = "StoreApp", name = "Store", label = "Store" },
}
local DOCK = { Map = 1, Radio = 2, Vehicles = 3, Camera = 4 } -- the dock's 4, in order
local CANVAS = 300 -- du: the upright screen's width; home and apps lay out on it
local ICON = 58 -- du, the squircle
local CELL_W, CELL_H = 68, 86
local DISPLAY_ORDER = 36 -- above the store panels (35), below CashBurst (41) and Cinematic (50)
local MARGIN = 12 -- du around the handset
local BEZEL = 9 -- du
local STATUS_H = 46 -- du, the status bar
local HOME_H = 26 -- du, the home indicator strip
local ISLAND = V(96, 28) -- du, the Dynamic Island upright
local ASPECT = 2.17 -- a modern handset
local OFF = UDim2.fromScale(0.5, 1.65)
local ON = UDim2.fromScale(0.5, 0.5)

type Mount = (page: Frame, close: () -> ()) -> any
type App = {
	name: string,
	label: string,
	run: (() -> ())?,
	mount: Mount?,
}
type Tile = { button: TextButton, scale: UIScale, label: TextLabel? }

local Phone = {}

local gui: ScreenGui? = nil
local backdrop: TextButton
local rig: Frame
local rigScale: UIScale
local body: Frame
local bodyScale: UIScale
local screen: Frame
local screenScale: UIScale
local island: Frame
local wake: Frame
local home: Frame
local appBg: Frame
local appPage: Frame
local pageScale: UIScale
local content: Frame
local backButton: TextButton
local clockLabel: TextLabel
local badge: Frame
local bounce: (() -> ())? = nil
local tiles: { Tile } = {}
local keys: { { edge: string, at: number, len: number, frame: Frame } } = {}
local byName: { [string]: App } = {}
local open = false
local serial = 0
local current: string? = nil
local cleanup: (() -> ())? = nil
local relayout: (() -> ())? = nil
local hand: Viewmodel.Handle? = nil
local crew: { number } = {}
local leader = 0
local drawCrew: (() -> ())? = nil
local eventBoard: EventBoard.Board? = nil
local pendingRows: { any }? = nil
local portraitSize = V(320, 694) -- du, set by fit

local function tween(
	obj: Instance,
	t: number,
	props: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?,
	delay: number?
): Tween
	local tw = TweenService:Create(
		obj,
		TweenInfo.new(
			t,
			style or Enum.EasingStyle.Quint,
			dir or Enum.EasingDirection.Out,
			0,
			false,
			delay or 0
		),
		props
	)
	tw:Play()
	return tw
end

-- a shape centred at (x, y), sized (w, h), all in the parent's scale
local function box(
	parent: Instance,
	color: Color3,
	x: number,
	y: number,
	w: number,
	h: number,
	r: number?
): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	if r then
		HudTheme.corner(f, r)
	end
	f.Parent = parent
	return f
end

local function gradient(parent: Instance, a: Color3, b: Color3, rotation: number): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(a, b)
	g.Rotation = rotation
	g.Parent = parent
	return g
end

local function focus(obj: GuiObject?)
	-- a keyboard user who has started navigating (an arrow or Return, see shortcut) keeps a selection
	if obj and (UserInputService.GamepadEnabled or GuiService.SelectedObject ~= nil) then
		GuiService.SelectedObject = obj
	end
end

-- the first button a gamepad can land on inside `root`
local function firstButton(root: Instance): GuiObject?
	for _, d in root:GetDescendants() do
		if d:IsA("GuiButton") and d.Selectable and d.Visible then
			local shown = true
			local p = d.Parent
			while p and p ~= root do
				if p:IsA("GuiObject") and not p.Visible then
					shown = false
					break
				end
				p = p.Parent
			end
			if shown then
				return d
			end
		end
	end
	return nil
end

local function popIcons(delay: number)
	local reduced = Comfort.reducedMotion()
	for i, t in tiles do
		local label = t.label
		if reduced then
			t.scale.Scale = 1
			if label then
				label.TextTransparency = 0
			end
		else
			t.scale.Scale = 0.2
			local at = delay + (i - 1) * 0.028
			tween(t.scale, 0.42, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, at)
			if label then
				label.TextTransparency = 1
				tween(label, 0.3, { TextTransparency = 0 }, nil, nil, at + 0.08)
			end
		end
	end
end

-- A du can draw at 0.7 px on a short landscape phone: icon labels grow there to stay >= 12.5 px.
local function sizeLabels()
	local px = rigScale.Scale * screenScale.Scale
	local size = HudTheme.scaled(math.max(13, math.ceil(12.5 / px)))
	for _, t in tiles do
		local l = t.label
		if l then
			l.TextSize = size
			l.Size = UDim2.new(1, 12, 0, size + 3)
		end
	end
end

-- Lays the upright handset out: the slab's size, the screen's canvas, the island, the side keys
-- and the app page's insets.
local function orient()
	local size = portraitSize
	rig.Size = UDim2.fromOffset(size.X, size.Y)
	-- the screen is a CANVAS-wide canvas scaled to the slab, so the home looks the same anywhere
	local k = (size.X - 2 * BEZEL) / CANVAS
	screenScale.Scale = k
	screen.Size = UDim2.fromOffset(CANVAS, (size.Y - 2 * BEZEL) / k)
	island.AnchorPoint = Vector2.new(0.5, 0)
	island.Position = UDim2.new(0.5, 0, 0, 10)
	island.Size = UDim2.fromOffset(ISLAND.X, ISLAND.Y)
	content.Position = UDim2.fromOffset(16, 4)
	content.Size = UDim2.new(1, -32, 1, -8)
	sizeLabels()
	for _, key in keys do
		local f = key.frame
		local left = key.edge == "left"
		f.AnchorPoint = Vector2.new(if left then 1 else 0, 0.5)
		f.Position = UDim2.new(if left then 0 else 1, if left then 1 else -1, key.at, 0)
		f.Size = UDim2.fromOffset(4, key.len)
	end
end

local function closeApp()
	local undo = cleanup
	cleanup = nil
	relayout = nil
	current = nil
	if undo then
		local ok, err = pcall(function()
			undo()
		end)
		if not ok then
			warn("[Phone] app cleanup: " .. tostring(err))
		end
	end
	content:ClearAllChildren()
end

local function showHome()
	-- hiding the app clears a keyboard selection: read it first so focus() keeps navigating
	local navigating = GuiService.SelectedObject ~= nil
	if current then
		closeApp()
	end
	appPage.Visible = false
	appBg.Visible = false
	home.Visible = true
	backButton.Visible = false
	clockLabel.Visible = true
	popIcons(0)
	local first = tiles[1] and tiles[1].button
	if navigating then
		GuiService.SelectedObject = first
	else
		focus(first)
	end
end

local function back()
	if current then
		showHome()
	else
		Phone.setOpen(false)
	end
end

local function onBack(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		back()
	end
	return Enum.ContextActionResult.Sink
end

-- Shows a panel's own frame on the app page; the panel keeps its logic. Returns the undo.
-- shortcut: a viewport resize while borrowed restores the pre-resize size; the panel's next fit
-- corrects it.
local function borrow(root: GuiObject, page: Frame, fill: GuiObject): () -> ()
	local parent, anchor, pos, size = root.Parent, root.AnchorPoint, root.Position, root.Size
	local fillT = fill.BackgroundTransparency
	local edge = fill:FindFirstChildOfClass("UIStroke")
	local sc = root:FindFirstChildOfClass("UIScale")
	local scale = if sc then sc.Scale else 1
	local close = root:FindFirstChild("Close", true)
	local function place()
		root.AnchorPoint = Vector2.zero
		root.Position = UDim2.new()
		root.Size = UDim2.fromScale(1, 1)
		if sc then
			sc.Scale = 1 -- the handset already scales to the device
		end
	end
	place()
	relayout = place
	fill.BackgroundTransparency = 1
	if edge then
		edge.Enabled = false
	end
	if close and close:IsA("GuiObject") then
		close.Visible = false -- back is the phone's
	end
	root.Parent = page
	return function()
		root.Parent = parent
		root.AnchorPoint, root.Position, root.Size = anchor, pos, size
		if sc then
			sc.Scale = scale
		end
		fill.BackgroundTransparency = fillT
		if edge then
			edge.Enabled = true
		end
		if close and close:IsA("GuiObject") then
			close.Visible = true
		end
	end
end

-- an app that shows an existing panel: PlayerGui[guiName][frameName] (bgName: its backing panel)
local function panelApp(
	guiName: string,
	frameName: string,
	bgName: string?,
	controller: (() -> any)?
): Mount
	return function(page: Frame): () -> ()
		local host = player:WaitForChild("PlayerGui"):FindFirstChild(guiName)
		local root = host and host:FindFirstChild(frameName)
		if not root or not root:IsA("GuiObject") then
			return function() end
		end
		local bg = if bgName then root:FindFirstChild(bgName) else nil
		local ctl: any = if controller then controller() else nil
		if ctl then
			task.spawn(ctl.Open) -- Season's Open pulls the view (yields)
		end
		local undo = borrow(root, page, if bg and bg:IsA("GuiObject") then bg else root)
		-- the panel closed itself (its own Escape / B): back to the icons
		local watch = root:GetPropertyChangedSignal("Visible"):Connect(function()
			if not root.Visible and current then
				task.defer(showHome)
			end
		end)
		return function()
			watch:Disconnect()
			if ctl then
				ctl.Close()
			end
			undo()
		end
	end
end

local function pill(parent: Instance, name: string, text: string, color: Color3): TextButton
	local b = HudTheme.button(name, text, UDim2.new(1, 0, 0, 63), parent)
	b.BackgroundColor3 = color
	b.TextSize = 24
	HudTheme.corner(b, 18)
	gradient(b, Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200), 90)
	return b
end

local function crewApp(page: Frame): () -> ()
	local faces = Instance.new("Frame")
	faces.Name = "Faces"
	faces.BackgroundTransparency = 1
	faces.AnchorPoint = Vector2.new(0.5, 0)
	faces.Position = UDim2.new(0.5, 0, 0, 24)
	faces.Size = UDim2.fromOffset(250, 250)
	faces.Parent = page
	local grid = Instance.new("UIGridLayout") -- 2 x 2: crews are up to 4
	grid.CellSize = UDim2.fromOffset(112, 112)
	grid.CellPadding = UDim2.fromOffset(26, 26)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = faces

	-- Invite over Leave, at the foot of the page under the thumb
	local buttons = Instance.new("Frame")
	buttons.Name = "Buttons"
	buttons.BackgroundTransparency = 1
	buttons.AnchorPoint = Vector2.new(0.5, 1)
	buttons.Position = UDim2.new(0.5, 0, 1, -16)
	buttons.Size = UDim2.new(1, 0, 0, 138)
	buttons.Parent = page
	local row = Instance.new("UIListLayout")
	row.HorizontalAlignment = Enum.HorizontalAlignment.Center
	row.VerticalAlignment = Enum.VerticalAlignment.Bottom
	row.Padding = UDim.new(0, 12)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = buttons

	-- + friend (docs/15 H9): Roblox's own invite sheet. CanSendGameInviteAsync keeps platforms
	-- that cannot invite silent; the pcall keeps a social outage off the phone.
	local invite = pill(buttons, "Invite", "+ Invite", C.accent)
	invite.LayoutOrder = 1
	invite.Activated:Connect(function()
		task.spawn(function()
			local ok, can = pcall(function()
				return SocialService:CanSendGameInviteAsync(player)
			end)
			if ok and can then
				pcall(function()
					SocialService:PromptGameInvite(player)
				end)
			end
		end)
	end)
	local leave = pill(buttons, "Leave", "Leave", C.locked)
	leave.LayoutOrder = 2
	leave.Activated:Connect(function()
		Net.event("CrewLeave"):FireServer()
	end)

	local function draw()
		for _, c in faces:GetChildren() do
			if c:IsA("ImageLabel") then
				c:Destroy()
			end
		end
		local ids = if #crew > 0 then crew else { player.UserId }
		for i = 1, 4 do -- crews are up to 4 (CrewService)
			local id = ids[i]
			local face = Instance.new("ImageLabel")
			face.LayoutOrder = i
			face.BackgroundColor3 = C.panelLight
			face.BackgroundTransparency = if id then 0 else 0.7
			face.Image = if id then `rbxthumb://type=AvatarHeadShot&id={id}&w=150&h=150` else ""
			HudTheme.corner(face, 99)
			HudTheme.stroke(
				face,
				if id and id == leader then C.gold else C.edge,
				if id == leader then 4 else 1
			)
			face.Parent = faces
		end
		leave.Visible = #crew > 0
	end
	draw()
	drawCrew = draw
	return function()
		drawCrew = nil
	end
end

local function eventsApp(page: Frame): () -> ()
	local board = EventBoard.buildPhone(page)
	eventBoard = board
	if pendingRows then
		board.update(pendingRows)
	end
	return function()
		eventBoard = nil
	end
end

-- a sibling app module (OPTIONAL); nil when it is not there or fails to load
local function optionalApp(moduleName: string): any
	local m = script.Parent:FindFirstChild(moduleName)
	if not m or not m:IsA("ModuleScript") then
		return nil
	end
	local ok, mod = pcall(require, m)
	if ok and type(mod) == "table" and type((mod :: any).mount) == "function" then
		return mod
	end
	warn(`[Phone] {moduleName}: {mod}`)
	return nil
end

-- the controllers, required when an app first needs them (literal paths for the type checker)
local function mapController(): any
	return require(Controllers:WaitForChild("MapController"))
end
local function radioController(): any
	return require(Controllers:WaitForChild("RadioController"))
end
local function stationController(): any
	return require(Controllers:WaitForChild("StationController"))
end
local function seasonController(): any
	return require(Controllers:WaitForChild("SeasonController"))
end
local function explorationController(): any
	return require(Controllers:WaitForChild("ExplorationController"))
end

local function appList(): { App }
	local list: { App } = {
		{
			name = "Map",
			label = "Map",
			run = function()
				mapController().Open()
			end,
		},
		{
			name = "Radio",
			label = "Radio",
			run = function()
				radioController().repeatLast()
			end,
		},
		{
			name = "Camera",
			label = "Camera",
			run = function()
				require(script.Parent:WaitForChild("PhotoMode")).setOpen(true)
			end,
		},
		{
			name = "Events",
			label = "Events",
			mount = eventsApp,
		},
		{
			name = "Season",
			label = "Season",
			mount = panelApp("SeasonHud", "SeasonBook", nil, seasonController),
		},
		{
			name = "CrewPay",
			label = "Crew Pay",
			mount = function(page: Frame)
				return stationController().mountPay(page)
			end,
		},
		{
			name = "PayRise",
			label = "Pay Rise",
			mount = function(page: Frame)
				return stationController().mountRise(page)
			end,
		},
		{
			name = "Logbook",
			label = "Logbook",
			mount = panelApp("LogbookHud", "Holder", "Logbook", explorationController),
		},
		{
			name = "Crew",
			label = "Crew",
			mount = crewApp,
		},
		{
			name = "Settings",
			label = "Settings",
			mount = panelApp("Settings", "Panel"),
		},
	}
	for i, spec in OPTIONAL do
		local mod = optionalApp(spec.module)
		if mod then
			table.insert(list, 3 + i, {
				name = spec.name,
				label = spec.label,
				mount = mod.mount,
			})
		end
	end
	return list
end

function Phone.openApp(name: string)
	local app = byName[name]
	if not app then
		return
	end
	Phone.setOpen(true)
	if not open then
		return
	end
	local run = app.run
	if run then
		Phone.setOpen(false)
		-- off at once: PhotoMode snapshots which ScreenGuis are enabled
		if gui then
			gui.Enabled = false
		end
		run()
		return
	end
	if current then
		closeApp()
	end
	current = name
	home.Visible = false
	appBg.Visible = true
	appPage.Visible = true
	backButton.Visible = true
	clockLabel.Visible = false
	local mount = app.mount :: Mount
	local ok, undo = pcall(mount, content, showHome)
	if ok and type(undo) == "function" then
		cleanup = undo
	elseif not ok then
		warn(`[Phone] {name}: {undo}`)
	end
	if not Comfort.reducedMotion() then
		pageScale.Scale = 0.94
		appPage.Position = UDim2.fromOffset(0, STATUS_H + 26)
		tween(pageScale, 0.32, { Scale = 1 })
		tween(appPage, 0.32, { Position = UDim2.fromOffset(0, STATUS_H) })
	end
	task.defer(function()
		local sel = GuiService.SelectedObject
		if not (sel and sel:IsDescendantOf(content)) then
			focus(firstButton(content) or backButton)
		end
	end)
end

-- the Events icon's page, for opening straight from a controller or a test
function Phone.openEvents()
	Phone.openApp("Events")
end

-- EventBoardController pushes the same rows the harbour board shows.
function Phone.setEventRows(rows: { any })
	pendingRows = rows
	local b = eventBoard
	if b then
		b.update(rows)
	end
	local live = false
	for _, row in rows do
		if type(row) == "table" and row.kind == "now" and not row.ready then
			live = true
			break
		end
	end
	if badge then
		local was = badge.Visible
		badge.Visible = live
		local hop = bounce
		if live and not was and hop then
			hop()
		end
	end
end

function Phone.isOpen(): boolean
	return open
end

local function tickClock()
	clockLabel.Text = os.date("%H:%M")
end

function Phone.setOpen(value: boolean)
	local g = gui
	if not g or value == open then
		return
	end
	if value and (Layout.coldOpen() or player:GetAttribute("CinematicPlaying") == true) then
		return
	end
	open = value
	serial += 1
	local s = serial
	local reduced = Comfort.reducedMotion()
	if value then
		if current then
			closeApp()
		end
		orient()
		appPage.Visible = false
		appBg.Visible = false
		home.Visible = true
		backButton.Visible = false
		clockLabel.Visible = true
		tickClock()
		g.Enabled = true
		hand = Viewmodel.playAction("phone")
		UserInputService.MouseIconEnabled = true
		ContextActionService:BindActionAtPriority(
			"PhoneBack",
			onBack,
			false,
			Enum.ContextActionPriority.High.Value + 10,
			Enum.KeyCode.ButtonB,
			Enum.KeyCode.Backspace,
			Enum.KeyCode.Escape
		)
		if reduced then
			rig.Position, body.Rotation, bodyScale.Scale = ON, 0, 1
			wake.BackgroundTransparency = 1
			backdrop.BackgroundTransparency = 0.4
			popIcons(0)
		else
			rig.Position, body.Rotation, bodyScale.Scale = OFF, -7, 0.84
			wake.BackgroundTransparency = 0
			backdrop.BackgroundTransparency = 1
			tween(backdrop, 0.35, { BackgroundTransparency = 0.4 })
			-- Back easing overshoots and settles: the spring
			tween(rig, 0.6, { Position = ON }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			tween(body, 0.55, { Rotation = 0 })
			tween(bodyScale, 0.6, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			tween(wake, 0.45, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, nil, 0.26)
			popIcons(0.3)
		end
		focus(tiles[1] and tiles[1].button)
	else
		ContextActionService:UnbindAction("PhoneBack")
		local h = hand
		if h then
			h.stop() -- only ends our clip if it is still the one playing
			hand = nil
		end
		local sel = GuiService.SelectedObject
		if sel and sel:IsDescendantOf(g) then
			GuiService.SelectedObject = nil
		end
		local function finish()
			if serial == s and not open then
				if current then
					closeApp()
				end
				g.Enabled = false
			end
		end
		if reduced then
			finish()
			return
		end
		tween(wake, 0.16, { BackgroundTransparency = 0 })
		tween(rig, 0.36, { Position = OFF }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		tween(body, 0.36, { Rotation = 6 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(bodyScale, 0.36, { Scale = 0.88 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(backdrop, 0.32, { BackgroundTransparency = 1 })
		task.delay(0.38, finish)
	end
end

local function makeTile(app: App, order: number, parent: Instance, withLabel: boolean): Tile
	local b = Instance.new("TextButton")
	b.Name = app.name
	b.Text = ""
	b.LayoutOrder = order
	b.Size = UDim2.fromOffset(CELL_W, CELL_H)
	b.BackgroundTransparency = 1
	b.AutoButtonColor = false
	b.Parent = parent

	-- the squircle art scales on hover / press
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0, if withLabel then 4 else (CELL_H - ICON) / 2)
	icon.Size = UDim2.fromOffset(ICON, ICON)
	icon.BackgroundTransparency = 1
	icon.Image = PHONE_IMAGES[app.name] or ""
	icon.Parent = b
	local scale = Instance.new("UIScale")
	scale.Parent = icon

	local label: TextLabel? = nil
	if withLabel then
		local l =
			HudTheme.label("Label", app.label, UDim2.new(1, 8, 0, 16), HudTheme.HeaderFont, 13, b)
		l.AnchorPoint = Vector2.new(0.5, 0)
		l.Position = UDim2.new(0.5, 0, 0, ICON + 8)
		l.TextXAlignment = Enum.TextXAlignment.Center
		l.TextColor3 = W
		l.TextStrokeTransparency = 0.82
		label = l
	end

	-- hover / press: the tile lifts and dips
	b.MouseEnter:Connect(function()
		tween(scale, 0.15, { Scale = 1.07 })
	end)
	b.MouseLeave:Connect(function()
		tween(scale, 0.18, { Scale = 1 })
	end)
	b.SelectionGained:Connect(function()
		tween(scale, 0.15, { Scale = 1.07 })
	end)
	b.SelectionLost:Connect(function()
		tween(scale, 0.18, { Scale = 1 })
	end)
	b.MouseButton1Down:Connect(function()
		tween(scale, 0.08, { Scale = 0.92 })
	end)
	b.Activated:Connect(function()
		Phone.openApp(app.name)
	end)
	return { button = b, scale = scale, label = label }
end

local function buildStatusBar(parent: Frame)
	local barFrame = Instance.new("Frame")
	barFrame.Name = "StatusBar"
	barFrame.BackgroundTransparency = 1
	barFrame.Size = UDim2.new(1, 0, 0, STATUS_H)
	barFrame.ZIndex = 5
	barFrame.Parent = parent
	local ear = (CANVAS - ISLAND.X) / 2 -- du either side of the island

	backButton = Instance.new("TextButton")
	backButton.Name = "Back"
	backButton.Text = ""
	-- narrow: the key chip beside it must clear the island (ear = 102 du)
	backButton.Position = UDim2.fromOffset(10, 7)
	backButton.Size = UDim2.fromOffset(40, 32)
	backButton.BackgroundColor3 = W
	backButton.BackgroundTransparency = 0.86
	backButton.AutoButtonColor = true
	backButton.Visible = false
	HudTheme.corner(backButton, 16)
	backButton.Parent = barFrame
	-- a drawn chevron
	for _, spec in { { 0.42, 0.5 - 0.11, -45 }, { 0.42, 0.5 + 0.11, 45 } } do
		local stroke = box(backButton, W, spec[1], spec[2], 0.33, 0.1, 99)
		stroke.Rotation = spec[3]
	end
	local backChip = InputGlyph.chip(backButton, Enum.KeyCode.Backspace, Enum.KeyCode.ButtonB)
	backChip.AnchorPoint = Vector2.new(0, 0.5)
	backChip.Position = UDim2.new(1, 4, 0.5, 0)
	backButton.Activated:Connect(showHome)

	-- the time in the left ear, signal and battery in the right (iOS)
	clockLabel = HudTheme.label(
		"Time",
		"",
		UDim2.fromOffset(ear, STATUS_H),
		Enum.Font.BuilderSansBold,
		17,
		barFrame
	)
	clockLabel.TextXAlignment = Enum.TextXAlignment.Center
	clockLabel.TextColor3 = W

	local right = Instance.new("Frame")
	right.Name = "Signal"
	right.AnchorPoint = Vector2.new(0.5, 0.5)
	right.Position = UDim2.new(1, -ear / 2, 0.5, 0)
	right.Size = UDim2.fromOffset(64, 14)
	right.BackgroundTransparency = 1
	right.Parent = barFrame
	for i = 1, 4 do
		local s = Instance.new("Frame")
		s.AnchorPoint = Vector2.new(0, 1)
		s.Position = UDim2.new(0, (i - 1) * 6, 1, 0)
		s.Size = UDim2.fromOffset(4, 4 + i * 2.5)
		s.BackgroundColor3 = W
		s.BackgroundTransparency = if i == 4 then 0.6 else 0
		s.BorderSizePixel = 0
		HudTheme.corner(s, 1)
		s.Parent = right
	end
	local battery = Instance.new("Frame")
	battery.Name = "Battery"
	battery.AnchorPoint = Vector2.new(1, 0.5)
	battery.Position = UDim2.new(1, -4, 0.5, 0)
	battery.Size = UDim2.fromOffset(26, 13)
	battery.BackgroundTransparency = 1
	HudTheme.corner(battery, 4)
	local edge = HudTheme.stroke(battery, W, 1.2)
	edge.Transparency = 0.5
	battery.Parent = right
	local juice = Instance.new("Frame")
	juice.Position = UDim2.fromOffset(2, 2)
	juice.Size = UDim2.new(0.8, -2, 1, -4)
	juice.BackgroundColor3 = W
	juice.BorderSizePixel = 0
	HudTheme.corner(juice, 2)
	juice.Parent = battery
	local nub = Instance.new("Frame")
	nub.Position = UDim2.new(1, 2, 0.5, -2)
	nub.Size = UDim2.fromOffset(2, 5)
	nub.BackgroundColor3 = W
	nub.BackgroundTransparency = 0.5
	nub.BorderSizePixel = 0
	nub.Parent = battery
end

-- wallpaper: assets/ui/phone_v2/wallpaper.png pending
-- the wallpaper: a stock-iOS soft gradient with blurred colour blooms (no image asset). A
-- CanvasGroup so the blooms clip to the screen's rounded corners.
local function buildWallpaper(parent: Frame)
	local paper = Instance.new("CanvasGroup")
	paper.Name = "Wallpaper"
	paper.Size = UDim2.fromScale(1, 1)
	paper.BackgroundColor3 = W
	paper.BorderSizePixel = 0
	HudTheme.corner(paper, 40)
	local base = Instance.new("UIGradient")
	base.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("2A2F86")),
		ColorSequenceKeypoint.new(0.4, Color3.fromHex("6E4BDB")),
		ColorSequenceKeypoint.new(0.72, Color3.fromHex("F07AB6")),
		ColorSequenceKeypoint.new(1, Color3.fromHex("FFC38A")),
	})
	base.Rotation = 75
	base.Parent = paper
	paper.Parent = parent
	-- each bloom: stacked faint discs, a soft radial falloff
	for _, spec in
		{
			{ c = "3FC8FF", x = 0.12, y = 0.18, s = 1.1 },
			{ c = "FF5FA8", x = 1.0, y = 0.52, s = 1.2 },
			{ c = "FFD67A", x = 0.2, y = 0.92, s = 1.0 },
			{ c = "8F7CFF", x = 0.7, y = 0.05, s = 0.8 },
		}
	do
		for i = 1, 4 do
			local d = Instance.new("Frame")
			d.AnchorPoint = Vector2.new(0.5, 0.5)
			d.Position = UDim2.fromScale(spec.x, spec.y)
			local size = spec.s * (1.15 - i * 0.2)
			d.Size = UDim2.fromScale(size, size)
			d.SizeConstraint = Enum.SizeConstraint.RelativeXX
			d.BackgroundColor3 = Color3.fromHex(spec.c)
			d.BackgroundTransparency = 0.8
			d.BorderSizePixel = 0
			HudTheme.corner(d, 999)
			d.Parent = paper
		end
	end
end

local function buildButton(region: Frame)
	local button = Instance.new("TextButton")
	button.Name = "PhoneButton"
	button.Text = ""
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromScale(0.5, 0.5)
	button.Size = UDim2.fromScale(1, 1)
	button.AutoButtonColor = false
	button.BorderSizePixel = 0
	button.BackgroundColor3 = W
	button.Parent = region
	local pop = Instance.new("UIScale")
	pop.Parent = button
	HudTheme.corner(button, 22)
	button.BackgroundTransparency = 1
	local art = Instance.new("ImageLabel")
	art.Name = "Art"
	art.Size = UDim2.fromScale(1, 1)
	art.BackgroundTransparency = 1
	art.Image = PHONE_IMAGES.Button
	art.ScaleType = Enum.ScaleType.Fit
	art.Parent = button
	badge = box(button, Color3.fromHex("FF3B30"), 0.92, 0.08, 0, 0, 99)
	badge.Size = UDim2.fromOffset(22, 22)
	badge.ZIndex = 3
	badge.Visible = false
	HudTheme.stroke(badge, W, 2.5).Transparency = 0
	local chip = InputGlyph.chip(button, Enum.KeyCode.P, Enum.KeyCode.ButtonL1)
	chip.AnchorPoint = Vector2.new(0.5, 0.5)
	chip.Position = UDim2.new(1, -4, 1, -4)

	-- hover / press, and a hop with a wiggle when a notification lands
	button.MouseEnter:Connect(function()
		tween(pop, 0.15, { Scale = 1.08 })
	end)
	button.MouseLeave:Connect(function()
		tween(pop, 0.18, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		tween(pop, 0.08, { Scale = 0.9 })
	end)
	bounce = function()
		if Comfort.reducedMotion() then
			return
		end
		tween(pop, 0.18, { Scale = 1.25 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		tween(pop, 0.5, { Scale = 1 }, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out, 0.18)
		for i, r in { -12, 10, -6, 0 } do
			tween(button, 0.08, { Rotation = r }, Enum.EasingStyle.Sine, nil, 0.1 + (i - 1) * 0.08)
		end
	end
	button.Activated:Connect(function()
		tween(pop, 0.2, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		Phone.setOpen(not open)
	end)
	Layout.onColdOpen(function(active: boolean)
		region.Visible = not active
		if active then
			Phone.setOpen(false)
		end
	end)
end

local function build(statusRegion: Frame)
	local g = Instance.new("ScreenGui")
	g.Name = "Phone"
	g.ResetOnSpawn = false
	g.DisplayOrder = DISPLAY_ORDER
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.Enabled = false
	Layout.prepare(g)
	gui = g

	-- tap outside closes; Modal frees the mouse in first person while the phone is up
	backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.new(1, 0, 1, 200) -- under the safe-area insets too
	backdrop.Position = UDim2.fromOffset(0, -100)
	backdrop.BackgroundColor3 = Color3.fromHex("02060A")
	backdrop.BackgroundTransparency = 1
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.Selectable = false
	backdrop.Modal = true
	backdrop.Parent = g
	backdrop.Activated:Connect(function(input: InputObject)
		-- the backdrop also hears taps that land on the handset (Active does not sink them): only a tap
		-- outside the body closes
		local at = input.Position
		for _, obj in player.PlayerGui:GetGuiObjectsAtPosition(at.X, at.Y) do
			if obj == body or obj:IsDescendantOf(body) then
				return
			end
		end
		Phone.setOpen(false)
	end)

	-- rig: the handset's size in du and the device scale; body: the open / close spring and turns
	rig = Instance.new("Frame")
	rig.Name = "Handset"
	rig.AnchorPoint = Vector2.new(0.5, 0.5)
	rig.Position = OFF
	rig.BackgroundTransparency = 1
	rig.Parent = g
	rigScale = Instance.new("UIScale")
	rigScale.Parent = rig

	-- the slab: near-black glass in a brushed titanium rim
	body = Instance.new("Frame")
	body.Name = "Body"
	body.Active = true -- taps on the phone do not reach the backdrop
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.fromScale(0.5, 0.5)
	body.Size = UDim2.fromScale(1, 1)
	body.BackgroundColor3 = Color3.fromHex("0A0B0D")
	body.BorderSizePixel = 0
	body.SelectionGroup = true
	HudTheme.corner(body, 50)
	local rim = HudTheme.stroke(body, W, 3)
	rim.Transparency = 0
	local rimShade = Instance.new("UIGradient")
	rimShade.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("D7DBDF")),
		ColorSequenceKeypoint.new(0.35, Color3.fromHex("6B7279")),
		ColorSequenceKeypoint.new(0.7, Color3.fromHex("A9B0B6")),
		ColorSequenceKeypoint.new(1, Color3.fromHex("474D53")),
	})
	rimShade.Rotation = 35
	rimShade.Parent = rim
	bodyScale = Instance.new("UIScale")
	bodyScale.Parent = body
	body.Parent = rig

	-- side keys: action + volume on the left edge, power on the right (orient places them)
	for _, spec in
		{
			{ edge = "left", at = 0.17, len = 26 },
			{ edge = "left", at = 0.25, len = 46 },
			{ edge = "left", at = 0.33, len = 46 },
			{ edge = "right", at = 0.28, len = 74 },
		}
	do
		local key = Instance.new("Frame")
		key.BackgroundColor3 = Color3.fromHex("7A8188")
		key.BorderSizePixel = 0
		HudTheme.corner(key, 2)
		key.Parent = body
		table.insert(keys, { edge = spec.edge, at = spec.at, len = spec.len, frame = key })
	end

	screen = Instance.new("Frame")
	screen.Name = "Screen"
	screen.AnchorPoint = Vector2.new(0.5, 0.5)
	screen.Position = UDim2.fromScale(0.5, 0.5)
	screen.BackgroundColor3 = Color3.new(0, 0, 0)
	screen.BorderSizePixel = 0
	HudTheme.corner(screen, 40)
	screen.Parent = body
	screenScale = Instance.new("UIScale")
	screenScale.Parent = screen
	buildWallpaper(screen)
	-- an open app's own background over the wallpaper
	appBg = Instance.new("Frame")
	appBg.Name = "AppBackground"
	appBg.Size = UDim2.fromScale(1, 1)
	appBg.BackgroundColor3 = Color3.fromHex("0B1218")
	appBg.BorderSizePixel = 0
	appBg.Visible = false
	HudTheme.corner(appBg, 40)
	appBg.Parent = screen
	buildStatusBar(screen)

	-- home: the icon grid from the top, the frosted dock along the bottom
	home = Instance.new("Frame")
	home.Name = "Home"
	home.BackgroundTransparency = 1
	home.Position = UDim2.fromOffset(0, STATUS_H)
	home.Size = UDim2.new(1, 0, 1, -STATUS_H - HOME_H)
	home.Parent = screen
	local dockH = ICON + 26
	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.AnchorPoint = Vector2.new(0.5, 0)
	grid.Position = UDim2.new(0.5, 0, 0, 14)
	grid.Size = UDim2.new(0, CANVAS - 24, 1, -dockH - 36)
	grid.Parent = home
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(CELL_W, CELL_H)
	layout.CellPadding = UDim2.fromOffset(0, 10)
	layout.FillDirectionMaxCells = 4
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	local dock = Instance.new("Frame")
	dock.Name = "Dock"
	dock.AnchorPoint = Vector2.new(0.5, 1)
	dock.Position = UDim2.new(0.5, 0, 1, -6)
	dock.Size = UDim2.fromOffset(CANVAS - 20, dockH)
	dock.BackgroundColor3 = W
	dock.BackgroundTransparency = 0.72
	dock.BorderSizePixel = 0
	HudTheme.corner(dock, 30)
	HudTheme.stroke(dock, W, 1).Transparency = 0.75
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.HorizontalAlignment = Enum.HorizontalAlignment.Center
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = dock
	dock.Parent = home

	-- an open app: below the status bar, above the home indicator
	appPage = Instance.new("Frame")
	appPage.Name = "App"
	appPage.BackgroundTransparency = 1
	appPage.Position = UDim2.fromOffset(0, STATUS_H)
	appPage.Size = UDim2.new(1, 0, 1, -STATUS_H - HOME_H)
	appPage.Visible = false
	appPage.Parent = screen
	pageScale = Instance.new("UIScale")
	pageScale.Parent = appPage
	content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Parent = appPage

	local docked = {}
	for i, app in appList() do
		byName[app.name] = app
		if DOCK[app.name] then
			table.insert(docked, app)
		else
			table.insert(tiles, makeTile(app, i, grid, true))
		end
	end
	table.sort(docked, function(a, b)
		return DOCK[a.name] < DOCK[b.name]
	end)
	for _, app in docked do
		table.insert(tiles, makeTile(app, DOCK[app.name], dock, false))
	end

	-- the Dynamic Island, over everything on the screen
	island = Instance.new("Frame")
	island.Name = "DynamicIsland"
	island.BackgroundColor3 = Color3.new(0, 0, 0)
	island.BorderSizePixel = 0
	island.ZIndex = 6
	HudTheme.corner(island, 999)
	island.Parent = screen

	-- home indicator: back from an app, or close from the icons
	local homeBar = Instance.new("TextButton")
	homeBar.Name = "HomeBar"
	homeBar.AnchorPoint = Vector2.new(0.5, 1)
	homeBar.Position = UDim2.fromScale(0.5, 1)
	homeBar.Size = UDim2.fromOffset(200, HOME_H + 10)
	homeBar.BackgroundTransparency = 1
	homeBar.Text = ""
	homeBar.ZIndex = 5
	homeBar.Parent = screen
	local line = box(homeBar, W, 0.5, 0.7, 0, 0, 99)
	line.Size = UDim2.fromOffset(124, 5)
	line.BackgroundTransparency = 0.1
	homeBar.Activated:Connect(back)

	-- the screen waking: black over everything, fading out
	wake = Instance.new("Frame")
	wake.Name = "Wake"
	wake.Size = UDim2.fromScale(1, 1)
	wake.BackgroundColor3 = Color3.new(0, 0, 0)
	wake.BorderSizePixel = 0
	wake.ZIndex = 20
	HudTheme.corner(wake, 40)
	wake.Parent = screen

	local function fit(mt: Layout.Metrics)
		local u = mt.usable
		-- upright: nearly the screen's height (all of it on a short landscape phone screen), and
		-- never narrower than the canvas, so app text keeps HudTheme's 0.7 px-per-du floor there
		local m = if u.Y * mt.scale < 560 then 0 else MARGIN
		local ph = math.min(u.Y - 2 * m, (u.X - 2 * m) * ASPECT)
		portraitSize = V(math.min(math.max(ph / ASPECT, CANVAS + 2 * BEZEL), u.X - 2 * m), ph)
		rigScale.Scale = mt.scale
		orient()
		body.Rotation = 0
		local again = relayout
		if again then
			task.defer(again) -- after the borrowed panel's own fit
		end
	end
	fit(Layout.current())
	Layout.onMetrics(fit)
	Layout.onTextScale(function()
		task.defer(sizeLabels) -- after HudTheme's own pass resets the labels
	end)

	-- the HUD button: the Hud's "phone" region on the left (HudLayout)
	local hud = statusRegion:FindFirstAncestorOfClass("ScreenGui")
	buildButton(if hud then Layout.region(hud, "phone") else statusRegion)

	g.Parent = player:WaitForChild("PlayerGui")
end

-- J (on foot: J is also the car's lights) / L3 -> Logbook; Start -> Settings; again closes
local NAV_KEYS = {
	[Enum.KeyCode.Up] = true,
	[Enum.KeyCode.Down] = true,
	[Enum.KeyCode.Left] = true,
	[Enum.KeyCode.Right] = true,
	[Enum.KeyCode.Return] = true,
}

local function shortcut(input: InputObject, processed: boolean)
	local key = input.KeyCode
	-- keyboard: the first arrow or Return selects, then Roblox's selection navigation moves and presses
	if open and NAV_KEYS[key] then
		local sel = GuiService.SelectedObject
		if not (sel and gui and sel:IsDescendantOf(gui)) then
			GuiService.SelectedObject = if current
				then firstButton(content) or backButton
				else tiles[1] and tiles[1].button
		end
		return
	end
	local app: string? = nil
	if key == Enum.KeyCode.ButtonStart then
		app = "Settings"
	elseif key == Enum.KeyCode.ButtonL3 then
		app = "Logbook"
	elseif key == Enum.KeyCode.J and not processed then
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not (hum and hum.SeatPart) then
			app = "Logbook"
		end
	end
	if not app then
		return
	end
	if open and current == app then
		Phone.setOpen(false)
	else
		Phone.openApp(app)
	end
end

function Phone.mount(statusRegion: Frame)
	if gui then
		return
	end
	build(statusRegion)
	ContextActionService:BindAction("PhoneToggle", function(_, state)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		Phone.setOpen(not open)
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.P, Enum.KeyCode.ButtonL1)
	UserInputService.InputBegan:Connect(shortcut)
	-- the mouse takes over from keyboard / pad navigation: drop the selection outline
	local function mouseUsed(input: InputObject)
		local t = input.UserInputType
		local sel = GuiService.SelectedObject
		if
			(t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.MouseButton1)
			and sel
			and sel:IsDescendantOf(gui)
		then
			GuiService.SelectedObject = nil
		end
	end
	UserInputService.InputChanged:Connect(mouseUsed)
	UserInputService.InputBegan:Connect(mouseUsed)
	task.spawn(function()
		while true do
			if open then
				tickClock()
			end
			task.wait(5)
		end
	end)
	Net.event("CrewJoin").OnClientEvent:Connect(function(payload: any)
		if type(payload) == "table" and type(payload.members) == "table" then
			crew = payload.members
			leader = tonumber(payload.leader) or 0
			if drawCrew then
				drawCrew()
			end
		end
	end)
	Net.event("CrewLeave").OnClientEvent:Connect(function()
		crew, leader = {}, 0
		if drawCrew then
			drawCrew()
		end
	end)
end

return Phone
