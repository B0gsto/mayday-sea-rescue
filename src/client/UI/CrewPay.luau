--!strict
-- CrewPay: the phone's Crew Pay and Pay Rise apps (docs/15 H6), drawn on an app page by
-- StationController (it owns the numbers and the remotes). Icons and numbers only.
--   Crew Pay   the station pot: coin + Cash, a fill meter, the clock to full (`2:14`, ✓ when
--              full), the hourly rate and Collect.
--   Pay Rise   the workshop level as 3 brass pips, the next level's rate and cost, and Upgrade
--              (the cost flashes red when the Cash is short, green when it is bought; ✓ at max).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudTheme = require(script.Parent:WaitForChild("HudTheme"))
local IdleIncome = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("IdleIncome"))

local C = HudTheme.Colors
local IRON = Color3.fromRGB(58, 66, 72)
local COIN = Color3.fromRGB(245, 213, 120)
local COIN_EDGE = Color3.fromRGB(184, 134, 47)
local BAD = Color3.fromRGB(244, 128, 112)

export type Pot = {
	button: TextButton,
	update: (
		cash: number,
		capCash: number,
		rate: number,
		secondsToFull: number,
		full: boolean
	) -> (),
}

export type Rise = {
	button: TextButton,
	update: (level: number, cost: number, maxed: boolean, rate: number) -> (),
	flash: (bad: boolean?) -> (),
}

local CrewPay = {}

local function frame(parent: Instance, name: string, color: Color3, pos: UDim2, size: UDim2): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Position = pos
	f.Size = size
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function text(
	parent: Instance,
	name: string,
	value: string,
	size: number,
	color: Color3
): TextLabel
	local l = HudTheme.label(
		name,
		value,
		UDim2.fromOffset(10, size + 8),
		HudTheme.HeaderFont,
		size,
		parent
	)
	l.AutomaticSize = Enum.AutomaticSize.X
	l.TextColor3 = color
	return l
end

local function coin(parent: Instance, size: number): Frame
	local c = frame(parent, "Coin", COIN, UDim2.new(), UDim2.fromOffset(size, size))
	HudTheme.corner(c, 99)
	HudTheme.stroke(c, COIN_EDGE, 3).Transparency = 0
	local inner =
		frame(c, "Inner", COIN_EDGE, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.56, 0.56))
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.BackgroundTransparency = 0.55
	HudTheme.corner(inner, 99)
	return c
end

local function clock(parent: Instance, size: number): Frame
	local c = frame(parent, "Clock", C.panel, UDim2.new(), UDim2.fromOffset(size, size))
	HudTheme.corner(c, 99)
	HudTheme.stroke(c, C.text, 3).Transparency = 0
	for i, spec in { { 0.34, 20 }, { 0.24, 118 } } do
		local hand = frame(
			c,
			`Hand{i}`,
			C.text,
			UDim2.fromScale(0.5, 0.5),
			UDim2.fromOffset(3, size * spec[1])
		)
		hand.AnchorPoint = Vector2.new(0.5, 1)
		hand.Rotation = spec[2]
	end
	return c
end

-- a horizontal row of children, centred
local function row(parent: Instance, name: string, y: number, h: number, gap: number): Frame
	local f = frame(parent, name, C.panel, UDim2.fromOffset(0, y), UDim2.new(1, 0, 0, h))
	f.BackgroundTransparency = 1
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, gap)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = f
	return f
end

-- the centred card both apps sit on
local function card(page: Instance, name: string): Frame
	local f = frame(page, name, C.panel, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(620, 360))
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BackgroundTransparency = 0.25
	HudTheme.corner(f, 24)
	HudTheme.stroke(f, C.gold, 2).Transparency = 0.55
	local fit = Instance.new("UISizeConstraint")
	fit.MaxSize = Vector2.new(620, 360)
	fit.Parent = f
	f.Size = UDim2.fromScale(0.9, 0.92)
	return f
end

local function action(parent: Instance, label: string, y: number): TextButton
	local b = HudTheme.button("Action", label, UDim2.fromOffset(280, 63), parent)
	b.AnchorPoint = Vector2.new(0.5, 0)
	b.Position = UDim2.new(0.5, 0, 0, y)
	b.TextSize = 26
	HudTheme.corner(b, 16)
	local sheen = Instance.new("UIGradient")
	sheen.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(196, 196, 196))
	sheen.Rotation = 90
	sheen.Parent = b
	return b
end

function CrewPay.pot(page: Instance): Pot
	local f = card(page, "CrewPay")
	local top = row(f, "Cash", 34, 80, 16)
	coin(top, 64).LayoutOrder = 1
	local cash = text(top, "Amount", "0", 64, C.gold)
	cash.LayoutOrder = 2

	local meter = frame(f, "Meter", IRON, UDim2.new(0.5, 0, 0, 140), UDim2.new(1, -96, 0, 26))
	meter.AnchorPoint = Vector2.new(0.5, 0)
	meter.ClipsDescendants = true
	HudTheme.corner(meter, 13)
	local fill = frame(meter, "Fill", COIN, UDim2.new(), UDim2.fromScale(0, 1))
	HudTheme.corner(fill, 13)

	local info = row(f, "Info", 184, 48, 14)
	clock(info, 36).LayoutOrder = 1
	local time = text(info, "Time", "0:00", 32, C.text)
	time.LayoutOrder = 2
	local spacer = frame(info, "Gap", C.panel, UDim2.new(), UDim2.fromOffset(28, 1))
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 3
	coin(info, 30).LayoutOrder = 4
	local rate = text(info, "Rate", "0/h", 28, C.textDim)
	rate.LayoutOrder = 5

	local button = action(f, "Collect", 262)
	return {
		button = button,
		update = function(
			cashIn: number,
			capCash: number,
			perHour: number,
			secondsToFull: number,
			full: boolean
		)
			cash.Text = HudTheme.formatNumber(cashIn)
			time.Text = if full then "✓" else IdleIncome.formatTime(secondsToFull)
			time.TextColor3 = if full then C.ready else C.text
			rate.Text = `{HudTheme.formatNumber(perHour)}/h`
			local fraction = if capCash > 0 then math.clamp(cashIn / capCash, 0, 1) else 0
			fill.Size = UDim2.fromScale(fraction, 1)
			fill.BackgroundColor3 = if full then C.ready else COIN
			local ready = cashIn >= 1
			button.AutoButtonColor = ready
			button.BackgroundColor3 = if ready then C.accent else C.locked
			button.TextTransparency = if ready then 0 else 0.5
		end,
	}
end

function CrewPay.rise(page: Instance): Rise
	local f = card(page, "PayRise")
	local pipsRow = row(f, "Level", 34, 80, 22)
	local arrow = text(pipsRow, "Arrow", "▲", 56, C.gold)
	arrow.LayoutOrder = 0
	local pips = {}
	for i = 1, 3 do
		local pip = frame(pipsRow, `Pip{i}`, IRON, UDim2.new(), UDim2.fromOffset(52, 52))
		pip.LayoutOrder = i
		HudTheme.corner(pip, 12)
		HudTheme.stroke(pip, C.gold, 2).Transparency = 0.4
		pips[i] = pip
	end

	local info = row(f, "Rate", 132, 48, 14)
	coin(info, 30).LayoutOrder = 1
	local rate = text(info, "Rate", "0/h", 30, C.textDim)
	rate.LayoutOrder = 2

	local price = row(f, "Cost", 186, 60, 14)
	local priceCoin = coin(price, 44)
	priceCoin.LayoutOrder = 1
	local cost = text(price, "Amount", "0", 48, C.text)
	cost.LayoutOrder = 2
	local maxedMark = text(price, "Maxed", "✓", 52, C.ready)
	maxedMark.LayoutOrder = 3
	maxedMark.Visible = false

	local button = action(f, "Upgrade", 262)
	local flashSerial = 0
	return {
		button = button,
		update = function(level: number, costIn: number, maxed: boolean, perHour: number)
			for i, pip in pips do
				pip.BackgroundColor3 = if i <= level then C.gold else IRON
			end
			rate.Text = `{HudTheme.formatNumber(perHour)}/h`
			cost.Visible = not maxed
			priceCoin.Visible = not maxed
			maxedMark.Visible = maxed
			if not maxed then
				cost.Text = HudTheme.formatNumber(costIn)
			end
			button.Visible = not maxed
		end,
		flash = function(bad: boolean?)
			flashSerial += 1
			local serial = flashSerial
			cost.TextColor3 = if bad then BAD else C.ready
			task.delay(0.7, function()
				if serial == flashSerial then
					cost.TextColor3 = C.text
				end
			end)
		end,
	}
end

return CrewPay
