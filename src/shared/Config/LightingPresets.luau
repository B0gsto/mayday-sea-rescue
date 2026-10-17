--!strict
-- LightingPresets: the Clear, Calm (golden hour), Overcast, Storm and Night looks from
-- docs/05-art-direction.md section 6, as data. WeatherController picks a day base (Clear, Calm
-- or Overcast; Overcast is the default weather), blends it toward Night by the sun elevation and
-- toward Storm by Weather.getIntensity(), and swaps the matching Sky (src/client/Ocean/SkyAssets).
-- WaterColor is published to the ocean (North Atlantic grey-green, darker in storm). Keep it
-- desaturated (S <= ~0.25): sunlight and specular push it toward saturated cyan on screen (round 3).
-- Values are starting points (-- tune). Colours use palette hex codes from docs 05 section 3.
--
-- ClockTime is listed for reference and for setting the scene once; the controller never moves
-- it during a storm (a sun swinging across the sky mid-storm looks broken), it only blends the
-- other values.

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
	ExposureCompensation = 1.1,
	Ambient = hex("#232B39"),
	OutdoorAmbient = hex("#48597A"),
	ColorShift_Top = hex("#6B7FA0"),
	EnvironmentDiffuseScale = 0.8,
	EnvironmentSpecularScale = 1,
	AtmosphereDensity = 0.26,
	AtmosphereHaze = 0.5,
	AtmosphereColor = hex("#2C3850"),
	AtmosphereDecay = hex("#1A2236"),
	AtmosphereGlare = 0,
	CloudsCover = 0.35,
	CloudsDensity = 0.40,
	CloudsColor = hex("#2A3038"),
	Saturation = -0.12,
	Contrast = 0.10,
	TintColor = hex("#DCE4F0"),
	BloomIntensity = 0.6,
	BloomSize = 32,
	BloomThreshold = 1.0,
	SunRaysIntensity = 0,
	WaterColor = hex("#1E2A30"),
})

-- Clear noon and bright overcast (docs 05 section 6.2). -- tune
local Clear: Preset = table.freeze({
	ClockTime = 12.5,
	Brightness = 3.0,
	ExposureCompensation = 0,
	Ambient = hex("#2E3238"),
	OutdoorAmbient = hex("#7C8590"),
	ColorShift_Top = hex("#FFF8EE"), -- round 4: less yellow, the warm top light turned the water olive
	EnvironmentDiffuseScale = 1,
	EnvironmentSpecularScale = 1,
	AtmosphereDensity = 0.28,
	AtmosphereHaze = 0.8,
	AtmosphereColor = hex("#C9D3D8"),
	AtmosphereDecay = hex("#6E8AA5"),
	AtmosphereGlare = 0.3,
	CloudsCover = 0.35,
	CloudsDensity = 0.25,
	CloudsColor = hex("#FFFFFF"),
	Saturation = 0,
	Contrast = 0.05,
	TintColor = hex("#FFFFFF"),
	BloomIntensity = 0.3,
	BloomSize = 24,
	BloomThreshold = 1.2, -- glitter blooms (round 3)
	SunRaysIntensity = 0.08,
	WaterColor = hex("#35484A"), -- round 4: less olive, low saturation (was #364846; #2F474E read cyan)
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
	AtmosphereDensity = 0.38,
	AtmosphereHaze = 2.0,
	AtmosphereColor = hex("#A9B0B4"),
	AtmosphereDecay = hex("#7D858A"),
	AtmosphereGlare = 0,
	CloudsCover = 0.85,
	CloudsDensity = 0.55,
	CloudsColor = hex("#C9CED1"),
	Saturation = -0.10,
	Contrast = 0.08,
	TintColor = hex("#F2F5F7"),
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
