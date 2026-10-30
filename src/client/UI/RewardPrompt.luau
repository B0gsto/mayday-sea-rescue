--!strict
-- RewardPrompt: the one reward prompt on join (owner, 2026-10-28: no chest, "just prompt that"). In the kit
-- look: a title ribbon, the wallet's coin and the amount, big; the 7-day strip of pips (today's raised)
-- when a streak reward applies; a crew row with the offline earnings; one big green Collect (a single
-- action, not a choice). Collect: click / tap, Enter or E, gamepad A. Built by RewardController.
--   RewardPrompt.show(playerGui, { cash, day?, welcome?, crew? }, onCollect)
--   onCollect(from): once, `from` is the big coin's centre on screen (UI/CoinShower springs from it)
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local UiImages = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UiImages")
) :: any

local AudioController =
	require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("AudioController"))
local HudTheme = require(script.Parent:WaitForChild("HudTheme"))
local InputGlyph = require(script.Parent:WaitForChild("InputGlyph"))
local Layout = require(script.Parent:WaitForChild("Layout"))
local Kit = script.Parent:WaitForChild("Kit")
local Style = require(Kit:WaitForChild("Style"))
local Theme = require(Kit:WaitForChild("Theme"))

export type Reward = {
	cash: number, -- the total: streak (with its welcome and group bonus) + crew
	day: number?, -- the streak day being collected (1..7), nil: no streak reward
	welcome: boolean?,
	crew: number?, -- offline crew earnings, nil / 0: none
}

local RewardPrompt = {}

local WIDTH = 540
local PIP, PIP_TODAY, PIP_GAP = 54, 74, 8
local INK = Theme.Colors.ink

local function image(parent: Instance, id: string, size: number): ImageLabel
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Image = id
	img.ScaleType = Enum.ScaleType.Fit
	img.Size = UDim2.fromOffset(size, size)
	img.Parent = parent
	return img
end

-- The wallet's gold number: white text under a gold gradient, a thick dark outline.
local function goldNumber(parent: Instance, text: string, size: number): TextLabel
	local l = Style.label(parent, text, size)
	l.TextWrapped = false
	l.AutomaticSize = Enum.AutomaticSize.X
	l.Size = UDim2.fromOffset(0, size + 8)
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(Color3.fromHex("FFF7B8"), Color3.fromHex("FFB81C"))
	grad.Parent = l
	local stroke = l:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Color3.fromHex("3A1E00")
		stroke.Thickness = 5
	end
	return l
end

local function row(parent: Instance, height: number, order: number, gap: number?): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, 0, 0, height)
	f.LayoutOrder = order
	f.Parent = parent
	local list = Style.list(f, true, gap or 10)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	return f
end

local function strip(parent: Instance, day: number)
	local r = row(parent, PIP_TODAY + 4, 2, PIP_GAP)
	local pips = UiImages.Pip
	for d = 1, 7 do
		local today = d == day
		local id = if d < day
			then pips.Done
			elseif d == 7 then (if today then pips.SevenToday else pips.Seven)
			elseif today then pips.Today
			else pips.Next
		local side = if today then PIP_TODAY else PIP
		local img = image(r, id, side)
		img.Name = `Day{d}`
		img.Size = UDim2.fromOffset(side, side * 172 / 160) -- the sprite's box
		img.LayoutOrder = d
		if d >= day and d < 7 then
			-- today: white on gold; the days ahead: ink on the light grey stud (white read washed out)
			local n = Style.label(img, tostring(d), if today then 36 else 28, not today)
			n.Position = UDim2.fromScale(0, -0.06)
			if not today then
				n.TextColor3 = INK
			end
		end
	end
end

local function crewRow(parent: Instance, crew: number)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(330, 72)
	holder.LayoutOrder = 3
	holder.Parent = parent
	local _, face = Style.block(holder, Theme.Grad.owned, { radius = 32, lip = 5, border = 3 })
	local r = row(face, 66, 1, 10)
	r.Size = UDim2.fromScale(1, 1)
	local crewIcon = Instance.new("Frame")
	crewIcon.BackgroundTransparency = 1
	crewIcon.Size = UDim2.fromOffset(68, 68)
	crewIcon.LayoutOrder = 1
	crewIcon.Parent = r
	Style.icon(crewIcon, "crew")
	local coin = image(r, UiImages.Hud.Coin, 46)
	coin.LayoutOrder = 2
	local n = Style.label(r, `+{HudTheme.formatNumber(crew)}`, 40)
	n.TextWrapped = false
	n.AutomaticSize = Enum.AutomaticSize.X
	n.Size = UDim2.fromOffset(0, 50)
	n.LayoutOrder = 3
end

local function title(reward: Reward): (string, string)
	if reward.welcome then
		return "Welcome Back!", "pink"
	elseif reward.day == 7 then
		return "Day 7!", "purple"
	elseif reward.day then
		return `Day {reward.day}`, "yellow"
	end
	return "Crew Pay", "blue"
end

function RewardPrompt.show(playerGui: Instance, reward: Reward, onCollect: (Vector2) -> ())
	local gui = Instance.new("ScreenGui")
	gui.Name = "RewardPrompt"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 44
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local hud = playerGui:FindFirstChild("Hud")
	if hud and hud:IsA("ScreenGui") then -- the HUD's screen space: the coin's position feeds CoinShower
		gui.IgnoreGuiInset = hud.IgnoreGuiInset
		gui.ScreenInsets = hud.ScreenInsets
	end
	gui.Parent = playerGui
	-- Studio: HudViewport previews a phone in the top-left corner
	local forced = RunService:IsStudio() and Workspace:GetAttribute("HudViewport")
	local canvas = Style.canvas(gui, if typeof(forced) == "Vector2" then forced else nil)

	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.BackgroundColor3 = Theme.Colors.shadow
	dim.BackgroundTransparency = 0.5
	-- over the top bar too (the HUD's screen space starts below it)
	local top = if gui.IgnoreGuiInset then 0 else GuiService:GetGuiInset().Y
	local _, kitScale = Style.metrics(canvas)
	dim.Position = UDim2.fromOffset(0, -top / kitScale)
	dim.Size = UDim2.new(1, 0, 1, top / kitScale)
	dim.Parent = canvas

	local hasDay = reward.day ~= nil
	-- crew pay alone: the big amount already is the crew pay (no second +N row)
	local crew = if reward.day then reward.crew or 0 else 0
	-- top room under the ribbon 46, amount 104, Collect 88, bottom 38 (the lip and air), list gaps 14
	local bodyH = 46
		+ 104
		+ 14
		+ 88
		+ 38
		+ (if hasDay then PIP_TODAY + 4 + 14 else 0)
		+ (if crew > 0 then 72 + 14 else 0)
	local root = Instance.new("Frame")
	root.Name = "Card"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.new(0.5, 0, 0.5, -6)
	root.Size = UDim2.fromOffset(WIDTH, bodyH + 34)
	root.Parent = canvas
	-- short screens: the card shrinks to fit (it is never cut)
	local vp, scale = Style.metrics(canvas)
	local fit = Instance.new("UIScale")
	fit.Scale = math.min(1, vp.Y / scale * 0.94 / (bodyH + 34), vp.X / scale * 0.94 / WIDTH)
	fit.Parent = root

	local bodyBox = Instance.new("Frame")
	bodyBox.Name = "Body"
	bodyBox.BackgroundTransparency = 1
	bodyBox.Position = UDim2.fromOffset(0, 34)
	bodyBox.Size = UDim2.new(1, 0, 0, bodyH)
	bodyBox.Parent = root
	local _, face = Style.block(
		bodyBox,
		Theme.Grad.body,
		{ shadow = true, lip = 8, radius = Theme.Size.corner + 4 }
	)
	local inner = Instance.new("Frame")
	inner.BackgroundTransparency = 1
	inner.Position = UDim2.fromOffset(0, 46)
	inner.Size = UDim2.new(1, 0, 1, -46)
	inner.Parent = face
	local list = Style.list(inner, false, 14)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center

	-- the ribbon over the top edge
	local text, colour = title(reward)
	local ribbon = Instance.new("Frame")
	ribbon.Name = "Ribbon"
	ribbon.BackgroundTransparency = 1
	ribbon.AnchorPoint = Vector2.new(0.5, 0)
	ribbon.Position = UDim2.fromScale(0.5, 0)
	ribbon.Size = UDim2.fromOffset(340, 72)
	ribbon.ZIndex = 2
	ribbon.Parent = root
	local _, ribbonFace = Style.block(ribbon, Style.grad(colour), { studs = true, radius = 20 })
	local t = Style.label(ribbonFace, text, Theme.Text.title - 4)
	t.TextWrapped = false
	t.ZIndex = 3

	-- the coin and the amount, big
	local amount = row(inner, 104, 1, 14)
	if not reward.day and (reward.crew or 0) > 0 then -- crew pay alone: the crew beside the amount
		local crewIcon = Instance.new("Frame")
		crewIcon.BackgroundTransparency = 1
		crewIcon.Size = UDim2.fromOffset(96, 96)
		crewIcon.LayoutOrder = 0
		crewIcon.Parent = amount
		Style.icon(crewIcon, "crew")
	end
	local coin = image(amount, UiImages.Hud.Coin, 100)
	coin.Name = "Coin"
	coin.LayoutOrder = 1
	local n = goldNumber(amount, `+{HudTheme.formatNumber(reward.cash)}`, 84)
	n.LayoutOrder = 2

	if reward.day then
		strip(inner, reward.day)
	end
	if crew > 0 then
		crewRow(inner, crew)
	end

	-- Collect
	local button = Style.button(inner, UDim2.fromOffset(320, 88))
	button.Name = "Collect"
	button.LayoutOrder = 4
	button.Modal = true -- frees the mouse in first person
	local _, buttonFace = Style.block(button, Theme.Grad.buy, { studs = true, radius = 22 })
	local label = Style.label(buttonFace, "Collect", Theme.Text.button + 8)
	label.TextWrapped = false
	local key = Instance.new("Frame")
	key.Name = "Key"
	key.AnchorPoint = Vector2.new(0, 0.5)
	key.Position = UDim2.new(0, 16, 0.5, 0)
	key.Size = UDim2.fromOffset(46, 46)
	key.BackgroundColor3 = Color3.new(1, 1, 1)
	key.Parent = buttonFace
	Style.corner(key, 10)
	Style.stroke(key, 3, true)
	local keyText = Style.label(key, "E", 28, true)
	keyText.TextColor3 = INK
	local pad = image(key, "", 46)
	local device = InputGlyph.onDevice(function(d)
		local touch = d == "Touch" or Layout.current().touch
		key.Visible = not touch
		pad.Image = if d == "Gamepad"
			then UserInputService:GetImageForKeyCode(Enum.KeyCode.ButtonA)
			else ""
		key.BackgroundTransparency = if pad.Image ~= "" then 1 else 0
		keyText.Text = if pad.Image ~= "" then "" else "E"
	end)

	local action = "RewardCollect"
	local done = false
	local function collect()
		if done then
			return
		end
		done = true
		ContextActionService:UnbindAction(action)
		ProximityPromptService.Enabled = true
		device:Disconnect()
		if GuiService.SelectedObject == button then
			GuiService.SelectedObject = nil
		end
		AudioController.play("UI_Click", nil, 1, 1)
		local from = coin.AbsolutePosition + coin.AbsoluteSize / 2
		Style.pop(root, false)
		Style.tween(dim, 0.2, { BackgroundTransparency = 1 })
		task.delay(0.3, function()
			gui:Destroy()
		end)
		task.spawn(onCollect, from)
	end
	Style.press(button, collect, 22)
	if RunService:IsStudio() then -- Studio: a capture bench collects by changing Workspace attribute RewardCollect
		Workspace:GetAttributeChangedSignal("RewardCollect"):Once(collect)
	end
	-- a new player spawns at the build tablet: its E prompt would open under the card (the bound E never sinks it)
	ProximityPromptService.Enabled = false
	ContextActionService:BindActionAtPriority(
		action,
		function(_, state)
			if state == Enum.UserInputState.Begin then
				collect()
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value + 10,
		Enum.KeyCode.Return,
		Enum.KeyCode.KeypadEnter,
		Enum.KeyCode.E,
		Enum.KeyCode.ButtonA
	)
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = button
	end
	Style.pop(root, true)
	AudioController.play("Album_Sparkle", nil, 0.5, 1.1)
end

return RewardPrompt
