--!strict
-- GoBackController (docs/30 section 1): the big Go back button (HudLayout "goback"; R, gamepad right stick click,
-- touch), shown by Boat/GoBack's rule while driving away from home. The press goes to the server (Net GoBack), which
-- answers everyone aboard: "Ride" with the route home: this client poses the hull along it every frame (GoBack.pose, the
-- same as the server, but smooth) under a chase shot that widens with speed: a swoosh as it turns, a nitro burst at the
-- launch, a rooster tail at speed, carve spray as it swings into the bay; a sea-blue veil only over a boxed-in route's
-- jump. "Land" hands the camera to the station shot, "Cancel" just lets go. Reduce motion: a third of the widening, no
-- spray trail. The first time anyone is aboard
-- (once per profile: Comfort's saved "GoBackTaught" flag) the button bounces once and a steady green arrow sits on it
-- (docs/30 section 4) until the press or until nobody is aboard; live v40 had 0 Go back presses in 6 sessions.
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
local UpgradeStation = require(Shared:WaitForChild("UpgradeStation"))

local AudioController = require(script.Parent.AudioController)
local CameraController = require(script.Parent.CameraController)
local HeliController = require(script.Parent.HeliController)
local ClientRoot = script.Parent.Parent
local Comfort = require(ClientRoot:WaitForChild("Camera"):WaitForChild("Comfort"))
local FuelGauge = require(ClientRoot:WaitForChild("UI"):WaitForChild("FuelGauge"))
local InputGlyph = require(ClientRoot:WaitForChild("UI"):WaitForChild("InputGlyph"))
local Layout = require(ClientRoot:WaitForChild("UI"):WaitForChild("Layout"))
local Style = require(ClientRoot:WaitForChild("UI"):WaitForChild("Kit"):WaitForChild("Style"))
local VFXKit = require(ClientRoot:WaitForChild("VFX"):WaitForChild("VFXKit"))

local ACTION = "GoBack"
local VEIL_IN = 0.2 -- s before a boxed-in route's jump -- tune
local VEIL_OUT = 0.3
local DIM = Color3.fromRGB(150, 150, 165) -- the button under the charge wipe
local VEIL_COLOR = Color3.fromRGB(0, 160, 175)
local RIDE_FOV = 25 -- degrees the ride shot widens at top speed -- tune

local GoBackController = {}

local player = Players.LocalPlayer
local charging = false
local run = 0 -- the current charge: its delayed steps check they still belong to it
local ride: {
	route: GoBack.Route,
	at: number,
	model: Model,
	length: number,
	from: CFrame, -- the camera when the ride took it
	fov: number,
	yaw: number, -- the shot's heading: the route's, lagged; the hull swings under it into the bay
	last: Vector3,
	launched: boolean,
	spray: number,
}? =
	nil
local shown = false
local root: Frame
local face: ImageButton
local wipe: UIGradient
local veil: Frame
local arrow: ImageLabel
local arrowShown = false
local arrowDone = false
local SEEN = "GoBackTaught"
local seenLoaded = false -- Comfort's saved flags are in: before that hasSeen reads false for everyone

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

-- One bounce of the button (after its own pop; the low-fuel cue too). Reduce motion: none.
local function bounce()
	local sc = face:FindFirstChildOfClass("UIScale") -- Style.press's
	if sc and not Comfort.reducedMotion() then
		sc.Scale = 1.3
		TweenService:Create(
			sc,
			TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
	end
end

-- One pop, one sound, no looping: paired feedback for "someone is aboard, this goes home".
local function setArrow(on: boolean)
	if on == arrowShown then
		return
	end
	arrowShown = on
	Style.pop(arrow, on)
	if not on then
		arrowDone = true -- one lesson per session even before the save lands
		return
	end
	Comfort.markSeen(SEEN)
	AudioController.play("UI_Prompt")
	task.delay(0.3, bounce)
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
					-- SpinCinematic: the client's whole Deep Spin, longer than the server's WheelSpinning
					spinning = player:GetAttribute("WheelSpinning") == true
						or player:GetAttribute("SpinCinematic") == true,
				})
				== nil
		)
	setArrow(
		want
			and not (charging or arrowDone)
			and model ~= nil
			and (tonumber(model:GetAttribute("SurvivorCount")) or 0) > 0
			and seenLoaded
			and (arrowShown or not Comfort.hasSeen(SEEN))
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
	if ride then
		CameraController.ClearOverride()
		Workspace.CurrentCamera.FieldOfView = ride.fov
		ride = nil
	end
	fade(1, VEIL_OUT)
	face.ImageColor3 = Color3.new(1, 1, 1)
	TweenService:Create(wipe, TweenInfo.new(0.15), { Offset = Vector2.new(-0.5, 0) }):Play()
end

local function yawOf(v: Vector3): number
	return math.atan2(-v.X, -v.Z)
end

local function onRide(route: GoBack.Route)
	arrowDone = true
	setArrow(false)
	charging = true
	run += 1
	local mine = run
	face.ImageColor3 = DIM
	wipe.Offset = Vector2.new(-0.5, 0)
	TweenService:Create(
		wipe,
		TweenInfo.new(GoBack.ARRIVE, Enum.EasingStyle.Linear),
		{ Offset = Vector2.new(0.5, 0) }
	):Play()
	AudioController.play("FX_Swoosh", nil, nil, 0.9)
	local model = driven()
	local camera = Workspace.CurrentCamera
	if model then
		local _, size = model:GetBoundingBox()
		ride = {
			route = route,
			at = os.clock(),
			model = model,
			length = math.max(size.X, size.Z),
			from = camera.CFrame,
			fov = camera.FieldOfView,
			yaw = yawOf(camera.CFrame.LookVector),
			last = route.start.Position,
			launched = false,
			spray = 0,
		}
	end
	local jump = GoBack.jumpTime(route)
	if jump then
		task.delay(math.max(jump - VEIL_IN, 0), function()
			if run == mine then
				fade(0, VEIL_IN)
			end
		end)
		task.delay(jump + 0.05, function()
			if run == mine then
				fade(1, VEIL_OUT)
			end
		end)
	end
	-- never left riding: every ride ends in a Cancel or a Land, unless this client stopped being told
	task.delay(GoBack.ARRIVE + GoBack.LAND_HOLD + 1, function()
		if run == mine then
			finish()
		end
	end)
end

-- Every frame of the ride, before the camera: the hull on the route, the chase shot, the spray.
local function stepRide(dt: number)
	local r = ride
	if not r or not r.model.Parent then
		return
	end
	local t = os.clock() - r.at
	local pose = GoBack.pose(r.route, t)
	r.model:PivotTo(pose)
	local moved = Vector3.new(pose.X - r.last.X, 0, pose.Z - r.last.Z)
	r.last = pose.Position
	local speed = moved.Magnitude / math.max(dt, 1 / 240)
	local frac = math.clamp(speed / math.max(GoBack.topSpeed(r.route), 1), 0, 1)
	-- the shot follows where the hull goes (in the turn: where it points), so the swing into the bay reads under it
	local want = if speed > 5
		then yawOf(moved)
		elseif t < GoBack.TURN then yawOf(pose.LookVector)
		else r.yaw
	local d = want - r.yaw
	r.yaw += math.atan2(math.sin(d), math.cos(d)) * (1 - math.exp(-dt / 0.25))
	local back = CFrame.Angles(0, r.yaw, 0).LookVector
	local dist = math.clamp(r.length * 1.6 + 8, 16, 70) * (1 + 0.35 * frac)
	local focus = pose.Position + Vector3.new(0, math.clamp(r.length * 0.25, 3, 12), 0)
	local shot =
		CFrame.lookAt(focus - back * dist + Vector3.new(0, dist * 0.38, 0), focus + back * 10)
	local reduced = Comfort.reducedMotion()
	local widen = RIDE_FOV * frac * (if reduced then 0.35 else 1)
	CameraController.SetOverride(r.from:Lerp(shot, math.clamp(t / 0.35, 0, 1)), r.fov + widen)
	-- spray off the stern, back over the wake (as BoatController's Nitro)
	local stern = pose.Position - pose.LookVector * r.length * 0.45
	local up = (-pose.LookVector + Vector3.yAxis * 0.4).Unit
	if not r.launched and t >= GoBack.TURN then
		r.launched = true
		VFXKit.play("nitro_burst", CFrame.fromMatrix(stern, pose.RightVector, up))
		VFXKit.play("nitro_ring", CFrame.new(stern.X, pose.Y - 0.5, stern.Z))
	elseif t - r.spray > 0.1 and t < GoBack.ARRIVE and not reduced then
		r.spray = t
		local turning = t < GoBack.TURN
			or (speed > 5 and math.abs(yawOf(moved) - yawOf(pose.LookVector)) > 0.3)
		if turning then -- the hull slides sideways: spray off its outside (banked left: a left turn, the starboard side)
			local out = pose.RightVector * (if pose.RightVector.Y > 0 then 1 else -1)
			out = Vector3.new(out.X, 0, out.Z).Unit
			local dir = (out + Vector3.yAxis * 0.7 - pose.LookVector * 0.4).Unit
			local at = pose.Position + out * r.length * 0.25
			VFXKit.play(
				"ski_carve",
				CFrame.fromMatrix(at, dir:Cross(Vector3.yAxis).Unit, dir),
				{ scale = 1 }
			)
		elseif frac > 0.3 then
			VFXKit.play(
				"nitro_trail",
				CFrame.fromMatrix(
					stern,
					pose.RightVector,
					(-pose.LookVector + Vector3.yAxis * 1.3).Unit
				)
			)
		end
	end
end

local function onLand()
	local model = driven()
	if model then
		SubRig.clear(model) -- the sub's held yaw and depth belong to the old spot
	end
	HeliController.Landed()
	CameraController.SnapBehind()
	if model and model:GetAttribute("BoatLevel") ~= nil and model.PrimaryPart then -- boats only: craft have no level
		CameraController.FrameStation(UpgradeStation.nearest(model.PrimaryPart.Position))
	end
	finish()
	local rider = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if rider and rider:IsA("BasePart") then
		VFXKit.play("go_back_land", CFrame.new(rider.Position.X, 0, rider.Position.Z))
	end
end

function GoBackController.Start()
	Comfort.whenReady(function()
		seenLoaded = true
	end)
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
	FuelGauge.mount(Layout.region(gui, "goback"), driven, bounce) -- over the button, while you drive (docs/31 C)
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

	Net.event("GoBack").OnClientEvent:Connect(function(phase: string, route: any)
		if phase == "Ride" and typeof(route) == "table" then
			onRide(route)
		elseif phase == "Land" then
			onLand()
		elseif charging then
			finish()
			AudioController.play("UI_Back")
		end
	end)

	-- before MaydayCamera (Camera + 1), so the shot is this frame's
	RunService:BindToRenderStep("GoBackRide", Enum.RenderPriority.Camera.Value, stepRide)

	while true do
		refresh()
		task.wait(0.2)
	end
end

return GoBackController
