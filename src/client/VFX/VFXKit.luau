--!strict
-- VFXKit (docs/26): the game's one effects player. Presets are data (VFX/Presets), textures one table
-- (Config/VFXTextures). Every play is an `Emit` burst from a pooled host (a hidden anchored Part per play slot
-- with its emitters built once), skipped beyond Presets.CULL studs from the camera, scaled by the graphics
-- level and halved (no light flash) under the Settings panel's Reduce motion. Sounds stay with the caller.
--   VFXKit.play(name, cframeOrPart, opts?) -> boolean   opts: { color, scale, radius, height }
--     radius: a `ring` layer's ring (a footprint's half width; past 8 studs it grows the pieces too), height: where
--     `top` layers start, still: no camera punch / tint (someone else's moment)
--   VFXKit.names() -> { string }                        every preset, sorted (the DEV `vfx` bench)
-- FX2 presets may also carry `sounds`, `punch` and `impactTint` (Presets "FX2 core loop"); played by fx2() below.
local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AudioController =
	require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("AudioController"))
local Comfort = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("Comfort"))
local Presets = require(script.Parent:WaitForChild("Presets"))
local VFXTextures = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("VFXTextures")
)

export type Opts = {
	color: Color3?,
	scale: number?,
	radius: number?,
	height: number?,
	still: boolean?,
}

type Emitter = { emitter: ParticleEmitter, layer: Presets.Layer, base: number, color: Color3 }
type Host =
	{ part: Part, top: Attachment, emitters: { Emitter }, light: PointLight?, freeAt: number }

local VFXKit = {}

local SLOTS = 4 -- hosts per preset: a fifth overlapping play reuses the oldest
local pools: { [string]: { Host } } = {}
local folder: Folder? = nil

local okSettings, gameSettings = pcall(function()
	return UserSettings():GetService("UserGameSettings")
end)

local function level(): number
	if not okSettings then
		return 0
	end
	local ok, v = pcall(function()
		return (gameSettings :: any).SavedQualityLevel.Value
	end)
	return if ok and type(v) == "number" then v else 0
end

local function numbers(values: { number }, k: number?): NumberSequence
	local m = k or 1
	if #values == 1 then
		return NumberSequence.new(values[1] * m)
	end
	local keys = {}
	for i, v in values do
		table.insert(keys, NumberSequenceKeypoint.new((i - 1) / (#values - 1), v * m))
	end
	return NumberSequence.new(keys)
end

local function build(l: Presets.Layer, color: Color3, parent: Instance): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	local tex = VFXTextures[l.tex]
	e.Texture = tex.id
	e.FlipbookLayout = (Enum.ParticleFlipbookLayout :: any)[tex.layout]
	if tex.layout ~= "None" then
		e.FlipbookMode = (Enum.ParticleFlipbookMode :: any)[tex.mode]
		e.FlipbookFramerate = NumberRange.new(tex.fps or 0)
		e.FlipbookStartRandom = tex.random == true
	end
	e.Rate = 0
	e.Color = ColorSequence.new(color)
	e.Size = numbers(l.size)
	e.Transparency = numbers(l.transparency or { 0, 1 })
	e.Lifetime = NumberRange.new(l.lifetime[1], l.lifetime[2])
	e.Speed = NumberRange.new(l.speed[1], l.speed[2])
	local spread = l.spread or { 0, 0 }
	e.SpreadAngle = Vector2.new(spread[1], spread[2])
	e.Acceleration = l.accel or Vector3.zero
	e.Drag = l.drag or 0
	if l.rotation then
		e.Rotation = NumberRange.new(l.rotation[1], l.rotation[2])
	end
	if l.spin then
		e.RotSpeed = NumberRange.new(l.spin[1], l.spin[2])
	end
	e.EmissionDirection = (Enum.NormalId :: any)[l.dir or "Top"]
	e.Orientation = if l.flat
		then Enum.ParticleOrientation.VelocityPerpendicular
		elseif l.streak then Enum.ParticleOrientation.VelocityParallel
		else Enum.ParticleOrientation.FacingCamera
	e.LightEmission = l.emission or 0
	e.LightInfluence = math.min(0.5, 1 - (l.emission or 0)) -- half lit: flat toy colours still read at night
	if l.ring then -- from the host Part's disc edge (its size is the ring), outward
		e.Shape = Enum.ParticleEmitterShape.Disc
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
		e.ShapePartial = 0.85
	end
	e.Parent = parent
	return e
end

local function newHost(p: Presets.Preset): Host
	if not (folder and folder.Parent) then
		local f = Instance.new("Folder")
		f.Name = "VFX"
		f.Parent = Workspace
		folder = f
	end
	local part = Instance.new("Part")
	part.Name = "VFXHost"
	part.Size = Vector3.one
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
	part.CastShadow = false
	part.Parent = folder
	local origin = Instance.new("Attachment")
	origin.Name = "Origin"
	origin.Parent = part
	local top = Instance.new("Attachment")
	top.Name = "Top"
	top.Parent = part
	local host: Host = { part = part, top = top, emitters = {}, light = nil, freeAt = 0 }
	for _, l in p.layers do
		local parent = if l.ring then part elseif l.at == "top" then top else origin
		for _, c in l.colors do
			local e = build(l, c, parent)
			table.insert(
				host.emitters,
				{ emitter = e, layer = l, base = l.count / #l.colors, color = c }
			)
		end
	end
	if p.light then
		local light = Instance.new("PointLight")
		light.Brightness = 0
		light.Color = p.light.color
		light.Range = p.light.range
		light.Shadows = false
		light.Parent = origin
		host.light = light
	end
	return host
end

-- A free host for the preset, a new one while under SLOTS, else the one that frees soonest.
local function take(name: string, p: Presets.Preset, now: number): Host
	local pool = pools[name]
	if not pool then
		pool = {}
		pools[name] = pool
	end
	local soonest: Host? = nil
	for _, h in pool do
		if h.freeAt <= now then
			return h
		end
		if not soonest or h.freeAt < soonest.freeAt then
			soonest = h
		end
	end
	if #pool < SLOTS or not soonest then
		local h = newHost(p)
		table.insert(pool, h)
		return h
	end
	return soonest
end

-- FX2: a short decaying camera shake plus an FOV kick the camera controllers damp back (the same `punch` as the FX1
-- kit: fov degrees in, negative widens; shake 0..1; time). Applied after the camera's step, undone before the next.
-- shortcut: a minimal copy of FX1's punch; reconcile into one when the FX1 branch merges.
local shakeUntil, shakeAmp, shakeTime = 0, 0, 1
local applied = CFrame.identity
local bound = false
local function punch(spec: { fov: number, shake: number, time: number })
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	camera.FieldOfView -= spec.fov
	if spec.shake <= 0 then
		return
	end
	if not bound then
		bound = true
		RunService:BindToRenderStep("VFXPunchUndo", Enum.RenderPriority.First.Value, function()
			camera.CFrame *= applied:Inverse()
			applied = CFrame.identity
			if os.clock() >= shakeUntil then
				RunService:UnbindFromRenderStep("VFXPunchUndo")
				RunService:UnbindFromRenderStep("VFXPunch")
				bound = false
			end
		end)
		RunService:BindToRenderStep("VFXPunch", Enum.RenderPriority.Camera.Value + 1, function()
			local k = math.max(shakeUntil - os.clock(), 0) / shakeTime
			local a = shakeAmp * k * k * 0.08 * (tonumber(Comfort.get("shake")) or 0.6)
			local t = os.clock() * 28
			applied = CFrame.Angles(
				math.noise(t, 1.3) * a,
				math.noise(t, 7.1) * a,
				math.noise(t, 4.7) * a * 0.5
			)
			camera.CFrame *= applied
		end)
	end
	shakeUntil, shakeAmp, shakeTime = os.clock() + spec.time, spec.shake, spec.time
end

-- FX2: the impact frame, a soft colour wash that eases out in 0.25 s (never orange; off under Reduce motion).
local grade: ColorCorrectionEffect? = nil
local function impactTint(color: Color3)
	local g = grade
	if not (g and g.Parent) then
		local c = Instance.new("ColorCorrectionEffect")
		c.Name = "VFXImpactTint"
		c.Parent = Lighting
		g, grade = c, c
	end
	local c = g :: ColorCorrectionEffect
	c.TintColor, c.Brightness = color, 0.06
	TweenService:Create(c, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
		TintColor = Color3.new(1, 1, 1),
		Brightness = 0,
	}):Play()
end

local function fx2(p: any, at: Vector3, o: Opts, reduced: boolean)
	for _, snd in p.sounds or {} do
		task.delay(snd.delay or 0, AudioController.play, snd.clip, at, snd.volume, snd.pitch)
	end
	if reduced or o.still then
		return
	end
	if p.punch then
		punch(p.punch)
	end
	if p.impactTint then
		impactTint(p.impactTint)
	end
end

function VFXKit.play(name: string, target: CFrame | BasePart, opts: Opts?): boolean
	local p = Presets.ALL[name]
	if not p then
		warn(`[VFXKit] unknown preset {name}`)
		return false
	end
	local cf = if typeof(target) == "CFrame" then target else (target :: BasePart).CFrame
	local camera = Workspace.CurrentCamera
	if camera and not Presets.visible((camera.CFrame.Position - cf.Position).Magnitude) then
		return false
	end
	local o: Opts = opts or {}
	local scale = o.scale or 1
	local reduced = Comfort.reducedMotion()
	local lv = level()
	local now = os.clock()
	local host = take(name, p, now)
	host.freeAt = now + Presets.duration(p)
	local r = math.max(o.radius or 1, 0.2)
	host.part.Size = Vector3.new(r * 2, 0.2, r * 2)
	host.part.CFrame = cf
	host.top.Position = Vector3.new(0, o.height or 0, 0)
	-- a whole building's footprint grows the pieces so they still read from the camera: ground rings with the
	-- radius up to 4x (round the building, not a wash over the island), the rest by its square root
	local grow = math.max(1, r / 8)
	for _, slot in host.emitters do
		local l = slot.layer
		slot.emitter.Size = numbers(l.size, if l.flat then math.min(grow, 4) else math.sqrt(grow))
		if l.tint then
			slot.emitter.Color = ColorSequence.new(o.color or slot.color)
		end
		local n = Presets.count(slot.base, scale, lv, reduced)
		if l.delay and l.delay > 0 then
			task.delay(l.delay, slot.emitter.Emit, slot.emitter, n)
		else
			slot.emitter:Emit(n)
		end
	end
	local light, spec = host.light, p.light
	if light and spec and not reduced and scale >= (spec.minScale or 0) then
		if o.color then
			light.Color = o.color
		end
		light.Brightness = spec.brightness
		TweenService
			:Create(light, TweenInfo.new(spec.time, Enum.EasingStyle.Quad), { Brightness = 0 })
			:Play()
	end
	fx2(p, cf.Position, o, reduced)
	return true
end

-- Every texture loads at start: an unloaded flipbook draws nothing, so a session's first splash came out blank.
task.spawn(function()
	local ids = {}
	for _, tex in VFXTextures do
		table.insert(ids, tex.id)
	end
	pcall(ContentProvider.PreloadAsync, ContentProvider, ids)
end)

function VFXKit.names(): { string }
	local out = {}
	for name in Presets.ALL do
		table.insert(out, name)
	end
	table.sort(out)
	return out
end

return VFXKit
