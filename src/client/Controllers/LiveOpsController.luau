--!strict
-- LiveOpsController: the client side of owner-triggered events (G60). Reads
-- ReplicatedStorage.LiveOpsState (LiveOpsService) and shows a subtle sky tint while it runs (a
-- separate ColorCorrectionEffect, so weather still owns the atmosphere). The countdown and name
-- are the LiveOps row of the phone's Events app (EventCalendar), not a HUD chip.
-- Nothing to press and no menu: the event is a world change (docs/15 section 1, CLAUDE.md).
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveOps = require(Shared:WaitForChild("LiveOps"))

local TICK = 0.2
local FOLDER_NAME = "LiveOpsState"

local LiveOpsController = {}
LiveOpsController.Priority = 111

local folder: Folder? = nil

local function attr(name: string, default: any): any
	local state = folder
	if not state then
		return default
	end
	local value = state:GetAttribute(name)
	return if value == nil then default else value
end

local function tintFor(event: string): Color3?
	local def = LiveOps.Events[event]
	return if def then def.tint else nil
end

function LiveOpsController.Init()
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, 30)
end

function LiveOpsController.Start()
	if not folder then
		return
	end
	local tint: ColorCorrectionEffect? = nil
	local existing = Lighting:FindFirstChild("LiveOpsTint")
	if existing and existing:IsA("ColorCorrectionEffect") then
		tint = existing
	else
		local effect = Instance.new("ColorCorrectionEffect")
		effect.Name = "LiveOpsTint"
		effect.Enabled = false
		effect.Brightness = 0.01
		effect.Contrast = 0.02
		effect.Saturation = 0.04
		effect.Parent = Lighting
		tint = effect
	end

	while true do
		local event = attr("Event", "") :: string
		local phase = attr("Phase", "") :: string
		local effect = tint
		if effect then
			local colour = if phase == "Active" then tintFor(event) else nil
			effect.Enabled = colour ~= nil
			if colour then
				effect.TintColor = colour
			end
		end
		task.wait(TICK)
	end
end

return LiveOpsController
