--!strict
-- PhotoMode: the free camera and lens (LU-6, docs/10 5.4, docs/14 section 6). Opened from the phone's
-- camera app (UI/Phone) or O / gamepad RT on foot. It pauses nothing: the world and other players keep
-- running; the camera flies free within PhotoMath.REACH studs of the player, with yaw/pitch, tilt,
-- FOV, a few colour grades and a held character pose (stock Roblox R15 emotes). A shutter press
-- flashes the screen and clicks (AudioConfig UI_Click, a verified public id).
--
-- Controls (every action on all devices):
--   fly      W A S D + Space/Shift | left stick | touch stick (bottom left)
--   look     mouse | right stick | drag (touch)
--   tilt     Q / E | D-pad left/right | two-finger horizontal drag
--   FOV      mouse wheel | LB / RB | pinch
--   shutter  F | A | shutter button        pose  P | X | arm button
--   grade    G | Y | grade button          close O | B | X button
-- The HUD (every other ScreenGui) is hidden while the lens is up; the player attribute
-- PhotoModeOpen mirrors the state. Poses play locally only (see the note in setPose).
--
--   PhotoMode.mount()
--   PhotoMode.setOpen(open) / isOpen() / toggle()
--   PhotoMode.setDeviceOverride("Touch" | "Gamepad" | "Keyboard" | nil)   dev/test only
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Client = script.Parent.Parent
local Comfort = require(Client:WaitForChild("Camera"):WaitForChild("Comfort"))
local FirstPerson = require(Client:WaitForChild("Camera"):WaitForChild("FirstPerson"))
local HudTheme = require(script.Parent:WaitForChild("HudTheme"))
local InputGlyph = require(script.Parent:WaitForChild("InputGlyph"))
local Layout = require(script.Parent:WaitForChild("Layout"))
local PhotoMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PhotoMath"))
local Telemetry = require(Client:WaitForChild("Telemetry"))
local Viewmodel = require(Client:WaitForChild("Camera"):WaitForChild("Viewmodel"))

local C = HudTheme.Colors
local player = Players.LocalPlayer
local DISPLAY_ORDER = 60 -- above Cinematic (50) and every HUD panel

local MOUSE_LOOK = 0.0045 -- rad per px
local TOUCH_LOOK = 0.006
local PAD_LOOK = 2.6 -- rad/s at full stick
local ROLL_RATE = 1.1 -- rad/s
local FLY_SPEED = 24 -- studs/s
local WHEEL_FOV = 3 -- degrees per wheel notch
local BUMPER_FOV = 6
local PINCH_TILT = 0.0015 -- rad per px of two-finger horizontal drag
local PRIORITY = Enum.ContextActionPriority.High.Value + 5 -- above the default controls so photo input sinks them

-- Stock Roblox R15 emotes (the ids in the default Animate script; no salute emote is stock).
local POSES = {
	{ name = "WAVE", id = "rbxassetid://507770239" },
	{ name = "POINT", id = "rbxassetid://507770453" },
	{ name = "CHEER", id = "rbxassetid://507770677" },
}

local PhotoMode = {}

local open = false
local deviceOverride: string? = nil
local gui: ScreenGui? = nil
local backdrop: TextButton
local flash: Frame
local closeButton: TextButton
local shutterButton: TextButton
local poseButton: TextButton
local gradeButton: TextButton
local poseLabel: TextLabel
local gradeLabel: TextLabel
local stick: TextButton
local knob: Frame
local modal: InputGlyph.Modal

local shot = {
	yaw = 0,
	pitch = 0,
	tilt = 0,
	fov = 70,
	pos = Vector3.zero,
	grade = 2, -- WARM
	pose = 0,
}
local focus = Vector3.zero
local look = Vector2.zero -- accumulated look this frame (radians)
local padLook = Vector2.zero
local padFly = Vector2.zero
local held: { [Enum.KeyCode]: boolean } = {}
local stickTouch: InputObject? = nil
local stickVec = Vector2.zero
local touches: { InputObject } = {}
local pinch: { d: number, fov: number, mid: number }? = nil
local track: AnimationTrack? = nil
local effect: ColorCorrectionEffect? = nil
local hidden: { [ScreenGui]: { wanted: boolean, conn: RBXScriptConnection? } } = {}
local keep: { [string]: boolean } = { PhotoMode = true, Freecam = true }

local function device(): InputGlyph.Device
	local d = deviceOverride
	if d == "Touch" or d == "Gamepad" or d == "Keyboard" then
		return d :: InputGlyph.Device
	end
	return InputGlyph.device()
end

----------------------------------------------------------------- the shot

local function focusPoint(): Vector3
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		focus = root.Position
	end
	return focus
end

local function deadzone(x: number): number
	local dz = 0.12
	if math.abs(x) < dz then
		return 0
	end
	return math.sign(x) * (math.abs(x) - dz) / (1 - dz)
end

local function setPose(index: number)
	shot.pose = index
	if track then
		track:Stop(0.2)
		track = nil
	end
	poseLabel.Text = if index == 0 then "POSE" else POSES[index].name
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator or index == 0 then
		return
	end
	local spec = POSES[index]
	-- shortcut: the pose plays on this client only; replicate it through a server Animation when
	-- photo sharing lands.
	local anim = Instance.new("Animation")
	anim.AnimationId = spec.id
	local ok, loaded = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	if not ok or loaded == nil then
		return
	end
	loaded.Priority = Enum.AnimationPriority.Action
	loaded.Looped = true
	loaded:Play(0.2)
	track = loaded
end

local function applyGrade()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local fx: ColorCorrectionEffect
	if effect then
		fx = effect
	else
		local created: ColorCorrectionEffect = Instance.new("ColorCorrectionEffect")
		created.Name = "PhotoGrade"
		created.Parent = camera
		effect = created
		fx = created
	end
	local g = PhotoMath.gradeAt(shot.grade)
	fx.Brightness = g.brightness
	fx.Contrast = g.contrast
	fx.Saturation = g.saturation
	fx.TintColor = g.tint or Color3.new(1, 1, 1)
	gradeLabel.Text = g.name
end

local function click()
	local ok, audio = pcall(function()
		return require(Client:WaitForChild("Controllers"):WaitForChild("AudioController"))
	end)
	if ok and type(audio) == "table" and type(audio.play) == "function" then
		audio.play("UI_Click", nil, 1.6, 1.12)
	end
end

local function shutter()
	-- Reduce motion: a soft glow instead of a full white flash.
	local reduced = Comfort.reducedMotion()
	flash.BackgroundTransparency = if reduced then 0.5 else 0.05
	TweenService:Create(
		flash,
		TweenInfo.new(
			if reduced then 0.5 else 0.35,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		),
		{ BackgroundTransparency = 1 }
	):Play()
	click()
end

local function step(dt: number)
	if not open then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	shot.yaw -= look.X
	shot.pitch -= look.Y
	look = Vector2.zero
	local stickLook = Vector2.new(deadzone(padLook.X), deadzone(padLook.Y))
	shot.yaw -= stickLook.X * PAD_LOOK * dt
	shot.pitch += stickLook.Y * PAD_LOOK * dt
	local roll = (if held[Enum.KeyCode.E] then 1 else 0) - (if held[Enum.KeyCode.Q] then 1 else 0)
	roll += (if held[Enum.KeyCode.DPadRight] then 1 else 0) - (if held[Enum.KeyCode.DPadLeft]
		then 1
		else 0)
	shot.tilt += roll * ROLL_RATE * dt

	local flat = CFrame.Angles(0, shot.yaw, 0)
	local move = Vector3.zero
	if held[Enum.KeyCode.W] then
		move += flat.LookVector
	end
	if held[Enum.KeyCode.S] then
		move -= flat.LookVector
	end
	if held[Enum.KeyCode.D] then
		move += flat.RightVector
	end
	if held[Enum.KeyCode.A] then
		move -= flat.RightVector
	end
	if held[Enum.KeyCode.Space] then
		move += Vector3.yAxis
	end
	if held[Enum.KeyCode.LeftShift] then
		move -= Vector3.yAxis
	end
	move += flat.LookVector * deadzone(padFly.Y) + flat.RightVector * deadzone(padFly.X)
	move -= flat.LookVector * stickVec.Y + flat.RightVector * stickVec.X
	if move.Magnitude > 1 then
		move = move.Unit
	end
	shot.pos += move * FLY_SPEED * dt
	shot.pos = PhotoMath.clampReach(focusPoint(), shot.pos)
	shot.pitch, shot.tilt, shot.fov = PhotoMath.clampShot(shot.pitch, shot.tilt, shot.fov)

	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = PhotoMath.lookCFrame(shot.pos, shot.yaw, shot.pitch, shot.tilt)
	camera.FieldOfView = shot.fov
	local char = player.Character
	if char then
		FirstPerson.resetBodyVisibility(char) -- the subject stays in frame (Foot mode hides it)
	end
end

----------------------------------------------------------------- input

local function onMove(
	_: string,
	state: Enum.UserInputState,
	input: InputObject
): Enum.ContextActionResult
	local key = input.KeyCode
	if state == Enum.UserInputState.Begin then
		held[key] = true
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		held[key] = nil
	end
	return Enum.ContextActionResult.Sink
end

local function onZoom(
	_: string,
	state: Enum.UserInputState,
	input: InputObject
): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		local inward = input.KeyCode == Enum.KeyCode.ButtonR1
			or input.KeyCode == Enum.KeyCode.ButtonR2
		shot.fov += if inward then -BUMPER_FOV else BUMPER_FOV
	end
	return Enum.ContextActionResult.Sink
end

local function onShutter(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		shutter()
	end
	return Enum.ContextActionResult.Sink
end

local function onPose(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		setPose((shot.pose + 1) % (#POSES + 1))
	end
	return Enum.ContextActionResult.Sink
end

local function onGrade(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		shot.grade = PhotoMath.nextGrade(shot.grade)
		applyGrade()
	end
	return Enum.ContextActionResult.Sink
end

local ACTIONS =
	{ "PhotoModeMove", "PhotoModeZoom", "PhotoModeShutter", "PhotoModePose", "PhotoModeGrade" }

local function bindControls()
	ContextActionService:BindActionAtPriority(
		"PhotoModeMove",
		onMove,
		false,
		PRIORITY,
		Enum.KeyCode.W,
		Enum.KeyCode.A,
		Enum.KeyCode.S,
		Enum.KeyCode.D,
		Enum.KeyCode.Space,
		Enum.KeyCode.LeftShift,
		Enum.KeyCode.Q,
		Enum.KeyCode.E,
		Enum.KeyCode.M,
		Enum.KeyCode.DPadLeft,
		Enum.KeyCode.DPadRight
	)
	ContextActionService:BindActionAtPriority(
		"PhotoModeZoom",
		onZoom,
		false,
		PRIORITY,
		Enum.KeyCode.ButtonR1,
		Enum.KeyCode.ButtonL1,
		Enum.KeyCode.ButtonR2,
		Enum.KeyCode.ButtonL2
	)
	ContextActionService:BindActionAtPriority(
		"PhotoModeShutter",
		onShutter,
		false,
		PRIORITY + 10,
		Enum.KeyCode.F,
		Enum.KeyCode.ButtonA
	)
	ContextActionService:BindActionAtPriority(
		"PhotoModePose",
		onPose,
		false,
		PRIORITY + 10,
		Enum.KeyCode.P,
		Enum.KeyCode.ButtonX
	)
	ContextActionService:BindActionAtPriority(
		"PhotoModeGrade",
		onGrade,
		false,
		PRIORITY + 10,
		Enum.KeyCode.G,
		Enum.KeyCode.ButtonY
	)
end

local function unbindControls()
	for _, name in ACTIONS do
		ContextActionService:UnbindAction(name)
	end
end

local function stickTo(input: InputObject)
	local centre = stick.AbsolutePosition + stick.AbsoluteSize / 2
	local off = Vector2.new(input.Position.X, input.Position.Y) - centre
	local radius = stick.AbsoluteSize.X / 2
	if off.Magnitude > radius then
		off = off.Unit * radius
	end
	knob.Position = UDim2.fromScale(0.5, 0.5) + UDim2.fromOffset(off.X, off.Y)
	stickVec = off / radius
end

local function resetStick()
	stickTouch = nil
	stickVec = Vector2.zero
	knob.Position = UDim2.fromScale(0.5, 0.5)
end

-- A touch that began on the backdrop: one finger looks, two pinch (FOV) and drag sideways (tilt).
local function touchBegan(input: InputObject)
	if input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	table.insert(touches, input)
	if #touches == 1 then
		return
	end
	local a, b = touches[1], touches[2]
	local pa = Vector2.new(a.Position.X, a.Position.Y)
	local pb = Vector2.new(b.Position.X, b.Position.Y)
	pinch = { d = math.max((pa - pb).Magnitude, 1), fov = shot.fov, mid = (pa.X + pb.X) / 2 }
end

local function touchMoved(input: InputObject)
	if input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local n = #touches
	if n == 0 then
		return
	end
	if pinch and n >= 2 then
		local a, b = touches[1], touches[2]
		local pa = Vector2.new(a.Position.X, a.Position.Y)
		local pb = Vector2.new(b.Position.X, b.Position.Y)
		local d = math.max((pa - pb).Magnitude, 1)
		shot.fov = pinch.fov * pinch.d / d
		local mid = (pa.X + pb.X) / 2
		shot.tilt += (pinch.mid - mid) * PINCH_TILT
		pinch.mid = mid
	elseif n == 1 and touches[1] == input then
		look += Vector2.new(input.Delta.X, input.Delta.Y) * (TOUCH_LOOK * Comfort.get("sensitivity"))
	end
end

local function touchEnded(input: InputObject)
	for i = #touches, 1, -1 do
		if touches[i] == input then
			table.remove(touches, i)
		end
	end
	if #touches < 2 then
		pinch = nil
	end
end

local function connectInput()
	UserInputService.InputChanged:Connect(function(input, processed)
		if not open then
			return
		end
		if input.KeyCode == Enum.KeyCode.Thumbstick2 then
			padLook = Vector2.new(input.Position.X, input.Position.Y)
		elseif input.KeyCode == Enum.KeyCode.Thumbstick1 then
			padFly = Vector2.new(input.Position.X, input.Position.Y)
		elseif input.UserInputType == Enum.UserInputType.MouseMovement then
			look += Vector2.new(input.Delta.X, input.Delta.Y) * (MOUSE_LOOK * Comfort.get(
				"sensitivity"
			))
		elseif input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
			local notch: number = input.Position.Z
			shot.fov -= notch * WHEEL_FOV
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Thumbstick2 then
			padLook = Vector2.zero
		elseif input.KeyCode == Enum.KeyCode.Thumbstick1 then
			padFly = Vector2.zero
		end
		touchEnded(input)
	end)
	backdrop.InputBegan:Connect(function(input)
		if not open then
			return
		end
		touchBegan(input)
	end)
	backdrop.InputChanged:Connect(function(input)
		if open then
			touchMoved(input)
		end
	end)
	backdrop.InputEnded:Connect(function(input)
		touchEnded(input)
	end)
	stick.InputBegan:Connect(function(input)
		if open and input.UserInputType == Enum.UserInputType.Touch then
			stickTouch = input
			stickTo(input)
		end
	end)
	stick.InputEnded:Connect(function(input)
		if stickTouch == input then
			resetStick()
		end
	end)
end

----------------------------------------------------------------- HUD hiding

local function hideOthers()
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end
	for _, g in playerGui:GetChildren() do
		if g:IsA("ScreenGui") and not keep[g.Name] and hidden[g] == nil then
			local entry: { wanted: boolean, conn: RBXScriptConnection? } =
				{ wanted = g.Enabled, conn = nil }
			hidden[g] = entry
			g.Enabled = false
			entry.conn = g:GetPropertyChangedSignal("Enabled"):Connect(function()
				if g.Enabled and open then
					entry.wanted = true -- opened while the lens is up: back after closing
					g.Enabled = false
				end
			end)
		end
	end
end

local function restoreOthers()
	for g, entry in hidden do
		if entry.conn then
			entry.conn:Disconnect()
		end
		if g.Parent then
			g.Enabled = entry.wanted
		end
	end
	table.clear(hidden)
end

----------------------------------------------------------------- lifecycle

local function openInput()
	local camera = Workspace.CurrentCamera
	local lookVector = if camera then camera.CFrame.LookVector else Vector3.new(0, 0, -1)
	shot.fov = if camera then camera.FieldOfView else 70
	shot.tilt = 0
	shot.pos = if camera then camera.CFrame.Position else focusPoint() + Vector3.new(0, 6, 12)
	shot.yaw = math.atan2(-lookVector.X, -lookVector.Z)
	shot.pitch = math.asin(math.clamp(lookVector.Y, -1, 1))
	local subject = focusPoint()
	if (shot.pos - subject).Magnitude < 6 then
		-- First person or a tight vehicle cam: pull back so the first frame shows the player.
		shot.pos = subject - lookVector * 8 + Vector3.new(0, 1.5, 0)
		local aim = subject + Vector3.new(0, 0.5, 0) - shot.pos
		shot.yaw = math.atan2(-aim.X, -aim.Z)
		shot.pitch = math.asin(math.clamp(aim.Unit.Y, -1, 1))
	end
	shot.pos = PhotoMath.clampReach(subject, shot.pos)
	look, padLook, padFly, stickVec = Vector2.zero, Vector2.zero, Vector2.zero, Vector2.zero
	table.clear(held)
	touches = {}
	pinch = nil
	resetStick()
	stick.Visible = device() == "Touch" -- re-read every open (a device may have changed while away)
	Viewmodel.stopAction()
	bindControls()
	hideOthers()
	applyGrade()
	modal.open(closeButton)
	UserInputService.MouseIconEnabled = true
end

local function closeInput()
	unbindControls()
	modal.close()
	restoreOthers()
	setPose(0)
	if effect then
		effect:Destroy()
		effect = nil
	end
	look, padLook, padFly = Vector2.zero, Vector2.zero, Vector2.zero
	table.clear(held)
	touches = {}
	pinch = nil
	resetStick()
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
	end
end

function PhotoMode.isOpen(): boolean
	return open
end

function PhotoMode.setOpen(value: boolean)
	local g = gui
	if not g then
		if not value then
			return
		end
		PhotoMode.mount()
		g = gui
	end
	if not g or value == open then
		return
	end
	if value and player:GetAttribute("CinematicPlaying") == true then
		return
	end
	open = value
	player:SetAttribute("PhotoModeOpen", value)
	g.Enabled = value
	-- the lens has its own fly stick and shutter: the walk controls would sit on top of both
	if UserInputService.TouchEnabled then
		GuiService.TouchControlsEnabled = not value
	end
	if value then
		Telemetry.once("PhotoModeOpen") -- G64: photo mode opened, once per session
		openInput()
	else
		closeInput()
	end
end

function PhotoMode.toggle()
	PhotoMode.setOpen(not open)
end

-- Dev/test only: pin the device the HUD draws for (Studio cannot emulate touch from a script).
function PhotoMode.setDeviceOverride(name: string?)
	deviceOverride = name
	if gui then
		stick.Visible = device() == "Touch"
	end
end

----------------------------------------------------------------- build

local function box(
	parent: Instance,
	color: Color3,
	x: number,
	y: number,
	w: number,
	h: number,
	r: number?
): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	if r then
		HudTheme.corner(f, r)
	end
	f.Parent = parent
	return f
end

local function keyButton(name: string, size: number, parent: Instance): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = ""
	b.Size = UDim2.fromOffset(size, size)
	b.BackgroundColor3 = C.panel
	b.BackgroundTransparency = 0.15
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	HudTheme.corner(b, 99)
	HudTheme.stroke(b)
	b.Parent = parent
	return b
end

local function glyphPose(b: GuiObject)
	box(b, C.text, 0.5, 0.3, 0.22, 0.22, 99)
	box(b, C.text, 0.44, 0.62, 0.26, 0.34, 3)
	box(b, C.accent, 0.7, 0.42, 0.1, 0.3, 2)
end

local function glyphGrade(b: GuiObject)
	box(b, Color3.fromHex("E8A87C"), 0.32, 0.52, 0.16, 0.42, 2)
	box(b, C.textDim, 0.5, 0.52, 0.16, 0.42, 2)
	box(b, Color3.fromHex("7CA8E8"), 0.68, 0.52, 0.16, 0.42, 2)
end

local function build()
	local g = Instance.new("ScreenGui")
	g.Name = "PhotoMode"
	g.ResetOnSpawn = false
	g.DisplayOrder = DISPLAY_ORDER
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.Enabled = false
	g:SetAttribute("CinematicKeep", true)
	Layout.prepare(g)
	gui = g

	-- A Modal backdrop frees the mouse from first-person lock; it also receives the look/pinch touches.
	local bd = Instance.new("TextButton")
	bd.Name = "Backdrop"
	bd.Text = ""
	bd.Size = UDim2.fromScale(1, 1)
	bd.BackgroundTransparency = 1
	bd.AutoButtonColor = false
	bd.Selectable = false
	bd.Modal = true
	bd.Parent = g
	backdrop = bd

	local hud = Instance.new("Frame")
	hud.Name = "Lens"
	hud.Size = UDim2.fromScale(1, 1)
	hud.BackgroundTransparency = 1
	hud.Parent = g
	local sc = Instance.new("UIScale")
	sc.Scale = Layout.current().scale
	sc.Parent = hud
	Layout.onMetrics(function(mt)
		sc.Scale = mt.scale
	end)

	-- shutter flash over everything
	local f = Instance.new("Frame")
	f.Name = "Flash"
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.ZIndex = 30
	f.Parent = g
	flash = f

	closeButton = keyButton("Close", 63, hud)
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -14, 0, 14)
	closeButton.ZIndex = 5
	local x1 = box(closeButton, C.text, 0.5, 0.5, 0.42, 0.08)
	x1.Rotation = 45
	local x2 = box(closeButton, C.text, 0.5, 0.5, 0.42, 0.08)
	x2.Rotation = -45

	shutterButton = keyButton("Shutter", 84, hud)
	shutterButton.AnchorPoint = Vector2.new(1, 1)
	shutterButton.Position = UDim2.new(1, -18, 1, -18)
	shutterButton.ZIndex = 5
	local ring = box(shutterButton, C.text, 0.5, 0.5, 0.64, 0.64, 99)
	ring.BackgroundTransparency = 1
	HudTheme.stroke(ring, C.text, 3)
	box(shutterButton, C.text, 0.5, 0.5, 0.44, 0.44, 99)

	poseButton = keyButton("Pose", 63, hud)
	poseButton.AnchorPoint = Vector2.new(1, 1)
	poseButton.Position = UDim2.new(1, -18, 1, -122)
	poseButton.ZIndex = 5
	glyphPose(poseButton)
	poseLabel = HudTheme.label(
		"PoseName",
		"POSE",
		UDim2.new(1, 0, 0, 24),
		HudTheme.HeaderFont,
		20,
		poseButton
	)
	poseLabel.Position = UDim2.fromOffset(0, 37)
	poseLabel.TextXAlignment = Enum.TextXAlignment.Center
	poseLabel.TextColor3 = C.textDim
	poseLabel.ZIndex = 5

	gradeButton = keyButton("Grade", 63, hud)
	gradeButton.AnchorPoint = Vector2.new(1, 1)
	gradeButton.Position = UDim2.new(1, -18, 1, -190)
	gradeButton.ZIndex = 5
	glyphGrade(gradeButton)
	gradeLabel = HudTheme.label(
		"GradeName",
		"WARM",
		UDim2.new(1, 0, 0, 24),
		HudTheme.HeaderFont,
		20,
		gradeButton
	)
	gradeLabel.Position = UDim2.fromOffset(0, 37)
	gradeLabel.TextXAlignment = Enum.TextXAlignment.Center
	gradeLabel.TextColor3 = C.textDim
	gradeLabel.ZIndex = 5

	InputGlyph.chip(closeButton, Enum.KeyCode.O, Enum.KeyCode.ButtonB)
	InputGlyph.chip(shutterButton, Enum.KeyCode.F, Enum.KeyCode.ButtonA)
	InputGlyph.chip(poseButton, Enum.KeyCode.P, Enum.KeyCode.ButtonX)
	InputGlyph.chip(gradeButton, Enum.KeyCode.G, Enum.KeyCode.ButtonY)

	-- touch fly stick (bottom left); hidden on keyboard / gamepad
	local st = Instance.new("TextButton")
	st.Name = "Stick"
	st.Text = ""
	st.AnchorPoint = Vector2.new(0, 1)
	st.Position = UDim2.new(0, 20, 1, -20)
	st.Size = UDim2.fromOffset(128, 128)
	st.BackgroundColor3 = C.panel
	st.BackgroundTransparency = 0.45
	st.BorderSizePixel = 0
	st.AutoButtonColor = false
	st.ZIndex = 5
	HudTheme.corner(st, 99)
	HudTheme.stroke(st)
	st.Parent = hud
	stick = st
	knob = box(st, C.text, 0.5, 0.5, 0.4, 0.4, 99)
	knob.BackgroundTransparency = 0.2

	shutterButton.Activated:Connect(shutter)
	poseButton.Activated:Connect(function()
		setPose((shot.pose + 1) % (#POSES + 1))
	end)
	gradeButton.Activated:Connect(function()
		shot.grade = PhotoMath.nextGrade(shot.grade)
		applyGrade()
	end)
	closeButton.Activated:Connect(function()
		PhotoMode.setOpen(false)
	end)

	modal = InputGlyph.modal("PhotoMode", function()
		PhotoMode.setOpen(false)
	end)

	InputGlyph.onDevice(function(_)
		stick.Visible = device() == "Touch"
	end)

	g.Parent = player:WaitForChild("PlayerGui")
end

function PhotoMode.mount()
	if gui then
		return
	end
	build()
	connectInput()
	RunService:BindToRenderStep("MaydayPhotoMode", Enum.RenderPriority.Camera.Value + 2, step)
	ContextActionService:BindAction("PhotoModeToggle", function(_, state, input)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if not open and input.KeyCode == Enum.KeyCode.ButtonR2 then
			-- RT is the car's throttle: only an on-foot RT opens the lens
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local seat = hum and hum.SeatPart
			local model = seat and seat:FindFirstAncestorOfClass("Model")
			if model and model:GetAttribute("LandVehicle") == true then
				return Enum.ContextActionResult.Pass
			end
		end
		PhotoMode.toggle()
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.O, Enum.KeyCode.ButtonR2)
	player:GetAttributeChangedSignal("CinematicPlaying"):Connect(function()
		if player:GetAttribute("CinematicPlaying") == true then
			PhotoMode.setOpen(false)
		end
	end)
	player.CharacterAdded:Connect(function()
		PhotoMode.setOpen(false)
	end)
end

return PhotoMode
