--!strict
-- OnboardingReward: the first reward burst (docs/16 B1): the Cash counter rolls, its coins fly
-- into the HUD wallet (CashBurst), a confetti pop, and Bosun leaps aboard. Client only, one shot. Mounted by OnboardingController
-- when the cold open ends on a rescue. Everything is code-built Parts and 2D frames (no text
-- except the number and the one word "Cash").
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AudioController =
	require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("AudioController"))
local CashBurst = require(script.Parent:WaitForChild("CashBurst"))
local HudTheme = require(script.Parent:WaitForChild("HudTheme"))
local OceanQuality =
	require(script.Parent.Parent:WaitForChild("Ocean"):WaitForChild("OceanQuality"))

local OnboardingReward = {}

local GOLD = Color3.fromRGB(255, 208, 106)
local CONFETTI = {
	Color3.fromRGB(255, 208, 106),
	Color3.fromRGB(255, 120, 30),
	Color3.fromRGB(120, 230, 160),
	Color3.fromRGB(120, 190, 255),
	Color3.fromRGB(255, 255, 255),
}
local COAT = Color3.fromRGB(30, 28, 30)
local HARNESS = Color3.fromRGB(255, 102, 0)

local function part(parent: Instance, size: Vector3, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = material
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function confetti(at: Vector3)
	local host = part(Workspace, Vector3.new(0.2, 0.2, 0.2), GOLD, Enum.Material.SmoothPlastic)
	host.Transparency = 1
	host.Position = at
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

-- A small code-built Bosun (plain Parts, the orange harness) leaps in an arc and sits.
local function bosunJump(from: Vector3, to: Vector3)
	local model = Instance.new("Model")
	model.Name = "OnboardingBosun"
	model.Parent = Workspace
	local body = part(model, Vector3.new(1, 0.9, 2.2), COAT, Enum.Material.Fabric)
	body.Name = "Body"
	model.PrimaryPart = body
	local head = part(model, Vector3.new(0.8, 0.75, 0.8), COAT, Enum.Material.Fabric)
	head.Name = "Head"
	local harness = part(model, Vector3.new(1.04, 0.34, 0.7), HARNESS, Enum.Material.SmoothPlastic)
	harness.Name = "Harness"
	local tail = part(model, Vector3.new(0.18, 0.18, 1.2), COAT, Enum.Material.Fabric)
	tail.Name = "Tail"
	for i, x in { -0.34, 0.34 } do
		for j, z in { -0.7, 0.7 } do
			local leg = part(model, Vector3.new(0.22, 0.75, 0.22), COAT, Enum.Material.Fabric)
			leg.Name = `Leg{i}_{j}`
			leg.Position = Vector3.new(x, 0.45, z)
		end
	end
	local function place(cf: CFrame)
		body.CFrame = cf
		head.CFrame = cf * CFrame.new(0, 0.72, -1.2)
		harness.CFrame = cf * CFrame.new(0, 0.25, 0.25)
		tail.CFrame = cf * CFrame.new(0, 0.35, 1.35) * CFrame.Angles(math.rad(-20), 0, 0)
	end
	local look = (to - from) * Vector3.new(1, 0, 1)
	local facing = if look.Magnitude > 0.1
		then CFrame.lookAt(from, from + look.Unit)
		else CFrame.new(from)
	place(facing)
	local start, finish = from + Vector3.new(0, 0.9, 0), to + Vector3.new(0, 1.6, 0)
	local t = 0
	local conn: RBXScriptConnection? = nil
	conn = RunService.Heartbeat:Connect(function(dt: number)
		t = math.min(t + dt / 1.15, 1)
		local p = start:Lerp(finish, t) + Vector3.new(0, math.sin(t * math.pi) * 5, 0)
		local cf = CFrame.lookAt(
			p,
			p + if facing.LookVector.Magnitude > 0 then facing.LookVector else Vector3.new(0, 0, -1)
		)
		place(cf * CFrame.Angles(math.sin(t * math.pi) * math.rad(-18), 0, 0))
		if t >= 1 then
			if conn then
				conn:Disconnect()
			end
			task.delay(2.4, function()
				for _, p2 in model:GetDescendants() do
					if p2:IsA("BasePart") then
						TweenService:Create(p2, TweenInfo.new(0.5), { Transparency = 1 }):Play()
					end
				end
				task.delay(0.6, function()
					model:Destroy()
				end)
			end)
		end
	end)
end

local function cashRoll(parent: Instance, fromCash: number, cash: number, seconds: number)
	local gui = Instance.new("ScreenGui")
	gui.Name = "OnboardingReward"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 40
	gui.Parent = parent

	local frame = Instance.new("Frame")
	frame.Name = "Roll"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.14) -- top centre: at 0.33 it sat behind your head (playtest 2026-10-26)
	frame.Size = UDim2.fromOffset(250, 108)
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
	word.AnchorPoint = Vector2.new(0, 0)
	word.Position = UDim2.fromOffset(84, 66)
	word.Size = UDim2.fromOffset(146, 20)
	word.BackgroundTransparency = 1
	word.Font = Enum.Font.BuilderSans
	word.TextSize = 15
	word.TextColor3 = HudTheme.Colors.textDim
	word.TextXAlignment = Enum.TextXAlignment.Left
	word.Text = "Cash"
	word.Parent = frame

	frame.Size = UDim2.fromOffset(250, 70)
	TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Back), {
		Size = UDim2.fromOffset(250, 108),
	}):Play()
	AudioController.play("UI_Pickup")

	local amount = math.max(0, cash - fromCash)
	local shown = fromCash
	local t = 0
	local conn: RBXScriptConnection? = nil
	conn = RunService.Heartbeat:Connect(function(dt: number)
		t = math.min(t + dt / seconds, 1)
		local q = 1 - (1 - t) ^ 3
		shown = fromCash + math.floor(amount * q + 0.5)
		number.Text = HudTheme.formatNumber(shown)
		if t >= 1 then
			if conn then
				conn:Disconnect()
			end
			number.Text = HudTheme.formatNumber(cash)
			-- the Cash leaves the panel for the wallet: where it lives from now on
			local from = coin.AbsolutePosition + coin.AbsoluteSize / 2
			CashBurst.playAt(parent, from, amount, false)
			AudioController.play("UI_Pickup")
			task.delay(1.8, function()
				TweenService:Create(frame, TweenInfo.new(0.5), {
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.5, 0.09),
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

local function yoursTag(vehicle: Model)
	local root = vehicle.PrimaryPart
	if not root then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "OnboardingYours"
	bb.Size = UDim2.fromOffset(74, 26)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 250
	bb.Adornee = root
	bb.Parent = root
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.BuilderSansMedium
	label.TextSize = 18
	label.TextColor3 = GOLD
	label.TextStrokeTransparency = 0.4
	label.Text = "YOURS"
	label.Parent = bb
	task.delay(6, function()
		if bb.Parent then
			TweenService:Create(label, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
			task.delay(0.6, function()
				bb:Destroy()
			end)
		end
	end)
end

local function ownedJetSki(player: Player): Model?
	local vehicles = Workspace:FindFirstChild("Vehicles")
	for _, m in if vehicles then vehicles:GetChildren() else {} do
		if
			m:IsA("Model")
			and m:GetAttribute("Owner") == player.UserId
			and m:GetAttribute("VehicleId") == "JetSki"
			and m.PrimaryPart
		then
			return m
		end
	end
	return nil
end

export type RewardOptions = {
	cash: number,
	fromCash: number,
	anchor: Vector3?,
}

function OnboardingReward.play(playerGui: Instance, opts: RewardOptions)
	local player = Players.LocalPlayer
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local at = opts.anchor
		or (if root and root:IsA("BasePart") then root.Position else Vector3.new(0, 10, 0))
	local vehicle = ownedJetSki(player)
	local jumpTo = if vehicle and vehicle.PrimaryPart
		then vehicle.PrimaryPart.Position + Vector3.new(0, 1.2, 0)
		else at + Vector3.new(0, 0, 3)
	confetti(at + Vector3.new(0, 4, 0))
	bosunJump(at + Vector3.new(3, 0, -4), jumpTo)
	AudioController.play("UI_Success")
	if vehicle then
		yoursTag(vehicle)
	end
	cashRoll(playerGui, opts.fromCash, opts.cash, 1.1)
end

return OnboardingReward
