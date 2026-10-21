--!strict
-- Transition: the close-work camera move between the third-person view and the eye point.
-- A 0.72 s eased dolly: the lens narrows a touch at the middle, a light depth-of-field and a
-- vignette pulse, the body fades as the camera passes through the head, and the viewmodel hands
-- rise at the end (CameraController). The path is spherecast clear of geometry and kept above the
-- swell. Comfort.reduceMotion swaps it for a quick fade cut.
--
--   Transition.begin(opts)            start a move (stops any move still running)
--   Transition.update(dt): boolean    drive it; false once it has settled
--   Transition.progress(): number     eased 0..1 of the current move
--   Transition.running(): boolean
--   Transition.stop()                 cancel and remove the effects
--
-- opts: { from: CFrame, to: () -> CFrame, fovFrom: number, fovTo: number,
--         bodyAtTarget: number? (1 hidden at the destination, 0 visible), waveHeight: fn?,
--         focus: (() -> Vector3?)? (close work: the dolly ends looking at this care area),
--         exclude: { Instance }? }
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Comfort = require(script.Parent.Comfort)
local TransitionMath = require(script.Parent.TransitionMath)

local Transition = {}

export type Opts = {
	from: CFrame,
	to: () -> CFrame,
	fovFrom: number,
	fovTo: number,
	bodyAtTarget: number?,
	waveHeight: ((Vector3) -> number)?,
	focus: (() -> Vector3?)?,
	exclude: { Instance }?,
}

type Active = {
	opts: Opts,
	from: CFrame,
	t: number,
	duration: number,
	reduced: boolean,
	bodyAtTarget: number,
	exclude: { Instance },
}

local active: Active? = nil
local dof: DepthOfFieldEffect? = nil
local vignetteGui: ScreenGui? = nil
local vignetteFrames: { Frame } = {}
local blackout: Frame? = nil

local castParams = RaycastParams.new()
castParams.FilterType = Enum.RaycastFilterType.Exclude
castParams.IgnoreWater = true
castParams.RespectCanCollide = true

local function ensureGui()
	if vignetteGui then
		return
	end
	local player = Players.LocalPlayer
	if not player then
		return
	end
	table.clear(vignetteFrames)
	local gui = Instance.new("ScreenGui")
	gui.Name = "MaydayCameraVignette"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 30
	gui.Enabled = false
	local edges = {
		{ size = UDim2.fromScale(1, 0.42), at = UDim2.fromScale(0, 0), rotation = 90 },
		{ size = UDim2.fromScale(1, 0.42), at = UDim2.fromScale(0, 0.58), rotation = 270 },
		{ size = UDim2.fromScale(0.42, 1), at = UDim2.fromScale(0, 0), rotation = 0 },
		{ size = UDim2.fromScale(0.42, 1), at = UDim2.fromScale(0.58, 0), rotation = 180 },
	}
	for _, e in edges do
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0, 0)
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BackgroundTransparency = 1
		f.Size = e.size
		f.Position = e.at
		f.ZIndex = 2
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = e.rotation
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = f
		f.Parent = gui
		table.insert(vignetteFrames, f)
	end
	local black = Instance.new("Frame")
	black.Name = "Cut"
	black.BorderSizePixel = 0
	black.BackgroundColor3 = Color3.new(0, 0, 0)
	black.BackgroundTransparency = 1
	black.Size = UDim2.fromScale(1, 1)
	black.ZIndex = 3
	black.Visible = false
	black.Parent = gui
	blackout = black
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then
		gui:Destroy()
		return -- try again next frame; never yield inside a render step
	end
	gui.Parent = playerGui
	vignetteGui = gui
end

local function ensureDof()
	if dof then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local d = Instance.new("DepthOfFieldEffect")
	d.Name = "MaydayCloseFocus"
	d.FocusDistance = 9
	d.InFocusRadius = 26
	d.NearIntensity = 0
	d.FarIntensity = 0
	d.Parent = camera
	dof = d
end

local function clearEffects()
	if dof then
		dof:Destroy()
		dof = nil
	end
	if vignetteGui then
		vignetteGui.Enabled = false
	end
	if blackout then
		blackout.Visible = false
		blackout.BackgroundTransparency = 1
	end
end

local function setBodyAlpha(alpha: number)
	local char = Players.LocalPlayer.Character
	if not char then
		return
	end
	local a = math.clamp(alpha, 0, 1)
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			(d :: any).LocalTransparencyModifier = a
		end
	end
end

local function headPoint(): Vector3?
	local char = Players.LocalPlayer.Character
	local head = char and char:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position
	end
	return nil
end

local function pulseEffects(pulse: number, vignette: number)
	if dof then
		dof.NearIntensity = 0.45 * pulse
		dof.FarIntensity = 0.22 * pulse
	end
	if vignetteGui and blackout then
		local on = vignette > 0.01
		vignetteGui.Enabled = on
		blackout.Visible = false
		for _, f in vignetteFrames do
			f.BackgroundTransparency = 1 - 0.8 * vignette
		end
	end
end

function Transition.begin(opts: Opts)
	Transition.stop()
	local reduced = Comfort.reducedMotion()
	local camera = Workspace.CurrentCamera
	local duration = TransitionMath.duration(reduced)
	active = {
		opts = opts,
		from = opts.from,
		t = 0,
		duration = duration,
		reduced = reduced,
		bodyAtTarget = math.clamp(opts.bodyAtTarget or 0, 0, 1),
		exclude = opts.exclude or {},
	}
	if camera then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	ensureGui()
	ensureDof()
	if reduced then
		-- the cut uses the same overlay: black rising to full, then clearing
		pulseEffects(0, 0)
		if vignetteGui and blackout then
			vignetteGui.Enabled = true
			blackout.Visible = true
			blackout.BackgroundTransparency = 1
		end
	end
end

function Transition.running(): boolean
	return active ~= nil
end

function Transition.progress(): number
	local a = active
	if not a then
		return 1
	end
	return TransitionMath.ease(a.t / math.max(a.duration, 0.001))
end

function Transition.update(dt: number): boolean
	local a = active
	if not a then
		return false
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return true
	end
	a.t += dt
	local k = math.clamp(a.t / math.max(a.duration, 0.001), 0, 1)
	local target = a.opts.to()
	local focus = a.opts.focus and a.opts.focus()
	if focus then
		target = TransitionMath.aim(target.Position, focus)
	end
	camera.CameraType = Enum.CameraType.Scriptable

	if a.reduced then
		-- quick fade cut: hold the old frame, swap at full black, clear
		local before = k < 0.5
		local cf = if before then a.from else target
		camera.CFrame = cf
		camera.FieldOfView = if before then a.opts.fovFrom else a.opts.fovTo
		setBodyAlpha(if before then 1 - a.bodyAtTarget else a.bodyAtTarget)
		if blackout then
			blackout.BackgroundTransparency = 1 - TransitionMath.cutAlpha(k)
		end
	else
		local e = TransitionMath.ease(k)
		local eye = headPoint() or a.from.Position
		local p = TransitionMath.point(a.from.Position, target.Position, e)
		castParams.FilterDescendantsInstances = a.exclude
		local delta = p - eye
		if delta.Magnitude > 1e-3 then
			local hit = Workspace:Spherecast(eye, 0.45, delta, castParams)
			p = TransitionMath.pullIn(
				eye,
				p,
				if hit then hit.Distance else nil,
				TransitionMath.WALL_PAD
			)
		end
		if a.opts.waveHeight then
			p = TransitionMath.aboveWater(p, a.opts.waveHeight(p), TransitionMath.WATER_CLEARANCE)
		end
		camera.CFrame = CFrame.new(p) * a.from.Rotation:Lerp(target.Rotation, e)
		camera.FieldOfView = TransitionMath.fov(a.opts.fovFrom, a.opts.fovTo, e)
		setBodyAlpha(TransitionMath.bodyAlpha((p - eye).Magnitude))
		pulseEffects(TransitionMath.pulse(k), TransitionMath.pulse(k) * 0.5)
	end

	if k >= 1 then
		-- settle exactly on the destination and its lens
		camera.CFrame = target
		camera.FieldOfView = a.opts.fovTo
		setBodyAlpha(a.bodyAtTarget)
		active = nil
		clearEffects()
		return false
	end
	return true
end

function Transition.stop()
	active = nil
	clearEffects()
end

return Transition
