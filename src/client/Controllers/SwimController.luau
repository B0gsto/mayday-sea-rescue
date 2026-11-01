--!strict
-- SwimController: surface swimming for the local character (docs 10 section 4.5; rules in
-- Shared.Explore.Snorkel). The duck dive was cut (docs/16 C20). The sea has no Terrain water, so
-- without this the character walks on the seabed. Where the water is deeper than Snorkel.WADE_DEPTH:
--   * the Humanoid is held in Swimming (Running / Freefall / Landed / Jumping off) and a
--     LinearVelocity on the root drives it: the move input horizontally, Snorkel's float spring
--     vertically; the eye floats at the surface, face down (mask under) when looking down
--   * Jump (Space, gamepad A, touch jump) is taken off the Humanoid before physics (Stepped):
--     the engine's own jump / swim handling outside Terrain water must never move the swimmer.
-- Feel: a splash on a jump in (VFXKit pickup_splash + Splash_Entry), a stroke rhythm (speed surges on each
-- pull, the head lifts with it, sprint strokes faster), water drag on the speed, and a short climb onto
-- quays / pontoons (push into the edge, or Jump). The foot camera stays above the waves while the head does.
-- Hands off while seated, anchored, climbing, dead, or while the player attribute SwimLocked is true
-- (CONTRACT: a mechanic that moves the character itself in the water sets SwimLocked).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioConfig = require(Shared:WaitForChild("Config"):WaitForChild("AudioConfig"))
local AudioController = require(script.Parent:WaitForChild("AudioController"))
local OceanController = require(script.Parent.OceanController)
local RipCurrent = require(Shared:WaitForChild("RipCurrent"))
local Snorkel = require(Shared:WaitForChild("Explore"):WaitForChild("Snorkel"))
local VFXKit = require(script.Parent.Parent:WaitForChild("VFX"):WaitForChild("VFXKit"))

local SwimController = {}

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
local lv: LinearVelocity? = nil
local swimHumanoid: Humanoid? = nil
local stroke: Sound? = nil
local fallbackTracks: { AnimationTrack } = {}
local swimSince = 0
local lastSplash = -10
local strokePhase = 0
local swimVel = Vector3.zero -- horizontal, follows the stick with water drag
local jumpAt = -10 -- last Jump eaten while swimming: climbs out at once
local climb: { a: CFrame, b: CFrame, c: CFrame, t0: number }? = nil
local CLIMB_UP, CLIMB_OVER = 0.24, 0.16 -- s
-- studs the foot camera keeps above the waves (0.8 put the lens in the wave facets: near-solid water frames)
local CAM_CLEAR = 2
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true

local function setStates(humanoid: Humanoid, enabled: boolean)
	for _, st in DISABLED_STATES do
		humanoid:SetStateEnabled(st, enabled)
	end
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
	if lv then
		lv:Destroy()
		lv = nil
	end
	if stroke then
		local s = stroke :: Sound
		s:Destroy()
		stroke = nil
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

local function surfaceAt(x: number, z: number): number
	local ok, h = pcall(OceanController.GetVisualHeight, x, z)
	return if ok and type(h) == "number" then h else 0
end

-- a jump or fall in throws a splash scaled by the impact; walking in from the shallows only sounds
local function splash(at: Vector3, impact: number)
	local t = os.clock()
	if t - lastSplash < 1.2 then
		return
	end
	lastSplash = t
	local k = math.clamp(impact / 30, 0, 1)
	AudioController.play("Splash_Entry", at, 0.35 + 0.65 * k, 1.1 - 0.2 * k)
	if impact > 6 then
		VFXKit.play("pickup_splash", CFrame.new(at), { scale = 0.55 + 0.55 * k })
	end
end

local function enterSwim(humanoid: Humanoid, root: BasePart)
	swimming = true
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
	swimVel = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1) -- a running jump carries on
	local p = root.Position
	splash(Vector3.new(p.X, surfaceAt(p.X, p.Z), p.Z), -root.AssemblyLinearVelocity.Y)
	local s = AudioController.newSound("Swim_Stroke", root, true)
	s.RollOffMaxDistance = 70
	stroke = s
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

-- Haul out: in the water and pushing into a quay / slipway / pier edge whose top is within reach of the water,
-- the character pulls itself up onto it (the jump is 3 studs, the quay top 4 above the sea: without this the
-- harbour walls trap anyone in the water away from a ladder or the steps).
local HAUL_REACH = 3.5 -- studs from the root to the wall
local HAUL_MAX = 5.5 -- highest ledge above the water surface
local HAUL_PUSH = 0.3 -- s of pushing into the wall first
local pushing = 0
local function haulOut(humanoid: Humanoid, root: BasePart, surfaceY: number, dt: number): boolean
	local move = humanoid.MoveDirection * Vector3.new(1, 0, 1)
	local function probe(from: Vector3): RaycastResult?
		local r = Workspace:Raycast(from, move.Unit * HAUL_REACH, rayParams)
		return if r and r.Normal.Y <= 0.5 then r else nil
	end
	-- a second probe at the waterline finds a shallow pontoon float the root's ray passes under
	local wall = if move.Magnitude > 0.5
		then probe(root.Position) or probe(
			Vector3.new(root.Position.X, surfaceY + 0.3, root.Position.Z)
		)
		else nil
	if not wall then
		pushing = 0
		return false
	end
	pushing += dt
	if pushing < HAUL_PUSH and os.clock() - jumpAt > 0.25 then
		return false
	end
	local dir = move.Unit
	local over = wall.Position + dir * 1.5
	local ledge = Workspace:Raycast(
		Vector3.new(over.X, surfaceY + HAUL_MAX + 0.5, over.Z),
		Vector3.new(0, -(HAUL_MAX + 4), 0),
		rayParams
	)
	if not ledge or ledge.Normal.Y < 0.7 or ledge.Position.Y < root.Position.Y - 1 then
		return false
	end
	-- open above the ledge (a taller wall or a roof blocks the horizontal or the vertical ray)
	local head = ledge.Position.Y + 2.5
	if
		Workspace:Raycast(root.Position, Vector3.new(0, head - root.Position.Y, 0), rayParams)
		or Workspace:Raycast(
			Vector3.new(root.Position.X, head, root.Position.Z),
			dir * (HAUL_REACH + 1.5),
			rayParams
		)
		or Workspace:Raycast(
			ledge.Position + Vector3.new(0, 0.1, 0),
			Vector3.new(0, 4.5, 0),
			rayParams
		)
	then
		return false
	end
	pushing = 0
	local stand = ledge.Position + Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2 + 0.1, 0)
	local up = Vector3.new(root.Position.X, stand.Y, root.Position.Z)
	-- up the wall, then over the edge (both paths cleared by the rays above)
	climb = {
		a = CFrame.lookAt(root.Position, root.Position + dir),
		b = CFrame.lookAt(up, up + dir),
		c = CFrame.lookAt(stand, stand + dir),
		t0 = os.clock(),
	}
	AudioController.play("Splash_Entry", Vector3.new(up.X, surfaceY, up.Z), 0.3, 1.25)
	VFXKit.play("pickup_splash", CFrame.new(up.X, surfaceY, up.Z), { scale = 0.5 })
	return true
end

-- plays the climb out; true while it runs
local function stepClimb(character: Model, root: BasePart): boolean
	local c = climb
	if not c then
		return false
	end
	local t = os.clock() - c.t0
	local cf
	if t < CLIMB_UP then
		local k = t / CLIMB_UP
		cf = c.a:Lerp(c.b, 1 - (1 - k) * (1 - k))
	elseif t < CLIMB_UP + CLIMB_OVER then
		cf = c.b:Lerp(c.c, (t - CLIMB_UP) / CLIMB_OVER)
	else
		climb = nil
		exitSwim()
		cf = c.c
	end
	if lv then
		lv.VectorVelocity = Vector3.zero
	end
	root.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(cf)
	return true
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
		or humanoid:GetState() == Enum.HumanoidStateType.Climbing
	then
		climb = nil
		exitSwim()
		return
	end
	if stepClimb(character, root) then
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
	-- in the water (swimming, or wading on the bottom where the jump cannot clear the wall)
	if pos.Y < surfaceY + 1 and haulOut(humanoid, root, surfaceY, dt) then
		return
	end

	if not swimming or not lv then
		return
	end
	local eyeY = if head then head.Position.Y else pos.Y + 1.5

	if humanoid:GetState() ~= Enum.HumanoidStateType.Swimming then
		humanoid:ChangeState(Enum.HumanoidStateType.Swimming)
	end

	local cam = Workspace.CurrentCamera
	local look = if cam then cam.CFrame.LookVector else root.CFrame.LookVector
	-- WalkSpeed 0 is a freeze (tablet, build mode): no strokes
	local move = if humanoid.WalkSpeed > 0 then humanoid.MoveDirection else Vector3.zero
	local moving = move.Magnitude > 0.1
	-- SprintController raises WalkSpeed above the base walk (Shift / L3 / full touch stick)
	local sprint = humanoid.WalkSpeed > StarterPlayer.CharacterWalkSpeed
	local rate = if not moving
		then Snorkel.TREAD_RATE
		elseif sprint then Snorkel.STROKE_RATE * Snorkel.SPRINT_SWIM
		else Snorkel.STROKE_RATE
	strokePhase = (strokePhase + rate * dt) % 1
	local surge, bob = Snorkel.stroke(strokePhase)
	-- the Captain skill's swim speed (SkillService; no skills = Snorkel.SWIM_SPEED)
	local swimSpeed = Snorkel.SWIM_SPEED
		* (tonumber(player:GetAttribute("SkillSwimMult")) or 1)
		* (if sprint then Snorkel.SPRINT_SWIM else 1)
		* (if moving then surge else 1)
	swimVel += (move * swimSpeed - swimVel) * (1 - math.exp(-Snorkel.WATER_DRAG * dt))
	local horizontal = swimVel
	local vy = Snorkel.verticalVelocity(eyeY, surfaceY, look.Y, if moving then bob else bob * 0.4)
	-- the rip off Puffin Isle (docs/09 section 8.4): stroke plus the current, so swimming
	-- straight back against it barely moves and going across it leaves the channel
	local flow = RipCurrent.velocityAt(RipCurrent.Beach, Vector3.new(pos.X, 0, pos.Z))
	-- mass changes after entry (VehicleService makes a rider massless and restores it once off the
	-- seat): a force sized at entry could not hold the swimmer up and they sank to the seabed
	lv.MaxForce = root.AssemblyMass * (Workspace.Gravity + 80)
	lv.VectorVelocity = Vector3.new(horizontal.X + flow.X, vy, horizontal.Z + flow.Z)
	ensureAnimation(character, humanoid, moving)
	if stroke then
		local s = stroke :: Sound
		s.PlaybackSpeed = if sprint then 1.2 else 1
		local want = if moving then AudioConfig.Clips.Swim_Stroke.volume else 0
		s.Volume += (want - s.Volume) * (1 - math.exp(-8 * dt))
		if s.Volume > 0.01 and not s.IsPlaying then
			s:Play()
		elseif s.Volume <= 0.01 and s.IsPlaying then
			s:Stop()
		end
	end
end

function SwimController.Init()
	player.CharacterRemoving:Connect(function()
		climb = nil
		exitSwim()
	end)
end

-- Stepped runs after the ControlModule sets Humanoid.Jump (render step) and before physics, so the
-- Humanoid never acts on a jump while swimming (F-4: Space sank the swimmer to the seabed).
local function eatJump()
	local humanoid = swimHumanoid
	if swimming and humanoid and humanoid.Jump then
		humanoid.Jump = false
		jumpAt = os.clock()
	end
end

-- After the default camera (and Shake): while the head is above the water, the foot camera never dips
-- under the waves (looking up from a swimmer flicked the Underwater grade on and off with each wave).
-- No height cutoff: a head more than 10 studs up (a deck, the HQ steps at the island edge) let a camera
-- looking up sink under the sea, and the Underwater grade and fog flashed on and off as it orbited.
local function keepCameraDry()
	local camera = Workspace.CurrentCamera
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if
		not camera
		or not head
		or not humanoid
		or humanoid.SeatPart
		or camera.CameraType ~= Enum.CameraType.Custom
	then
		return
	end
	local hp = head.Position
	local headSea = surfaceAt(hp.X, hp.Z)
	if hp.Y < headSea - 0.5 then
		return
	end
	local pos = camera.CFrame.Position
	local floor = surfaceAt(pos.X, pos.Z) + CAM_CLEAR
	if pos.Y < floor then
		local lifted = Vector3.new(pos.X, floor, pos.Z)
		camera.CFrame = CFrame.lookAt(lifted, camera.Focus.Position)
	end
end

function SwimController.Start()
	RunService.Stepped:Connect(eatJump)
	RunService:BindToRenderStep("SwimCameraDry", Enum.RenderPriority.Camera.Value + 2, function()
		xpcall(keepCameraDry, function(err)
			warn(`[SwimController] {err}`)
		end)
	end)
	RunService.Heartbeat:Connect(function(dt)
		xpcall(step, function(err)
			warn(`[SwimController] {err}`)
			exitSwim()
		end, dt)
	end)
end

return SwimController
