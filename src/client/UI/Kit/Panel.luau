--!strict
-- Panel: the centred window. Cyan title bar (icon + name, studs), red square X, light body with
-- an optional Tabs row and a scrolling list. Fits itself to the canvas (Theme.panelSize).
--   local p = Panel.new(canvas, { title = "Shop", icon = "shop", onClose = fn })
--   Card.new(p.body, {...})   p.open() / p.close()  p.closeButton: the X   p.top: a slot above the list (Tabs)
local GuiService = game:GetService("GuiService")

local Style = require(script.Parent:WaitForChild("Style"))
local Theme = require(script.Parent:WaitForChild("Theme"))

local S = Theme.Size

export type Props = {
	title: string,
	icon: string?,
	color: string?, -- title bar accent (default "title")
	size: Vector2?, -- design size in du (default Theme.Size.panel)
	tabs: boolean?, -- reserve a Tabs row (p.top)
	wide: boolean?, -- keep the design width on desktop (default: about half the screen)
	onClose: (() -> ())?,
}
export type Panel = {
	root: Frame,
	top: Frame,
	body: ScrollingFrame,
	closeButton: ImageButton,
	open: () -> (),
	close: () -> (),
	isOpen: () -> boolean,
}

local Panel = {}

function Panel.new(canvas: Instance, props: Props): Panel
	local want = props.size or S.panel
	-- dims the screen behind the open panel (the panel is modal)
	local dim = Instance.new("Frame")
	dim.Name = "PanelDim_" .. props.title
	dim.BackgroundColor3 = Theme.Colors.shadow
	dim.BackgroundTransparency = 0.45
	dim.Size = UDim2.fromScale(1, 1)
	dim.ZIndex = 4
	dim.Visible = false
	dim.Parent = canvas

	local root = Instance.new("Frame")
	root.Name = "Panel_" .. props.title
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Visible = false
	root.ZIndex = 5

	-- body (below the bar's lower half)
	local bodyBox = Instance.new("Frame")
	bodyBox.Name = "Body"
	bodyBox.BackgroundTransparency = 1
	bodyBox.Position = UDim2.fromOffset(0, S.titleBar * 0.5)
	bodyBox.Size = UDim2.new(1, 0, 1, -S.titleBar * 0.5)
	bodyBox.Parent = root
	local _, bodyFace =
		Style.block(bodyBox, Theme.Grad.body, { shadow = true, lip = 8, radius = S.corner + 4 })

	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.BackgroundTransparency = 1
	inner.Position = UDim2.fromOffset(0, S.titleBar * 0.5 + 6)
	inner.Size = UDim2.new(1, 0, 1, -(S.titleBar * 0.5 + 6))
	inner.Parent = bodyFace
	Style.pad(inner, S.pad)
	Style.list(inner, false, 10)

	-- the list fades out at the bottom edge: a scroll cue when a card is cut
	local fade = Instance.new("Frame")
	fade.Name = "Fade"
	fade.BackgroundColor3 = Theme.Grad.body.bottom
	fade.BorderSizePixel = 0
	fade.AnchorPoint = Vector2.new(0, 1)
	fade.Position = UDim2.new(0, S.border, 1, -S.pad + 4)
	fade.Size = UDim2.new(1, -S.border * 2 - 18, 0, 40)
	fade.ZIndex = 2
	local fg = Instance.new("UIGradient")
	fg.Rotation = 90
	fg.Transparency = NumberSequence.new(1, 0)
	fg.Parent = fade
	fade.Parent = bodyFace

	local top = Instance.new("Frame")
	top.Name = "Top"
	top.BackgroundTransparency = 1
	top.Size = UDim2.new(1, 0, 0, S.tab)
	top.Visible = props.tabs == true
	top.Parent = inner

	local body = Instance.new("ScrollingFrame")
	body.Name = "List"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Size = UDim2.new(1, 0, 1, if props.tabs then -(S.tab + 10) else 0)
	body.LayoutOrder = 1
	body.CanvasSize = UDim2.new()
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.ScrollingDirection = Enum.ScrollingDirection.Y
	body.ScrollBarThickness = 14
	body.ScrollBarImageColor3 = Theme.Colors.ink
	body.ScrollBarImageTransparency = 0
	body.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	body.Selectable = false
	body.Parent = inner
	local list = Style.list(body, false, 12)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local lp = Instance.new("UIPadding") -- room for the cards' borders and lips
	lp.PaddingTop = UDim.new(0, 4)
	lp.PaddingBottom = UDim.new(0, 8)
	lp.PaddingLeft = UDim.new(0, 4)
	lp.PaddingRight = UDim.new(0, 4)
	lp.Parent = body

	-- title bar
	local bar = Instance.new("Frame")
	bar.Name = "TitleBar"
	bar.BackgroundTransparency = 1
	bar.Size = UDim2.new(1, -S.close * 0.5, 0, S.titleBar)
	bar.ZIndex = 2
	bar.Parent = root
	local _, barFace = Style.block(
		bar,
		Style.grad(props.color or "title"),
		{ studs = true, radius = S.corner + 4 }
	)
	local hasIcon = props.icon ~= nil
	local iconSide = S.titleBar + 22
	if props.icon then
		local ic = Instance.new("Frame")
		ic.Name = "Icon"
		ic.BackgroundTransparency = 1
		ic.AnchorPoint = Vector2.new(0, 0.5)
		ic.Position = UDim2.new(0, -iconSide * 0.12, 0.5, -4)
		ic.Size = UDim2.fromOffset(iconSide, iconSide)
		ic.ZIndex = 3
		ic.Parent = bar
		Style.icon(ic, props.icon)
	end
	local title = Style.label(barFace, props.title, Theme.Text.title)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextWrapped = false
	title.Position = UDim2.fromOffset(if hasIcon then iconSide * 0.75 + 6 else S.pad + 6, 0)
	title.Size = UDim2.new(1, -(if hasIcon then iconSide * 0.75 + 6 else S.pad + 6) - S.close, 1, 0)

	-- red X, over the bar's right end
	local x = Style.button(root, UDim2.fromOffset(S.close, S.close + S.lip))
	x.Name = "Close"
	x.AnchorPoint = Vector2.new(1, 0)
	x.Position = UDim2.new(1, 0, 0, (S.titleBar - S.close - S.lip) * 0.5 - 2)
	x.ZIndex = 4
	local _, xFace = Style.block(x, Style.grad("close"), { radius = S.cornerSmall })
	local xl = Style.label(xFace, "X", Theme.Text.title)
	xl.TextScaled = false

	-- du around the list: the bar's lower half, inner offset + padding, list padding, lip, tabs row
	local chrome = S.titleBar * 0.5
		+ 6
		+ S.pad * 2
		+ 12
		+ 8
		+ (if props.tabs then S.tab + 10 else 0)
	local function fit()
		local vp, scale = Style.metrics(root)
		local sz = Theme.panelSize(vp, scale, want, props.wide)
		local h = sz.Y
		-- portrait: shrink to the content (no dead space under a short list)
		local ratio = if root.Size.Y.Offset > 0 then root.AbsoluteSize.Y / root.Size.Y.Offset else 0
		if vp.Y > vp.X and not props.wide and ratio > 0 then
			local content = math.ceil(list.AbsoluteContentSize.Y / ratio + chrome)
			h = math.clamp(content, math.min(260, h), h)
		end
		root.Size = UDim2.fromOffset(sz.X, h)
	end
	list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)

	local function close()
		dim.Visible = false
		Style.pop(root, false)
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(root) then
			GuiService.SelectedObject = nil
		end
		if props.onClose then
			props.onClose()
		end
	end
	Style.press(x, close, S.cornerSmall)

	root.Parent = canvas
	fit()
	canvas:GetAttributeChangedSignal("KitScale"):Connect(fit)

	return {
		root = root,
		top = top,
		body = body,
		closeButton = x,
		open = function()
			fit()
			dim.Visible = true
			Style.pop(root, true)
		end,
		close = close,
		isOpen = function()
			return root.Visible
		end,
	}
end

return Panel
