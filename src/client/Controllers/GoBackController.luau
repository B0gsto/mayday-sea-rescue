--!strict
-- GoBackController (docs/30 section 1): the big Go back button (HudLayout "goback"; R, gamepad right stick click,
-- touch), shown by Boat/GoBack's rule while driving away from home. The press goes to the server (Net GoBack), which
-- answers everyone aboard: "Charge" widens the camera with a whoosh and wipes the button over 1.5 s; a sea-blue veil
-- covers the jump; "Land" drops the veil on the craft at home, "Cancel" just lets go. Reduce motion: no FOV and no
-- shake (Camera/Shake itself goes quiet), the veil stays since a bare jump cut is worse. The first survivor ever aboard
-- gets one steady green arrow on the button (docs/30 section 4), gone at the first press.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GoBack = require(Shared:WaitForChild("Boat"):WaitForChild("GoBack"))
local Net = require(Shared:WaitForChild("Net"))
local SubRig = require(Shared:WaitForChild("Sub"):WaitForChild("Rig"))
local UiImages = require(Shared:WaitForChild("Config"):WaitForChild("UiImages"))

local AudioController = require(script.Parent.AudioController)
local CameraController = require(script.Parent.CameraController)
local HeliController = require(script.Parent.HeliController)
local ClientRoot = script.Parent.Parent
local Comfort = require(ClientRoot:WaitForChild("Camera"):WaitForChild("Comfort"))
local InputGlyph = require(ClientRoot:WaitForChild("UI"):WaitForChild("InputGlyph"))
local Layout = require(ClientRoot:WaitForChild("UI"):WaitForChild("Layout"))
local Shake = require(ClientRoot:WaitForChild("Camera"):WaitForChild("Shake"))
local Style = require(ClientRoot:WaitForChild("UI"):WaitForChild("Kit"):WaitForChild("Style"))
local VFXKit = require(ClientRoot:WaitForChild("VFX"):WaitForChild("VFXKit"))

local ACTION = "GoBack"
local VEIL_IN = 0.2 -- s before the landing -- tune
local VEIL_OUT = 0.3
local DIM = Color3.fromRGB(150, 150, 165) -- the button under the charge wipe
local VEIL_COLOR = Color3.fromRGB(0, 160, 175)

local GoBackController = {}

local player = Players.LocalPlayer
local charging = false
local run = 0 -- the current charge: its delayed steps check they still belong to it
local chargedAt = 0
local shown = false
local root: Frame
local face: ImageButton
local wipe: UIGradient
local veil: Frame
local arrow: ImageLabel
local arrowShown = false
local arrowDone = false
local fov, fovApplied = 0, 0

-- The craft whose DriverSeat we sit in.
local function driven(): Model?
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local model = seat and seat.Name == "DriverSeat" and seat.Parent
	return if model
			and model:IsA("Model")
			and model:GetAttribute("VehicleId") ~= nil
		then model
		else nil
end

local function press()
	if shown and not charging then
		Net.event("GoBack"):FireServer()
	end
end

-- One pop, one sound, no looping: paired feedback for "someone is aboard, this goes home".
local function setArrow(on: boolean)
	if on == arrowShown then
		return
	end
	arrowShown = on
	Style.pop(arrow, on)
	if on then
		AudioController.play("UI_Prompt")
	end
end

local function refresh()
	local model = driven()
	local want = charging
		or (
			model ~= nil
			and GoBack.refusal({
					driving = true,
					coldOpenDone = player:GetAttribute("ColdOpenDone") == true,
					survivors = tonumber(model:GetAttribute("SurvivorCount")) or 0,
					testRide = player:GetAttribute("TestRide") ~= nil,
					at = model:GetPivot().Position,
					bay = player:GetAttribute("BayCFrame"),
				})
				== nil
		)
	setArrow(
		want
			and not (charging or arrowDone)
			and model ~= nil
			and (tonumber(model:GetAttribute("SurvivorCount")) or 0) > 0
			and (tonumber(player:GetAttribute("Rescued")) or 0) == 0
	)
	if want == shown then
		return
	end
	shown = want
	Style.pop(root, want)
	if want then
		ContextActionService:BindAction(ACTION, function(_, state: Enum.UserInputState)
			if state == Enum.UserInputState.Begin then
				press()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.R, Enum.KeyCode.ButtonR3)
	else
		ContextActionService:UnbindAction(ACTION)
	end
end

local function fade(to: number, seconds: number)
	TweenService:Create(
		veil,
		TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{ BackgroundTransparency = to }
	):Play()
end

local function finish()
	charging = false
	run += 1
	fade(1, VEIL_OUT)
	face.ImageColor3 = Color3.new(1, 1, 1)
	TweenService:Create(wipe, TweenInfo.new(0.15), { Offset = Vector2.new(-0.5, 0) }):Play()
end

local function onCharge()
	arrowDone = true
	setArrow(false)
	charging = true
	run += 1
	local mine = run
	chargedAt = os.clock()
	face.ImageColor3 = DIM
	wipe.Offset = Vector2.new(-0.5, 0)
	TweenService:Create(
		wipe,
		TweenInfo.new(GoBack.CHARGE, Enum.EasingStyle.Linear),
		{ Offset = Vector2.new(0.5, 0) }
	):Play()
	AudioController.play("FX_Whoosh", nil, nil, 0.8)
	Shake.add({ magnitude = 0.6, roughness = 14, fadeIn = GoBack.CHARGE - 0.3, time = 0.3 })
	task.delay(GoBack.CHARGE - VEIL_IN, function()
		if run == mine then
			fade(0, VEIL_IN)
		end
	end)
	-- never left under the veil: every charge ends in a Cancel or a Land, unless this client stopped being told
	task.delay(GoBack.CHARGE + GoBack.LAND_HOLD + 1, function()
		if run == mine then
			finish()
		end
	end)
end

local function onLand()
	local model = driven()
	if model then
		SubRig.clear(model) -- the sub's held yaw and depth belong to the old spot
	end
	HeliController.Landed()
	CameraController.SnapBehind()
	finish()
	local rider = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if rider and rider:IsA("BasePart") then
		VFXKit.play("go_back_land", CFrame.new(rider.Position.X, 0, rider.Position.Z))
	end
end

function GoBackController.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "GoBack"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	Layout.prepare(gui)
	root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.Parent = Layout.region(gui, "goback")
	face = Instance.new("ImageButton")
	face.Name = "Face"
	face.BackgroundTransparency = 1
	face.Image = UiImages.Hud.GoBack
	face.ScaleType = Enum.ScaleType.Fit
	face.Size = UDim2.fromScale(1, 1)
	face.Parent = root
	Style.press(face, press)
	face.Selectable = false -- gamepad: its own button, not a stop on the menu's focus path
	local fill = Instance.new("ImageLabel")
	fill.Name = "Wipe"
	fill.BackgroundTransparency = 1
	fill.Image = UiImages.Hud.GoBack
	fill.ScaleType = Enum.ScaleType.Fit
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = face
	wipe = Instance.new("UIGradient")
	wipe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(0.501, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	wipe.Offset = Vector2.new(-0.5, 0) -- all clear; +0.5 is all shown
	wipe.Parent = fill
	local words = Style.label(face, "Go back", 34)
	words.AnchorPoint = Vector2.new(1, 0.5)
	words.Position = UDim2.fromScale(0.95, 0.5)
	words.Size = UDim2.fromScale(0.64, 0.7)
	InputGlyph.chip(face, Enum.KeyCode.R, Enum.KeyCode.ButtonR3)
	arrow = Instance.new("ImageLabel")
	arrow.Name = "Arrow"
	arrow.BackgroundTransparency = 1
	arrow.Image = UiImages.Markers.BuildArrow -- points down at the button
	arrow.ScaleType = Enum.ScaleType.Fit
	arrow.AnchorPoint = Vector2.new(0.5, 1)
	arrow.Position = UDim2.fromScale(0.5, -0.04)
	arrow.SizeConstraint = Enum.SizeConstraint.RelativeYY
	arrow.Size = UDim2.fromScale(1.1, 1.1)
	arrow.Visible = false
	arrow.Parent = root
	gui.Parent = player:WaitForChild("PlayerGui")

	local veilGui = Instance.new("ScreenGui")
	veilGui.Name = "GoBackVeil"
	veilGui.IgnoreGuiInset = true
	veilGui.ResetOnSpawn = false
	veilGui.DisplayOrder = 99 -- over the HUD, under ColdOpenFade
	veil = Instance.new("Frame")
	veil.BackgroundColor3 = VEIL_COLOR
	veil.BackgroundTransparency = 1
	veil.BorderSizePixel = 0
	veil.Size = UDim2.fromScale(1, 1)
	veil.Parent = veilGui
	veilGui.Parent = player:WaitForChild("PlayerGui")

	Net.event("GoBack").OnClientEvent:Connect(function(phase: string)
		if phase == "Charge" then
			onCharge()
		elseif phase == "Land" then
			onLand()
		elseif charging then
			finish()
			AudioController.play("UI_Back")
		end
	end)

	-- the FOV goes on after the camera scripts and comes off before them, so they never ease from it (as Camera/Shake)
	RunService:BindToRenderStep("GoBackFovUndo", Enum.RenderPriority.First.Value, function()
		local camera = Workspace.CurrentCamera
		if camera and fovApplied ~= 0 then
			camera.FieldOfView -= fovApplied
		end
		fovApplied = 0
	end)
	RunService:BindToRenderStep(
		"GoBackFovApply",
		Enum.RenderPriority.Camera.Value + 1,
		function(dt: number)
			local camera = Workspace.CurrentCamera
			if charging then
				local k = math.clamp((os.clock() - chargedAt) / GoBack.CHARGE, 0, 1)
				fov = GoBack.CHARGE_FOV * k * k
			else
				fov = if fov < 0.1 then 0 else fov * math.exp(-8 * dt)
			end
			if camera and fov ~= 0 and not Comfort.reducedMotion() then
				fovApplied = fov
				camera.FieldOfView += fovApplied
			end
		end
	)

	while true do
		refresh()
		task.wait(0.2)
	end
end

return GoBackController
