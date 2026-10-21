--!strict
-- StreakReward: the crate-open burst (docs/15 H5): a confetti pop at the chest, the Cash counter
-- rolling up and, on a day-7 crate, a gold star tag. Client only, code-built Parts and 2D frames.
-- The number and the coin are the only text.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AudioController =
	require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("AudioController"))
local Comfort = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("Comfort"))
local HudTheme = require(script.Parent:WaitForChild("HudTheme"))
local OceanQuality =
	require(script.Parent.Parent:WaitForChild("Ocean"):WaitForChild("OceanQuality"))

local StreakReward = {}

local GOLD = Color3.fromRGB(255, 208, 106)
local CONFETTI = {
	Color3.fromRGB(255, 208, 106),
	Color3.fromRGB(255, 120, 30),
	Color3.fromRGB(120, 230, 160),
	Color3.fromRGB(120, 190, 255),
	Color3.fromRGB(255, 255, 255),
}

export type Options = {
	cash: number,
	cashAfter: number,
	weekly: boolean,
	at: Vector3,
}

local function confetti(at: Vector3)
	local host = Instance.new("Part")
	host.Name = "StreakConfetti"
	host.Size = Vector3.new(0.2, 0.2, 0.2)
	host.Transparency = 1
	host.Anchored = true
	host.CanCollide = false
	host.CanQuery = false
	host.CanTouch = false
	host.Position = at
	host.Parent = Workspace
	-- RP-P1: the pop still reads at a quarter of the particles on Low.
	local tier = OceanQuality.current().name
	local emit = if tier == "Low" then 8 elseif tier == "Medium" then 16 else 26
	for i, color in CONFETTI do
		local e = Instance.new("ParticleEmitter")
		e.Name = `Confetti{i}`
		e.Color = ColorSequence.new(color)
		e.LightEmission = 0.35
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.7),
			NumberSequenceKeypoint.new(1, 0.35),
		})
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		e.Lifetime = NumberRange.new(1.2, 2)
		e.Speed = NumberRange.new(16, 30)
		e.SpreadAngle = Vector2.new(70, 70)
		e.Acceleration = Vector3.new(0, -30, 0)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-240, 240)
		e.Rate = 0
		e.Parent = host
		e:Emit(emit)
	end
	task.delay(3, function()
		host:Destroy()
	end)
end

-- Reduce motion: the confetti pop becomes one soft gold fade.
local function softFade(playerGui: Instance)
	local gui = Instance.new("ScreenGui")
	gui.Name = "StreakFade"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 39
	gui.Parent = playerGui
	local f = Instance.new("Frame")
	f.BackgroundColor3 = GOLD
	f.BackgroundTransparency = 0.86
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 1)
	f.Parent = gui
	TweenService:Create(f, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	task.delay(0.7, function()
		gui:Destroy()
	end)
end

local function cashRoll(playerGui: Instance, fromCash: number, cash: number, weekly: boolean)
	local gui = Instance.new("ScreenGui")
	gui.Name = "StreakReward"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 40
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "Roll"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.33)
	frame.Size = UDim2.fromOffset(250, 70)
	frame.BackgroundColor3 = HudTheme.Colors.panel
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Parent = gui
	HudTheme.corner(frame, 14)
	HudTheme.stroke(frame, GOLD, 2)

	local coin = Instance.new("Frame")
	coin.AnchorPoint = Vector2.new(0, 0.5)
	coin.Position = UDim2.fromOffset(22, 44)
	coin.Size = UDim2.fromOffset(46, 46)
	coin.BackgroundColor3 = GOLD
	coin.BorderSizePixel = 0
	coin.Parent = frame
	HudTheme.corner(coin, 23)
	local inner = Instance.new("Frame")
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromOffset(30, 30)
	inner.BackgroundColor3 = Color3.fromRGB(196, 150, 56)
	inner.BorderSizePixel = 0
	inner.Parent = coin
	HudTheme.corner(inner, 15)

	local number = Instance.new("TextLabel")
	number.AnchorPoint = Vector2.new(0, 0.5)
	number.Position = UDim2.fromOffset(84, 44)
	number.Size = UDim2.fromOffset(146, 44)
	number.BackgroundTransparency = 1
	number.Font = Enum.Font.BuilderSansMedium
	number.TextSize = 34
	number.TextColor3 = GOLD
	number.TextXAlignment = Enum.TextXAlignment.Left
	number.Text = HudTheme.formatNumber(fromCash)
	number.Parent = frame

	local word = Instance.new("TextLabel")
	word.Position = UDim2.fromOffset(84, 66)
	word.Size = UDim2.fromOffset(146, 20)
	word.BackgroundTransparency = 1
	word.Font = Enum.Font.BuilderSans
	word.TextSize = 15
	word.TextColor3 = HudTheme.Colors.textDim
	word.TextXAlignment = Enum.TextXAlignment.Left
	word.Text = "Cash"
	word.Parent = frame

	if weekly then
		local star = Instance.new("TextLabel")
		star.Position = UDim2.new(1, -30, 0, 8)
		star.Size = UDim2.fromOffset(24, 24)
		star.BackgroundTransparency = 1
		star.Font = Enum.Font.BuilderSansMedium
		star.TextSize = 22
		star.TextColor3 = GOLD
		star.Text = "★"
		star.Parent = frame
	end

	TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Back), {
		Size = UDim2.fromOffset(250, 108),
	}):Play()

	local amount = math.max(0, cash - fromCash)
	local shown = fromCash
	local t = 0
	local conn: RBXScriptConnection? = nil
	conn = RunService.Heartbeat:Connect(function(dt: number)
		t = math.min(t + dt / 1.1, 1)
		local q = 1 - (1 - t) ^ 3
		shown = fromCash + math.floor(amount * q + 0.5)
		number.Text = HudTheme.formatNumber(shown)
		if t >= 1 then
			if conn then
				conn:Disconnect()
				conn = nil
			end
			number.Text = HudTheme.formatNumber(cash)
			task.delay(1.8, function()
				TweenService:Create(frame, TweenInfo.new(0.5), {
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.5, 0.28),
				}):Play()
				TweenService:Create(number, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
				TweenService:Create(word, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
				task.delay(0.6, function()
					gui:Destroy()
				end)
			end)
		end
	end)
end

function StreakReward.play(playerGui: Instance, opts: Options)
	if Comfort.reducedMotion() then
		softFade(playerGui)
	else
		confetti(opts.at)
	end
	AudioController.play("Crate_Lid", opts.at, 1, 1)
	task.delay(0.18, function()
		AudioController.play("Cash_Coins", opts.at, 1, 1)
	end)
	if opts.weekly then
		task.delay(0.35, function()
			AudioController.play("Music_CrateFanfare", nil, 1, 1)
		end)
	end
	cashRoll(playerGui, opts.cashAfter - opts.cash, opts.cashAfter, opts.weekly)
end

return StreakReward
