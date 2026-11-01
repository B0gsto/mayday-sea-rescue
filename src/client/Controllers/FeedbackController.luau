--!strict
-- FeedbackController: the sound + short visual for two moments with no other home (publish polish, 2026-10-27).
--   - A survivor joins your crew (WorkerService publishes a fresh recruit with `From`): a cheerful chime, and
--     their name tag pops once their rig is drawn (WorkerController + SurvivorTag).
--   - Medals gained (player attribute `Medals` rises): a medal spins in mid-screen over a sunburst with a star
--     burst, holds, then arcs into the Skills button and lands with a ding. Skipped under an open panel (the Skills counter shows it there).
--   - FX2 core loop: a Lego burst round a fresh recruit as their tag pops (crew_arrive), and a splash where your
--     own boat is put in the water (launch_splash).
--   - The recruit reaches their job spot (WorkerController.Arrived, feel review 11): their category icon and "+1"
--     pop over them, a teal ring and their first pay coins (crew_start), then the icon flies to their building's
--     sign and lands with an outline on the building (crew_clockon); a 2.45 s two-shot camera beat frames worker and
--     sign (at most once per 20 s).
-- Sounds go through AudioController (SFX group), so the settings panel's volume and mute apply.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AudioController = require(script.Parent:WaitForChild("AudioController"))
local CameraController = require(script.Parent:WaitForChild("CameraController"))
local Comfort = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("Comfort"))
local RewardPop = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("RewardPop"))
local UiImages = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UiImages")
)
local VFXKit = require(script.Parent.Parent:WaitForChild("VFX"):WaitForChild("VFXKit"))
local WorkerBadge = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("WorkerBadge"))
local WorkerController = require(script.Parent:WaitForChild("WorkerController"))

local FeedbackController = {}

local player = Players.LocalPlayer
local TAG = "SurvivorNameTag" -- SurvivorTag's BillboardGui
-- the medal's height as a share of the screen (it pops in at 1.5x mid-screen, holds at 1.3x: ~27%, a phone reads it)
local MEDAL = 0.21

-- The tag springs up to twice its size and settles.
local function pop(tag: BillboardGui)
	local base = tag.Size
	tag.Size = UDim2.new(base.X.Scale * 2, base.X.Offset * 2, base.Y.Scale * 2, base.Y.Offset * 2)
	TweenService:Create(
		tag,
		TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = base }
	):Play()
end

local function joined(cfg: Instance)
	local from = cfg:GetAttribute("From")
	if not (cfg:IsA("Configuration") and typeof(from) == "CFrame") then
		return -- only fresh recruits walk in from the jetty
	end
	if not (cfg.Parent and cfg.Parent.Name == tostring(player.UserId)) then
		return
	end
	AudioController.play("Album_Sparkle", nil, 1.3, 1.12)
	task.delay(0.12, function()
		AudioController.play("Album_Sparkle", nil, 1, 1.5)
	end)
	local name = cfg:GetAttribute("SurvivorName")
	task.spawn(function()
		for _ = 1, 24 do -- the rig shows up when the templates are in and you are in range
			local folder = Workspace:FindFirstChild("WorkersLocal")
			for _, rig in if folder then folder:GetChildren() else {} do
				local tag = rig:FindFirstChild(TAG)
				if
					tag
					and tag:IsA("BillboardGui")
					and rig:IsA("Model")
					and rig:GetAttribute("SurvivorName") == name
					and (rig:GetPivot().Position - from.Position).Magnitude < 80
				then
					pop(tag)
					AudioController.play("UI_FriendPop", rig:GetPivot().Position, 1.5, 1.1)
					local _, size = rig:GetBoundingBox()
					VFXKit.play(
						"crew_arrive",
						rig:GetPivot() - Vector3.new(0, size.Y * 0.5, 0),
						{ radius = 2, height = size.Y + 1 }
					)
					return
				end
			end
			task.wait(0.25)
		end
	end)
end

local BEAT_GAP = 20 -- s: at most one arrival camera beat in this window (a wave of recruits gets one)
local lastBeat = -math.huge

-- The recruit's building on your plot (cfg Workplace) and the point to frame on it: its sign (and the way the sign
-- faces), else the upper middle of the building. Nil while it has no building there (a Builder on a site).
local function workplace(cfg: Configuration): (Model?, Vector3, Vector3?)
	local key = cfg:GetAttribute("Workplace")
	local marina = Workspace:FindFirstChild("Marina")
	local plot = marina and marina:FindFirstChild(`Plot{player:GetAttribute("DockPlot")}`)
	local b = if type(key) == "string" and key ~= "" and plot then plot:FindFirstChild(key) else nil
	if not (b and b:IsA("Model")) then
		return nil, Vector3.zero, nil
	end
	local sign: BasePart? = nil
	for _, d in b:GetDescendants() do
		if
			d.Name == "Sign"
			and d:IsA("BasePart")
			and (not sign or d.Size.Magnitude > sign.Size.Magnitude)
		then
			sign = d
		end
	end
	if sign then
		return b :: Model, sign.Position, sign.CFrame.LookVector -- DockPieces' sign faces -Z
	end
	local cf, size = b:GetBoundingBox()
	return b :: Model, cf.Position + Vector3.new(0, size.Y * 0.25, 0), nil
end

-- A 2.45 s two-shot: the camera eases out to frame the new worker in front of their building's sign, holds with a
-- slow push, and eases back (a cut and a 2 s hold under Reduce motion). Skippable.
local function beat(rig: Model, focus: Vector3, face: Vector3?)
	local cam = Workspace.CurrentCamera
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if
		not (cam and hum)
		or (hum.SeatPart and hum.SeatPart.AssemblyLinearVelocity.Magnitude > 4) -- moored after a delivery is fine
		or player:GetAttribute("MenuOpen") == true
		or player:GetAttribute("CinematicPlaying") == true
		or os.clock() - lastBeat < BEAT_GAP
		or (cam.CFrame.Position - focus).Magnitude > 150 -- too far off to be your moment
	then
		return
	end
	lastBeat = os.clock()
	local at = rig:GetPivot().Position + Vector3.new(0, 1, 0)
	local mid = at:Lerp(focus, 0.5)
	local flat = Vector3.new(1, 0, 1)
	-- in front of the sign and on the worker's side of the building, so the worker stands before it
	local toWorker = (at - focus) * flat
	local dir = (if face then face * flat else Vector3.zero)
		+ (if toWorker.Magnitude > 0.5 then toWorker.Unit * 0.8 else Vector3.zero)
	if dir.Magnitude < 0.1 then
		dir = (cam.CFrame.Position - mid) * flat
	end
	dir = if dir.Magnitude > 0.1 then dir.Unit else Vector3.zAxis
	-- shortcut: no occlusion test, the sign side is open by construction; raycast and swing if a wall hides the worker
	local dist = math.clamp((focus - at).Magnitude * 1.1 + 10, 14, 45)
	local view = CFrame.lookAt(mid + dir * dist + Vector3.new(0, dist * 0.35, 0), mid)
	local back, fov = cam.CFrame, cam.FieldOfView
	local opts = { id = "recruit_arrive", repeatable = true, skippable = true }
	if Comfort.reducedMotion() then
		CameraController.PlayCinematic(
			{ { from = view, duration = 2, fov = fov, handheld = 0 } },
			opts
		)
		return
	end
	local near = view * CFrame.new(0, 0, -1.5)
	CameraController.PlayCinematic({
		{ from = back, to = view, duration = 0.45, fov = fov, toFov = 55, handheld = 0 },
		{ from = view, to = near, duration = 1.5, fov = 55, handheld = 0.1 },
		{ from = near, to = back, duration = 0.5, fov = 55, toFov = fov, handheld = 0 },
	}, opts)
end

-- A steady outline round the building while the icon sits on it: fades in, holds, fades out (one beat, no pulse).
local function outline(building: Model)
	local h = Instance.new("Highlight")
	h.Adornee = building
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.FillColor = Color3.fromRGB(0, 160, 175) -- Presets' SEA teal, never orange
	h.FillTransparency = 1
	h.OutlineColor = Color3.new(1, 1, 1)
	h.OutlineTransparency = 1
	h.Parent = building
	TweenService:Create(h, TweenInfo.new(0.2), { OutlineTransparency = 0, FillTransparency = 0.8 })
		:Play()
	task.delay(0.8, function()
		TweenService
			:Create(h, TweenInfo.new(0.45), { OutlineTransparency = 1, FillTransparency = 1 })
			:Play()
		task.delay(0.5, h.Destroy, h)
	end)
end

-- The recruit reaches their spot and clocks on. t=0: teal ring + their category icon and "+1" pop over them, the
-- camera eases to the two-shot; t=0.55: the icon flies to their building's sign (whoosh); t=1.15: it lands with a
-- pop, plates and a ding, the building takes a white outline; t=2.0 it shrinks away; camera back by t=2.45.
local function arrived(cfg: Configuration, rig: Model)
	local root = rig.PrimaryPart
	local category = cfg:GetAttribute("Category") or cfg:GetAttribute("WorkerCategory")
	if not (root and type(category) == "string") then
		return
	end
	local _, size = rig:GetBoundingBox()
	VFXKit.play("crew_start", rig:GetPivot() - Vector3.new(0, size.Y * 0.5, 0), { radius = 2 })
	local building, focus, face = workplace(cfg)
	local gui = Instance.new("BillboardGui")
	gui.Name = "StartPop"
	gui.Adornee = root
	gui.Size = UDim2.fromOffset(84, 40)
	gui.StudsOffset = Vector3.new(0, 6.2, 0)
	gui.MaxDistance = 160
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = gui
	local icon = Instance.new("Frame")
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(38, 38)
	icon.Position = UDim2.fromOffset(2, 1)
	icon.Parent = gui
	WorkerBadge.icon(icon, category)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(42, 0)
	label.Size = UDim2.fromOffset(42, 40)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "+1"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	gui.Parent = rig
	TweenService:Create(
		scale,
		TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()
	local out = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local function leave(hold: number, rise: Vector3)
		task.delay(hold, function()
			TweenService
				:Create(gui, out, { StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + rise })
				:Play()
			TweenService:Create(label, out, { TextTransparency = 1, TextStrokeTransparency = 1 })
				:Play()
			TweenService:Create(scale, out, { Scale = 0 }):Play() -- the icon disc has no fade: it shrinks away
			task.delay(0.5, gui.Destroy, gui)
		end)
	end
	if not building then
		leave(1.4, Vector3.new(0, 2.2, 0)) -- no building to point at: one pop over them, then it drifts up
		return
	end
	beat(rig, focus, face)
	-- the flight: the icon leaves the worker and lands above the sign (an offset in the root's frame)
	task.delay(0.55, function()
		if not (gui.Parent and root.Parent) then
			return
		end
		AudioController.play("FX_Whoosh", root.Position, 0.6, 1.2)
		local over = focus + Vector3.new(0, 2.5, 0)
		TweenService
			:Create(gui, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
				StudsOffset = Vector3.zero,
				StudsOffsetWorldSpace = root.CFrame:VectorToObjectSpace(over - root.Position),
			})
			:Play()
		task.delay(0.6, function()
			scale.Scale = 1.35
			TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 })
				:Play()
			VFXKit.play("crew_clockon", CFrame.new(over), { radius = 1.5 })
			outline(building)
			leave(0.85, Vector3.new(0, 1.5, 0))
		end)
	end)
end

local function flip()
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	local menu = playerGui and playerGui:FindFirstChild("Menu")
	local target = menu and menu:FindFirstChild("Menu_Skills", true)
	local camera = Workspace.CurrentCamera
	if not (playerGui and menu and target and target:IsA("GuiObject") and camera) then
		AudioController.play("UI_Step", nil, 1, 1.3)
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "MedalFlip"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 41
	gui.IgnoreGuiInset = (menu :: ScreenGui).IgnoreGuiInset
	gui.Parent = playerGui
	task.delay(4, gui.Destroy, gui) -- failsafe: never a medal parked on screen
	local start = camera.ViewportSize * Vector2.new(0.5, 0.4)
	local goal = target.AbsolutePosition + target.AbsoluteSize / 2
	local reduced = Comfort.reducedMotion()
	local size = math.floor(camera.ViewportSize.Y * MEDAL)
	-- the world dims behind the hold (35%), so the medal is the one thing on screen, and clears as it flies
	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 1
	dim.BorderSizePixel = 0
	dim.Parent = gui
	if not reduced then
		TweenService:Create(dim, TweenInfo.new(0.2), { BackgroundTransparency = 0.65 }):Play()
	end
	-- FX2b: anticipation (a sunburst swells, the medal spins in with a rise), impact (it lands big with a star
	-- burst and a power-up), a short hold, then an arc into the Skills button, which squashes with a ding
	local holder = Instance.new("ImageLabel")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromOffset(start.X, start.Y)
	holder.Size = UDim2.fromOffset(size * 0.69, size) -- the sticker's own shape (260 x 300 box, trimmed)
	holder.Image = UiImages.Badges.Medal
	holder.ScaleType = Enum.ScaleType.Fit
	holder.ZIndex = 2
	holder.Parent = gui
	AudioController.play("FX_Reveal", nil, 0.8, 1.2)
	task.delay(0.28, AudioController.play, "FX_PowerUp", nil, 0.9, 1.1)
	local grow = Instance.new("UIScale")
	grow.Parent = holder
	if not reduced then
		RewardPop.rays(gui, start, size * 3.2, 1.05)
		task.delay(0.28, RewardPop.stars, gui, start, size * 1.1, 8)
		grow.Scale = 0.2
		local swell =
			TweenService:Create(grow, TweenInfo.new(0.32, Enum.EasingStyle.Back), { Scale = 1.5 })
		swell.Completed:Once(
			function() -- then a soft settle while it holds (a second tween now would cancel this)
				TweenService
					:Create(grow, TweenInfo.new(0.35, Enum.EasingStyle.Sine), { Scale = 1.3 })
					:Play()
			end
		)
		swell:Play()
		-- the spin-in: its width flips twice and slows (a coin landing face up)
		TweenService:Create( -- reverses: it ends at full width
			holder,
			TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 1, true),
			{ Size = UDim2.fromOffset(size * 0.06, size) }
		):Play()
		holder.Rotation = -25
		TweenService:Create(holder, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Rotation = 0 })
			:Play()
	end
	-- the flight: a bezier from mid-screen up and over into the button, easing in (it falls into its slot)
	local hold = if reduced then 0 else 0.72
	local lift = start + Vector2.new((goal.X - start.X) * 0.35, -size * 1.2)
	task.delay(hold, function()
		local t = Instance.new("NumberValue")
		local fly = TweenService:Create(
			t,
			TweenInfo.new(
				if reduced then 0.2 else 0.55,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			),
			{ Value = 1 }
		)
		local scale0 = grow.Scale
		TweenService:Create(dim, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		t.Changed:Connect(function(k: number)
			local p = start:Lerp(lift, k):Lerp(lift:Lerp(goal, k), k)
			holder.Position = UDim2.fromOffset(p.X, p.Y)
			grow.Scale = scale0 + (target.AbsoluteSize.Y / size - scale0) * k -- lands at the button's size
			holder.Rotation = 20 * k
		end)
		fly.Completed:Once(function()
			gui:Destroy()
			AudioController.play("FX_Ding", nil, 0.9, 1.5)
			AudioController.play("FX_Pop", nil, 0.7, 1.2)
			local scale = target:FindFirstChildOfClass("UIScale") or Instance.new("UIScale") -- one per button
			scale.Parent = target
			scale.Scale = 1.35
			TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 })
				:Play()
			if not reduced then -- a small sunburst and stars round the button it landed in
				local land = Instance.new("ScreenGui")
				land.Name = "MedalLand"
				land.ResetOnSpawn = false
				land.DisplayOrder = 41
				land.IgnoreGuiInset = gui.IgnoreGuiInset
				land.Parent = playerGui
				local w = target.AbsoluteSize.X
				RewardPop.rays(land, goal, w * 3.4, 0.6)
				RewardPop.stars(land, goal, w * 1.5, 9) -- chunky: a star is ~half the button
				task.delay(0.8, land.Destroy, land)
			end
		end)
		fly:Play()
	end)
end

function FeedbackController.Init() end

function FeedbackController.Start()
	local medals = player:GetAttribute("Medals")
	WorkerController.Arrived:Connect(arrived)
	player:GetAttributeChangedSignal("Medals"):Connect(function()
		local now = player:GetAttribute("Medals")
		if
			type(medals) == "number"
			and type(now) == "number"
			and now > medals
			and player:GetAttribute("MenuOpen") ~= true
		then
			flip()
		end
		medals = now
	end)
	-- your boat put in the water (the board's Launch, the free jet ski): a splash once it has streamed in
	task.spawn(function()
		local vehicles = Workspace:WaitForChild("Vehicles", 30)
		if not vehicles then
			return
		end
		vehicles.ChildAdded:Connect(function(m)
			if not (m:IsA("Model") and m:GetAttribute("Owner") == player.UserId) then
				return
			end
			for _ = 1, 20 do
				if m.PrimaryPart then
					local at = m.PrimaryPart.Position
					VFXKit.play(
						"launch_splash",
						CFrame.new(at.X, math.min(at.Y, 1), at.Z),
						{ radius = 3 }
					)
					return
				end
				task.wait(0.1)
			end
		end)
	end)
	local root = ReplicatedStorage:WaitForChild("Workers")
	root.DescendantAdded:Connect(joined) -- existing workers never carry `From` on a rejoin
end

return FeedbackController
