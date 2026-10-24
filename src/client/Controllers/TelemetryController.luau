--!strict
-- TelemetryController: reports the device type once per session (SessionEnd / InputDead fields on the
-- server; docs/research/analytics.md). Nothing else: the other client facts are one-line hooks.
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local VRService = game:GetService("VRService")

local Telemetry = require(script.Parent.Parent:WaitForChild("Telemetry"))

local TelemetryController = {}

local function device(): string
	if VRService.VREnabled then
		return "VR"
	elseif GuiService:IsTenFootInterface() then
		return "Console"
	elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Touch"
	elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "Gamepad"
	end
	return "Keyboard"
end

function TelemetryController.Start()
	Telemetry.send("Device", device())
end

return TelemetryController
