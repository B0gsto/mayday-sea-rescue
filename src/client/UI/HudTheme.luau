--!strict
-- HudTheme: the restrained, realistic HUD look (photoreal brief; supersedes the chunky docs 05
-- section 9 style). Translucent near-black panels with a hairline edge, thin Builder Sans type,
-- one muted safety-orange accent used sparingly, buttons still at least 48 px tall. Small factory
-- helpers so every HUD piece looks the same. Placement lives in UI/Layout.
local Layout = require(script.Parent:WaitForChild("Layout"))
local Hud = require(
	game:GetService("ReplicatedStorage")
		:WaitForChild("Shared")
		:WaitForChild("Config")
		:WaitForChild("UiImages")
).Hud

local HudTheme = {}

-- Text size setting: every label made here scales, and re-scales live when the setting changes.
local scaledLabels: { [TextLabel]: number } = {}
local scaledButtons: { [TextButton]: number } = {}

function HudTheme.scaled(size: number): number
	return math.round(size * Layout.textScale())
end

HudTheme.MinTextPx = 14 -- rendered px floor for HUD-region text (phones draw at UIScale 0.7)

-- A label inside a Layout region never renders under MinTextPx: the UIScales above it multiply.
local function labelSize(label: TextLabel, base: number): number
	local k, p = 1, label.Parent
	while p do
		local sc = p:FindFirstChildOfClass("UIScale")
		if sc then
			k *= sc.Scale
		end
		if p:GetAttribute("HudRegion") then
			return math.round(math.max(base * Layout.textScale(), HudTheme.MinTextPx / k))
		end
		p = p.Parent
	end
	return HudTheme.scaled(base)
end

local function rescale()
	for label, base in scaledLabels do
		if label.Parent == nil then
			scaledLabels[label] = nil
		elseif not label.TextScaled then
			label.TextSize = labelSize(label, base)
		end
	end
	for button, base in scaledButtons do
		if button.Parent == nil then
			scaledButtons[button] = nil
		elseif not button.TextScaled then
			button.TextSize = HudTheme.scaled(base)
		end
	end
end
Layout.onTextScale(rescale)
Layout.onMetrics(rescale)

HudTheme.Colors = {
	panel = Color3.fromHex("0C1217"), -- near-black slate
	panelLight = Color3.fromHex("26323A"), -- raised slate (secondary buttons)
	accent = Color3.fromHex("D9682E"), -- muted rescue orange
	text = Color3.fromHex("ECEDEA"), -- off-white
	textDim = Color3.fromHex("B4BEC5"), -- rain grey (>= 9:1 on the panel; was too faint on a phone)
	ready = Color3.fromHex("6FBF8E"), -- muted green ("ready" states)
	locked = Color3.fromHex("2A3239"), -- slate
	gold = Color3.fromHex("E3C88F"), -- pale brass (Cash)
	bar = Color3.fromHex("8FB7BC"), -- grey-teal (progress bars)
	edge = Color3.fromHex("FFFFFF"), -- hairline panel edge (drawn at EdgeTransparency)
}

HudTheme.PanelTransparency = 0.35
HudTheme.PromptTransparency = 0.18 -- mechanic / interaction panels: denser, they carry body text
-- Type sizes (px at UIScale 1; the Layout scale floor 0.7 keeps 18 at ~12.6 px on a phone).
HudTheme.TextSize = {
	title = 21, -- panel header
	body = 18, -- instructions, readouts
	small = 16, -- real term, hints (never below this in a panel)
}
HudTheme.EdgeTransparency = 0.85
HudTheme.HeaderFont = Enum.Font.BuilderSansMedium
HudTheme.BodyFont = Enum.Font.BuilderSans
HudTheme.BoldFont = Enum.Font.BuilderSansMedium
HudTheme.MinButtonHeight = 52 -- >= 48 px (docs 05)
HudTheme.Corner = 6

function HudTheme.corner(parent: GuiObject, radius: number?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or HudTheme.Corner)
	c.Parent = parent
	return c
end

function HudTheme.stroke(parent: GuiObject, color: Color3?, thickness: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color or HudTheme.Colors.edge
	s.Thickness = thickness or 1
	s.Transparency = if color then 0 else HudTheme.EdgeTransparency
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function HudTheme.padding(parent: GuiObject, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.Parent = parent
end

function HudTheme.panel(name: string, size: UDim2, parent: Instance?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.BackgroundColor3 = HudTheme.Colors.panel
	f.BackgroundTransparency = HudTheme.PanelTransparency
	f.BorderSizePixel = 0
	HudTheme.corner(f)
	HudTheme.stroke(f)
	f.Parent = parent
	return f
end

function HudTheme.label(
	name: string,
	text: string,
	size: UDim2,
	font: Enum.Font?,
	textSize: number?,
	parent: Instance?
): TextLabel
	local base = textSize or HudTheme.TextSize.body
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Text = text
	l.Size = size
	l.BackgroundTransparency = 1
	l.Font = font or HudTheme.BodyFont
	l.TextColor3 = HudTheme.Colors.text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = parent
	l.TextSize = labelSize(l, base)
	scaledLabels[l] = base
	return l
end

function HudTheme.button(name: string, text: string, size: UDim2, parent: Instance?): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = text
	b.Size = size
	b.AutoButtonColor = true
	b.BackgroundColor3 = HudTheme.Colors.accent
	b.BorderSizePixel = 0
	b.Font = HudTheme.HeaderFont
	b.TextSize = HudTheme.scaled(HudTheme.TextSize.body)
	b.TextColor3 = HudTheme.Colors.text
	b.TextWrapped = true
	HudTheme.corner(b, 4)
	b.Parent = parent
	scaledButtons[b] = HudTheme.TextSize.body
	return b
end

-- Sprite HUD (assets/ui/hud/mockup.png): rounded bold type, white with a soft dark edge.
HudTheme.NumberFont = Enum.Font.FredokaOne
HudTheme.LabelFont = Enum.Font.GothamBold
HudTheme.Slice = {
	Panel = Rect.new(32, 32, 480, 224), -- UiImages.Hud.Panel (512x256)
	SpeedPanel = Rect.new(24, 24, 488, 104), -- UiImages.Hud.SpeedPanel (512x128)
	Bar = Rect.new(32, 16, 480, 48), -- UiImages.Hud.BarTrack / BarFill (512x64)
}

-- A sprite: ScaleType Fit, or Slice when `slice` (9-slice rect, source px) is given.
function HudTheme.image(
	name: string,
	image: string,
	size: UDim2,
	parent: Instance?,
	slice: Rect?,
	sliceScale: number?
): ImageLabel
	local i = Instance.new("ImageLabel")
	i.Name = name
	i.Image = image
	i.Size = size
	i.BackgroundTransparency = 1
	i.BorderSizePixel = 0
	if slice then
		i.ScaleType = Enum.ScaleType.Slice
		i.SliceCenter = slice
		i.SliceScale = sliceScale or 1
	else
		i.ScaleType = Enum.ScaleType.Fit
	end
	i.Parent = parent
	return i
end

-- The sprite HUD's navy 9-slice (UiImages Hud.Panel, ~14 du corners) with an orange accent, in
-- place of a slate panel's fill, corner and edge (toasts, prompts, the step card).
function HudTheme.skin(f: GuiObject)
	f.BackgroundTransparency = 1
	for _, c in f:GetChildren() do
		if c:IsA("UICorner") or c:IsA("UIStroke") then
			c:Destroy()
		end
	end
	local bg =
		HudTheme.image("Skin", Hud.Panel, UDim2.fromScale(1, 1), f, HudTheme.Slice.Panel, 0.45)
	bg.ZIndex = 0
	local pad = f:FindFirstChildOfClass("UIPadding")
	if pad then -- cover the padding too
		local l, r = pad.PaddingLeft.Offset, pad.PaddingRight.Offset
		local t, b = pad.PaddingTop.Offset, pad.PaddingBottom.Offset
		bg.Position = UDim2.fromOffset(-l, -t)
		bg.Size = UDim2.new(1, l + r, 1, t + b)
	end
	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.AnchorPoint = Vector2.new(0.5, 0)
	accent.Position = UDim2.new(0.5, 0, 0, bg.Position.Y.Offset)
	accent.Size = UDim2.new(0.4, 0, 0, 4)
	accent.BackgroundColor3 = HudTheme.Colors.accent
	accent.BorderSizePixel = 0
	accent.Parent = f
	HudTheme.corner(accent, 2)
end

-- White HUD text with a subtle dark edge (reads on sky, sea and sand).
function HudTheme.outline(label: TextLabel): TextLabel
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = Color3.fromHex("06101C")
	label.TextStrokeTransparency = 0.55
	return label
end

-- An iOS segmented control in the HUD colours: a dark track, an orange thumb that slides to the picked segment. Each segment
-- is a TextButton (touch, mouse, gamepad A). set(i) moves the thumb (no callback); the caller wires
-- onPick, which runs on a tap.
function HudTheme.segmented(
	parent: Instance,
	labels: { string },
	height: number,
	onPick: (index: number) -> ()
): (Frame, { TextButton }, (index: number) -> ())
	local C = HudTheme.Colors
	local track = Instance.new("Frame")
	track.Name = "Segments"
	track.Size = UDim2.new(1, 0, 0, height)
	track.BackgroundColor3 = C.panel
	track.BackgroundTransparency = 0.2
	track.BorderSizePixel = 0
	HudTheme.corner(track, 9)
	HudTheme.padding(track, 2)
	track.Parent = parent
	local n = #labels
	local thumb = Instance.new("Frame")
	thumb.Name = "Thumb"
	thumb.Size = UDim2.fromScale(1 / n, 1)
	thumb.BackgroundColor3 = C.accent
	thumb.BorderSizePixel = 0
	HudTheme.corner(thumb, 7)
	thumb.Parent = track
	local buttons: { TextButton } = {}
	for i, text in labels do
		local b = Instance.new("TextButton")
		b.Name = text
		b.Text = text
		b.Font = Enum.Font.BuilderSansBold
		b.TextSize = 17 -- fixed: three ~90 du segments fit "Jet Skis" / "Day Pass" at 17
		b.TextColor3 = C.text
		b.AutoButtonColor = false
		b.BackgroundTransparency = 1
		b.Position = UDim2.fromScale((i - 1) / n, 0)
		b.Size = UDim2.fromScale(1 / n, 1)
		b.ZIndex = 2
		b.Parent = track
		HudTheme.corner(b, 7)
		b.Activated:Connect(function()
			onPick(i)
		end)
		buttons[i] = b
	end
	local first = true
	local function set(index: number)
		local at = UDim2.fromScale((index - 1) / n, 0)
		if first then
			thumb.Position, first = at, false
		else
			game:GetService("TweenService")
				:Create(thumb, TweenInfo.new(0.22, Enum.EasingStyle.Quint), { Position = at })
				:Play()
		end
		for i, b in buttons do
			b.TextColor3 = if i == index then C.text else C.textDim
		end
	end
	return track, buttons, set
end

-- 12345 -> "12,345"
function HudTheme.formatNumber(n: number): string
	local s = tostring(math.floor(n))
	local sign, digits = s:match("^(-?)(%d+)$")
	if not digits then
		return s
	end
	local out = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return (sign or "") .. out
end

return HudTheme
