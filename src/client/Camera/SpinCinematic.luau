--!strict
-- SpinCinematic (owner 2026-11-01: "a cool animation and a cinematic, very cool"): the spinner's own prize-wheel
-- show. Other players only see the wheel spin, the burst and the flex banner (PrizeWheelController).
--   takeover  the camera swoops to a low hero shot of the wheel and pushes in as it slows; letterbox, the world dims
--             and desaturates, the HUD and prompts hide, a drone rises under a heartbeat
--   ladder    a stud-star flare charges at the hub while a rarity label climbs Common -> the won rarity (one pop,
--             colour shift, pitch-up sting and camera kick a step; Epic+ fakes out once: SpinCinePlan)
--   payoff    Rare a beam; Epic a purple sky + orbit; Legendary a golden sea (shafts, a gold plinth rises, coin
--             rain); Mythic lightning, a starfield, a gold Lego halo built brick by brick, a ray tunnel, whiteout
--   reveal    the prize pops out of the hub in front of the wheel (the caller's reveal sets SpinRevealed), a hold,
--             then everything is restored
-- Any tap / click / key / button after SKIP_AFTER jumps to the reveal (or ends the hold). Reduce motion: no shake,
-- no kicks, soft washes only. Every beat has a sound.
--   SpinCinematic.start(ctx) -> true      ctx: { payload, hub: CFrame (the rotor's rest pivot), landIn: number,
--                                          reveal: (Vector3) -> (), colorOf: (string) -> Color3, onExit: () -> () }
--   SpinCinematic.active(): boolean
--   SpinCinematic.whenDone(fn)            runs fn now, or when the takeover ends (the spinner's flex banner)
-- Player attribute SpinCinematic (true while on).
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Comfort = require(script.Parent:WaitForChild("Comfort"))
local SpinCinePlan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SpinCinePlan"))
local SpinRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SpinRules"))
local VFXTextures = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("VFXTextures")
)
local Controllers = script.Parent.Parent:WaitForChild("Controllers")
local AudioController = require(Controllers:WaitForChild("AudioController"))
local CameraController = require(Controllers:WaitForChild("CameraController"))
local VFXKit = require(script.Parent.Parent:WaitForChild("VFX"):WaitForChild("VFXKit"))

local player = Players.LocalPlayer
local UP = Vector3.yAxis
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 198, 64)
local WARM_WHITE = Color3.fromRGB(255, 250, 235)
local STAGE = 10 -- studs in front of the hub where the prize is shown
local HALO_BRICKS = 24
local HALO_RADIUS = 9

type Grade = { tint: Color3, bright: number, sat: number, contrast: number }
type Beat = { at: number, seq: number, fn: () -> () }
type Brick = { model: Model, start: number, from: Vector3, angle: number }
type Run = {
	payload: any,
	plan: SpinCinePlan.Plan,
	land: number, -- os.clock() when the wheel stops
	spinTime: number,
	hub: Vector3,
	n: Vector3, -- out of the wheel's face, toward the player
	view: Vector3, -- the shots' axis: n, swung aside when buildings crowd the wheel's front
	room: number, -- 0.4..1: how much of the 34-stud hero distance is clear (shots and the halo shrink to fit)
	right: Vector3, -- the view's right
	ignore: RaycastParams, -- the camera's collision clamp
	stage: Vector3,
	reveal: (Vector3) -> (),
	colorOf: (string) -> Color3,
	revealed: boolean,
	beats: { Beat },
	nextBeat: number,
	revealBeat: Beat,
	folder: Folder,
	shot: (number) -> (CFrame, number),
	focus: Vector3,
	grade: Grade,
	vignette: number,
	energy: number,
	flareColor: Color3,
	drone: number, -- 0..1 drone level (pitch rises with it)
	thumpAt: number,
	halo: { Brick }?,
	haloSpin: number,
}

local SpinCinematic = {}

local run: Run? = nil
local active = false
local startedAt = 0
local onExit: (() -> ())? = nil
local after: { () -> () } = {}
local hidden: { ScreenGui } = {}
local promptsWere = true
local inputConn: RBXScriptConnection? = nil

local gui: ScreenGui? = nil
local bars: { Frame } = {}
local vignettes: { Frame } = {}
local label: TextLabel? = nil
local sub: TextLabel? = nil
local caption: TextLabel? = nil
local wash: Frame? = nil
local cc: ColorCorrectionEffect? = nil
local dof: DepthOfFieldEffect? = nil
local drone: Sound? = nil
local flare: { part: Part, gui: BillboardGui, core: ImageLabel, rays: { ImageLabel }, light: PointLight }? =
	nil

-- smoothed state
local camCf = CFrame.identity
local camFov = 70
local restoreFov = 70
local fovKick = 0
local shake = 0
local cur = { bars = 0, vignette = 0, energy = 0, drone = 0 }
local curGrade: Grade = { tint = WHITE, bright = 0, sat = 0, contrast = 0 }
local curFlareColor = WHITE

local function reduced(): boolean
	return Comfort.reducedMotion()
end

local function damp(k: number, dt: number): number
	return 1 - math.exp(-k * dt)
end

local function lerp(a: number, b: number, k: number): number
	return a + (b - a) * k
end

local function ease(x: number): number -- in-out
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function outBack(x: number): number
	local u = math.clamp(x, 0, 1) - 1
	return 1 + 2.7 * u ^ 3 + 1.7 * u ^ 2
end

local function sfx(name: string, volume: number?, pitch: number?)
	AudioController.play(name, nil, volume, pitch)
end

---------------------------------------------------------------- screen layer

local function text(name: string, pos: UDim2, size: UDim2, z: number, parent: Instance): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = pos
	l.Size = size
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = WHITE
	l.TextTransparency = 1
	l.Text = ""
	l.ZIndex = z
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.fromRGB(20, 18, 30)
	stroke.Transparency = 1
	stroke.Parent = l
	local scale = Instance.new("UIScale")
	scale.Parent = l
	l.Parent = parent
	return l
end

local function ensureGui(): ScreenGui
	local old = gui
	if old and old.Parent then
		return old
	end
	local g = Instance.new("ScreenGui")
	g.Name = "SpinCinematic"
	g.IgnoreGuiInset = true
	g.ResetOnSpawn = false
	g.DisplayOrder = 55
	g.Enabled = false
	-- vignette: four edge gradients darken toward the frame
	type Edge = { anchor: Vector2, pos: UDim2, size: UDim2, rot: number }
	local edges: { Edge } = {
		{
			anchor = Vector2.new(0, 0),
			pos = UDim2.fromScale(0, 0),
			size = UDim2.fromScale(1, 0.4),
			rot = 90,
		},
		{
			anchor = Vector2.new(0, 1),
			pos = UDim2.fromScale(0, 1),
			size = UDim2.fromScale(1, 0.4),
			rot = 270,
		},
		{
			anchor = Vector2.new(0, 0),
			pos = UDim2.fromScale(0, 0),
			size = UDim2.fromScale(0.32, 1),
			rot = 0,
		},
		{
			anchor = Vector2.new(1, 0),
			pos = UDim2.fromScale(1, 0),
			size = UDim2.fromScale(0.32, 1),
			rot = 180,
		},
	}
	for i, spec in edges do
		local f = Instance.new("Frame")
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BackgroundTransparency = 1
		f.BorderSizePixel = 0
		f.AnchorPoint = spec.anchor
		f.Position = spec.pos
		f.Size = spec.size
		local grad = Instance.new("UIGradient")
		grad.Rotation = spec.rot
		grad.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		grad.Parent = f
		f.Parent = g
		vignettes[i] = f
	end
	for i = 1, 2 do
		local bar = Instance.new("Frame")
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.BorderSizePixel = 0
		bar.AnchorPoint = Vector2.new(0, if i == 1 then 0 else 1)
		bar.Position = UDim2.fromScale(0, if i == 1 then 0 else 1)
		bar.Size = UDim2.fromScale(1, 0)
		bar.ZIndex = 2
		bar.Parent = g
		bars[i] = bar
	end
	label = text("Rarity", UDim2.fromScale(0.5, 0.22), UDim2.fromScale(0.8, 0.11), 3, g)
	sub = text("Prize", UDim2.fromScale(0.5, 0.31), UDim2.fromScale(0.7, 0.06), 3, g)
	caption = text("Caption", UDim2.fromScale(0.5, 0.72), UDim2.fromScale(0.8, 0.09), 3, g)
	local w = Instance.new("Frame")
	w.Name = "Wash"
	w.BackgroundColor3 = WHITE
	w.BackgroundTransparency = 1
	w.BorderSizePixel = 0
	w.Size = UDim2.fromScale(1, 1)
	w.ZIndex = 5
	w.Parent = g
	wash = w
	g.Parent = player:WaitForChild("PlayerGui")
	gui = g
	return g
end

-- text and its outline together (a UIStroke ignores TextTransparency)
local function fadeText(l: TextLabel?, to: number, time: number)
	if not l then
		return
	end
	local stroke = l:FindFirstChildOfClass("UIStroke")
	if time <= 0 then
		l.TextTransparency = to
		if stroke then
			stroke.Transparency = to
		end
		return
	end
	TweenService:Create(l, TweenInfo.new(time), { TextTransparency = to }):Play()
	if stroke then
		TweenService:Create(stroke, TweenInfo.new(time), { Transparency = to }):Play()
	end
end

local function pop(l: TextLabel?, txt: string, color: Color3, from: number)
	if not l then
		return
	end
	l.Text = txt
	l.TextColor3 = color
	fadeText(l, 0, 0)
	local scale = l:FindFirstChildOfClass("UIScale")
	if scale then
		scale.Scale = if reduced() then 1 else from
		TweenService:Create(
			scale,
			TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
	end
end

-- a screen wash in, a short hold, out (never strobes: one per beat, >= 0.35 s apart); reduce motion caps it soft
local function whiteout(color: Color3, peak: number, inTime: number, hold: number, outTime: number)
	local w = wash
	if not w then
		return
	end
	if reduced() then
		peak, inTime, outTime = math.min(peak, 0.35), math.max(inTime, 0.3), math.max(outTime, 0.6)
	end
	w.BackgroundColor3 = color
	local into = TweenService:Create(
		w,
		TweenInfo.new(inTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ BackgroundTransparency = 1 - peak }
	)
	into:Play()
	task.delay(inTime + hold, function()
		if wash == w then
			TweenService:Create(
				w,
				TweenInfo.new(outTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ BackgroundTransparency = 1 }
			):Play()
		end
	end)
end

local function kick(fov: number, amount: number)
	if reduced() then
		return
	end
	fovKick += fov
	shake = math.max(shake, amount)
end

---------------------------------------------------------------- world pieces

local function part(
	r: Run,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.CastShadow = false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = r.folder
	return p
end

-- the stud-star flare at the hub: a BillboardGui (core + four crossed rays) driven by `energy` every frame
local function buildFlare(r: Run)
	local p = part(r, Vector3.one * 0.2, CFrame.new(r.hub + r.n * 1.8), WHITE)
	p.Transparency = 1
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(1, 1)
	bb.LightInfluence = 0
	bb.Brightness = 1.6
	bb.Parent = p
	local function image(tex: string, size: UDim2, rot: number): ImageLabel
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = VFXTextures[tex].id
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, 0.5)
		img.Size = size
		img.Rotation = rot
		img.ImageTransparency = 1
		img.Parent = bb
		return img
	end
	local rays = {}
	for i = 0, 3 do
		table.insert(rays, image("spincine_rays", UDim2.fromScale(0.16, 1.7), i * 45))
	end
	local core = image("spincine_flare", UDim2.fromScale(1, 1), 0)
	local light = Instance.new("PointLight")
	light.Range = 24
	light.Brightness = 0
	light.Shadows = false
	light.Parent = p
	flare = { part = p, gui = bb, core = core, rays = rays, light = light }
end

local function ground(at: Vector3): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip: { Instance } = {}
	local vfx = Workspace:FindFirstChild("VFX")
	if vfx then
		table.insert(skip, vfx)
	end
	if player.Character then
		table.insert(skip, player.Character)
	end
	if run then
		table.insert(skip, run.folder)
	end
	params.FilterDescendantsInstances = skip
	local hit = Workspace:Raycast(at, Vector3.new(0, -60, 0), params)
	return if hit then hit.Position.Y else at.Y - 12
end

-- Legendary: a gold Lego plinth (round brick column, cap plate, studs) rises under the stage
local function plinth(r: Run)
	local floor = ground(r.stage)
	local top = r.stage.Y - 2.6
	local h = math.max(top - floor, 2)
	local base = Vector3.new(r.stage.X, floor, r.stage.Z)
	local pieces: { { part: Part, cf: CFrame } } = {}
	local function piece(size: Vector3, at: Vector3, shape: Enum.PartType?, color: Color3?)
		local cf = CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2)
		local p = part(r, size, cf - Vector3.new(0, h + 1, 0), color or GOLD, nil, shape)
		table.insert(pieces, { part = p, cf = cf })
	end
	piece(Vector3.new(h, 4.4, 4.4), base + UP * (h / 2), Enum.PartType.Cylinder)
	piece(
		Vector3.new(0.8, 5.8, 5.8),
		base + UP * (h + 0.38),
		Enum.PartType.Cylinder,
		Color3.fromRGB(255, 214, 100)
	)
	for _, o in
		{
			Vector3.new(1.3, 0, 1.3),
			Vector3.new(-1.3, 0, 1.3),
			Vector3.new(1.3, 0, -1.3),
			Vector3.new(-1.3, 0, -1.3),
		}
	do
		piece(Vector3.new(0.5, 1.2, 1.2), base + UP * (h + 1) + o, Enum.PartType.Cylinder)
	end
	for _, pc in pieces do
		TweenService:Create(
			pc.part,
			TweenInfo.new(1.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ CFrame = pc.cf }
		):Play()
	end
	VFXKit.play("spincine_shafts", CFrame.new(base + UP * 0.3), { radius = 4, still = true })
	sfx("Rigging_Creak", 1, 0.7)
end

-- Mythic: a jagged neon bolt from the sky onto the wheel; one strike, then it fades (no flicker)
local function bolt(r: Run)
	local from = r.hub + UP * 140 + r.right * 18 + r.n * 6
	local to = r.hub + r.n * 1.5
	local last = from
	local segs = 9
	for i = 1, segs do
		local k = i / segs
		local jitter = if i == segs
			then Vector3.zero
			else (r.right * (math.random() - 0.5) + r.n * (math.random() - 0.5) * 0.6)
				* 14
				* (1 - k * 0.7)
		local nextAt = from:Lerp(to, k) + jitter
		local len = (nextAt - last).Magnitude
		local mid = (last + nextAt) / 2
		local cf = CFrame.lookAt(mid, nextAt)
		local glow = part(
			r,
			Vector3.new(1.4, 1.4, len),
			cf,
			Color3.fromRGB(150, 185, 255),
			Enum.Material.Neon
		)
		local coreP = part(r, Vector3.new(0.5, 0.5, len + 0.3), cf, WHITE, Enum.Material.Neon)
		for _, p in { glow, coreP } do
			TweenService:Create(
				p,
				TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.15),
				{
					Transparency = 1,
				}
			):Play()
		end
		last = nextAt
	end
	VFXKit.play("spincine_bolt", CFrame.new(to), { radius = 6, still = true })
	if not reduced() then
		whiteout(Color3.fromRGB(225, 235, 255), 0.6, 0.04, 0.05, 0.4)
	end
	kick(6, 1.6)
end

-- Mythic: the gold Lego halo's bricks, built round the stage one by one (update() flies them in)
local function halo(r: Run, t0: number)
	local bricks: { Brick } = {}
	for i = 1, HALO_BRICKS do
		local angle = (i - 1) / HALO_BRICKS * math.pi * 2
		local m = Instance.new("Model")
		local b = part(
			r,
			Vector3.new(2.3, 1.2, 1.6),
			CFrame.identity,
			if i % 2 == 0 then GOLD else Color3.fromRGB(255, 220, 110)
		)
		b.Parent = m
		for _, x in { -0.55, 0.55 } do
			local stud = part(
				r,
				Vector3.new(0.3, 0.75, 0.75),
				CFrame.new(x, 0.72, 0) * CFrame.Angles(0, 0, math.pi / 2),
				b.Color,
				nil,
				Enum.PartType.Cylinder
			)
			stud.Parent = m
		end
		m.PrimaryPart = b -- built at the origin: PivotTo keeps the studs' offsets
		m.Parent = r.folder
		local outward = math.random() * math.pi * 2
		table.insert(bricks, {
			model = m,
			start = t0 + (i - 1) * 0.085,
			from = r.stage
				+ (r.right * math.cos(outward) + UP * math.sin(outward)) * 34
				+ r.view * 8,
			angle = angle,
		})
		m:PivotTo(CFrame.new(0, -500, 0))
	end
	r.halo = bricks
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 26
	light.Brightness = 2.5
	light.Shadows = false
	local holder = part(r, Vector3.one * 0.2, CFrame.new(r.stage + r.view * 2), GOLD)
	holder.Transparency = 1
	light.Parent = holder
end

local function stepHalo(r: Run, t: number, dt: number)
	local bricks = r.halo
	if not bricks then
		return
	end
	r.haloSpin += dt * 0.35
	for i, b in bricks do
		local p = (t - b.start) / 0.45
		if p < 0 then
			continue
		end
		local a = b.angle + r.haloSpin
		local radial = r.right * math.cos(a) + UP * math.sin(a)
		local tangent = r.right * -math.sin(a) + UP * math.cos(a)
		local slot = r.stage + radial * HALO_RADIUS * math.max(r.room, 0.6)
		local at = b.from:Lerp(slot, outBack(p))
		b.model:PivotTo(CFrame.fromMatrix(at, tangent, radial))
		if p >= 1 and not b.model:GetAttribute("Locked") then
			b.model:SetAttribute("Locked", true)
			if i % 3 == 0 then
				sfx("FX_Snap", 0.7, 0.9 + i * 0.02)
			end
		end
	end
end

---------------------------------------------------------------- shots

-- a ray that sees what the camera sees: invisible parts (triggers, colliders) are skipped and remembered
local function cast(from: Vector3, dir: Vector3, params: RaycastParams): RaycastResult?
	for _ = 1, 6 do
		local hit = Workspace:Raycast(from, dir, params)
		if not hit or not hit.Instance:IsA("BasePart") or hit.Instance.Transparency < 0.95 then
			return hit
		end
		params:AddToFilter(hit.Instance)
	end
	return nil
end

local function hero(r: Run, dist: number, h: number, side: number): CFrame
	local k = r.room -- a crowded plaza: closer and a little higher
	return CFrame.lookAt(
		r.hub + r.view * dist * k + UP * (h + (1 - k) * 6) + r.right * side * k,
		r.hub + UP * 0.5
	)
end

local function orbit(r: Run, center: Vector3, radius: number, h: number, deg: number): CFrame
	local a = math.rad(deg)
	local dir = r.view * math.cos(a) + r.right * math.sin(a)
	local k = r.room
	return CFrame.lookAt(center + dir * radius * k + UP * (h + (1 - k) * 6), center)
end

-- the spin push-in (t < 0) and the ladder's slow creep (t >= 0)
local function baseShot(r: Run): (number) -> (CFrame, number)
	return function(t: number)
		if t < 0 then
			local e = 1 - (1 - math.clamp(1 + t / r.spinTime, 0, 1)) ^ 2
			return hero(r, 34 - 10 * e, -3 + e, 6 - 3 * e), 50 - 6 * e
		end
		local k = math.clamp(t / math.max(r.plan.payoff, 0.5), 0, 1)
		return hero(r, 24 - 5 * k, -2 + 0.5 * k, 3 - 1.5 * k), 44 - 4 * k
	end
end

---------------------------------------------------------------- beats

local function add(r: Run, at: number, fn: () -> ())
	table.insert(r.beats, { at = at, seq = #r.beats, fn = fn })
end

local function ladder(r: Run)
	local plan = r.plan
	for i, step in plan.steps do
		local rank = SpinRules.rank(step.rarity)
		local final = i == #plan.steps
		add(r, step.at, function()
			local c = r.colorOf(step.rarity)
			r.flareColor = c
			r.energy = if final and plan.fake then 1.3 else 0.25 + 0.75 * rank / 6
			r.drone = math.max(r.drone, 0.4 + 0.1 * rank)
			pop(label, string.upper(step.rarity), c, 1.5 + 0.08 * rank)
			if final and plan.fake then
				sfx("FX_PowerUp", 1, 1)
				r.drone = 1
			end
			sfx("FX_ChimeHit", 0.75, 0.75 * 2 ^ ((rank - 1) * 2 / 12))
			VFXKit.play(
				"spincine_flare",
				CFrame.fromMatrix(r.hub + r.n * 2, r.right, r.view),
				{ color = c, scale = 0.45 + 0.11 * rank, still = true }
			)
			kick(1.5 + 0.6 * rank, 0.1 + 0.06 * rank)
			if not reduced() then
				whiteout(c, 0.16, 0.05, 0, 0.3)
			end
			r.grade = {
				tint = WHITE:Lerp(c, 0.1 + 0.03 * rank),
				bright = -0.12 - 0.02 * rank,
				sat = -0.35,
				contrast = 0.05 + 0.02 * rank,
			}
			r.vignette = 0.45 + 0.07 * rank
		end)
	end
	local fake = plan.fake
	if fake then
		add(r, fake, function() -- the flare nearly dies; the world darkens; the drone sags
			r.energy = 0.06
			r.drone = 0.25
			fadeText(label, 0.55, 0.4)
			sfx("FX_Whoosh", 0.6, 0.55)
			r.grade = { tint = r.grade.tint, bright = -0.3, sat = -0.6, contrast = 0.1 }
			r.vignette = 0.9
		end)
	end
end

local function payoff(r: Run)
	local P = r.plan.payoff
	local rank = r.plan.rank
	local color = r.colorOf(r.plan.rarity)
	local up = CFrame.new(r.hub)
	if rank < 6 then
		add(
			r,
			P + 0.45,
			function() -- the last pop's surge reads, then the flare hands over to the payoff
				r.energy = 0
			end
		)
	end
	if rank == 3 then -- Rare: a beam off the wheel, the camera tilts up after it
		add(r, P, function()
			VFXKit.play("spincine_beam", up, { color = color, still = true })
			r.shot = function(_t)
				return CFrame.lookAt(r.hub + r.view * 26 + UP * -3 + r.right * 4, r.hub + UP * 9),
					52
			end
			r.focus = r.hub
		end)
	elseif rank == 4 then -- Epic: a purple sky, rays and stars, an orbit
		add(r, P, function()
			r.drone = 0.6
			r.grade =
				{ tint = Color3.fromRGB(205, 170, 255), bright = -0.15, sat = 0.15, contrast = 0.1 }
			r.vignette = 0.55
			VFXKit.play("spincine_rays", CFrame.new(r.stage), { color = color, still = true })
			for _, h in { -6, 14 } do
				VFXKit.play(
					"spincine_stars",
					CFrame.new(r.stage + UP * h),
					{ radius = 50, still = true }
				)
			end
			r.focus = r.stage
			r.shot = function(t)
				local k = ease((t - P) / 2.4)
				return orbit(r, r.stage, lerp(22, 18, k), 2, lerp(0, 70, k)), 48
			end
		end)
		add(r, P + 2, function()
			whiteout(Color3.fromRGB(240, 225, 255), 0.55, 0.3, 0.05, 0.6)
			sfx("FX_TonalHit", 0.9, 1)
		end)
	elseif rank == 5 then -- Legendary: the golden sea
		add(r, P, function()
			r.drone = 0.5
			r.grade =
				{ tint = Color3.fromRGB(255, 214, 130), bright = 0.02, sat = 0.3, contrast = 0.08 }
			r.vignette = 0.35
			r.focus = r.stage
			r.shot = function(t)
				local k = ease((t - P) / 5)
				return orbit(r, r.stage, lerp(26, 20, k), lerp(-3, 2, k), lerp(-25, 85, k)), 50
			end
		end)
		add(r, P + 0.4, function()
			plinth(r)
		end)
		add(r, P + 2, function()
			VFXKit.play(
				"spincine_coins",
				CFrame.new(r.stage + UP * 24),
				{ radius = 12, still = true }
			)
		end)
		add(r, P + 2.6, function()
			VFXKit.play("spincine_rays", CFrame.new(r.stage), { color = GOLD, still = true })
		end)
		add(r, P + 3, function()
			pop(caption, "GOLDEN TIDE", GOLD, 1.3)
			sfx("FX_ChimeTail", 0.9, 1)
		end)
		add(r, P + 4.6, function()
			fadeText(caption, 1, 0.3)
			whiteout(Color3.fromRGB(255, 240, 200), 0.85, 0.35, 0.05, 0.7)
			sfx("FX_Boom", 0.9, 1)
		end)
	elseif rank >= 6 then -- Mythic: the full show
		add(r, P, function()
			r.drone = 0
			r.grade = {
				tint = Color3.fromRGB(160, 170, 255),
				bright = -0.35,
				sat = -0.75,
				contrast = 0.15,
			}
			r.vignette = 0.8
			r.focus = r.hub
			r.shot = function(_t)
				return hero(r, 42, 6, -10), 55
			end
			sfx("Thunder_Near", 0.5, 0.6)
		end)
		add(r, P + 0.6, function()
			r.energy = 0
			bolt(r)
		end)
		add(r, P + 1.2, function()
			r.grade = {
				tint = Color3.fromRGB(120, 130, 230),
				bright = -0.25,
				sat = -0.4,
				contrast = 0.15,
			}
			for _, h in { -12, 4, 20, 36 } do
				VFXKit.play(
					"spincine_stars",
					CFrame.new(r.stage + UP * h),
					{ radius = 55, still = true }
				)
			end
			r.focus = r.stage
			r.shot = function(t)
				local k = ease((t - P - 1.2) / 3.2)
				return orbit(r, r.stage, lerp(30, 24, k), 3, lerp(0, 35, k)), 52
			end
		end)
		add(r, P + 1.5, function()
			halo(r, P + 1.5)
		end)
		add(r, P + 4, function()
			VFXKit.play(
				"spincine_halo",
				CFrame.fromMatrix(r.stage, r.right, r.view),
				{ still = true }
			)
			r.grade =
				{ tint = Color3.fromRGB(255, 225, 170), bright = -0.15, sat = 0.1, contrast = 0.12 }
			kick(3, 0.5)
		end)
		for i = 0, 2 do
			add(r, P + 4.4 + i * 0.4, function()
				VFXKit.play(
					"spincine_tunnel",
					CFrame.fromMatrix(r.stage, r.right, r.view),
					{ radius = 6, still = true }
				)
			end)
		end
		add(r, P + 4.4, function()
			sfx("FX_PowerUp", 1, 0.9)
			r.shot = function(t)
				local k = ease((t - P - 4.4) / 3)
				return orbit(r, r.stage, lerp(24, 11, k), lerp(3, 1, k), lerp(35, 20, k)),
					lerp(62, 40, k)
			end
		end)
		add(r, P + 5.6, function()
			pop(caption, "OCEAN BLESSED", GOLD, 1.3)
			sfx("FX_ChimeTail", 1, 0.9)
		end)
		add(r, P + 7.4, function()
			fadeText(caption, 1, 0.3)
			whiteout(WARM_WHITE, 1, 0.5, 0.2, 0.9)
			sfx("FX_Boom", 1, 0.85)
			sfx("FX_TonalHit", 1, 1)
		end)
	end
end

local function revealBeat(r: Run): Beat
	return {
		at = r.plan.reveal,
		seq = math.huge, -- after anything else at the same time
		fn = function()
			r.revealed = true
			r.energy = 0
			r.drone = 0
			local c = r.colorOf(r.plan.rarity)
			pop(label, string.upper(r.plan.rarity), c, 1.25)
			pop(sub, tostring(r.payload.name or "Prize"), WHITE, 1.4)
			r.grade = { tint = WHITE, bright = 0, sat = 0.15, contrast = 0.05 }
			r.vignette = 0.2
			r.focus = r.stage
			local t0 = r.plan.reveal
			r.shot = function(t)
				return orbit(r, r.stage, 15, 1.5, 8 * (t - t0) - 6), 46
			end
			ProximityPromptService.Enabled = promptsWere -- the wheel's prompts are back for the next token
			r.reveal(r.stage)
		end,
	}
end

---------------------------------------------------------------- takeover

local function showSelf(on: boolean)
	local char = player.Character
	if not char then
		return
	end
	for _, x in char:GetDescendants() do
		if x:IsA("BasePart") or x:IsA("Decal") then
			(x :: any).LocalTransparencyModifier = if on then 0 else 1
		end
	end
end

local function exit()
	if not active then
		return
	end
	active = false
	RunService:UnbindFromRenderStep("SpinCinematic")
	if inputConn then
		inputConn:Disconnect()
		inputConn = nil
	end
	CameraController.ClearOverride()
	showSelf(true)
	local cam = Workspace.CurrentCamera
	if cam then
		cam.FieldOfView = restoreFov
	end
	for _, g in hidden do
		if g.Parent then
			g.Enabled = true
		end
	end
	hidden = {}
	ProximityPromptService.Enabled = promptsWere
	if cc then
		cc:Destroy()
	end
	if dof then
		dof:Destroy()
	end
	if drone then
		drone:Destroy()
	end
	cc, dof, drone, flare = nil, nil, nil, nil
	local r = run
	run = nil
	if r then
		r.folder:Destroy()
	end
	if gui then
		gui.Enabled = false
		for _, l in { label, sub, caption } do
			fadeText(l, 1, 0)
		end
		if wash then
			wash.BackgroundTransparency = 1
		end
	end
	player:SetAttribute("SpinCinematic", nil)
	local fn = onExit
	onExit = nil
	if fn then
		task.spawn(fn)
	end
	local queued = after
	after = {}
	for _, f in queued do
		task.spawn(f)
	end
end

-- jump to the reveal (or, already revealed, end the hold: a beat later, so a tap on the wheel's spin button carries
-- straight into the next spin's quick takeover instead of cutting out and swooping back in)
local function skip()
	local r = run
	if not r then
		return
	end
	if r.revealed then
		task.delay(0.35, function()
			if run == r then
				exit()
			end
		end)
		return
	end
	for _, d in r.folder:GetChildren() do
		if not (flare and d == flare.part) then
			d:Destroy()
		end
	end
	r.halo = nil
	fadeText(caption, 1, 0.2)
	r.land = os.clock() - r.plan.reveal
	r.nextBeat = table.find(r.beats, r.revealBeat) or #r.beats
	if not reduced() then
		whiteout(WARM_WHITE, 0.5, 0.08, 0, 0.5)
	end
end

local function update(dt: number)
	local r = run
	if not r then
		exit()
		return
	end
	local now = os.clock()
	local t = now - r.land
	while r.beats[r.nextBeat] and r.beats[r.nextBeat].at <= t do
		local b = r.beats[r.nextBeat]
		r.nextBeat += 1
		local ok, err = pcall(b.fn :: any)
		if not ok then
			warn(`[SpinCinematic] {err}`)
		end
	end
	if run ~= r then
		return
	end
	if t >= r.plan.done then
		exit()
		return
	end
	stepHalo(r, t, dt)

	-- camera: damped toward the beat's shot, plus kicks and shake
	local cf, fov = r.shot(t)
	-- never through a wall: the plaza is crowded round the wheel (Boathouse 16 studs off its face)
	local want = cf.Position - r.focus
	local hit = cast(r.focus, want, r.ignore)
	if hit then
		cf = CFrame.new(hit.Position - want.Unit * 1.5) * cf.Rotation
	end
	camCf = camCf:Lerp(cf, damp(3.2, dt))
	camFov = lerp(camFov, fov, damp(3.2, dt))
	fovKick = lerp(fovKick, 0, damp(7, dt))
	shake = lerp(shake, 0, damp(5, dt))
	local jolt = CFrame.identity
	if shake > 0.01 and not reduced() then
		local k = math.rad(shake) * (tonumber(Comfort.get("shake")) or 0.6)
		local c = now * 22
		jolt = CFrame.Angles(
			math.noise(c, 1.3) * k * 2,
			math.noise(c, 7.9) * k * 2,
			math.noise(c, 4.2) * k
		)
	end
	CameraController.SetOverride(camCf * jolt, camFov - fovKick)
	showSelf(false) -- the spinner stands between the camera and the hub

	-- grade, vignette, letterbox, depth of field
	local g = r.grade
	local kg = damp(3, dt)
	curGrade = {
		tint = curGrade.tint:Lerp(g.tint, kg),
		bright = lerp(curGrade.bright, g.bright, kg),
		sat = lerp(curGrade.sat, g.sat, kg),
		contrast = lerp(curGrade.contrast, g.contrast, kg),
	}
	if cc then
		cc.TintColor, cc.Brightness, cc.Saturation, cc.Contrast =
			curGrade.tint, curGrade.bright, curGrade.sat, curGrade.contrast
	end
	cur.bars = lerp(cur.bars, 1, damp(4, dt))
	cur.vignette = lerp(cur.vignette, r.vignette, damp(3, dt))
	for _, bar in bars do
		bar.Size = UDim2.fromScale(1, 0.11 * cur.bars)
	end
	for _, v in vignettes do
		v.BackgroundTransparency = 1 - 0.85 * cur.vignette
	end
	if dof then
		dof.FocusDistance = (camCf.Position - r.focus).Magnitude
		dof.FarIntensity = 0.45 * cur.bars
	end

	-- the flare
	cur.energy = lerp(cur.energy, r.energy, damp(6, dt))
	curFlareColor = curFlareColor:Lerp(r.flareColor, damp(8, dt))
	local f = flare
	if f then
		local e = cur.energy
		f.gui.Size = UDim2.fromScale(3 + 16 * e, 3 + 16 * e)
		local alpha = 1 - math.clamp(e * 1.2, 0, 0.95)
		f.core.ImageTransparency = alpha
		f.core.ImageColor3 = WHITE:Lerp(curFlareColor, 0.55)
		for i, ray in f.rays do
			ray.ImageTransparency = alpha
			ray.ImageColor3 = curFlareColor
			ray.Rotation = (i - 1) * 45 + now * 18 * (1 + e)
		end
		f.light.Brightness = 3 * math.min(e, 1.2)
		f.light.Color = curFlareColor
	end

	-- the drone rises with the climb; the heartbeat quickens until the payoff
	cur.drone = lerp(cur.drone, r.drone, damp(2, dt))
	local d = drone
	if d then
		d.Volume = 0.5 * cur.drone
		d.PlaybackSpeed = 0.55 + 0.6 * cur.drone
	end
	if t < r.plan.payoff and now >= r.thumpAt then
		local climb = math.clamp((t + r.spinTime) / (r.spinTime + r.plan.payoff), 0, 1)
		r.thumpAt = now + lerp(0.9, 0.45, climb)
		sfx("FX_Thud", 0.5 + 0.4 * climb, 0.5)
	end
end

local function onInput(input: InputObject)
	local kind = input.UserInputType
	local ok = kind == Enum.UserInputType.MouseButton1
		or kind == Enum.UserInputType.Touch
		or kind == Enum.UserInputType.Keyboard
		or (
			string.sub(kind.Name, 1, 7) == "Gamepad"
			and input.KeyCode ~= Enum.KeyCode.Thumbstick1
			and input.KeyCode ~= Enum.KeyCode.Thumbstick2
		)
	if ok and os.clock() - startedAt >= SpinCinePlan.SKIP_AFTER then
		skip()
	end
end

local function enter()
	if active then
		return
	end
	active = true
	local cam = Workspace.CurrentCamera
	camCf, camFov, restoreFov = cam.CFrame, cam.FieldOfView, cam.FieldOfView
	fovKick, shake = 0, 0
	cur = { bars = 0, vignette = 0, energy = 0, drone = 0 }
	curGrade = { tint = WHITE, bright = 0, sat = 0, contrast = 0 }
	local g = ensureGui()
	g.Enabled = true
	for _, sg in player:WaitForChild("PlayerGui"):GetChildren() do
		if sg:IsA("ScreenGui") and sg.Enabled and sg ~= g then
			sg.Enabled = false
			table.insert(hidden, sg)
		end
	end
	promptsWere = ProximityPromptService.Enabled
	ProximityPromptService.Enabled = false
	local c = Instance.new("ColorCorrectionEffect")
	c.Name = "SpinCinematicGrade"
	c.Parent = cam
	cc = c
	local field = Instance.new("DepthOfFieldEffect")
	field.Name = "SpinCinematicFocus"
	field.InFocusRadius = 14
	field.NearIntensity = 0
	field.FarIntensity = 0
	field.Parent = cam
	dof = field
	local s = AudioController.newSound("Under_Ambience", nil, true)
	s:Play()
	drone = s
	player:SetAttribute("SpinCinematic", true)
	sfx("FX_Swoosh", 0.8, 0.9)
	RunService:BindToRenderStep("SpinCinematic", Enum.RenderPriority.Camera.Value, update)
	inputConn = UserInputService.InputBegan:Connect(onInput)
end

function SpinCinematic.start(ctx: {
	payload: any,
	hub: CFrame,
	wheel: Instance,
	landIn: number,
	reveal: (Vector3) -> (),
	colorOf: (string) -> Color3,
	onExit: (() -> ())?,
}): boolean
	local quick = active
	local old = run
	if old and not old.revealed then
		old.revealBeat.fn() -- a new spin while the last one still teases: show its prize now
	end
	if old then
		old.folder:Destroy()
		run = nil
		flare = nil
	end
	local hub = ctx.hub.Position
	-- the wheel faces the player: its face normal is the rotor's look axis, flipped to the side we stand on
	local look = ctx.hub.LookVector
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local viewer = if root and root:IsA("BasePart")
		then root.Position
		else Workspace.CurrentCamera.CFrame.Position
	local n = Vector3.new(look.X, 0, look.Z)
	n = if n.Magnitude > 0.01 then n.Unit else Vector3.new(0, 0, -1)
	if (viewer - hub):Dot(n) < 0 then
		n = -n
	end
	local folder = Instance.new("Folder")
	folder.Name = "SpinCinematic"
	folder.Parent = Workspace
	local ignore = RaycastParams.new()
	ignore.FilterType = Enum.RaycastFilterType.Exclude

	local excluded: { Instance } = { ctx.wheel, folder }
	if char then
		table.insert(excluded, char)
	end
	ignore.FilterDescendantsInstances = excluded
	-- the stage sits in front of the face, short of anything solid; the shots swing to the clearest side
	local front = cast(hub + n * 2, n * STAGE, ignore)
	local stage = if front then math.max(4, front.Distance - 1) else STAGE
	local view, best = n, -1
	for _, deg in { 0, 25, -25, 45, -45, 65, -65 } do
		local dir = CFrame.Angles(0, math.rad(deg), 0):VectorToWorldSpace(n)
		local h = cast(hub + UP * 2, dir * 34, ignore)
		local d = if h then h.Distance else 34
		if d > best + 4 then -- a wider angle has to buy real room
			view, best = dir, d
		end
	end
	local plan = SpinCinePlan.plan(tostring(ctx.payload.rarity), quick)
	local landIn = math.max(ctx.landIn, 0)
	local r: Run = {
		payload = ctx.payload,
		plan = plan,
		land = os.clock() + landIn,
		spinTime = math.max(landIn, 1),
		hub = hub,
		n = n,
		view = view,
		right = view:Cross(UP).Unit,
		ignore = ignore,
		room = math.clamp((best - 3) / 31, 0.4, 1),
		stage = hub + n * stage,
		reveal = ctx.reveal,
		colorOf = ctx.colorOf,
		revealed = false,
		beats = {},
		nextBeat = 1,
		revealBeat = (nil :: any) :: Beat,
		folder = folder,
		shot = (nil :: any) :: (number) -> (CFrame, number),
		focus = hub,
		grade = { tint = WHITE, bright = -0.08, sat = -0.35, contrast = 0.04 },
		vignette = 0.25,
		energy = 0,
		flareColor = WHITE,
		drone = 0.2,
		thumpAt = os.clock() + 0.6,
		halo = nil,
		haloSpin = 0,
	}
	r.shot = baseShot(r)
	r.revealBeat = revealBeat(r)
	-- the flare starts to gather in the wheel's last second
	add(r, -math.min(1.2, landIn), function()
		r.energy = 0.18
		r.drone = 0.4
	end)
	ladder(r)
	payoff(r)
	table.insert(r.beats, r.revealBeat)
	table.sort(
		r.beats,
		function(a, b) -- stable: same-time beats keep their order (the last pop before the payoff)
			return a.at < b.at or (a.at == b.at and a.seq < b.seq)
		end
	)
	if quick then
		ProximityPromptService.Enabled = false -- the last reveal handed them back
	end
	for _, l in { label, sub, caption } do
		fadeText(l, 1, 0)
	end
	if not quick then
		startedAt = os.clock()
	end
	onExit = ctx.onExit or onExit
	enter()
	run = r
	buildFlare(r)
	return true
end

function SpinCinematic.active(): boolean
	return active
end

function SpinCinematic.whenDone(fn: () -> ())
	if active then
		table.insert(after, fn)
	else
		task.spawn(fn)
	end
end

return SpinCinematic
