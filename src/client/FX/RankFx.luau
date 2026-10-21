--!strict
-- RankFx: the world half of the promotion beat (docs 03 section 3): a red and a green flare arc
-- up beside the player, confetti pops overhead and the nearest NPCs turn and salute. All client
-- local (the beat is a cue, not gameplay), every part anchored and non-colliding; each call returns
-- a cleanup function the controller runs on skip or beat end.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Flipbooks = require(Shared:WaitForChild("Fx"):WaitForChild("Flipbooks"))
local OceanQuality =
	require(script.Parent.Parent:WaitForChild("Ocean"):WaitForChild("OceanQuality"))
local PyroMath = require(Shared:WaitForChild("Fx"):WaitForChild("PyroMath"))

local RankFx = {}

local RED = Color3.fromRGB(255, 72, 48)
local GREEN = Color3.fromRGB(70, 224, 132)
local CONFETTI = {
	Color3.fromRGB(255, 208, 106),
	Color3.fromRGB(255, 120, 30),
	Color3.fromRGB(120, 230, 160),
	Color3.fromRGB(120, 190, 255),
	Color3.fromRGB(255, 255, 255),
}

local function keys(points: { { number } }): NumberSequence
	local k = {}
	for _, p in points do
		table.insert(k, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(k)
end

local function glowPart(at: Vector3): Part
	local p = Instance.new("Part")
	p.Name = "RankGlow"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = CFrame.new(at)
	p.Parent = Workspace.CurrentCamera or Workspace
	return p
end

-- One flare climbing from `at` on a curved path, lit in `colour`, burning out after about 2 s.
local function flare(at: Vector3, side: Vector3, colour: Color3, seed: number): () -> ()
	local part = glowPart(at)
	local head = Instance.new("ParticleEmitter")
	Flipbooks.apply(head, "FX_Flare_Head")
	head.Color = ColorSequence.new(colour)
	head.LightEmission = 1
	head.LightInfluence = 0
	head.Size = keys({ { 0, 0.8 }, { 1, 1.1 } })
	head.Lifetime = NumberRange.new(0.15, 0.28)
	head.Speed = NumberRange.new(0.2, 0.6)
	head.Rate = 46
	head.LockedToPart = true
	head.Parent = part
	local sparks = Instance.new("ParticleEmitter")
	Flipbooks.apply(sparks, "FX_Flare_Sparks")
	sparks.Color = ColorSequence.new(colour:Lerp(Color3.new(1, 1, 1), 0.55))
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Size = NumberSequence.new(1.3)
	sparks.Lifetime = NumberRange.new(0.4, 0.7)
	sparks.Speed = NumberRange.new(4, 9)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Acceleration = Vector3.new(0, -12, 0)
	sparks.Rate = 10
	sparks.Parent = part
	local smoke = Instance.new("ParticleEmitter")
	Flipbooks.apply(smoke, "FX_Flare_Smoke")
	smoke.Color = ColorSequence.new(colour:Lerp(Color3.new(0.95, 0.95, 0.95), 0.68))
	smoke.Size = keys({ { 0, 1 }, { 1, 6 } })
	smoke.Transparency = keys({ { 0, 0.2 }, { 0.6, 0.45 }, { 1, 1 } })
	smoke.Lifetime = NumberRange.new(2.4, 3.8)
	smoke.Speed = NumberRange.new(1, 2.4)
	smoke.SpreadAngle = Vector2.new(10, 10)
	smoke.Acceleration = Vector3.new(0.5, 0.9, 0)
	smoke.Rate = 9
	smoke.LockedToPart = false
	smoke.Parent = part
	local light = Instance.new("PointLight")
	light.Color = colour
	light.Brightness = 6
	light.Range = 34
	light.Shadows = false
	light.Parent = part

	local t = 0
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt: number)
		t += dt
		local u = math.min(t / 1.5, 1)
		local h = 20 * math.sin(u * math.pi * 0.5)
		part.CFrame = CFrame.new(at + side * 7 * u + Vector3.new(0, h, 0))
		light.Brightness = 6 * PyroMath.flicker(t, seed)
		if t > 3.1 then
			head.Enabled, sparks.Enabled = false, false
		end
		if t > 3.6 then
			head.Enabled, sparks.Enabled, smoke.Enabled = false, false, false
			conn:Disconnect()
			task.delay(2.5, function()
				part:Destroy()
			end)
		end
	end)
	return function()
		if conn.Connected then
			conn:Disconnect()
		end
		part:Destroy()
	end
end

-- Red on the player's right, green on the left: a boat's signal colours, arcing up and hanging.
function RankFx.flares(at: Vector3, right: Vector3): () -> ()
	local a = flare(at + right * 5, right, RED, 1)
	local b = flare(at - right * 5, -right, GREEN, 2)
	return function()
		a()
		b()
	end
end

-- A confetti pop overhead (the same code-built burst as the onboarding reward, rank colour added).
function RankFx.confetti(at: Vector3, colour: Color3): () -> ()
	local host = glowPart(at)
	local tier = OceanQuality.current().name
	local count = if tier == "Low" then 8 elseif tier == "Medium" then 16 else 28
	local palette = { colour, table.unpack(CONFETTI) }
	for i, c in palette do
		local e = Instance.new("ParticleEmitter")
		e.Name = `Confetti{i}`
		e.Color = ColorSequence.new(c)
		e.LightEmission = 0.35
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.75),
			NumberSequenceKeypoint.new(1, 0.35),
		})
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		e.Lifetime = NumberRange.new(1.3, 2.2)
		e.Speed = NumberRange.new(16, 30)
		e.SpreadAngle = Vector2.new(75, 75)
		e.Acceleration = Vector3.new(0, -28, 0)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-240, 240)
		e.Rate = 0
		e.Parent = host
		e:Emit(count)
	end
	task.delay(3.2, function()
		host:Destroy()
	end)
	return function()
		host:Destroy()
	end
end

-- The nearest up to three NPC rigs turn toward the player and hold a salute with the right arm.
local function nearest(origin: Vector3): { { model: Model, root: BasePart, d: number } }
	local out = {}
	for _, inst in CollectionService:GetTagged("NpcCharacter") do
		if inst:IsA("Model") and inst.Parent then
			local root = inst:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local d = (root.Position - origin).Magnitude
				if d < 48 then
					table.insert(out, { model = inst, root = root, d = d })
				end
			end
		end
	end
	table.sort(out, function(a, b)
		return a.d < b.d
	end)
	return out
end

function RankFx.salute(origin: Vector3): () -> ()
	local restore: { () -> () } = {}
	local npcs = nearest(origin)
	for i = 1, math.min(#npcs, 3) do
		local c = npcs[i]
		if c then
			local arm = c.model:FindFirstChild("RightUpperArm")
			local shoulder = arm and arm:FindFirstChild("RightShoulder")
			if shoulder and shoulder:IsA("Motor6D") then
				local original = shoulder.C0
				local raised = original * CFrame.Angles(math.rad(-150), 0, math.rad(-20))
				TweenService:Create(
					shoulder,
					TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ C0 = raised }
				):Play()
				table.insert(restore, function()
					TweenService:Create(shoulder, TweenInfo.new(0.4), { C0 = original }):Play()
				end)
			end
			local rootJoint = c.root:FindFirstChild("RootJoint")
			if rootJoint and rootJoint:IsA("Motor6D") then
				local cf = c.root.CFrame
				local to = Vector3.new(origin.X - cf.Position.X, 0, origin.Z - cf.Position.Z)
				if to.Magnitude > 1 then
					local base = math.atan2(-cf.LookVector.X, -cf.LookVector.Z)
					local want = math.atan2(-to.X, -to.Z)
					local yaw = (want - base + math.pi) % (math.pi * 2) - math.pi
					local original = rootJoint.C0
					TweenService:Create(
						rootJoint,
						TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ C0 = original * CFrame.Angles(0, yaw, 0) }
					):Play()
					table.insert(restore, function()
						TweenService:Create(rootJoint, TweenInfo.new(0.4), { C0 = original }):Play()
					end)
				end
			end
		end
	end
	task.delay(2.4, function()
		for _, f in restore do
			f()
		end
	end)
	return function()
		for _, f in restore do
			f()
		end
	end
end

return RankFx
