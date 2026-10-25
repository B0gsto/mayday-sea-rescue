--!strict
-- SettingsPanel: the settings menu (docs 13 RP-S1). Camera comfort (FOV, shake, look sensitivity,
-- speed FOV), a "Seasick-safe" preset, a graphics override (ocean and scatter detail), volumes (master,
-- effects, voices, music), NPC voices on/off, muting other players' horns / sirens / radios, and
-- "Owned items": a CosmeticPicker per cosmetic slot the player owns (RP-M5).
--
-- Layout: the stock iOS Settings look, a dark grouped list in one ScrollingFrame (icon tile,
-- 1-3 word label, switch / slider / segmented control per row).
--
-- Lives on the phone: its Settings app (gamepad Start opens it) borrows the panel frame onto the
-- phone screen. setOpen still shows it standalone (X or gamepad B closes).
-- Values live in Camera/Comfort (saved on the profile; keys and rules in shared/SettingsRules).
--
-- Audio: sets the AudioConfig SoundGroup tree (SoundService.Master > Music, SFX, Ambience, Radio >
-- Voice) to the slider values; "Radio" is the NPC voice level and "Voice" is muted while voice is off. Sounds
-- join a group through Sound.SoundGroup (SettingsPanel.soundGroup(name) finds or makes it).
--
--   SettingsPanel.mount()   HudController calls this once
--   SettingsPanel.setOpen(open) / SettingsPanel.isOpen()
--   SettingsPanel.soundGroup(channel): SoundGroup
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local A11yPalette = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("A11yPalette"))
local Comfort = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("Comfort"))
local CosmeticPicker = require(script.Parent:WaitForChild("CosmeticPicker"))
local Cosmetics = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Cosmetics"))
local Glyph = require(script.Parent:WaitForChild("Glyph"))
local HudTheme = require(script.Parent:WaitForChild("HudTheme"))
local Layout = require(script.Parent:WaitForChild("Layout"))
local SettingsRules =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SettingsRules"))
local SettingsArt = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UiImages")
).SettingsArt

local player = Players.LocalPlayer

local SettingsPanel = {}

local DISPLAY_ORDER = 40 -- above the store panels (35), below Cinematic (50)
local PANEL_W = 340
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

-- iOS-style dark grouped list: black page, #1C1C1E groups, a coloured icon tile per row.
local BG = Color3.fromHex("000000")
local GROUP = Color3.fromHex("1C1C1E")
local HAIR = Color3.fromHex("38383A")
local DIM = Color3.fromHex("98989F")
local SEG = Color3.fromHex("313135")
local SEG_ON = Color3.fromHex("636366")
local OFF = Color3.fromHex("39393D")
local Tint = {
	red = Color3.fromHex("FF453A"),
	orange = Color3.fromHex("FF9F0A"),
	yellow = Color3.fromHex("E5B800"),
	green = Color3.fromHex("30D158"),
	teal = Color3.fromHex("40C8E0"),
	blue = Color3.fromHex("0A84FF"),
	indigo = Color3.fromHex("5E5CE6"),
	purple = Color3.fromHex("BF5AF2"),
	pink = Color3.fromHex("FF375F"),
	grey = Color3.fromHex("8E8E93"),
}
local LINE = 52 -- du: one-line row (icon, label, control on the right)
local TALL = 104 -- du: label line + a full-width slider or segmented control under it
local INSET = 54 -- du: label x (12 margin + 30 tile + 12 gap); separators start here
-- Row icons drawn from Frames (symbol characters may not exist in Roblox fonts). Unknown keys
-- draw as text, so plain letters ("A") stay letters.
local V2 = Vector2.new
local WHITE = Color3.new(1, 1, 1)
local function bar(p: Instance, w: number, h: number, x: number, y: number, r: number?): Frame
	return Glyph.bar(p, V2(w, h), V2(x, y), r or 0, WHITE)
end
local function zig(p: Instance, y: number)
	for i, x in { 0.27, 0.5, 0.73 } do
		bar(p, 0.28, 0.1, x, y, if i == 2 then 30 else -30)
	end
end
local function circle(p: Instance, d: number, x: number, y: number)
	local c = bar(p, d, d, x, y)
	c.BackgroundTransparency = 1
	local st = Instance.new("UIStroke")
	st.Color = WHITE
	st.Thickness = 2
	st.Parent = c
	return c
end
local function note(p: Instance, x: number)
	bar(p, 0.24, 0.2, x - 0.08, 0.72)
	bar(p, 0.09, 0.52, x, 0.44)
end
local SHAPES: { [string]: (Frame) -> () } = {
	waves = function(p)
		zig(p, 0.4)
		zig(p, 0.62)
	end,
	wave = function(p)
		zig(p, 0.5)
	end,
	shake = function(p)
		zig(p, 0.3)
		zig(p, 0.5)
		zig(p, 0.7)
	end,
	reset = function(p)
		circle(p, 0.58, 0.5, 0.52)
		bar(p, 0.26, 0.1, 0.2, 0.3, 60) -- the arrowhead on the rim
		bar(p, 0.26, 0.1, 0.32, 0.18, -20)
	end,
	fov = function(p)
		bar(p, 0.62, 0.1, 0.36, 0.5, -28)
		bar(p, 0.62, 0.1, 0.36, 0.5, 28)
		bar(p, 0.12, 0.12, 0.1, 0.5)
	end,
	plus = function(p)
		circle(p, 0.66, 0.5, 0.5)
		bar(p, 0.4, 0.1, 0.5, 0.5)
		bar(p, 0.1, 0.4, 0.5, 0.5)
	end,
	speed = function(p)
		Glyph.draw("speed", p, WHITE)
	end,
	half = function(p)
		circle(p, 0.66, 0.5, 0.5)
		local fill = bar(p, 0.66, 0.66, 0.5, 0.5)
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 1),
			NumberSequenceKeypoint.new(0.501, 0),
			NumberSequenceKeypoint.new(1, 0),
		})
		g.Parent = fill
	end,
	pause = function(p)
		bar(p, 0.14, 0.56, 0.36, 0.5, nil)
		bar(p, 0.14, 0.56, 0.64, 0.5, nil)
	end,
	tap = function(p)
		circle(p, 0.66, 0.5, 0.5)
		bar(p, 0.26, 0.26, 0.5, 0.5)
	end,
	peak = function(p)
		bar(p, 0.5, 0.11, 0.34, 0.46, -58)
		bar(p, 0.5, 0.11, 0.66, 0.46, 58)
		bar(p, 0.74, 0.11, 0.5, 0.7)
	end,
	note = function(p)
		note(p, 0.56)
		bar(p, 0.24, 0.09, 0.66, 0.24, 35)
	end,
	notes = function(p)
		note(p, 0.38)
		note(p, 0.74)
		bar(p, 0.42, 0.1, 0.56, 0.2, -10)
	end,
	sparkle = function(p)
		bar(p, 0.12, 0.7, 0.5, 0.5)
		bar(p, 0.7, 0.12, 0.5, 0.5)
		bar(p, 0.3, 0.3, 0.5, 0.5, 45)
	end,
	burst = function(p)
		for _, r in { 0, 45, 90, 135 } do
			bar(p, 0.72, 0.09, 0.5, 0.5, r)
		end
		bar(p, 0.34, 0.34, 0.5, 0.5)
	end,
	star = function(p)
		for _, r in { 0, 60, 120 } do
			bar(p, 0.12, 0.7, 0.5, 0.5, r)
		end
	end,
	bubble = function(p)
		Glyph.bar(p, V2(0.7, 0.48), V2(0.5, 0.44), 0, WHITE, 0.4)
		bar(p, 0.12, 0.26, 0.36, 0.7, 30)
	end,
	horn = function(p)
		Glyph.bar(p, V2(0.2, 0.3), V2(0.28, 0.5), 0, WHITE, 0.2)
		bar(p, 0.32, 0.1, 0.5, 0.36, -35)
		bar(p, 0.32, 0.1, 0.5, 0.64, 35)
		bar(p, 0.1, 0.62, 0.66, 0.5)
	end,
	no = function(p)
		circle(p, 0.66, 0.5, 0.5)
		bar(p, 0.62, 0.1, 0.5, 0.5, -45)
	end,
}

local SWITCH = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

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

local function hairline(parent: Instance, x: number)
	local h = Instance.new("Frame")
	h.Name = "Hairline"
	h.Position = UDim2.fromOffset(x, 0)
	h.Size = UDim2.new(1, -x, 0, 1)
	h.BackgroundColor3 = HAIR
	h.BorderSizePixel = 0
	h.Parent = parent
end

local order = 0
local rowsIn: { [Instance]: number } = {}

-- A row in a group: icon tile + label on the top line. `reserve` keeps the label clear of the
-- control on its right.
local function row(
	group: Frame,
	name: string,
	glyph: string,
	tint: Color3,
	label: string,
	height: number,
	reserve: number
): Frame
	order += 1
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = UDim2.new(1, 0, 0, height)
	f.BackgroundTransparency = 1
	f.LayoutOrder = order
	f.Parent = group
	local n = (rowsIn[group] or 0) + 1
	rowsIn[group] = n
	if n > 1 then
		hairline(f, INSET)
	end
	local tile = Instance.new("Frame")
	tile.Name = "Icon"
	tile.Position = UDim2.fromOffset(12, (LINE - 30) / 2)
	tile.Size = UDim2.fromOffset(30, 30)
	tile.BackgroundColor3 = tint
	tile.BorderSizePixel = 0
	tile.Parent = f
	HudTheme.corner(tile, 7)
	local shape = SHAPES[glyph]
	local art = SettingsArt[glyph] -- an uploaded white glyph (docs/18) over the drawn one
	local image = if art and art ~= "" then art else nil
	local g =
		Instance.new(if image then "ImageLabel" elseif shape then "Frame" else "TextLabel") :: any
	g.Name = "Glyph"
	g.BackgroundTransparency = 1
	if image then
		g.AnchorPoint = Vector2.new(0.5, 0.5)
		g.Position = UDim2.fromScale(0.5, 0.5)
		g.Size = UDim2.fromScale(0.72, 0.72)
		g.Image = image
	elseif shape then
		g.AnchorPoint = Vector2.new(0.5, 0.5)
		g.Position = UDim2.fromScale(0.5, 0.5)
		g.Size = UDim2.fromScale(0.72, 0.72)
		shape(g)
	else
		g.Size = UDim2.fromScale(1, 1)
		g.Text = glyph
		g.Font = HudTheme.HeaderFont
		g.TextSize = 18
		g.TextColor3 = WHITE
	end
	g.Parent = tile
	local l = HudTheme.label(
		"Label",
		label,
		UDim2.new(1, -INSET - reserve, 0, LINE),
		HudTheme.BodyFont,
		20,
		f
	)
	l.Position = UDim2.fromOffset(INSET, 0)
	l.TextColor3 = Color3.new(1, 1, 1)
	return f
end

-- A small caps header and the rounded group under it; rows go in the returned group.
local function section(parent: Instance, title: string): Frame
	order += 1
	local l = HudTheme.label(
		"Section_" .. title,
		string.upper(title),
		UDim2.new(1, 0, 0, 40),
		HudTheme.BodyFont,
		18,
		parent
	)
	l.TextColor3 = DIM
	l.TextYAlignment = Enum.TextYAlignment.Bottom
	l.LayoutOrder = order
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = l
	order += 1
	local g = Instance.new("Frame")
	g.Name = "Group_" .. title
	g.Size = UDim2.fromScale(1, 0)
	g.AutomaticSize = Enum.AutomaticSize.Y
	g.BackgroundColor3 = GROUP
	g.BorderSizePixel = 0
	g.LayoutOrder = order
	g.Parent = parent
	HudTheme.corner(g, 12)
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = g
	return g
end

-- right-aligned grey value on a row's top line
local function valueLabel(f: Frame, w: number): TextLabel
	local v = HudTheme.label("Value", "", UDim2.fromOffset(w, LINE), HudTheme.BodyFont, 18, f)
	v.AnchorPoint = Vector2.new(1, 0)
	v.Position = UDim2.new(1, -12, 0, 0)
	v.TextXAlignment = Enum.TextXAlignment.Right
	v.TextColor3 = DIM
	return v
end

-- the full-width strip under a tall row's label line
local function strip(f: Frame): Frame
	local c = Instance.new("Frame")
	c.Name = "Control"
	c.Position = UDim2.fromOffset(12, LINE - 2)
	c.Size = UDim2.new(1, -24, 0, 44)
	c.BackgroundTransparency = 1
	c.Parent = f
	return c
end

local function stepButton(name: string, text: string, parent: Instance): TextButton
	local b = HudTheme.button(name, text, UDim2.fromOffset(44, 44), parent)
	b.BackgroundTransparency = 1
	b.AutoButtonColor = false
	b.TextColor3 = DIM
	b.Font = HudTheme.HeaderFont
	return b
end

-- A number slider: [-] track [+], value on the label line. Mouse and touch drag the track;
-- gamepad and taps use the buttons (`step` each).
local function slider(
	group: Frame,
	key: string,
	glyph: string,
	tint: Color3,
	label: string,
	step: number,
	format: (number) -> string
)
	local range = SettingsRules.Ranges[key]
	local lo, hi = range[1], range[2]
	local f = row(group, key, glyph, tint, label, TALL, 70)
	local value = valueLabel(f, 64)
	local control = strip(f)

	local minus = stepButton("Minus", "-", control)
	noteFirst(minus)
	local plus = stepButton("Plus", "+", control)
	plus.AnchorPoint = Vector2.new(1, 0)
	plus.Position = UDim2.fromScale(1, 0)

	local track = Instance.new("TextButton")
	track.Name = "Track"
	track.Text = ""
	track.AutoButtonColor = false
	track.Selectable = false
	track.BackgroundTransparency = 1
	track.Position = UDim2.fromOffset(56, 0)
	track.Size = UDim2.new(1, -112, 1, 0)
	track.Parent = control
	local rail = Instance.new("Frame")
	rail.Name = "Rail"
	rail.AnchorPoint = Vector2.new(0, 0.5)
	rail.Position = UDim2.fromScale(0, 0.5)
	rail.Size = UDim2.new(1, 0, 0, 4)
	rail.BackgroundColor3 = OFF
	rail.BorderSizePixel = 0
	rail.Parent = track
	HudTheme.corner(rail, 2)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Tint.blue
	fill.BorderSizePixel = 0
	fill.Parent = rail
	HudTheme.corner(fill, 2)
	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.fromScale(0, 0.5)
	knob.Size = UDim2.fromOffset(26, 26)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.BorderSizePixel = 0
	knob.Parent = rail
	HudTheme.corner(knob, 13)

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

-- An iOS segmented control under the label; `options` are { label, value } pairs. Returns the row
-- (its top line has room for a value label).
local function segmented(
	group: Frame,
	key: string,
	glyph: string,
	tint: Color3,
	label: string,
	options: { { any } }
): Frame
	local f = row(group, key, glyph, tint, label, TALL, 100)
	local control = strip(f)
	control.BackgroundColor3 = SEG
	control.BackgroundTransparency = 0
	HudTheme.corner(control, 9)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 3)
	pad.PaddingRight = UDim.new(0, 3)
	pad.PaddingTop = UDim.new(0, 3)
	pad.PaddingBottom = UDim.new(0, 3)
	pad.Parent = control
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.Padding = UDim.new(0, 2)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = control
	local n = #options
	local buttons: { TextButton } = {}
	for i, opt in options do
		local b = HudTheme.button(`Opt_{tostring(opt[2])}`, opt[1] :: string, UDim2.new(), control)
		b.Size = UDim2.new(1 / n, -2 * (n - 1) / n, 1, 0)
		b.LayoutOrder = i
		b.AutoButtonColor = false
		b.BackgroundColor3 = SEG_ON
		HudTheme.corner(b, 7)
		noteFirst(b)
		buttons[i] = b
		b.Activated:Connect(function()
			Comfort.set(key, opt[2])
		end)
	end
	onRefresh(key, function()
		local v = Comfort.get(key)
		for i, b in buttons do
			local on = options[i][2] == v
			b.BackgroundTransparency = if on then 0 else 1
			b.TextColor3 = if on then Color3.new(1, 1, 1) else DIM
			b.Font = if on then HudTheme.HeaderFont else HudTheme.BodyFont
		end
	end)
	return f
end

-- An iOS pill switch (green on, knob slides). The hit area is the row's whole right end.
local function toggle(group: Frame, key: string, glyph: string, tint: Color3, label: string)
	local f = row(group, key, glyph, tint, label, LINE, 76)
	local hit = Instance.new("TextButton")
	hit.Name = "Switch"
	hit.Text = ""
	hit.AutoButtonColor = false
	hit.BackgroundTransparency = 1
	hit.AnchorPoint = Vector2.new(1, 0)
	hit.Position = UDim2.fromScale(1, 0)
	hit.Size = UDim2.new(0, 76, 1, 0)
	hit.Parent = f
	noteFirst(hit)
	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.AnchorPoint = Vector2.new(1, 0.5)
	pill.Position = UDim2.new(1, -12, 0.5, 0)
	pill.Size = UDim2.fromOffset(52, 32)
	pill.BorderSizePixel = 0
	pill.Parent = hit
	HudTheme.corner(pill, 16)
	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.AnchorPoint = Vector2.new(0, 0.5)
	knob.Size = UDim2.fromOffset(28, 28)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.BorderSizePixel = 0
	knob.Parent = pill
	HudTheme.corner(knob, 14)
	hit.Activated:Connect(function()
		Comfort.set(key, Comfort.get(key) ~= true)
	end)
	onRefresh(key, function()
		local on = Comfort.get(key) == true
		TweenService:Create(pill, SWITCH, { BackgroundColor3 = if on then Tint.green else OFF })
			:Play()
		TweenService:Create(knob, SWITCH, { Position = UDim2.new(0, if on then 22 else 2, 0.5, 0) })
			:Play()
	end)
end

-- A tappable row (the whole row is the button); returns the row's right-side mark.
local function action(
	group: Frame,
	name: string,
	glyph: string,
	tint: Color3,
	label: string,
	onTap: () -> ()
): TextLabel
	local f = row(group, name, glyph, tint, label, LINE, 40)
	local hit = Instance.new("TextButton")
	hit.Name = "Tap"
	hit.Text = ""
	hit.AutoButtonColor = false
	hit.BackgroundTransparency = 1
	hit.Size = UDim2.fromScale(1, 1)
	hit.Parent = f
	noteFirst(hit)
	hit.Activated:Connect(onTap)
	local mark = valueLabel(f, 30)
	mark.TextColor3 = Tint.blue
	mark.Font = HudTheme.HeaderFont
	return mark
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
	p.BackgroundColor3 = BG
	p.BackgroundTransparency = 0
	p.ClipsDescendants = true
	p.Active = true
	local scale = Instance.new("UIScale")
	scale.Parent = p
	panel = p

	local close = HudTheme.button("Close", "✕", UDim2.fromOffset(44, 44), p)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 10)
	close.BackgroundColor3 = GROUP
	close.TextColor3 = DIM
	close.ZIndex = 2
	HudTheme.corner(close, 22)
	close.Activated:Connect(function()
		SettingsPanel.setOpen(false)
	end)

	local s = Instance.new("ScrollingFrame")
	s.Name = "List"
	s.Size = UDim2.fromScale(1, 1)
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 3
	s.ScrollBarImageColor3 = DIM
	s.ScrollingDirection = Enum.ScrollingDirection.Y
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.CanvasSize = UDim2.new()
	s.Selectable = false
	s.Parent = p
	scroller = s
	local inner = Instance.new("UIPadding")
	inner.PaddingLeft = UDim.new(0, 12)
	inner.PaddingRight = UDim.new(0, 12)
	inner.PaddingTop = UDim.new(0, 8)
	inner.PaddingBottom = UDim.new(0, 28)
	inner.Parent = s
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = s

	-- iOS large title (scrolls with the list)
	order += 1
	local title =
		HudTheme.label("Title", "Settings", UDim2.new(1, -56, 0, 52), HudTheme.HeaderFont, 32, s)
	title.Position = UDim2.fromOffset(4, 0)
	title.TextColor3 = Color3.new(1, 1, 1)
	title.LayoutOrder = order

	local comfort = section(s, "Comfort")
	local seasick = action(comfort, "Seasick", "waves", Tint.teal, "Seasick-safe", function()
		Comfort.setMany(SettingsRules.SEASICK)
	end)
	action(comfort, "Reset", "reset", Tint.grey, "Reset", function()
		local d: { [string]: any } = {}
		for _, k in SettingsRules.COMFORT_KEYS do
			d[k] = (SettingsRules.Defaults :: any)[k]
		end
		Comfort.setMany(d)
	end)
	table.insert(extraRefresh, function()
		local on = SettingsRules.isPreset(Comfort.all() :: any, SettingsRules.SEASICK)
		seasick.Text = if on then "✓" else ""
	end)
	slider(comfort, "fov", "fov", Tint.indigo, "Field of view", 5, function(v)
		return `{math.round(v)}°`
	end)
	slider(comfort, "shake", "shake", Tint.red, "Shake", 0.05, pct)
	slider(comfort, "sensitivity", "plus", Tint.teal, "Sensitivity", 0.1, function(v)
		return string.format("%.1fx", v)
	end)
	toggle(comfort, "speedFov", "speed", Tint.orange, "Speed FOV")

	local access = section(s, "Accessibility")
	segmented(access, "colourAssist", "half", Tint.pink, "Colour assist", {
		{ "Off", "Off" },
		{ "Deut", "Deuteranopia" },
		{ "Prot", "Protanopia" },
		{ "Trit", "Tritanopia" },
	})
	segmented(access, "textSize", "A", Tint.blue, "Text size", {
		{ "100%", 100 },
		{ "125%", 125 },
		{ "150%", 150 },
	})
	toggle(access, "reduceMotion", "pause", Tint.green, "Reduce motion")
	toggle(access, "holdToTap", "tap", Tint.orange, "Hold to tap")

	local gfx = section(s, "Graphics")
	local q = { { "Auto", "Auto" }, { "High", "High" }, { "Med", "Medium" }, { "Low", "Low" } }
	segmented(gfx, "oceanQuality", "waves", Tint.blue, "Ocean", q)
	segmented(gfx, "scatterQuality", "peak", Tint.green, "Rocks & plants", q)

	local audio = section(s, "Audio")
	slider(audio, "volMaster", "note", Tint.red, "Master", 0.05, pct)
	slider(audio, "volSfx", "sparkle", Tint.orange, "Effects", 0.05, pct)
	slider(audio, "volRadio", "wave", Tint.teal, "Voices", 0.05, pct)
	slider(audio, "volMusic", "notes", Tint.pink, "Music", 0.05, pct)
	toggle(audio, "voice", "bubble", Tint.purple, "Voices on")
	toggle(audio, "muteHorns", "horn", Tint.grey, "Mute horns")
	toggle(audio, "muteSirens", "burst", Tint.red, "Mute sirens")
	toggle(audio, "muteRadios", "no", Tint.grey, "Mute radios")

	-- Owned items (RP-M5): one cycler per cosmetic slot whose game pass the player owns
	local owned = section(s, "Owned items")
	owned.Name = "OwnedItems"
	local ownedPad = Instance.new("UIPadding")
	ownedPad.PaddingLeft = UDim.new(0, 12)
	ownedPad.PaddingRight = UDim.new(0, 12)
	ownedPad.Parent = owned
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
				local picker = CosmeticPicker.new(owned, slot, { layoutOrder = i, height = LINE })
				if #pickers > 0 then
					hairline(picker.frame, 0)
				end
				table.insert(pickers, picker)
			end
		end
		-- nothing owned: no empty section
		owned.Visible = #pickers > 0
		local header = s:FindFirstChild("Section_Owned items")
		if header and header:IsA("GuiObject") then
			header.Visible = owned.Visible
		end
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
		elseif key == "colourAssist" then
			A11yPalette.setMode(Comfort.get("colourAssist") :: string)
		elseif key == "holdToTap" then
			applyHoldToTap()
		end
	end)
end

return SettingsPanel
