--!strict
-- OceanQuality: picks the ocean grid tier from the player's graphics quality setting
-- (UserGameSettings.SavedQualityLevel). Tiers follow docs/06 section 3.1 (numbers are -- tune).
--
-- Each tier is two rings around the camera:
--   near patch: nearCells x nearCells cells of nearCell studs (full detail, exact at vertices)
--   outer ring: outerCells x outerCells cells of outerCell studs with a holeCells x holeCells hole
--               that the near patch fills exactly (nearCells * nearCell == holeCells * outerCell)
-- The whole system snaps in outerCell steps (a whole multiple of nearCell), so no vertex ever
-- slides. updateHz = 0 means every frame.

local UserInputService = game:GetService("UserInputService")

export type Tier = {
	name: string,
	nearCells: number,
	nearCell: number,
	outerCells: number,
	outerCell: number,
	holeCells: number,
	updateHz: number,
	fallbackCells: number, -- Part-grid fallback resolution when EditableMesh is unavailable
	fallbackCell: number,
}

local OceanQuality = {}

-- Vertex counts: High 1089 near + 576 ring; Medium 625 + 392; Low 169 + 264.
OceanQuality.TIERS = table.freeze({
	High = table.freeze({
		name = "High",
		nearCells = 32,
		nearCell = 4,
		outerCells = 24,
		outerCell = 16,
		holeCells = 8,
		updateHz = 0,
		fallbackCells = 12,
		fallbackCell = 12,
	}),
	Medium = table.freeze({
		name = "Medium",
		nearCells = 24,
		nearCell = 6,
		outerCells = 20,
		outerCell = 18,
		holeCells = 8,
		updateHz = 30,
		fallbackCells = 10,
		fallbackCell = 14,
	}),
	Low = table.freeze({
		name = "Low",
		nearCells = 12,
		nearCell = 10,
		outerCells = 16,
		outerCell = 20,
		holeCells = 6,
		updateHz = 15,
		fallbackCells = 8,
		fallbackCell = 16,
	}),
} :: { [string]: Tier })

local function userGameSettings(): UserGameSettings?
	local ok, result = pcall(function()
		return UserSettings():GetService("UserGameSettings")
	end)
	return if ok then result else nil
end

-- Graphics level 1..10, or nil for Automatic / unknown.
local function savedLevel(): number?
	local settings = userGameSettings()
	if not settings then
		return nil
	end
	local level = settings.SavedQualityLevel
	if level == Enum.SavedQualitySetting.Automatic then
		return nil
	end
	return level.Value -- QualityLevel1..10 have Value 1..10
end

function OceanQuality.current(): Tier
	local level = savedLevel()
	if level == nil then
		-- Automatic: phones and tablets get Medium, everything else High. -- tune
		local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		return if touchOnly then OceanQuality.TIERS.Medium else OceanQuality.TIERS.High
	elseif level <= 3 then
		return OceanQuality.TIERS.Low
	elseif level <= 7 then
		return OceanQuality.TIERS.Medium
	end
	return OceanQuality.TIERS.High
end

-- Calls back when the player changes graphics quality. Returns the connection (or nil).
function OceanQuality.onChanged(callback: () -> ()): RBXScriptConnection?
	local settings = userGameSettings()
	if not settings then
		return nil
	end
	return settings:GetPropertyChangedSignal("SavedQualityLevel"):Connect(callback)
end

return OceanQuality
