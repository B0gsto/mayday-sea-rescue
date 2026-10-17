--!strict
-- LightingPresets: the Calm (golden hour), Storm and Night looks from docs/05-art-direction.md
-- section 6, as data. WeatherController blends Calm -> Storm by Weather.getIntensity().
-- Values are starting points (-- tune). Colours use palette hex codes from docs 05 section 3.
--
-- ClockTime is listed for reference and for setting the scene once; the controller never moves
-- it during a storm (a sun swinging across the sky mid-storm looks broken), it only blends the
-- other values.

export type Preset = {
	-- Lighting
	ClockTime: number,
	Brightness: number,
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
	-- Ocean tint for OceanController (stream A may read it)
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
	Brightness = 2.6,
	Ambient = hex("#3A3F4A"),
	OutdoorAmbient = hex("#8A7F70"),
	ColorShift_Top = Palette.GoldenHour,
	EnvironmentDiffuseScale = 1,
	EnvironmentSpecularScale = 1,
	AtmosphereDensity = 0.30,
	AtmosphereHaze = 1.2,
	AtmosphereColor = hex("#FFD9A8"),
	AtmosphereDecay = Palette.SunsetCoral,
	AtmosphereGlare = 0.6,
	CloudsCover = 0.45,
	CloudsDensity = 0.35,
	CloudsColor = hex("#FFF1DD"),
	Saturation = 0.10,
	Contrast = 0.05,
	TintColor = hex("#FFF4E6"),
	BloomIntensity = 0.4,
	BloomSize = 24,
	BloomThreshold = 1.6,
	SunRaysIntensity = 0.04, -- "on, low"
	WaterColor = Palette.DeepTeal,
})

local Storm: Preset = table.freeze({
	ClockTime = 14.5,
	Brightness = 1.2,
	Ambient = hex("#3A4450"),
	OutdoorAmbient = hex("#6F7C88"),
	ColorShift_Top = Palette.RainGrey,
	EnvironmentDiffuseScale = 0.7,
	EnvironmentSpecularScale = 0.8,
	AtmosphereDensity = 0.55,
	AtmosphereHaze = 2.8,
	AtmosphereColor = Palette.RainGrey,
	AtmosphereDecay = Palette.StormSlate,
	AtmosphereGlare = 0,
	CloudsCover = 0.92,
	CloudsDensity = 0.80,
	CloudsColor = Palette.StormSteel,
	Saturation = -0.25,
	Contrast = 0.12,
	TintColor = hex("#E6F0F7"),
	BloomIntensity = 0.2,
	BloomSize = 24,
	BloomThreshold = 2,
	SunRaysIntensity = 0,
	WaterColor = Palette.StormSteel,
})

local Night: Preset = table.freeze({
	ClockTime = 21.5,
	Brightness = 0.4,
	Ambient = hex("#141C28"),
	OutdoorAmbient = hex("#28344A"),
	ColorShift_Top = hex("#4A6A9A"),
	EnvironmentDiffuseScale = 0.5,
	EnvironmentSpecularScale = 0.7,
	AtmosphereDensity = 0.35,
	AtmosphereHaze = 1.0,
	AtmosphereColor = hex("#2A3A55"),
	AtmosphereDecay = Palette.AbyssNavy,
	AtmosphereGlare = 0,
	CloudsCover = 0.50,
	CloudsDensity = 0.40,
	CloudsColor = Palette.StormSlate,
	Saturation = -0.10,
	Contrast = 0.08,
	TintColor = hex("#DDE6FF"),
	BloomIntensity = 0.6,
	BloomSize = 28,
	BloomThreshold = 1.2,
	SunRaysIntensity = 0,
	WaterColor = Palette.AbyssNavy,
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
	Flash = Flash,
	blend = blend,
})
