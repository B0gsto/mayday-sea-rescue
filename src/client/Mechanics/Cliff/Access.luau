--!strict
-- cliff_access (docs/09 section 8.5): reach the casualty. From the cliff top, take the line at
-- the anchor and lower yourself down the face (hold E / tap / X); from the boat, step ashore at
-- the foot and the step is already done. No choice is offered: the world (anchor, line, waving
-- casualty) says which is which.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Client = script.Parent.Parent.Parent
local CliffRules =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("CliffRules"))
local Find = require(script.Parent:WaitForChild("Find"))
local Radio = require(Client:WaitForChild("Controllers"):WaitForChild("RadioController"))
local Step = require(script.Parent.Parent:WaitForChild("PIW"):WaitForChild("Step"))
local Ui = require(script.Parent.Parent:WaitForChild("PIW"):WaitForChild("Ui"))

local Access = {}

Access.LOWER_SECONDS = 3

-- Moves the character down the line from the top to the foot; returns a cancel function.
local function lower(s: Step.S): () -> ()
	local character = Players.LocalPlayer.Character
	local from = Find.root()
	if not character or not from then
		return function() end
	end
	local humanoid = Find.humanoid()
	if humanoid then
		humanoid.PlatformStand = true
	end
	local target = CFrame.lookAt(
		CliffRules.SITE.foot + Vector3.new(0, 3, 0),
		CliffRules.SITE.foot + Vector3.new(0, 3, 12)
	)
	local start = from.CFrame
	local t0 = os.clock()
	local done = false
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function()
		if done or not character.Parent then
			return
		end
		local a = math.clamp((os.clock() - t0) / Access.LOWER_SECONDS, 0, 1)
		local p = start.Position:Lerp(target.Position, a)
		character:PivotTo(CFrame.lookAt(p, target.Position + target.LookVector))
		if a >= 1 then
			done = true
			if conn then
				conn:Disconnect()
			end
			if humanoid then
				humanoid.PlatformStand = false
			end
			Step.finish(s, { metrics = { lower = 1 } })
		end
	end)
	return function()
		done = true
		if conn then
			conn:Disconnect()
		end
		if humanoid then
			humanoid.PlatformStand = false
		end
	end
end

function Access.start(
	ctx: { [string]: any },
	finish: (result: { [string]: any }) -> ()
): (() -> ())?
	local s = Step.new(ctx, finish, "CliffAccess", 110)
	if Step.autoStub(s, { lower = 1 }) then
		return Step.cleanup(s)
	end
	Radio.say("cliff_sighted")
	local root = Find.root()
	local atFoot = root
		and CliffRules.near(root.Position, CliffRules.SITE.foot, CliffRules.FOOT_RADIUS)
	if atFoot then
		if root and root.Position.Y < CliffRules.SITE.foot.Y - 8 then
			-- arrived by sea: swim in and climb ashore onto the ledge
			Step.line(s, "Climb ashore", 54)
			s.say('Crew: "Cliff foot. Climbing up."', 3)
			Ui.add(s.bag, lower(s))
			return Step.cleanup(s)
		end
		Step.line(s, "On scene", 54)
		s.say('Crew: "With you."', 2)
		task.delay(1, function()
			Step.finish(s, { metrics = { lower = 0 } })
		end)
		return Step.cleanup(s)
	end
	local anchor = Find.anchor()
	if not anchor then
		Step.line(s, "Find the anchor", 54)
		return Step.cleanup(s)
	end
	Step.line(s, "Hold to lower", 54)
	local prompt = Ui.add(s.bag, Find.prompt(anchor, "Lower", 0.3))
	local cleanupLower: (() -> ())? = nil
	prompt.Triggered:Connect(function()
		if cleanupLower then
			return
		end
		prompt.Enabled = false
		s.say('Crew: "On the line. Down we go."', 3)
		Ui.hands("haul_left", { loop = true })
		cleanupLower = lower(s)
		Ui.add(s.bag, cleanupLower)
	end)
	Ui.add(s.bag, function()
		Ui.handsStop()
	end)
	return Step.cleanup(s)
end

return Access
