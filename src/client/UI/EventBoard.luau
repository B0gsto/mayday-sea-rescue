--!strict
-- EventBoard: the one "what's coming" list (docs/15 section 2) drawn as cards: a drawn icon,
-- a 1-3 word label and the numbers from EventCalendar, on the phone's Events page. No interaction, no
-- prices: the board only shows when the free content lands (fair FOMO, docs/15 section 1).
--
-- update(rows) is called at most once a second; the now rows pulse on that beat, so no tweens or
-- per-frame work run.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EventCalendar = require(Shared:WaitForChild("EventCalendar"))
local HudTheme = require(script.Parent:WaitForChild("HudTheme"))
local C = HudTheme.Colors

local INK = Color3.fromRGB(238, 240, 236)
local DIM = Color3.fromRGB(158, 174, 182)
local GOLD = Color3.fromRGB(232, 198, 128)
local HOT = Color3.fromRGB(255, 142, 86)
local READY = Color3.fromRGB(111, 191, 142)

export type Board = {
	root: Frame,
	update: (rows: { EventCalendar.Row }) -> (),
}

local ROWS: { { id: string, icon: EventCalendar.Icon } } = {
	{ id = "GreatStorm", icon = "storm" },
	{ id = "LiveOps", icon = "spark" },
	{ id = "GhostLight", icon = "lantern" },
	{ id = "Halloween", icon = "pumpkin" },
	{ id = "Season", icon = "book" },
	{ id = "Restock", icon = "bell" },
	{ id = "Crate", icon = "crate" },
	{ id = "Strongbox", icon = "strongbox" },
}

local EventBoard = {}

local function box(
	parent: Instance,
	color: Color3,
	x: number,
	y: number,
	w: number,
	h: number,
	r: number?
): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	if r then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, r)
		c.Parent = f
	end
	f.Parent = parent
	return f
end

local function icon(kind: EventCalendar.Icon, parent: Instance, size: number): Frame
	local f = Instance.new("Frame")
	f.Name = kind
	f.Size = UDim2.fromOffset(size, size)
	f.BackgroundTransparency = 1
	f.Parent = parent

	if kind == "storm" then
		box(f, Color3.fromRGB(150, 168, 178), 0.48, 0.42, 0.7, 0.3, 8)
		box(f, Color3.fromRGB(150, 168, 178), 0.28, 0.36, 0.34, 0.32, 99)
		box(f, Color3.fromRGB(150, 168, 178), 0.48, 0.3, 0.4, 0.38, 99)
		box(f, Color3.fromRGB(174, 190, 198), 0.7, 0.38, 0.3, 0.3, 99)
		local bolt = box(f, GOLD, 0.52, 0.76, 0.12, 0.34, 2)
		bolt.Rotation = -24
	elseif kind == "lantern" then
		box(f, Color3.fromRGB(96, 78, 54), 0.5, 0.2, 0.5, 0.06, 2)
		box(f, Color3.fromRGB(96, 78, 54), 0.5, 0.32, 0.08, 0.24, 2)
		box(f, Color3.fromRGB(96, 78, 54), 0.5, 0.44, 0.5, 0.09, 3)
		box(f, GOLD, 0.5, 0.64, 0.44, 0.38, 6)
		box(f, Color3.fromRGB(255, 196, 108), 0.5, 0.64, 0.28, 0.24, 4)
		box(f, Color3.fromRGB(96, 78, 54), 0.5, 0.84, 0.5, 0.07, 2)
	elseif kind == "pumpkin" then
		box(f, Color3.fromRGB(226, 126, 48), 0.5, 0.62, 0.58, 0.48, 99)
		box(f, Color3.fromRGB(198, 100, 36), 0.34, 0.62, 0.28, 0.42, 99)
		box(f, Color3.fromRGB(198, 100, 36), 0.66, 0.62, 0.28, 0.42, 99)
		box(f, Color3.fromRGB(108, 146, 74), 0.56, 0.3, 0.1, 0.18, 2)
		box(f, Color3.fromRGB(48, 34, 22), 0.4, 0.58, 0.12, 0.08, 2)
		box(f, Color3.fromRGB(48, 34, 22), 0.6, 0.58, 0.12, 0.08, 2)
		box(f, Color3.fromRGB(255, 196, 108), 0.5, 0.74, 0.26, 0.06, 2)
	elseif kind == "book" then
		box(f, Color3.fromRGB(146, 104, 58), 0.54, 0.5, 0.52, 0.62, 4)
		box(f, GOLD, 0.32, 0.5, 0.1, 0.62, 3)
		box(f, INK, 0.58, 0.38, 0.28, 0.04, 2)
		box(f, INK, 0.58, 0.5, 0.28, 0.04, 2)
		box(f, INK, 0.58, 0.62, 0.2, 0.04, 2)
	elseif kind == "bell" then
		box(f, GOLD, 0.5, 0.3, 0.12, 0.12, 99)
		box(f, GOLD, 0.5, 0.58, 0.56, 0.42, 10)
		box(f, Color3.fromRGB(190, 154, 88), 0.5, 0.78, 0.66, 0.09, 3)
		box(f, GOLD, 0.5, 0.9, 0.14, 0.14, 99)
	elseif kind == "crate" then
		box(f, Color3.fromRGB(160, 118, 70), 0.5, 0.55, 0.62, 0.48, 3)
		box(f, Color3.fromRGB(120, 84, 48), 0.5, 0.53, 0.66, 0.1, 2)
		box(f, Color3.fromRGB(120, 84, 48), 0.5, 0.75, 0.66, 0.08, 2)
		box(f, GOLD, 0.5, 0.36, 0.18, 0.08, 2)
	elseif kind == "spark" then
		box(f, GOLD, 0.5, 0.5, 0.2, 0.78, 99)
		box(f, GOLD, 0.5, 0.5, 0.78, 0.2, 99)
		box(f, Color3.fromRGB(255, 232, 168), 0.5, 0.5, 0.3, 0.3, 99)
	else
		box(f, Color3.fromRGB(140, 100, 58), 0.5, 0.68, 0.64, 0.32, 3)
		box(f, Color3.fromRGB(168, 122, 70), 0.5, 0.46, 0.7, 0.16, 4)
		box(f, GOLD, 0.5, 0.6, 0.12, 0.16, 2)
		box(f, Color3.fromRGB(60, 46, 30), 0.5, 0.77, 0.5, 0.04, 2)
	end
	return f
end

-- The phone's Events page, portrait (268 du wide): full-width rounded cards, a tinted icon chip,
-- the name on top, a big countdown or a Now pill bottom right. Text >= 18 du (a du can be 0.7 px).
local CARD_H = 92
local CHIP = 60
local TINT: { [string]: Color3 } = {
	storm = Color3.fromRGB(52, 74, 96),
	spark = Color3.fromRGB(96, 64, 128),
	lantern = Color3.fromRGB(38, 84, 88),
	pumpkin = Color3.fromRGB(74, 44, 92),
	book = Color3.fromRGB(92, 66, 40),
	bell = Color3.fromRGB(44, 62, 104),
	crate = Color3.fromRGB(52, 86, 58),
	strongbox = Color3.fromRGB(84, 58, 44),
}

function EventBoard.buildPhone(parent: Instance): Board
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "EventList"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = DIM
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Selectable = false
	scroll.Parent = parent

	local root = Instance.new("Frame")
	root.Name = "EventRows"
	root.Size = UDim2.new(1, -8, 0, 0)
	root.AutomaticSize = Enum.AutomaticSize.Y
	root.BackgroundTransparency = 1
	root.Parent = scroll
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = root
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.Parent = root

	type Card = {
		frame: Frame,
		stroke: UIStroke,
		name: TextLabel,
		value: TextLabel,
		sub: TextLabel,
		pill: Frame,
		pillText: TextLabel,
	}
	local cards: { [string]: Card } = {}

	for order, spec in ROWS do
		local card = Instance.new("Frame")
		card.Name = spec.id
		card.LayoutOrder = order
		card.Size = UDim2.new(1, 0, 0, CARD_H)
		card.BackgroundColor3 = C.panelLight
		card.BorderSizePixel = 0
		card.Visible = false
		HudTheme.corner(card, 16)
		local stroke = HudTheme.stroke(card, HOT, 2)
		card.Parent = root

		local chip = box(card, TINT[spec.icon] or C.panel, 0, 0.5, 0, 0, 16)
		chip.AnchorPoint = Vector2.new(0, 0.5)
		chip.Position = UDim2.new(0, 12, 0.5, 0)
		chip.Size = UDim2.fromOffset(CHIP, CHIP)
		local mark = icon(spec.icon, chip, 44)
		mark.AnchorPoint = Vector2.new(0.5, 0.5)
		mark.Position = UDim2.fromScale(0.5, 0.5)

		local left = 12 + CHIP + 12
		local name = HudTheme.label(
			"Name",
			"",
			UDim2.new(1, -(left + 12), 0, 26),
			HudTheme.HeaderFont,
			22,
			card
		)
		name.Position = UDim2.fromOffset(left, 10)

		local sub = HudTheme.label(
			"Sub",
			"",
			UDim2.new(1, -(left + 12), 0, 36),
			HudTheme.BodyFont,
			18,
			card
		)
		sub.AnchorPoint = Vector2.new(0, 1)
		sub.Position = UDim2.new(0, left, 1, -10)
		sub.TextColor3 = C.textDim

		local value = HudTheme.label(
			"Value",
			"",
			UDim2.new(1, -(left + 12), 0, 40),
			Enum.Font.BuilderSansBold,
			30,
			card
		)
		value.AnchorPoint = Vector2.new(1, 1)
		value.Position = UDim2.new(1, -14, 1, -8)
		value.TextXAlignment = Enum.TextXAlignment.Right
		value.TextColor3 = GOLD

		local pill = box(card, HOT, 1, 1, 0, 0, 99)
		pill.AnchorPoint = Vector2.new(1, 1)
		pill.Position = UDim2.new(1, -12, 1, -10)
		pill.Size = UDim2.fromOffset(84, 38)
		local pillText =
			HudTheme.label("Text", "", UDim2.fromScale(1, 1), Enum.Font.BuilderSansBold, 22, pill)
		pillText.TextXAlignment = Enum.TextXAlignment.Center
		pillText.TextColor3 = C.panel

		cards[spec.id] = {
			frame = card,
			stroke = stroke,
			name = name,
			value = value,
			sub = sub,
			pill = pill,
			pillText = pillText,
		}
	end

	local pulse = false

	local function update(rows: { EventCalendar.Row })
		pulse = not pulse
		local seen: { [string]: boolean } = {}
		for order, row in rows do
			local card = cards[row.id]
			if card then
				seen[row.id] = true
				card.frame.Visible = true
				card.frame.LayoutOrder = order
				card.name.Text = row.label
				local main, sub = EventCalendar.text(row)
				local now = row.kind == "now"
				local urgent = row.kind == "clock" and (row.seconds or 0) <= 120
				local full = row.kind == "percent" and (row.fraction or 0) >= 0.999
				card.pill.Visible = now
				card.value.Visible = not now
				card.pill.BackgroundColor3 = if row.ready == true
					then READY
					elseif pulse then HOT
					else GOLD
				card.pillText.Text = if row.ready == true then "✓" else "Now"
				card.value.Text = main
				card.value.TextColor3 = if urgent then HOT elseif full then READY else GOLD
				card.sub.Text = sub or ""
				card.stroke.Enabled = now or urgent
				card.stroke.Color = if row.ready == true then READY else HOT
			end
		end
		for id, card in cards do
			if not seen[id] then
				card.frame.Visible = false
			end
		end
	end

	return { root = root, update = update }
end

return EventBoard
