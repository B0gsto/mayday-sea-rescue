--!strict
-- cliff_recover (docs/09 section 8.5): get them off the ledge. With the boat lying alongside,
-- take them and carry them aboard. Otherwise clip them to the line, climb to the anchor and haul
-- with both hands (alternate clicks / LB+RB / the two pads). The boat in the water is the cue:
-- there is no menu. The server applies the result (CliffScene.Recovered).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Client = script.Parent.Parent.Parent
local CliffRules =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("CliffRules"))
local Find = require(script.Parent:WaitForChild("Find"))
local Radio = require(Client:WaitForChild("Controllers"):WaitForChild("RadioController"))
local Step = require(script.Parent.Parent:WaitForChild("PIW"):WaitForChild("Step"))
local Ui = require(script.Parent.Parent:WaitForChild("PIW"):WaitForChild("Ui"))

local Recover = {}

Recover.CLIMB_SECONDS = 2.5
Recover.CARRY_LIMIT = 60 -- s before the carry gives up (the step's own timeout is longer)

-- Moves the character along the line to `to`; calls done() at the end. Returns a cancel function.
local function ride(to: Vector3, seconds: number, done: () -> ()): () -> ()
	local character = Players.LocalPlayer.Character
	local from = Find.root()
	if not character or not from then
		return function() end
	end
	local humanoid = Find.humanoid()
	if humanoid then
		humanoid.PlatformStand = true
	end
	local start = from.CFrame
	local target = CFrame.lookAt(to, to + Vector3.new(0, 0, 12))
	local t0 = os.clock()
	local finished = false
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function()
		if finished or not character.Parent then
			return
		end
		local a = math.clamp((os.clock() - t0) / seconds, 0, 1)
		local p = start.Position:Lerp(target.Position, a)
		character:PivotTo(CFrame.lookAt(p, target.Position + target.LookVector))
		if a >= 1 then
			finished = true
			if conn then
				conn:Disconnect()
			end
			if humanoid then
				humanoid.PlatformStand = false
			end
			done()
		end
	end)
	return function()
		finished = true
		if conn then
			conn:Disconnect()
		end
		if humanoid then
			humanoid.PlatformStand = false
		end
	end
end

function Recover.start(
	ctx: { [string]: any },
	finish: (result: { [string]: any }) -> ()
): (() -> ())?
	local s = Step.new(ctx, finish, "CliffRecover", 150)
	if Step.autoStub(s, { method = "line", score = 1 }) then
		return Step.cleanup(s)
	end
	local root = Find.root()
	if not root then
		return Step.cleanup(s)
	end
	local victim = Find.victim(ctx)
	local at = Find.casualtyPoint(ctx, victim)
	local boat = Find.boat(ctx, at, 200)
	local boatDistance = if boat and boat.PrimaryPart
		then CliffRules.flatDistance(boat.PrimaryPart.Position, at)
		else nil
	local route = CliffRules.routeFor(root.Position, boatDistance)
	local victimPart = victim and victim.PrimaryPart
	local carrying = false
	local carryingFrom = 0
	local hauling = false
	local cleanupRide: (() -> ())? = nil

	-- The carry ends when the casualty is actually aboard: inside the boat's deck bounds, not
	-- merely alongside it (a flat-distance check finished the carry from the water).
	local function casualtyAboard(): boolean
		if not (boat and boat.Parent and boat.PrimaryPart) then
			return false
		end
		if not (victim and victim.Parent and victim.PrimaryPart) then
			return false
		end
		local hull = boat.PrimaryPart
		local speed = hull.AssemblyLinearVelocity.Magnitude
		return speed < CliffRules.BOAT_SPEED
			and CliffRules.onDeck(victim.PrimaryPart.Position, hull.CFrame, hull.Size)
	end

	local function startHaul()
		if hauling then
			return
		end
		hauling = true
		Step.line(s, "Haul · alternate hands", 54)
		local haul = CliffRules.newHaul(nil, ctx.operation.storm == true)
		local setMeter = Ui.meter(s.panel, "Line", UDim2.fromOffset(12, 76), 436)
		local from = CliffRules.SITE.foot
		local to = CliffRules.SITE.top
		local function place()
			if not (victim and victim.PrimaryPart) then
				return
			end
			local a = math.clamp(haul.done / haul.total, 0, 1)
			local p = from:Lerp(to, a)
			victim:PivotTo(CFrame.lookAt(p + Vector3.new(0, 0.2, 0), p + Vector3.new(0, 0.2, 10)))
		end
		local function tap(hand: string)
			if CliffRules.complete(haul) then
				return
			end
			local counted = CliffRules.pull(haul, hand)
			if counted then
				Ui.hands(if hand == "L" then "haul_left" else "haul_right")
			end
			setMeter(haul.done / haul.total, 0.6, 1)
			place()
			if CliffRules.complete(haul) then
				Ui.handsStop()
				Radio.say("cliff_recovered")
				Step.finish(s, {
					metrics = { method = "line", score = CliffRules.haulScore(haul) },
				})
			end
		end
		Ui.pads(s.bag, s.panel, tap)
	end

	local function climbThenHaul()
		if root.Position.Y > CliffRules.SITE.top.Y - 30 then
			startHaul()
			return
		end
		Step.line(s, "Climb to the anchor", 54)
		cleanupRide =
			ride(CliffRules.SITE.top + Vector3.new(0, 3, 4), Recover.CLIMB_SECONDS, startHaul)
		Ui.add(s.bag, cleanupRide)
	end

	local function carry()
		carrying = true
		carryingFrom = os.clock()
		Step.line(s, "To the boat", 54)
		Ui.hands("drag", { loop = true })
	end

	-- The casualty is the world action: carry when the boat is alongside, else clip to the line.
	if victimPart then
		local prompt = Ui.add(s.bag, Find.prompt(victimPart, "Take them", 0.5))
		prompt.Triggered:Connect(function()
			if carrying or hauling or cleanupRide then
				return
			end
			prompt.Enabled = false
			if route == "boat" then
				carry()
			else
				climbThenHaul()
			end
		end)
	else
		local stand = Instance.new("Part")
		stand.Name = "CliffCasualtyPoint"
		stand.Anchored, stand.CanCollide, stand.CanQuery = true, false, false
		stand.Transparency = 1
		stand.Size = Vector3.one
		stand.Position = at
		stand.Parent = game:GetService("Workspace")
		Ui.add(s.bag, stand)
		local prompt = Ui.add(s.bag, Find.prompt(stand, "Take them", 0.5))
		prompt.Triggered:Connect(climbThenHaul)
	end

	-- From the top the line is always ready (the crew clipped them on below).
	local anchor = Find.anchor()
	if anchor then
		local haulPrompt = Ui.add(s.bag, Find.prompt(anchor, "Haul", 0.4))
		haulPrompt.Triggered:Connect(function()
			if not carrying then
				startHaul()
			end
		end)
	end

	Step.heartbeat(s, function()
		if not carrying then
			return
		end
		local r = Find.root()
		if not r then
			return
		end
		if victim and victim.Parent then
			local look = r.CFrame.LookVector
			local p = Vector3.new(r.Position.X, r.Position.Y - 2.5, r.Position.Z) + look * 2.5
			victim:PivotTo(CFrame.lookAt(p, p + look))
		end
		if casualtyAboard() then
			Ui.handsStop()
			Radio.say("cliff_recovered")
			Step.finish(s, {
				metrics = {
					method = "boat",
					score = CliffRules.carryScore(
						os.clock() - carryingFrom,
						ctx.operation.storm == true
					),
				},
			})
		elseif os.clock() - carryingFrom > Recover.CARRY_LIMIT then
			carrying = false
			Ui.handsStop()
			Step.finish(s, { failed = true })
		end
	end)
	return Step.cleanup(s)
end

return Recover
