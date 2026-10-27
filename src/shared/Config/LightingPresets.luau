--!strict
-- LightingPresets: the Clear, Calm (golden hour), Overcast, Storm and Night looks from
-- docs/05-art-direction.md section 6, as data. WeatherController picks a day base (Clear, Calm
-- or Overcast; Clear is the always-sunny default), blends it toward Night by the sun elevation and
-- toward Storm by Weather.getIntensity(), and swaps the matching Sky (src/client/Ocean/SkyAssets).
-- WaterColor is published to the ocean (Clear: blue-teal; others grey-green, darker in storm).
-- Values are starting points (-- tune). Colours use palette hex codes from docs 05 section 3.
--
-- ClockTime is listed for reference only: the day/night clock (DayClock, written by StormService)
-- moves the sun; Calm doubles as the dusk / dawn look and Night as the 3 min moonlit night.

export type Preset = {
	-- Lighting
	ClockTime: number,
	Brightness: number,
	ExposureCompensation: number,
	Ambient: Color3,
	OutdoorAmbient: Color3,
	ColorShift_Top: Color3,
	EnvironmentDiffuseScale: number,
	EnvironmentSpecularScale: number,
	-- Atmosphere
	AtmosphereDensity: number,
	AtmosphereHaze: number,
	AtmosphereColor: Color3,
	AtmosphereDecay: Color3,
	AtmosphereGlare: number,
	-- Clouds
	CloudsCover: number,
	CloudsDensity: number,
	CloudsColor: Color3,
	-- ColorCorrection
	Saturation: number,
	Contrast: number,
	TintColor: Color3,
	-- Bloom
	BloomIntensity: number,
	BloomSize: number,
	BloomThreshold: number,
	-- SunRays (0 = off)
	SunRaysIntensity: number,
	-- Deep-water tint, published to OceanController as the Lighting attribute OceanWaterColor
	WaterColor: Color3,
}

local hex = Color3.fromHex

-- Palette (docs 05 section 3)
local Palette = table.freeze({
	DeepTeal = hex("#0E5E6F"),
	AbyssNavy = hex("#0A2A3B"),
	ShallowAqua = hex("#3FC1C0"),
	Foam = hex("#EAF7F5"),
	GoldenHour = hex("#FFC872"),
	SunsetCoral = hex("#FF8C69"),
	StormSteel = hex("#5B6B7A"),
	StormSlate = hex("#2F3A45"),
	RainGrey = hex("#9AA8B3"),
	BeaconYellow = hex("#FFE27A"),
})

local Calm: Preset = table.freeze({
	ClockTime = 17.3,
	Brightness = 2.4,
	ExposureCompensation = 0,
	Ambient = hex("#3A3430"),
	OutdoorAmbient = hex("#8A7B6E"),
	ColorShift_Top = hex("#FFC890"),
	EnvironmentDiffuseScale = 1,
	EnvironmentSpecularScale = 1,
	AtmosphereDensity = 0.36,
	AtmosphereHaze = 2.2,
	AtmosphereColor = hex("#E3B48C"),
	AtmosphereDecay = hex("#B8754E"),
	AtmosphereGlare = 0.6,
	CloudsCover = 0.5,
	CloudsDensity = 0.35,
	CloudsColor = hex("#FFD8B2"),
	Saturation = -0.05,
	Contrast = 0.08,
	TintColor = hex("#FFF0E0"),
	BloomIntensity = 0.3,
	BloomSize = 24,
	BloomThreshold = 1.1, -- glitter blooms (round 3)
	SunRaysIntensity = 0.12, -- golden shafts
	WaterColor = hex("#36463F"),
})

local Storm: Preset = table.freeze({
	ClockTime = 14.5,
	Brightness = 1.0,
	ExposureCompensation = 0.3,
	Ambient = hex("#33383D"),
	OutdoorAmbient = hex("#6A7278"),
	ColorShift_Top = hex("#A9B2B8"),
	EnvironmentDiffuseScale = 1,
	EnvironmentSpecularScale = 0.8,
	AtmosphereDensity = 0.55,
	AtmosphereHaze = 3.0,
	AtmosphereColor = hex("#6F777D"),
	AtmosphereDecay = hex("#4F575D"),
	AtmosphereGlare = 0,
	CloudsCover = 0.92,
	CloudsDensity = 0.9,
	CloudsColor = hex("#5E666C"),
	Saturation = -0.25,
	Contrast = 0.12,
	TintColor = hex("#E8EEF2"),
	BloomIntensity = 0.2,
	BloomSize = 28,
	BloomThreshold = 1.8,
	SunRaysIntensity = 0,
	WaterColor = hex("#232C2B"),
})

local Night: Preset = table.freeze({
	ClockTime = 21.5,
	Brightness = 0.9,
	-- Moonlit, never a void (audit 2026-10-28 P1-1): the day sky faces dimmed by the engine plus a navy haze give the
	-- sky, a blue-teal sea and a high outdoor fill keep the island and boats readable. Low exposure and bloom so the
	-- Neon lamps glow instead of blooming into white bars (P1-3).
	ExposureCompensation = 0.4,
	Ambient = hex("#36445E"),
	OutdoorAmbient = hex("#7A8CB4"),
	ColorShift_Top = hex("#6B7FA0"),
	EnvironmentDiffuseScale = 0.8,
	EnvironmentSpecularScale = 1,
	AtmosphereDensity = 0.25,
	AtmosphereHaze = 1.0,
	AtmosphereColor = hex("#4A68A8"),
	AtmosphereDecay = hex("#30487A"),
	AtmosphereGlare = 0,
	CloudsCover = 0.45,
	CloudsDensity = 0.40,
	CloudsColor = hex("#5A6886"), -- moonlit cloud
	Saturation = -0.12,
	Contrast = 0.10,
	TintColor = hex("#C8D6F2"),
	BloomIntensity = 0.3,
	BloomSize = 24,
	BloomThreshold = 1.3,
	SunRaysIntensity = 0,
	WaterColor = hex("#1E6670"),
})

-- Clear: the always-sunny default (user, 2026-10-22): blue sky, white clouds, warm sun, clear
-- distance, colours that pop. Brightness/exposure stay moderate so pale ground doesn't blow out. -- tune
local Clear: Preset = table.freeze({
	ClockTime = 14,
	-- Lighting study 2026-10-28 (variant C, build/status/2026-10-28/lighting): crisp and saturated, a high sun
	-- (Lighting.GeographicLatitude 30 and ShadowSoftness 0.15 in default.project.json), an azure sea.
	Brightness = 2.8,
	ExposureCompensation = 0.1,
	Ambient = hex("#2C3440"),
	OutdoorAmbient = hex("#7A8898"),
	ColorShift_Top = hex("#FFE6C4"), -- warm sun (map pass 2: warmer)
	EnvironmentDiffuseScale = 1,
	EnvironmentSpecularScale = 1, -- sky reflection and sun glints on the sea (playtest 2: 0.55 read as a matte lawn)
	AtmosphereDensity = 0.15, -- clear distance; the island still reads from the air
	AtmosphereHaze = 0,
	AtmosphereColor = hex("#D6E6F0"),
	AtmosphereDecay = hex("#4F86C0"),
	AtmosphereGlare = 0.1,
	CloudsCover = 0.45,
	CloudsDensity = 0.3,
	CloudsColor = hex("#FFFFFF"),
	Saturation = 0.3,
	Contrast = 0.18,
	TintColor = hex("#FFFCF6"),
	BloomIntensity = 0.15,
	BloomSize = 20,
	BloomThreshold = 1.8, -- sun glitter only, not the pale ground or Neon trim
	SunRaysIntensity = 0.05,
	WaterColor = hex("#1A6F86"), -- azure, bluer than grass (playtest 2: green-teal #24493C read as lawn)
})

local Overcast: Preset = table.freeze({
	ClockTime = 13,
	Brightness = 1.8,
	ExposureCompensation = 0.2,
	Ambient = hex("#3A3F44"),
	OutdoorAmbient = hex("#8D949A"),
	ColorShift_Top = hex("#D8DEE2"),
	EnvironmentDiffuseScale = 1,
	EnvironmentSpecularScale = 1,
	AtmosphereDensity = 0.31, -- T5: bright overcast, not fog (was 0.38 / haze 2.0)
	AtmosphereHaze = 1.3,
	AtmosphereColor = hex("#A9B0B4"),
	AtmosphereDecay = hex("#7D858A"),
	AtmosphereGlare = 0,
	CloudsCover = 0.85,
	CloudsDensity = 0.55,
	CloudsColor = hex("#C9CED1"),
	Saturation = 0.02, -- T5: was -0.10 / contrast 0.08 (grey, flat)
	Contrast = 0.14,
	TintColor = hex("#F6F6F2"),
	BloomIntensity = 0.2,
	BloomSize = 24,
	BloomThreshold = 1.8,
	SunRaysIntensity = 0,
	WaterColor = hex("#34423F"),
})

-- Lightning flash: added on top of the blend for a moment. -- tune
local Flash = table.freeze({
	Brightness = 2.2, -- added to Lighting.Brightness at the flash peak
	ExposureBoost = 0.6, -- added to ColorCorrection.Brightness at the peak
	TintColor = hex("#EAF2FF"),
	BoltColor = hex("#F2F6FF"),
	Duration = 0.35, -- seconds, one single flash, never a strobe
})

local function lerpNumber(a: number, b: number, alpha: number): number
	return a + (b - a) * alpha
end

-- Blends two presets. Numbers lerp, Color3s lerp; alpha 0 = a, 1 = b.
local function blend(a: Preset, b: Preset, alpha: number): Preset
	local out: { [string]: any } = {}
	for key, value in a :: any do
		local other = (b :: any)[key]
		if typeof(value) == "Color3" then
			out[key] = (value :: Color3):Lerp(other, alpha)
		else
			out[key] = lerpNumber(value, other, alpha)
		end
	end
	return (out :: any) :: Preset
end

return table.freeze({
	Palette = Palette,
	Calm = Calm,
	Storm = Storm,
	Night = Night,
	Clear = Clear,
	Overcast = Overcast,
	Flash = Flash,
	blend = blend,
})
