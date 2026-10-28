--!strict
-- Panel: the centred window. Cyan title bar (icon + name, studs), red square X, light body with
-- an optional Tabs row and a scrolling list. Fits itself to the canvas (Theme.panelSize).
--   local p = Panel.new(canvas, { title = "Shop", icon = "shop", onClose = fn })
--   Card.new(p.body, {...})   p.open() / p.close()  p.closeButton: the X   p.top: a slot above the list (Tabs)
local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local AudioController =
	require(script.Parent.Parent.Parent:WaitForChild("Controllers"):WaitForChild("AudioController"))
local Comfort = require(script.Parent.Parent.Parent:WaitForChild("Camera"):WaitForChild("Comfort"))
local Style = require(script.Parent:WaitForChild("Style"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local UiImages = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UiImages")
)

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

-- every uploaded UI image loads at start: a panel's first open drew its icons blank for ~0.4 s (FX2b)
task.spawn(function()
	local ids = {}
	local function walk(t: { [string]: any })
		for _, v in t do
			if type(v) == "string" and string.find(v, "^rbxassetid://") then
				table.insert(ids, v)
			elseif type(v) == "table" then
				walk(v)
			end
		end
	end
	walk(UiImages)
	pcall(ContentProvider.PreloadAsync, ContentProvider, ids)
end)

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
	local titleX = if hasIcon then iconSide * 0.75 + 6 else S.pad + 6
	local title = Style.label(barFace, props.title, Theme.Text.title)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextWrapped = false
	title.Position = UDim2.fromOffset(titleX, 0)
	title.Size = UDim2.new(1, -titleX - S.close, 1, 0)

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
	local padding = inner:FindFirstChildOfClass("UIPadding") :: UIPadding
	top.ZIndex = 3
	local function fit()
		local vp, scale = Style.metrics(root)
		local sz = Theme.panelSize(vp, scale, want, props.wide)
		-- short landscape (phones): the tabs move into the title bar in place of the name (the icon stays),
		-- tighter padding, so the list gets the height (verify 2026-10-26: the Shop showed 1.3 cards)
		local compact = Theme.compact(vp, scale)
		local px = UDim.new(0, if compact then 8 else S.pad)
		padding.PaddingTop, padding.PaddingBottom, padding.PaddingLeft, padding.PaddingRight =
			px, px, px, px
		if props.tabs then
			top.Parent = if compact then bar else inner
			top.AnchorPoint = Vector2.new(0, if compact then 0.5 else 0)
			top.Position = if compact then UDim2.new(0, titleX, 0.5, -2) else UDim2.new()
			top.Size = UDim2.new(1, if compact then -titleX - S.close * 0.5 - 8 else 0, 0, S.tab)
			title.Visible = not compact
			body.Size = UDim2.new(1, 0, 1, if compact then 0 else -(S.tab + 10))
		end
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

	-- FX2b: the dim fades rather than blinks; the window rises into place as it pops and sinks as it tucks away
	local DIM = dim.BackgroundTransparency
	local dimFade = TweenInfo.new(0.18, Enum.EasingStyle.Quad)
	local function close()
		if root.Visible then
			AudioController.play("FX_Swoosh", nil, 1, 1.1)
		end
		local out = TweenService:Create(dim, dimFade, { BackgroundTransparency = 1 })
		out.Completed:Once(function(state)
			if state == Enum.PlaybackState.Completed then
				dim.Visible = false
			end
		end)
		out:Play()
		if not Comfort.reducedMotion() then
			Style.tween(
				root,
				0.18,
				{ Position = UDim2.new(0.5, 0, 0.5, 28) },
				Enum.EasingStyle.Quad
			)
		end
		Style.pop(root, false)
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(root) then
			GuiService.SelectedObject = nil
		end
		if props.onClose then
			props.onClose()
		end
	end
	Style.press(x, close, S.cornerSmall)

	local function cascade()
		local cards = {}
		for _, c in body:GetChildren() do
			if c:IsA("GuiObject") and c.Visible then
				table.insert(cards, c)
			end
		end
		table.sort(cards, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		for i = 1, math.min(#cards, 8) do
			-- one UIScale per object counts: a pressable card's own press scale does the pop
			local sc = cards[i]:FindFirstChildOfClass("UIScale")
			if not sc then
				local u = Instance.new("UIScale")
				u.Name = "EnterScale"
				u.Parent = cards[i]
				sc = u
			end
			local enter = sc :: UIScale
			enter.Scale = 0.6
			TweenService:Create(
				enter,
				TweenInfo.new(
					0.3,
					Enum.EasingStyle.Back,
					Enum.EasingDirection.Out,
					0,
					false,
					0.05 * i
				),
				{ Scale = 1 }
			):Play()
		end
	end

	root.Parent = canvas
	fit()
	canvas:GetAttributeChangedSignal("KitScale"):Connect(fit)
	canvas:GetAttributeChangedSignal("KitViewport"):Connect(fit)

	return {
		root = root,
		top = top,
		body = body,
		closeButton = x,
		open = function()
			fit()
			dim.Visible = true
			dim.BackgroundTransparency = 1
			TweenService:Create(dim, dimFade, { BackgroundTransparency = DIM }):Play()
			Style.pop(root, true)
			AudioController.play("FX_Pop", nil, 0.6, 1.1)
			if Comfort.reducedMotion() then
				root.Position = UDim2.fromScale(0.5, 0.5)
				return
			end
			root.Position = UDim2.new(0.5, 0, 0.5, 36)
			Style.tween(root, 0.32, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Back)
			-- the first cards cascade in one after another (a card's own pop scale, not its layout slot), a
			-- frame later: panels (Shop) rebuild their cards right after open()
			task.defer(cascade)
		end,
		close = close,
		isOpen = function()
			return root.Visible
		end,
	}
end

return Panel
