--!strict
-- CliffScene (server): the cliff casualty's world (docs/09 section 8.5). A dressed casualy rig
-- stands waving on the ledge at the foot of Haven Head, with the line, the anchor stake and the
-- stretcher at the cliff-top rescue point. OperationService calls spawn on activate, Recovered
-- when the recovery step completes, and Cleanup when the operation closes.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CasualtyAsset =
	require(script.Parent.Parent:WaitForChild("Assets"):WaitForChild("CasualtyAsset"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CliffRules = require(Shared:WaitForChild("CliffRules"))
local RescueDressing = require(script.Parent:WaitForChild("RescueDressing"))

type Rec = {
	folder: Folder,
	victim: Model?,
	rope: Beam?,
	waving: boolean,
}

local CliffScene = {}

local live: { [any]: Rec } = setmetatable({}, { __mode = "k" }) :: any

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	colour: Color3,
	material: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material
	p.Parent = parent
	return p
end

-- A code-built walker for the (rare) frame before the R15 casualty variants are built.
local function greyboxWalker(): Model
	local model = Instance.new("Model")
	model.Name = "Victim"
	local at = CliffRules.SITE.foot
	local root = part(
		model,
		"HumanoidRootPart",
		Vector3.new(2, 2, 1),
		CFrame.new(at + Vector3.new(0, 4, 0)),
		Color3.fromRGB(220, 220, 215),
		Enum.Material.SmoothPlastic
	)
	root.Transparency = 1
	root.PivotOffset = CFrame.new(0, -4, 0) -- pivot at the feet, like the R15 casualty
	root.CanQuery = true -- the treat and haul prompts attach here
	model.PrimaryPart = root
	part(
		model,
		"Torso",
		Vector3.new(2, 2, 1),
		root.CFrame,
		Color3.fromRGB(70, 90, 120),
		Enum.Material.Fabric
	)
	local head = part(
		model,
		"Head",
		Vector3.new(1.3, 1.3, 1.3),
		root.CFrame * CFrame.new(0, 1.7, 0),
		Color3.fromRGB(200, 160, 130),
		Enum.Material.SmoothPlastic
	)
	head.Shape = Enum.PartType.Ball
	part(
		model,
		"LeftLeg",
		Vector3.new(0.8, 2, 0.8),
		root.CFrame * CFrame.new(-0.5, -1.9, 0),
		Color3.fromRGB(50, 55, 60),
		Enum.Material.Fabric
	)
	part(
		model,
		"RightLeg",
		Vector3.new(0.8, 2, 0.8),
		root.CFrame * CFrame.new(0.5, -1.9, 0),
		Color3.fromRGB(50, 55, 60),
		Enum.Material.Fabric
	)
	local arm = part(
		model,
		"RightArm",
		Vector3.new(0.8, 2, 0.8),
		root.CFrame * CFrame.new(1.4, 1.2, 0),
		Color3.fromRGB(70, 90, 120),
		Enum.Material.Fabric
	)
	model:SetAttribute("Rigged", false)
	-- wave: the right arm swings overhead, so the casualty reads from the cliff top and the sea
	task.spawn(function()
		local base = arm.CFrame
		local t = 0
		while model.Parent do
			t += task.wait(0.08)
			arm.CFrame = base * CFrame.Angles(0, 0, math.rad(-150) + math.sin(t * 5) * math.rad(22))
		end
	end)
	return model
end

local function walker(parent: Instance): Model
	local rig = CasualtyAsset.clone()
	if rig then
		rig.Name = "Victim"
		rig:SetAttribute("Survivor", true)
		rig:SetAttribute("CasualtyPose", "Wave")
		for _, d in rig:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
			end
		end
		if rig.PrimaryPart then
			rig.PrimaryPart.CanQuery = true -- prompts attach to the root
		end
		rig.Parent = parent
		return rig
	end
	local fallback = greyboxWalker()
	fallback.Parent = parent
	return fallback
end

function CliffScene.Spawn(scene: any)
	if live[scene] then
		return
	end
	local callProps = Workspace:FindFirstChild("CallProps")
	if not callProps then
		callProps = Instance.new("Folder")
		callProps.Name = "CallProps"
		callProps.Parent = Workspace
	end
	local folder = Instance.new("Folder")
	folder.Name = `Cliff_{scene.opId}`
	folder.Parent = callProps

	local S = CliffRules.SITE
	local at = CFrame.lookAt(S.foot + Vector3.new(0, 0.2, 0), S.foot + Vector3.new(0, 0.2, 12))
	-- direct child of CallProps: the shared PIW mechanics scan it there (Victim + CallId)
	local victim = walker(callProps)
	victim:SetAttribute("CallId", scene.opId)
	victim:PivotTo(at)
	RescueDressing.apply(victim, scene.variant, { root = victim.PrimaryPart })
	if victim.PrimaryPart then
		local a = Instance.new("Attachment")
		a.Name = "CliffRopePoint"
		a.Position = Vector3.new(0, 3.2, 0)
		a.Parent = victim.PrimaryPart
	end

	-- the anchor stake at the cliff-top rescue point (tagged: the client finds it)
	local ground = S.anchor.Y - 2
	local stake = part(
		folder,
		"CliffRopeAnchor",
		Vector3.new(1, 6, 1),
		CFrame.new(S.anchor.X, ground + 3, S.anchor.Z),
		Color3.fromRGB(70, 72, 70),
		Enum.Material.Metal
	)
	CollectionService:AddTag(stake, "CliffRopeAnchor")
	local cap = part(
		folder,
		"AnchorCap",
		Vector3.new(1.6, 0.7, 1.6),
		stake.CFrame * CFrame.new(0, 3.2, 0),
		Color3.fromRGB(255, 190, 40),
		Enum.Material.Neon
	)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 80)
	light.Range = 30
	light.Brightness = 1.5
	light.Parent = cap
	local ring = Instance.new("Attachment")
	ring.Name = "RopePoint"
	ring.Position = Vector3.new(0, 3.2, 0)
	ring.Parent = stake

	part(
		folder,
		"Stretcher",
		Vector3.new(7, 0.4, 2.4),
		CFrame.new(S.anchor.X - 6, ground + 0.6, S.anchor.Z - 2),
		Color3.fromRGB(235, 130, 40),
		Enum.Material.Fabric
	)

	local rope: Beam? = nil
	if victim.PrimaryPart then
		local cas = victim.PrimaryPart:FindFirstChild("CliffRopePoint")
		if cas and cas:IsA("Attachment") then
			local beam = Instance.new("Beam")
			beam.Name = "CliffLine"
			beam.Attachment0 = ring
			beam.Attachment1 = cas
			beam.Width0 = 0.16
			beam.Width1 = 0.16
			beam.FaceCamera = true
			beam.CurveSize0 = 10
			beam.Color = ColorSequence.new(Color3.fromRGB(240, 230, 200))
			beam.LightInfluence = 0.4
			beam.Parent = folder
			rope = beam
		end
	end

	-- the walker is on rock, not in water: a slow wet-wind drift, not the swimmer clock
	for _, c in scene.casualties or {} do
		c.inWater = false
		c.wet = true
		c.sheltered = false
	end

	live[scene] = { folder = folder, victim = victim, rope = rope, waving = true }
end

-- The recovery step completed: a line haul brings them to the cliff top; carrying them to the
-- boat takes them off the ledge aboard (the model leaves the world).
function CliffScene.Recovered(scene: any, by: Player?)
	local rec = live[scene]
	if not rec or not rec.victim then
		return
	end
	local root = by and by.Character and by.Character:FindFirstChild("HumanoidRootPart")
	local atFoot = root ~= nil
		and math.abs((root :: BasePart).Position.Y - CliffRules.SITE.foot.Y) < 30
	if atFoot then
		rec.victim:Destroy()
		rec.victim = nil
	else
		local victim = rec.victim
		victim:PivotTo(
			CFrame.lookAt(
				CliffRules.SITE.anchor - Vector3.new(0, 1, 5),
				CliffRules.SITE.anchor - Vector3.new(0, 1, 15)
			)
		)
		victim:SetAttribute("CasualtyPose", "Sit")
	end
	if rec.rope then
		rec.rope:Destroy()
		rec.rope = nil
	end
	if rec.folder.Parent then
		rec.folder:SetAttribute("Recovered", true)
	end
end

function CliffScene.Cleanup(scene: any)
	local rec = live[scene]
	if not rec then
		return
	end
	live[scene] = nil
	rec.waving = false
	if rec.victim then
		rec.victim:Destroy()
	end
	rec.folder:Destroy()
end

return CliffScene
