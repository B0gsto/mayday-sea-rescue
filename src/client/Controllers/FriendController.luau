--!strict
-- FriendController: the friends bonus chip and the crew-up flare (docs/15 H9).
--   * A small two-head icon with `+20%` sits beside the Cash counter (no text); the percent is the
--     server's FriendBonus player attribute (+10% per friend in the server, cap +30%).
--   * While on an operation, a flare glyph by the minimap is a hold action (U / gamepad Y / press
--     and hold on touch). Holding it fires Friend_Flare; the flare rises locally at once, and
--     friends / crewmates get Friend_FlareSeen and see it rise over the operation with an icon
--     pinned to the screen edge pointing at it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioController = require(script.Parent:WaitForChild("AudioController"))
local Net = require(Shared:WaitForChild("Net"))
local UI = script.Parent.Parent:WaitForChild("UI")
local HudTheme = require(UI:WaitForChild("HudTheme"))
local InputGlyph = require(UI:WaitForChild("InputGlyph"))
local Layout = require(UI:WaitForChild("Layout"))
local OceanQuality =
	require(script.Parent.Parent:WaitForChild("Ocean"):WaitForChild("OceanQuality"))
local OpsController = require(script.Parent:WaitForChild("OpsController"))

local C = HudTheme.Colors
local player = Players.LocalPlayer
local HOLD = 0.9 -- s of holding the glyph to fire -- tune
local LOCAL_COLOR = Color3.fromRGB(255, 120, 40)

local FriendController = {}
FriendController.Priority = 60

type Flare = { position: Vector3, color: Color3, expires: number }

local flareSeen: RemoteEvent
local flareOut: RemoteEvent
local button: TextButton
local fill: Frame
local chip: Frame
local chipLabel: TextLabel
local markerGui: ScreenGui
local marker: Frame
local markerDiamond: Frame
local active: Flare? = nil
local pointer = false
local keyDown = false
local progress = 0
local lastFire = -math.huge

local function raiseFlare(position: Vector3, color: Color3)
	local part = Instance.new("Part")
	part.Name = "FriendFlare"
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = Vector3.new(1.2, 1.2, 1.2)
	part.Position = position + Vector3.new(0, 4, 0)
	part.Parent = Workspace
	-- RP-P1: one flare is a gameplay signal, but the free PointLight goes on Low and the sparks
	-- thin out; the Neon ball still reads across the bay.
	local tier = OceanQuality.current().name
	if tier ~= "Low" then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 90
		light.Brightness = 4
		light.Parent = part
	end
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(color)
	sparks.Lifetime = NumberRange.new(1.2, 2)
	sparks.Rate = if tier == "Low" then 8 elseif tier == "Medium" then 18 else 30
	sparks.Speed = NumberRange.new(2, 6)
	sparks.SpreadAngle = Vector2.new(80, 80)
	sparks.Size = NumberSequence.new(0.6, 0)
	sparks.LightEmission = 1
	sparks.Parent = part
	TweenService:Create(
		part,
		TweenInfo.new(2.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = position + Vector3.new(0, 140, 0), Transparency = 1 }
	):Play()
	task.delay(3, function()
		sparks.Enabled = false
	end)
	task.delay(6, function()
		part:Destroy()
	end)
end

local function onFlare(data: any)
	if type(data) ~= "table" or typeof(data.position) ~= "Vector3" then
		return
	end
	local rgb = data.color
	local color = if typeof(rgb) == "table" and typeof(rgb[1]) == "number"
		then Color3.new(rgb[1], rgb[2], rgb[3])
		else LOCAL_COLOR
	raiseFlare(data.position, color)
	active = {
		position = data.position,
		color = color,
		expires = os.clock() + (tonumber(data.seconds) or 45),
	}
	markerDiamond.BackgroundColor3 = color
end

local function updateMarker()
	local flare = active
	local camera = Workspace.CurrentCamera
	if not flare or not camera then
		marker.Visible = false
		return
	end
	if os.clock() > flare.expires then
		active = nil
		marker.Visible = false
		return
	end
	local viewport = camera.ViewportSize
	local point, onScreen = camera:WorldToViewportPoint(flare.position + Vector3.new(0, 80, 0))
	local x, y = point.X, point.Y
	if point.Z <= 0 then
		x, y, onScreen = viewport.X - x, viewport.Y - y, false
	end
	local margin = 30
	if
		onScreen
		and x > margin
		and x < viewport.X - margin
		and y > margin
		and y < viewport.Y - margin
	then
		marker.Position = UDim2.fromOffset(x, y)
	else
		local cx, cy = viewport.X / 2, viewport.Y / 2
		local dx = x - cx
		local dy = y - cy
		if math.abs(dx) + math.abs(dy) < 0.01 then
			dy = -1
		end
		local scale = math.min(
			(viewport.X / 2 - margin) / math.max(math.abs(dx), 0.01),
			(viewport.Y / 2 - margin) / math.max(math.abs(dy), 0.01)
		)
		marker.Position = UDim2.fromOffset(cx + dx * scale, cy + dy * scale)
	end
	marker.Visible = true
end

local function buildHud()
	local gui = Instance.new("ScreenGui")
	gui.Name = "FriendHud"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 17 -- above the minimap (16): the flare sits in its corner
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

	local region = Layout.region(gui, "minimap")
	button = HudTheme.button("Flare", "", UDim2.fromOffset(63, 63), region)
	button.Name = "FlareButton"
	button.AnchorPoint = Vector2.new(0, 0)
	button.Position = UDim2.fromScale(0, 0) -- top-left, clear of the minimap's MAP button
	button.BackgroundColor3 = C.panel
	button.BackgroundTransparency = 0.2
	button.ClipsDescendants = true
	button.Visible = false
	local diamond = Instance.new("Frame")
	diamond.AnchorPoint = Vector2.new(0.5, 0.5)
	diamond.Position = UDim2.fromScale(0.5, 0.42)
	diamond.Size = UDim2.fromOffset(18, 18)
	diamond.Rotation = 45
	diamond.BackgroundColor3 = C.accent
	diamond.BorderSizePixel = 0
	HudTheme.corner(diamond, 2)
	diamond.Parent = button
	local stem = Instance.new("Frame")
	stem.AnchorPoint = Vector2.new(0.5, 0)
	stem.Position = UDim2.fromScale(0.5, 0.6)
	stem.Size = UDim2.fromOffset(4, 14)
	stem.BackgroundColor3 = C.accent
	stem.BorderSizePixel = 0
	stem.Parent = button
	fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.AnchorPoint = Vector2.new(0, 1)
	fill.Position = UDim2.fromScale(0, 1)
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = C.ready
	fill.BackgroundTransparency = 0.55
	fill.BorderSizePixel = 0
	fill.Parent = button
	InputGlyph.chip(button, Enum.KeyCode.U, Enum.KeyCode.ButtonY)

	gui.Parent = player:WaitForChild("PlayerGui")
end

local function buildMarker()
	markerGui = Instance.new("ScreenGui")
	markerGui.Name = "FriendFlareMarker"
	markerGui.ResetOnSpawn = false
	markerGui.DisplayOrder = 18
	markerGui.IgnoreGuiInset = true
	markerGui.Parent = player:WaitForChild("PlayerGui")
	marker = Instance.new("Frame")
	marker.Name = "Marker"
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.Size = UDim2.fromOffset(30, 30)
	marker.BackgroundTransparency = 1
	marker.Visible = false
	marker.Parent = markerGui
	markerDiamond = Instance.new("Frame")
	markerDiamond.AnchorPoint = Vector2.new(0.5, 0.5)
	markerDiamond.Position = UDim2.fromScale(0.5, 0.5)
	markerDiamond.Size = UDim2.fromOffset(15, 15)
	markerDiamond.Rotation = 45
	markerDiamond.BackgroundColor3 = LOCAL_COLOR
	markerDiamond.BorderSizePixel = 0
	HudTheme.corner(markerDiamond, 3)
	markerDiamond.Parent = marker
	HudTheme.stroke(markerDiamond, C.panel, 2)
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

local function held(): boolean
	return pointer or keyDown
end

function FriendController.Init()
	local folder = Net.init()
	flareSeen = folder:WaitForChild("Friend_FlareSeen", 30) :: RemoteEvent
	flareOut = folder:WaitForChild("Friend_Flare", 30) :: RemoteEvent
	buildHud()
	buildMarker()
	syncChip()
	player:GetAttributeChangedSignal("FriendBonus"):Connect(syncChip)
	Layout.onColdOpen(syncChip)
	flareSeen.OnClientEvent:Connect(onFlare)

	button.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			pointer = true
		end
	end)
	button.InputEnded:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			pointer = false
		end
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.U or input.KeyCode == Enum.KeyCode.ButtonY then
			keyDown = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.U or input.KeyCode == Enum.KeyCode.ButtonY then
			keyDown = false
		end
	end)
end

function FriendController.Start()
	attachChip()
	RunService.RenderStepped:Connect(function(dt: number)
		local state = OpsController.GetState()
		local onOperation = state ~= nil and state.state == "Active"
		local show = onOperation
			and not Layout.coldOpen()
			and player:GetAttribute("CinematicPlaying") ~= true
		button.Visible = show
		updateMarker()
		if show and held() then
			progress = math.min(progress + dt / HOLD, 1)
			if progress >= 1 and os.clock() - lastFire > 6 then
				lastFire = os.clock()
				progress = 0
				flareOut:FireServer()
				if state and typeof(state.position) == "Vector3" then
					raiseFlare(state.position, LOCAL_COLOR)
				end
			end
		else
			progress = math.max(0, progress - dt * 3)
		end
		fill.Size = UDim2.fromScale(progress, 1)
	end)
end

return FriendController
