--!strict
-- Phone: the player's phone and the home of every menu (docs/14 §6, RP-PH1; playtest 2026-10-21:
-- "the entire UI on the phone, a big phone with an animation"). P, gamepad L1 or the phone button
-- by the rank strip opens it: a landscape handset filling the safe area slides up with a spring,
-- the screen wakes and the icons pop in; closing plays it back (a short fade with reduced motion).
-- The phone-in-hand Viewmodel loop plays and a Modal backdrop frees the cursor.
-- Apps (an icon and a 1-2 word label):
--   Map, Radio, Camera   close the phone and run (MapController.Open, Radio repeat, PhotoMode)
--   Logbook, Season, Settings   the existing panels (ExplorationController's Logbook, SeasonBook,
--                        SettingsPanel): their frames are borrowed onto the phone screen
--   Events               EventBoard.buildPhone rows (EventBoardController pushes them)
--   Crew                 the crew's faces (leader ringed in brass), Invite and Leave
--   Vehicles             UI/VehiclesApp.mount(page) when that module is there
--   Crew Pay, Pay Rise   StationController.mountPay / mountRise (station pot and workshop)
-- Back: the chevron, the home bar, gamepad B, Backspace or Escape; at home they close the phone.
-- J (on foot) / gamepad L3 open the Logbook app, gamepad Start the Settings app. A gold dot on the
-- phone button: an event is on now.
--   Phone.mount(statusRegion)   HudController calls this once
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
local player = Players.LocalPlayer
-- the user's icon art (assets/ui/phone, uploaded as Images through tools/assets.py)
local ART: { [string]: string } = {
	Map = "rbxassetid://78753808243316",
	Radio = "rbxassetid://137514171104143",
	Events = "rbxassetid://99314211130736",
	Vehicles = "rbxassetid://133675801196948",
	CrewPay = "rbxassetid://99621546437175",
	PayRise = "rbxassetid://116868851918712",
	Season = "rbxassetid://134505277608737",
	Logbook = "rbxassetid://77395907263418",
	Crew = "rbxassetid://120864312381464",
	Camera = "rbxassetid://113013786928161",
	Settings = "rbxassetid://135064908499694",
	PhoneButton = "rbxassetid://93763825688168",
	Wallpaper = "rbxassetid://115625655172292", -- 474x1024 portrait, cover-cropped
}
local DOCK = { Map = 1, Radio = 2, Vehicles = 3, Camera = 4 } -- the dock's favourites, in order
local ICON = 104 -- du, the squircle
local DISPLAY_ORDER = 36 -- above the store panels (35), below CashBurst (41) and Cinematic (50)
local MARGIN = 12 -- du around the handset
local BEZEL = 14 -- du
local STATUS_H = 44 -- du, the screen's status bar
local HOME_H = 30 -- du, the home bar strip
local ASPECT = 2.17 -- a modern handset held sideways
local OFF = UDim2.fromScale(0.5, 1.65)
local ON = UDim2.fromScale(0.5, 0.5)

type App = {
	name: string,
	label: string,
	color: Color3,
	run: (() -> ())?,
	mount: ((page: Frame) -> () -> ())?,
}
type Tile = { button: TextButton, scale: UIScale, label: TextLabel? }

local Phone = {}

local gui: ScreenGui? = nil
local backdrop: TextButton
local rig: Frame
local rigScale: UIScale
local body: Frame
local bodyScale: UIScale
local wake: Frame
local home: Frame
local appPage: Frame
local pageScale: UIScale
local content: Frame
local backButton: TextButton
local clockLabel: TextLabel
local badge: Frame
local tiles: { Tile } = {}
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

local function tween(
	obj: Instance,
	t: number,
	props: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?,
	delay: number?
)
	TweenService:Create(
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
	):Play()
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
	if obj and UserInputService.GamepadEnabled then
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

local function goHome()
	if current then
		closeApp()
	end
	appPage.Visible = false
	home.Visible = true
	backButton.Visible = false
	popIcons(0)
	focus(tiles[1] and tiles[1].button)
end

local function back()
	if current then
		goHome()
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
): (Frame) -> () -> ()
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
				task.defer(goHome)
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
	local b = HudTheme.button(name, text, UDim2.fromOffset(200, 63), parent)
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
	faces.AnchorPoint = Vector2.new(0.5, 0.5)
	faces.Position = UDim2.fromScale(0.5, 0.4)
	faces.Size = UDim2.new(1, 0, 0, 150)
	faces.Parent = page
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 28)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = faces

	local buttons = Instance.new("Frame")
	buttons.Name = "Buttons"
	buttons.BackgroundTransparency = 1
	buttons.AnchorPoint = Vector2.new(0.5, 0)
	buttons.Position = UDim2.fromScale(0.5, 0.72)
	buttons.Size = UDim2.new(1, 0, 0, 63)
	buttons.Parent = page
	local row = list:Clone()
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
			face.Size = UDim2.fromOffset(132, 132)
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

-- VehiclesApp is another module's (VehiclesApp.mount(page) -> cleanup); the phone works without it
local function vehiclesMount(): ((Frame) -> () -> ())?
	local m = script.Parent:FindFirstChild("VehiclesApp")
	if not m or not m:IsA("ModuleScript") then
		return nil
	end
	local ok, mod = pcall(require, m)
	if ok and type(mod) == "table" and type((mod :: any).mount) == "function" then
		return (mod :: any).mount
	end
	warn("[Phone] VehiclesApp: " .. tostring(mod))
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
			color = Color3.fromHex("3E8FB0"),
			run = function()
				mapController().Open()
			end,
		},
		{
			name = "Radio",
			label = "Radio",
			color = C.accent,
			run = function()
				radioController().repeatLast()
			end,
		},
		{ name = "Events", label = "Events", color = Color3.fromHex("6E56C2"), mount = eventsApp },
		{
			name = "CrewPay",
			label = "Crew Pay",
			color = Color3.fromHex("8A6A2C"),
			mount = function(page: Frame)
				return stationController().mountPay(page)
			end,
		},
		{
			name = "PayRise",
			label = "Pay Rise",
			color = Color3.fromHex("4F8A43"),
			mount = function(page: Frame)
				return stationController().mountRise(page)
			end,
		},
		{
			name = "Season",
			label = "Season",
			color = Color3.fromHex("8C3B4A"),
			mount = panelApp("SeasonHud", "SeasonBook", nil, seasonController),
		},
		{
			name = "Logbook",
			label = "Logbook",
			color = Color3.fromHex("34488A"),
			mount = panelApp("LogbookHud", "Holder", "Logbook", explorationController),
		},
		{ name = "Crew", label = "Crew", color = Color3.fromHex("2E9C8F"), mount = crewApp },
		{
			name = "Camera",
			label = "Camera",
			color = Color3.fromHex("4A545C"),
			run = function()
				require(script.Parent:WaitForChild("PhotoMode")).setOpen(true)
			end,
		},
		{
			name = "Settings",
			label = "Settings",
			color = Color3.fromHex("5B6670"),
			mount = panelApp("Settings", "Panel"),
		},
	}
	local vehicles = vehiclesMount()
	if vehicles then
		table.insert(list, 4, {
			name = "Vehicles",
			label = "Vehicles",
			color = Color3.fromHex("2F7D6B"),
			mount = vehicles,
		})
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
	appPage.Visible = true
	backButton.Visible = true
	local mount = app.mount :: (Frame) -> () -> ()
	local ok, undo = pcall(mount, content)
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
		badge.Visible = live
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
		appPage.Visible = false
		home.Visible = true
		backButton.Visible = false
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
	b.Size = UDim2.fromOffset(ICON, ICON)
	b.BackgroundTransparency = 1
	b.AutoButtonColor = false
	b.Parent = parent

	-- the squircle and its soft shadow scale together
	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.fromScale(0.5, 0)
	icon.Size = UDim2.fromOffset(ICON, ICON)
	icon.BackgroundTransparency = 1
	icon.Parent = b
	local scale = Instance.new("UIScale")
	scale.Parent = icon
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Position = UDim2.fromOffset(0, 4)
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = 0.72
	shadow.BorderSizePixel = 0
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.22, 0)
	round.Parent = shadow
	shadow.Parent = icon
	local tile = Instance.new("ImageLabel")
	tile.Name = "Tile"
	tile.Size = UDim2.fromScale(1, 1)
	tile.BackgroundColor3 = app.color -- shows while the image streams in
	tile.BorderSizePixel = 0
	tile.Image = ART[app.name] or ""
	tile.ScaleType = Enum.ScaleType.Crop
	round:Clone().Parent = tile
	tile.Parent = icon

	local label: TextLabel? = nil
	if withLabel then
		local l =
			HudTheme.label("Label", app.label, UDim2.new(1, 24, 0, 22), HudTheme.HeaderFont, 15, b)
		l.AnchorPoint = Vector2.new(0.5, 0)
		l.Position = UDim2.new(0.5, 0, 0, ICON + 6)
		l.TextXAlignment = Enum.TextXAlignment.Center
		l.TextColor3 = Color3.new(1, 1, 1)
		l.TextStrokeTransparency = 0.75
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

local function buildStatusBar(screen: Frame)
	local bar = Instance.new("Frame")
	bar.Name = "StatusBar"
	bar.BackgroundTransparency = 1
	bar.Size = UDim2.new(1, 0, 0, STATUS_H)
	bar.ZIndex = 5
	bar.Parent = screen

	backButton = Instance.new("TextButton")
	backButton.Name = "Back"
	backButton.Text = ""
	backButton.Position = UDim2.fromOffset(18, 2)
	backButton.Size = UDim2.fromOffset(72, 40)
	backButton.BackgroundColor3 = C.text
	backButton.BackgroundTransparency = 0.88
	backButton.AutoButtonColor = true
	backButton.Visible = false
	HudTheme.corner(backButton, 20)
	backButton.Parent = bar
	-- a drawn chevron
	for _, spec in { { 0.36, 0.5 - 0.11, -45 }, { 0.36, 0.5 + 0.11, 45 } } do
		local stroke = box(backButton, C.text, spec[1], spec[2], 0.2, 0.09, 99)
		stroke.Rotation = spec[3]
	end
	local backChip = InputGlyph.chip(backButton, Enum.KeyCode.Backspace, Enum.KeyCode.ButtonB)
	backChip.AnchorPoint = Vector2.new(0, 0.5)
	backChip.Position = UDim2.new(1, 6, 0.5, 0)
	backButton.Activated:Connect(goHome)

	clockLabel =
		HudTheme.label("Time", "", UDim2.fromOffset(120, STATUS_H), HudTheme.HeaderFont, 19, bar)
	clockLabel.AnchorPoint = Vector2.new(0.5, 0)
	clockLabel.Position = UDim2.fromScale(0.5, 0)
	clockLabel.TextXAlignment = Enum.TextXAlignment.Center

	-- signal bars and the battery, right
	for i = 1, 4 do
		local s = Instance.new("Frame")
		s.AnchorPoint = Vector2.new(0, 1)
		s.Position = UDim2.new(1, -150 + (i - 1) * 8, 0, 29)
		s.Size = UDim2.fromOffset(5, 4 + i * 3)
		s.BackgroundColor3 = C.text
		s.BackgroundTransparency = if i == 4 then 0.6 else 0
		s.BorderSizePixel = 0
		HudTheme.corner(s, 1)
		s.Parent = bar
	end
	local battery = Instance.new("Frame")
	battery.Name = "Battery"
	battery.Position = UDim2.new(1, -96, 0, 14)
	battery.Size = UDim2.fromOffset(34, 16)
	battery.BackgroundTransparency = 1
	HudTheme.corner(battery, 5)
	local edge = HudTheme.stroke(battery, C.text, 1.5)
	edge.Transparency = 0.25
	battery.Parent = bar
	local juice = Instance.new("Frame")
	juice.Position = UDim2.fromOffset(3, 3)
	juice.Size = UDim2.new(0.72, -3, 1, -6)
	juice.BackgroundColor3 = C.ready
	juice.BorderSizePixel = 0
	HudTheme.corner(juice, 3)
	juice.Parent = battery
	local nub = Instance.new("Frame")
	nub.Position = UDim2.new(1, 2, 0.5, -3)
	nub.Size = UDim2.fromOffset(3, 6)
	nub.BackgroundColor3 = C.text
	nub.BackgroundTransparency = 0.25
	nub.BorderSizePixel = 0
	nub.Parent = battery
end

-- the wallpaper: the user's stormy harbour, cover-cropped, darkened toward the dock for the labels
local function buildWallpaper(screen: Frame)
	local paper = Instance.new("ImageLabel")
	paper.Name = "Wallpaper"
	paper.Size = UDim2.fromScale(1, 1)
	paper.BackgroundColor3 = Color3.fromHex("0B1620")
	paper.BorderSizePixel = 0
	paper.Image = ART.Wallpaper
	paper.ScaleType = Enum.ScaleType.Crop
	HudTheme.corner(paper, 32)
	paper.Parent = screen
	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BorderSizePixel = 0
	HudTheme.corner(shade, 32)
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.62),
		NumberSequenceKeypoint.new(0.5, 0.78),
		NumberSequenceKeypoint.new(1, 0.45),
	})
	fade.Parent = shade
	shade.Parent = paper
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

	-- rig: the handset's size in du and the device scale; body: the open / close spring
	rig = Instance.new("Frame")
	rig.Name = "Handset"
	rig.AnchorPoint = Vector2.new(0.5, 0.5)
	rig.Position = OFF
	rig.BackgroundTransparency = 1
	rig.Parent = g
	rigScale = Instance.new("UIScale")
	rigScale.Parent = rig

	body = Instance.new("Frame")
	body.Name = "Body"
	body.Active = true -- taps on the phone do not reach the backdrop
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.fromScale(0.5, 0.5)
	body.Size = UDim2.fromScale(1, 1)
	body.BackgroundColor3 = Color3.new(1, 1, 1)
	body.BorderSizePixel = 0
	body.SelectionGroup = true
	HudTheme.corner(body, 46)
	gradient(body, Color3.fromHex("3A4148"), Color3.fromHex("111418"), 70)
	local rim = HudTheme.stroke(body, Color3.new(1, 1, 1), 2)
	rim.Transparency = 0
	local rimShade = Instance.new("UIGradient")
	rimShade.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("C9D0D6")),
		ColorSequenceKeypoint.new(0.35, Color3.fromHex("5A636B")),
		ColorSequenceKeypoint.new(0.7, Color3.fromHex("9AA3AB")),
		ColorSequenceKeypoint.new(1, Color3.fromHex("3A4148")),
	})
	rimShade.Rotation = 35
	rimShade.Parent = rim
	bodyScale = Instance.new("UIScale")
	bodyScale.Parent = body
	body.Parent = rig

	-- side keys on the top edge and the front camera in the left bezel
	for _, spec in { { 0.14, 54 }, { 0.2, 54 }, { 0.82, 76 } } do
		local key = Instance.new("Frame")
		key.AnchorPoint = Vector2.new(0, 1)
		key.Position = UDim2.new(spec[1], 0, 0, 1)
		key.Size = UDim2.fromOffset(spec[2], 5)
		key.BackgroundColor3 = Color3.fromHex("4A525A")
		key.BorderSizePixel = 0
		HudTheme.corner(key, 2)
		key.Parent = body
	end
	local cam = box(body, Color3.fromHex("05080B"), 0, 0.5, 0, 0, 99)
	cam.Position = UDim2.new(0, BEZEL / 2 + 1, 0.5, 0)
	cam.Size = UDim2.fromOffset(9, 9)
	box(cam, Color3.fromHex("1F3A5A"), 0.5, 0.5, 0.45, 0.45, 99)

	local screen = Instance.new("Frame")
	screen.Name = "Screen"
	screen.Position = UDim2.fromOffset(BEZEL, BEZEL)
	screen.Size = UDim2.new(1, -2 * BEZEL, 1, -2 * BEZEL)
	screen.BackgroundColor3 = Color3.new(0, 0, 0)
	screen.BorderSizePixel = 0
	HudTheme.corner(screen, 32)
	screen.Parent = body
	buildWallpaper(screen)
	buildStatusBar(screen)

	-- home: the icon grid from the top, the frosted dock along the bottom
	home = Instance.new("Frame")
	home.Name = "Home"
	home.BackgroundTransparency = 1
	home.Position = UDim2.fromOffset(0, STATUS_H)
	home.Size = UDim2.new(1, 0, 1, -STATUS_H - HOME_H)
	home.Parent = screen
	local dockH = ICON + 28
	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.AnchorPoint = Vector2.new(0.5, 0)
	grid.Position = UDim2.new(0.5, 0, 0, 18)
	grid.Size = UDim2.new(1, -56, 1, -dockH - 50)
	grid.Parent = home
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(ICON + 30, ICON + 34)
	layout.CellPadding = UDim2.fromOffset(12, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	local dock = Instance.new("Frame")
	dock.Name = "Dock"
	dock.AnchorPoint = Vector2.new(0.5, 1)
	dock.Position = UDim2.new(0.5, 0, 1, -18) -- clear of the home bar's touch strip
	dock.Size = UDim2.fromOffset(0, dockH)
	dock.AutomaticSize = Enum.AutomaticSize.X
	dock.BackgroundColor3 = Color3.fromHex("DCE6EE")
	dock.BackgroundTransparency = 0.72
	dock.BorderSizePixel = 0
	HudTheme.corner(dock, 38)
	HudTheme.stroke(dock, Color3.new(1, 1, 1), 1).Transparency = 0.7
	local frost = Instance.new("UIGradient")
	frost.Rotation = 90
	frost.Transparency = NumberSequence.new(0, 0.35)
	frost.Parent = dock
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 22)
	pad.PaddingRight = UDim.new(0, 22)
	pad.Parent = dock
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0, 30)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = dock
	dock.Parent = home

	-- an open app: below the status bar, above the home bar
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
	content.Position = UDim2.fromOffset(24, 4)
	content.Size = UDim2.new(1, -48, 1, -8)
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
	for _, app in docked do
		table.insert(tiles, makeTile(app, DOCK[app.name], dock, false))
	end

	-- home bar: back from an app, or close from the icons
	local bar = Instance.new("TextButton")
	bar.Name = "HomeBar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.fromScale(0.5, 1)
	bar.Size = UDim2.fromOffset(260, HOME_H + 14)
	bar.BackgroundTransparency = 1
	bar.Text = ""
	bar.ZIndex = 5
	bar.Parent = screen
	local line = box(bar, C.text, 0.5, 0.62, 0, 0, 99)
	line.Size = UDim2.fromOffset(170, 6)
	line.BackgroundTransparency = 0.2
	bar.Activated:Connect(back)

	-- the screen waking: black over everything, fading out
	wake = Instance.new("Frame")
	wake.Name = "Wake"
	wake.Size = UDim2.fromScale(1, 1)
	wake.BackgroundColor3 = Color3.new(0, 0, 0)
	wake.BorderSizePixel = 0
	wake.ZIndex = 20
	HudTheme.corner(wake, 32)
	wake.Parent = screen

	local function fit(mt: Layout.Metrics)
		local u = mt.usable
		local w = math.min(u.X - 2 * MARGIN, (u.Y - 2 * MARGIN) * ASPECT)
		local h = math.min(u.Y - 2 * MARGIN, (u.X - 2 * MARGIN) * ASPECT)
		rig.Size = UDim2.fromOffset(w, h)
		rigScale.Scale = mt.scale
		local again = relayout
		if again then
			task.defer(again) -- after the borrowed panel's own fit
		end
	end
	fit(Layout.current())
	Layout.onMetrics(fit)

	-- HUD button left of the rank strip: the user's phone glyph as a rounded icon
	local button = Instance.new("ImageButton")
	button.Name = "PhoneButton"
	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = UDim2.fromOffset(-6, 0)
	button.Size = UDim2.fromOffset(52, 52)
	button.BackgroundColor3 = C.panel
	button.BorderSizePixel = 0
	button.Image = ART.PhoneButton
	button.ScaleType = Enum.ScaleType.Crop
	HudTheme.corner(button, 12)
	HudTheme.stroke(button)
	badge = box(button, C.gold, 0.82, 0.18, 0, 0, 99)
	badge.Size = UDim2.fromOffset(12, 12)
	badge.Visible = false
	HudTheme.stroke(badge, C.panel, 2).Transparency = 0
	local chip = InputGlyph.chip(button, Enum.KeyCode.P, Enum.KeyCode.ButtonL1)
	chip.AnchorPoint = Vector2.new(0.5, 0)
	chip.Position = UDim2.new(0.5, 0, 1, 4)
	button.Parent = statusRegion
	button.Activated:Connect(function()
		Phone.setOpen(not open)
	end)
	Layout.onColdOpen(function(active: boolean)
		button.Visible = not active
		if active then
			Phone.setOpen(false)
		end
	end)

	g.Parent = player:WaitForChild("PlayerGui")
end

-- J (on foot: J is also the car's lights) / L3 -> Logbook; Start -> Settings; again closes
local function shortcut(input: InputObject, processed: boolean)
	local key = input.KeyCode
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
