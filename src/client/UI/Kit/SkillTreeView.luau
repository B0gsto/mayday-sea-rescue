--!strict
-- SkillTreeView (docs/25 F, J): the full-screen radial skill tree. Four coloured sectors radiate
-- from a compass at the centre ("You"), keystones are octagon badges and the minor nodes are the
-- dots on the winding paths. Drag / wheel / pinch pan and zoom, the D-pad / arrows / left stick
-- jump to the nearest node. The panel passes only the nodes you own or can unlock next, and the view
-- frames them (owner 2026-10-28). Tapping a node (A / Return) shrinks the tree into a bottom-left
-- minimap and slides in its card; the minimap, the card's X, B / Escape or empty space bring the tree
-- back. Medals are the only currency.
--   local v = SkillTreeView.new(parent, { nodes = {...}, medals = 12, onBuy = fn, ... })
--   v.setNodes(nodes, medals)   v.openAt(newestId)   v.close()
-- Node: { id, name, icon, effect, price, ring, angle, sector, keystone, state, focus }
local AssetService = game:GetService("AssetService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Counter = require(script.Parent:WaitForChild("Counter"))
local Glyph = require(script.Parent.Parent:WaitForChild("Glyph"))
local PriceButton = require(script.Parent:WaitForChild("PriceButton"))
local Style = require(script.Parent:WaitForChild("Style"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local TreeMath = require(script.Parent:WaitForChild("TreeMath"))
local UiImages = require(
	game:GetService("ReplicatedStorage")
		:WaitForChild("Shared")
		:WaitForChild("Config")
		:WaitForChild("UiImages")
)

local S = Theme.Size

local BG = Color3.fromHex("0D1B2A")
local BG_TOP = Color3.fromHex("11263B")
local CARD = Color3.fromHex("13263A")
local RING = Color3.fromHex("1B2D42")
local OUTER = Color3.fromHex("2C425A")
local DIVIDER = Color3.fromHex("122033")
local ICON_OWNED = Color3.fromHex("132232")
local GOLD = Color3.fromHex("FFC928")

export type State = "owned" | "buyable" | "soon" -- soon: an update's teaser, greyed, never buyable
export type Node = {
	id: string,
	name: string,
	icon: string,
	effect: string,
	price: number,
	ring: number,
	angle: number,
	sector: string,
	keystone: boolean,
	state: State,
	focus: string?,
	needs: { string },
}
export type Done = (boolean) -> ()
export type Props = {
	nodes: { Node },
	medals: number,
	onBuy: ((string, Done) -> ())?,
	onSelect: ((Node) -> ())?, -- a node's card opened: the panel may move the camera
	onEndFocus: (() -> ())?, -- the full tree is back: end the camera focus
	onClose: (() -> ())?,
	onReset: (() -> ())?, -- the free reset (docs/25 F): every Medal back
}
export type View = {
	root: Frame,
	setNodes: (nodes: { Node }, medals: number) -> (),
	openAt: (id: string?) -> (),
	close: () -> (),
	isOpen: () -> boolean,
}

local SECTOR: { [string]: { name: string, color: Color3 } } = {
	Captain = { name = "CAPTAIN", color = Color3.fromHex("FF8A65") },
	Rescue = { name = "RESCUE", color = Color3.fromHex("4DD0E1") },
	Crew = { name = "CREW & LUCK", color = Color3.fromHex("B388FF") },
	Industry = { name = "INDUSTRY", color = Color3.fromHex("FFD54F") },
	Bridge = { name = "BRIDGE", color = Color3.fromHex("CFD8DC") },
}

local BADGE = 50
local DOT = 16
local HIT = 90
local DOT_HIT = 44
local MINI = 0.3 -- the minimap's share of the screen
local FIT_PAD = 110 -- du round the visible nodes (keystone labels hang 70 below the badge)
local FIT_MIN_ZOOM = 0.9 -- the opening fit never zooms out further: nodes stay big and legible (real client)
local TOP_BAR = 90 -- du under the title / Medals / X bar

local SOON = { name = "Soon", color = Color3.fromRGB(150, 156, 168) }
local function sectorOf(n: Node): { name: string, color: Color3 }
	return if n.state == "soon" then SOON else SECTOR[n.sector] or SECTOR.Bridge
end

-- ---------------------------------------------------------------------------------------------
-- Octagons: a small EditableImage (128 px, downsampled to 50) gives a real octagon; a rounded
-- square is the fallback if the API is unavailable.

local octCache: { [string]: any } = {}

local function octContent(mode: string, fill: Color3, stroke: Color3, dashed: boolean): Content?
	local key = `{mode}|{fill:ToHex()}|{stroke:ToHex()}|{dashed}`
	local hit = octCache[key]
	if hit ~= nil then
		return if hit == false then nil else hit
	end
	local ok, content = pcall(function()
		local side = 128
		local img = AssetService:CreateEditableImage({ Size = Vector2.new(side, side) })
		local centre = Vector2.new(side * 0.5, side * 0.5)
		local outer, inner = {}, {}
		for k = 0, 7 do
			local a = math.rad(22.5 + k * 45)
			local d = Vector2.new(math.sin(a), -math.cos(a))
			outer[k + 1] = centre + d * 60
			inner[k + 1] = centre + d * 54
		end
		if mode ~= "fill" then
			for k = 1, 8 do
				local k2 = (k % 8) + 1
				local a, b, ia, ib = outer[k], outer[k2], inner[k], inner[k2]
				if dashed then
					local p1, p2 = a + (b - a) * 0.08, a + (b - a) * 0.52
					local q1, q2 = ia + (ib - ia) * 0.08, ia + (ib - ia) * 0.52
					img:DrawTriangle(p1, p2, q2, stroke, 0)
					img:DrawTriangle(p1, q2, q1, stroke, 0)
				else
					img:DrawTriangle(a, b, ib, stroke, 0)
					img:DrawTriangle(a, ib, ia, stroke, 0)
				end
			end
		end
		for k = 2, 7 do
			img:DrawTriangle(inner[1], inner[k], inner[k + 1], fill, 0)
		end
		return Content.fromObject(img)
	end)
	if ok and content then
		octCache[key] = content
		return content
	end
	octCache[key] = false
	return nil
end

local function octImage(
	parent: Instance,
	mode: string,
	fill: Color3,
	stroke: Color3,
	dashed: boolean,
	size: number
): ImageLabel?
	local content = octContent(mode, fill, stroke, dashed)
	if not content then
		return nil
	end
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	local ok = pcall(function()
		img.ImageContent = content
	end)
	if not ok then
		img:Destroy()
		return nil
	end
	img.ScaleType = Enum.ScaleType.Fit
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Position = UDim2.fromScale(0.5, 0.5)
	img.Size = UDim2.fromOffset(size, size)
	img.Parent = parent
	return img
end

local function roundedBadge(parent: Instance, fill: Color3, stroke: Color3, size: number): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromOffset(size, size)
	f.BackgroundColor3 = fill
	f.BorderSizePixel = 0
	Style.corner(f, math.floor(size * 0.28))
	local s = Style.stroke(f, 3, true)
	s.Color = stroke
	f.Parent = parent
	return f
end

-- ---------------------------------------------------------------------------------------------
-- Drawn keystone icons (bar primitives, no image quota), using the badge fill for cut-outs.

local bar = Glyph.bar

local function disc(p: Instance, w: number, h: number, x: number, y: number, c: Color3): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.BackgroundColor3 = c
	f.BorderSizePixel = 0
	Style.corner(f, 999)
	f.Parent = p
	return f
end

local function outline(
	p: Instance,
	size: number,
	x: number,
	y: number,
	c: Color3,
	thickness: number?
)
	local f = disc(p, size, size, x, y, c)
	f.BackgroundTransparency = 1
	local s = Style.stroke(f, thickness or 3, true)
	s.Color = c
	return f
end

local function drawIcon(kind: string, p: Instance, c: Color3, bg: Color3)
	if kind == "q" then
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Text = "?"
		t.TextScaled = true
		t.FontFace = Font.new(Theme.FONT, Enum.FontWeight.Bold)
		t.TextColor3 = c
		t.Parent = p
		return
	end
	if kind == "boat" or kind == "coin" or kind == "cross" or kind == "home" then
		Glyph.draw(kind, p, c)
		return
	end
	if kind == "house" then
		Glyph.draw("home", p, c)
		return
	end
	if kind == "bolt" then
		bar(p, Vector2.new(0.16, 0.36), Vector2.new(0.42, 0.3), -32, c, 0.2)
		bar(p, Vector2.new(0.24, 0.14), Vector2.new(0.5, 0.48), 0, c, 0.2)
		bar(p, Vector2.new(0.16, 0.34), Vector2.new(0.58, 0.7), -32, c, 0.2)
	elseif kind == "drop" then
		bar(p, Vector2.new(0.46, 0.46), Vector2.new(0.5, 0.36), 45, c, 0.08)
		disc(p, 0.56, 0.56, 0.5, 0.62, c)
	elseif kind == "buoy" then
		outline(p, 0.82, 0.5, 0.5, c)
		outline(p, 0.38, 0.5, 0.5, c)
		bar(p, Vector2.new(0.8, 0.1), Vector2.new(0.5, 0.5), 0, c)
		bar(p, Vector2.new(0.1, 0.8), Vector2.new(0.5, 0.5), 0, c)
	elseif kind == "chev" then
		for _, x in { 0.34, 0.64 } do
			bar(p, Vector2.new(0.1, 0.36), Vector2.new(x, 0.37), -45, c, 0.2)
			bar(p, Vector2.new(0.1, 0.36), Vector2.new(x, 0.63), 45, c, 0.2)
		end
	elseif kind == "eye" then
		outline(p, 0.84, 0.5, 0.5, c)
		disc(p, 0.3, 0.3, 0.5, 0.5, c)
	elseif kind == "gear" then
		outline(p, 0.54, 0.5, 0.5, c)
		for k = 0, 7 do
			local a = k * 45
			bar(
				p,
				Vector2.new(0.12, 0.26),
				Vector2.new(0.5 + math.sin(math.rad(a)) * 0.35, 0.5 - math.cos(math.rad(a)) * 0.35),
				a,
				c,
				0.2
			)
		end
	elseif kind == "star" then
		for _, a in { 0, 60, 120 } do
			bar(p, Vector2.new(0.12, 0.74), Vector2.new(0.5, 0.5), a, c, 0.2)
		end
	elseif kind == "sun" then
		for k = 0, 3 do
			bar(p, Vector2.new(0.09, 0.8), Vector2.new(0.5, 0.5), k * 45, c, 0.2)
		end
		disc(p, 0.34, 0.34, 0.5, 0.5, c)
	elseif kind == "heart" then
		disc(p, 0.34, 0.34, 0.36, 0.36, c)
		disc(p, 0.34, 0.34, 0.64, 0.36, c)
		bar(p, Vector2.new(0.46, 0.46), Vector2.new(0.5, 0.58), 45, c, 0.08)
	elseif kind == "clover" then
		disc(p, 0.34, 0.34, 0.5, 0.28, c)
		disc(p, 0.34, 0.34, 0.72, 0.5, c)
		disc(p, 0.34, 0.34, 0.5, 0.72, c)
		disc(p, 0.34, 0.34, 0.28, 0.5, c)
	elseif kind == "brick" then
		bar(p, Vector2.new(0.68, 0.23), Vector2.new(0.5, 0.37), 0, c, 0.12)
		bar(p, Vector2.new(0.68, 0.23), Vector2.new(0.5, 0.63), 0, c, 0.12)
		bar(p, Vector2.new(0.06, 0.2), Vector2.new(0.34, 0.63), 0, bg, 0.05)
		bar(p, Vector2.new(0.06, 0.2), Vector2.new(0.66, 0.37), 0, bg, 0.05)
	elseif kind == "fish" then
		local body = disc(p, 0.56, 0.4, 0.42, 0.5, c)
		body.Rotation = 0
		bar(p, Vector2.new(0.24, 0.18), Vector2.new(0.72, 0.35), -35, c, 0.2)
		bar(p, Vector2.new(0.24, 0.18), Vector2.new(0.72, 0.65), 35, c, 0.2)
		disc(p, 0.11, 0.11, 0.32, 0.44, bg)
	elseif kind == "hat" then
		disc(p, 0.48, 0.48, 0.5, 0.44, c)
		bar(p, Vector2.new(0.8, 0.14), Vector2.new(0.5, 0.68), 0, c, 0.1)
	elseif kind == "cart" then
		bar(p, Vector2.new(0.5, 0.32), Vector2.new(0.44, 0.44), 0, c, 0.1)
		disc(p, 0.2, 0.2, 0.3, 0.7, c)
		disc(p, 0.2, 0.2, 0.6, 0.7, c)
		bar(p, Vector2.new(0.22, 0.08), Vector2.new(0.78, 0.42), 0, c, 0.2)
	elseif kind == "moon" then
		disc(p, 0.62, 0.62, 0.46, 0.5, c)
		disc(p, 0.54, 0.54, 0.64, 0.4, bg)
	elseif kind == "plane" then
		bar(p, Vector2.new(0.1, 0.72), Vector2.new(0.5, 0.5), 0, c, 0.2)
		bar(p, Vector2.new(0.72, 0.1), Vector2.new(0.5, 0.46), 0, c, 0.2)
		bar(p, Vector2.new(0.28, 0.08), Vector2.new(0.5, 0.76), 0, c, 0.2)
	elseif kind == "medal" then
		Glyph.draw("medal", p, c)
	else
		outline(p, 0.7, 0.5, 0.5, c)
	end
end

local function clear(p: Instance)
	for _, ch in p:GetChildren() do
		if ch:IsA("GuiObject") then
			ch:Destroy()
		end
	end
end

local SkillTreeView = {}

function SkillTreeView.new(parent: Instance, props: Props): View
	local serial = 0
	serial += 1
	local action = `SkillTreeView_{serial}`

	local nodesById: { [string]: Node } = {}
	local stateById: { [string]: State } = {}
	local points: { TreeMath.Point } = {}
	local posById: { [string]: Vector2 } = {}
	local buttons: { [string]: ImageButton } = {}
	local marks: { [string]: ImageButton } = {}
	local order: { string } = {}

	local zoom = 1
	local pan = Vector2.zero
	local selectedId: string? = nil
	local selectionOnCard = false
	local buying = false
	local fitted = false
	local mini = false
	local medalValue = props.medals
	local refresh: () -> ()
	local beginDrag: (InputObject) -> ()
	local suppressUntil = 0
	local drag: { start: Vector2, pan: Vector2, moved: boolean, input: InputObject }? = nil
	local pinchStart: number? = nil
	local stickAt = 0

	local root = Instance.new("Frame")
	root.Name = "SkillTree"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.ClipsDescendants = true
	root.Visible = false
	root.ZIndex = 2
	root.Parent = parent

	-- empty space: on the full tree it starts a drag, over the world (minimap up) it restores the tree
	local hit = Style.button(root, UDim2.fromScale(1, 1))
	hit.Name = "Hit"
	hit.Selectable = false
	hit.ZIndex = 1

	-- the whole tree; one UIScale tween shrinks it into the bottom-left minimap (no per-frame layout)
	local stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.BackgroundColor3 = BG
	stage.BorderSizePixel = 0
	stage.AnchorPoint = Vector2.new(0, 1)
	stage.Position = UDim2.fromScale(0, 1)
	stage.Size = UDim2.fromScale(1, 1)
	stage.ClipsDescendants = true
	stage.Active = false -- taps on empty chart fall through to `hit`
	stage.ZIndex = 2
	stage.Parent = root
	local bgGrad = Instance.new("UIGradient")
	bgGrad.Color = ColorSequence.new(BG_TOP, BG)
	bgGrad.Rotation = 90
	bgGrad.Parent = stage
	local stageScale = Instance.new("UIScale")
	stageScale.Parent = stage
	local stageCorner = Style.corner(stage, 0)
	local stageStroke = Style.stroke(stage, 8, true)
	stageStroke.Color = Color3.new(1, 1, 1)
	stageStroke.Transparency = 1

	local content = Instance.new("Frame")
	content.Name = "Chart"
	content.BackgroundTransparency = 1
	content.ClipsDescendants = false
	content.Size = UDim2.fromOffset(1, 1)
	content.ZIndex = 2
	content.Parent = stage
	local zoomScale = Instance.new("UIScale")
	zoomScale.Parent = content

	local edgeLayer = Instance.new("Frame")
	edgeLayer.Name = "Edges"
	edgeLayer.BackgroundTransparency = 1
	edgeLayer.Size = UDim2.fromScale(1, 1)
	edgeLayer.ZIndex = 1
	edgeLayer.Parent = content

	local nodeLayer = Instance.new("Frame")
	nodeLayer.Name = "Nodes"
	nodeLayer.BackgroundTransparency = 1
	nodeLayer.Size = UDim2.fromScale(1, 1)
	nodeLayer.ZIndex = 3
	nodeLayer.Parent = content

	local edges: { Frame } = {}

	local size = TreeMath.radialSize()
	content.Size = UDim2.fromOffset(size.X, size.Y)

	-- faint rings + sector dividers + corner names ------------------------------------------------
	for i = 2, #TreeMath.RING_RADII do
		local r = TreeMath.RING_RADII[i]
		local ring = Instance.new("Frame")
		ring.Name = "Ring" .. i
		ring.BackgroundTransparency = 1
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromScale(0.5, 0.5)
		ring.Size = UDim2.fromOffset(r * 2, r * 2)
		Style.corner(ring, 999)
		local stroke = Style.stroke(ring, if i == #TreeMath.RING_RADII then 2 else 1.5, true)
		stroke.Color = if i == #TreeMath.RING_RADII then OUTER else RING
		stroke.Transparency = if i == #TreeMath.RING_RADII then 0.15 else 0.3
		ring.Parent = content
	end
	local centre = size * 0.5
	for _, angle in { 0, 90, 180, 270 } do
		local c = TreeMath.connector(centre, centre + TreeMath.polar(5, angle), 1.5)
		local f = Instance.new("Frame")
		f.BackgroundColor3 = DIVIDER
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromOffset(c.pos.X, c.pos.Y)
		f.Size = UDim2.fromOffset(c.size.X, c.size.Y)
		f.Rotation = c.rotation
		f.BackgroundTransparency = 0.35
		f.ZIndex = 1
		f.Parent = content
	end
	local CORNERS = {
		{ sector = "Captain", ax = 0, ay = 0, align = Enum.TextXAlignment.Left },
		{ sector = "Rescue", ax = 1, ay = 0, align = Enum.TextXAlignment.Right },
		{ sector = "Crew", ax = 1, ay = 1, align = Enum.TextXAlignment.Right },
		{ sector = "Industry", ax = 0, ay = 1, align = Enum.TextXAlignment.Left },
	}
	for _, corner in CORNERS do
		local look = SECTOR[corner.sector]
		local label = Style.label(stage, look.name, 40) -- screen corners: readable at any zoom
		label.AnchorPoint = Vector2.new(corner.ax, corner.ay)
		label.Position = UDim2.new(
			corner.ax,
			if corner.ax == 0 then 18 else -18,
			corner.ay,
			if corner.ay == 0 then 104 else -84 -- below the title / Medals / X bar, above bottom-corner HUD buttons
		)
		label.Size = UDim2.fromOffset(420, 52)
		label.TextXAlignment = corner.align
		label.TextWrapped = false
		label.TextColor3 = look.color
		label.ZIndex = 7
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = Theme.Colors.ink
			stroke.Thickness = 3
		end
	end

	-- centre compass -------------------------------------------------------------------------------
	local compass = Instance.new("Frame")
	compass.Name = "Compass"
	compass.AnchorPoint = Vector2.new(0.5, 0.5)
	compass.Position = UDim2.fromScale(0.5, 0.5)
	compass.Size = UDim2.fromOffset(100, 100)
	compass.BackgroundColor3 = BG
	compass.BorderSizePixel = 0
	compass.ZIndex = 2
	Style.corner(compass, 999)
	local cStroke = Style.stroke(compass, 3, true)
	cStroke.Color = Color3.new(1, 1, 1)
	compass.Parent = content
	for _, a in { 0, 45, 90, 135 } do
		local len = if a % 90 == 0 then 0.74 else 0.5
		Glyph.bar(
			compass,
			Vector2.new(if a % 90 == 0 then 0.1 else 0.07, len),
			Vector2.new(0.5, 0.5),
			a,
			if a % 90 == 0 then Color3.new(1, 1, 1) else Color3.fromHex("90A4AE"),
			0.2
		)
	end
	disc(compass, 0.14, 0.14, 0.5, 0.5, Color3.fromHex("FF5252"))
	local you = Style.label(content, "YOU", 16)
	you.AnchorPoint = Vector2.new(0.5, 0)
	you.Position = UDim2.new(0.5, 0, 0.5, 60)
	you.Size = UDim2.fromOffset(120, 24)
	you.ZIndex = 2

	local selRing = Instance.new("Frame")
	selRing.Name = "Selection"
	selRing.BackgroundTransparency = 1
	selRing.AnchorPoint = Vector2.new(0.5, 0.5)
	selRing.Size = UDim2.fromOffset(HIT, HIT)
	selRing.Visible = false
	selRing.ZIndex = 6
	Style.corner(selRing, 999)
	local selStroke = Style.stroke(selRing, 2.5, true)
	selStroke.Color = Color3.fromHex("FFE74A")
	selRing.Parent = content

	-- chrome: title, medal counter and the red X ------------------------------------------------
	local title = Style.label(stage, "SKILLS", 32)
	title.AnchorPoint = Vector2.new(0, 0)
	title.Position = UDim2.fromOffset(24, 20)
	title.Size = UDim2.fromOffset(220, 44)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 9

	local counter = Counter.new(root, { kind = "medal", value = medalValue })
	counter.root.Name = "SkillMedals"
	counter.root.AnchorPoint = Vector2.new(1, 0)
	counter.root.Position =
		UDim2.new(1, -(S.margin + S.close + 12), 0, S.margin + (S.close - S.counter.Y) * 0.5)
	counter.root.ZIndex = 9

	local close = Style.button(root, UDim2.fromOffset(S.close, S.close + S.lip))
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -S.margin, 0, S.margin)
	close.ZIndex = 10
	local _, closeFace = Style.block(close, Style.grad("close"), { radius = S.cornerSmall })
	local x = Style.label(closeFace, "X", Theme.Text.title)
	x.TextScaled = false

	-- the free reset, left of the Medal counter (a circular arrow; refunds every Medal)
	local reset = Style.button(stage, UDim2.fromOffset(S.close, S.close + S.lip))
	reset.Name = "Reset"
	reset.AnchorPoint = Vector2.new(1, 0)
	reset.Position = UDim2.new(1, -(S.margin + S.close + 24 + S.counter.X), 0, S.margin)
	reset.ZIndex = 10
	local _, resetFace = Style.block(reset, Style.grad("blue"), { radius = S.cornerSmall })
	local arrow = Instance.new("ImageLabel")
	arrow.BackgroundTransparency = 1
	arrow.Image = UiImages.SettingsArt.reset
	arrow.ScaleType = Enum.ScaleType.Fit
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position = UDim2.fromScale(0.5, 0.5)
	arrow.Size = UDim2.fromScale(0.62, 0.62)
	arrow.ZIndex = 11
	arrow.Parent = resetFace

	-- the detail card: slides in on the right while the tree sits in the corner ----------------------
	local CARD_IN = UDim2.new(1, -24, 0.5, 40)
	local CARD_OUT = UDim2.new(1, 440, 0.5, 40)
	local card = Instance.new("Frame")
	card.Name = "Detail"
	card.AnchorPoint = Vector2.new(1, 0.5)
	card.Position = CARD_OUT
	card.Size = UDim2.fromOffset(380, 380)
	card.BackgroundColor3 = CARD
	card.BackgroundTransparency = 0.03
	card.Visible = false
	card.ZIndex = 8
	Style.corner(card, 20)
	local cardStroke = Style.stroke(card, 4, true)
	cardStroke.Color = SECTOR.Captain.color
	card.Parent = root

	local cardX = Style.button(card, UDim2.fromOffset(52, 52 + S.lip))
	cardX.Name = "Close"
	cardX.AnchorPoint = Vector2.new(1, 0)
	cardX.Position = UDim2.new(1, -12, 0, 12)
	cardX.ZIndex = 10
	local _, cardXFace = Style.block(cardX, Style.grad("close"), { radius = S.cornerSmall })
	Style.label(cardXFace, "X", 26).TextScaled = false

	local cardIcon = Instance.new("Frame")
	cardIcon.Name = "Art"
	cardIcon.BackgroundTransparency = 1
	cardIcon.AnchorPoint = Vector2.new(0.5, 0)
	cardIcon.Position = UDim2.new(0.5, 0, 0, 22)
	cardIcon.Size = UDim2.fromOffset(112, 112)
	cardIcon.ZIndex = 9
	cardIcon.Parent = card

	local cardName = Style.label(card, "", 28)
	cardName.AnchorPoint = Vector2.new(0.5, 0)
	cardName.Position = UDim2.new(0.5, 0, 0, 146)
	cardName.Size = UDim2.new(1, -32, 0, 36)
	cardName.TextWrapped = false
	cardName.TextTruncate = Enum.TextTruncate.AtEnd
	cardName.ZIndex = 9

	local cardEffect = Style.label(card, "", 40)
	cardEffect.AnchorPoint = Vector2.new(0.5, 0)
	cardEffect.Position = UDim2.new(0.5, 0, 0, 186)
	cardEffect.Size = UDim2.new(1, -32, 0, 50)
	cardEffect.TextWrapped = false
	cardEffect.TextColor3 = Color3.fromHex("FFE082")
	cardEffect.ZIndex = 9

	local function activateBuy()
		local n = if selectedId then nodesById[selectedId :: string] else nil
		if not n or buying or n.state ~= "buyable" or medalValue < n.price then
			return
		end
		if props.onBuy == nil then
			return
		end
		buying = true
		refresh()
		props.onBuy(n.id, function(ok: boolean)
			buying = false
			if selectedId == n.id then
				refresh()
			end
			if not ok then
				return
			end
		end)
	end

	local pb = PriceButton.new(card, {
		price = 1,
		currency = "Medal",
		onActivate = activateBuy,
	})
	pb.root.Name = "Buy"
	pb.root.Size = UDim2.fromOffset(220, 72)
	pb.root.AnchorPoint = Vector2.new(0.5, 1)
	pb.root.Position = UDim2.new(0.5, 0, 1, -22)
	pb.root.ZIndex = 10
	Style.press(close, function()
		if props.onClose then
			props.onClose()
		end
	end, S.cornerSmall)
	Style.press(reset, function()
		if props.onReset then
			props.onReset()
		end
	end, S.cornerSmall)

	-- -------------------------------------------------------------------------------------------
	local function kitScale(): number
		local _, k = Style.metrics(root)
		return math.max(k, 0.05)
	end

	local function viewportDu(): Vector2
		return root.AbsoluteSize / kitScale()
	end

	local moving: { Tween } = {}
	-- place the chart; `time` tweens it there (a re-fit after a buy)
	local function apply(time: number?)
		for _, tw in moving do
			tw:Cancel()
		end
		moving = {}
		local at = UDim2.fromOffset(pan.X, pan.Y)
		if time then
			local info = TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			moving = {
				TweenService:Create(content, info, { Position = at }),
				TweenService:Create(zoomScale, info, { Scale = zoom }),
			}
			for _, tw in moving do
				tw:Play()
			end
		else
			content.Position = at
			zoomScale.Scale = zoom
		end
	end

	local function viewRect(): TreeMath.View
		local vp = viewportDu()
		return { pos = Vector2.zero, size = Vector2.new(math.max(vp.X, 4), math.max(vp.Y, 200)) }
	end

	local function clampView()
		pan = TreeMath.clampPanIn(pan, viewRect(), size, zoom)
		apply()
	end

	-- zoom and pan onto what you can unlock (+ the centre), not the whole tree (owner 2026-10-28); never
	-- below FIT_MIN_ZOOM, so a grown tree still opens big (pinch / scroll zoom out to MIN_ZOOM)
	local function fit(time: number?)
		local pts = { centre }
		for id, at in posById do
			if stateById[id] == "buyable" then
				table.insert(pts, at)
			end
		end
		if #pts == 1 then -- nothing left to unlock: the whole tree
			for _, at in posById do
				table.insert(pts, at)
			end
		end
		local vp = viewRect()
		local free = { pos = Vector2.new(0, TOP_BAR), size = vp.size - Vector2.new(0, TOP_BAR) }
		zoom, pan = TreeMath.fitBox(pts, free, FIT_PAD, FIT_MIN_ZOOM, TreeMath.MAX_ZOOM)
		pan = TreeMath.clampPanIn(pan, vp, size, zoom)
		apply(time)
	end

	local function deselect()
		selectedId = nil
		selectionOnCard = false
		pb.root.Selectable = false
		selRing.Visible = false
	end

	-- the tree in the bottom-left corner + the node card, or the full tree back
	-- over the minimap: a tap anywhere on it brings the full tree back
	local miniHit = Style.button(stage, UDim2.fromScale(1, 1))
	miniHit.Name = "Restore"
	miniHit.Selectable = false
	miniHit.Visible = false
	miniHit.ZIndex = 20
	local function setMini(on: boolean)
		if mini == on then
			return
		end
		mini = on
		drag = nil
		miniHit.Visible = on
		stageCorner.CornerRadius = UDim.new(0, if on then 60 else 0)
		Style.tween(stageScale, 0.35, { Scale = if on then MINI else 1 })
		Style.tween(stageStroke, 0.35, { Transparency = if on then 0 else 1 })
		-- clear of the wallet / Cash under the hidden left menu
		Style.tween(stage, 0.35, {
			Position = if on then UDim2.new(0, 24, 1, -110) else UDim2.fromScale(0, 1),
		})
		if on then
			card.Visible = true
			Style.tween(card, 0.3, { Position = CARD_IN })
		else
			card.Visible = false
			card.Position = CARD_OUT
			pb.root.Selectable = false
			if props.onEndFocus then
				props.onEndFocus()
			end
		end
	end

	refresh = function()
		local n = if selectedId then nodesById[selectedId :: string] else nil
		if not n then
			deselect()
			setMini(false)
			return
		end
		local look = sectorOf(n)
		cardStroke.Color = look.color
		clear(cardIcon)
		local owned = n.state == "owned"
		local fill = if owned then look.color else BG
		local art = Instance.new("Frame")
		art.BackgroundTransparency = 1
		art.AnchorPoint = Vector2.new(0.5, 0.5)
		art.Position = UDim2.fromScale(0.5, 0.5)
		art.Size = UDim2.fromOffset(100, 100)
		art.Parent = cardIcon
		if
			not octImage(
				cardIcon,
				"badge",
				fill,
				if owned then Color3.new(1, 1, 1) else look.color,
				false,
				112
			)
		then
			roundedBadge(cardIcon, fill, if owned then Color3.new(1, 1, 1) else look.color, 112)
		end
		art.ZIndex = 2
		drawIcon(n.icon, art, if owned then ICON_OWNED else look.color, fill)
		cardName.Text = n.name
		cardEffect.Text = n.effect

		local affordable = medalValue >= n.price
		if owned then
			pb.setState("owned")
			pb.setText(nil)
		elseif n.state == "soon" then
			pb.setState("disabled")
			pb.setText("Soon")
		elseif buying then
			pb.setState("disabled")
			pb.setText("...")
		else
			pb.setState(if affordable then "buy" else "disabled")
			pb.setText(nil)
		end
		pb.setPrice(n.price)
		pb.root.Selectable = mini and not owned and affordable and not buying
	end

	-- selecting a node shows its card; `open` also moves the camera (the panel) and the gamepad
	-- selection to the buy button
	local choose: (string, boolean) -> ()

	local function reveal(id: string)
		local at = posById[id]
		if not at then
			return
		end
		local view = viewRect()
		local screen = pan + at * zoom
		local mx = math.min(
			(if nodesById[id] and nodesById[id].keystone then BADGE else DOT) * 0.5 * zoom + 12,
			view.size.X * 0.45
		)
		local my = mx + 26
		local nx, ny = pan.X, pan.Y
		if screen.X < view.pos.X + mx then
			nx = view.pos.X + mx - at.X * zoom
		elseif screen.X > view.pos.X + view.size.X - mx then
			nx = view.pos.X + view.size.X - mx - at.X * zoom
		end
		if screen.Y < view.pos.Y + my then
			ny = view.pos.Y + my - at.Y * zoom
		elseif screen.Y > view.pos.Y + view.size.Y - my then
			ny = view.pos.Y + view.size.Y - my - at.Y * zoom
		end
		pan = TreeMath.clampPanIn(Vector2.new(nx, ny), view, size, zoom)
		apply()
	end

	local function segments(): { { a: string?, b: string } }
		local out: { { a: string?, b: string } } = {}
		local minors: { [string]: { Node } } = {}
		for _, n in nodesById do
			if not n.keystone then
				local base = string.match(n.id, "^(.+)_m%d+$")
				if base then
					local list = minors[base]
					if not list then
						list = {}
						minors[base] = list
					end
					table.insert(list, n)
				end
			end
		end
		for _, list in minors do
			table.sort(list, function(na: Node, nb: Node): boolean
				return (tonumber(string.match(na.id, "_(%d+)$")) or 0)
					< (tonumber(string.match(nb.id, "_(%d+)$")) or 0)
			end)
		end
		local used: { [string]: boolean } = {}
		for _, n in nodesById do
			if n.keystone then
				local list: { Node } = minors[n.id] or {}
				if #list > 0 then
					local prev = if #list[1].needs > 0 then list[1].needs[1] else nil -- the chain's start
					for _, m in list do
						table.insert(out, { a = prev, b = m.id })
						used[m.id] = true
						prev = m.id
					end
					table.insert(out, { a = prev, b = n.id })
				else
					for _, need in n.needs do
						table.insert(out, { a = need, b = n.id })
					end
				end
				for i = 2, #n.needs do
					table.insert(out, { a = n.needs[i], b = n.id })
				end
				if #n.needs == 0 and #list == 0 then
					table.insert(out, { a = nil, b = n.id })
				end
				used[n.id] = true
			end
		end
		-- a dot that is not on a keystone chain still joins its need
		for _, n in nodesById do
			if not n.keystone and not used[n.id] then
				for _, need in n.needs do
					table.insert(out, { a = need, b = n.id })
				end
			end
		end
		return out
	end

	local function linkLook(a: Node?, b: Node): (Color3, number, number)
		local ownedA = a == nil or a.state == "owned"
		if ownedA and b.state == "owned" then
			return sectorOf(b).color, 0.08, 4.5
		end
		return sectorOf(b).color, 0.5, 3.5
	end

	local function addEdge(from: Vector2, to: Vector2, colour: Color3, alpha: number, thick: number)
		local c = TreeMath.connector(from, to, thick)
		local f = Instance.new("Frame")
		f.BackgroundColor3 = colour
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromOffset(c.pos.X, c.pos.Y)
		f.Size = UDim2.fromOffset(c.size.X, c.size.Y)
		f.Rotation = c.rotation
		f.BackgroundTransparency = alpha
		f.ZIndex = 1
		Style.corner(f, 99)
		f.Parent = edgeLayer
		table.insert(edges, f)
	end

	local function nodeVisual(n: Node, at: Vector2)
		local look = sectorOf(n)
		local fill = if n.state == "owned" then look.color else BG
		local stroke = if n.state == "owned" then Color3.new(1, 1, 1) else look.color
		local hitSize = if n.keystone then HIT else DOT_HIT
		local b = Style.button(nodeLayer, UDim2.fromOffset(hitSize, hitSize))
		b.Name = "Node_" .. n.id
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Position = UDim2.fromOffset(at.X, at.Y)
		b.ClipsDescendants = false
		b.ZIndex = if n.keystone then 4 else 3
		b:SetAttribute("SkillNodeId", n.id)
		buttons[n.id] = b
		marks[n.id] = b
		local badge = if n.keystone then BADGE else DOT
		if n.state == "owned" then
			local glow = octImage(b, "fill", look.color, look.color, false, badge * 1.45)
			if glow then
				glow.ImageTransparency = 0.78
				glow.ZIndex = 0
			end
		elseif n.state == "buyable" then -- unlockable next: a steady soft halo, no looping pulse (owner 2026-10-28)
			local halo = octImage(b, "fill", look.color, look.color, false, badge * 1.5)
			if halo then
				halo.ImageTransparency = 0.7
				halo.ZIndex = 0
			end
		end
		local art = Instance.new("Frame")
		art.BackgroundTransparency = 1
		art.AnchorPoint = Vector2.new(0.5, 0.5)
		art.Position = UDim2.fromScale(0.5, 0.5)
		art.Size = UDim2.fromOffset(badge, badge)
		art.ZIndex = 2
		art.Parent = b
		if n.keystone then
			if not octImage(b, "badge", fill, stroke, false, BADGE) then
				roundedBadge(b, fill, stroke, BADGE)
			end
			drawIcon(n.icon, art, if n.state == "owned" then ICON_OWNED else look.color, fill)
			local label = Style.label(b, n.name, 17)
			label.AnchorPoint = Vector2.new(0.5, 0)
			label.Position = UDim2.new(0.5, 0, 0, 48)
			label.Size = UDim2.fromOffset(136, 22)
			label.TextXAlignment = Enum.TextXAlignment.Center
			label.TextWrapped = false
			label.TextTruncate = Enum.TextTruncate.AtEnd
			label.TextColor3 = if n.state == "owned" then Color3.new(1, 1, 1) else look.color
			label.ZIndex = 5
		else
			if not octImage(b, "badge", fill, stroke, false, DOT) then
				roundedBadge(b, fill, stroke, DOT)
			end
			if n.state == "buyable" then
				local ring = Instance.new("Frame")
				ring.BackgroundTransparency = 1
				ring.AnchorPoint = Vector2.new(0.5, 0.5)
				ring.Position = UDim2.fromScale(0.5, 0.5)
				ring.Size = UDim2.fromOffset(DOT + 9, DOT + 9)
				Style.corner(ring, 999)
				local s = Style.stroke(ring, 2, true)
				s.Color = look.color
				ring.ZIndex = 1
				ring.Parent = b
			end
		end
		b.InputBegan:Connect(beginDrag)
		Style.press(b, function()
			if os.clock() >= suppressUntil then
				choose(n.id, true)
			end
		end, 99)
	end

	local function rebuildEdges()
		for _, f in edges do
			f:Destroy()
		end
		edges = {}
		edgeLayer:Destroy()
		edgeLayer = Instance.new("Frame")
		edgeLayer.Name = "Edges"
		edgeLayer.BackgroundTransparency = 1
		edgeLayer.Size = UDim2.fromScale(1, 1)
		edgeLayer.ZIndex = 1
		edgeLayer.Parent = content
		for _, seg in segments() do
			local a = if seg.a then nodesById[seg.a] else nil
			local b = nodesById[seg.b]
			local from = if seg.a then posById[seg.a] else centre -- nil: a hidden end, no link
			local to = posById[seg.b]
			if b and from and to then
				local colour, alpha, thick = linkLook(a, b)
				addEdge(from, to, colour, alpha, thick)
			end
		end
	end

	local function addNewestHalo(id: string)
		local at = posById[id]
		local n = nodesById[id]
		if not at or not n then
			return
		end
		local halo = Instance.new("Frame")
		halo.Name = "Newest"
		halo.AnchorPoint = Vector2.new(0.5, 0.5)
		halo.Position = UDim2.fromOffset(at.X, at.Y)
		halo.Size = UDim2.fromOffset(70, 70)
		halo.BackgroundTransparency = 1
		halo.ZIndex = 5
		Style.corner(halo, 999)
		local s = Style.stroke(halo, 3, true)
		s.Color = GOLD
		s.Transparency = 0.1
		halo.Parent = content
		Style.tween(halo, 0.8, { Size = UDim2.fromOffset(130, 130) })
		Style.tween(s, 0.8, { Transparency = 1 })
		task.delay(0.85, function()
			halo:Destroy()
		end)
	end

	local firstBuild = true
	-- -> did the set of shown nodes change (a buy revealed more, a reset hid them)?
	local function build(nodes: { Node }): boolean
		local previousState = stateById
		local wasOwned: { [string]: boolean } = {}
		for id, state in previousState do
			wasOwned[id] = state == "owned"
		end
		nodesById = {}
		stateById = {}
		points = {}
		posById = {}
		buttons = {}
		marks = {}
		order = {}
		for _, n in nodes do
			nodesById[n.id] = n
			stateById[n.id] = n.state
			if n.keystone then
				table.insert(order, n.id)
			end
		end
		local radial: { TreeMath.RadialNode } = {}
		for _, n in nodes do
			table.insert(radial, { id = n.id, ring = n.ring, angle = n.angle })
		end
		posById = TreeMath.radialLayout(radial)
		nodeLayer:Destroy()
		nodeLayer = Instance.new("Frame")
		nodeLayer.Name = "Nodes"
		nodeLayer.BackgroundTransparency = 1
		nodeLayer.Size = UDim2.fromScale(1, 1)
		nodeLayer.ZIndex = 3
		nodeLayer.Parent = content
		rebuildEdges()
		local sorted = table.clone(nodes)
		table.sort(sorted, function(a: Node, b: Node): boolean
			if a.keystone ~= b.keystone then
				return not a.keystone
			end
			return false
		end)
		for _, n in sorted do
			local at = posById[n.id]
			if at then
				nodeVisual(n, at)
				table.insert(points, { id = n.id, pos = at })
			end
		end
		local shownChanged = false
		for id in previousState do
			shownChanged = shownChanged or nodesById[id] == nil
		end
		if selectedId and nodesById[selectedId :: string] then
			refresh()
			local b = buttons[selectedId :: string]
			if b and UserInputService.GamepadEnabled then
				GuiService.SelectedObject = if selectionOnCard and pb.root.Selectable
					then pb.root
					else b
			end
		else
			deselect()
			setMini(false)
		end
		if not firstBuild then
			for _, n in nodes do
				local old = previousState[n.id]
				shownChanged = shownChanged or old == nil
				if n.state == "buyable" and old ~= "buyable" then
					local mark = marks[n.id]
					if mark then -- one gentle pop: newly reachable tiles grow in from small
						local sc = mark:FindFirstChildOfClass("UIScale")
						if sc then
							sc.Scale = if old == nil then 0.2 else 0.7
							Style.tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
						end
					end
				end
			end
			for _, n in nodes do
				if n.state == "owned" and not wasOwned[n.id] then
					local mark = marks[n.id]
					if mark then
						local sc = mark:FindFirstChildOfClass("UIScale")
						if sc then
							sc.Scale = 1.35
							Style.tween(sc, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
						end
						-- lock-in: one ring in the sector colour snaps out from the node and fades
						local ringSize = if n.keystone then BADGE else DOT
						local ring = Instance.new("Frame")
						ring.Name = "LockIn"
						ring.AnchorPoint = Vector2.new(0.5, 0.5)
						ring.Position = UDim2.fromScale(0.5, 0.5)
						ring.Size = UDim2.fromOffset(ringSize, ringSize)
						ring.BackgroundTransparency = 1
						ring.ZIndex = 5
						ring.Parent = mark
						Style.corner(ring, 999)
						local stroke = Style.stroke(ring, 5, true)
						stroke.Color = sectorOf(n).color
						Style.tween(
							ring,
							0.5,
							{ Size = UDim2.fromOffset(ringSize * 2.6, ringSize * 2.6) }
						)
						Style.tween(stroke, 0.5, { Transparency = 1 })
						task.delay(0.6, function()
							ring:Destroy()
						end)
					end
					local path = {}
					local need = if #n.needs > 0 then n.needs[1] else nil
					local start = if need then posById[need] else centre
					if start then
						table.insert(path, start)
						local at = posById[n.id]
						if at then
							table.insert(path, at)
							task.spawn(function()
								local dot = Instance.new("Frame")
								dot.BackgroundColor3 = GOLD
								dot.BorderSizePixel = 0
								dot.AnchorPoint = Vector2.new(0.5, 0.5)
								dot.Size = UDim2.fromOffset(12, 12)
								dot.ZIndex = 6
								Style.corner(dot, 999)
								dot.Parent = content
								local total = 0
								for i = 2, #path do
									total += (path[i] - path[i - 1]).Magnitude
								end
								total = math.max(total, 1)
								local t = 0
								local run: RBXScriptConnection
								run = RunService.Heartbeat:Connect(function(dt: number)
									t += dt * 0.45
									local left = math.min(t, 1) * total
									local p = path[1]
									for i = 2, #path do
										local d = (path[i] - path[i - 1]).Magnitude
										if left <= d then
											p = path[i - 1]
												+ (path[i] - path[i - 1])
													* (left / math.max(d, 1e-6))
											break
										end
										left -= d
										p = path[i]
									end
									dot.Position = UDim2.fromOffset(p.X, p.Y)
									if t >= 1 then
										run:Disconnect()
										dot:Destroy()
									end
								end)
							end)
						end
					end
				end
			end
		end
		firstBuild = false
		return shownChanged
	end

	beginDrag = function(input: InputObject)
		local t = input.UserInputType
		if
			(t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch)
			and drag == nil
			and not mini
		then
			drag = {
				start = Vector2.new(input.Position.X, input.Position.Y),
				pan = pan,
				moved = false,
				input = input,
			}
		end
	end

	local function move(dir: Vector2)
		local view = viewRect()
		local from: Vector2
		local selected = if selectedId then posById[selectedId :: string] else nil
		if selected then
			from = selected
		else
			from = (view.pos + view.size * 0.5 - pan) / zoom
		end
		local id = TreeMath.nearest(points, from, dir)
		if id then
			choose(id, false)
		end
	end

	choose = function(id: string, open: boolean)
		local n = nodesById[id]
		if not n then
			return
		end
		selectedId = id
		open = open or mini -- the stick in the corner state flips through the cards
		if open then
			setMini(true)
		end
		refresh()
		if n.keystone then
			selRing.Size = UDim2.fromOffset(HIT + 6, HIT + 6)
		else
			selRing.Size = UDim2.fromOffset(DOT + 18, DOT + 18)
		end
		selRing.Position = UDim2.fromOffset(posById[id].X, posById[id].Y)
		selRing.Visible = true
		selectionOnCard = false
		if open and UserInputService.GamepadEnabled and pb.root.Selectable then
			selectionOnCard = true
			GuiService.SelectedObject = pb.root
		elseif buttons[id] and UserInputService.GamepadEnabled then
			GuiService.SelectedObject = buttons[id]
		end
		reveal(id)
		if open and props.onSelect then
			props.onSelect(n)
		end
	end

	-- drag / wheel / pinch ------------------------------------------------------------------------
	hit.InputBegan:Connect(beginDrag)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if not root.Visible then
			return
		end
		local t = input.UserInputType
		if
			drag
			and (
				t == Enum.UserInputType.MouseMovement
				or (t == Enum.UserInputType.Touch and input == drag.input)
			)
		then
			local d = drag :: any
			local delta = Vector2.new(input.Position.X, input.Position.Y) - d.start
			if delta.Magnitude > 6 then
				d.moved = true
				suppressUntil = os.clock() + 0.25
			end
			if d.moved then
				pan = d.pan + delta / kitScale()
				pan = TreeMath.clampPanIn(pan, viewRect(), size, zoom)
				apply()
			end
		elseif t == Enum.UserInputType.MouseWheel and not mini then
			local view = viewRect()
			local before = zoom
			zoom =
				math.clamp(zoom * (1.12 ^ input.Position.Z), TreeMath.MIN_ZOOM, TreeMath.MAX_ZOOM)
			pan = TreeMath.zoomAbout(pan, view.pos + view.size * 0.5, before, zoom)
			pan = TreeMath.clampPanIn(pan, view, size, zoom)
			apply()
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if not drag then
			return
		end
		local d = drag :: any
		local t = input.UserInputType
		if
			t == Enum.UserInputType.MouseButton1
			or (t == Enum.UserInputType.Touch and input == d.input)
		then
			drag = nil
			if d.moved then
				suppressUntil = os.clock() + 0.2
			end
		end
	end)
	hit.Activated:Connect(function()
		if os.clock() < suppressUntil then
			return
		end
		deselect()
		setMini(false) -- over the world: the full tree comes back
	end)
	local function restore()
		deselect()
		setMini(false)
	end
	miniHit.Activated:Connect(restore)
	Style.press(cardX, restore, S.cornerSmall)
	UserInputService.TouchPinch:Connect(function(_, scale: number, _, state: Enum.UserInputState)
		if not root.Visible then
			return
		end
		if state == Enum.UserInputState.Begin and not mini then
			pinchStart = zoom
			drag = nil
		elseif state == Enum.UserInputState.Change and pinchStart then
			local view = viewRect()
			local before = zoom
			zoom =
				math.clamp(pinchStart * math.max(scale, 0.05), TreeMath.MIN_ZOOM, TreeMath.MAX_ZOOM)
			pan = TreeMath.zoomAbout(pan, view.pos + view.size * 0.5, before, zoom)
			pan = TreeMath.clampPanIn(pan, view, size, zoom)
			apply()
		else
			pinchStart = nil
		end
	end)

	-- keyboard / gamepad --------------------------------------------------------------------------
	local DIRS: { [Enum.KeyCode]: Vector2 } = {
		[Enum.KeyCode.DPadUp] = Vector2.new(0, -1),
		[Enum.KeyCode.DPadDown] = Vector2.new(0, 1),
		[Enum.KeyCode.DPadLeft] = Vector2.new(-1, 0),
		[Enum.KeyCode.DPadRight] = Vector2.new(1, 0),
		[Enum.KeyCode.Up] = Vector2.new(0, -1),
		[Enum.KeyCode.Down] = Vector2.new(0, 1),
		[Enum.KeyCode.Left] = Vector2.new(-1, 0),
		[Enum.KeyCode.Right] = Vector2.new(1, 0),
	}

	local function back()
		if not root.Visible then
			return false
		end
		if mini then
			restore()
			return true
		end
		return false
	end

	ContextActionService:BindActionAtPriority(
		action,
		function(_, state, input)
			if not root.Visible then
				return Enum.ContextActionResult.Pass
			end
			local key = input.KeyCode
			if key == Enum.KeyCode.Thumbstick1 then
				local v = Vector2.new(input.Position.X, -input.Position.Y)
				if
					(state == Enum.UserInputState.Begin or state == Enum.UserInputState.Change)
					and v.Magnitude > 0.55
					and os.clock() - stickAt > 0.22
				then
					stickAt = os.clock()
					move(v.Unit)
					return Enum.ContextActionResult.Sink
				end
				return Enum.ContextActionResult.Pass
			end
			if key == Enum.KeyCode.ButtonB then
				if state == Enum.UserInputState.Begin and back() then
					return Enum.ContextActionResult.Sink
				end
				return Enum.ContextActionResult.Pass
			end
			if key == Enum.KeyCode.ButtonA or key == Enum.KeyCode.Return then
				if state ~= Enum.UserInputState.Begin then
					return Enum.ContextActionResult.Pass
				end
				local sel = GuiService.SelectedObject
				if selectionOnCard and sel == pb.root and pb.root.Selectable then
					activateBuy()
					return Enum.ContextActionResult.Sink
				end
				if sel and sel:IsA("GuiButton") and sel:GetAttribute("SkillNodeId") == nil then
					return Enum.ContextActionResult.Pass
				end
				local id = selectedId or order[1]
				if id then
					choose(id, true)
					return Enum.ContextActionResult.Sink
				end
				return Enum.ContextActionResult.Pass
			end
			local dir = DIRS[key]
			if dir and state == Enum.UserInputState.Begin then
				move(dir)
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end,
		false,
		Enum.ContextActionPriority.High.Value + 30,
		Enum.KeyCode.DPadUp,
		Enum.KeyCode.DPadDown,
		Enum.KeyCode.DPadLeft,
		Enum.KeyCode.DPadRight,
		Enum.KeyCode.Up,
		Enum.KeyCode.Down,
		Enum.KeyCode.Left,
		Enum.KeyCode.Right,
		Enum.KeyCode.ButtonA,
		Enum.KeyCode.ButtonB,
		Enum.KeyCode.Return,
		Enum.KeyCode.Thumbstick1
	)

	UserInputService.InputBegan:Connect(function(input: InputObject)
		if not root.Visible then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape then
			if not back() and props.onClose then
				props.onClose()
			end
		end
	end)
	root.Destroying:Connect(function()
		ContextActionService:UnbindAction(action)
	end)

	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if fitted then
			clampView()
		end
	end)

	local function openAt(id: string?)
		if not fitted or #points == 0 then
			return
		end
		restore()
		fit()
		if id then
			addNewestHalo(id)
			local b = buttons[id]
			if b and UserInputService.GamepadEnabled then
				GuiService.SelectedObject = b
			end
		end
	end

	local function setNodes(nodes: { Node }, medals: number)
		if medals ~= medalValue then
			medalValue = medals
			counter.set(medals)
		end
		if build(nodes) and root.Visible then
			fit(0.5) -- zoom out smoothly onto the newly revealed nodes
		end
		fitted = true
	end

	local function closeView()
		root.Visible = false
		deselect()
		if mini then -- snap back, so the next open starts on the full tree
			setMini(false)
			stageScale.Scale = 1
			stage.Position = UDim2.fromScale(0, 1)
			stageStroke.Transparency = 1
		end
		local sel = GuiService.SelectedObject
		if sel and sel:IsDescendantOf(root) then
			GuiService.SelectedObject = nil
		end
	end

	build(props.nodes)
	fitted = true

	return {
		root = root,
		setNodes = setNodes,
		openAt = openAt,
		close = function()
			closeView()
		end,
		isOpen = function()
			return root.Visible
		end,
	}
end

return SkillTreeView
