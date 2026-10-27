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
-- One extra detail-card button (the build tablet's Finish now): a price, or just a 1-3 word text.
export type Action = {
	price: number?,
	currency: ("Robux" | "Cash")?,
	text: string?,
	icon: string?,
	visible: boolean?,
	enabled: boolean?,
	onActivate: () -> (),
}
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
	note: string?, -- text in the price row instead of the price (a busy site's timer)
	robux: number?, -- second price button on the detail card
	need: string?, -- the prerequisite the Needs line selects
	pulse: boolean?, -- tutorial pointer ring
	action: Action?,
}
export type Group = { id: string, name: string, icon: string?, color: string? }
export type Props = {
	nodes: { Node },
	groups: { Group }?,
	cash: number?,
	header: boolean?, -- group lane headers (default true; off for a single nameless lane)
	renderIcon: ((Instance, string) -> ())?, -- draw node art yourself (icon is the fallback)
	onSelect: ((string) -> ())?,
	onBuy: ((string) -> ())?,
	onBuyRobux: ((string) -> ())?,
}
export type TreeView = {
	root: Frame,
	setNodes: (nodes: { Node }, cash: number?) -> (),
	select: (id: string?) -> (),
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

	local nodesById: { [string]: Node } = {}
	local choose: (string, boolean) -> ()

	-- The detail card is compact and docked to the free side of the band (right on landscape, top on
	-- portrait), so the tree keeps a free rect of its own and the card never covers the selected node.
	local DETAIL_PAD = 12
	local DETAIL_TOP = 92 -- icon + name / effect / needs, above the price row
	local detail = Instance.new("Frame")
	detail.Name = "Detail"
	detail.BackgroundTransparency = 1
	detail.Size = UDim2.fromOffset(360, 120)
	detail.ZIndex = 8
	detail.Visible = false
	detail.Parent = root
	local _, dface =
		Style.block(detail, Style.grad("body"), { shadow = true, radius = S.corner + 2 })
	local dIcon = Instance.new("Frame")
	dIcon.Name = "Icon"
	dIcon.BackgroundColor3 = Color3.new(1, 1, 1)
	dIcon.BackgroundTransparency = 0.4
	dIcon.Position = UDim2.fromOffset(12, 10)
	dIcon.Size = UDim2.fromOffset(56, 56)
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
	dName.Position = UDim2.fromOffset(76, 4)
	dName.Size = UDim2.new(1, -88, 0, 34)
	local nameCap = Instance.new("UITextSizeConstraint")
	nameCap.MaxTextSize = Theme.Text.heading
	nameCap.MinTextSize = 14
	nameCap.Parent = dName
	local dEffect = Style.label(dface, "", Theme.Text.small + 2, true)
	dEffect.TextXAlignment = Enum.TextXAlignment.Left
	dEffect.TextWrapped = false
	dEffect.TextScaled = true
	dEffect.Position = UDim2.fromOffset(76, 39)
	dEffect.Size = UDim2.new(1, -88, 0, 24)
	local effectCap = Instance.new("UITextSizeConstraint")
	effectCap.MaxTextSize = Theme.Text.small + 2
	effectCap.MinTextSize = 12
	effectCap.Parent = dEffect
	local dNeedsButton = Style.button(dface, UDim2.new(1, -88, 0, 24))
	dNeedsButton.Name = "Needs"
	dNeedsButton.Position = UDim2.fromOffset(76, 64)
	local dNeeds = Style.label(dNeedsButton, "", Theme.Text.small, true)
	dNeeds.TextXAlignment = Enum.TextXAlignment.Left
	dNeeds.TextWrapped = false
	dNeeds.TextScaled = true
	dNeeds.TextColor3 = Theme.Grad.red.bottom
	local needsCap = Instance.new("UITextSizeConstraint")
	needsCap.MaxTextSize = Theme.Text.small
	needsCap.MinTextSize = 12
	needsCap.Parent = dNeeds
	Style.press(dNeedsButton, function()
		local node = if selectedId then nodesById[selectedId :: string] else nil
		if node and node.need and nodesById[node.need] then
			choose(node.need, false)
		end
	end, S.cornerSmall)
	-- a price button needs 184 du; on a narrow card the slot scales it down (still a big touch target)
	local function buttonSlot(): (Frame, UIScale)
		local holder = Instance.new("Frame")
		holder.Name = "Slot"
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromOffset(S.price.X, S.price.Y)
		holder.Visible = false
		holder.Parent = dface
		local sc = Instance.new("UIScale")
		sc.Parent = holder
		return holder, sc
	end
	local dPriceSlot, dPriceScale = buttonSlot()
	local dPrice = PriceButton.new(dPriceSlot, {
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
	dPrice.root.Visible = false
	dPrice.root.Selectable = false
	local dRobuxSlot, dRobuxScale = buttonSlot()
	local dRobux = PriceButton.new(dRobuxSlot, {
		price = 0,
		currency = "Robux",
		state = "buy",
		onActivate = function()
			local id = selectedId
			if id and props.onBuyRobux then
				props.onBuyRobux(id)
			end
		end,
	})
	dRobux.root.Visible = false
	dRobux.root.Selectable = false
	local dActionSlot, dActionScale = buttonSlot()
	local dAction = PriceButton.new(dActionSlot, {
		price = 0,
		currency = "Robux",
		state = "disabled",
		onActivate = function()
			local node = if selectedId then nodesById[selectedId :: string] else nil
			if node and node.action then
				node.action.onActivate()
			end
		end,
	})
	dAction.root.Visible = false
	dAction.root.Selectable = false
	local actionIcon = Instance.new("Frame")
	actionIcon.Name = "ActionIcon"
	actionIcon.BackgroundTransparency = 1
	actionIcon.Position = UDim2.fromOffset(5, 3)
	actionIcon.Size = UDim2.fromOffset(22, 22)
	actionIcon.ZIndex = 3
	actionIcon.Parent = dAction.root

	local layout = TreeMath.layout({})
	local boxes: { [string]: TreeMath.Box } = {}
	local buttons: { [string]: ImageButton } = {}
	local order: { string } = {}
	local points: { TreeMath.Point } = {}
	local pulses: { UIStroke } = {}
	local noteLabels: { [string]: TextLabel } = {}
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

	-- The free tree rect: the detail card reserves the right column on landscape, the top strip on
	-- portrait. Ten du of breathing room beside the card.
	local function viewRect(): TreeMath.View
		local vp = viewportDu()
		local right, top = 0, 0
		if detail.Visible then
			if vp.X >= vp.Y then
				right = detail.Size.X.Offset + 20
			else
				top = detail.Size.Y.Offset + 20
			end
		end
		return {
			pos = Vector2.new(0, top),
			size = Vector2.new(math.max(vp.X - right, 4), math.max(vp.Y - top, 4)),
		}
	end

	local function clampView()
		pan = TreeMath.clampPanIn(pan, viewRect(), layout.size, zoom)
		apply()
	end

	local function hideDetail()
		detail.Visible = false
		dPrice.root.Selectable = false
		dRobux.root.Selectable = false
		dAction.root.Selectable = false
		selectedId = nil
		clampView()
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
		if props.renderIcon then
			props.renderIcon(dArt, node.id)
		else
			Style.icon(dArt, node.icon)
		end
		dName.Text = node.name
		dEffect.Text = node.effect or ""
		local missing: { string } = {}
		for _, need in node.needs do
			if nodesById[need] then
				table.insert(missing, (nodesById[need] :: Node).name)
			end
		end
		local needNode = if node.need then nodesById[node.need] else nil
		dNeedsButton.Visible = state == "locked" and #missing > 0
		dNeeds.Text = if needNode
			then `Needs: {needNode.name}`
			else `Needs: {table.concat(missing, ", ")}`
		dNeedsButton.Selectable = needNode ~= nil

		-- buy buttons in a row under the words; busy hides them all (the site's card offers Finish now)
		local list: { { button: PriceButton.PriceButton, slot: Frame, scale: UIScale } } = {}
		local showAction = node.action ~= nil and node.action.visible ~= false
		if showAction then
			table.insert(list, { button = dAction, slot = dActionSlot, scale = dActionScale })
		end
		local showRobux = node.robux ~= nil and props.onBuyRobux ~= nil and state == "buyable"
		if showRobux then
			table.insert(list, { button = dRobux, slot = dRobuxSlot, scale = dRobuxScale })
		end
		local showCash = state ~= "busy" and node.price > 0 -- price 0: not sold (a quest reward)
		if showCash then
			table.insert(list, { button = dPrice, slot = dPriceSlot, scale = dPriceScale })
		end
		dPrice.root.Visible = false
		dRobux.root.Visible = false
		dAction.root.Visible = false
		dPriceSlot.Visible = false
		dRobuxSlot.Visible = false
		dActionSlot.Visible = false
		-- compact card: a du width that scales with the screen, docked right on landscape and on top
		-- on portrait. Buttons share the bottom row; a narrow slot shrinks the whole button.
		local vp = viewportDu()
		local portrait = vp.Y > vp.X
		local cardW = if portrait
			then math.min(vp.X - 32, 760)
			else math.clamp(vp.X * 0.34, 360, 460)
		local gap = 8
		local slotW = if #list > 0 then (cardW - 2 * DETAIL_PAD - (#list - 1) * gap) / #list else 0
		local k = math.clamp(slotW / S.price.X, 0.1, 1)
		if #list > 0 then
			-- a short band (a phone on its side) shrinks the row too, so the card never overflows it
			k = math.min(k, math.max((vp.Y - 12 - DETAIL_TOP - DETAIL_PAD) / S.price.Y, 0.1))
		end
		local height = DETAIL_TOP + (if #list > 0 then S.price.Y * k + DETAIL_PAD else 0)
		for i, entry in list do
			entry.button.root.Visible = true
			entry.slot.Visible = true
			entry.scale.Scale = k
			local w = S.price.X * k
			entry.slot.Position = UDim2.fromOffset(
				math.floor(DETAIL_PAD + (i - 1) * (slotW + gap) + (slotW - w) * 0.5),
				DETAIL_TOP
			)
		end
		if portrait then
			detail.AnchorPoint = Vector2.new(0.5, 0)
			detail.Position = UDim2.new(0.5, 0, 0, 10)
		else
			detail.AnchorPoint = Vector2.new(1, 0.5)
			detail.Position = UDim2.new(1, -10, 0.5, 0)
		end
		detail.Size = UDim2.fromOffset(cardW, height)

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
		dPrice.root.Selectable = showCash and state == "buyable" and affordable and canBuy

		if showRobux then
			dRobux.setPrice(node.robux :: number)
			dRobux.setState("buy")
		end
		dRobux.root.Selectable = showRobux

		local act = node.action
		if showAction and act then
			dAction.setPrice(act.price or 0)
			dAction.setText(if act.price == nil then act.text else nil)
			dAction.setState(if act.enabled == false then "disabled" else "buy")
			for _, c in actionIcon:GetChildren() do
				c:Destroy()
			end
			if act.icon then
				Style.icon(actionIcon, act.icon)
			end
		end
		dAction.root.Selectable = showAction and act ~= nil and act.enabled ~= false
		detail.Visible = true
		clampView()
	end

	-- Bring a node fully into the free rect (the card may have just made it narrower).
	local function reveal(id: string)
		local box = boxes[id]
		if not box then
			return
		end
		local view = viewRect()
		local at = pan + centre(box) * zoom
		local nx, ny = pan.X, pan.Y
		-- keep the whole node card inside the free rect, not only its centre
		local mx = math.min(box.size.X * 0.5 * zoom + 8, view.size.X * 0.45)
		local my = math.min(box.size.Y * 0.5 * zoom + 8, view.size.Y * 0.45)
		if at.X < view.pos.X + mx then
			nx = view.pos.X + mx - centre(box).X * zoom
		elseif at.X > view.pos.X + view.size.X - mx then
			nx = view.pos.X + view.size.X - mx - centre(box).X * zoom
		end
		if at.Y < view.pos.Y + my then
			ny = view.pos.Y + my - centre(box).Y * zoom
		elseif at.Y > view.pos.Y + view.size.Y - my then
			ny = view.pos.Y + view.size.Y - my - centre(box).Y * zoom
		end
		pan = TreeMath.clampPanIn(Vector2.new(nx, ny), view, layout.size, zoom)
		apply()
	end

	-- drag to pan (mouse + touch) starts on the empty canvas and on a node alike; a drag never
	-- activates the node it started on (suppressUntil)
	local drag: { start: Vector2, pan: Vector2, moved: boolean, input: InputObject }? = nil
	local function beginDrag(input: InputObject)
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
	end

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
		if props.renderIcon then
			props.renderIcon(art, node.id)
		else
			Style.icon(art, node.icon)
		end
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
		cap.MinTextSize = 12
		cap.Parent = name

		local row = Instance.new("Frame")
		row.Name = "Price"
		row.BackgroundTransparency = 1
		row.Position = UDim2.fromOffset(9, 58)
		row.Size = UDim2.new(1, -18, 0, 28)
		row.Parent = face
		if node.note then
			local note = Style.label(row, node.note, Theme.Text.small)
			noteLabels[node.id] = note
			note.TextXAlignment = Enum.TextXAlignment.Left
			note.TextWrapped = false
			note.Position = UDim2.fromOffset(4, 0)
			note.Size = UDim2.new(1, -4, 1, 0)
		elseif state == "owned" then
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
		if node.pulse then
			halo.Color = GOLD
			halo.Transparency = 0.1 -- steady: the tutorial pointer never blinks (owner, 2026-10-28)
		elseif state == "buyable" then
			halo.Transparency = if affordable then 0.45 else 0.75
			if affordable then
				table.insert(pulses, halo)
			end
		end

		card.InputBegan:Connect(beginDrag)
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
		reveal(id)
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
		layout = TreeMath.layout(placed, if props.header == false then { header = 0 } else nil)
		content.Size = UDim2.fromOffset(layout.size.X, layout.size.Y)
		for _, c in content:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		nodesById = {}
		noteLabels = {}
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

		if props.header ~= false then
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
		local view = viewRect()
		if view.size.X < 4 or view.size.Y < 4 or layout.size.X < 4 or #points == 0 then
			return
		end
		zoom = math.clamp(
			math.min((view.size.X - 24) / layout.size.X, (view.size.Y - 24) / layout.size.Y),
			0.7,
			1
		)
		-- lanes read top down: start at the first branch, centred across
		local shown = layout.size * zoom
		pan = TreeMath.clampPanIn(
			Vector2.new(view.pos.X + (view.size.X - shown.X) * 0.5, view.pos.Y),
			view,
			layout.size,
			zoom
		)
		fitted = true
		apply()
	end

	-- true when only the ticking text (note, effect, action) differs from what is drawn
	local function onlyText(nodes: { Node }, value: number?): boolean
		if value ~= cash or #nodes ~= #points then
			return false
		end
		for _, n in nodes do
			local old = nodesById[n.id]
			if not old or (old.note == nil) ~= (n.note == nil) then
				return false
			end
			for k, v in n :: any do
				local was = (old :: any)[k]
				if k == "needs" then
					if table.concat(v, ",") ~= table.concat(was, ",") then
						return false
					end
				elseif k ~= "note" and k ~= "effect" and k ~= "action" and v ~= was then
					return false
				end
			end
			for k in old :: any do
				if (n :: any)[k] == nil and k ~= "note" and k ~= "effect" and k ~= "action" then
					return false
				end
			end
		end
		return true
	end

	local function setNodes(nodes: { Node }, value: number?)
		-- a running site's timer ticks twice a second: retext in place, as a rebuild eats clicks
		if onlyText(nodes, value) then
			for _, n in nodes do
				nodesById[n.id] = n
				local label = noteLabels[n.id]
				if label and n.note then
					label.Text = n.note
				end
			end
			refreshDetail()
			return
		end
		cash = if value ~= nil then value else cash
		local keep = selectedId
		build(sortedNodes(nodes))
		selectedId = if keep and nodesById[keep] then keep else nil
		refreshDetail()
		if not fitted then
			fit()
		else
			clampView()
		end
	end

	build(sortedNodes(props.nodes))
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if selectedId then
			refreshDetail() -- redock the card (a resize can change the orientation)
		end
		if not fitted then
			fit()
		else
			clampView()
		end
	end)

	-- pulse the green halo of affordable nodes (a soft glow, never a flash)
	task.spawn(function()
		local t = 0
		while root.Parent do
			if onScreen() then
				t += 0.05
				local wave = 0.5 + 0.5 * math.sin(t * 4)
				for _, s in pulses do
					s.Transparency = 0.45 + 0.32 * wave
				end
			end
			task.wait(0.05)
		end
	end)

	-- an empty tap closes the detail card
	hit.InputBegan:Connect(beginDrag)
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
				suppressUntil = os.clock() + 0.25
			end
			if d.moved then
				pan = d.pan + delta / kitScale()
				pan = TreeMath.clampPanIn(pan, viewRect(), layout.size, zoom)
				apply()
			end
		elseif t == Enum.UserInputType.MouseWheel then
			local view = viewRect()
			local before = zoom
			zoom =
				math.clamp(zoom * (1.12 ^ input.Position.Z), TreeMath.MIN_ZOOM, TreeMath.MAX_ZOOM)
			pan = TreeMath.zoomAbout(pan, view.pos + view.size * 0.5, before, zoom)
			pan = TreeMath.clampPanIn(pan, view, layout.size, zoom)
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
			local view = viewRect()
			local before = zoom
			zoom =
				math.clamp(pinchStart * math.max(scale, 0.05), TreeMath.MIN_ZOOM, TreeMath.MAX_ZOOM)
			pan = TreeMath.zoomAbout(pan, view.pos + view.size * 0.5, before, zoom)
			pan = TreeMath.clampPanIn(pan, view, layout.size, zoom)
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
		local view = viewRect()
		local from: Vector2
		if selectedId and boxes[selectedId :: string] then
			from = centre(boxes[selectedId :: string])
		else
			from = (view.pos + view.size * 0.5 - pan) / zoom
		end
		local id = TreeMath.nearest(points, from, dir)
		if not id then
			return
		end
		choose(id, false)
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
		select = function(id: string?)
			if id then
				choose(id, false)
			else
				hideDetail()
			end
		end,
		selected = function()
			return selectedId
		end,
	}
end

return TreeView
