--!strict
-- FriendController: the friends bonus chip (docs/15 H9). A small two-head icon with `+20%` sits
-- beside the Cash counter (no text); the percent is the server's FriendBonus player attribute
-- (+10% per friend in the server, cap +30%).
local Players = game:GetService("Players")

local AudioController = require(script.Parent:WaitForChild("AudioController"))
local UI = script.Parent.Parent:WaitForChild("UI")
local HudTheme = require(UI:WaitForChild("HudTheme"))
local Layout = require(UI:WaitForChild("Layout"))

local C = HudTheme.Colors
local player = Players.LocalPlayer

local FriendController = {}
FriendController.Priority = 60

local chip: Frame
local chipLabel: TextLabel

local function buildHud()
	local gui = Instance.new("ScreenGui")
	gui.Name = "FriendHud"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 17
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	Layout.prepare(gui)
	local status = Layout.region(gui, "status")

	chip = Instance.new("Frame")
	chip.Name = "FriendBonus"
	chip.AnchorPoint = Vector2.new(1, 0)
	chip.Size = UDim2.fromOffset(64, 24)
	chip.BackgroundColor3 = C.panel
	chip.BackgroundTransparency = 0.2
	chip.BorderSizePixel = 0
	chip.Visible = false
	HudTheme.corner(chip, 9)
	chip.Parent = status
	local heads = { { 0.16, 0.42, 6 }, { 0.28, 0.5, 4 } }
	for _, h in heads do
		local head = Instance.new("Frame")
		head.AnchorPoint = Vector2.new(0.5, 0.5)
		head.Position = UDim2.fromScale(h[1], h[2])
		head.Size = UDim2.fromOffset(h[3], h[3])
		head.BackgroundColor3 = C.text
		head.BorderSizePixel = 0
		HudTheme.corner(head, 99)
		head.Parent = chip
	end
	local body = Instance.new("Frame")
	body.AnchorPoint = Vector2.new(0.5, 0)
	body.Position = UDim2.fromScale(0.16, 0.55)
	body.Size = UDim2.fromOffset(10, 7)
	body.BackgroundColor3 = C.text
	body.BorderSizePixel = 0
	HudTheme.corner(body, 99)
	body.Parent = chip
	local body2 = body:Clone()
	body2.Position = UDim2.fromScale(0.28, 0.62)
	body2.Size = UDim2.fromOffset(6, 5)
	body2.BackgroundTransparency = 0.4
	body2.Parent = chip
	chipLabel = Instance.new("TextLabel")
	chipLabel.Position = UDim2.fromOffset(18, 0)
	chipLabel.Size = UDim2.fromOffset(44, 24)
	chipLabel.BackgroundTransparency = 1
	chipLabel.Font = HudTheme.HeaderFont
	chipLabel.TextSize = 20
	chipLabel.TextColor3 = C.gold
	chipLabel.TextXAlignment = Enum.TextXAlignment.Left
	chipLabel.Text = ""
	chipLabel.Parent = chip

	gui.Parent = player:WaitForChild("PlayerGui")
end

local lastBonus: number? = nil

local function syncChip()
	local percent = player:GetAttribute("FriendBonus")
	local value = if typeof(percent) == "number" then math.floor(percent) else 0
	local previous = lastBonus
	if previous ~= nil and value > previous then
		AudioController.play("UI_FriendPop", nil, 1, 1.04)
	end
	lastBonus = value
	chipLabel.Text = `+{value}%`
	chip.Visible = value > 0 and not Layout.coldOpen()
end

local function attachChip()
	local playerGui = player:WaitForChild("PlayerGui", 10)
	local hud = playerGui and (playerGui:FindFirstChild("Hud") or playerGui:WaitForChild("Hud", 10))
	-- the wallet's cash row lays the chip out after the amount (UIListLayout)
	local row = hud and hud:FindFirstChild("CashRow", true)
	if row then
		chip.LayoutOrder = 3
		chip.AnchorPoint = Vector2.zero
		chip.Parent = row
	end
end

function FriendController.Init()
	buildHud()
	syncChip()
	player:GetAttributeChangedSignal("FriendBonus"):Connect(syncChip)
	Layout.onColdOpen(syncChip)
end

function FriendController.Start()
	attachChip()
end

return FriendController
