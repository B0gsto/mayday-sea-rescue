--!strict
-- HudTheme: docs 05 section 9 UI style. Chunky rounded Abyss Navy panels (~90% opacity), a
-- Rescue Orange accent edge, Hull White text, Fredoka One headers, Builder Sans body, buttons at
-- least 48 px tall. Small factory helpers so every HUD piece looks the same.
local HudTheme = {}

HudTheme.Colors = {
	panel = Color3.fromHex("0A2A3B"), -- Abyss Navy
	panelLight = Color3.fromHex("0E5E6F"), -- Deep Teal
	accent = Color3.fromHex("FF6B1A"), -- Rescue Orange
	text = Color3.fromHex("F4F1EA"), -- Hull White
	textDim = Color3.fromHex("9AA8B3"), -- Rain Grey
	ready = Color3.fromHex("3EE07A"), -- Waypoint Green ("ready" states)
	locked = Color3.fromHex("2F3A45"), -- Storm Slate
	gold = Color3.fromHex("FFC872"), -- Golden Hour (Cash)
	bar = Color3.fromHex("3FC1C0"), -- Shallow Aqua (Rep)
}

HudTheme.PanelTransparency = 0.1
HudTheme.HeaderFont = Enum.Font.FredokaOne
HudTheme.BodyFont = Enum.Font.BuilderSans
HudTheme.BoldFont = Enum.Font.BuilderSansBold
HudTheme.MinButtonHeight = 52 -- >= 48 px (docs 05)
HudTheme.Corner = 14

function HudTheme.corner(parent: GuiObject, radius: number?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or HudTheme.Corner)
	c.Parent = parent
	return c
end

function HudTheme.stroke(parent: GuiObject, color: Color3?, thickness: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color or HudTheme.Colors.accent
	s.Thickness = thickness or 2
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
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Text = text
	l.Size = size
	l.BackgroundTransparency = 1
	l.Font = font or HudTheme.BodyFont
	l.TextSize = textSize or 18
	l.TextColor3 = HudTheme.Colors.text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = parent
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
	b.TextSize = 20
	b.TextColor3 = HudTheme.Colors.text
	b.TextWrapped = true
	HudTheme.corner(b, 12)
	b.Parent = parent
	return b
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
