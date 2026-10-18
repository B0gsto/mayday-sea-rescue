--!strict
-- SeamarkController (RP-I1b-2): the client side of src/server/World/Seamarks.luau. Every model tagged "Seamark"
-- (anchored by the server at ATT_WaterLine on the still sea) is moved locally each frame onto the Waves surface:
-- heave, a lean along the wave slope and a slow swing on its mooring (Shared.SeamarkRules.motion), smoothed, LOD'd
-- by distance (every frame near, a few times a second further out, frozen far away). Lit marks run the
-- characteristic of their art/reference/<asset>/dims.md (SeamarkRules.Lights) at night, at dusk and in a storm:
-- the *_Lens part turns Neon in the lens colour with a small PointLight at ATT_Light (only near the camera) and
-- a pixel-size flare billboard so the flash reads across the bay; by day the lantern is dark (photocell).
-- The marks are also small blips on the map (MapController.SetBlips("Seamarks", ...)).

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapController = require(script.Parent.MapController)
local SeamarkRules = require(Shared:WaitForChild("SeamarkRules"))
local Waves = require(Shared:WaitForChild("Waves"))
local Weather = require(Shared:WaitForChild("Weather"))

local SeamarkController = {}

local TAG = "Seamark"
local NEAR = 600 -- studs: moved every frame
local MID = 1500 -- moved at MID_HZ; beyond, left where it is
local MID_HZ = 8
local LIGHT_RANGE = 320 -- the PointLight (Range LIGHT_REACH) only this close to the camera
local LIGHT_REACH = 18
local FLARE_DISTANCE = 2200
local CHECK_EVERY = 0.5 -- s between photocell checks

type Lens =
	{ part: BasePart, material: Enum.Material, color: Color3, appearance: SurfaceAppearance? }

type Tracked = {
	model: Model,
	mark: SeamarkRules.Mark,
	motion: SeamarkRules.Motion,
	parts: { BasePart },
	offsets: { CFrame }, -- each part from the still pivot
	y: number,
	pitch: number,
	roll: number,
	nextMove: number,
	lenses: { Lens },
	light: SeamarkRules.Light?,
	phase: number,
	point: PointLight?,
	flare: BillboardGui?,
	lit: boolean, -- the lantern is working (night)
	on: boolean?, -- the flash state last applied
}

local byId: { [string]: SeamarkRules.Mark } = {}
local tracked: { [Model]: Tracked } = {}
local lanternsOn = false
local nextCheck = 0

local function flare(parent: Attachment, color: Color3): BillboardGui
	local g = Instance.new("BillboardGui")
	g.Name = "SeamarkFlare"
	g.Size = UDim2.new(0.5, 5, 0.5, 5) -- a lens-sized glow near, never under 5 px far away
	g.LightInfluence = 0
	g.MaxDistance = FLARE_DISTANCE
	g.AlwaysOnTop = false
	g.ResetOnSpawn = false
	g.Enabled = false
	local halo = Instance.new("Frame")
	halo.AnchorPoint = Vector2.new(0.5, 0.5)
	halo.Position = UDim2.fromScale(0.5, 0.5)
	halo.Size = UDim2.fromScale(2.2, 2.2)
	halo.BackgroundColor3 = color
	halo.BackgroundTransparency = 0.82
	halo.BorderSizePixel = 0
	local core = halo:Clone()
	core.Size = UDim2.fromScale(1, 1)
	core.BackgroundTransparency = 0.05
	core.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.45)
	for _, f in { halo, core } do
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = f
		f.Parent = g
	end
	g.Parent = parent
	return g
end

local function setLit(t: Tracked, lit: boolean)
	if t.lit == lit then
		return
	end
	t.lit = lit
	t.on = nil
	for _, l in t.lenses do
		if l.appearance then
			l.appearance.Parent = if lit then nil else l.part
		end
		if not lit then
			l.part.Material = l.material
			l.part.Color = l.color
		end
	end
	if not lit then
		if t.point then
			t.point.Enabled = false
		end
		if t.flare then
			t.flare.Enabled = false
		end
	end
end

local function setFlash(t: Tracked, on: boolean, near: boolean)
	local light = t.light :: SeamarkRules.Light
	if t.on ~= on then
		t.on = on
		for _, l in t.lenses do
			l.part.Material = if on then Enum.Material.Neon else Enum.Material.Glass
			l.part.Color = if on then light.color else light.color:Lerp(Color3.new(0, 0, 0), 0.75)
		end
		if t.flare then
			t.flare.Enabled = on
		end
	end
	if t.point then
		local want = on and near
		if t.point.Enabled ~= want then
			t.point.Enabled = want
		end
	end
end

local function track(model: Instance)
	if not model:IsA("Model") or tracked[model] then
		return
	end
	local id = model:GetAttribute("SeamarkId")
	local mark = type(id) == "string" and byId[id] or nil
	if not mark then
		return
	end
	local sea = model:GetAttribute("SeaY")
	local still = CFrame.new(mark.x, if type(sea) == "number" then sea else 0, mark.z)
		* CFrame.Angles(0, math.rad(mark.yaw), 0)
	local t: Tracked = {
		model = model,
		mark = mark,
		motion = SeamarkRules.motion(mark.asset),
		parts = {},
		offsets = {},
		y = 0,
		pitch = 0,
		roll = 0,
		nextMove = 0,
		lenses = {},
		light = if mark.light then SeamarkRules.Lights[mark.light] else nil,
		phase = SeamarkRules.phase(mark.id),
		lit = false,
	}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(t.parts, d)
			table.insert(t.offsets, still:ToObjectSpace(d.CFrame))
			if t.light and string.find(d.Name, "_Lens", 1, true) then
				table.insert(t.lenses, {
					part = d,
					material = d.Material,
					color = d.Color,
					appearance = d:FindFirstChildOfClass("SurfaceAppearance"),
				})
			end
		end
	end
	local light = t.light
	if light then
		local att = model:FindFirstChild("ATT_Light", true)
		if att and att:IsA("Attachment") then
			local p = Instance.new("PointLight")
			p.Name = "SeamarkLight"
			p.Color = light.color
			p.Range = LIGHT_REACH
			p.Brightness = 3
			p.Shadows = false
			p.Enabled = false
			p.Parent = att
			t.point = p
			t.flare = flare(att, light.color)
		end
	end
	tracked[model] = t
	setLit(t, lanternsOn)
end

local function untrack(model: Instance)
	tracked[model :: Model] = nil
end

local function step(dt: number)
	local now = Workspace:GetServerTimeNow()
	local clock = os.clock()
	if clock >= nextCheck then
		nextCheck = clock + CHECK_EVERY
		local on = SeamarkRules.lightsOn(
			Weather.getState(),
			Lighting:GetAttribute("WeatherBase") :: string?,
			Lighting:GetSunDirection().Y
		)
		if on ~= lanternsOn then
			lanternsOn = on
			for _, t in tracked do
				setLit(t, on)
			end
		end
	end
	local cam = Workspace.CurrentCamera
	local eye = if cam then cam.CFrame.Position else Vector3.zero
	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	for model, t in tracked do
		if not model.Parent then
			tracked[model] = nil
			continue
		end
		local mark = t.mark
		local d = Vector2.new(mark.x - eye.X, mark.z - eye.Z).Magnitude
		if t.light and t.lit then
			local light = t.light :: SeamarkRules.Light
			local period = SeamarkRules.period(light.seq)
			setFlash(t, SeamarkRules.isOn(light.seq, now + t.phase * period), d < LIGHT_RANGE)
		end
		if d > MID or (d > NEAR and clock < t.nextMove) then
			continue
		end
		local step_dt = if d > NEAR then 1 / MID_HZ else dt
		t.nextMove = clock + 1 / MID_HZ
		local pos = Vector3.new(mark.x, 0, mark.z)
		local h, n = Waves.sampleAt(mark.x, mark.z, now, Weather.getWaveParams(pos, now))
		local m = t.motion
		local pitch, roll = SeamarkRules.tiltFrom(n.X, n.Z, m.follow, m.maxTilt)
		local a = 1 - math.exp(-step_dt / m.lag)
		t.y += (h * m.heave - t.y) * a
		t.pitch += (pitch - t.pitch) * a
		t.roll += (roll - t.roll) * a
		-- a slow swing on the mooring (a few degrees), out of step from mark to mark
		local swing = math.rad(4) * math.sin(now * 0.09 + t.phase * 6.283)
		local base = model:GetAttribute("SeaY")
		local seaY = if type(base) == "number" then base else 0
		local cf = CFrame.new(mark.x, seaY + t.y, mark.z)
			* CFrame.Angles(t.pitch, 0, t.roll)
			* CFrame.Angles(0, math.rad(mark.yaw) + swing, 0)
		for i, p in t.parts do
			table.insert(parts, p)
			table.insert(frames, cf * t.offsets[i])
		end
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function SeamarkController.Init()
	for _, m in SeamarkRules.Marks do
		byId[m.id] = m
	end
end

function SeamarkController.Start()
	local items = {}
	for _, m in SeamarkRules.Marks do
		if m.map then
			table.insert(
				items,
				{ id = m.id, position = Vector3.new(m.x, 0, m.z), style = m.map, size = 10 }
			)
		end
	end
	MapController.SetBlips("Seamarks", items)
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(inst: Instance)
		task.defer(track, inst) -- Atomic: the whole model arrives together; let its children settle
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(untrack)
	for _, inst in CollectionService:GetTagged(TAG) do
		track(inst)
	end
	RunService.Heartbeat:Connect(step)
end

return SeamarkController
