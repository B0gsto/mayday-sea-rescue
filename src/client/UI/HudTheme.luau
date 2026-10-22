--!strict
-- HudTheme: the restrained, realistic HUD look (photoreal brief; supersedes the chunky docs 05
-- section 9 style). Translucent near-black panels with a hairline edge, thin Builder Sans type,
-- one muted safety-orange accent used sparingly, buttons still at least 48 px tall. Small factory
-- helpers so every HUD piece looks the same. Placement lives in UI/Layout.
local Layout = require(script.Parent:WaitForChild("Layout"))

local HudTheme = {}

-- Text size setting: every label made here scales, and re-scales live when the setting changes.
local scaledLabels: { [TextLabel]: number } = {}
local scaledButtons: { [TextButton]: number } = {}

function HudTheme.scaled(size: number): number
	return math.round(size * Layout.textScale())
end

Layout.onTextScale(function()
	for label, base in scaledLabels do
		if label.Parent == nil then
			scaledLabels[label] = nil
		elseif not label.TextScaled then
			label.TextSize = HudTheme.scaled(base)
		end
	end
	for button, base in scaledButtons do
		if button.Parent == nil then
			scaledButtons[button] = nil
		elseif not button.TextScaled then
			button.TextSize = HudTheme.scaled(base)
		end
	end
end)

HudTheme.Colors = {
	panel = Color3.fromHex("0C1217"), -- near-black slate
	panelLight = Color3.fromHex("26323A"), -- raised slate (secondary buttons)
	accent = Color3.fromHex("D9682E"), -- muted rescue orange
	text = Color3.fromHex("ECEDEA"), -- off-white
	textDim = Color3.fromHex("B4BEC5"), -- rain grey (>= 9:1 on the panel; was too faint on a phone)
	ready = Color3.fromHex("6FBF8E"), -- muted green ("ready" states)
	locked = Color3.fromHex("2A3239"), -- slate
	gold = Color3.fromHex("E3C88F"), -- pale brass (Cash)
	bar = Color3.fromHex("8FB7BC"), -- grey-teal (Rep)
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
	l.TextSize = HudTheme.scaled(base)
	l.TextColor3 = HudTheme.Colors.text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = parent
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

-- White HUD text with a subtle dark edge (reads on sky, sea and sand).
function HudTheme.outline(label: TextLabel): TextLabel
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = Color3.fromHex("06101C")
	label.TextStrokeTransparency = 0.55
	return label
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
