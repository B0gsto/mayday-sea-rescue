--!strict
-- StreetController (I1b-3): client-side life for the lighthouses:
--   * each lighthouse's Fl(2) W 10s beam (Shared.HarbourLightBeam, tags HarbourLight / Lighthouse):
--     at night or in a storm a rotating rig at ATT_Light carries two bullseye pairs (panels 0/30 and
--     180/210 degrees) as Beam cones plus one SpotLight per pair, turning at 18 deg/s on the server
--     clock, a warm PointLight in the lantern, and the _Lens Neon brightening as a panel sweeps the
--     camera.
-- Lighthouses may stream (Atomic models): found by tag, rigs live inside them and go when they stream out.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LightBeam = require(Shared:WaitForChild("HarbourLightBeam"))

local StreetController = {}

local LIGHT_TAGS = { "HarbourLight", "Lighthouse" }
local LENS_TAGS = { "HarbourLightLens", "LighthouseLens" }
local BEAM_LENGTH = 320 -- studs: the visible cone (the real light reaches 9 nmi)
local WARM = Color3.fromRGB(255, 236, 205) -- ~4000 K
local LENS_REST = Color3.fromRGB(150, 132, 100)
local LENS_DAY = Color3.fromRGB(214, 220, 212)

type Rig = {
	model: Model,
	part: BasePart,
	centre: Vector3,
	beams: { Beam },
	point: PointLight,
	lenses: { BasePart },
	lit: boolean,
}

local rigs: { [Model]: Rig } = {}

local function beamFor(parent: BasePart, bearing: number): Beam
	local dir = CFrame.Angles(0, math.rad(bearing), 0) * Vector3.xAxis
	local a0 = Instance.new("Attachment")
	a0.Name = `Panel{bearing}`
	a0.CFrame = CFrame.lookAt(Vector3.zero, dir)
	a0.Parent = parent
	local a1 = Instance.new("Attachment")
	a1.Position = dir * BEAM_LENGTH
	a1.Parent = parent
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Width0 = 2.4 -- the 0.79 m drum lens
	b.Width1 = 2 * BEAM_LENGTH * math.tan(math.rad(LightBeam.HALF_WIDTH))
	b.FaceCamera = true
	b.LightEmission = 1
	b.LightInfluence = 0
	b.Brightness = 2
	b.Color = ColorSequence.new(WARM)
	b.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.35, 0.82),
		NumberSequenceKeypoint.new(1, 1),
	})
	b.Segments = 1
	b.Enabled = false
	b.Parent = parent
	return b
end

local function build(model: Model): Rig?
	local att = model:FindFirstChild("ATT_Light", true)
	if not (att and att:IsA("Attachment")) then
		return nil
	end
	local part: BasePart = Instance.new("Part")
	part.Name = "BeamRig"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = CFrame.new(att.WorldPosition)
	part.Parent = model
	local beams: { Beam } = {}
	for _, p in LightBeam.PANELS do
		table.insert(beams, beamFor(part, p))
		if p == 0 or p == 180 then -- one SpotLight per pair, between its two panels
			local mid = CFrame.Angles(0, math.rad(p + 15), 0) * Vector3.xAxis
			local sa = Instance.new("Attachment")
			sa.CFrame = CFrame.lookAt(Vector3.zero, mid)
			sa.Parent = part
			local s = Instance.new("SpotLight")
			s.Face = Enum.NormalId.Front
			s.Angle = 40
			s.Range = 60
			s.Brightness = 3
			s.Color = WARM
			s.Shadows = false
			s.Enabled = false
			s.Parent = sa
		end
	end
	local point = Instance.new("PointLight")
	point.Range = 14
	point.Brightness = 1.2
	point.Color = WARM
	point.Shadows = false
	point.Enabled = false
	point.Parent = part
	local lenses: { BasePart } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			for _, tag in LENS_TAGS do
				if d:HasTag(tag) then
					table.insert(lenses, d)
					break
				end
			end
		end
	end
	return {
		model = model,
		part = part,
		centre = att.WorldPosition,
		beams = beams,
		point = point,
		lenses = lenses,
		lit = true,
	}
end

local function night(): boolean
	-- the storm this player sees (WeatherController): a cold open keeps a global storm off screen
	local storm = (tonumber(Lighting:GetAttribute("LocalStormIntensity")) or 0) >= 0.5
	return LightBeam.lit(
		if storm then "Storm" else "Calm",
		Lighting:GetAttribute("WeatherBase"),
		Lighting:GetSunDirection().Y
	)
end

local function setLit(r: Rig, on: boolean)
	r.lit = on
	for _, b in r.beams do
		b.Enabled = on
	end
	for _, d in r.part:GetDescendants() do
		if d:IsA("SpotLight") then
			d.Enabled = on
		end
	end
	r.point.Enabled = on
	for _, l in r.lenses do
		l.Material = if on then Enum.Material.Neon else Enum.Material.Glass
		l.Color = if on then LENS_REST else LENS_DAY
		l.Transparency = if on then 0 else 0.1
	end
end

local function watch(tag: string, add: (Model) -> (), remove: (Model) -> ())
	local function onAdd(inst: Instance)
		if inst:IsA("Model") then
			add(inst)
		end
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(onAdd)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(inst)
		if inst:IsA("Model") then
			remove(inst)
		end
	end)
	for _, inst in CollectionService:GetTagged(tag) do
		onAdd(inst)
	end
end

function StreetController.Init() end

function StreetController.Start()
	local function addLight(m: Model)
		task.defer(function() -- the Atomic model arrives whole; wait a frame for the lens tags
			if rigs[m] == nil and m.Parent then
				local r = build(m)
				if r then
					rigs[m] = r
					setLit(r, false)
				end
			end
		end)
	end
	for _, tag in LIGHT_TAGS do
		watch(tag, addLight, function(m)
			rigs[m] = nil
		end)
	end
	RunService.RenderStepped:Connect(function()
		local now = Workspace:GetServerTimeNow()
		local cam = Workspace.CurrentCamera
		local camPos = if cam then cam.CFrame.Position else Vector3.zero
		local isNight = night()
		for m, r in rigs do
			if not m.Parent then
				rigs[m] = nil
				continue
			end
			local want = isNight
			if want ~= r.lit then
				setLit(r, want)
			end
			if want then
				r.point.Color = WARM
				r.point.Range = 14
				r.part.CFrame = CFrame.new(r.centre)
					* CFrame.Angles(0, math.rad(LightBeam.angle(now)), 0)
				local d = camPos - r.centre
				local k = LightBeam.intensity(now, LightBeam.bearing(d.X, d.Z))
				for _, l in r.lenses do
					l.Color = LENS_REST:Lerp(Color3.new(1, 1, 1), k)
				end
				r.point.Brightness = 1.2 + 2.5 * k
			end
		end
	end)
end

return StreetController
