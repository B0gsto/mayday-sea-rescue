--!strict
-- SprintController: run on foot. Hold Shift (keyboard) or click the left stick (gamepad, toggles); on touch
-- the thumbstick pushed all the way runs. Only swaps the base walk speed (WorldService 18) for SPRINT, so
-- freezes (WalkSpeed 0: tablet, build mode) and the DEV walk override are left alone. While running on the
-- ground a run track fades in over the Animate script's walk/run (jumps and falls keep their own poses).
-- Also keeps the Animate script's walk/run/idle on Roblox catalog pack clips (LOCO); re-set every frame since
-- the server's ApplyDescriptionAsync (Outfits) rewrites them from the avatar's own packs.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local WALK = 18 -- StarterPlayer.CharacterWalkSpeed (WorldService)
local SPRINT = 30 -- owner 2026-11-01: 1.5x (was 20)
local RUN_ANIM = "rbxassetid://18537384940" -- adidas Sports Animation Pack run (Roblox catalog)
-- Animate folder -> clip (Cartoony Animation Package, Roblox catalog); walk and run share the walk clip: at WalkSpeed 12 the Animate script blends mostly
-- into "run", and running is the sprint track's job
local LOCO: { [string]: string } = {
	walk = "rbxassetid://10921082452",
	run = "rbxassetid://10921082452",
	idle = "rbxassetid://10921071918",
	idle2 = "rbxassetid://10921072875", -- Animate's idle Animation2 (the rarer look-around)
}
local RUN_PACE = 12.8 -- studs/s a run clip covers at speed 1 (the default Animate script's figure: 2x its walk)

local SprintController = {}

function SprintController.Start()
	local player = Players.LocalPlayer
	local held = false -- Shift held / L3 toggled on
	local runAnim = Instance.new("Animation")
	runAnim.AnimationId = RUN_ANIM
	local track: AnimationTrack? = nil
	local trackHum: Humanoid? = nil

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
		local animate = char and char:FindFirstChild("Animate")
		if animate then
			for _, folder in animate:GetChildren() do
				for _, a in if LOCO[folder.Name] then folder:GetChildren() else {} do
					local want = LOCO[if a.Name == "Animation2" then "idle2" else folder.Name]
					if a:IsA("Animation") and a.AnimationId ~= want then
						a.AnimationId = want
					end
				end
			end
		end
		if not hum or hum.SeatPart then
			if track and track.IsPlaying then
				track:Stop(0.2)
			end
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
		if trackHum ~= hum then
			local animator = hum:FindFirstChildOfClass("Animator")
			if not animator then
				return
			end
			track = animator:LoadAnimation(runAnim)
			trackHum = hum
			local t = track :: AnimationTrack
			t.Priority = Enum.AnimationPriority.Movement
			t.Looped = true
		end
		local t = track :: AnimationTrack
		local state = hum:GetState()
		local running = hum.WalkSpeed == SPRINT
			and moving > 0.05
			and hum.FloorMaterial ~= Enum.Material.Air
			and (
				state == Enum.HumanoidStateType.Running
				or state == Enum.HumanoidStateType.RunningNoPhysics
			)
		if running and not t.IsPlaying then
			t:Play(0.25)
			t:AdjustSpeed(SPRINT / RUN_PACE)
		elseif not running and t.IsPlaying then
			t:Stop(0.25)
		end
	end)
end

return SprintController
