--!strict
-- SeasonBook: the Season app on the phone (docs/15 H8, docs/04 §3.1; portrait redesign after the
-- 2026-10-21 playtest: "a child gets it in one look"). Top to bottom: the days-left chip, the
-- current level as a big gold badge, one bar to the next level (its number in a small badge at
-- the bar's end), then the next few rewards as rows: tier, icon, a 1-3 word label and a tick
-- (claimed), a gold Claim pill (reached: tap the row) or a lock (dimmed). No numbers beyond the
-- level, the days and the reward. Mouse, touch, gamepad A on a focused row; Close or B away.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("Season"))
local HudTheme = require(script.Parent:WaitForChild("HudTheme"))
local Layout = require(script.Parent:WaitForChild("Layout"))

local C = HudTheme.Colors
local WIDTH, HEIGHT = 340, 620 -- du, standalone; on the phone it fills the app page
local ROWS = 5 -- rewards shown
local ROW_H, ROW_GAP = 52, 6
local BADGE = 132

export type TierView = {
	tier: number,
	xp: number,
	cash: number,
	rep: number,
	cosmetic: string?,
	surprise: string?,
	claimed: boolean,
	reached: boolean,
}

export type View = {
	id: string,
	name: string,
	xp: number,
	tier: number,
	xpInto: number,
	xpSpan: number,
	maxed: boolean,
	claimed: number,
	total: number,
	live: boolean,
	daysLeft: number,
	tiers: { TierView },
}

export type Book = {
	frame: Frame,
	setOpen: (open: boolean) -> (),
	isOpen: () -> boolean,
	update: (view: View) -> (),
	firstButton: () -> GuiObject?,
	flash: (tier: number) -> (),
}

local SeasonBook = {}

local function shape(
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
		HudTheme.corner(f, r)
	end
	f.Parent = parent
	return f
end

-- Reward marks drawn from shapes, so no image assets are needed.
local GLYPH: { [string]: (Instance, Color3) -> () } = {
	Cash = function(t, color)
		local disc = shape(t, color, 0.5, 0.5, 0.64, 0.64, 99)
		local mark =
			HudTheme.label("Coin", "$", UDim2.fromScale(1, 1), HudTheme.HeaderFont, 24, disc)
		mark.TextColor3 = C.panel
		mark.TextXAlignment = Enum.TextXAlignment.Center
		mark.TextYAlignment = Enum.TextYAlignment.Center
	end,
	Rep = function(t, color)
		shape(t, color, 0.34, 0.66, 0.16, 0.34, 2)
		shape(t, color, 0.5, 0.55, 0.16, 0.56, 2)
		shape(t, color, 0.66, 0.42, 0.16, 0.82, 2)
	end,
	Decal = function(t, color)
		shape(t, color, 0.31, 0.5, 0.07, 0.7, 2)
		local flag = shape(t, color, 0.6, 0.37, 0.5, 0.32, 3)
		flag.BackgroundTransparency = 0.15
	end,
	Wake = function(t, color)
		for i = 1, 3 do
			shape(t, color, 0.5, 0.34 + i * 0.16, 0.7 - i * 0.08, 0.07, 99)
		end
	end,
	Title = function(t, color)
		shape(t, color, 0.5, 0.36, 0.62, 0.2, 2)
		local left = shape(t, color, 0.28, 0.64, 0.1, 0.34, 2)
		left.Rotation = 12
		local right = shape(t, color, 0.72, 0.64, 0.1, 0.34, 2)
		right.Rotation = -12
	end,
	Livery = function(t, color)
		shape(t, color, 0.5, 0.64, 0.72, 0.22, 4)
		shape(t, color, 0.5, 0.43, 0.3, 0.2, 2)
		shape(t, C.panel, 0.5, 0.7, 0.5, 0.05, 99)
	end,
	Lantern = function(t, color)
		shape(t, color, 0.5, 0.55, 0.52, 0.5, 8)
		shape(t, C.panel, 0.5, 0.55, 0.34, 0.34, 6)
		shape(t, color, 0.5, 0.26, 0.26, 0.07, 99)
		shape(t, color, 0.5, 0.84, 0.34, 0.06, 99)
	end,
	Gull = function(t, color)
		local left = shape(t, color, 0.33, 0.5, 0.34, 0.07, 99)
		left.Rotation = -24
		local right = shape(t, color, 0.67, 0.5, 0.34, 0.07, 99)
		right.Rotation = 24
		shape(t, color, 0.5, 0.58, 0.1, 0.16, 99)
	end,
	Star = function(t, color)
		local l = HudTheme.label("Star", "★", UDim2.fromScale(1, 1), HudTheme.HeaderFont, 30, t)
		l.TextColor3 = color
		l.TextXAlignment = Enum.TextXAlignment.Center
	end,
}

local COLOUR: { [string]: Color3 } = {
	Cash = C.gold,
	Rep = C.bar,
	Decal = C.accent,
	Wake = C.ready,
	Title = C.gold,
	Livery = C.accent,
	Lantern = Color3.fromRGB(255, 176, 86),
	Gull = C.textDim,
	Star = C.gold,
}

local function rewardOf(tier: TierView): (string, string)
	if tier.cosmetic then
		local name = Config.cosmetics[tier.cosmetic] or "Decal"
		return name, name
	end
	if tier.surprise then
		local name = Config.surprises[tier.surprise] or "Star"
		return name, name
	end
	if tier.rep > 0 then
		return "Rep", `+{tier.rep}`
	end
	return "Cash", HudTheme.formatNumber(tier.cash)
end

local function drawIcon(frame: Frame, kind: string)
	frame:ClearAllChildren()
	local glyph = GLYPH[kind] or GLYPH.Cash
	glyph(frame, COLOUR[kind] or C.gold)
end

-- A small clock: a ring with two hands. No text.
local function drawClock(parent: Instance, x: number, y: number, size: number)
	local ring = shape(parent, C.panel, 0, 0, 0, 0, 99)
	ring.AnchorPoint = Vector2.new(0, 0.5)
	ring.Position = UDim2.new(0, x, 0.5, y)
	ring.Size = UDim2.fromOffset(size, size)
	HudTheme.stroke(ring, C.text, 2)
	local hour = shape(ring, C.text, 0.5, 0.5, 0.12, 0.3, 99)
	hour.AnchorPoint = Vector2.new(0.5, 1)
	local minute = shape(ring, C.text, 0.5, 0.5, 0.34, 0.12, 99)
	minute.AnchorPoint = Vector2.new(0, 0.5)
end

type Row = {
	button: TextButton,
	num: TextLabel,
	icon: Frame,
	label: TextLabel,
	tick: Frame,
	claim: Frame,
	dim: Frame,
	lock: Frame,
	stroke: UIStroke,
	tier: number,
}

local function makeRow(parent: Instance, order: number, onClaim: (tier: number) -> ()): Row
	local b = Instance.new("TextButton")
	b.Name = `Reward{order}`
	b.LayoutOrder = order
	b.Size = UDim2.new(1, 0, 0, ROW_H)
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundColor3 = C.panelLight
	b.BorderSizePixel = 0
	HudTheme.corner(b, 16)
	local stroke = HudTheme.stroke(b, C.gold, 2)
	b.Parent = parent

	local disc = shape(b, C.panel, 0, 0.5, 0, 0, 99)
	disc.AnchorPoint = Vector2.new(0, 0.5)
	disc.Position = UDim2.new(0, 10, 0.5, 0)
	disc.Size = UDim2.fromOffset(36, 36)
	local num = HudTheme.label("N", "", UDim2.fromScale(1, 1), HudTheme.HeaderFont, 18, disc)
	num.TextXAlignment = Enum.TextXAlignment.Center

	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 54, 0.5, 0)
	icon.Size = UDim2.fromOffset(38, 38)
	icon.BackgroundTransparency = 1
	icon.Parent = b

	local label = HudTheme.label("Reward", "", UDim2.new(1, -184, 1, 0), HudTheme.HeaderFont, 20, b)
	label.Position = UDim2.fromOffset(100, 0)

	-- right edge: a tick (claimed), a Claim pill (reached) or a lock (not yet)
	local tick = shape(b, C.ready, 1, 0.5, 0, 0, 99)
	tick.AnchorPoint = Vector2.new(1, 0.5)
	tick.Position = UDim2.new(1, -12, 0.5, 0)
	tick.Size = UDim2.fromOffset(34, 34)
	local a = shape(tick, C.panel, 0.38, 0.58, 0.12, 0.32, 99)
	a.Rotation = -45
	local c = shape(tick, C.panel, 0.58, 0.48, 0.12, 0.56, 99)
	c.Rotation = 40

	local claim = shape(b, C.gold, 1, 0.5, 0, 0, 14)
	claim.AnchorPoint = Vector2.new(1, 0.5)
	claim.Position = UDim2.new(1, -10, 0.5, 0)
	claim.Size = UDim2.fromOffset(74, 38)
	local claimText =
		HudTheme.label("Text", "Claim", UDim2.fromScale(1, 1), HudTheme.HeaderFont, 18, claim)
	claimText.TextXAlignment = Enum.TextXAlignment.Center
	claimText.TextColor3 = C.panel

	local dim = shape(b, C.panel, 0.5, 0.5, 1, 1, 16)
	dim.BackgroundTransparency = 0.45
	dim.ZIndex = 3
	local lock = Instance.new("Frame")
	lock.Name = "Lock"
	lock.AnchorPoint = Vector2.new(1, 0.5)
	lock.Position = UDim2.new(1, -14, 0.5, 0)
	lock.Size = UDim2.fromOffset(28, 30)
	lock.BackgroundTransparency = 1
	lock.ZIndex = 4
	lock.Parent = b
	local shackle = shape(lock, C.panel, 0.5, 0.32, 0.62, 0.56, 99)
	shackle.BackgroundTransparency = 1
	shackle.ZIndex = 4
	HudTheme.stroke(shackle, C.textDim, 3)
	local body = shape(lock, C.textDim, 0.5, 0.7, 1, 0.6, 5)
	body.ZIndex = 4

	local row: Row = {
		button = b,
		num = num,
		icon = icon,
		label = label,
		tick = tick,
		claim = claim,
		dim = dim,
		lock = lock,
		stroke = stroke,
		tier = 0,
	}
	b.Activated:Connect(function()
		if b.Selectable and row.tier > 0 then
			onClaim(row.tier)
		end
	end)
	return row
end

-- Pure: the first tier to list. One claimed row for context, then what comes next.
local function firstShown(view: View): number
	local from = view.tier + 1
	for i, def in view.tiers do
		if def.reached and not def.claimed then
			from = i
			break
		end
	end
	return math.clamp(from - 1, 1, math.max(1, #view.tiers - ROWS + 1))
end

function SeasonBook.build(gui: ScreenGui, onClaim: (tier: number) -> ()): Book
	local frame = HudTheme.panel("SeasonBook", UDim2.fromOffset(WIDTH, HEIGHT), gui)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.BackgroundTransparency = HudTheme.PromptTransparency
	frame.Visible = false
	frame.SelectionGroup = true
	HudTheme.padding(frame, 14)
	local scale = Instance.new("UIScale")
	scale.Parent = frame
	local function fit(mt: Layout.Metrics)
		scale.Scale = mt.scale
		frame.Size =
			UDim2.fromOffset(math.min(WIDTH, mt.usable.X - 40), math.min(HEIGHT, mt.usable.Y - 24))
	end
	fit(Layout.current())
	Layout.onMetrics(fit)

	-- days left, top left (hidden off season); Close top right (the phone hides it: back is its own)
	local chip = shape(frame, C.panelLight, 0, 0, 0, 0, 16)
	chip.Name = "TimeLeft"
	chip.AnchorPoint = Vector2.zero
	chip.Position = UDim2.fromOffset(0, 4)
	chip.Size = UDim2.fromOffset(84, 34)
	drawClock(chip, 9, 0, 18)
	local days = HudTheme.label("Days", "", UDim2.new(1, -34, 1, 0), HudTheme.HeaderFont, 18, chip)
	days.Position = UDim2.fromOffset(32, 0)
	local close = HudTheme.button("Close", "X", UDim2.fromOffset(42, 42), frame)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.fromScale(1, 0)
	close.BackgroundColor3 = C.panelLight
	HudTheme.corner(close, 21)

	-- the level badge
	local glow = shape(frame, C.gold, 0.5, 0, 0, 0, 99)
	glow.AnchorPoint = Vector2.new(0.5, 0)
	glow.Position = UDim2.new(0.5, 0, 0, 36)
	glow.Size = UDim2.fromOffset(BADGE + 20, BADGE + 20)
	glow.BackgroundTransparency = 0.8
	local badge = shape(glow, Color3.new(1, 1, 1), 0.5, 0.5, 0, 0, 99)
	badge.Size = UDim2.fromOffset(BADGE, BADGE)
	local shine = Instance.new("UIGradient")
	shine.Color = ColorSequence.new(Color3.fromHex("FFE58A"), Color3.fromHex("E39A2B"))
	shine.Rotation = 90
	shine.Parent = badge
	HudTheme.stroke(badge, Color3.new(1, 1, 1), 4)
	local level =
		HudTheme.label("Level", "0", UDim2.fromScale(1, 1), HudTheme.HeaderFont, 68, badge)
	level.TextXAlignment = Enum.TextXAlignment.Center
	level.TextColor3 = Color3.fromHex("4A2E06")
	local badgeScale = Instance.new("UIScale")
	badgeScale.Parent = glow

	-- one bar to the next level, its number in a small badge at the end
	local barY = 36 + BADGE + 20 + 14
	local barBack = shape(frame, C.locked, 0, 0, 0, 0, 13)
	barBack.AnchorPoint = Vector2.zero
	barBack.Position = UDim2.fromOffset(0, barY + 9)
	barBack.Size = UDim2.new(1, -40, 0, 26)
	local barFill = shape(barBack, Color3.new(1, 1, 1), 0, 0.5, 0, 1, 13)
	barFill.AnchorPoint = Vector2.new(0, 0.5)
	local fillShine = Instance.new("UIGradient")
	fillShine.Color = ColorSequence.new(Color3.fromHex("7CE8FF"), Color3.fromHex("2F8CFF"))
	fillShine.Parent = barFill
	local nextBadge = shape(frame, C.panelLight, 1, 0, 0, 0, 99)
	nextBadge.AnchorPoint = Vector2.new(1, 0)
	nextBadge.Position = UDim2.new(1, 0, 0, barY)
	nextBadge.Size = UDim2.fromOffset(44, 44)
	HudTheme.stroke(nextBadge, C.gold, 2)
	local nextLevel =
		HudTheme.label("Next", "", UDim2.fromScale(1, 1), HudTheme.HeaderFont, 20, nextBadge)
	nextLevel.TextXAlignment = Enum.TextXAlignment.Center

	-- the next few rewards
	local listY = barY + 44 + 12
	local list = Instance.new("Frame")
	list.Name = "Rewards"
	list.BackgroundTransparency = 1
	list.ClipsDescendants = true
	list.Position = UDim2.fromOffset(0, listY)
	list.Size = UDim2.new(1, 0, 1, -listY)
	list.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, ROW_GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	local rows: { Row } = {}
	for i = 1, ROWS do
		rows[i] = makeRow(list, i, onClaim)
	end

	local open = false
	local shownLevel: number? = nil

	local function apply(view: View)
		chip.Visible = view.live
		days.Text = `{view.daysLeft}d`
		level.Text = tostring(view.tier)
		nextLevel.Text = if view.maxed then "★" else tostring(view.tier + 1)
		local ratio = if view.xpSpan > 0 then math.clamp(view.xpInto / view.xpSpan, 0, 1) else 1
		barFill.Size = UDim2.fromScale(if view.maxed then 1 else ratio, 1)
		barFill.Visible = ratio > 0 or view.maxed
		-- a level-up while open: the badge pops
		if open and shownLevel and view.tier > shownLevel then
			badgeScale.Scale = 1.25
			TweenService:Create(
				badgeScale,
				TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1 }
			):Play()
		end
		shownLevel = view.tier

		local from = firstShown(view)
		for i, row in rows do
			local def = view.tiers[from + i - 1]
			row.button.Visible = def ~= nil
			if def then
				local claimable = def.reached and not def.claimed
				local kind, text = rewardOf(def)
				row.tier = def.tier
				row.num.Text = tostring(def.tier)
				row.label.Text = text
				drawIcon(row.icon, kind)
				row.tick.Visible = def.claimed
				row.claim.Visible = claimable
				row.dim.Visible = not def.reached
				row.lock.Visible = not def.reached
				row.stroke.Enabled = claimable
				row.button.Selectable = claimable
				row.button.BackgroundTransparency = if def.claimed then 0.45 else 0
			end
		end
	end

	local function flash(tier: number)
		for _, row in rows do
			if row.tier == tier and row.button.Visible then
				local burst = shape(row.button, C.gold, 0.5, 0.5, 1, 1, 16)
				burst.BackgroundTransparency = 0.3
				burst.ZIndex = 5
				TweenService:Create(burst, TweenInfo.new(0.35), { BackgroundTransparency = 1 })
					:Play()
				task.delay(0.4, function()
					burst:Destroy()
				end)
			end
		end
	end

	local book: Book
	book = {
		frame = frame,
		setOpen = function(value: boolean)
			open = value
			frame.Visible = value
		end,
		isOpen = function()
			return open
		end,
		update = apply,
		firstButton = function(): GuiObject?
			for _, row in rows do
				if row.button.Visible and row.button.Selectable then
					return row.button
				end
			end
			return close
		end,
		flash = flash,
	}

	close.Activated:Connect(function()
		book.setOpen(false)
	end)

	return book
end

return SeasonBook
