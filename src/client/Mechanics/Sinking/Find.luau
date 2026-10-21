--!strict
-- Sinking/Find: what the sinking-vessel mechanics read from the live scene (the hull, the pump,
-- the leak and the crew on the cabin roof) and the world prompts they add. Client-only.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Find = {}

function Find.root(): BasePart?
	local char = Players.LocalPlayer.Character
	local r = char and char:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

function Find.scene(ctx: { [string]: any }): Folder?
	local props = Workspace:FindFirstChild("CallProps")
	if not props then
		return nil
	end
	local opId = ctx.operation and ctx.operation.id
	if typeof(opId) == "string" then
		local exact = props:FindFirstChild(`Sinking_{opId}`)
		if exact and exact:IsA("Folder") then
			return exact
		end
	end
	local near = ctx.operation and ctx.operation.position
	local best: Folder?, bestD = nil, math.huge
	for _, child in props:GetChildren() do
		if child:IsA("Folder") and string.sub(child.Name, 1, 8) == "Sinking_" then
			local boat = child:FindFirstChild("SinkingBoat")
			local at = boat and boat:IsA("Model") and boat.PrimaryPart
			local d = if at and typeof(near) == "Vector3" then (at.Position - near).Magnitude else 0
			if d < bestD then
				best, bestD = child, d
			end
		end
	end
	return best
end

function Find.part(scene: Folder?, name: string): BasePart?
	local found = scene and scene:FindFirstChild(name, true)
	return if found and found:IsA("BasePart") then found else nil
end

function Find.boat(scene: Folder?): Model?
	local found = scene and scene:FindFirstChild("SinkingBoat")
	return if found and found:IsA("Model") then found else nil
end

-- The crew still on the roof: models tagged with the Crew attribute.
function Find.crew(scene: Folder?): { Model }
	local out = {}
	if not scene then
		return out
	end
	for _, child in scene:GetDescendants() do
		if child:IsA("Model") and child:GetAttribute("Crew") == true and child.PrimaryPart then
			table.insert(out, child)
		end
	end
	return out
end

function Find.prompt(parent: BasePart, action: string, hold: number): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = "Morwenna's Pride"
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

return Find
