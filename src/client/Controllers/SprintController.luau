--!strict
-- SprintController: run on foot. Hold Shift (keyboard) or click the left stick (gamepad, toggles); on touch
-- the thumbstick pushed all the way runs. Only swaps the base walk speed (WorldService 12) for SPRINT, so
-- freezes (WalkSpeed 0: tablet, build mode) and the DEV walk override are left alone.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local WALK = 12 -- StarterPlayer.CharacterWalkSpeed (WorldService)
local SPRINT = 20

local SprintController = {}

function SprintController.Start()
	local player = Players.LocalPlayer
	local held = false -- Shift held / L3 toggled on

	ContextActionService:BindAction(
		"Sprint",
		function(_, state: Enum.UserInputState, input: InputObject)
			if input.KeyCode == Enum.KeyCode.ButtonL3 then
				if state == Enum.UserInputState.Begin then
					held = not held
				end
			else
				held = state == Enum.UserInputState.Begin
			end
			return Enum.ContextActionResult.Pass
		end,
		false,
		Enum.KeyCode.LeftShift,
		Enum.KeyCode.RightShift,
		Enum.KeyCode.ButtonL3
	)
	UserInputService.WindowFocusReleased:Connect(function()
		held = false
	end)

	RunService.Heartbeat:Connect(function()
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.SeatPart then
			return
		end
		local moving = hum.MoveDirection.Magnitude
		if moving < 0.05 then
			held = held and UserInputService:GetLastInputType() ~= Enum.UserInputType.Gamepad1 -- L3 run ends on stop
		end
		local touchRun = UserInputService:GetLastInputType() == Enum.UserInputType.Touch
			and moving > 0.95
		local want = if held or touchRun then SPRINT else WALK
		if (hum.WalkSpeed == WALK or hum.WalkSpeed == SPRINT) and hum.WalkSpeed ~= want then
			hum.WalkSpeed = want
		end
	end)
end

return SprintController
