--!strict
-- CallCard: the radio call card (docs 05 section 9). Greybox but clean: Abyss Navy panel,
-- Rescue Orange header and Accept button, rounded corners, mobile-sized touch targets.
--
--   local card = CallCard.new(container, data, onAccept)
--   card:update(data, secondsLeft, distance)   -- refresh text (cheap, call a few times a second)
--   card:destroy()
--   CallCard.toast(container, title, body, color)
local TweenService = game:GetService("TweenService")

local CallCard = {}
CallCard.__index = CallCard

CallCard.Colors = {
	Orange = Color3.fromHex("#FF6B1A"),
	Navy = Color3.fromHex("#0A2A3B"),
	Yellow = Color3.fromHex("#FFD23F"),
	Green = Color3.fromHex("#3EE07A"),
	Red = Color3.fromHex("#E8322B"),
	Text = Color3.fromRGB(245, 248, 250),
	Muted = Color3.fromRGB(170, 195, 210),
}
local C = CallCard.Colors

export type CallCard = typeof(setmetatable(
	{} :: {
		frame: Frame,
		header: TextLabel,
		timer: TextLabel,
		title: TextLabel,
		sub: TextLabel,
		line: TextLabel,
		reward: TextLabel,
		accept: TextButton,
		accepted: boolean,
		tween: Tween?,
	},
	CallCard
))

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function padding(parent: Instance, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.Parent = parent
end

local function label(
	parent: Instance,
	name: string,
	order: number,
	size: number,
	font: Enum.Font,
	color: Color3
): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.LayoutOrder = order
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.Font = font
	l.TextSize = size
	l.TextColor3 = color
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = ""
	l.Parent = parent
	return l
end

local function formatTime(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end
CallCard.formatTime = formatTime

function CallCard.new(container: Instance, data: { [string]: any }, onAccept: () -> ()): CallCard
	local frame = Instance.new("Frame")
	frame.Name = `Call_{data.id}`
	frame.BackgroundColor3 = C.Navy
	frame.BackgroundTransparency = 0.06
	frame.Size = UDim2.fromScale(1, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.LayoutOrder = if data.isBig then 0 else 1
	corner(frame, 14)
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.Orange
	stroke.Thickness = if data.isBig then 3 else 2
	stroke.Parent = frame
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 4)
	list.Parent = frame

	-- header strip: MAYDAY + timer
	local strip = Instance.new("Frame")
	strip.Name = "Header"
	strip.LayoutOrder = 0
	strip.BackgroundColor3 = C.Orange
	strip.Size = UDim2.new(1, 0, 0, 32)
	corner(strip, 14)
	strip.Parent = frame
	local header = Instance.new("TextLabel")
	header.BackgroundTransparency = 1
	header.Position = UDim2.fromOffset(14, 0)
	header.Size = UDim2.new(1, -90, 1, 0)
	header.Font = Enum.Font.FredokaOne
	header.TextSize = 18
	header.TextColor3 = C.Text
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Text = if data.isBig then "BIG CALL  ·  ALL HANDS" else "MAYDAY"
	header.Parent = strip
	local timer = Instance.new("TextLabel")
	timer.BackgroundTransparency = 1
	timer.AnchorPoint = Vector2.new(1, 0)
	timer.Position = UDim2.new(1, -14, 0, 0)
	timer.Size = UDim2.new(0, 80, 1, 0)
	timer.Font = Enum.Font.FredokaOne
	timer.TextSize = 18
	timer.TextColor3 = C.Text
	timer.TextXAlignment = Enum.TextXAlignment.Right
	timer.Parent = strip

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.LayoutOrder = 1
	body.BackgroundTransparency = 1
	body.Size = UDim2.fromScale(1, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	padding(body, 12)
	body.Parent = frame
	local bl = Instance.new("UIListLayout")
	bl.SortOrder = Enum.SortOrder.LayoutOrder
	bl.Padding = UDim.new(0, 4)
	bl.Parent = body

	local title =
		label(body, "Title", 1, if data.isBig then 24 else 21, Enum.Font.FredokaOne, C.Text)
	local sub = label(body, "Sub", 2, 15, Enum.Font.BuilderSansBold, C.Muted)
	local line = label(body, "Line", 3, 15, Enum.Font.BuilderSans, C.Text)
	local reward = label(body, "Reward", 4, 15, Enum.Font.BuilderSansBold, C.Yellow)

	local accept = Instance.new("TextButton")
	accept.Name = "Accept"
	accept.LayoutOrder = 5
	accept.Size = UDim2.new(1, 0, 0, 50) -- >= 48 px touch target
	accept.BackgroundColor3 = C.Orange
	accept.AutoButtonColor = true
	accept.Font = Enum.Font.FredokaOne
	accept.TextSize = 22
	accept.TextColor3 = C.Text
	accept.Text = if data.isBig then "JOIN" else "ACCEPT"
	corner(accept, 12)
	accept.Parent = body

	local self = setmetatable({
		frame = frame,
		header = header,
		timer = timer,
		title = title,
		sub = sub,
		line = line,
		reward = reward,
		accept = accept,
		accepted = false,
		tween = nil :: Tween?,
	}, CallCard)

	accept.Activated:Connect(function()
		if not self.accepted then
			accept.Text = "EN ROUTE"
			accept.AutoButtonColor = false
			onAccept()
		end
	end)

	if data.isBig then
		local pulse = TweenService:Create(
			stroke,
			TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Color = C.Yellow }
		)
		pulse:Play()
		self.tween = pulse
	end

	-- slide in
	frame.Parent = container
	local scale = Instance.new("UIScale")
	scale.Scale = 0.85
	scale.Parent = frame
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	return self
end

local function objective(data: { [string]: any }): string
	if data.message then
		return data.message
	end
	if data.state == "Offered" then
		return data.radioLine
	end
	if data.kind == "Tow" then
		return if data.towing then "Tow to dock" else "Attach tow"
	end
	if (data.aboard or 0) > 0 then
		return "Dock or hospital"
	end
	return if data.kind == "DriftingCraft" then "Pull both aboard" else "Pull aboard"
end

function CallCard.update(
	self: CallCard,
	data: { [string]: any },
	secondsLeft: number,
	distance: number?
)
	self.title.Text = data.title or data.kind
	local dist = if distance then `{math.floor(distance + 0.5)} m` else "--"
	local progress = if data.state == "Active" and (data.total or 0) > 1
		then `  ·  {data.delivered or 0}/{data.total} safe`
		else ""
	self.sub.Text = `{data.zoneName or ""}  ·  {dist}{progress}`
	self.line.Text = objective(data)
	self.timer.Text = formatTime(secondsLeft)
	self.timer.TextColor3 = if secondsLeft < 30 and data.state == "Active" then C.Navy else C.Text
	if data.state == "Active" then
		self.reward.Visible = false
		local joined = data.joined == true or not data.isBig
		self.accept.Visible = not joined
		self.accepted = joined
	else
		self.reward.Visible = true
		self.reward.Text = `+{data.cash or 0} Cash   +{data.rep or 0} Rep`
	end
	if data.isBig and data.joined then
		self.accept.Visible = false
	end
end

function CallCard.destroy(self: CallCard)
	if self.tween then
		self.tween:Cancel()
	end
	self.frame:Destroy()
end

-- A short result banner that fades out after `seconds`.
function CallCard.toast(
	container: Instance,
	title: string,
	body: string,
	color: Color3,
	seconds: number?
)
	local frame = Instance.new("Frame")
	frame.Name = "Toast"
	frame.LayoutOrder = 2
	frame.BackgroundColor3 = C.Navy
	frame.BackgroundTransparency = 0.06
	frame.Size = UDim2.fromScale(1, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	corner(frame, 14)
	padding(frame, 12)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 2
	stroke.Parent = frame
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 2)
	list.Parent = frame
	local t = label(frame, "Title", 1, 22, Enum.Font.FredokaOne, color)
	t.Text = title
	local b = label(frame, "Body", 2, 15, Enum.Font.BuilderSans, C.Text)
	b.Text = body
	frame.Parent = container
	task.delay(seconds or 4.5, function()
		local info = TweenInfo.new(0.4)
		TweenService:Create(frame, info, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(stroke, info, { Transparency = 1 }):Play()
		TweenService:Create(t, info, { TextTransparency = 1 }):Play()
		TweenService:Create(b, info, { TextTransparency = 1 }):Play()
		task.wait(0.45)
		frame:Destroy()
	end)
end

return CallCard
