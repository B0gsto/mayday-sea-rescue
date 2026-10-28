--!strict
-- WeatherController: the client side of the storm (docs 06 section 3.4, docs 05 section 6).
--   * At 10 Hz blends a day base preset (Clear, the default, Calm golden hour or Overcast)
--     toward Calm by DayClock.warmth (the warm dusk and dawn; none 09:00-15:30), toward Night by
--     the sun's elevation and toward Storm by Weather.getIntensity() (Lighting, Atmosphere, Clouds,
--     ColorCorrection, Bloom, SunRays; creates missing effects). It moves ClockTime itself every
--     0.5 s from DayClock (server time + DayClockOffset; StormService writes the same value rarely);
--     a storm's look wins over the hour, and hides the sun.
--   * Sky: swaps the Sky cube faces (src/client/Ocean/SkyAssets) to the dominant preset (Storm
--     above intensity 0.5, Calm at dusk / dawn, else the base, also at night) - Roblox can't blend skies.
--   * Publishes the blended water and haze colours to the ocean as Lighting attributes
--     OceanWaterColor / OceanHazeColor.
--   * Dev override (Studio shots, separate module cache): the Lighting attribute WeatherBase
--     ("Clear" | "Calm" | "Overcast") replaces the base preset while it is set.
--   * Rain: a camera-following ParticleEmitter, rate scaled by intensity and graphics quality,
--     off while a raycast straight up hits a roof.
--   * Lightning in Storm: strikes come from WeatherMath.lightningStrikes(StormId), so every
--     client sees the same bolt at the same world spot and time. Each strike is a Beam bolt, one
--     short brightness flash (strikes are at least WeatherMath.STRIKE_MIN_GAP apart, never a
--     strobe) and thunder delayed by the distance to the camera.
--   * A "Storm incoming!" banner (and siren cue) when the Warning phase begins.

local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioConfig = require(Shared:WaitForChild("Config"):WaitForChild("AudioConfig"))
local AudioController = require(script.Parent:WaitForChild("AudioController"))
local DayClock = require(Shared:WaitForChild("DayClock"))
local Flipbooks = require(Shared:WaitForChild("Fx"):WaitForChild("Flipbooks"))
local LightingPresets = require(Shared:WaitForChild("Config"):WaitForChild("LightingPresets"))
local Net = require(Shared:WaitForChild("Net"))
local OceanQuality =
	require(script.Parent.Parent:WaitForChild("Ocean"):WaitForChild("OceanQuality"))
local OnboardingWeather = require(Shared:WaitForChild("OnboardingWeather"))
local Weather = require(Shared:WaitForChild("Weather"))
local WeatherMath = require(Shared:WaitForChild("WeatherMath"))
local WorldConfig = require(Shared:WaitForChild("Config"):WaitForChild("WorldConfig"))

type Preset = LightingPresets.Preset

-- Assets: placeholders until audio and textures are uploaded (empty id = silent).
local THUNDER_SOUND_ID = AudioConfig.id("Thunder_Near") -- crack + rumble (RL stand-in)
local RAIN_LOOP_SOUND_ID = AudioConfig.id("Rain_Heavy") -- rain bed, looped (wind is AudioController's)
local SIREN_SOUND_ID = AudioConfig.id("Siren_Wail") -- harbour storm siren, one shot (RL stand-in)
-- FX2: 16 motion-blurred streak variants (random start, held) and the ripple ring on the sea.
local RAIN_STREAKS = Flipbooks.uploaded("FX_Rain_Streak")
local RIPPLE_MAX_RATE = 260 -- ripples/s over the RIPPLE_AREA square at full storm, High -- tune
local RIPPLE_AREA = 70 -- studs square around the camera -- tune
local RIPPLE_MAX_HEIGHT = 45 -- camera height above the sea beyond which ripples are not drawn

local BLEND_HZ = 10
local ROOF_CHECK_SECONDS = 0.25
local ROOF_RAY_LENGTH = 150 -- studs -- tune
local RAIN_MAX_RATE = 1300 -- particles/s at full storm, top quality -- tune
local RAIN_AREA = 110 -- studs square around the camera -- tune
local RAIN_HEIGHT = 38 -- studs above the camera -- tune
local RAIN_FALL_SPEED = 85 -- studs/s -- tune
local WIND_PUSH = 22 -- studs/s^2 sideways at full storm -- tune
local RAIN_LOOP_VOLUME = 0.6
local THUNDER_STUDS_PER_SECOND = 1200 -- speed of sound (about 343 m/s) in studs -- tune
local BOLT_TOP_Y = 420
local BOLT_SEGMENTS = 10
local BOLT_LIFETIME = 0.22
local BANNER_HOLD_SECONDS = 4.5

local WeatherController = {}

local DAY_PRESETS: { [string]: Preset } = {
	Clear = LightingPresets.Clear,
	Calm = LightingPresets.Calm,
	Overcast = LightingPresets.Overcast,
}
local basePresetName = "Clear" -- always sunny (user, 2026-10-22); was Overcast
local sky: Sky
local skyKey = ""
local SkyAssets: { [string]: { [string]: string } }? = nil
do
	local ocean = script.Parent.Parent:FindFirstChild("Ocean")
	local module = ocean and ocean:FindFirstChild("SkyAssets")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok and type(result) == "table" then
			SkyAssets = result :: any
		end
	end
end
local atmosphere: Atmosphere
local clouds: Clouds
local colorCorrection: ColorCorrectionEffect
local bloom: BloomEffect
local sunRays: SunRaysEffect
local current: Preset = LightingPresets.Clear

local rainPart: Part
local rainEmitter: ParticleEmitter
local ripplePart: Part
local rippleEmitter: ParticleEmitter
local rainLoop: Sound
local thunderTemplate: Sound
local sirenSound: Sound
local underRoof = false

local bannerGui: ScreenGui
local bannerFrame: Frame
local bannerLabel: TextLabel
local bannerToken = 0

-- Lightning schedule for the current storm.
local strikes: { WeatherMath.Strike } = {}
local strikeStormId = -1
local strikeDuration = -1
local nextStrike = 1
local flashStart = -math.huge
local flashStrength = 0

local function findOrCreate<T>(parent: Instance, className: string, name: string): T
	local existing = parent:FindFirstChildOfClass(className :: any)
	if existing then
		return (existing :: any) :: T
	end
	local created = Instance.new(className :: any)
	created.Name = name
	created.Parent = parent
	return (created :: any) :: T
end

local function newSound(name: string, soundId: string, looped: boolean, volume: number): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = soundId
	sound.Looped = looped
	sound.Volume = volume
	sound.SoundGroup = AudioController.group("Ambience")
	sound.Parent = SoundService
	return sound
end

local function playIfReal(sound: Sound)
	if sound.SoundId ~= "" then
		sound:Play()
	end
end

-- 0.25 (lowest) .. 1 (highest) from the player's graphics quality; Automatic counts as mid.
local function qualityFactor(): number
	local ok, level = pcall(function()
		return (UserSettings():GetService("UserGameSettings") :: any).SavedQualityLevel.Value
	end)
	if not ok or type(level) ~= "number" or level <= 0 then
		return 0.6
	end
	return 0.25 + 0.75 * math.clamp(level / 10, 0, 1)
end

local function reducedMotion(): boolean
	local ok, value = pcall(function()
		return (GuiService :: any).ReducedMotionEnabled
	end)
	return ok and value == true
end

--------------------------------------------------------------------------------------------------
-- Lighting blend

local function applyBlend(p: Preset)
	Lighting.Ambient = p.Ambient
	Lighting.ExposureCompensation = p.ExposureCompensation
	Lighting.OutdoorAmbient = p.OutdoorAmbient
	Lighting.ColorShift_Top = p.ColorShift_Top
	Lighting.EnvironmentDiffuseScale = p.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = p.EnvironmentSpecularScale
	atmosphere.Density = p.AtmosphereDensity
	atmosphere.Haze = p.AtmosphereHaze
	atmosphere.Color = p.AtmosphereColor
	atmosphere.Decay = p.AtmosphereDecay
	atmosphere.Glare = p.AtmosphereGlare
	clouds.Cover = p.CloudsCover
	clouds.Density = p.CloudsDensity
	clouds.Color = p.CloudsColor
	colorCorrection.Saturation = p.Saturation
	colorCorrection.Contrast = p.Contrast
	bloom.Intensity = p.BloomIntensity
	bloom.Size = p.BloomSize
	bloom.Threshold = p.BloomThreshold
	sunRays.Intensity = p.SunRaysIntensity
	sunRays.Enabled = p.SunRaysIntensity > 0.001
end

-- Brightness and tint carry the lightning flash, so they are written every frame.
local function applyFlash(now: number)
	local flash = 0
	local age = now - flashStart
	local duration = LightingPresets.Flash.Duration
	if age >= 0 and age < duration then
		local rise = 0.08 -- eases in: a soft lift, not a hard cut
		flash = if age < rise then age / rise else (1 - (age - rise) / (duration - rise)) ^ 2
		flash *= flashStrength
	end
	Lighting.Brightness = current.Brightness + LightingPresets.Flash.Brightness * flash
	colorCorrection.Brightness = LightingPresets.Flash.ExposureBoost * flash
	colorCorrection.TintColor = current.TintColor:Lerp(LightingPresets.Flash.TintColor, flash)
end

local function smoothstep(e0: number, e1: number, x: number): number
	local t = math.clamp((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)
end

-- 0 by day .. 1 once the sun is well below the horizon (about 13 degrees: a long blue hour). 18:30 (sun y -0.13) is
-- n 0.78. No floor: with the sun on the horizon (18:00) the warm Calm grade still holds (n 0.18).
local function nightFactor(): number
	return 1 - smoothstep(-0.22, 0.08, Lighting:GetSunDirection().Y)
end

-- Twilight (sun from ~4 degrees up to 7.5 below: 17:45..18:30 and 05:30..06:15). The engine tints the sky faces
-- dark orange as the sun meets the horizon, and the blue Night grade over that read as rust-brown (WX1). A warm haze
-- band on the horizon, a lavender grade and a violet decay carry the sky to navy instead, without the glare that
-- washed out the low sun; the land holds about its sunset brightness once the sun is down. Zero by 18:30 (sun
-- y -0.13), so the approved navy 18:30 and the moonlit night are unchanged. -- tune
local TWILIGHT_BAND = Color3.fromHex("#F2A27A")
local TWILIGHT_TINT = Color3.fromHex("#E2D6F2")
local TWILIGHT_DECAY = Color3.fromHex("#3C3F7A")
-- wx3: (75, 80, 115) took the land near black at 18:15 on a phone; this holds it near the 18:00 brightness
local TWILIGHT_OUTDOOR = Color3.fromRGB(140, 135, 165)
-- A storm at night: a teal-slate sea, renders near (40, 64, 70) (wx3; #2E5A60 rendered navy). The night light is
-- blue, so the albedo leans warm. -- tune
local STORM_NIGHT_WATER = Color3.fromRGB(108, 122, 97)
-- Under the night storm deck the glossy wave facets mirrored the sky in hard-edged pale patches (wx2). -- tune
local STORM_NIGHT_SPECULAR = 0.25

local function grade(p: Preset, y: number)
	local below = smoothstep(-0.13, -0.07, y)
	local twilight = below * (1 - smoothstep(0, 0.07, y))
	if twilight > 0.001 then
		p.AtmosphereColor = p.AtmosphereColor:Lerp(TWILIGHT_BAND, twilight)
		p.AtmosphereDecay = p.AtmosphereDecay:Lerp(TWILIGHT_DECAY, twilight)
		p.AtmosphereGlare *= 1 - twilight
		p.TintColor = p.TintColor:Lerp(TWILIGHT_TINT, twilight)
		p.OutdoorAmbient =
			p.OutdoorAmbient:Lerp(TWILIGHT_OUTDOOR, below * (1 - smoothstep(-0.07, 0, y)))
	end
	-- Low sun (6:00 and 18:00, about half an hour either side): softer bloom and rays, so the disc on the horizon
	-- doesn't wash the island out. -- tune
	local low = (1 - smoothstep(0.03, 0.15, y)) * smoothstep(-0.1, -0.03, y)
	if low > 0.001 then
		p.BloomThreshold += (math.max(p.BloomThreshold, 1.4) - p.BloomThreshold) * low
		p.SunRaysIntensity += (math.min(p.SunRaysIntensity, 0.05) - p.SunRaysIntensity) * low
	end
end

local function applySky(key: string)
	if key == skyKey then
		return
	end
	skyKey = key
	local faces = SkyAssets and SkyAssets[key]
	if faces then
		-- Preload before assigning: the sky's specular environment map is captured from the faces as set, and faces
		-- still loading are captured black, so the glossy water reflected black blobs at grazing angles (play3 s4).
		task.spawn(function()
			local ids = { faces.Bk, faces.Dn, faces.Ft, faces.Lf, faces.Rt, faces.Up }
			pcall(ContentProvider.PreloadAsync, ContentProvider, ids)
			if skyKey ~= key then
				return
			end
			sky.SkyboxBk = faces.Bk
			sky.SkyboxDn = faces.Dn
			sky.SkyboxFt = faces.Ft
			sky.SkyboxLf = faces.Lf
			sky.SkyboxRt = faces.Rt
			sky.SkyboxUp = faces.Up
		end)
	end
	-- No sun, moon or stars behind a solid cloud deck.
	local open = key ~= "Storm" and key ~= "Overcast"
	sky.CelestialBodiesShown = open
	sky.StarCount = if open then 3000 else 0
end

-- The full blend for this moment: day base -> Night by the sun, -> Storm by intensity.
-- A new player's cold open stays calm on their client even when a storm is already running
-- (G81): OnboardingWeather holds the level at 1 until the cold open ends, then eases it out.
local startedAt = os.clock()
local calmLevel = 0

local function calmTarget(): number
	local player = Players.LocalPlayer
	local active = player:GetAttribute("ColdOpenActive") == true
	local done = player:GetAttribute("ColdOpenDone") == true
	return OnboardingWeather.target(active, done, os.clock() - startedAt)
end

local function computeBlend(intensity: number): Preset
	local override = Lighting:GetAttribute("WeatherBase")
	local name = basePresetName
	if type(override) == "string" and DAY_PRESETS[override] then
		name = override
	end
	Lighting:SetAttribute("LocalStormIntensity", intensity) -- the client sea, boats and audio
	local warm = DayClock.warmth(Lighting.ClockTime)
	local day = if warm > 0.001
		then LightingPresets.blend(DAY_PRESETS[name], LightingPresets.Calm, warm)
		else DAY_PRESETS[name]
	local n = nightFactor()
	local dayMix = if n > 0.001 then LightingPresets.blend(day, LightingPresets.Night, n) else day
	local stormMix = LightingPresets.Storm
	if n > 0.001 then
		stormMix = LightingPresets.blend(LightingPresets.Storm, LightingPresets.Night, n * 0.8)
		-- the storm keeps its cloud deck at night; only the light darkens
		stormMix.CloudsCover = LightingPresets.Storm.CloudsCover
		stormMix.CloudsDensity = LightingPresets.Storm.CloudsDensity
		stormMix.WaterColor = LightingPresets.Storm.WaterColor:Lerp(STORM_NIGHT_WATER, n)
		stormMix.EnvironmentSpecularScale += (STORM_NIGHT_SPECULAR - stormMix.EnvironmentSpecularScale) * n
	end
	-- At night the day faces stay up: the engine dims them to a moonlit navy with clouds (dark faces render black).
	-- The Calm (sunset-painted) faces until the sun is just below the horizon (n 0.25, about 18:05): on the horizon the
	-- engine turns the day faces' white clouds a dull brown, the painted ones a sunset orange. After it the day faces
	-- dim to violet / navy (the approved 18:30); the Calm faces would go maroon.
	applySky(if intensity >= 0.5 then "Storm" elseif n < 0.25 and warm >= 0.5 then "Calm" else name)
	local p = LightingPresets.blend(dayMix, stormMix, intensity) -- a fresh table: grade() writes to it
	grade(p, Lighting:GetSunDirection().Y)
	Lighting:SetAttribute("OceanWaterColor", p.WaterColor)
	Lighting:SetAttribute("OceanHazeColor", p.AtmosphereColor)
	return p
end

--------------------------------------------------------------------------------------------------
-- Rain

local function createRain()
	rainPart = Instance.new("Part")
	rainPart.Name = "WeatherRainEmitter"
	rainPart.Anchored = true
	rainPart.CanCollide = false
	rainPart.CanQuery = false
	rainPart.CanTouch = false
	rainPart.CastShadow = false
	rainPart.Transparency = 1
	rainPart.Size = Vector3.new(RAIN_AREA, 1, RAIN_AREA)

	rainEmitter = Instance.new("ParticleEmitter")
	rainEmitter.Name = "Rain"
	Flipbooks.apply(rainEmitter, "FX_Rain_Streak")
	rainEmitter.EmissionDirection = Enum.NormalId.Bottom
	rainEmitter.Shape = Enum.ParticleEmitterShape.Box
	rainEmitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	-- World-up, not VelocityParallel: that laid the tall streak cells across the fall (sideways rain). The wind
	-- drift (WIND_PUSH) is a few degrees at 85 studs/s, so upright streaks lose nothing.
	rainEmitter.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
	rainEmitter.Speed = NumberRange.new(RAIN_FALL_SPEED * 0.9, RAIN_FALL_SPEED * 1.1)
	rainEmitter.Lifetime = NumberRange.new(0.7, 0.9)
	if RAIN_STREAKS then
		-- the streak fills ~70 % of its cell's height: about 1.3 studs (40 cm) of 1/50 s exposure
		rainEmitter.Size = NumberSequence.new(3) -- bold enough to read on a phone
		rainEmitter.Squash = NumberSequence.new(0.1)
		rainEmitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.12, 0.15),
			NumberSequenceKeypoint.new(1, 0.35),
		})
	else
		rainEmitter.Size = NumberSequence.new(0.14)
		rainEmitter.Squash = NumberSequence.new(2.6) -- stretch each drop into a streak
		rainEmitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.15, 0.45),
			NumberSequenceKeypoint.new(1, 0.6),
		})
	end
	rainEmitter.Color = ColorSequence.new(LightingPresets.Palette.RainGrey)
	rainEmitter.LightInfluence = if RAIN_STREAKS then 0.5 else 0.6 -- 0.85 sank into the dark storm light
	rainEmitter.LightEmission = 0.35
	rainEmitter.Rate = 0
	rainEmitter.Enabled = true
	rainEmitter.Parent = rainPart

	-- Ripple rings where the drops hit the sea: flat particles on a box at sea level under the camera.
	ripplePart = Instance.new("Part")
	ripplePart.Name = "WeatherRainRipples"
	ripplePart.Anchored = true
	ripplePart.CanCollide = false
	ripplePart.CanQuery = false
	ripplePart.CanTouch = false
	ripplePart.CastShadow = false
	ripplePart.Transparency = 1
	ripplePart.Size = Vector3.new(RIPPLE_AREA, 0.1, RIPPLE_AREA)
	rippleEmitter = Instance.new("ParticleEmitter")
	rippleEmitter.Name = "RainRipples"
	Flipbooks.apply(rippleEmitter, "FX_Rain_OnWater")
	rippleEmitter.EmissionDirection = Enum.NormalId.Top
	rippleEmitter.Shape = Enum.ParticleEmitterShape.Box
	rippleEmitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	rippleEmitter.Orientation = Enum.ParticleOrientation.VelocityPerpendicular -- flat on the water
	rippleEmitter.Speed = NumberRange.new(0.01)
	rippleEmitter.Lifetime = NumberRange.new(0.45, 0.7)
	rippleEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(1, 1.6),
	})
	rippleEmitter.Transparency = NumberSequence.new(0.35)
	rippleEmitter.Color = ColorSequence.new(LightingPresets.Palette.RainGrey)
	rippleEmitter.Rate = 0
	rippleEmitter.Enabled = Flipbooks.uploaded("FX_Rain_OnWater")
	rippleEmitter.Parent = ripplePart

	rainLoop = newSound("StormRainLoop", RAIN_LOOP_SOUND_ID, true, 0)
end

local roofParams = RaycastParams.new()
roofParams.FilterType = Enum.RaycastFilterType.Exclude
roofParams.IgnoreWater = true

local function checkRoof(camera: Camera)
	local exclude: { Instance } = { rainPart }
	local character = Players.LocalPlayer.Character
	if character then
		table.insert(exclude, character)
	end
	roofParams.FilterDescendantsInstances = exclude
	local origin = camera.CFrame.Position + Vector3.new(0, 0.5, 0)
	local hit = Workspace:Raycast(origin, Vector3.new(0, ROOF_RAY_LENGTH, 0), roofParams)
	underRoof = hit ~= nil and hit.Instance.Transparency < 0.9
end

local function updateRain(camera: Camera, intensity: number)
	local position = camera.CFrame.Position
	local look = camera.CFrame.LookVector
	-- Lead the box a little toward where the camera looks, so the streaks fill the view.
	local ahead = Vector3.new(look.X, 0, look.Z) * (RAIN_AREA * 0.25)
	rainPart.CFrame = CFrame.new(position + ahead + Vector3.new(0, RAIN_HEIGHT, 0))
	if rainPart.Parent ~= camera then
		rainPart.Parent = camera -- client-only, never replicated, not hit by other raycasts
	end
	local wind = Weather.getWindDirection()
	rainEmitter.Acceleration = Vector3.new(math.cos(wind), 0, math.sin(wind))
		* (WIND_PUSH * intensity)
	local tierName = OceanQuality.current().name
	local quality = if RAIN_STREAKS then Flipbooks.scale("rain", tierName) else qualityFactor()
	local heavy = if Weather.isGreatStorm() then 1 else 0.5 -- a plain Storm rains lighter
	local rate = if underRoof then 0 else RAIN_MAX_RATE * quality * heavy * intensity * intensity
	rainEmitter.Rate = if rate < 1 then 0 else rate
	local seaY = WorldConfig.SeaLevel
	local above = position.Y - seaY
	ripplePart.CFrame = CFrame.new(position.X + ahead.X, seaY + 0.12, position.Z + ahead.Z)
	if ripplePart.Parent ~= camera then
		ripplePart.Parent = camera
	end
	local ripples = if underRoof
			or above < 0
			or above > RIPPLE_MAX_HEIGHT
		then 0
		else RIPPLE_MAX_RATE * Flipbooks.scale("rain", tierName) * intensity * intensity
	rippleEmitter.Rate = if ripples < 1 then 0 else ripples
	rainLoop.Volume = RAIN_LOOP_VOLUME * intensity * (if underRoof then 0.45 else 1)
	if intensity > 0.01 and not rainLoop.IsPlaying then
		playIfReal(rainLoop)
	elseif intensity <= 0.01 and rainLoop.IsPlaying then
		rainLoop:Stop()
	end
end

--------------------------------------------------------------------------------------------------
-- Lightning

local function strikePosition(strike: WeatherMath.Strike): Vector3
	-- World space around the harbour (origin), so every client agrees where it landed.
	return Vector3.new(
		math.cos(strike.angle) * strike.distance,
		0,
		math.sin(strike.angle) * strike.distance
	)
end

local function drawBolt(ground: Vector3, seed: number)
	local nextFloat = WeatherMath.rng(seed)
	local holder = Instance.new("Part")
	holder.Name = "LightningBolt"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.CFrame = CFrame.identity
	local previous: Attachment? = nil
	local offsetX, offsetZ = 0, 0
	for i = 0, BOLT_SEGMENTS do
		local alpha = i / BOLT_SEGMENTS
		if i > 0 and i < BOLT_SEGMENTS then
			offsetX += (nextFloat() - 0.5) * 60
			offsetZ += (nextFloat() - 0.5) * 60
		elseif i == BOLT_SEGMENTS then
			offsetX, offsetZ = 0, 0
		end
		local attachment = Instance.new("Attachment")
		attachment.Position = ground + Vector3.new(offsetX, BOLT_TOP_Y * (1 - alpha), offsetZ)
		attachment.Parent = holder
		if previous then
			local beam = Instance.new("Beam")
			beam.Attachment0 = previous
			beam.Attachment1 = attachment
			beam.FaceCamera = true
			beam.LightEmission = 1
			beam.LightInfluence = 0
			beam.Brightness = 6
			beam.Color = ColorSequence.new(LightingPresets.Flash.BoltColor)
			beam.Width0 = 7 * (1 - (i - 1) / BOLT_SEGMENTS) + 1.5
			beam.Width1 = 7 * (1 - alpha) + 1.5
			beam.Transparency = NumberSequence.new(0.05)
			beam.Segments = 1
			beam.Parent = holder
		end
		previous = attachment
	end
	holder.Parent = Workspace.CurrentCamera
	Debris:AddItem(holder, BOLT_LIFETIME)
end

local function strike(index: number, info: WeatherMath.Strike, camera: Camera, stormId: number)
	local ground = strikePosition(info)
	drawBolt(ground, stormId * 977 + index)
	local distance = (ground - camera.CFrame.Position).Magnitude
	local strength = math.clamp(1.2 - distance / 2200, 0.35, 1)
	if reducedMotion() then
		strength = 0 -- reduced motion / flashes: the bolt and thunder only
	end
	flashStart = os.clock()
	flashStrength = strength
	if THUNDER_SOUND_ID ~= "" then
		task.delay(distance / THUNDER_STUDS_PER_SECOND, function()
			local thunder = thunderTemplate:Clone()
			thunder.Volume = math.clamp(1.1 - distance / 3000, 0.25, 1)
			thunder.Parent = SoundService
			thunder:Play()
			Debris:AddItem(thunder, 12)
		end)
	end
end

local function updateLightning(camera: Camera, now: number)
	if Weather.getState() ~= "Storm" then
		return
	end
	local snapshot = Weather.getSnapshot()
	if snapshot.StormId ~= strikeStormId or snapshot.StateDuration ~= strikeDuration then
		-- The sequence for a storm is a fixed prefix, so a longer (Great) storm keeps the
		-- strikes already seen and only adds more at the end.
		strikes = WeatherMath.lightningStrikes(snapshot.StormId, snapshot.StateDuration)
		strikeStormId = snapshot.StormId
		strikeDuration = snapshot.StateDuration
		nextStrike = 1
		local elapsed = now - snapshot.StateStartTime
		while strikes[nextStrike] and strikes[nextStrike].time < elapsed - 0.5 do
			nextStrike += 1 -- joined late: skip strikes that already happened
		end
	end
	local elapsed = now - snapshot.StateStartTime
	local info = strikes[nextStrike]
	if info and elapsed >= info.time then
		nextStrike += 1
		if elapsed - info.time < 1 then
			strike(nextStrike - 1, info, camera, snapshot.StormId)
		end
	end
end

--------------------------------------------------------------------------------------------------
-- Banner

local function createBanner()
	bannerGui = Instance.new("ScreenGui")
	bannerGui.Name = "StormBanner"
	bannerGui.ResetOnSpawn = false
	bannerGui.DisplayOrder = 20
	bannerGui.Enabled = false

	bannerFrame = Instance.new("Frame")
	bannerFrame.Name = "Banner"
	bannerFrame.AnchorPoint = Vector2.new(0.5, 0)
	bannerFrame.Position = UDim2.new(0.5, 0, 0, -120)
	bannerFrame.Size = UDim2.fromOffset(460, 64)
	bannerFrame.BackgroundColor3 = LightingPresets.Palette.StormSlate
	bannerFrame.BackgroundTransparency = 0.1
	bannerFrame.Parent = bannerGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = bannerFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromHex("#E8322B") -- Hazard Red: danger
	stroke.Thickness = 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = bannerFrame

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(460, 64)
	sizeLimit.Parent = bannerFrame

	bannerLabel = Instance.new("TextLabel")
	bannerLabel.Name = "Text"
	bannerLabel.BackgroundTransparency = 1
	bannerLabel.Size = UDim2.fromScale(1, 1)
	bannerLabel.Font = Enum.Font.FredokaOne
	bannerLabel.TextScaled = true
	bannerLabel.TextColor3 = Color3.fromHex("#F4F1EA") -- Hull White
	bannerLabel.Text = "Storm incoming!"
	bannerLabel.Parent = bannerFrame

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 18)
	padding.PaddingRight = UDim.new(0, 18)
	padding.Parent = bannerLabel

	local textStroke = Instance.new("UIStroke")
	textStroke.Color = Color3.fromHex("#0A2A3B") -- Abyss Navy
	textStroke.Thickness = 2
	textStroke.Parent = bannerLabel

	bannerGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function showBanner(text: string)
	bannerToken += 1
	local token = bannerToken
	bannerLabel.Text = text
	bannerGui.Enabled = true
	bannerFrame.Position = UDim2.new(0.5, 0, 0, -120)
	local inInfo = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(bannerFrame, inInfo, { Position = UDim2.new(0.5, 0, 0, 72) }):Play()
	task.delay(BANNER_HOLD_SECONDS, function()
		if token ~= bannerToken then
			return
		end
		local outInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local tween =
			TweenService:Create(bannerFrame, outInfo, { Position = UDim2.new(0.5, 0, 0, -120) })
		tween.Completed:Connect(function()
			if token == bannerToken then
				bannerGui.Enabled = false
			end
		end)
		tween:Play()
	end)
end

local function onStateChanged(state: string)
	if state == "Warning" and calmLevel < 0.5 then
		showBanner(if Weather.isGreatStorm() then "Great Storm incoming!" else "Storm incoming!")
		sirenSound.Volume = 0.5
		playIfReal(sirenSound)
		task.delay(5, function() -- one rise and fall, then it fades (the clip runs long)
			TweenService:Create(sirenSound, TweenInfo.new(1.5), { Volume = 0 }):Play()
			task.wait(1.5)
			sirenSound:Stop()
		end)
	end
end

--------------------------------------------------------------------------------------------------

function WeatherController.Init()
	atmosphere = findOrCreate(Lighting, "Atmosphere", "Atmosphere")
	clouds = findOrCreate(Workspace.Terrain, "Clouds", "Clouds")
	colorCorrection = findOrCreate(Lighting, "ColorCorrectionEffect", "WeatherColorCorrection")
	bloom = findOrCreate(Lighting, "BloomEffect", "WeatherBloom")
	sunRays = findOrCreate(Lighting, "SunRaysEffect", "WeatherSunRays")
	sky = findOrCreate(Lighting, "Sky", "Sky")
	sky.StarCount = 3000 -- Roblox only draws stars at night; none under a storm deck (applySky)
	sky.MoonAngularSize = 9 -- tune (13 read oversized)
	-- Visible sun and moon discs (round 3): the built-in textures, set explicitly so an empty
	-- id from an older place file can't hide them. The sun disc drives the water's sun glitter.
	sky.SunTextureId = "rbxasset://sky/sun.jpg"
	sky.MoonTextureId = "rbxasset://sky/moon.jpg"
	sky.SunAngularSize = 14 -- tune
	sky.CelestialBodiesShown = true
	atmosphere.Offset = 0.15
	sunRays.Spread = 0.6
	clouds.Enabled = true

	createRain()
	thunderTemplate = newSound("Thunder", THUNDER_SOUND_ID, false, 1)
	sirenSound = newSound("StormSiren", SIREN_SOUND_ID, false, 0.5)
	createBanner()

	Weather.changed:Connect(onStateChanged)
	-- The phase cue: a Storm upgraded to a Great Storm mid-phase gets its own banner.
	Net.event("StormChanged").OnClientEvent:Connect(function(payload: any)
		if type(payload) == "table" and payload.state == "Storm" and payload.isGreatStorm then
			if Weather.getState() == "Storm" and calmLevel < 0.5 then
				showBanner("GREAT STORM!")
			end
		end
	end)
end

function WeatherController.Start()
	calmLevel = calmTarget()
	local intensity = OnboardingWeather.localIntensity(Weather.getIntensity(), calmLevel)
	current = computeBlend(intensity)
	applyBlend(current)
	if Weather.getState() == "Warning" then
		onStateChanged("Warning") -- joined during the warning
	end

	local sinceBlend = math.huge
	local sinceRoof = math.huge
	local sinceClock = math.huge
	RunService.RenderStepped:Connect(function(dt: number)
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local now = Workspace:GetServerTimeNow()
		sinceClock += dt
		if sinceClock >= 0.5 then
			sinceClock = 0
			local offset = tonumber(Workspace:GetAttribute("DayClockOffset")) or 0
			Lighting.ClockTime = DayClock.clockTime(now + offset)
		end
		sinceBlend += dt
		if sinceBlend >= 1 / BLEND_HZ then
			calmLevel = OnboardingWeather.step(calmLevel, calmTarget(), sinceBlend)
			sinceBlend = 0
			intensity = OnboardingWeather.localIntensity(Weather.getIntensity(now), calmLevel)
			current = computeBlend(intensity)
			applyBlend(current)
		end
		sinceRoof += dt
		if sinceRoof >= ROOF_CHECK_SECONDS then
			sinceRoof = 0
			checkRoof(camera)
		end
		updateRain(camera, intensity)
		if intensity > 0.01 then
			updateLightning(camera, now)
		end
		applyFlash(os.clock())
	end)
end

return WeatherController
