--!strict
-- FuelGauge (docs/31 C): the fuel can and its bar just over Go back, shown while you drive. Reads FuelService's player
-- attributes Fuel / FuelMax / FuelBurn (1, 5 or 25; 0 in the Shallows). No numbers: green, yellow under 50 %, red under
-- 20 %; the bar's drain speed is the burn and 1-2 chevrons by the can show x5 / x25. At 20 %: one pop of the can, one
-- beep, one Go back bounce. The burn stepping up: one shake of the can. Empty: the fuel_sputter VFX at the boat. A
-- refuel: the bar fills in ~0.4 s with the fuel_fill VFX. Reduce motion: no pop, shake or bounce; sounds and colours stay.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UiImages = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UiImages")
)

local ClientRoot = script.Parent.Parent
local AudioController =
	require(ClientRoot:WaitForChild("Controllers"):WaitForChild("AudioController"))
local Comfort = require(ClientRoot:WaitForChild("Camera"):WaitForChild("Comfort"))
local Layout = require(script.Parent:WaitForChild("Layout"))
local Style = require(script.Parent:WaitForChild("Kit"):WaitForChild("Style"))
local VFXKit = require(ClientRoot:WaitForChild("VFX"):WaitForChild("VFXKit"))

local player = Players.LocalPlayer

local FuelGauge = {}

local LOW, HALF = 0.2, 0.5
local REFILL = 0.1 -- a jump up by more than this share of the tank is a refuel
local RATE = 8 -- 1/s: the bar eases to the tank this fast, so a full refill lands in ~0.4 s
local GREEN = Color3.fromRGB(88, 214, 96)
local YELLOW = Color3.fromRGB(255, 210, 60)
local RED = Color3.fromRGB(240, 58, 52)
local INK = Color3.fromRGB(20, 18, 28)
local CAN = 40 -- px

local function share(): number?
	local fuel, max = player:GetAttribute("Fuel"), player:GetAttribute("FuelMax")
	if type(fuel) ~= "number" or type(max) ~= "number" or max <= 0 then
		return nil
	end
	return math.clamp(fuel / max, 0, 1)
end

-- driving: the craft you drive (GoBackController's), bounce: one bounce of the Go back button
function FuelGauge.mount(region: Frame, driving: () -> Model?, bounce: () -> ())
	local root = Instance.new("Frame")
	root.Name = "FuelGauge"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Position = UDim2.new(0.5, 0, 0, -6)
	root.Size = UDim2.new(0.8, 0, 0, CAN)
	root.Visible = false
	root.Parent = region

	local can = Instance.new("Frame") -- the icon's box: it pops and shakes
	can.Name = "Can"
	can.BackgroundTransparency = 1
	can.Size = UDim2.fromOffset(CAN, CAN)
	can.Parent = root
	Style.icon(can, "fuel")

	local chevrons: { ImageLabel } = {}
	for i = 1, 2 do
		local c = Instance.new("ImageLabel")
		c.Name = `Chevron{i}`
		c.BackgroundTransparency = 1
		c.Image = UiImages.Hud.FuelChevron
		c.ScaleType = Enum.ScaleType.Fit
		c.Position = UDim2.fromOffset(CAN + 2, if i == 1 then 21 else 5) -- the second stacks above the first
		c.Size = UDim2.fromOffset(20, 15)
		c.Visible = false
		c.Parent = root
		chevrons[i] = c
	end

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundColor3 = INK
	track.BackgroundTransparency = 0.15
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.new(0, CAN + 26, 0.5, 0)
	track.Size = UDim2.new(1, -(CAN + 26), 0, 20)
	Style.corner(track, 10)
	track.Parent = root
	local pad = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(pad :: any)[side] = UDim.new(0, 3)
	end
	pad.Parent = track
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = GREEN
	fill.Size = UDim2.fromScale(1, 1)
	Style.corner(fill, 7)
	fill.Parent = track
	local lip = Instance.new("UIGradient") -- a lit top over a darker lip, like the sticker art
	lip.Rotation = 90
	lip.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170))
	lip.Parent = fill

	local shown = 1 -- the bar's share, easing to the tank
	local last: number? = nil -- the tank's share at the last change
	local lastBurn = 0

	local function boat(): CFrame?
		local model = driving()
		return if model then model:GetPivot() else nil
	end

	local function shake()
		if Comfort.reducedMotion() then
			return
		end
		can.Position = UDim2.fromOffset(0, 0)
		TweenService:Create(
			can,
			TweenInfo.new(0.05, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true),
			{ Position = UDim2.fromOffset(6, 0) }
		):Play()
	end

	player:GetAttributeChangedSignal("Fuel"):Connect(function()
		local f = share()
		local was = last
		last = f
		if not (f and was) then
			return
		end
		local at = boat()
		if f - was > REFILL then
			if at then
				VFXKit.play("fuel_fill", at)
			end
		elseif f <= 0 and was > 0 then
			if at then
				VFXKit.play("fuel_sputter", at)
			end
		elseif f < LOW and was >= LOW and root.Visible then
			AudioController.play("Fuel_Low")
			if not Comfort.reducedMotion() then
				Style.pop(can, true)
				bounce()
			end
		end
	end)

	local function onBurn()
		local burn = tonumber(player:GetAttribute("FuelBurn")) or 0
		chevrons[1].Visible = burn >= 5
		chevrons[2].Visible = burn >= 25
		if burn > lastBurn and burn >= 5 and root.Visible then
			shake() -- with the zone banner, so crossing the line and the faster burn read together
		end
		lastBurn = burn
	end
	player:GetAttributeChangedSignal("FuelBurn"):Connect(onBurn)
	onBurn()

	RunService.Heartbeat:Connect(function(dt: number)
		local f = share()
		local on = f ~= nil and driving() ~= nil and not Layout.coldOpen()
		if on ~= root.Visible then
			root.Visible = on
			shown = f or shown -- appear at the tank, never drain in from full
		end
		if not (on and f) then
			return
		end
		last = last or f
		shown += (f - shown) * math.min(1, dt * RATE)
		fill.Size = UDim2.fromScale(shown, 1)
		fill.BackgroundColor3 = if shown < LOW then RED elseif shown < HALF then YELLOW else GREEN
	end)
end

return FuelGauge
