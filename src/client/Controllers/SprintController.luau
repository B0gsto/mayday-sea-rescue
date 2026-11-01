--!strict
-- SprintController: run on foot. Hold Shift (keyboard) or click the left stick (gamepad, toggles); on touch
-- the thumbstick pushed all the way runs. Only swaps the base walk speed (WorldService 12) for SPRINT, so
-- freezes (WalkSpeed 0: tablet, build mode) and the DEV walk override are left alone. While running on the
-- ground a run track fades in over the Animate script's walk/run (jumps and falls keep their own poses).
-- Also keeps the Animate script's walk/run/idle on Roblox catalog pack clips (LOCO); re-set every frame since
-- the server's ApplyDescriptionAsync (Outfits) rewrites them from the avatar's own packs.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local WALK = 12 -- StarterPlayer.CharacterWalkSpeed (WorldService)
local SPRINT = 20
local RUN_ANIM = "rbxassetid://18537384940" -- adidas Sports Animation Pack run (Roblox catalog)
-- Animate folder -> clip (Cartoony Animation Package, Roblox catalog). Natural ground speeds at HipHeight 2, by FK
-- on the clips (the stock walk/run measure the Animate script's 6.4/12.8 the same way): walk ~8, run ~12.5 studs/s.
-- At WalkSpeed 12 Animate plays ~88% run at speed 1 (it assumes 12.8), so the feet hold the ground; the walk clip
-- there (it was both) covered ~8 studs/s and slid.
local LOCO: { [string]: string } = {
	walk = "rbxassetid://10921082452",
	run = "rbxassetid://10921076136",
	idle = "rbxassetid://10921071918",
	idle2 = "rbxassetid://10921072875", -- Animate's idle Animation2 (the rarer look-around)
}
local RUN_PACE = 23.5 -- studs/s the adidas run covers at speed 1 (FK, as above; it was taken as 12.8: feet at 1.8x the ground)
local RUN_PHASE = 0.04 -- its left-foot plant comes this much of a cycle after the Cartoony run's (both clips' FK)
local FADE = 0.2 -- s, walk <-> sprint
local STEP_PITCH = 1.85 / 3.08 -- RbxCharacterSounds' Running loop: PlaybackSpeed 1.85 = 3.08 steps/s (the Cartoony run's 3.0)

local SprintController = {}

function SprintController.Start()
	local player = Players.LocalPlayer
	local held = false -- Shift held / L3 toggled on
	local runAnim = Instance.new("Animation")
	runAnim.AnimationId = RUN_ANIM
	local track: AnimationTrack? = nil
	local trackHum: Humanoid? = nil
	local animator: Animator? = nil

	-- Animate's walk + run tracks (both 0.667 s, kept in step by Animate): the sprint starts and ends on their phase
	local function locoTracks(): { AnimationTrack }
		local out = {}
		if not animator then
			return out
		end
		for _, tr in animator:GetPlayingAnimationTracks() do
			local id = tr.Animation and tr.Animation.AnimationId
			if id == LOCO.walk or id == LOCO.run then
				table.insert(out, tr)
			end
		end
		return out
	end

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
			animator = hum:FindFirstChildOfClass("Animator")
			if not animator then
				return
			end
			track = (animator :: Animator):LoadAnimation(runAnim)
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
			local base = locoTracks()[1]
			t:Play(FADE)
			if base and base.Length > 0 and t.Length > 0 then
				t.TimePosition = ((base.TimePosition / base.Length + RUN_PHASE) % 1) * t.Length
			end
		elseif not running and t.IsPlaying then
			if t.Length > 0 then
				local phase = (t.TimePosition / t.Length - RUN_PHASE) % 1
				for _, tr in locoTracks() do
					tr.TimePosition = phase * tr.Length
				end
			end
			t:Stop(FADE)
		end
		local root = hum.RootPart
		if running and root then
			-- stride matched to ground speed (and leg length, as Animate scales by HipHeight)
			local flat = math.clamp(
				(root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude,
				WALK,
				SPRINT
			)
			t:AdjustSpeed(flat / (RUN_PACE * math.max(hum.HipHeight, 0.5) / 2))
		end
		local step: any = root and root:FindFirstChild("Running")
		if step and (step:IsA("Sound") or step:IsA("AudioPlayer")) then
			-- footsteps on the sprint's stride (2 plants per cycle); else the stock rate, which fits the jog
			local rate = if running and t.Length > 0 then 2 * t.Speed / t.Length else 3.08
			step.PlaybackSpeed = rate * STEP_PITCH
		end
	end)
end

return SprintController
