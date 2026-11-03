--!strict
-- TelemetryController: reports the device type, when the world is on screen and the average frame rate
-- (SessionEnd / SessionPerf / InputDead fields on the server). The other client facts are one-line hooks.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VRService = game:GetService("VRService")

local Telemetry = require(script.Parent.Parent:WaitForChild("Telemetry"))

local TelemetryController = {}

local FPS_FIRST = 5 -- s: early, so sessions that quit in seconds still report a frame rate
local FPS_EVERY = 30 -- s between reports; the server keeps the latest and logs it once, at session end

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
	local player = Players.LocalPlayer
	task.spawn(function()
		while player:GetAttribute("LoadingScreenActive") == true do
			player:GetAttributeChangedSignal("LoadingScreenActive"):Wait()
		end
		Telemetry.once("WorldReady")
	end)
	local frames, seconds = 0, 0
	RunService.Heartbeat:Connect(function(dt: number)
		if dt < 1 then -- a longer frame is the app in the background on a phone, not its frame rate
			frames += 1
			seconds += dt
		end
	end)
	task.spawn(function()
		task.wait(FPS_FIRST)
		while true do
			if seconds > 0 then
				Telemetry.send("Fps", math.round(frames / seconds) :: any)
			end
			task.wait(FPS_EVERY)
		end
	end)
end

return TelemetryController
