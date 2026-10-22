--!strict
-- CashBurst: coins fly from a world spot into the Cash counter (docs/15 H6). The strongbox
-- collects, the coins arc to the top-right HUD where the wallet lives, and a short +number floats
-- up. Icons and one number only. Client only.

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Comfort = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("Comfort"))
local HudTheme = require(script.Parent:WaitForChild("HudTheme"))

local GOLD = Color3.fromRGB(255, 208, 106)
local COINS = 12

local CashBurst = {}

local function coinAt(parent: Instance, position: Vector2, size: number): Frame
	local coin = Instance.new("Frame")
	coin.Name = "Coin"
	coin.AnchorPoint = Vector2.new(0.5, 0.5)
	coin.Position = UDim2.fromOffset(position.X, position.Y)
	coin.Size = UDim2.fromOffset(size, size)
	coin.BackgroundColor3 = GOLD
	coin.BorderSizePixel = 0
	coin.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = coin
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.new(1, -6, 1, -6)
	inner.BackgroundColor3 = Color3.fromRGB(214, 164, 62)
	inner.BorderSizePixel = 0
	inner.Parent = coin
	local innerCorner = Instance.new("UICorner")
	innerCorner.CornerRadius = UDim.new(1, 0)
	innerCorner.Parent = inner
	return coin
end

-- `from` is the strongbox board in the world; nothing plays when it is off screen.
function CashBurst.play(playerGui: Instance, from: Vector3, cash: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local point, visible = camera:WorldToViewportPoint(from)
	if not visible then
		return
	end
	CashBurst.playAt(playerGui, Vector2.new(point.X, point.Y), cash)
end

-- Same burst from a screen point (a debrief's pay line); the coins still land on the HUD counter.
function CashBurst.playAt(playerGui: Instance, start: Vector2, cash: number, showAmount: boolean?)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	local gui = Instance.new("ScreenGui")
	gui.Name = "CashBurst"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 41
	gui.Parent = playerGui

	local hud = playerGui:FindFirstChild("Hud")
	local wallet = hud and hud:FindFirstChild("Wallet", true)
	local slot = wallet and wallet:FindFirstChild("Coin", true)
	local target = if slot and slot:IsA("GuiObject")
		then slot.AbsolutePosition + slot.AbsoluteSize / 2
		else Vector2.new(110, viewport.Y - 300)
	local reduced = Comfort.reducedMotion()
	local rng = Random.new()
	for i = 1, (if reduced then 0 else COINS) do
		local jitter = Vector2.new(rng:NextNumber(-14, 14), rng:NextNumber(-10, 14))
		local coin = coinAt(gui, start + jitter, rng:NextInteger(12, 20))
		local tween = TweenService:Create(
			coin,
			TweenInfo.new(0.85 + i * 0.025, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				Position = UDim2.fromOffset(target.X, target.Y),
				Size = UDim2.fromOffset(8, 8),
				BackgroundTransparency = 0.15,
			}
		)
		task.delay((i - 1) * 0.025, function()
			tween:Play()
		end)
	end

	if showAmount ~= false then
		local plus = Instance.new("TextLabel")
		plus.Name = "Amount"
		plus.AnchorPoint = Vector2.new(0.5, 0.5)
		plus.Position = UDim2.fromOffset(start.X, start.Y - 46)
		plus.Size = UDim2.fromOffset(180, 44)
		plus.BackgroundTransparency = 1
		plus.Font = Enum.Font.BuilderSansBold
		plus.TextSize = 34
		plus.TextColor3 = GOLD
		plus.TextStrokeTransparency = 0.55
		plus.Text = `+{HudTheme.formatNumber(cash)}`
		plus.Parent = gui
		TweenService
			:Create(plus, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				-- reduce motion: no rise, just a short fade in place
				Position = UDim2.fromOffset(
					start.X,
					if reduced then start.Y - 46 else start.Y - 94
				),
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			})
			:Play()
	end

	task.delay(3, function()
		gui:Destroy()
	end)
end

return CashBurst
