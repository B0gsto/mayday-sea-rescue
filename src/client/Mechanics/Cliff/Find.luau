--!strict
-- Cliff/Find: what the cliff mechanics read from the live scene: the anchor stake, the casualty
-- model (Workspace.CallProps "Victim", CallId = the operation id) and the nearest boat.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CliffRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CliffRules"))

local Find = {}

function Find.root(): BasePart?
	local char = Players.LocalPlayer.Character
	local r = char and char:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

function Find.humanoid(): Humanoid?
	local char = Players.LocalPlayer.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

function Find.anchor(): BasePart?
	for _, inst in CollectionService:GetTagged("CliffRopeAnchor") do
		if inst:IsA("BasePart") and inst.Parent then
			return inst
		end
	end
	local folder = Workspace:FindFirstChild("CallProps")
	local found = folder and folder:FindFirstChild("CliffRopeAnchor", true)
	if found and found:IsA("BasePart") then
		return found
	end
	return nil
end

function Find.victim(ctx: { [string]: any }): Model?
	local folder = Workspace:FindFirstChild("CallProps")
	if not folder then
		return nil
	end
	local opId = ctx.operation and ctx.operation.id
	local near = ctx.casualty and ctx.casualty.position
	local best: Model?, bestD = nil, math.huge
	for _, m in folder:GetChildren() do
		if
			m:IsA("Model")
			and m.Name == "Victim"
			and m:GetAttribute("CallId") == opId
			and m.PrimaryPart
		then
			local d = if typeof(near) == "Vector3"
				then (m.PrimaryPart.Position - near).Magnitude
				else 0
			if d < bestD then
				best, bestD = m, d
			end
		end
	end
	return best
end

function Find.casualtyPoint(ctx: { [string]: any }, victim: Model?): Vector3
	if victim and victim.PrimaryPart and victim.PrimaryPart.Parent then
		return victim.PrimaryPart.Position
	end
	local p = ctx.casualty and ctx.casualty.position
	return if typeof(p) == "Vector3" then p else CliffRules.SITE.foot
end

-- The player's boat (even after stepping off it) nearest to `at`, within `range` studs.
function Find.boat(ctx: { [string]: any }, at: Vector3, range: number?): Model?
	local direct = ctx.vehicle
	if typeof(direct) == "Instance" and direct:IsA("Model") and direct.Parent then
		return direct
	end
	local folder = Workspace:FindFirstChild("Vehicles")
	if not folder then
		return nil
	end
	local best: Model?, bestD = nil, range or math.huge
	for _, m in folder:GetChildren() do
		if m:IsA("Model") and m:GetAttribute("VehicleId") ~= nil and m.PrimaryPart then
			local d = CliffRules.flatDistance(m.PrimaryPart.Position, at)
			if d < bestD then
				best, bestD = m, d
			end
		end
	end
	return best
end

function Find.prompt(parent: BasePart, action: string, hold: number): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = "Cliff"
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

return Find
