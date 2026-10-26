--!strict
-- TreeView: the Kit's generic skill / tech tree. Nodes are chunky Kit cards (icon, 1-3 word
-- name, Cash price or a tick) laid out as horizontal lanes per group, joined by lines from each
-- prerequisite to the node. Drag (mouse + touch) pans, wheel / pinch zooms, and the D-pad / left
-- stick moves the selection to the nearest node in that direction (TreeMath.nearest), A opens it.
-- Selecting shows a small detail card with the effect and a green Cash PriceButton.
--   local v = TreeView.new(parent, { nodes = {...}, groups = {...}, cash = 1250,
--       onSelect = fn(id), onBuy = fn(id) })
--   v.setNodes(nodes, cash)  v.select(id)
-- Node: { id, name, icon, price, needs = {ids}, col, row, group?, effect?, state? }
-- state: "owned" | "buyable" | "locked" | "busy" (default locked).
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Glyph = require(script.Parent.Parent:WaitForChild("Glyph"))
local PriceButton = require(script.Parent:WaitForChild("PriceButton"))
local Style = require(script.Parent:WaitForChild("Style"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local TreeMath = require(script.Parent:WaitForChild("TreeMath"))

local S = Theme.Size

export type State = "owned" | "buyable" | "locked" | "busy"
export type Node = {
	id: string,
	name: string,
	icon: string,
	price: number,
	needs: { string },
	col: number,
	row: number,
	group: string?,
	effect: string?,
	state: State?,
}
export type Group = { id: string, name: string, icon: string?, color: string? }
export type Props = {
	nodes: { Node },
	groups: { Group }?,
	cash: number?,
	onSelect: ((string) -> ())?,
	onBuy: ((string) -> ())?,
}
export type TreeView = {
	root: Frame,
	setNodes: (nodes: { Node }, cash: number?) -> (),
	select: (id: string) -> (),
	selected: () -> string?,
}

local GRAD: { [State]: string } = {
	owned = "owned",
	buyable = "blue",
	locked = "locked",
	busy = "orange",
}
local LINK: { [State]: Color3 } = {
	owned = Color3.fromHex("E9B324"),
	buyable = Color3.fromHex("2C8EF0"),
	locked = Color3.fromHex("9AA0B4"),
	busy = Color3.fromHex("FFB21E"),
}
local GOLD = Color3.fromHex("FFC928")
local GREEN = Color3.fromHex("59F27A")

local serial = 0

-- A drawn hourglass (no image quota): two caps joined by a pinched X.
local function hourglass(parent: Instance)
	local box = Instance.new("Frame")
	box.Name = "Hourglass"
	box.BackgroundTransparency = 1
	box.Size = UDim2.fromScale(1, 1)
	box.Parent = parent
	Glyph.bar(box, Vector2.new(0.72, 0.12), Vector2.new(0.5, 0.14), 0, GOLD)
	Glyph.bar(box, Vector2.new(0.72, 0.12), Vector2.new(0.5, 0.86), 0, GOLD)
	Glyph.bar(box, Vector2.new(0.62, 0.09), Vector2.new(0.5, 0.5), 58, GOLD)
	Glyph.bar(box, Vector2.new(0.62, 0.09), Vector2.new(0.5, 0.5), -58, GOLD)
end

local TreeView = {}

function TreeView.new(parent: Instance, props: Props): TreeView
	serial += 1
	local action = `TreeView_{serial}`
	local selectedId: string? = nil

	local root = Instance.new("Frame")
	root.Name = "TreeView"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.ClipsDescendants = true
	root.ZIndex = 2
	root.Parent = parent

	local hit = Style.button(root, UDim2.fromScale(1, 1))
	hit.Name = "Hit"
	hit.Selectable = false
	hit.ZIndex = 1

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromOffset(1, 1)
	content.ZIndex = 2
	content.Parent = root
	local zoomScale = Instance.new("UIScale")
	zoomScale.Parent = content

	local detail = Instance.new("Frame")
	detail.Name = "Detail"
	detail.BackgroundTransparency = 1
	detail.AnchorPoint = Vector2.new(0.5, 1)
	detail.Position = UDim2.new(0.5, 0, 1, -14)
	detail.Size = UDim2.new(1, -24, 0, 112)
	detail.ZIndex = 8
	detail.Visible = false
	detail.Parent = root
	local detailSize = Instance.new("UISizeConstraint")
	detailSize.MaxSize = Vector2.new(560, 112)
	detailSize.Parent = detail
	local _, dface =
		Style.block(detail, Style.grad("body"), { shadow = true, radius = S.corner + 2 })
	local dIcon = Instance.new("Frame")
	dIcon.Name = "Icon"
	dIcon.BackgroundColor3 = Color3.new(1, 1, 1)
	dIcon.BackgroundTransparency = 0.4
	dIcon.AnchorPoint = Vector2.new(0, 0.5)
	dIcon.Position = UDim2.new(0, 12, 0.5, 0)
	dIcon.Size = UDim2.fromOffset(72, 72)
	Style.corner(dIcon, S.cornerSmall)
	dIcon.Parent = dface
	local dArt = Instance.new("Frame")
	dArt.BackgroundTransparency = 1
	dArt.Position = UDim2.fromScale(0.14, 0.14)
	dArt.Size = UDim2.fromScale(0.72, 0.72)
	dArt.Parent = dIcon
	local dName = Style.label(dface, "", Theme.Text.heading, true)
	dName.TextXAlignment = Enum.TextXAlignment.Left
	dName.TextWrapped = false
	dName.TextScaled = true
	dName.Position = UDim2.fromOffset(96, 8)
	dName.Size = UDim2.new(1, -300, 0, 34)
	local nameCap = Instance.new("UITextSizeConstraint")
	nameCap.MaxTextSize = Theme.Text.heading
	nameCap.MinTextSize = 16
	nameCap.Parent = dName
	local dEffect = Style.label(dface, "", Theme.Text.small + 2, true)
	dEffect.TextXAlignment = Enum.TextXAlignment.Left
	dEffect.TextWrapped = false
	dEffect.Position = UDim2.fromOffset(96, 42)
	dEffect.Size = UDim2.new(1, -300, 0, 28)
	local dNeeds = Style.label(dface, "", Theme.Text.small, true)
	dNeeds.TextXAlignment = Enum.TextXAlignment.Left
	dNeeds.TextWrapped = false
	dNeeds.TextScaled = true
	dNeeds.TextColor3 = Theme.Grad.red.bottom
	dNeeds.Position = UDim2.fromOffset(96, 72)
	dNeeds.Size = UDim2.new(1, -300, 0, 26)
	local needsCap = Instance.new("UITextSizeConstraint")
	needsCap.MaxTextSize = Theme.Text.small
	needsCap.MinTextSize = 12
	needsCap.Parent = dNeeds
	local dPrice = PriceButton.new(dface, {
		price = 0,
		currency = "Cash",
		state = "disabled",
		onActivate = function()
			local id = selectedId
			if id and props.onBuy then
				props.onBuy(id)
			end
		end,
	})
	dPrice.root.AnchorPoint = Vector2.new(1, 0.5)
	dPrice.root.Position = UDim2.new(1, -12, 0.5, 0)
	dPrice.root.Selectable = false

	local layout = TreeMath.layout({})
	local nodesById: { [string]: Node } = {}
	local boxes: { [string]: TreeMath.Box } = {}
	local buttons: { [string]: ImageButton } = {}
	local order: { string } = {}
	local points: { TreeMath.Point } = {}
	local pulses: { UIStroke } = {}
	local cash = props.cash
	local fitted = false
	local alive = true
	local zoom = 1
	local pan = Vector2.zero
	local suppressUntil = 0
	local stickAt = 0
	local pinchStart: number? = nil

	local function onScreen(): boolean
		if not alive then
			return false
		end
		local p: Instance? = root
		while p and p ~= game do
			if p:IsA("GuiObject") and not p.Visible then
				return false
			end
			p = p.Parent
		end
		return true
	end

	local function kitScale(): number
		local _, k = Style.metrics(root)
		return math.max(k, 0.05)
	end

	local function viewportDu(): Vector2
		return root.AbsoluteSize / kitScale()
	end

	local function apply()
		content.Position = UDim2.fromOffset(pan.X, pan.Y)
		zoomScale.Scale = zoom
	end

	local function centre(box: TreeMath.Box): Vector2
		return box.pos + box.size * 0.5
	end

	local function hideDetail()
		detail.Visible = false
		dPrice.root.Selectable = false
		selectedId = nil
	end

	local function refreshDetail()
		local node = if selectedId then nodesById[selectedId :: string] else nil
		if not node then
			hideDetail()
			return
		end
		local state: State = node.state or "locked"
		for _, c in dArt:GetChildren() do
			if not c:IsA("UICorner") then
				c:Destroy()
			end
		end
		Style.icon(dArt, node.icon)
		dName.Text = node.name
		dEffect.Text = node.effect or ""
		local missing: { string } = {}
		for _, need in node.needs do
			if nodesById[need] then
				table.insert(missing, (nodesById[need] :: Node).name)
			end
		end
		dNeeds.Visible = state == "locked" and #missing > 0
		dNeeds.Text = `Needs: {table.concat(missing, ", ")}`
		dPrice.setPrice(node.price)
		local affordable = cash == nil or cash >= node.price
		local canBuy = props.onBuy ~= nil
		dPrice.setState(
			if state == "owned"
				then "owned"
				elseif
					state == "locked"
					or state == "busy"
					or not affordable
					or not canBuy
				then "disabled"
				else "buy"
		)
		dPrice.root.Selectable = state == "buyable" and affordable and canBuy
		detail.Visible = true
	end

	local choose: (string, boolean) -> ()

	local function buildCard(node: Node, box: TreeMath.Box)
		local state: State = node.state or "locked"
		local card = Style.button(content, UDim2.fromOffset(box.size.X, box.size.Y))
		card.Name = "Node_" .. node.id
		card.Position = UDim2.fromOffset(box.pos.X, box.pos.Y)
		card.ZIndex = 3
		card:SetAttribute("TreeNodeId", node.id)
		buttons[node.id] = card

		local glow = Instance.new("Frame")
		glow.Name = "Glow"
		glow.BackgroundTransparency = 1
		glow.AnchorPoint = Vector2.new(0, 0)
		glow.Position = UDim2.fromOffset(-5, -5)
		glow.Size = UDim2.new(1, 10, 1, 10)
		Style.corner(glow, S.corner + 6)
		glow.Parent = card
		local halo = Style.stroke(glow, 7, true)
		halo.Color = GREEN
		halo.Transparency = 1

		local _, face = Style.block(card, Style.grad(GRAD[state]), { radius = S.corner + 2 })
		if state == "owned" then
			local rim = face:FindFirstChildOfClass("UIStroke")
			if rim then
				rim.Color = GOLD
				rim.Thickness = 5
			end
		end

		local well = Instance.new("Frame")
		well.BackgroundColor3 = Color3.new(1, 1, 1)
		well.BackgroundTransparency = 0.4
		well.Position = UDim2.fromOffset(9, 9)
		well.Size = UDim2.fromOffset(46, 46)
		Style.corner(well, S.cornerSmall)
		well.Parent = face
		local art = Instance.new("Frame")
		art.BackgroundTransparency = 1
		art.Position = UDim2.fromScale(0.12, 0.12)
		art.Size = UDim2.fromScale(0.76, 0.76)
		art.Parent = well
		Style.icon(art, node.icon)
		if state == "locked" then
			local lock = Instance.new("Frame")
			lock.BackgroundTransparency = 1
			lock.AnchorPoint = Vector2.new(0.5, 0.5)
			lock.Position = UDim2.fromScale(0.5, 0.5)
			lock.Size = UDim2.fromScale(0.66, 0.66)
			lock.Parent = well
			Style.icon(lock, "lock")
		end

		local name = Style.label(face, node.name, Theme.Text.small + 2)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextWrapped = true
		name.TextScaled = true
		name.Position = UDim2.fromOffset(61, 6)
		name.Size = UDim2.new(1, -70, 0, 38)
		local cap = Instance.new("UITextSizeConstraint")
		cap.MaxTextSize = Theme.Text.small + 2
		cap.MinTextSize = 11
		cap.Parent = name

		local row = Instance.new("Frame")
		row.Name = "Price"
		row.BackgroundTransparency = 1
		row.Position = UDim2.fromOffset(9, 58)
		row.Size = UDim2.new(1, -18, 0, 28)
		row.Parent = face
		if state == "owned" then
			local tick = Instance.new("Frame")
			tick.BackgroundColor3 = GOLD
			tick.Position = UDim2.fromOffset(0, 1)
			tick.Size = UDim2.fromOffset(26, 26)
			Style.corner(tick, 99)
			Style.stroke(tick, 2.5, true)
			tick.Parent = row
			local mark = Instance.new("Frame")
			mark.BackgroundTransparency = 1
			mark.AnchorPoint = Vector2.new(0.5, 0.5)
			mark.Position = UDim2.fromScale(0.5, 0.52)
			mark.Size = UDim2.fromScale(0.64, 0.64)
			mark.Parent = tick
			Glyph.draw("check", mark, Color3.new(1, 1, 1))
		elseif state == "busy" then
			local hour = Instance.new("Frame")
			hour.BackgroundTransparency = 1
			hour.Position = UDim2.fromOffset(0, 1)
			hour.Size = UDim2.fromOffset(26, 26)
			hour.Parent = row
			hourglass(hour)
		else
			local coin = Instance.new("Frame")
			coin.BackgroundTransparency = 1
			coin.Position = UDim2.fromOffset(0, 2)
			coin.Size = UDim2.fromOffset(24, 24)
			coin.Parent = row
			Style.icon(coin, "cash")
			local price = Style.label(row, Theme.short(node.price), Theme.Text.small)
			price.TextXAlignment = Enum.TextXAlignment.Left
			price.TextWrapped = false
			price.Position = UDim2.fromOffset(28, 0)
			price.Size = UDim2.new(1, -28, 1, 0)
		end

		local affordable = cash == nil or cash >= (node.price or 0)
		if state == "buyable" then
			halo.Transparency = if affordable then 0.45 else 0.75
			if affordable then
				table.insert(pulses, halo)
			end
		end

		card.SelectionGained:Connect(function()
			selectedId = node.id
		end)
		Style.press(card, function()
			if os.clock() >= suppressUntil then
				choose(node.id, true)
			end
		end, S.corner + 2)
	end

	choose = function(id: string, open: boolean)
		local node = nodesById[id]
		if not node then
			return
		end
		selectedId = id
		refreshDetail()
		if open then
			if UserInputService.GamepadEnabled and dPrice.root.Selectable then
				GuiService.SelectedObject = dPrice.root
			elseif buttons[id] then
				GuiService.SelectedObject = buttons[id]
			end
		elseif buttons[id] then
			GuiService.SelectedObject = buttons[id]
		end
		if props.onSelect then
			props.onSelect(id)
		end
	end

	local function build(sorted: { Node })
		local placed: { TreeMath.Node } = {}
		for _, n in sorted do
			table.insert(placed, { id = n.id, col = n.col, row = n.row, group = n.group })
		end
		layout = TreeMath.layout(placed)
		content.Size = UDim2.fromOffset(layout.size.X, layout.size.Y)
		for _, c in content:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		nodesById = {}
		boxes = {}
		buttons = {}
		order = {}
		points = {}
		pulses = {}

		local groupOf: { [string]: Group } = {}
		local groups: { Group } = props.groups or {}
		for _, g in groups do
			groupOf[g.id] = g
		end

		for _, node in sorted do
			nodesById[node.id] = node
		end
		for _, lane in layout.lanes do
			for _, box in lane.nodes do
				boxes[box.id] = box
			end
			table.insert(order, lane.id)
		end

		for _, node in sorted do
			local state: State = node.state or "locked"
			for _, need in node.needs do
				local a, b = boxes[need], boxes[node.id]
				if a and b then
					local line = TreeMath.connector(centre(a), centre(b))
					local bar = Instance.new("Frame")
					bar.Name = `Link_{need}_{node.id}`
					bar.AnchorPoint = Vector2.new(0.5, 0.5)
					bar.Position = UDim2.fromOffset(line.pos.X, line.pos.Y)
					bar.Size = UDim2.fromOffset(line.size.X, line.size.Y)
					bar.Rotation = line.rotation
					bar.BackgroundColor3 = LINK[state]
					bar.BackgroundTransparency = 0.05
					bar.BorderSizePixel = 0
					Style.corner(bar, 99)
					bar.ZIndex = 1
					bar.Parent = content
				end
			end
		end

		for _, lane in layout.lanes do
			local g = groupOf[lane.id]
			local head = Instance.new("Frame")
			head.Name = `Lane_{lane.id}`
			head.BackgroundTransparency = 1
			head.Position = UDim2.fromOffset(TreeMath.PAD, lane.y)
			head.Size = UDim2.fromOffset(layout.size.X - TreeMath.PAD * 2, TreeMath.HEADER)
			head.ZIndex = 2
			head.Parent = content
			local _, face = Style.block(
				head,
				Style.grad(if g and g.color then g.color else "blue"),
				{ lip = 4 }
			)
			local icon = Instance.new("Frame")
			icon.BackgroundTransparency = 1
			icon.AnchorPoint = Vector2.new(0, 0.5)
			icon.Position = UDim2.new(0, 8, 0.5, 0)
			icon.Size = UDim2.fromOffset(34, 34)
			icon.Parent = face
			Style.icon(icon, if g and g.icon then g.icon else "boost")
			local label = Style.label(face, if g then g.name else lane.id, Theme.Text.heading)
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextWrapped = false
			label.Position = UDim2.fromOffset(50, 0)
			label.Size = UDim2.new(1, -60, 1, 0)
		end

		for _, node in sorted do
			local box = boxes[node.id]
			if box then
				buildCard(node, box)
				table.insert(points, { id = node.id, pos = centre(box) })
			end
		end

		if selectedId and not nodesById[selectedId :: string] then
			hideDetail()
		else
			refreshDetail()
			if selectedId and UserInputService.GamepadEnabled then
				GuiService.SelectedObject = buttons[selectedId :: string]
			end
		end
	end

	local function sortedNodes(nodes: { Node }): { Node }
		local rank: { [string]: number } = {}
		local groups: { Group } = props.groups or {}
		for i, g in groups do
			rank[g.id] = i
		end
		local out = table.clone(nodes)
		local at: { [string]: number } = {}
		for i, n in out do
			at[n.id] = i
		end
		table.sort(out, function(a: Node, b: Node): boolean
			local ga, gb = rank[a.group or ""] or math.huge, rank[b.group or ""] or math.huge
			if ga ~= gb then
				return ga < gb
			end
			return at[a.id] < at[b.id] -- input order inside a lane
		end)
		return out
	end

	local function fit()
		local vp = viewportDu()
		if vp.X < 4 or vp.Y < 4 or layout.size.X < 4 or #points == 0 then
			return
		end
		zoom =
			math.clamp(math.min((vp.X - 24) / layout.size.X, (vp.Y - 24) / layout.size.Y), 0.7, 1)
		-- lanes read top down: start at the first branch, centred across
		local shown = layout.size * zoom
		pan = TreeMath.clampPan(Vector2.new((vp.X - shown.X) * 0.5, 0), vp, layout.size, zoom)
		fitted = true
		apply()
	end

	local function setNodes(nodes: { Node }, value: number?)
		cash = if value ~= nil then value else cash
		local keep = selectedId
		build(sortedNodes(nodes))
		selectedId = if keep and nodesById[keep] then keep else nil
		refreshDetail()
		if not fitted then
			fit()
		else
			local vp = viewportDu()
			pan = TreeMath.clampPan(pan, vp, layout.size, zoom)
			apply()
		end
	end

	build(sortedNodes(props.nodes))
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if not fitted then
			fit()
		else
			local vp = viewportDu()
			pan = TreeMath.clampPan(pan, vp, layout.size, zoom)
			apply()
		end
	end)

	-- pulse the green halo of affordable nodes (a soft glow, never a flash)
	task.spawn(function()
		local t = 0
		while root.Parent do
			if onScreen() and #pulses > 0 then
				t += 0.05
				local a = 0.45 + 0.32 * (0.5 + 0.5 * math.sin(t * 4))
				for _, s in pulses do
					s.Transparency = a
				end
			end
			task.wait(0.05)
		end
	end)

	-- drag to pan (mouse + touch); an empty tap closes the detail card
	local drag: { start: Vector2, pan: Vector2, moved: boolean, input: InputObject }? = nil
	hit.InputBegan:Connect(function(input: InputObject)
		local t = input.UserInputType
		if
			(t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch)
			and drag == nil
		then
			drag = {
				start = Vector2.new(input.Position.X, input.Position.Y),
				pan = pan,
				moved = false,
				input = input,
			}
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if not onScreen() then
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
			end
			if d.moved then
				pan = d.pan + delta / kitScale()
				local vp = viewportDu()
				pan = TreeMath.clampPan(pan, vp, layout.size, zoom)
				apply()
			end
		elseif t == Enum.UserInputType.MouseWheel then
			local vp = viewportDu()
			local before = zoom
			zoom =
				math.clamp(zoom * (1.12 ^ input.Position.Z), TreeMath.MIN_ZOOM, TreeMath.MAX_ZOOM)
			pan = TreeMath.zoomAbout(pan, vp * 0.5, before, zoom)
			pan = TreeMath.clampPan(pan, vp, layout.size, zoom)
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
		if os.clock() >= suppressUntil then
			hideDetail()
		end
	end)
	UserInputService.TouchPinch:Connect(function(_, scale: number, _, state: Enum.UserInputState)
		if not onScreen() then
			return
		end
		if state == Enum.UserInputState.Begin then
			pinchStart = zoom
			drag = nil
		elseif state == Enum.UserInputState.Change and pinchStart then
			local vp = viewportDu()
			local before = zoom
			zoom =
				math.clamp(pinchStart * math.max(scale, 0.05), TreeMath.MIN_ZOOM, TreeMath.MAX_ZOOM)
			pan = TreeMath.zoomAbout(pan, vp * 0.5, before, zoom)
			pan = TreeMath.clampPan(pan, vp, layout.size, zoom)
			apply()
		else
			pinchStart = nil
		end
	end)

	local DIRS: { [Enum.KeyCode]: Vector2 } = {
		[Enum.KeyCode.DPadUp] = Vector2.new(0, -1),
		[Enum.KeyCode.DPadDown] = Vector2.new(0, 1),
		[Enum.KeyCode.DPadLeft] = Vector2.new(-1, 0),
		[Enum.KeyCode.DPadRight] = Vector2.new(1, 0),
	}

	local function move(dir: Vector2)
		local from: Vector2
		if selectedId and boxes[selectedId :: string] then
			from = centre(boxes[selectedId :: string])
		else
			local vp = viewportDu()
			from = (vp * 0.5 - pan) / zoom
		end
		local id = TreeMath.nearest(points, from, dir)
		if not id then
			return
		end
		choose(id, false)
		local box = boxes[id]
		if box then
			local vp = viewportDu()
			local at = pan + centre(box) * zoom
			local nx, ny = pan.X, pan.Y
			if at.X < 40 then
				nx = 40 - centre(box).X * zoom
			elseif at.X > vp.X - 40 then
				nx = vp.X - 40 - centre(box).X * zoom
			end
			local low = if detail.Visible then 40 + detail.Size.Y.Offset else 40
			if at.Y < 40 then
				ny = 40 - centre(box).Y * zoom
			elseif at.Y > vp.Y - low then
				ny = vp.Y - low - centre(box).Y * zoom
			end
			pan = TreeMath.clampPan(Vector2.new(nx, ny), vp, layout.size, zoom)
			apply()
		end
	end

	ContextActionService:BindActionAtPriority(
		action,
		function(_, state, input)
			if not onScreen() then
				return Enum.ContextActionResult.Pass
			end
			if input.KeyCode == Enum.KeyCode.Thumbstick1 then
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
			if input.KeyCode == Enum.KeyCode.ButtonA then
				local sel = GuiService.SelectedObject
				if
					state == Enum.UserInputState.Begin
					and not (sel and sel:IsDescendantOf(root))
					and order[1]
				then
					choose(order[1], true)
					return Enum.ContextActionResult.Sink
				end
				return Enum.ContextActionResult.Pass
			end
			local dir = DIRS[input.KeyCode]
			if dir and state == Enum.UserInputState.Begin then
				move(dir)
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end,
		false,
		Enum.ContextActionPriority.High.Value + 20,
		Enum.KeyCode.DPadUp,
		Enum.KeyCode.DPadDown,
		Enum.KeyCode.DPadLeft,
		Enum.KeyCode.DPadRight,
		Enum.KeyCode.ButtonA,
		Enum.KeyCode.Thumbstick1
	)
	root.Destroying:Connect(function()
		alive = false
		ContextActionService:UnbindAction(action)
	end)

	return {
		root = root,
		setNodes = setNodes,
		select = function(id: string)
			choose(id, false)
		end,
		selected = function()
			return selectedId
		end,
	}
end

return TreeView
