--!strict
-- SettingsPanel: the settings menu (docs 13 RP-S1). Camera comfort (horizon stabilisation, FOV,
-- head bob, shake, G-force lean, look sensitivity, speed FOV, motion blur, lens spray), a
-- "Seasick-safe" preset, a graphics override (ocean and scatter detail), volumes (master,
-- effects, radio, music), radio voices on/off, muting other players' horns / sirens / radios, Assist /
-- Pro, and "Owned items": a CosmeticPicker per cosmetic slot the player owns (RP-M5).
--
-- Lives on the phone: its Settings app (gamepad Start opens it) borrows the panel frame onto the
-- phone screen. setOpen still shows it standalone (X or gamepad B closes).
-- Values live in Camera/Comfort (saved on the profile; keys and rules in shared/SettingsRules).
--
-- Audio: sets the AudioConfig SoundGroup tree (SoundService.Master > Music, SFX, Ambience, Radio >
-- Voice) to the slider values; "Voice" (voiced radio clips) is muted while voice is off. Sounds
-- join a group through Sound.SoundGroup (SettingsPanel.soundGroup(name) finds or makes it).
-- Assist / Pro: sent to the server (Settings_SetPro, SettingsService), which owns the OpsPro
-- attribute; switching to Pro waits until the current operation ends.
--
--   SettingsPanel.mount()   HudController calls this once
--   SettingsPanel.setOpen(open) / SettingsPanel.isOpen()
--   SettingsPanel.soundGroup(channel): SoundGroup
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local A11yPalette = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("A11yPalette"))
local Comfort = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("Comfort"))
local CosmeticPicker = require(script.Parent:WaitForChild("CosmeticPicker"))
local Cosmetics = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Cosmetics"))
local HudTheme = require(script.Parent:WaitForChild("HudTheme"))
local Layout = require(script.Parent:WaitForChild("Layout"))
local SettingsRules =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SettingsRules"))

local C = HudTheme.Colors
local player = Players.LocalPlayer

local SettingsPanel = {}

local DISPLAY_ORDER = 40 -- above the store panels (35), below Cinematic (50)
local ROW = 56 -- du per row
local PANEL_W = 600
local PANEL_H = 620

local gui: ScreenGui? = nil
local panel: Frame? = nil
local scroller: ScrollingFrame? = nil
local firstSelectable: GuiObject? = nil
local open = false
local refreshers: { [string]: { () -> () } } = {}
local extraRefresh: { () -> () } = {}

---------------------------------------------------------------- audio mix

-- The AudioConfig tree: SoundService.Master holds Music, SFX, Ambience and Radio; Radio holds
-- Voice. AudioController (RP-AU1) builds it; this finds or creates the same groups by name so the
-- sliders work whichever side runs first, then also tells AudioController.setVolume if it exists.
local PARENT =
	{ SFX = "Master", Ambience = "Master", Radio = "Master", Music = "Master", Voice = "Radio" }

function SettingsPanel.soundGroup(name: string): SoundGroup
	local parentName = PARENT[name]
	local parent: Instance = if parentName
		then SettingsPanel.soundGroup(parentName)
		else SoundService
	local g = parent:FindFirstChild(name)
	if g and g:IsA("SoundGroup") then
		return g
	end
	local created = Instance.new("SoundGroup")
	created.Name = name
	created.Parent = parent
	return created
end

local function audioController(): any
	local controllers = script.Parent.Parent:FindFirstChild("Controllers")
	local m = controllers and controllers:FindFirstChild("AudioController")
	if not (m and m:IsA("ModuleScript")) then
		return nil
	end
	local ok, mod = pcall(require, m)
	return if ok and type(mod) == "table" and type(mod.setVolume) == "function" then mod else nil
end

local function applyAudio()
	local mix = SettingsRules.mix(Comfort.all() :: any)
	for name, volume in mix do
		SettingsPanel.soundGroup(name).Volume = volume
	end
	local ac = audioController()
	if ac then
		for name, volume in mix do
			pcall(ac.setVolume, name, volume)
		end
	end
end

---------------------------------------------------------------- Assist / Pro

local proQueued = false
local function sendPro()
	if proQueued then
		return
	end
	proQueued = true
	task.delay(0.3, function()
		proQueued = false
		local net = ReplicatedStorage:FindFirstChild("Net")
		local remote = net and net:FindFirstChild("Settings_SetPro")
		if remote and remote:IsA("RemoteEvent") then
			remote:FireServer(Comfort.get("pro") == true)
		end
	end)
end

---------------------------------------------------------------- Hold to tap

-- One local pass over ProximityPrompts: hold-to-tap makes every hold prompt a tap (0 s). A prompt's
-- designed hold is remembered on the prompt so turning the setting off restores it.
local function applyHoldToTap()
	local on = Comfort.get("holdToTap") == true
	for _, d in Workspace:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			local base = d:GetAttribute("A11yHold")
			if type(base) ~= "number" then
				base = d.HoldDuration
				d:SetAttribute("A11yHold", base)
			end
			d.HoldDuration = if on then 0 else base
		end
	end
end

---------------------------------------------------------------- widgets

local function refresh(key: string)
	local list = refreshers[key]
	if list then
		for _, fn in list do
			fn()
		end
	end
	for _, fn in extraRefresh do
		fn()
	end
end

local function onRefresh(key: string, fn: () -> ())
	local list = refreshers[key]
	if not list then
		list = {}
		refreshers[key] = list
	end
	table.insert(list, fn)
	fn()
end

local function noteFirst(obj: GuiObject)
	if firstSelectable == nil then
		firstSelectable = obj
	end
end

local function smallButton(name: string, text: string, w: number, parent: Instance): TextButton
	local b = HudTheme.button(name, text, UDim2.fromOffset(w, 44), parent)
	b.BackgroundColor3 = C.panelLight
	b.TextSize = HudTheme.scaled(HudTheme.TextSize.body)
	b.Font = HudTheme.BodyFont
	return b
end

local order = 0
local function row(parent: Instance, name: string, label: string): (Frame, TextLabel)
	order += 1
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = UDim2.new(1, 0, 0, ROW)
	f.BackgroundTransparency = 1
	f.LayoutOrder = order
	f.Parent = parent
	local l = HudTheme.label(
		"Label",
		label,
		UDim2.new(0.42, -8, 1, 0),
		HudTheme.BodyFont,
		HudTheme.TextSize.body,
		f
	)
	l.TextColor3 = C.text
	return f, l
end

local function section(parent: Instance, title: string)
	order += 1
	local l = HudTheme.label(
		"Section_" .. title,
		string.upper(title),
		UDim2.new(1, 0, 0, 34),
		HudTheme.HeaderFont,
		HudTheme.TextSize.small,
		parent
	)
	l.TextColor3 = C.textDim
	l.TextYAlignment = Enum.TextYAlignment.Bottom
	l.LayoutOrder = order
	local rule = Instance.new("Frame")
	rule.Name = "Rule"
	rule.AnchorPoint = Vector2.new(0, 1)
	rule.Position = UDim2.new(0, 0, 1, 2)
	rule.Size = UDim2.new(1, 0, 0, 1)
	rule.BackgroundColor3 = C.edge
	rule.BackgroundTransparency = 0.85
	rule.BorderSizePixel = 0
	rule.Parent = l
end

local function note(parent: Instance, text: string): TextLabel
	order += 1
	local l = HudTheme.label(
		"Note",
		text,
		UDim2.fromScale(1, 0),
		HudTheme.BodyFont,
		HudTheme.TextSize.small,
		parent
	)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.TextWrapped = true
	l.TextTruncate = Enum.TextTruncate.None
	l.TextColor3 = C.textDim
	l.LayoutOrder = order
	return l
end

-- A number slider: [-] track [+] value. Mouse and touch drag the track; gamepad and taps use the
-- buttons (`step` each).
local function slider(
	parent: Instance,
	key: string,
	label: string,
	step: number,
	format: (number) -> string
)
	local range = SettingsRules.Ranges[key]
	local lo, hi = range[1], range[2]
	local f = row(parent, key, label)
	local control = Instance.new("Frame")
	control.Name = "Control"
	control.AnchorPoint = Vector2.new(1, 0.5)
	control.Position = UDim2.fromScale(1, 0.5)
	control.Size = UDim2.new(0.58, 0, 0, 44)
	control.BackgroundTransparency = 1
	control.Parent = f

	local minus = smallButton("Minus", "−", 44, control)
	noteFirst(minus)
	local plus = smallButton("Plus", "+", 44, control)
	plus.AnchorPoint = Vector2.new(1, 0)
	plus.Position = UDim2.new(1, -64, 0, 0)
	local value = HudTheme.label(
		"Value",
		"",
		UDim2.fromOffset(60, 44),
		HudTheme.BodyFont,
		HudTheme.TextSize.body,
		control
	)
	value.AnchorPoint = Vector2.new(1, 0)
	value.Position = UDim2.fromScale(1, 0)
	value.TextXAlignment = Enum.TextXAlignment.Right

	local track = Instance.new("TextButton")
	track.Name = "Track"
	track.Text = ""
	track.AutoButtonColor = false
	track.Selectable = false
	track.BackgroundTransparency = 1
	track.Position = UDim2.fromOffset(54, 0)
	track.Size = UDim2.new(1, -54 - 54 - 64, 1, 0)
	track.Parent = control
	local rail = Instance.new("Frame")
	rail.Name = "Rail"
	rail.AnchorPoint = Vector2.new(0, 0.5)
	rail.Position = UDim2.fromScale(0, 0.5)
	rail.Size = UDim2.new(1, 0, 0, 4)
	rail.BackgroundColor3 = C.panelLight
	rail.BorderSizePixel = 0
	rail.Parent = track
	HudTheme.corner(rail, 2)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = C.bar
	fill.BorderSizePixel = 0
	fill.Parent = rail
	HudTheme.corner(fill, 2)
	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.fromScale(0, 0.5)
	knob.Size = UDim2.fromOffset(16, 16)
	knob.BackgroundColor3 = C.text
	knob.BorderSizePixel = 0
	knob.Parent = rail
	HudTheme.corner(knob, 8)

	onRefresh(key, function()
		local v = Comfort.get(key) :: number
		local a = math.clamp((v - lo) / (hi - lo), 0, 1)
		fill.Size = UDim2.fromScale(a, 1)
		knob.Position = UDim2.fromScale(a, 0.5)
		value.Text = format(v)
	end)
	local function snap(v: number): number
		return math.clamp(math.round(v / step) * step, lo, hi)
	end
	minus.Activated:Connect(function()
		Comfort.set(key, snap((Comfort.get(key) :: number) - step))
	end)
	plus.Activated:Connect(function()
		Comfort.set(key, snap((Comfort.get(key) :: number) + step))
	end)

	local dragging: InputObject? = nil
	local function setFromX(x: number)
		local w = rail.AbsoluteSize.X
		if w < 1 then
			return
		end
		local a = math.clamp((x - rail.AbsolutePosition.X) / w, 0, 1)
		local fine = step / 5
		Comfort.set(key, math.clamp(math.round((lo + a * (hi - lo)) / fine) * fine, lo, hi))
	end
	track.InputBegan:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			dragging = input
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if dragging == nil then
			return
		end
		local t = input.UserInputType
		if
			(
				t == Enum.UserInputType.MouseMovement
				and dragging.UserInputType == Enum.UserInputType.MouseButton1
			) or input == dragging
		then
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if dragging and (input == dragging or input.UserInputType == dragging.UserInputType) then
			dragging = nil
		end
	end)
end

-- A row of mutually exclusive buttons; `options` are { label, value } pairs.
local function segmented(
	parent: Instance,
	key: string,
	label: string,
	options: { { any } },
	onPick: ((any) -> ())?
)
	local f = row(parent, key, label)
	local control = Instance.new("Frame")
	control.Name = "Control"
	control.AnchorPoint = Vector2.new(1, 0.5)
	control.Position = UDim2.fromScale(1, 0.5)
	control.Size = UDim2.new(0.58, 0, 0, 44)
	control.BackgroundTransparency = 1
	control.Parent = f
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = control
	local n = #options
	local buttons: { TextButton } = {}
	for i, opt in options do
		local b = smallButton(`Opt_{tostring(opt[2])}`, opt[1] :: string, 0, control)
		b.Size = UDim2.new(1 / n, -6 * (n - 1) / n, 1, 0)
		b.LayoutOrder = i
		b.TextSize = HudTheme.scaled(HudTheme.TextSize.small)
		noteFirst(b)
		buttons[i] = b
		b.Activated:Connect(function()
			if onPick then
				onPick(opt[2])
			else
				Comfort.set(key, opt[2])
			end
		end)
	end
	onRefresh(key, function()
		local v = Comfort.get(key)
		for i, b in buttons do
			local on = options[i][2] == v
			b.BackgroundColor3 = if on then C.accent else C.panelLight
			b.TextColor3 = if on then C.text else C.textDim
			b.Font = if on then HudTheme.HeaderFont else HudTheme.BodyFont
		end
	end)
end

local function toggle(parent: Instance, key: string, label: string)
	segmented(parent, key, label, { { "Off", false }, { "On", true } })
end

local function pct(v: number): string
	return `{math.round(v * 100)}%`
end

---------------------------------------------------------------- build

local function build()
	local g = Instance.new("ScreenGui")
	g.Name = "Settings"
	g.ResetOnSpawn = false
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.DisplayOrder = DISPLAY_ORDER
	Layout.prepare(g)
	g.Enabled = false
	gui = g

	-- dim the world behind the panel (and free the mouse in first person)
	local shade = Instance.new("TextButton")
	shade.Name = "Shade"
	shade.Text = ""
	shade.AutoButtonColor = false
	shade.Selectable = false
	shade.Modal = true
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.55
	shade.BorderSizePixel = 0
	shade.Parent = g
	shade.Activated:Connect(function()
		SettingsPanel.setOpen(false)
	end)

	local p = HudTheme.panel("Panel", UDim2.fromOffset(PANEL_W, PANEL_H), g)
	p.AnchorPoint = Vector2.new(0.5, 0.5)
	p.Position = UDim2.fromScale(0.5, 0.5)
	p.BackgroundTransparency = HudTheme.PromptTransparency
	p.Active = true
	local scale = Instance.new("UIScale")
	scale.Parent = p
	HudTheme.padding(p, 16)
	panel = p

	local title = HudTheme.label(
		"Title",
		"Settings",
		UDim2.new(1, -60, 0, 44),
		HudTheme.HeaderFont,
		HudTheme.TextSize.title,
		p
	)
	title.TextColor3 = C.text
	local close = smallButton("Close", "✕", 44, p)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.fromScale(1, 0)
	close.Activated:Connect(function()
		SettingsPanel.setOpen(false)
	end)

	-- preset strip
	local presets = Instance.new("Frame")
	presets.Name = "Presets"
	presets.Position = UDim2.fromOffset(0, 52)
	presets.Size = UDim2.new(1, 0, 0, 44)
	presets.BackgroundTransparency = 1
	presets.Parent = p
	local seasick = smallButton("Seasick", "Seasick-safe", 0, presets)
	seasick.Size = UDim2.new(0.5, -4, 1, 0)
	local reset = smallButton("Reset", "Reset comfort", 0, presets)
	reset.AnchorPoint = Vector2.new(1, 0)
	reset.Position = UDim2.fromScale(1, 0)
	reset.Size = UDim2.new(0.5, -4, 1, 0)
	seasick.Activated:Connect(function()
		Comfort.setMany(SettingsRules.SEASICK)
	end)
	reset.Activated:Connect(function()
		local d: { [string]: any } = {}
		for _, k in SettingsRules.COMFORT_KEYS do
			d[k] = (SettingsRules.Defaults :: any)[k]
		end
		Comfort.setMany(d)
	end)
	table.insert(extraRefresh, function()
		local on = SettingsRules.isPreset(Comfort.all() :: any, SettingsRules.SEASICK)
		seasick.BackgroundColor3 = if on then C.accent else C.panelLight
		seasick.Text = if on then "Seasick-safe  ✓" else "Seasick-safe"
	end)

	local s = Instance.new("ScrollingFrame")
	s.Name = "List"
	s.Position = UDim2.fromOffset(0, 104)
	s.Size = UDim2.new(1, 0, 1, -104)
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 4
	s.ScrollBarImageColor3 = C.textDim
	s.ScrollingDirection = Enum.ScrollingDirection.Y
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.CanvasSize = UDim2.new()
	s.Selectable = false
	s.Parent = p
	scroller = s
	local inner = Instance.new("UIPadding")
	inner.PaddingRight = UDim.new(0, 12)
	inner.Parent = s
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 2)
	list.Parent = s

	section(s, "Comfort")
	slider(s, "horizonStab", "Horizon stabilisation", 0.05, pct)
	slider(s, "fov", "Field of view", 5, function(v)
		return `{math.round(v)}°`
	end)
	slider(s, "headBob", "Head bob", 0.05, pct)
	slider(s, "shake", "Camera shake", 0.05, pct)
	slider(s, "gLean", "G-force lean", 0.05, pct)
	slider(s, "sensitivity", "Look sensitivity", 0.1, function(v)
		return string.format("%.1fx", v)
	end)
	toggle(s, "speedFov", "Speed FOV kick")
	toggle(s, "motionBlur", "Motion blur")
	toggle(s, "lensSpray", "Lens spray")

	section(s, "Accessibility")
	segmented(s, "colourAssist", "Colour assist", {
		{ "Off", "Off" },
		{ "Deut", "Deuteranopia" },
		{ "Prot", "Protanopia" },
		{ "Trit", "Tritanopia" },
	})
	segmented(s, "textSize", "Text size", {
		{ "100%", 100 },
		{ "125%", 125 },
		{ "150%", 150 },
	})
	toggle(s, "reduceMotion", "Reduce motion")
	toggle(s, "holdToTap", "Hold to tap")

	section(s, "Graphics")
	local q = { { "Auto", "Auto" }, { "High", "High" }, { "Med", "Medium" }, { "Low", "Low" } }
	segmented(s, "oceanQuality", "Ocean detail", q)
	segmented(s, "scatterQuality", "Rocks and plants", q)

	section(s, "Audio")
	slider(s, "volMaster", "Master", 0.05, pct)
	slider(s, "volSfx", "Effects", 0.05, pct)
	slider(s, "volRadio", "Radio", 0.05, pct)
	slider(s, "volMusic", "Music", 0.05, pct)
	toggle(s, "voice", "Radio voices")
	toggle(s, "muteHorns", "Mute horns")
	toggle(s, "muteSirens", "Mute sirens")
	toggle(s, "muteRadios", "Mute radios")

	section(s, "Operations")
	segmented(s, "pro", "Mode", { { "Assist", false }, { "Pro", true } })
	local proNote = note(s, "")
	local function updateProNote()
		local want = Comfort.get("pro") == true
		local active = player:GetAttribute("OpsPro") == true
		local base = if want then "No hints · +20% Rep" else "Hints on"
		if want and not active then
			base ..= "\nNext op"
		end
		proNote.Text = base
	end
	table.insert(extraRefresh, updateProNote)
	player:GetAttributeChangedSignal("OpsPro"):Connect(updateProNote)
	updateProNote()

	-- Owned items (RP-M5): one cycler per cosmetic slot whose game pass the player owns
	section(s, "Owned items")
	order += 1
	local owned = Instance.new("Frame")
	owned.Name = "OwnedItems"
	owned.Size = UDim2.fromScale(1, 0)
	owned.AutomaticSize = Enum.AutomaticSize.Y
	owned.BackgroundTransparency = 1
	owned.LayoutOrder = order
	owned.Parent = s
	local ownedList = Instance.new("UIListLayout")
	ownedList.SortOrder = Enum.SortOrder.LayoutOrder
	ownedList.Padding = UDim.new(0, 8)
	ownedList.Parent = owned
	local ownedNote = note(s, "")
	local pickers: { CosmeticPicker.Picker } = {}
	local function ownsPass(key: string): boolean
		return player:GetAttribute("Pass_" .. key) == true
	end
	local function rebuildOwned()
		for _, picker in pickers do
			picker.destroy()
		end
		table.clear(pickers)
		for i, slot in Cosmetics.slots() do
			if Cosmetics.ownsSlot(slot, ownsPass) then
				table.insert(pickers, CosmeticPicker.new(owned, slot, { layoutOrder = i }))
			end
		end
		ownedNote.Text = if #pickers == 0 then "None · Chandlery" else ""
	end
	rebuildOwned()
	player.AttributeChanged:Connect(function(attr: string)
		if string.sub(attr, 1, 5) == "Pass_" then
			rebuildOwned()
		end
	end)
	for _, fn in extraRefresh do
		fn()
	end

	local function fit(mt: Layout.Metrics)
		scale.Scale = mt.scale
		local w = math.min(PANEL_W, mt.usable.X - 24)
		local h = math.min(PANEL_H, mt.usable.Y - 16)
		p.Size = UDim2.fromOffset(w, h)
	end
	fit(Layout.current())
	Layout.onMetrics(fit)
	g.Parent = player:WaitForChild("PlayerGui")
end

---------------------------------------------------------------- open / close

local function onBack(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		SettingsPanel.setOpen(false)
	end
	return Enum.ContextActionResult.Sink
end

function SettingsPanel.isOpen(): boolean
	return open
end

function SettingsPanel.setOpen(value: boolean)
	local g = gui
	if not g or value == open then
		return
	end
	open = value
	g.Enabled = value
	if value then
		ContextActionService:BindActionAtPriority(
			"SettingsBack",
			onBack,
			false,
			Enum.ContextActionPriority.High.Value + 10,
			Enum.KeyCode.ButtonB
		)
		local s = scroller
		if s then
			s.CanvasPosition = Vector2.zero
		end
		if UserInputService.GamepadEnabled and firstSelectable then
			GuiService.SelectedObject = firstSelectable
		end
	else
		ContextActionService:UnbindAction("SettingsBack")
		local sel = GuiService.SelectedObject
		if sel and panel and sel:IsDescendantOf(panel) then
			GuiService.SelectedObject = nil
		end
	end
end

function SettingsPanel.mount()
	if gui then
		return
	end
	build()
	applyAudio()
	A11yPalette.setMode(Comfort.get("colourAssist") :: string)
	applyHoldToTap()
	Workspace.DescendantAdded:Connect(function(d: Instance)
		if d:IsA("ProximityPrompt") and Comfort.get("holdToTap") == true then
			local base = d:GetAttribute("A11yHold")
			if type(base) ~= "number" then
				base = d.HoldDuration
				d:SetAttribute("A11yHold", base)
			end
			d.HoldDuration = 0
		end
	end)
	Comfort.changed:Connect(function(key: string)
		refresh(key)
		if string.sub(key, 1, 3) == "vol" or key == "voice" then
			applyAudio()
		elseif key == "pro" then
			sendPro()
		elseif key == "colourAssist" then
			A11yPalette.setMode(Comfort.get("colourAssist") :: string)
		elseif key == "holdToTap" then
			applyHoldToTap()
		end
	end)
	Comfort.whenReady(sendPro)
end

return SettingsPanel
