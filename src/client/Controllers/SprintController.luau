--!strict
-- SprintController: run on foot. Hold Shift (keyboard) or click the left stick (gamepad, toggles); on touch
-- the thumbstick pushed all the way runs. Only swaps the base walk speed (WorldService 12) for SPRINT, so
-- freezes (WalkSpeed 0: tablet, build mode) and the DEV walk override are left alone. While running on the
-- ground a run track fades in over the Animate script's walk/run (jumps and falls keep their own poses).
-- Also keeps the Animate script's walk/run/idle on Roblox catalog pack clips (LOCO); re-set every frame since
-- the server's ApplyDescriptionAsync (Outfits) rewrites them from the avatar's own packs.
-- Sprint beats: the push-off leans the chest in with a dust kick off the back foot (sprint_kick) and sets the
-- player's SprintKick attribute (CameraController's short FOV push); a stop from a sprint brakes: the stride slows
-- out, the chest leans back, dust skids off the front foot (sprint_brake). Reduce motion keeps only the sounds.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Comfort = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("Comfort"))
local VFXKit = require(script.Parent.Parent:WaitForChild("VFX"):WaitForChild("VFXKit"))

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
-- chest lean pulses (Waist joint, radians: negative leans in): peak, seconds to the peak, seconds back to upright
local KICK_LEAN = { -0.26, 0.1, 0.4 }
local BRAKE_LEAN = { 0.22, 0.08, 0.3 }

-- 0 -> 1 fast (out cubic), then back to 0 (smoothstep)
local function pulse(spec: { number }, t: number): number
	local amp, rise, fall = spec[1], spec[2], spec[3]
	if t < 0 or t > rise + fall then
		return 0
	elseif t < rise then
		return amp * (1 - (1 - t / rise) ^ 3)
	end
	local k = (t - rise) / fall
	return amp * (1 - k * k * (3 - 2 * k))
end

local SprintController = {}

function SprintController.Start()
	local player = Players.LocalPlayer
	local held = false -- Shift held / L3 toggled on
	local runAnim = Instance.new("Animation")
	runAnim.AnimationId = RUN_ANIM
	local track: AnimationTrack? = nil
	local trackHum: Humanoid? = nil
	local animator: Animator? = nil
	local lean: { number }? = nil -- the lean pulse playing, and when it started
	local leanAt = 0
	local leanWrote: CFrame? = nil -- the Waist Transform this wrote last frame (a joint no track keys keeps it)
	local leanBase = CFrame.identity

	-- dust off the foot furthest back (kick) or forward (brake), fired back / forward and up; sound-only under
	-- Reduce motion
	local function beat(char: Model, root: BasePart, name: string, spec: { number })
		lean, leanAt = spec, os.clock()
		local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
		local sign = if name == "sprint_kick" then -1 else 1
		local foot: BasePart? = nil
		for _, n in { "LeftFoot", "RightFoot" } do
			local f = char:FindFirstChild(n)
			if
				f
				and f:IsA("BasePart")
				and (not foot or sign * f.Position:Dot(look) > sign * foot.Position:Dot(look))
			then
				foot = f
			end
		end
		local at = if foot
			then foot.Position - Vector3.new(0, foot.Size.Y / 2, 0)
			else root.Position
		local up = (look * sign + Vector3.yAxis * 0.5).Unit
		VFXKit.play(name, CFrame.fromMatrix(at, root.CFrame.RightVector, up), {
			scale = if Comfort.reducedMotion() then 0 else 1,
		})
		if name == "sprint_kick" then
			player:SetAttribute("SprintKick", os.clock())
		end
	end

	-- after the Animator: the lean pulse turns the Waist on top of the playing pose
	RunService.PreSimulation:Connect(function()
		local char = player.Character
		local torso = char and char:FindFirstChild("UpperTorso")
		local waist: any = torso and torso:FindFirstChild("Waist")
		if not waist or not (waist:IsA("Motor6D") or waist:IsA("AnimationConstraint")) then
			return
		end
		local now: CFrame = waist.Transform
		if leanWrote and now == leanWrote then
			now = leanBase -- no track keyed the waist this frame: turn from the pose, not from last frame's turn
		end
		leanBase = now
		local a = if lean and not Comfort.reducedMotion()
			then pulse(lean, os.clock() - leanAt)
			else 0
		if a == 0 then
			leanWrote = nil
			return
		end
		leanWrote = now * CFrame.Angles(a, 0, 0)
		waist.Transform = leanWrote
	end)

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
		local root = hum.RootPart
		if running and not t.IsPlaying then
			local base = locoTracks()[1]
			t:Play(FADE)
			if base and base.Length > 0 and t.Length > 0 then
				t.TimePosition = ((base.TimePosition / base.Length + RUN_PHASE) % 1) * t.Length
			end
			-- a push-off from a walk or a stand, not a landing mid-sprint (already at speed)
			if
				root
				and char
				and (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude < SPRINT - 3
			then
				beat(char, root, "sprint_kick", KICK_LEAN)
			end
		elseif not running and t.IsPlaying then
			if moving < 0.05 and hum.FloorMaterial ~= Enum.Material.Air and root and char then
				-- brake: the stride slows out under the idle (a planted step), not a run frozen mid-air
				t:AdjustSpeed(0.35)
				t:Stop(0.3)
				beat(char, root, "sprint_brake", BRAKE_LEAN)
			else
				if t.Length > 0 then
					local phase = (t.TimePosition / t.Length - RUN_PHASE) % 1
					for _, tr in locoTracks() do
						tr.TimePosition = phase * tr.Length
					end
				end
				t:Stop(FADE)
			end
		end
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
