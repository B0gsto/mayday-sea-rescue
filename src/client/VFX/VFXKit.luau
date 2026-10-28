--!strict
-- VFXKit (docs/26): the game's one effects player. Presets are data (VFX/Presets), textures one table
-- (Config/VFXTextures). Every play is an `Emit` burst from a pooled host (a hidden anchored Part per play slot
-- with its emitters built once), skipped beyond Presets.CULL studs from the camera, scaled by the graphics
-- level and halved (no light flash) under the Settings panel's Reduce motion. Sounds stay with the caller, except
-- the FX1 spectacle presets' layered `sounds` (with their beams, camera punch and hit-stop, Presets header).
--   VFXKit.play(name, cframeOrPart, opts?) -> boolean   opts: { color, scale, radius, height, still }
--     radius: a `ring` layer's ring (a footprint's half width; past 8 studs it grows the pieces too), height: where
--     `top` layers start, still: no camera punch (someone else's moment)
--   VFXKit.names() -> { string }                        every preset, sorted (the DEV `vfx` bench)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AudioController =
	require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("AudioController"))
local Comfort = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("Comfort"))
local Presets = require(script.Parent:WaitForChild("Presets"))
local Shake = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("Shake"))
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
type Pillar = { beam: Beam, tip: Attachment, spec: Presets.Beam }
type Host = {
	part: Part,
	top: Attachment,
	emitters: { Emitter },
	light: PointLight?,
	pillars: { Pillar },
	freeAt: number,
}

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

local function numbers(
	values: { number },
	k: number?,
	ease: string?,
	clamp: boolean?
): NumberSequence
	local m = k or 1
	if #values == 1 then
		return NumberSequence.new(values[1] * m)
	end
	local keys = {}
	for _, tv in Presets.curve(values, ease) do
		local v = tv[2] * m
		table.insert(
			keys,
			NumberSequenceKeypoint.new(tv[1], if clamp then math.clamp(v, 0, 1) else v)
		)
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
	e.Size = numbers(l.size, 1, l.ease)
	e.Transparency = numbers(l.transparency or { 0, 1 }, 1, l.fade, true)
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
	local host: Host =
		{ part = part, top = top, emitters = {}, light = nil, pillars = {}, freeAt = 0 }
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
	for _, b in (p.beams or {}) :: { Presets.Beam } do
		local tip = Instance.new("Attachment")
		tip.Name = "BeamTip"
		tip.Parent = part
		local beam = Instance.new("Beam")
		beam.Attachment0 = if b.at == "top" then top else origin
		beam.Attachment1 = tip
		beam.Texture = VFXTextures.light_beam.id
		beam.TextureMode = Enum.TextureMode.Stretch
		beam.FaceCamera = true
		beam.Segments = 1
		beam.Color = ColorSequence.new(b.color)
		beam.Transparency = NumberSequence.new({ -- solid at the base, gone at the top
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.6, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		})
		beam.LightEmission = b.emission or 0
		beam.LightInfluence = 0
		beam.Width0, beam.Width1 = 0, 0
		beam.Parent = part
		table.insert(host.pillars, { beam = beam, tip = tip, spec = b })
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

-- A light pillar shoots up from its base, holds, then thins away.
local function pillar(pl: Pillar, base: Vector3, color: Color3?, scale: number)
	local s = pl.spec
	if s.tint and color then
		pl.beam.Color = ColorSequence.new(color)
	end
	local w = s.width * scale
	pl.tip.Position = base + Vector3.new(0, s.height * 0.15, 0)
	pl.beam.Width0, pl.beam.Width1 = w * 0.3, w * 0.3
	local quick = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(pl.tip, quick, { Position = base + Vector3.new(0, s.height * scale, 0) })
		:Play()
	TweenService:Create(pl.beam, quick, { Width0 = w, Width1 = w * 0.8 }):Play()
	TweenService:Create(
		pl.beam,
		TweenInfo.new(s.time - 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.12),
		{ Width0 = 0, Width1 = 0 }
	):Play()
end

-- The impact frame (docs/26): a 2-3 frame screen pop (tint, saturation, brightness) that eases back. One shared
-- ColorCorrection under the camera; a newer hit restarts it.
local frameFx: ColorCorrectionEffect? = nil
local frameTween: Tween? = nil
local function impactFrame(spec: Presets.Frame, color: Color3?)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local cc: ColorCorrectionEffect = frameFx or Instance.new("ColorCorrectionEffect")
	if cc.Parent ~= camera then
		cc.Name = "VFXImpactFrame"
		cc.Parent = camera
		frameFx = cc
	end
	if frameTween then
		frameTween:Cancel()
	end
	cc.TintColor = if color then spec.tint:Lerp(color, 0.2) else spec.tint
	cc.Saturation, cc.Brightness, cc.Contrast = spec.saturation, spec.brightness, spec.contrast or 0
	local back = TweenService:Create(
		cc,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.05),
		{ TintColor = Color3.new(1, 1, 1), Saturation = 0, Brightness = 0, Contrast = 0 }
	)
	frameTween = back
	back:Play()
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
		slot.emitter.Size =
			numbers(l.size, if l.flat then math.min(grow, 4) else math.sqrt(grow), l.ease)
		if l.tint then
			slot.emitter.Color = ColorSequence.new(o.color or slot.color)
		end
		slot.emitter.TimeScale = 1
		local n = if l.flash and reduced then 0 else Presets.count(slot.base, scale, lv, reduced)
		if n == 0 then
			continue
		elseif l.delay and l.delay > 0 then
			task.delay(l.delay, slot.emitter.Emit, slot.emitter, n)
		else
			slot.emitter:Emit(n)
		end
	end
	for _, s in (p.sounds or {}) :: { Presets.Sound } do
		task.delay(s.delay or 0, AudioController.play, s.clip, cf.Position, s.volume, s.pitch)
	end
	task.delay(p.impact or 0, function()
		local light, spec = host.light, p.light
		if light and spec and not reduced and scale >= (spec.minScale or 0) then
			if o.color then
				light.Color = o.color
			end
			light.Brightness = spec.brightness
			TweenService:Create(
				light,
				TweenInfo.new(spec.time, Enum.EasingStyle.Exponential),
				{ Brightness = 0 }
			):Play()
		end
		for _, pl in host.pillars do
			pillar(
				pl,
				if pl.spec.at == "top" then host.top.Position else Vector3.zero,
				o.color,
				scale
			)
		end
		local kick = p.punch
		if kick and not o.still then
			Shake.kick(kick.fov)
			Shake.add({
				magnitude = kick.magnitude,
				roughness = kick.roughness,
				time = kick.time,
				pos = kick.pos,
			})
		end
		if p.frame and not o.still and not reduced then
			impactFrame(p.frame, o.color)
		end
		local stop = p.hitstop
		if stop then -- the impact frame: every burst crawls out, then snaps to full speed
			for _, slot in host.emitters do
				slot.emitter.TimeScale = 0.2
			end
			task.delay(stop, function()
				for _, slot in host.emitters do
					slot.emitter.TimeScale = 1
				end
			end)
		end
	end)
	return true
end

function VFXKit.names(): { string }
	local out = {}
	for name in Presets.ALL do
		table.insert(out, name)
	end
	table.sort(out)
	return out
end

return VFXKit
