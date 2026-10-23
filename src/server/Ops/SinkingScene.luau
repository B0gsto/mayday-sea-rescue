--!strict
-- SinkingScene (server): the fishing boat of the Sinking Vessel operation (docs/09 section 8.1, docs/16 K1).
-- Spectacle only: a code-built trawler lists and settles over the call, with the swirl where the water
-- comes in and a waterline that climbs her side. Her crew are already in the water beside her
-- (RescueService survivors). OperationService calls Spawn on activate and Cleanup when it closes.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RescueDressing = require(script.Parent:WaitForChild("RescueDressing"))

local SinkingScene = {}

SinkingScene.SINK_SECONDS = 480 -- she is nearly gone this long after the call starts -- tune
SinkingScene.LIST_START = math.rad(6)
SinkingScene.LIST_MAX = math.rad(20)
SinkingScene.SETTLE_MAX = 4.5 -- studs the hull drops by the end

type Rec = { folder: Folder, conn: RBXScriptConnection }

local live: { [any]: Rec } = setmetatable({}, { __mode = "k" }) :: any

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	colour: Color3,
	material: Enum.Material?
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
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

function SinkingScene.Spawn(scene: any)
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
	folder.Name = `Sinking_{scene.opId}`
	folder.Parent = callProps

	local model = Instance.new("Model")
	model.Name = "SinkingBoat"
	model.Parent = folder

	local hull =
		part(model, "Hull", Vector3.new(24, 7, 52), CFrame.new(), Color3.fromRGB(224, 226, 220))
	hull.Material = Enum.Material.SmoothPlastic
	model.PrimaryPart = hull
	part(model, "Keel", Vector3.new(22, 2, 50), CFrame.new(0, -3.4, 0), Color3.fromRGB(150, 44, 40))
	part(
		model,
		"Cabin",
		Vector3.new(14, 8, 18),
		CFrame.new(0, 7.5, -4),
		Color3.fromRGB(236, 238, 232)
	)
	part(
		model,
		"Roof",
		Vector3.new(15.5, 0.7, 19.5),
		CFrame.new(0, 11.85, -4),
		Color3.fromRGB(200, 202, 196)
	)
	part(
		model,
		"Wheelhouse",
		Vector3.new(12.4, 2.2, 1),
		CFrame.new(0, 8.7, -13.1),
		Color3.fromRGB(40, 60, 78),
		Enum.Material.Glass
	)
	local gunwale = Color3.fromRGB(190, 60, 50)
	part(model, "RailPort", Vector3.new(0.4, 0.8, 48), CFrame.new(-11.8, 3.9, 0), gunwale)
	part(model, "RailStarboard", Vector3.new(0.4, 0.8, 48), CFrame.new(11.8, 3.9, 0), gunwale)
	part(
		model,
		"Mast",
		Vector3.new(0.8, 12, 0.8),
		CFrame.new(0, 18, -9),
		Color3.fromRGB(90, 94, 98)
	)
	part(
		model,
		"Boom",
		Vector3.new(0.6, 0.6, 14),
		CFrame.new(0, 23, -2),
		Color3.fromRGB(90, 94, 98)
	)
	part(
		model,
		"NameBoard",
		Vector3.new(7, 1.6, 0.3),
		CFrame.new(0, 3.9, -26.2),
		Color3.fromRGB(24, 40, 58)
	)

	RescueDressing.apply(model, scene.variant, { root = hull :: BasePart })

	-- where the water comes in: a bright swirl and bubbles on the starboard quarter
	local leak = part(
		model,
		"LeakPoint",
		Vector3.new(2.2, 2.2, 2.2),
		CFrame.new(12.2, 0.4, 6),
		Color3.fromRGB(225, 245, 255),
		Enum.Material.Neon
	)
	leak.Shape = Enum.PartType.Ball
	leak.Transparency = 0.25
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Name = "LeakSwirl"
	bubbles.Rate = 22
	bubbles.Lifetime = NumberRange.new(0.4, 0.9)
	bubbles.Speed = NumberRange.new(1, 3)
	bubbles.SpreadAngle = Vector2.new(18, 18)
	bubbles.Size = NumberSequence.new(0.5, 0.1)
	bubbles.Color = ColorSequence.new(Color3.fromRGB(235, 250, 255))
	bubbles.Transparency = NumberSequence.new(0.2, 1)
	bubbles.Parent = leak

	-- the sea's edge on her side: a fixed white line the hull settles through
	local foam = part(
		folder,
		"Waterline",
		Vector3.new(30, 0.12, 58),
		CFrame.new(scene.position.X, 0.22, scene.position.Z) * CFrame.Angles(0, math.rad(18), 0),
		Color3.fromRGB(245, 250, 252),
		Enum.Material.SmoothPlastic
	)
	foam.Transparency = 0.45

	local base = CFrame.new(scene.position.X, 0, scene.position.Z)
		* CFrame.Angles(0, math.rad(18), 0)
	model:PivotTo(base)
	folder:SetAttribute("OpId", scene.opId)
	local started = os.clock()
	local conn = RunService.Heartbeat:Connect(function()
		local f = math.clamp((os.clock() - started) / SinkingScene.SINK_SECONDS, 0, 1)
		local list = SinkingScene.LIST_START + (SinkingScene.LIST_MAX - SinkingScene.LIST_START) * f
		model:PivotTo(
			base * CFrame.new(0, -SinkingScene.SETTLE_MAX * f, 0) * CFrame.Angles(0, 0, list)
		)
	end)
	live[scene] = { folder = folder, conn = conn }
end

function SinkingScene.Cleanup(scene: any)
	local rec = live[scene]
	if not rec then
		return
	end
	live[scene] = nil
	rec.conn:Disconnect()
	rec.folder:Destroy()
end

return SinkingScene
