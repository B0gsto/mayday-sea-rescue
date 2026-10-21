--!strict
-- OceanQuality: picks the ocean grid tier from the player's graphics quality setting
-- (UserGameSettings.SavedQualityLevel), or the settings panel's override (Comfort "oceanQuality":
-- "Auto" follows the Roblox slider). Tiers follow docs/06 section 3.1 (numbers are -- tune).
--
-- Each tier is two rings around the camera:
--   near patch: nearCells x nearCells cells of nearCell studs (full detail, exact at vertices)
--   outer ring: outerCells x outerCells cells of outerCell studs with a holeCells x holeCells hole
--               that the near patch fills exactly (nearCells * nearCell == holeCells * outerCell)
-- The whole system snaps in outerCell steps (a whole multiple of nearCell), so no vertex ever
-- slides. updateHz = 0 means every frame.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Comfort = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("Comfort"))
local SettingsRules =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SettingsRules"))

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

-- Vertex counts: High 1089 near + 576 ring; Medium 625 + 392; Low 121 + 264.
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
		nearCells = 10,
		nearCell = 12,
		outerCells = 16,
		outerCell = 20,
		holeCells = 6,
		updateHz = 12,
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
	-- Studio perf runs (RP-P1) force a tier through Workspace.PerfQuality; never read outside Studio.
	if RunService:IsStudio() then
		local forced = Workspace:GetAttribute("PerfQuality")
		if forced == "High" or forced == "Medium" or forced == "Low" then
			return OceanQuality.TIERS[forced] or OceanQuality.TIERS.High
		end
	end
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local name = SettingsRules.qualityTier(Comfort.get("oceanQuality"), savedLevel(), touchOnly)
	return OceanQuality.TIERS[name] or OceanQuality.TIERS.High
end

-- Calls back when the player changes graphics quality (the Roblox slider or the settings
-- panel's ocean override). Returns the slider connection (or nil).
function OceanQuality.onChanged(callback: () -> ()): RBXScriptConnection?
	Comfort.changed:Connect(function(key: string)
		if key == "oceanQuality" then
			callback()
		end
	end)
	if RunService:IsStudio() then
		Workspace:GetAttributeChangedSignal("PerfQuality"):Connect(callback)
	end
	local settings = userGameSettings()
	if not settings then
		return nil
	end
	return settings:GetPropertyChangedSignal("SavedQualityLevel"):Connect(callback)
end

return OceanQuality
