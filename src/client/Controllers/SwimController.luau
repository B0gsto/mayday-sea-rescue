--!strict
-- SwimController: snorkelling and breath-hold duck dives for the local character (docs 10 section
-- 4.5; rules in Shared.Explore.Snorkel). The sea has no Terrain water, so without this the
-- character walks on the seabed. Where the water is deeper than Snorkel.WADE_DEPTH:
--   * the Humanoid is held in Swimming (Running / Freefall / Landed / Jumping off) and a
--     LinearVelocity on the root drives it: the move input horizontally, Snorkel's float spring or
--     dive vertically; the eye floats at the surface, face down (mask under) when looking down
--   * Dive: C, gamepad B or the DIVE touch button (ContextActionService, bound only while
--     swimming); while diving, forward input follows the camera pitch; Jump / the same button
--     surfaces; out of breath it surfaces by itself. A breath bar shows in the "gauges" region.
--   * Fins gear swims faster (PlayerDataChanged gear.Fins).
-- Hands off while seated, anchored, climbing, dead, or while the player attribute SwimLocked is true
-- (CONTRACT: a mechanic that moves the character itself in the water sets SwimLocked).
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HudTheme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("HudTheme"))
local Layout = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Layout"))
local Net = require(Shared:WaitForChild("Net"))
local OceanController = require(script.Parent.OceanController)
local Snorkel = require(Shared:WaitForChild("Explore"):WaitForChild("Snorkel"))

local SwimController = {}

local ACTION = "SnorkelDive"
local DISABLED_STATES = {
	Enum.HumanoidStateType.Running,
	Enum.HumanoidStateType.RunningNoPhysics,
	Enum.HumanoidStateType.Freefall,
	Enum.HumanoidStateType.Landed,
	Enum.HumanoidStateType.Jumping,
	Enum.HumanoidStateType.FallingDown,
	Enum.HumanoidStateType.GettingUp,
}

local player = Players.LocalPlayer
local swimming = false
local mode: Snorkel.Mode = "surface"
local breath = Snorkel.BREATH
local diveStarted = 0
local divePressed, surfacePressed = false, false
local finsLevel = 0
local lv: LinearVelocity? = nil
local swimHumanoid: Humanoid? = nil
local fallbackTracks: { AnimationTrack } = {}
local swimSince = 0
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true

local hud: { root: Frame, fill: Frame }? = nil

local function buildHud()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SnorkelHud"
	gui.ResetOnSpawn = false
	Layout.prepare(gui)
	gui.Parent = player:WaitForChild("PlayerGui")
	local region = Layout.region(gui, "gauges")
	local root = HudTheme.panel("Breath", UDim2.fromOffset(180, 40), region)
	root.AnchorPoint = Vector2.new(1, 1)
	root.Position = UDim2.fromScale(1, 1)
	root.Visible = false
	HudTheme.padding(root, 8)
	local label =
		HudTheme.label("Label", "BREATH", UDim2.new(0, 64, 1, 0), HudTheme.HeaderFont, 15, root)
	label.TextColor3 = HudTheme.Colors.textDim
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.AnchorPoint = Vector2.new(1, 0.5)
	track.Position = UDim2.fromScale(1, 0.5)
	track.Size = UDim2.new(1, -70, 0, 6)
	track.BackgroundColor3 = HudTheme.Colors.locked
	track.BorderSizePixel = 0
	track.Parent = root
	HudTheme.corner(track, 3)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = HudTheme.Colors.bar
	fill.BorderSizePixel = 0
	fill.Parent = track
	HudTheme.corner(fill, 3)
	hud = { root = root, fill = fill }
end

local function setStates(humanoid: Humanoid, enabled: boolean)
	for _, st in DISABLED_STATES do
		humanoid:SetStateEnabled(st, enabled)
	end
end

local function onAction(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		if mode == "surface" then
			divePressed = true
		else
			surfacePressed = true
		end
	end
	return Enum.ContextActionResult.Sink
end

local function stopFallback()
	for _, t in fallbackTracks do
		t:Stop(0.3)
	end
	table.clear(fallbackTracks)
end

local function exitSwim()
	if not swimming then
		return
	end
	swimming = false
	mode = "surface"
	ContextActionService:UnbindAction(ACTION)
	if lv then
		lv:Destroy()
		lv = nil
	end
	stopFallback()
	local humanoid = swimHumanoid
	swimHumanoid = nil
	if humanoid and humanoid.Parent then
		setStates(humanoid, true)
		if humanoid:GetState() == Enum.HumanoidStateType.Swimming then
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		end
	end
end

local function enterSwim(humanoid: Humanoid, root: BasePart)
	swimming = true
	mode = "surface"
	swimHumanoid = humanoid
	swimSince = os.clock()
	setStates(humanoid, false)
	humanoid:ChangeState(Enum.HumanoidStateType.Swimming)
	local att = root:FindFirstChild("RootAttachment") :: Attachment?
	if not att then
		local a = Instance.new("Attachment")
		a.Name = "SwimAttachment"
		a.Parent = root
		att = a
	end
	local v = Instance.new("LinearVelocity")
	v.Name = "SnorkelSwim"
	v.Attachment0 = att
	v.RelativeTo = Enum.ActuatorRelativeTo.World
	v.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	v.MaxForce = root.AssemblyMass * (Workspace.Gravity + 80)
	v.VectorVelocity = root.AssemblyLinearVelocity * Vector3.new(1, 0.2, 1)
	v.Parent = root
	lv = v
	ContextActionService:BindAction(ACTION, onAction, true, Enum.KeyCode.C, Enum.KeyCode.ButtonB)
	ContextActionService:SetTitle(ACTION, "DIVE")
	ContextActionService:SetPosition(ACTION, UDim2.new(1, -150, 1, -150))
end

-- The default Animate script may not play swim tracks outside Terrain water: play its own swim
-- animations once if nothing swim-like is playing half a second in.
local function ensureAnimation(character: Model, humanoid: Humanoid, moving: boolean)
	if os.clock() - swimSince < 0.5 then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	local animate = character:FindFirstChild("Animate")
	if not animator or not animate then
		return
	end
	if #fallbackTracks == 0 then
		for _, t in animator:GetPlayingAnimationTracks() do
			if t.Animation and string.find(string.lower(t.Animation.Name), "swim") then
				return -- Animate handles it
			end
		end
		for _, name in { "swim", "swimidle" } do
			local folder = animate:FindFirstChild(name)
			local anim = folder and folder:FindFirstChildOfClass("Animation")
			if anim then
				local t = animator:LoadAnimation(anim)
				t.Priority = Enum.AnimationPriority.Movement
				t.Looped = true
				table.insert(fallbackTracks, t)
			end
		end
	end
	local swimTrack, idleTrack = fallbackTracks[1], fallbackTracks[2]
	if swimTrack and moving and not swimTrack.IsPlaying then
		swimTrack:Play(0.3)
		if idleTrack then
			idleTrack:Stop(0.3)
		end
	elseif idleTrack and not moving and not idleTrack.IsPlaying then
		idleTrack:Play(0.3)
		if swimTrack then
			swimTrack:Stop(0.3)
		end
	end
end

local function surfaceAt(x: number, z: number): number
	local ok, h = pcall(OceanController.GetVisualHeight, x, z)
	return if ok and type(h) == "number" then h else 0
end

local function step(dt: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if
		not character
		or not humanoid
		or not root
		or humanoid.Health <= 0
		or humanoid.SeatPart ~= nil
		or root.Anchored
		or player:GetAttribute("SwimLocked") == true
		or humanoid:GetState() == Enum.HumanoidStateType.Climbing
	then
		exitSwim()
		breath = Snorkel.stepBreath(breath, false, dt)
		if hud then
			hud.root.Visible = false
		end
		return
	end
	local pos = root.Position
	local surfaceY = surfaceAt(pos.X, pos.Z)
	rayParams.FilterDescendantsInstances = { character }
	local hit = Workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -400, 0), rayParams)
	local floorY = if hit then hit.Position.Y else -1e4
	local should = Snorkel.shouldSwim(pos.Y, surfaceY, floorY, swimming)
	if should and not swimming then
		enterSwim(humanoid, root)
	elseif not should and swimming then
		exitSwim()
	end

	local eyeY = if head then head.Position.Y else pos.Y + 1.5
	local under = swimming and eyeY < surfaceY - 0.3
	breath = Snorkel.stepBreath(breath, under, dt)
	if hud then
		hud.root.Visible = swimming and (mode ~= "surface" or breath < Snorkel.BREATH - 0.05)
		hud.fill.Size = UDim2.fromScale(breath / Snorkel.BREATH, 1)
		hud.fill.BackgroundColor3 = if breath < Snorkel.BREATH * 0.25
			then HudTheme.Colors.accent
			else HudTheme.Colors.bar
	end
	if not swimming or not lv then
		return
	end

	if humanoid.Jump then
		humanoid.Jump = false
		if mode == "dive" then
			surfacePressed = true
		end
	end
	local prev = mode
	mode = Snorkel.nextMode(mode, surfaceY - eyeY, breath, divePressed, surfacePressed)
	divePressed, surfacePressed = false, false
	if mode == "dive" and prev ~= "dive" then
		diveStarted = os.clock()
	end
	if mode ~= prev then
		ContextActionService:SetTitle(ACTION, if mode == "surface" then "DIVE" else "UP")
	end
	if humanoid:GetState() ~= Enum.HumanoidStateType.Swimming then
		humanoid:ChangeState(Enum.HumanoidStateType.Swimming)
	end

	local cam = Workspace.CurrentCamera
	local look = if cam then cam.CFrame.LookVector else root.CFrame.LookVector
	local move = humanoid.MoveDirection
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
	local forward = math.max(0, move:Dot(flat))
	local speed = Snorkel.speed(mode, finsLevel)
	local horizontal = move * speed
	if mode == "dive" and forward > 0.1 then
		-- head-first: the forward part of the input follows the camera, strafing stays flat
		local side = move - flat * move:Dot(flat)
		horizontal = Vector3.new(look.X, 0, look.Z) * speed * forward + side * speed
	end
	local vy = Snorkel.verticalVelocity(
		mode,
		eyeY,
		surfaceY,
		floorY,
		look.Y,
		forward,
		os.clock() - diveStarted
	)
	lv.VectorVelocity = Vector3.new(horizontal.X, vy, horizontal.Z)
	ensureAnimation(character, humanoid, move.Magnitude > 0.1)
end

function SwimController.Init()
	buildHud()
	local ev = Net.event("PlayerDataChanged")
	if ev then
		ev.OnClientEvent:Connect(function(snapshot: any)
			if type(snapshot) == "table" and type(snapshot.gear) == "table" then
				finsLevel = tonumber(snapshot.gear.Fins) or finsLevel
			end
		end)
	end
	player.CharacterRemoving:Connect(function()
		exitSwim()
		breath = Snorkel.BREATH
	end)
end

function SwimController.Start()
	RunService.Heartbeat:Connect(function(dt)
		xpcall(step, function(err)
			warn(`[SwimController] {err}`)
			exitSwim()
		end, dt)
	end)
end

return SwimController
