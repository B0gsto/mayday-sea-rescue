--!strict
-- Underwater: the view when the camera is below the drawn surface (ocean spike, round 1).
--   fog       five large camera-facing translucent slices at 12..150 studs (a cheap depth fog
--             that does not fight WeatherController over the shared Atmosphere)
--   grade     ColorCorrection (blue-green tint, lower saturation) plus a light Blur
--   shafts    a few camera-facing Beams slanting down along the sun direction
--   motes     particulates drifting around the camera
-- The water surface is drawn from below too (MeshGrid adds back faces), and it is partly
-- transparent, so the sky shows through it like Snell's window.
-- Everything is created once and only toggled / moved, no per-frame allocation.
local Lighting = game:GetService("Lighting")

local FOG_DISTANCES = { 12, 25, 45, 80, 150 } -- studs -- tune
local FOG_TRANSPARENCY = 0.72 -- per slice -- tune
local FOG_COLOUR = Color3.fromHex("#0F3A40") -- palette deep water, a touch greener -- tune
local SHAFTS = 7
local DEEP_TINT = Color3.fromHex("#7FC4BC")
local DARK_TINT = Color3.fromHex("#3E6E6C")

export type Underwater = {
	folder: Folder,
	slices: { Part },
	cc: ColorCorrectionEffect,
	blur: BlurEffect,
	anchor: Part,
	shafts: { Beam },
	tops: { Attachment },
	bottoms: { Attachment },
	motes: ParticleEmitter,
	window: Part,
	active: boolean,
}

local Underwater = {}

local function basePart(name: string, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function Underwater.new(parent: Instance): Underwater
	local folder = Instance.new("Folder")
	folder.Name = "OceanUnderwater"
	folder.Parent = parent
	local slices = {}
	for i, d in FOG_DISTANCES do
		local p = basePart(`Fog{i}`, folder)
		p.Size = Vector3.new(d * 4, d * 4, 0.05)
		p.Color = FOG_COLOUR
		p.Transparency = 1
		slices[i] = p
	end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "OceanUnderwaterGrade"
	cc.TintColor = Color3.fromHex("#7FC4BC")
	cc.Saturation = -0.15
	cc.Contrast = 0.08
	cc.Brightness = -0.04
	cc.Enabled = false
	cc.Parent = Lighting
	local blur = Instance.new("BlurEffect")
	blur.Name = "OceanUnderwaterBlur"
	blur.Size = 3
	blur.Enabled = false
	blur.Parent = Lighting
	local anchor = basePart("Anchor", folder)
	anchor.Size = Vector3.new(60, 30, 60)
	anchor.Transparency = 1
	local shafts, tops, bottoms = {}, {}, {}
	for i = 1, SHAFTS do
		local a0 = Instance.new("Attachment")
		local a1 = Instance.new("Attachment")
		a0.Parent = anchor
		a1.Parent = anchor
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.FaceCamera = true
		beam.LightEmission = 0.6
		beam.LightInfluence = 0
		beam.Color = ColorSequence.new(Color3.fromHex("#BFE6DE"))
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.82),
			NumberSequenceKeypoint.new(1, 1),
		})
		beam.Width0 = 2 + (i % 3) * 1.5
		beam.Width1 = 5 + (i % 4) * 2
		beam.Segments = 1
		beam.Enabled = false
		beam.Parent = anchor
		shafts[i], tops[i], bottoms[i] = beam, a0, a1
	end
	local motes = Instance.new("ParticleEmitter")
	motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	motes.Color = ColorSequence.new(Color3.fromHex("#CFE3DA"))
	motes.LightInfluence = 0.6
	motes.Size = NumberSequence.new(0.08, 0.15)
	motes.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	motes.Lifetime = NumberRange.new(4, 7)
	motes.Speed = NumberRange.new(0.2, 0.8)
	motes.SpreadAngle = Vector2.new(180, 180)
	motes.Shape = Enum.ParticleEmitterShape.Box
	motes.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	motes.Rate = 0
	motes.Parent = anchor
	-- Snell's window: the bright disc of sky seen straight up through the surface (radius about
	-- 1.13 x depth). A translucent Neon disc just under the surface, above the camera.
	local window = basePart("SurfaceWindow", folder)
	window.Shape = Enum.PartType.Cylinder
	window.Material = Enum.Material.Neon
	window.Color = Color3.fromHex("#9FD3C9")
	window.Size = Vector3.new(0.05, 20, 20)
	window.Transparency = 1
	return {
		window = window,
		folder = folder,
		slices = slices,
		cc = cc,
		blur = blur,
		anchor = anchor,
		shafts = shafts,
		tops = tops,
		bottoms = bottoms,
		motes = motes,
		active = false,
	}
end

-- Call every frame. surfaceY: the water height above the camera.
function Underwater.update(u: Underwater, camera: Camera, surfaceY: number)
	local cf = camera.CFrame
	local under = cf.Position.Y < surfaceY - 0.15
	if under ~= u.active then
		u.active = under
		u.cc.Enabled = under
		u.blur.Enabled = under
		for _, s in u.slices do
			s.Transparency = if under then FOG_TRANSPARENCY else 1
		end
		for _, b in u.shafts do
			b.Enabled = under
		end
		u.motes.Rate = if under then 25 else 0
		u.window.Transparency = 1
	end
	if not under then
		return
	end
	for i, s in u.slices do
		s.CFrame = cf * CFrame.new(0, 0, -FOG_DISTANCES[i])
	end
	local pos = cf.Position
	-- Depth darkening: light falls off quickly with depth below the surface. -- tune
	local depth = math.max(surfaceY - pos.Y, 0)
	local dark = math.clamp(depth / 40, 0, 1)
	u.cc.Brightness = -0.04 - 0.22 * dark
	u.cc.TintColor = DEEP_TINT:Lerp(DARK_TINT, dark)
	local light = math.clamp(Lighting.Brightness / 2.5, 0.15, 1)
	local radius = math.clamp(depth * 1.13 + 3, 4, 90)
	u.window.Size = Vector3.new(0.05, radius * 2, radius * 2)
	u.window.CFrame = CFrame.new(pos.X, surfaceY - 0.35, pos.Z) * CFrame.Angles(0, 0, math.pi / 2)
	u.window.Transparency = 1 - (0.55 * light * (1 - 0.6 * dark))
	u.anchor.CFrame = CFrame.new(pos.X, surfaceY - 15, pos.Z)
	local sun = Lighting:GetSunDirection()
	local down = if sun.Y > 0.05 then -sun.Unit else Vector3.new(0, -1, 0)
	for i, top in u.tops do
		local angle = i * 2.4
		local r = 6 + i * 4
		top.Position = Vector3.new(math.cos(angle) * r, 15, math.sin(angle) * r)
		u.bottoms[i].Position = top.Position + down * (30 + (i % 3) * 10)
	end
end

function Underwater.destroy(u: Underwater)
	u.folder:Destroy()
	u.cc:Destroy()
	u.blur:Destroy()
end

return Underwater
