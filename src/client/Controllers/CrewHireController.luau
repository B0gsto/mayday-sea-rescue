--!strict
-- CrewHireController (docs/23 (j), WP-15): the client half of the late-game crew. On every
-- seeker and hired crew model (Workspace.CrewHire, attribute CrewRole) this draws a local
-- billboard: the role glyph (Glyph) and 1..3 skill stars, no text. On the player's own models a
-- local "Hire" / "Fire" prompt opens the card (role glyph, stars, hire price in Cash, daily
-- wage) with Hire / Close or Fire / Close — the same panel look as the dock price card
-- (DockController; a later UI-kit pass restyles all of it). Hired state and the 20-minute line
-- rotation come from the server; a small clock glyph above the station door counts down to the
-- next group (CrewHire.nextGroupAt on os.time, the same epochs the server uses).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrewHire = require(Shared:WaitForChild("Crew"):WaitForChild("CrewHire"))
local Marina = require(Shared:WaitForChild("Marina"))
local Net = require(Shared:WaitForChild("Net"))
local UiImages = require(Shared:WaitForChild("Config"):WaitForChild("UiImages"))

local UI = script.Parent.Parent:WaitForChild("UI")
local AudioController = require(script.Parent:WaitForChild("AudioController"))
local Glyph = require(UI:WaitForChild("Glyph"))
local HudTheme = require(UI:WaitForChild("HudTheme"))
local InputGlyph = require(UI:WaitForChild("InputGlyph"))

local CrewHireController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local C = HudTheme.Colors
local GOLD = Color3.fromRGB(242, 190, 40)
local FIRE = Color3.fromRGB(196, 52, 40)

local ROLE_COLORS = {
	Mechanic = Color3.fromRGB(240, 140, 60),
	Lifeguard = Color3.fromRGB(232, 66, 66),
	Dispatcher = Color3.fromRGB(96, 168, 240),
}

local modal: InputGlyph.Modal
local openModel: Model? = nil

-- a four-point sparkle (the "skill star") inside a square parent, in Glyph scale units
local function sparkle(parent: Instance, color: Color3)
	Glyph.bar(parent, Vector2.new(0.42, 0.15), Vector2.new(0.5, 0.5), 0, color, 0.5)
	Glyph.bar(parent, Vector2.new(0.15, 0.42), Vector2.new(0.5, 0.5), 0, color, 0.5)
	Glyph.bar(parent, Vector2.new(0.3, 0.15), Vector2.new(0.5, 0.5), 45, color, 0.5)
	Glyph.bar(parent, Vector2.new(0.3, 0.15), Vector2.new(0.5, 0.5), -45, color, 0.5)
end

local function starRow(parent: Instance, stars: number)
	for _, child in parent:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	for _ = 1, math.clamp(stars, 0, 3) do
		local s = Instance.new("Frame")
		s.Size = UDim2.fromOffset(18, 18)
		s.BackgroundTransparency = 1
		sparkle(s, GOLD)
		s.Parent = parent
	end
end

local function roleColor(role: string): Color3
	return ROLE_COLORS[role] or C.text
end

local function starsOf(model: Model): number
	local s = model:GetAttribute("CrewStars")
	return if type(s) == "number" then s else 0
end

-- the seeker / crew billboard above the head: role glyph + stars (everyone sees it, locally drawn)
local function attachBillboard(model: Model)
	if model:FindFirstChild("CrewTag") then
		return
	end
	local head = model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return -- streaming: the next scan picks it up
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "CrewTag"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(112, 40)
	gui.StudsOffset = Vector3.new(0, 1.4, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 48
	gui.Parent = model
	local row = Instance.new("Frame")
	row.Size = UDim2.fromScale(1, 1)
	row.BackgroundTransparency = 1
	row.Parent = gui
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 4)
	list.Parent = row
	local role = model:GetAttribute("CrewRole")
	local icon = Instance.new("Frame")
	icon.Size = UDim2.fromOffset(30, 30)
	icon.BackgroundTransparency = 1
	icon.Parent = row
	if type(role) == "string" and CrewHire.Roles[role] then
		Glyph.draw(CrewHire.Roles[role].glyph, icon, roleColor(role))
	end
	local stars = Instance.new("Frame")
	stars.Size = UDim2.fromOffset(60, 24)
	stars.BackgroundTransparency = 1
	stars.Parent = row
	starRow(stars, starsOf(model))
end

-- the card (same panel look as DockController's dock price card) ------------------------------

type Card = {
	gui: ScreenGui,
	icon: Frame,
	stars: Frame,
	title: TextLabel,
	wageRow: Frame,
	action: TextButton,
	actionRow: Frame,
	actionConn: RBXScriptConnection?,
}
local card: Card? = nil

local function close()
	if card then
		card.gui.Enabled = false
	end
	openModel = nil
	modal.close()
end

local function shake(b: GuiObject)
	local at = b.Position
	b.Position = at + UDim2.fromOffset(8, 0)
	TweenService:Create(b, TweenInfo.new(0.3, Enum.EasingStyle.Elastic), { Position = at }):Play()
	AudioController.play("UI_Fail")
end

local function row(parent: Instance): Frame
	local r = Instance.new("Frame")
	r.Name = "Row"
	r.Size = UDim2.fromScale(1, 1)
	r.BackgroundTransparency = 1
	r.Parent = parent
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = r
	return r
end

local function text(parent: Instance, s: string, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.AutomaticSize = Enum.AutomaticSize.X
	l.Size = UDim2.fromOffset(0, 26)
	l.BackgroundTransparency = 1
	l.Font = HudTheme.NumberFont
	l.TextSize = HudTheme.scaled(22)
	l.TextColor3 = color
	l.Text = s
	l.Parent = parent
	return l
end

local function coin(parent: Instance, px: number)
	local c = Instance.new("ImageLabel")
	c.Size = UDim2.fromOffset(px, px)
	c.BackgroundTransparency = 1
	c.Image = UiImages.Hud.Coin
	c.Parent = parent
	return c
end

local function buildCard(): Card
	local gui = Instance.new("ScreenGui")
	gui.Name = "CrewCard"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 30
	gui.Enabled = false
	gui.Parent = playerGui
	local panel = HudTheme.panel("Card", UDim2.fromOffset(260, 238), gui)
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -110)
	panel.BackgroundTransparency = HudTheme.PromptTransparency
	HudTheme.padding(panel, 14)
	HudTheme.skin(panel)

	local closeButton = HudTheme.button("Close", "X", UDim2.fromOffset(34, 34), panel)
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.fromScale(1, 0)
	closeButton.BackgroundColor3 = C.panelLight
	closeButton.Activated:Connect(close)

	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.fromScale(0.5, 0)
	icon.Size = UDim2.fromOffset(56, 56)
	icon.BackgroundTransparency = 1
	icon.Parent = panel
	local stars = Instance.new("Frame")
	stars.Name = "Stars"
	stars.AnchorPoint = Vector2.new(0.5, 0)
	stars.Position = UDim2.fromOffset(130, 62)
	stars.Size = UDim2.fromOffset(80, 20)
	stars.BackgroundTransparency = 1
	stars.Parent = panel
	starRow(stars, 0)
	local title = HudTheme.label(
		"Title",
		"",
		UDim2.new(1, 0, 0, 30),
		HudTheme.HeaderFont,
		HudTheme.TextSize.title,
		panel
	)
	title.Position = UDim2.fromOffset(0, 90)
	title.TextXAlignment = Enum.TextXAlignment.Center

	local wageBox = Instance.new("Frame")
	wageBox.Name = "Wage"
	wageBox.Position = UDim2.fromOffset(0, 124)
	wageBox.Size = UDim2.new(1, 0, 0, 26)
	wageBox.BackgroundTransparency = 1
	wageBox.Parent = panel
	local wage = row(wageBox)

	local action =
		HudTheme.button("Action", "", UDim2.new(1, 0, 0, HudTheme.MinButtonHeight), panel)
	action.Position = UDim2.fromOffset(0, 158)
	local actionRow = row(action)

	return {
		gui = gui,
		icon = icon,
		stars = stars,
		title = title,
		wageRow = wage,
		action = action,
		actionRow = actionRow,
		actionConn = nil,
	}
end

local function invoke(remoteName: string, role: string): (boolean, string)
	local remote = Net.init():WaitForChild(remoteName, 5) :: RemoteFunction?
	if not remote then
		return false, "Busy"
	end
	local ok, result = pcall(function()
		return remote:InvokeServer(role)
	end)
	if not ok then
		return false, "Busy"
	end
	local pair = result :: { [number]: any }
	return pair[1] == true, pair[2] or "No"
end

local function act(role: string, hired: boolean)
	local remote = if hired then "Crew_Fire" else "Crew_Hire"
	local ok = invoke(remote, role)
	if ok then
		AudioController.play("Chandlery_Till")
		close()
	elseif card then
		shake(card.action)
	end
end

local function paint(role: string, model: Model)
	local c = card
	if not c then
		return
	end
	local def = CrewHire.Roles[role]
	local hired = model:GetAttribute("CrewHired") == true
	Glyph.draw(def.glyph, c.icon, roleColor(role))
	starRow(c.stars, starsOf(model))
	c.title.Text = role
	for _, child in c.wageRow:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	text(c.wageRow, "Pay", C.textDim)
	coin(c.wageRow, 18)
	text(c.wageRow, `{HudTheme.formatNumber(def.wage)}/day`, C.text)
	for _, child in c.actionRow:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	if hired then
		c.action.Text = "Fire"
		c.action.BackgroundColor3 = FIRE
	else
		c.action.Text = "Hire"
		c.action.BackgroundColor3 = C.accent
		coin(c.actionRow, 22)
		text(c.actionRow, HudTheme.formatNumber(def.price), C.text)
	end
	if c.actionConn then
		c.actionConn:Disconnect()
	end
	c.actionConn = c.action.Activated:Connect(function()
		act(role, hired)
	end)
end

local function open(model: Model)
	local role = model:GetAttribute("CrewRole")
	if type(role) ~= "string" or not CrewHire.Roles[role] then
		return
	end
	card = card or buildCard()
	openModel = model
	paint(role, model)
	local c = card :: Card
	c.gui.Enabled = true
	modal.open(c.action)
	AudioController.play("UI_Click")
end

-- the owner's local prompt: Hire on a seeker, Fire on a hired crew member (a ProximityPrompt
-- lives on a BasePart, so it goes on the root, not the model)
local function attachPrompt(model: Model, hired: boolean)
	if model:FindFirstChild("CrewPrompt", true) then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head")
	if not root or not root:IsA("BasePart") then
		return -- the next scan picks it up
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CrewPrompt"
	prompt.ActionText = if hired then "Fire" else "Hire"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function()
		open(model)
	end)
	prompt.PromptHidden:Connect(function()
		if openModel == model then
			close()
		end
	end)
end

local function ensureTag(model: Model)
	attachBillboard(model)
	if model:GetAttribute("CrewOwner") == player.UserId then
		local hired = model:GetAttribute("CrewHired") == true
		local prompt = model:FindFirstChild("CrewPrompt", true)
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.ActionText = if hired then "Fire" else "Hire"
		else
			attachPrompt(model, hired)
		end
	end
end

local watched: { [Model]: true } = setmetatable({}, { __mode = "k" }) :: any -- model -> tagged

local function scan()
	local f = Workspace:FindFirstChild("CrewHire")
	if not f then
		return
	end
	for _, model in f:GetDescendants() do
		if model:IsA("Model") and model:GetAttribute("CrewRole") ~= nil then
			ensureTag(model)
			if not watched[model] then
				watched[model] = true
				-- owner / hired attributes can land after the model itself
				model.AttributeChanged:Connect(function(name)
					if name == "CrewOwner" or name == "CrewHired" then
						ensureTag(model)
					end
				end)
			end
		end
	end
end

-- the clock above the station door: minutes to the next 20-minute group ------------------------

type Clock = { part: Part, label: TextLabel }
local clock: Clock? = nil

local function clockAt(): CFrame?
	local bay = player:GetAttribute("BayCFrame")
	if typeof(bay) ~= "CFrame" then
		return nil
	end
	-- just above the station wall, out from the door (DockPieces ST: h 16, hd 15, door on -Z)
	return (bay :: CFrame) * Marina.LOTS.Station.cf * CFrame.new(0, 17.2, -(15 + 0.9))
end

local function buildClock()
	local at = clockAt()
	if not at then
		return
	end
	local part = Instance.new("Part")
	part.Name = "CrewClock"
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
	part.CFrame = at
	part.Parent = Workspace
	local gui = Instance.new("BillboardGui")
	gui.Name = "Clock"
	gui.Adornee = part
	gui.Size = UDim2.fromOffset(64, 62)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 90
	gui.Parent = part
	local icon = Instance.new("Frame")
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.fromScale(0.5, 0)
	icon.Size = UDim2.fromOffset(34, 34)
	icon.BackgroundTransparency = 1
	icon.Parent = gui
	Glyph.draw("clock", icon, C.text)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Size = UDim2.fromOffset(64, 22)
	label.Position = UDim2.fromOffset(0, 38)
	label.BackgroundTransparency = 1
	label.Font = HudTheme.NumberFont
	label.TextSize = HudTheme.scaled(13)
	label.TextColor3 = C.text
	label.TextStrokeTransparency = 0.5
	label.Parent = gui
	clock = { part = part, label = label }
end

local function unlocked(): boolean
	return player:GetAttribute("DockStation") == true
end

local function refreshClock()
	local want = unlocked()
	if clock and not want then
		clock.part:Destroy()
		clock = nil
	elseif want and not clock then
		buildClock()
	end
end

local function tickClock()
	if clock then
		local remaining = CrewHire.nextGroupAt(os.time()) - os.time()
		clock.label.Text = string.format("%dm", math.max(0, math.ceil(remaining / 60)))
	end
end

function CrewHireController.Init()
	modal = InputGlyph.modal("CrewCard", close)
end

function CrewHireController.Start()
	refreshClock()
	player:GetAttributeChangedSignal("DockStation"):Connect(refreshClock)
	player:GetAttributeChangedSignal("BayCFrame"):Connect(function()
		if clock then
			clock.part:Destroy()
			clock = nil
		end
		refreshClock()
	end)
	refreshClock()
	task.spawn(function()
		while true do
			scan()
			tickClock()
			task.wait(2)
		end
	end)
end

return CrewHireController
