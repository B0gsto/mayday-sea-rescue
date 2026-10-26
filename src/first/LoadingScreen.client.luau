--!strict
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular)
local INK = Color3.fromRGB(20, 18, 28)
local WHITE = Color3.fromRGB(255, 255, 255)
local YELLOW_TOP = Color3.fromRGB(255, 242, 122)
local YELLOW_BOTTOM = Color3.fromRGB(255, 178, 30)
local SKY_TOP = Color3.fromRGB(150, 220, 255)
local SKY_BOTTOM = Color3.fromRGB(36, 120, 200)

local TIPS = {
	"Slow down in the orange ring.",
	"Build your island at the tablet.",
	"Bring survivors to the drop-off pad.",
	"Check the map to explore.",
	"Your boat board is on the jetty.",
}

local TIP_SECONDS = 4
local MIN_SHOW = 2.2
local LOAD_TIMEOUT = 25
local FLY_SECONDS = 6.4
local FOV = 62

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui:SetAttribute("CinematicKeep", true)
gui.Parent = playerGui

local canvas = Instance.new("CanvasGroup")
canvas.Name = "Canvas"
canvas.BackgroundTransparency = 1
canvas.AnchorPoint = Vector2.new(0.5, 0.5)
canvas.Position = UDim2.fromScale(0.5, 0.5)
canvas.Size = UDim2.fromOffset(1280, 720)
canvas.Parent = gui

local uiScale = Instance.new("UIScale")
uiScale.Parent = canvas

local function fit()
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.55, 1.6)
	uiScale.Scale = scale
	canvas.Size = UDim2.fromOffset(viewport.X / scale, viewport.Y / scale)
end
fit()
task.spawn(function()
	local camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera")
	if camera and camera:IsA("Camera") then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
end)

local function corner(parent: Instance, radius: number): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function outline(parent: Instance, thickness: number, color: Color3): UIStroke
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = color
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = parent
	return s
end

local function label(parent: Instance, text: string, size: number, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = FONT
	l.Text = text
	l.TextSize = size
	l.TextColor3 = color or WHITE
	l.TextWrapped = true
	l.Size = UDim2.fromScale(1, 1)
	outline(l, math.max(2, size * 0.08), INK)
	l.Parent = parent
	return l
end

local sky = Instance.new("Frame")
sky.Name = "Sky"
sky.Size = UDim2.fromScale(1, 1)
sky.BorderSizePixel = 0
sky.BackgroundColor3 = WHITE
sky.BackgroundTransparency = 0.05
sky.Parent = canvas
local skyGradient = Instance.new("UIGradient")
skyGradient.Color = ColorSequence.new(SKY_TOP, SKY_BOTTOM)
skyGradient.Rotation = 90
skyGradient.Parent = sky

local logo = Instance.new("Frame")
logo.Name = "Logo"
logo.BackgroundTransparency = 1
logo.AnchorPoint = Vector2.new(0.5, 0.5)
logo.Position = UDim2.fromScale(0.5, 0.18)
logo.Size = UDim2.new(0.92, 0, 0, 200)
logo.Parent = canvas
local logoCap = Instance.new("UISizeConstraint")
logoCap.MaxSize = Vector2.new(900, 200)
logoCap.Parent = logo

local title = label(logo, "MAYDAY!", 104)
title.Name = "Title"
title.Size = UDim2.fromScale(1, 0.62)
local titleGradient = Instance.new("UIGradient")
titleGradient.Color = ColorSequence.new(WHITE, Color3.fromRGB(205, 240, 255))
titleGradient.Rotation = 90
titleGradient.Parent = title

local subtitle = label(logo, "SEA RESCUE", 60)
subtitle.Name = "Subtitle"
subtitle.Position = UDim2.fromScale(0, 0.58)
subtitle.Size = UDim2.fromScale(1, 0.42)
local subtitleGradient = Instance.new("UIGradient")
subtitleGradient.Color = ColorSequence.new(YELLOW_TOP, YELLOW_BOTTOM)
subtitleGradient.Rotation = 90
subtitleGradient.Parent = subtitle

local tagline = label(canvas, "Rescue. Build. Explore.", 30)
tagline.Name = "Tagline"
tagline.AnchorPoint = Vector2.new(0.5, 0)
tagline.Position = UDim2.fromScale(0.5, 0.34)
tagline.Size = UDim2.fromOffset(760, 42)
tagline.TextWrapped = false

local bar = Instance.new("Frame")
bar.Name = "Progress"
bar.AnchorPoint = Vector2.new(0.5, 0.5)
bar.Position = UDim2.fromScale(0.5, 0.55)
bar.Size = UDim2.fromOffset(560, 48)
bar.BackgroundColor3 = Color3.fromRGB(16, 34, 58)
bar.BackgroundTransparency = 0.1
bar.Parent = canvas
corner(bar, 24)
outline(bar, 5, INK)

local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Position = UDim2.fromOffset(6, 6)
fill.Size = UDim2.new(0, 0, 1, -12)
fill.BackgroundColor3 = YELLOW_BOTTOM
fill.Parent = bar
corner(fill, 18)
local fillGradient = Instance.new("UIGradient")
fillGradient.Color = ColorSequence.new(YELLOW_TOP, YELLOW_BOTTOM)
fillGradient.Rotation = 90
fillGradient.Parent = fill

local glow = Instance.new("Frame")
glow.Name = "Glow"
glow.AnchorPoint = Vector2.new(0.5, 0.5)
glow.Position = UDim2.new(0, 6, 0.5, 0)
glow.Size = UDim2.fromOffset(74, 74)
glow.BackgroundColor3 = Color3.fromRGB(255, 232, 80)
glow.BackgroundTransparency = 0.55
glow.ZIndex = 3
glow.Parent = bar
corner(glow, 37)

local knob = Instance.new("Frame")
knob.Name = "Knob"
knob.AnchorPoint = Vector2.new(0.5, 0.5)
knob.Position = UDim2.new(0, 6, 0.5, 0)
knob.Size = UDim2.fromOffset(38, 38)
knob.BackgroundColor3 = WHITE
knob.ZIndex = 4
knob.Parent = bar
corner(knob, 19)
outline(knob, 5, YELLOW_BOTTOM)

local status = label(canvas, "Warming up...", 26)
status.Name = "Status"
status.AnchorPoint = Vector2.new(0.5, 0)
status.Position = UDim2.fromScale(0.5, 0.61)
status.Size = UDim2.fromOffset(700, 40)
status.TextWrapped = false

local pill = Instance.new("Frame")
pill.Name = "Tip"
pill.AnchorPoint = Vector2.new(0.5, 1)
pill.Position = UDim2.fromScale(0.5, 0.94)
pill.Size = UDim2.new(0.8, 0, 0, 56)
pill.BackgroundColor3 = Color3.fromRGB(12, 28, 50)
pill.BackgroundTransparency = 0.08
pill.Parent = canvas
corner(pill, 28)
outline(pill, 4, INK)
local pillCap = Instance.new("UISizeConstraint")
pillCap.MinSize = Vector2.new(300, 56)
pillCap.MaxSize = Vector2.new(760, 56)
pillCap.Parent = pill

local tipTag = label(pill, "TIP", 22, YELLOW_TOP)
tipTag.AnchorPoint = Vector2.new(0, 0.5)
tipTag.Position = UDim2.new(0, 26, 0.5, 0)
tipTag.Size = UDim2.fromOffset(56, 30)
tipTag.TextXAlignment = Enum.TextXAlignment.Left
tipTag.TextWrapped = false

local tipLabel = label(pill, TIPS[1], 24)
tipLabel.Position = UDim2.fromOffset(96, 0)
tipLabel.Size = UDim2.new(1, -116, 1, 0)
tipLabel.TextXAlignment = Enum.TextXAlignment.Left
tipLabel.TextWrapped = false
tipLabel.TextScaled = true
local tipSize = Instance.new("UITextSizeConstraint")
tipSize.MinTextSize = 14
tipSize.MaxTextSize = 24
tipSize.Parent = tipLabel

task.spawn(function()
	local index = 1
	while gui.Parent do
		task.wait(TIP_SECONDS)
		index = index % #TIPS + 1
		tipLabel.Text = TIPS[index]
	end
end)

local fadeTween: Tween? = nil
local function fadeOverlay(seconds: number)
	local current = fadeTween
	if current then
		current:Cancel()
	end
	local tween = TweenService:Create(canvas, TweenInfo.new(seconds), { GroupTransparency = 1 })
	fadeTween = tween
	tween:Play()
end

local barActive = true

local function statusFor(p: number): string
	if p < 0.25 then
		return "Warming up..."
	elseif p < 0.5 then
		return "Loading the harbour..."
	elseif p < 0.8 then
		return "Loading the islands..."
	elseif p < 0.98 then
		return "Loading boats..."
	end
	return "Almost ready..."
end

local function setProgress(p: number, text: string?)
	p = math.clamp(p, 0, 1)
	TweenService:Create(fill, TweenInfo.new(0.25), {
		Size = UDim2.new(p, -12 * p, 1, -12),
	}):Play()
	local x = UDim2.new(p, 6 - 12 * p, 0.5, 0)
	TweenService:Create(knob, TweenInfo.new(0.25), { Position = x }):Play()
	TweenService:Create(glow, TweenInfo.new(0.25), { Position = x }):Play()
	if text then
		status.Text = text
	end
end

local function waitChild(parent: Instance, name: string, seconds: number): Instance?
	local child = parent:FindFirstChild(name)
	if child then
		return child
	end
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		task.wait(0.05)
		child = parent:FindFirstChild(name)
		if child then
			return child
		end
	end
	return parent:FindFirstChild(name)
end

local function loadModule(module: Instance?): any?
	if not (module and module:IsA("ModuleScript")) then
		return nil
	end
	local ok, value = pcall(require, module)
	return if ok then value else nil
end

local function resolveComfort(): boolean
	local ps = player:WaitForChild("PlayerScripts", 10)
	local client = ps and waitChild(ps, "Client", 10)
	local cameraFolder = client and waitChild(client, "Camera", 5)
	local comfortScript = cameraFolder and waitChild(cameraFolder, "Comfort", 5)
	if not (comfortScript and comfortScript:IsA("ModuleScript")) then
		return false
	end
	local ok, mod = pcall(require, comfortScript)
	if not ok or type(mod) ~= "table" then
		return false
	end
	if type(mod.load) ~= "function" or type(mod.whenReady) ~= "function" then
		return false
	end
	task.spawn(function()
		pcall(mod.load)
	end)
	local ready = false
	mod.whenReady(function()
		ready = true
	end)
	local deadline = os.clock() + 6
	while not ready and os.clock() < deadline do
		task.wait(0.05)
	end
	return ready and mod.reducedMotion() == true
end

local function collectAssets(UiImages: any): { Instance | string }
	local out: { Instance | string } = {}
	local seen: { [any]: boolean } = {}
	local function add(value: Instance | string)
		if not seen[value] then
			seen[value] = true
			table.insert(out, value)
		end
	end
	local function collect(value: any)
		if type(value) == "string" then
			if string.find(value, "rbxassetid://", 1, true) then
				add(value)
			end
		elseif type(value) == "table" then
			for _, v in value do
				collect(v)
			end
		end
	end
	if type(UiImages) == "table" then
		collect(UiImages.Kit)
		collect(UiImages.Hud)
		collect(UiImages.VehicleArt)
	end
	for _, name in { "Vehicles", "Marina", "Npcs", "Map", "Dressing" } do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			for _, child in folder:GetChildren() do
				add(child)
			end
		end
	end
	return out
end

local function preload(assets: { Instance | string }, deadline: number): boolean
	local total = #assets
	if total == 0 then
		return true
	end
	local index = 1
	while index <= total do
		if os.clock() >= deadline then
			return false
		end
		local batch: { Instance | string } = {}
		local last = math.min(index + 7, total)
		for i = index, last do
			table.insert(batch, assets[i])
		end
		pcall(ContentProvider.PreloadAsync, ContentProvider, batch)
		index = last + 1
		if barActive then
			local p = 0.2 + 0.75 * math.min(index - 1, total) / total
			setProgress(p, statusFor(p))
		end
	end
	return true
end

local function streamAround(position: Vector3): boolean
	if not Workspace.StreamingEnabled then
		return true
	end
	local ok = pcall(function()
		player:RequestStreamAroundAsync(position, 10)
	end)
	return ok
end

local function flatLook(cf: CFrame): Vector3
	local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	if look.Magnitude > 1e-3 then
		return look.Unit
	end
	return Vector3.new(0, 0, 1)
end

local function behind(pos: Vector3, cf: CFrame): CFrame
	local look = flatLook(cf)
	return CFrame.lookAt(pos - look * 19 + Vector3.new(0, 4.5, 0), pos + Vector3.new(0, 1.5, 0))
end

local function coldOpenCraft(): Model?
	local folder = Workspace:FindFirstChild("Vehicles")
	if not folder then
		return nil
	end
	for _, child in folder:GetChildren() do
		if
			child:IsA("Model")
			and child:GetAttribute("Owner") == player.UserId
			and child:GetAttribute("ColdOpen") == true
		then
			return child
		end
	end
	return nil
end

local function finishPose(bay: CFrame?, firstSession: boolean, fallback: CFrame): CFrame
	if firstSession then
		local craft = coldOpenCraft()
		if craft then
			-- Cinematic.Lists.coldOpen's last pose (pivot yaw frame), so the chase camera takes over smoothly
			local pivot = craft:GetPivot()
			local look = flatLook(pivot)
			return CFrame.lookAt(
				pivot.Position - look * 19.4 + Vector3.new(0, 8.2, 0),
				pivot.Position + look * 20 + Vector3.new(0, 4.8, 0)
			)
		end
		if bay then
			local look = flatLook(bay)
			return CFrame.lookAt(
				bay.Position - look * 26 + Vector3.new(0, 14, 0),
				bay.Position + Vector3.new(0, 2, 0)
			)
		end
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return behind(root.Position, root.CFrame)
	end
	return behind(fallback.Position, fallback)
end

local finished = false
local controls: any = nil
local cameraBound = false
local canSkip = false
local skipped = false

local function cleanup()
	if finished then
		return
	end
	finished = true
	if cameraBound then
		RunService:UnbindFromRenderStep("LoadingFlyover")
		cameraBound = false
	end
	player:SetAttribute("LoadingScreenActive", nil)
	player:SetAttribute("CinematicPlaying", nil)
	if controls then
		pcall(function()
			controls:Enable()
		end)
	end
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
	end
end

UserInputService.InputBegan:Connect(function()
	if canSkip then
		skipped = true
	end
end)

local function main()
	local t0 = os.clock()
	local deadline = t0 + LOAD_TIMEOUT
	player:SetAttribute("LoadingScreenActive", true)
	player:SetAttribute("CinematicPlaying", true)

	task.spawn(function()
		local ps = player:WaitForChild("PlayerScripts", 10)
		local pm = ps and ps:WaitForChild("PlayerModule", 10)
		if pm and pm:IsA("ModuleScript") then
			local ok, mod = pcall(require, pm)
			if ok and type(mod) == "table" then
				local okControls, c = pcall(function()
					return mod:GetControls()
				end)
				if okControls and c and not finished then
					controls = c
					c:Disable()
				end
			end
		end
	end)

	-- nil until the Comfort settings are in: the orbit only starts once reduced motion is known to be off
	local reduced: boolean? = nil
	task.spawn(function()
		reduced = resolveComfort()
	end)

	local shared = waitChild(ReplicatedStorage, "Shared", math.max(0.1, deadline - os.clock()))
	local config = shared and waitChild(shared, "Config", 5)
	local LoadingPath = loadModule(shared and waitChild(shared, "LoadingPath", 5))
	local RingLayout = loadModule(config and waitChild(config, "RingLayout", 5))
	local UiImages = loadModule(config and waitChild(config, "UiImages", 5))
	local Marina = loadModule(shared and waitChild(shared, "Marina", 5))

	if not (LoadingPath and RingLayout) then
		barActive = false
		setProgress(1, "Ready!")
		fadeOverlay(0.6)
		task.wait(0.6)
		cleanup()
		gui:Destroy()
		return
	end

	local ringCenter: Vector3 = RingLayout.Center -- docs/23 (p): the lagoon, ringed by the islands
	local bay: CFrame? = nil
	local firstSession = false
	local spawnCF: CFrame = RingLayout.Islands[1].spawn
	local orbitAngle = 0
	local flyActive = false
	local flyStart = 0
	local flyIsland = ringCenter
	local flySweep = ringCenter
	local flyLook = ringCenter

	local function startOrbit()
		if reduced ~= false or cameraBound then
			return
		end
		cameraBound = true
		RunService:BindToRenderStep(
			"LoadingFlyover",
			Enum.RenderPriority.Camera.Value + 2,
			function(dt: number)
				local camera = Workspace.CurrentCamera
				if not camera then
					return
				end
				local frame: CFrame
				if flyActive then
					local t = math.clamp((os.clock() - flyStart) / FLY_SECONDS, 0, 1)
					frame = LoadingPath.flyover(
						t,
						ringCenter,
						flyIsland,
						orbitAngle,
						flySweep,
						flyLook,
						finishPose(bay, firstSession, spawnCF)
					)
				else
					orbitAngle += dt * LoadingPath.ORBIT_SPEED
					frame = LoadingPath.orbit(ringCenter, orbitAngle)
				end
				camera.CameraType = Enum.CameraType.Scriptable
				camera.CFrame = frame
				camera.FieldOfView = FOV
			end
		)
		TweenService:Create(sky, TweenInfo.new(1.4), { BackgroundTransparency = 0.42 }):Play()
	end

	setProgress(0.05, "Warming up...")
	task.spawn(function()
		while reduced == nil and not finished do
			task.wait(0.05)
		end
		if not finished then
			startOrbit()
		end
	end)

	if not game:IsLoaded() then
		local loaded = false
		task.spawn(function()
			game.Loaded:Wait()
			loaded = true
		end)
		while not loaded and os.clock() < deadline do
			task.wait(0.05)
		end
	end

	setProgress(0.12, "Loading the harbour...")
	while os.clock() < deadline do
		local raw = player:GetAttribute("BayCFrame")
		if typeof(raw) == "CFrame" then
			bay = raw
			break
		end
		task.wait(0.05)
	end

	local islandCenter = ringCenter
	local isleFrame: CFrame? = nil
	local bayCF = bay
	if bayCF then
		local islandOffset = Marina and Marina.ISLAND
		if typeof(islandOffset) == "CFrame" then
			local frame = bayCF * islandOffset
			isleFrame = frame
			islandCenter = frame.Position
		end
	end

	local assets = collectAssets(UiImages)
	local preloaded = false
	task.spawn(function()
		preloaded = preload(assets, deadline)
	end)
	local streamed = false
	task.spawn(function()
		local ringOk = streamAround(ringCenter)
		local islandOk = streamAround(islandCenter)
		streamed = ringOk and islandOk
	end)
	while (not preloaded or not streamed) and os.clock() < deadline do
		task.wait(0.05)
	end

	while os.clock() - t0 < MIN_SHOW do
		task.wait(0.05)
	end
	barActive = false
	setProgress(1, "Ready!")

	local plot = player:GetAttribute("DockPlot")
	local look = if isleFrame
		then (isleFrame * CFrame.new(0, 10.4, -28.5)).Position
		else spawnCF.Position + spawnCF.LookVector * 10
	local marinaFolder = Workspace:FindFirstChild("Marina")
	if marinaFolder and type(plot) == "number" then
		local plotFolder = marinaFolder:FindFirstChild(`Plot{plot}`)
		local board = plotFolder and plotFolder:FindFirstChild("NameBoard", true)
		if board and board:IsA("BasePart") then
			look = board.Position
		end
	end

	-- a new profile gets the cold-open jet ski from the server, a returning one ColdOpenDone: wait for
	-- either (then the character) so the flight has a fixed end
	while
		os.clock() < deadline
		and player:GetAttribute("ColdOpenDone") ~= true
		and coldOpenCraft() == nil
	do
		task.wait(0.05)
	end
	firstSession = coldOpenCraft() ~= nil
	while not firstSession and os.clock() < deadline do
		local char = player.Character
		if char and char:FindFirstChild("HumanoidRootPart") then
			break
		end
		task.wait(0.05)
	end
	if type(plot) == "number" then
		local islandRow = RingLayout.Islands[plot]
		if islandRow then
			spawnCF = islandRow.spawn
		end
	end

	if reduced ~= false then -- reduced motion, or Comfort never answered: a plain fade
		fadeOverlay(0.9)
		task.wait(0.9)
		cleanup()
		gui:Destroy()
		return
	end

	task.wait(0.35)
	local initialFinish = finishPose(bay, firstSession, spawnCF)
	local from = LoadingPath.spiral(1, ringCenter, islandCenter, orbitAngle)
	local away = (from.Position - initialFinish.Position) * Vector3.new(1, 0, 1)
	if away.Magnitude < 1 then
		away = Vector3.new(from.LookVector.X, 0, from.LookVector.Z)
	end
	if away.Magnitude < 1e-3 then
		away = Vector3.new(0, 0, 1)
	end
	local sweep = look + away.Unit * 30 + Vector3.new(0, 10, 0) -- the sign reads, the lens stays clear of it
	flyIsland = islandCenter
	flySweep = sweep
	flyLook = look
	flyStart = os.clock()
	flyActive = true
	canSkip = true
	fadeOverlay(0.9)

	while os.clock() - flyStart < FLY_SECONDS do
		if skipped then
			break
		end
		task.wait(0.05)
	end

	local final = finishPose(bay, firstSession, spawnCF)
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = final
		camera.FieldOfView = FOV
	end
	cleanup()
	fadeOverlay(0.2)
	task.wait(0.2)
	gui:Destroy()
end

task.spawn(function()
	local ok, err = pcall(function()
		main()
		return true
	end)
	if not ok then
		warn(`[LoadingScreen] {err}`)
		canSkip = false
		cleanup()
		if gui.Parent then
			fadeOverlay(0.4)
			task.wait(0.4)
			gui:Destroy()
		end
	end
end)
