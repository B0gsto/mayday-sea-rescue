--!strict
-- Kit Style: the instance helpers every Kit component builds from (Theme holds the numbers).
--   canvas(parent, viewport?)  a du frame with the viewport UIScale (fixed viewport = style guide)
--   block(parent, grad, opts)  the chunky piece: dark lip under a gradient face, thick ink border
--   label(parent, text, size)  display font, white, black outline
--   icon(parent, name)         UiImages.Kit art, else a neutral placeholder tile with the letter
--   press(button, onActivate)  hover grow, press squash + bounce, gamepad ring, sounds-free
--   pop(root, on)              pop-in / pop-out
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local A11yPalette = require(Shared:WaitForChild("A11yPalette"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local UiImages = require(Shared:WaitForChild("Config"):WaitForChild("UiImages")) :: any

local S = Theme.Size
local C = Theme.Colors

local Style = {}

local fontFace = Font.new(Theme.FONT, Enum.FontWeight.Regular)

-- shortcut: the palette is read when a piece is built; open screens keep their colours until rebuilt.
function Style.grad(name: string): Theme.Grad
	return Theme.palette(A11yPalette.mode())[name] or Theme.Grad.blue
end

function Style.corner(parent: Instance, r: number?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or S.corner)
	c.Parent = parent
	return c
end

function Style.stroke(parent: Instance, thickness: number, border: boolean?): UIStroke
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = C.ink
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.ApplyStrokeMode = if border
		then Enum.ApplyStrokeMode.Border
		else Enum.ApplyStrokeMode.Contextual
	s.Parent = parent
	return s
end

function Style.gradient(parent: Instance, grad: Theme.Grad): UIGradient
	local u = parent:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
	u.Color = ColorSequence.new(grad.top, grad.bottom)
	u.Rotation = 90
	u.Parent = parent
	return u
end

function Style.label(parent: Instance, text: string, size: number, dark: boolean?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = fontFace
	l.Text = text
	l.TextSize = size
	l.TextColor3 = if dark then C.textDark else C.text
	l.TextWrapped = true
	l.Size = UDim2.fromScale(1, 1)
	if not dark then
		Style.stroke(l, if size >= Theme.Text.body then S.textStroke else S.textStrokeSmall)
	end
	l.Parent = parent
	return l
end

function Style.studs(face: GuiObject, radius: number)
	local img = (UiImages.Kit or {}).Studs
	if not Theme.STUDS or not img or img == "" or img == "rbxassetid://0" then
		return
	end
	local t = Instance.new("ImageLabel")
	t.Name = "Studs"
	t.BackgroundTransparency = 1
	t.Image = img
	t.ImageTransparency = Theme.STUD_TRANSPARENCY
	t.ScaleType = Enum.ScaleType.Tile
	t.TileSize = UDim2.fromOffset(S.studTile, S.studTile)
	t.Size = UDim2.fromScale(1, 1)
	t.ZIndex = face.ZIndex
	Style.corner(t, radius)
	t.Parent = face
end

export type BlockOpts = {
	radius: number?,
	lip: number?,
	border: number?,
	shadow: boolean?,
	studs: boolean?,
}

-- A chunky piece filling `parent`: Lip (darker, full size) under Face (gradient, lip shorter).
-- Returns the holder and the face; children go on the face. recolor(grad) repaints both.
function Style.block(parent: Instance, grad: Theme.Grad, opts: BlockOpts?): (Frame, Frame)
	local o: BlockOpts = opts or {}
	local radius = o.radius or S.corner
	local lip = o.lip or S.lip
	local holder = Instance.new("Frame")
	holder.Name = "Block"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	if o.shadow then
		local sh = Instance.new("Frame")
		sh.Name = "Shadow"
		sh.BackgroundColor3 = C.shadow
		sh.BackgroundTransparency = 0.6
		sh.Position = UDim2.fromOffset(0, S.shadow)
		sh.Size = UDim2.fromScale(1, 1)
		Style.corner(sh, radius + 2)
		sh.Parent = holder
	end
	local under = Instance.new("Frame")
	under.Name = "Lip"
	under.BackgroundColor3 = Theme.shade(grad.bottom)
	under.Size = UDim2.fromScale(1, 1)
	Style.corner(under, radius)
	Style.stroke(under, o.border or S.border, true)
	under.Parent = holder
	local face = Instance.new("Frame")
	face.Name = "Face"
	face.BackgroundColor3 = Color3.new(1, 1, 1)
	face.Size = UDim2.new(1, 0, 1, -lip)
	Style.corner(face, radius)
	Style.stroke(face, o.border or S.border, true)
	Style.gradient(face, grad)
	if o.studs then
		Style.studs(face, radius)
	end
	face.Parent = holder
	holder.Parent = parent
	return holder, face
end

function Style.recolor(holder: Frame, grad: Theme.Grad)
	local lip = holder:FindFirstChild("Lip") :: Frame?
	local face = holder:FindFirstChild("Face") :: Frame?
	if lip then
		lip.BackgroundColor3 = Theme.shade(grad.bottom)
	end
	if face then
		Style.gradient(face, grad)
	end
end

-- Uploaded Kit art id for an icon name ("shop", "cash", ...), or nil while it is 0 / missing.
function Style.iconId(name: string): string?
	local id = (UiImages.Kit or {})[name]
	return if type(id) == "string" and id ~= "" and id ~= "rbxassetid://0" then id else nil
end

-- A square icon filling `parent` (keep it square with the parent's size). Placeholder: a white
-- tile with the name's first letter, so the kit renders before the art lands.
local function placeholder(parent: Instance, name: string): Frame
	local box = Instance.new("Frame")
	box.Name = "Icon"
	box.BackgroundColor3 = Color3.new(1, 1, 1)
	box.BackgroundTransparency = 0.55
	box.Size = UDim2.fromScale(0.8, 0.8)
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	Style.corner(box, S.cornerSmall)
	local l = Style.label(box, string.upper(string.sub(name, 1, 1)), 30)
	l.TextScaled = true
	box.Parent = parent
	return box
end

function Style.icon(parent: Instance, name: string): GuiObject
	local id = Style.iconId(name)
	if not id then
		return placeholder(parent, name)
	end
	local img = Instance.new("ImageLabel")
	img.Name = "Icon"
	img.BackgroundTransparency = 1
	img.Image = id
	img.ScaleType = Enum.ScaleType.Fit
	img.Size = UDim2.fromScale(1, 1)
	img.Parent = parent
	-- img1: art still downloading shows the letter tile until it lands, never an empty tile
	if ContentProvider:GetAssetFetchStatus(id) ~= Enum.AssetFetchStatus.Success then
		local box = placeholder(parent, name)
		local conn = ContentProvider:GetAssetFetchStatusChangedSignal(id):Connect(function(status)
			if status == Enum.AssetFetchStatus.Success then
				box:Destroy()
			end
		end)
		box.Destroying:Once(function()
			conn:Disconnect()
		end)
	end
	return img
end

-- Gamepad selection ring: a thick yellow rounded outline drawn over the selected button.
local function ring(radius: number): Frame
	local r = Instance.new("Frame")
	r.Name = "Ring"
	r.BackgroundTransparency = 1
	r.Size = UDim2.new(1, 12, 1, 12)
	r.Position = UDim2.fromOffset(-6, -6)
	Style.corner(r, radius + 6)
	local s = Style.stroke(r, 5, true)
	s.Color = C.ring
	return r
end

local function tween(inst: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?)
	TweenService
		:Create(
			inst,
			TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			props
		)
		:Play()
end

-- Hover / selection grows 6%, press squashes to 90% and bounces back; onActivate on release.
-- Works for mouse, touch (Activated) and gamepad (selection + ButtonA). `still`: no hover growth (list cards,
-- which a clipping scroll column would cut).
function Style.press(button: GuiButton, onActivate: (() -> ())?, radius: number?, still: boolean?)
	button.AutoButtonColor = false
	button.Selectable = true
	button.SelectionImageObject = ring(radius or S.corner)
	local sc = Instance.new("UIScale")
	sc.Parent = button
	local over = false
	local function rest()
		tween(sc, 0.25, { Scale = if over and not still then 1.06 else 1 }, Enum.EasingStyle.Back)
	end
	button.MouseEnter:Connect(function()
		over = true
		rest()
	end)
	button.MouseLeave:Connect(function()
		over = false
		rest()
	end)
	button.SelectionGained:Connect(function()
		over = true
		rest()
	end)
	button.SelectionLost:Connect(function()
		over = false
		rest()
	end)
	button.MouseButton1Down:Connect(function()
		tween(sc, 0.08, { Scale = 0.9 })
	end)
	button.MouseButton1Up:Connect(rest)
	button.Activated:Connect(function()
		rest()
		if button.Active and onActivate then
			onActivate()
		end
	end)
end

-- Plain transparent button root (an ImageButton with no image: Activated + selection).
function Style.button(parent: Instance?, size: UDim2): ImageButton
	local b = Instance.new("ImageButton")
	b.BackgroundTransparency = 1
	b.Image = ""
	b.Size = size
	b.Parent = parent
	return b
end

-- Pop a root in (0.6 -> 1, Back) or out (-> 0.6, then hidden).
function Style.pop(root: GuiObject, on: boolean)
	local sc = root:FindFirstChild("PopScale") :: UIScale?
	if not sc then
		local u = Instance.new("UIScale")
		u.Name = "PopScale"
		u.Parent = root
		sc = u
	end
	local scale = sc :: UIScale
	if on then
		root.Visible = true
		scale.Scale = 0.6
		tween(scale, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
	else
		local tw =
			TweenService:Create( -- Back In: a small swell first (anticipation), then it tucks away
				sc,
				TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In),
				{
					Scale = 0.6,
				}
			)
		tw.Completed:Once(function(state)
			if state == Enum.PlaybackState.Completed then
				root.Visible = false
			end
		end)
		tw:Play()
	end
end

Style.tween = tween

-- A full-size du frame under `parent` with the viewport UIScale. Without `viewport` it tracks
-- the parent's AbsoluteSize (a ScreenGui); with one it is fixed (the style guide's fake devices).
-- Attributes KitViewport / KitScale let children (Panel) fit themselves.
function Style.canvas(parent: GuiBase2d, viewport: Vector2?): Frame
	local f = Instance.new("Frame")
	f.Name = "KitCanvas"
	f.BackgroundTransparency = 1
	local sc = Instance.new("UIScale")
	sc.Parent = f
	local function fit()
		local vp = viewport or parent.AbsoluteSize
		local s = Theme.scaleFor(vp)
		sc.Scale = s
		f.Size = UDim2.fromOffset(vp.X / s, vp.Y / s)
		f:SetAttribute("KitScale", s)
		f:SetAttribute("KitViewport", vp)
	end
	fit()
	if not viewport then
		parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	end
	f.Parent = parent
	return f
end

-- The nearest canvas metrics above `inst` (viewport px, scale).
function Style.metrics(inst: Instance): (Vector2, number, Instance?)
	local p: Instance? = inst
	while p do
		local vp = p:GetAttribute("KitViewport")
		if typeof(vp) == "Vector2" then
			return vp, (p:GetAttribute("KitScale") :: number?) or 1, p
		end
		p = p.Parent
	end
	return Vector2.new(1280, 720), 1, nil
end

-- A vertical / horizontal list layout.
function Style.list(parent: Instance, horizontal: boolean?, padding: number?): UIListLayout
	local l = Instance.new("UIListLayout")
	l.FillDirection = if horizontal
		then Enum.FillDirection.Horizontal
		else Enum.FillDirection.Vertical
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, padding or S.pad)
	l.Parent = parent
	return l
end

function Style.pad(parent: Instance, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.Parent = parent
end

return Style
