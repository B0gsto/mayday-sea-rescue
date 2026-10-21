--!strict
-- lighthouse_crank: the lighthouse mission's world action (G67). The player walks up to the
-- tower, holds the crank (E / gamepad X / touch hold: a ProximityPrompt), and the optic turns.
-- One hold relights the light; the server records `cranks = 1`. The crank is built from the
-- light's model pivot (ATT_Light's tower) or its catalogue position, so it sits on the tower.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Lighthouses = require(Shared:WaitForChild("Lighthouses"))
local Step = require(script.Parent.PIW.Step)
local Ui = require(script.Parent.PIW.Ui)

local Mech = {}

Mech.HOLD = 3 -- seconds on the crank
Mech.TURN = 1.2 -- seconds for the optic to come round

local function modelFor(id: string): Model?
	for _, model in CollectionService:GetTagged("Lighthouse") do
		if model:IsA("Model") and model:GetAttribute("LightId") == id then
			return model
		end
	end
	for _, model in CollectionService:GetTagged("HarbourLight") do
		if model:IsA("Model") then
			local modelId = model:GetAttribute("LightId")
			if modelId == nil or modelId == id then
				return model
			end
		end
	end
	return nil
end

local function crankPart(parent: Instance, name: string, size: Vector3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Material = Enum.Material.Metal
	p.Color = Color3.fromRGB(92, 96, 100)
	p.Parent = parent
	return p
end

function Mech.start(ctx: { [string]: any }, finish: (result: { [string]: any }) -> ()): (() -> ())?
	local s = Step.new(ctx, finish, "Crank", 96)
	if Step.autoStub(s, { cranks = 1 }) then
		return Step.cleanup(s)
	end
	local light = Lighthouses.missionLight(ctx.operation.kind)
	if not light then
		Step.finish(s, { metrics = { cranks = 0 }, failed = true })
		return Step.cleanup(s)
	end
	local model = modelFor(light.id)
	local base = if model then model:GetPivot().Position else light.position
	local origin = base + light.crankOffset
	local rig = Ui.add(s.bag, Instance.new("Model"))
	rig.Name = `LighthouseCrank_{light.id}`
	local wheel = crankPart(
		rig,
		"Wheel",
		Vector3.new(0.8, 4.6, 4.6),
		CFrame.new(origin) * CFrame.Angles(0, 0, math.pi / 2)
	)
	wheel.Shape = Enum.PartType.Cylinder
	crankPart(
		rig,
		"Handle",
		Vector3.new(0.6, 0.6, 3.4),
		CFrame.new(origin + Vector3.new(0, 0.4, 0))
	)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CrankPrompt"
	prompt.ObjectText = light.displayName
	prompt.ActionText = "Turn the lens"
	prompt.HoldDuration = Mech.HOLD
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Parent = wheel
	rig.PrimaryPart = wheel
	rig.Parent = Workspace

	local turning = false
	local function turn()
		if turning or s.finished then
			return
		end
		turning = true
		s.say('Crew: "The optic is turning..."', 2)
		local t0 = os.clock()
		Ui.add(
			s.bag,
			RunService.Heartbeat:Connect(function()
				local a = math.min((os.clock() - t0) / Mech.TURN, 1)
				wheel.CFrame = CFrame.new(origin) * CFrame.Angles(0, math.rad(360 * a), math.pi / 2)
				if a >= 1 then
					Step.finish(s, { metrics = { cranks = 1 } })
				end
			end)
		)
	end
	prompt.Triggered:Connect(function(player)
		if player == Players.LocalPlayer then
			turn()
		end
	end)
	-- Assist: the prompt glows after a few seconds; still an action in the world, not a button
	if ctx.isAssist ~= false then
		Ui.add(
			s.bag,
			task.delay(6, function()
				if not turning then
					s.say("Hold E / X / the prompt to turn the crank.", 4)
				end
			end)
		)
	end
	return Step.cleanup(s)
end

return Mech
