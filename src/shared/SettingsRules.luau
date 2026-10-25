--!strict
-- SettingsRules (pure, client and server): the player settings data model behind the settings
-- panel (src/client/UI/SettingsPanel) and its store (src/client/Camera/Comfort). Lune-tested in
-- tests/Settings.spec.luau.
--
--   Defaults / Ranges / Choices    the keys, their defaults, number ranges and string choices
--   clean(key, value)              a sanitised value, or nil when the key or value is invalid
--   SEASICK                        the "Seasick-safe" comfort preset
--   isPreset(values, preset)       true when every preset key already has the preset value
--   qualityTier(override, savedLevel, touchOnly)   "High" | "Medium" | "Low"
--   mix(values)                   SoundGroup volumes (Master, SFX, Ambience, Radio, Music, Voice)
--
-- Everything is saved in the profile's flags.cameraSettings table (ProgressionRules keeps up to
-- 64 fields there, together with the cinematic "seen_<id>" flags; this model uses 18).

local SettingsRules = {}

export type Quality = "Auto" | "High" | "Medium" | "Low"

local DEFAULTS = {
	-- comfort (camera)
	fov = 75, -- base field of view, degrees
	shake = 0.6, -- camera shake intensity 0..1
	speedFov = true, -- the FOV kick at speed
	sensitivity = 1, -- look sensitivity multiplier
	-- graphics override ("Auto" follows the Roblox graphics quality slider)
	oceanQuality = "Auto",
	scatterQuality = "Auto",
	-- audio (0..1 each; the mix is master x channel)
	volMaster = 1,
	volSfx = 0.9,
	volRadio = 1,
	volMusic = 0.6,
	voice = true, -- voiced radio clips (subtitles always show)
	-- other players' cosmetic sounds (RP-M5, CosmeticsController ctx.muted)
	muteHorns = false,
	muteSirens = false,
	muteRadios = false,
	-- accessibility
	colourAssist = "Off", -- "Off" | "Deuteranopia" | "Protanopia" | "Tritanopia"
	textSize = 100, -- % applied through Layout's text scale
	reduceMotion = false, -- no shake/bob; bursts and flashes become fades/glows
	holdToTap = false, -- hold actions also toggle on a second press; prompts tap
}
SettingsRules.Defaults = table.freeze(table.clone(DEFAULTS))

SettingsRules.Ranges = table.freeze({
	fov = { 60, 95 },
	shake = { 0, 1 },
	sensitivity = { 0.2, 3 },
	volMaster = { 0, 1 },
	volSfx = { 0, 1 },
	volRadio = { 0, 1 },
	volMusic = { 0, 1 },
	textSize = { 100, 150 },
} :: { [string]: { number } })

SettingsRules.Choices = table.freeze({
	oceanQuality = { "Auto", "High", "Medium", "Low" },
	scatterQuality = { "Auto", "High", "Medium", "Low" },
	colourAssist = { "Off", "Deuteranopia", "Protanopia", "Tritanopia" },
} :: { [string]: { string } })

-- Seasick-safe: little shake, no FOV kick and a wider view
-- (a wider FOV lowers the visual-vestibular mismatch). Other keys are left alone.
SettingsRules.SEASICK = table.freeze({
	fov = 85,
	shake = 0.15,
	speedFov = false,
} :: { [string]: any })

-- The comfort keys "Reset comfort" restores (graphics and audio are left alone).
SettingsRules.COMFORT_KEYS = table.freeze({
	"fov",
	"shake",
	"speedFov",
	"sensitivity",
})

function SettingsRules.clean(key: string, value: any): any
	local default = (DEFAULTS :: any)[key]
	if default == nil or type(value) ~= type(default) then
		return nil
	end
	if type(value) == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return nil
		end
		local range = SettingsRules.Ranges[key]
		return if range then math.clamp(value, range[1], range[2]) else value
	elseif type(value) == "string" then
		local choices = SettingsRules.Choices[key]
		if choices and not table.find(choices, value) then
			return nil
		end
	end
	return value
end

function SettingsRules.isPreset(values: { [string]: any }, preset: { [string]: any }): boolean
	for k, v in preset do
		local cur = values[k]
		if type(v) == "number" and type(cur) == "number" then
			if math.abs(cur - v) > 1e-3 then
				return false
			end
		elseif cur ~= v then
			return false
		end
	end
	return true
end

-- The ocean / scatter tier. `savedLevel` is UserGameSettings.SavedQualityLevel 1..10, or nil for
-- Automatic (then phones and tablets get Medium, everything else High). -- tune
function SettingsRules.qualityTier(
	override: string?,
	savedLevel: number?,
	touchOnly: boolean
): string
	if override == "High" or override == "Medium" or override == "Low" then
		return override
	end
	if savedLevel == nil or savedLevel <= 0 then
		return if touchOnly then "Medium" else "High"
	elseif savedLevel <= 3 then
		return "Low"
	elseif savedLevel <= 7 then
		return "Medium"
	end
	return "High"
end

local function unit(v: any): number
	local n = tonumber(v)
	return if n and n == n then math.clamp(n, 0, 1) else 1
end

-- SoundGroup volumes for the nested mix (AudioConfig categories: Master holds Music, SFX,
-- Ambience and Radio; Voice, the voiced radio clips, sits under Radio). Each group carries its own
-- slider value; nesting multiplies them (an effect plays at Master x SFX). Ambience follows SFX.
function SettingsRules.mix(values: { [string]: any }): { [string]: number }
	return {
		Master = unit(values.volMaster),
		SFX = unit(values.volSfx),
		Ambience = unit(values.volSfx),
		Radio = unit(values.volRadio),
		Music = unit(values.volMusic),
		Voice = if values.voice == false then 0 else 1,
	}
end

return table.freeze(SettingsRules)
