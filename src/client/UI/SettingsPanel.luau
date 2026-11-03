--!strict
-- SettingsPanel: the kit settings window. Camera comfort, accessibility, graphics, the audio mix
-- (Master > Music, SFX, Ambience, Radio > Voice) and the owned cosmetic pickers.
--
--   SettingsPanel.mount()                  HudController/Menu calls this once (audio + hold rules)
--   SettingsPanel.newPanel(canvas, onClose)  the Menu's Settings panel
--   SettingsPanel.soundGroup(channel)      every sound joins the mix through this
local A11yPalette =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("A11yPalette"))
local Comfort = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("Comfort"))
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local SettingsRules = require(Shared:WaitForChild("SettingsRules"))
local UiImages = require(Shared:WaitForChild("Config"):WaitForChild("UiImages"))
local SettingsArt = UiImages.SettingsArt

local CosmeticPicker = require(script.Parent:WaitForChild("CosmeticPicker"))
local Glyph = require(script.Parent:WaitForChild("Glyph"))
local Kit = script.Parent:WaitForChild("Kit")
local Panel = require(Kit:WaitForChild("Panel"))
local Style = require(Kit:WaitForChild("Style"))
local Theme = require(Kit:WaitForChild("Theme"))
local Toggle = require(Kit:WaitForChild("Toggle"))

local player = Players.LocalPlayer
local S = Theme.Size
local SettingsPanel = {}

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

local function pct(v: number): string
	return `{math.round(v * 100)}%`
end

local function art(parent: Instance, name: string, color: string)
	local tile = Instance.new("Frame")
	tile.Name = "Icon"
	tile.BackgroundColor3 = Style.grad(color).top
	tile.AnchorPoint = Vector2.new(0, 0.5)
	tile.Position = UDim2.new(0, 12, 0.5, 0)
	tile.Size = UDim2.fromOffset(52, 52)
	tile.Parent = parent
	Style.corner(tile, S.cornerSmall)
	Style.stroke(tile, 3, true)
	local id = SettingsArt[name]
	if type(id) == "string" and id ~= "" then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = id
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, 0.5)
		img.Size = UDim2.fromScale(0.88, 0.88) -- the glyphs sit in a padded canvas: ~75% of the tile (in-game ADs, 2026-11-01)
		img.Parent = tile
	else
		local letter = Style.label(tile, string.upper(string.sub(name, 1, 1)), 30)
		letter.TextScaled = true
	end
end

local function section(parent: Instance, order: number, title: string): number
	local l = Style.label(parent, string.upper(title), Theme.Text.body, true)
	l.Size = UDim2.new(1, -8, 0, 36)
	l.LayoutOrder = order
	l.TextXAlignment = Enum.TextXAlignment.Left
	return order + 1
end

local function rowRoot(parent: Instance, order: number, height: number): Frame
	local row = Instance.new("Frame")
	row.Name = "Setting"
	row.Size = UDim2.new(1, 0, 0, height)
	row.BackgroundTransparency = 1
	row.LayoutOrder = order
	row.Parent = parent
	local holder, face = Style.block(row, Style.grad("body"), { lip = 5, radius = S.cornerSmall })
	holder.Name = "Row"
	local labelLine = Instance.new("Frame")
	labelLine.Name = "LabelLine"
	labelLine.BackgroundTransparency = 1
	labelLine.Size = UDim2.new(1, 0, 0, 70)
	labelLine.Parent = face
	return row
end

local function rowLabel(parent: Instance, text: string, right: number): TextLabel
	local l = Style.label(parent, text, Theme.Text.body, true)
	l.Position = UDim2.fromOffset(78, 0)
	l.Size = UDim2.new(1, -78 - right, 0, 70)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = false
	l.TextTruncate = Enum.TextTruncate.AtEnd
	return l
end

-- `key`: a Comfort flag, or the switch's own state and handler (the Seasick-safe preset)
local function toggleRow(
	parent: Instance,
	order: number,
	key: string | { on: boolean, onChange: (boolean) -> () },
	artName: string,
	color: string,
	label: string
): (Frame, Toggle.Toggle)
	local row = rowRoot(parent, order, 82)
	local line = row:FindFirstChild("LabelLine", true) :: Frame
	art(line, artName, color)
	rowLabel(line, label, 150)
	local t = Toggle.new(
		line,
		if type(key) == "table"
			then key
			else {
				on = Comfort.get(key) == true,
				onChange = function(on)
					Comfort.set(key, on)
				end,
			}
	)
	t.root.AnchorPoint = Vector2.new(1, 0.5)
	t.root.Position = UDim2.new(1, -14, 0.5, 0)
	return row, t
end

-- a chunky white minus / plus on a slider end button: Glyph bars over an ink drop (text "-" read as a slot)
local function sign(face: Frame, plus: boolean)
	for i, colour in { Theme.Colors.ink, Color3.new(1, 1, 1) } do
		local box = Instance.new("Frame")
		box.BackgroundTransparency = 1
		box.AnchorPoint = Vector2.new(0.5, 0.5)
		box.Position = UDim2.new(0.5, 0, 0.5, if i == 1 then 3 else 0)
		box.Size = UDim2.fromScale(0.78, 0.78)
		box.Parent = face
		Instance.new("UIAspectRatioConstraint").Parent = box
		Glyph.bar(box, Vector2.new(0.84, 0.26), Vector2.new(0.5, 0.5), 0, colour, 0.3)
		if plus then
			Glyph.bar(box, Vector2.new(0.26, 0.84), Vector2.new(0.5, 0.5), 0, colour, 0.3)
		end
	end
end

local function sliderRow(
	parent: Instance,
	order: number,
	key: string,
	artName: string,
	color: string,
	label: string,
	step: number,
	format: (number) -> string
)
	local range = SettingsRules.Ranges[key]
	local lo, hi = range[1], range[2]
	local row = rowRoot(parent, order, 150)
	local line = row:FindFirstChild("LabelLine", true) :: Frame
	art(line, artName, color)
	rowLabel(line, label, 110)
	local value = Style.label(line, "", Theme.Text.heading, true)
	value.AnchorPoint = Vector2.new(1, 0)
	value.Position = UDim2.new(1, -16, 0, 0)
	value.Size = UDim2.fromOffset(100, 70)
	value.TextXAlignment = Enum.TextXAlignment.Right

	local strip = Instance.new("Frame")
	strip.Name = "Control"
	strip.BackgroundTransparency = 1
	strip.Position = UDim2.fromOffset(78, 74)
	strip.Size = UDim2.new(1, -92, 0, 56)
	strip.Parent = (row:FindFirstChild("Row") :: Frame):FindFirstChild("Face")

	-- 56 du: a 39 pt tap target at the 0.7 phone floor
	local minus = Style.button(strip, UDim2.fromOffset(56, 56))
	local _, mFace = Style.block(minus, Style.grad("blue"), { lip = 4, radius = S.cornerSmall })
	sign(mFace, false)
	local plus = Style.button(strip, UDim2.fromOffset(56, 56))
	plus.AnchorPoint = Vector2.new(1, 0)
	plus.Position = UDim2.fromScale(1, 0)
	local _, pFace = Style.block(plus, Style.grad("blue"), { lip = 4, radius = S.cornerSmall })
	sign(pFace, true)

	local track = Instance.new("TextButton")
	track.Name = "Track"
	track.Text = ""
	track.AutoButtonColor = false
	track.Selectable = false
	track.BackgroundTransparency = 1
	track.Position = UDim2.fromOffset(68, 0)
	track.Size = UDim2.new(1, -136, 1, 0)
	track.Parent = strip
	local rail = Instance.new("Frame")
	rail.AnchorPoint = Vector2.new(0, 0.5)
	rail.Position = UDim2.fromScale(0, 0.5)
	rail.Size = UDim2.new(1, 0, 0, 18)
	rail.BackgroundColor3 = Theme.Colors.ink
	rail.Parent = track
	Style.corner(rail, 9)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Style.grad("blue").top
	fill.Parent = rail
	Style.corner(fill, 9)
	local knob = Instance.new("Frame")
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Size = UDim2.fromOffset(32, 32)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.Parent = track
	Style.corner(knob, 16)
	Style.stroke(knob, 4, true)

	local function paint()
		local v = Comfort.get(key) :: number
		local a = math.clamp((v - lo) / (hi - lo), 0, 1)
		fill.Size = UDim2.fromScale(a, 1)
		knob.Position = UDim2.fromScale(a, 0.5)
		value.Text = format(v)
	end
	local function snap(v: number): number
		return math.clamp(math.round(v / step) * step, lo, hi)
	end
	paint()
	Style.press(minus, function()
		Comfort.set(key, snap((Comfort.get(key) :: number) - step))
		paint()
	end, S.cornerSmall)
	Style.press(plus, function()
		Comfort.set(key, snap((Comfort.get(key) :: number) + step))
		paint()
	end, S.cornerSmall)

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
	track.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			dragging = input
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		local d = dragging
		if not d then
			return
		end
		local t = input.UserInputType
		if
			(
				t == Enum.UserInputType.MouseMovement
				and d.UserInputType == Enum.UserInputType.MouseButton1
			) or rawequal(input, d)
		then
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local d = dragging
		if d and (rawequal(input, d) or input.UserInputType == d.UserInputType) then
			dragging = nil
		end
	end)
	return row, paint
end

local function segmentRow(
	parent: Instance,
	order: number,
	key: string,
	artName: string,
	color: string,
	label: string,
	options: { { any } }
)
	local row = rowRoot(parent, order, 150)
	local line = row:FindFirstChild("LabelLine", true) :: Frame
	art(line, artName, color)
	rowLabel(line, label, 16)
	local strip = Instance.new("Frame")
	strip.BackgroundColor3 = Theme.Colors.ink
	strip.Position = UDim2.fromOffset(78, 74)
	strip.Size = UDim2.new(1, -92, 0, 56)
	strip.Parent = (row:FindFirstChild("Row") :: Frame):FindFirstChild("Face")
	Style.corner(strip, S.cornerSmall)
	local list = Style.list(strip, true, 4)
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	local buttons = {}
	for i, opt in options do
		local b = Style.button(strip, UDim2.new(1 / #options, -4, 1, -8))
		b.LayoutOrder = i
		local holder = Style.block(b, Style.grad("blue"), { lip = 4, radius = S.cornerSmall })
		local t = Style.label(holder, opt[1] :: string, Theme.Text.small)
		t.TextWrapped = false
		Style.press(b, function()
			Comfort.set(key, opt[2])
		end, S.cornerSmall)
		table.insert(buttons, holder)
	end
	local function paint()
		local v = Comfort.get(key)
		for i, holder in buttons do
			Style.recolor(holder, Style.grad(if options[i][2] == v then "yellow" else "blue"))
		end
	end
	paint()
	return row, paint
end

local function actionRow(
	parent: Instance,
	order: number,
	artName: string,
	color: string,
	label: string,
	onTap: () -> ()
): Frame
	local row = rowRoot(parent, order, 82)
	local line = row:FindFirstChild("LabelLine", true) :: Frame
	art(line, artName, color)
	rowLabel(line, label, 150)
	-- a chunky orange button with the row's glyph, the Toggle's size (AD 2026-11-01: the bare row read as a label)
	local button = Style.button(line, UDim2.fromOffset(124, 64))
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -14, 0.5, 0)
	local _, face = Style.block(button, Style.grad("orange"), { lip = 5, radius = S.cornerSmall })
	local glyph = Instance.new("ImageLabel")
	glyph.BackgroundTransparency = 1
	glyph.AnchorPoint = Vector2.new(0.5, 0.5)
	glyph.Position = UDim2.fromScale(0.5, 0.5)
	glyph.Size = UDim2.fromOffset(48, 48)
	glyph.Image = SettingsArt[artName] or ""
	glyph.ScaleType = Enum.ScaleType.Fit
	glyph.Parent = face
	Style.press(button, onTap, S.cornerSmall)
	return row
end

local mounted = false
local currentPanel: Panel.Panel? = nil

function SettingsPanel.newPanel(canvas: Frame, onClose: () -> ())
	local panel = Panel.new(canvas, {
		title = "Settings",
		icon = "settings",
		size = Vector2.new(780, 600),
		onClose = onClose,
	})
	currentPanel = panel
	-- the rows clear the title bar and the bottom edge and fade under both (in-game ADs 2026-11-01: hard cuts).
	-- The fades follow the list's edges: Panel's padding changes on compact (phone) screens.
	local listPad = panel.body:FindFirstChildOfClass("UIPadding") :: UIPadding
	listPad.PaddingTop, listPad.PaddingBottom = UDim.new(0, 24), UDim.new(0, 40)
	local inner = panel.body.Parent :: Frame
	local innerPad = inner:FindFirstChildOfClass("UIPadding") :: UIPadding
	local bottomFade = (inner.Parent :: Frame):FindFirstChild("Fade") :: Frame
	local topFade = bottomFade:Clone()
	topFade.Name = "FadeTop"
	topFade.AnchorPoint = Vector2.zero
	topFade.Size = UDim2.new(1, -S.border * 2 - 18, 0, 24)
	topFade.BackgroundColor3 = Theme.Grad.body.top
	local topGrad = topFade:FindFirstChildOfClass("UIGradient") :: UIGradient
	topGrad.Transparency = NumberSequence.new(0, 1)
	topFade.Parent = bottomFade.Parent
	local function placeFades()
		topFade.Position =
			UDim2.fromOffset(S.border, inner.Position.Y.Offset + innerPad.PaddingTop.Offset)
		bottomFade.Position = UDim2.new(0, S.border, 1, -innerPad.PaddingBottom.Offset)
	end
	placeFades()
	innerPad:GetPropertyChangedSignal("PaddingBottom"):Connect(placeFades)
	local order = 0
	local paints: { () -> () } = {}
	local extra: { () -> () } = {}
	local ownedPickers: { CosmeticPicker.Picker } = {}
	local ownedHeader: TextLabel? = nil

	order = section(panel.body, order, "Comfort")
	order += 1
	local function resetComfort()
		local d: { [string]: any } = {}
		for _, k in SettingsRules.COMFORT_KEYS do
			d[k] = (SettingsRules.Defaults :: any)[k]
		end
		Comfort.setMany(d)
	end
	local function seasickOn(): boolean
		return SettingsRules.isPreset(Comfort.all() :: any, SettingsRules.SEASICK)
	end
	-- the preset as a switch: on applies it, off goes back to the defaults
	local _, seasick = toggleRow(panel.body, order, {
		on = seasickOn(),
		onChange = function(on: boolean)
			if on then
				Comfort.setMany(SettingsRules.SEASICK)
			else
				resetComfort()
			end
		end,
	}, "waves", "teal", "Seasick-safe")
	order += 1
	actionRow(panel.body, order, "reset", "grey", "Reset", resetComfort)
	table.insert(extra, function()
		if seasick.get() ~= seasickOn() then
			seasick.set(seasickOn())
		end
	end)
	order += 1
	local _, p0 = sliderRow(
		panel.body,
		order,
		"fov",
		"fov",
		"purple",
		"Field of view",
		5,
		function(v)
			return `{math.round(v)}°`
		end
	)
	table.insert(paints, p0)
	order += 1
	local _, p1 = sliderRow(panel.body, order, "shake", "shake", "red", "Shake", 0.05, pct)
	table.insert(paints, p1)
	order += 1
	local _, p2 = sliderRow(
		panel.body,
		order,
		"sensitivity",
		"plus",
		"teal",
		"Sensitivity",
		0.1,
		function(v)
			return string.format("%.1fx", v)
		end
	)
	table.insert(paints, p2)
	order += 1
	toggleRow(panel.body, order, "speedFov", "speed", "orange", "Speed FOV")

	order = section(panel.body, order, "Accessibility")
	order += 1
	local _, p3 = segmentRow(panel.body, order, "colourAssist", "half", "pink", "Colour assist", {
		{ "Off", "Off" },
		{ "Deut", "Deuteranopia" },
		{ "Prot", "Protanopia" },
		{ "Trit", "Tritanopia" },
	})
	table.insert(paints, p3)
	order += 1
	local _, p4 = segmentRow(panel.body, order, "textSize", "A", "blue", "Text size", {
		{ "100%", 100 },
		{ "125%", 125 },
		{ "150%", 150 },
	})
	table.insert(paints, p4)
	order += 1
	toggleRow(panel.body, order, "reduceMotion", "pause", "green", "Reduce motion")
	order += 1
	toggleRow(panel.body, order, "holdToTap", "tap", "orange", "Hold to tap")
	order += 1
	toggleRow(panel.body, order, "haptics", "shake", "purple", "Vibration")

	order = section(panel.body, order, "Graphics")
	local q = { { "Auto", "Auto" }, { "High", "High" }, { "Med", "Medium" }, { "Low", "Low" } }
	order += 1
	local _, p9 = segmentRow(panel.body, order, "oceanQuality", "waves", "blue", "Ocean", q)
	table.insert(paints, p9)
	order += 1
	local _, p10 =
		segmentRow(panel.body, order, "scatterQuality", "peak", "green", "Rocks & plants", q)
	table.insert(paints, p10)

	order = section(panel.body, order, "Audio")
	order += 1
	local _, p5 = sliderRow(panel.body, order, "volMaster", "note", "red", "Master", 0.05, pct)
	table.insert(paints, p5)
	order += 1
	local _, p6 = sliderRow(panel.body, order, "volSfx", "sparkle", "orange", "Effects", 0.05, pct)
	table.insert(paints, p6)
	order += 1
	local _, p7 = sliderRow(panel.body, order, "volRadio", "wave", "teal", "Voices", 0.05, pct)
	table.insert(paints, p7)
	order += 1
	local _, p8 = sliderRow(panel.body, order, "volMusic", "notes", "pink", "Music", 0.05, pct)
	table.insert(paints, p8)
	order += 1
	toggleRow(panel.body, order, "voice", "bubble", "purple", "Voices on")
	order += 1
	toggleRow(panel.body, order, "muteHorns", "horn", "grey", "Mute horns")
	order += 1
	toggleRow(panel.body, order, "muteSirens", "burst", "red", "Mute sirens")
	order += 1
	toggleRow(panel.body, order, "muteRadios", "no", "grey", "Mute radios")

	order += 1
	local header = Style.label(panel.body, "OWNED ITEMS", Theme.Text.small, true)
	ownedHeader = header
	header.LayoutOrder = order
	header.TextXAlignment = Enum.TextXAlignment.Left
	local owned = Instance.new("Frame")
	owned.Name = "OwnedItems"
	owned.Size = UDim2.fromScale(1, 0)
	owned.AutomaticSize = Enum.AutomaticSize.Y
	owned.BackgroundTransparency = 1
	owned.LayoutOrder = order + 1
	owned.Parent = panel.body
	Style.list(owned, false, 8)

	local function ownsPass(key: string): boolean
		return player:GetAttribute("Pass_" .. key) == true
	end
	local function rebuildOwned()
		for _, picker in ownedPickers do
			picker.destroy()
		end
		table.clear(ownedPickers)
		for i, slot in Cosmetics.slots() do
			if
				Cosmetics.ownsSlot(slot, ownsPass)
				or #Cosmetics.ownedOptions(slot, CosmeticPicker.owns) > 1
			then
				local picker = CosmeticPicker.new(owned, slot, {
					layoutOrder = i,
					height = 76,
				})
				table.insert(ownedPickers, picker)
			end
		end
		local any = #ownedPickers > 0
		owned.Visible = any
		local h = ownedHeader
		if h then
			h.Visible = any
		end
	end
	rebuildOwned()
	player.AttributeChanged:Connect(function(attr)
		if string.sub(attr, 1, 5) == "Pass_" and panel.isOpen() then
			rebuildOwned()
		end
	end)

	local function refreshAll()
		for _, fn in paints do
			fn()
		end
		for _, fn in extra do
			fn()
		end
	end
	refreshAll()
	Comfort.changed:Connect(function(key)
		if not panel.isOpen() then
			return
		end
		refreshAll()
		if key:sub(1, 3) == "vol" or key == "voice" then
			applyAudio()
		elseif key == "colourAssist" then
			A11yPalette.setMode(Comfort.get("colourAssist") :: string)
		elseif key == "holdToTap" then
			applyHoldToTap()
		end
	end)

	return {
		open = function()
			panel.open()
			refreshAll()
		end,
		close = panel.close,
		isOpen = panel.isOpen,
		root = panel.root,
	}
end

function SettingsPanel.isOpen(): boolean
	return currentPanel ~= nil and currentPanel.isOpen()
end

function SettingsPanel.mount()
	if mounted then
		return
	end
	mounted = true
	applyAudio()
	A11yPalette.setMode(Comfort.get("colourAssist") :: string)
	applyHoldToTap()
	-- a prompt is tapped only after it shows, so this beats a whole-world DescendantAdded hook on phones
	ProximityPromptService.PromptShown:Connect(function(d: ProximityPrompt)
		if Comfort.get("holdToTap") == true then
			local base = d:GetAttribute("A11yHold")
			if type(base) ~= "number" then
				base = d.HoldDuration
				d:SetAttribute("A11yHold", base)
			end
			d.HoldDuration = 0
		end
	end)
	Comfort.changed:Connect(function(key)
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
