--!strict
-- DiverRescue: the Diver at a Wreck scene (docs/23 (h) "Sub pen"). The diver is the scene's normal casualty
-- (RescueService holds them on the seabed: call.dive), boarded by the usual server rule (Ops/CraftBoard: the
-- sub inside Dive's ring, slow and steady, for Board.HOLD). This adds the look: an orange ring on the seabed
-- that shows through the underwater fog (an always-on-top Highlight), a shot line up to a buoy at the
-- surface (the pin), and a tank, mask and bubbles on the diver. BuildWrecks puts placeholder hulls at the
-- CallTypes.DiveSites with no wreck in the world yet (Parts; never Slate/WoodPlanks/Brick/Concrete).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CallTypes = require(Shared:WaitForChild("Calls"):WaitForChild("CallTypes"))
local Dive = require(Shared:WaitForChild("Sub"):WaitForChild("Dive"))
local Flipbooks = require(Shared:WaitForChild("Fx"):WaitForChild("Flipbooks"))

local DiverRescue = {}

local ORANGE = Color3.fromRGB(255, 122, 26)
local RUST = Color3.fromRGB(122, 64, 40)
local IRON = Color3.fromRGB(70, 66, 62)
local SEGMENTS = 16

local live: { [any]: Folder } = {}

local function part(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false -- never the sub's seabed ray, never a wall
	p.CastShadow = false
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

-- An iron steamship broken on the seabed: the hull on its side, the bow torn off, the funnel and a
-- boiler beside it. `cf` on the seabed, the hull along its Z.
local function hull(parent: Instance, cf: CFrame)
	local m = Instance.new("Model")
	m.Name = "WreckHull"
	local lie = cf * CFrame.Angles(0, 0, math.rad(28))
	part(m, Vector3.new(10, 7, 30), lie * CFrame.new(0, 2.5, 4), RUST, Enum.Material.Metal)
	part(m, Vector3.new(8.6, 1, 28), lie * CFrame.new(0, 6.4, 4), IRON, Enum.Material.Metal) -- deck
	part(m, Vector3.new(10, 6, 9), lie * CFrame.new(0, 2.3, 22.5), RUST, Enum.Material.Metal) -- stern
	local bow = Instance.new("WedgePart")
	bow.Size = Vector3.new(9, 6, 10)
	bow.CFrame = cf
		* CFrame.new(3, 2, -19)
		* CFrame.Angles(math.rad(-12), math.rad(22), math.rad(-15))
	bow.Color = RUST
	bow.Material = Enum.Material.Metal
	bow.Anchored, bow.CanCollide, bow.CanTouch, bow.CanQuery, bow.CastShadow =
		true, false, false, false, false
	bow.Parent = m
	part(
		m,
		Vector3.new(12, 3.4, 3.4),
		cf * CFrame.new(-8, 1.5, 2) * CFrame.Angles(0, math.rad(70), 0),
		IRON,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	) -- the fallen funnel
	part(
		m,
		Vector3.new(6, 5, 5),
		cf * CFrame.new(7, 2.3, -9) * CFrame.Angles(0, math.rad(90), 0),
		RUST,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	) -- a boiler
	part(m, Vector3.new(0.6, 16, 0.6), lie * CFrame.new(0, 12, 10), IRON, Enum.Material.Metal) -- the mast
	m.Parent = parent
end

function DiverRescue.BuildWrecks()
	local folder = Instance.new("Folder")
	folder.Name = "DiveWrecks"
	for _, site in CallTypes.DiveSites do
		if site.hull then
			hull(folder, CFrame.new(site.wreck) * CFrame.Angles(0, math.rad(site.yaw), 0))
		end
	end
	folder.Parent = Workspace
end

-- The pick-up ring flat on the seabed round `at` (Dive.RING_RADIUS).
local function ring(parent: Instance, at: Vector3)
	local m = Instance.new("Model")
	m.Name = "DiveRing"
	local r = Dive.RING_RADIUS
	local len = 2 * math.pi * r / SEGMENTS + 0.3
	for i = 1, SEGMENTS do
		local a = (i - 0.5) / SEGMENTS * math.pi * 2
		local mid = at + Vector3.new(math.cos(a) * r, 0.3, math.sin(a) * r)
		part(
			m,
			Vector3.new(0.7, 0.3, len),
			CFrame.lookAt(mid, mid + Vector3.new(-math.sin(a), 0, math.cos(a))),
			ORANGE,
			Enum.Material.Neon
		)
	end
	local glow = Instance.new("Highlight") -- through the underwater fog slices (Ocean/Underwater)
	glow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	glow.FillColor = ORANGE
	glow.FillTransparency = 0.4
	glow.OutlineColor = ORANGE
	glow.Parent = m
	m.Parent = parent
end

-- The shot line from the buoy (the pin on the surface) down to the ring.
local function shotLine(parent: Instance, at: Vector3)
	local top = Vector3.new(at.X, 0, at.Z)
	local depth = top.Y - at.Y
	part(
		parent,
		Vector3.new(0.25, depth, 0.25),
		CFrame.new(top - Vector3.new(0, depth / 2, 0)),
		ORANGE,
		Enum.Material.Neon
	)
	local buoy = part(
		parent,
		Vector3.new(2.6, 2.6, 2.6),
		CFrame.new(top),
		ORANGE,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	local light = Instance.new("PointLight")
	light.Color = ORANGE
	light.Range = 20
	light.Parent = buoy
end

-- Tank, mask and bubbles on the casualty, riding its floater (RescueService moves them; welded aboard).
local function dress(op: any)
	local victim = op.scene.victims and op.scene.victims[1]
	local f = victim and victim.floater
	if not (f and victim.model) then
		return
	end
	local base: CFrame = f.offsets[1]
	local function add(p: BasePart, offset: CFrame)
		p.Parent = victim.model
		table.insert(f.parts, p)
		table.insert(f.offsets, base * offset)
	end
	local tank = part(
		victim.model,
		Vector3.new(2.4, 1.1, 1.1),
		f.cf * base,
		Color3.fromRGB(255, 196, 40),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	tank.Name = "DiveTank"
	add(tank, CFrame.new(0, 0.2, 0.8) * CFrame.Angles(0, 0, math.rad(90)))
	local mask = part(
		victim.model,
		Vector3.new(1.1, 0.55, 0.35),
		f.cf * base,
		Color3.fromRGB(40, 60, 75),
		Enum.Material.Glass
	)
	mask.Name = "DiveMask"
	add(mask, CFrame.new(0, 1.75, -0.6))
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Name = "Bubbles"
	Flipbooks.apply(bubbles, "FX_Under_Bubbles")
	bubbles.Color = ColorSequence.new(Color3.fromHex("#DDEDEA"))
	bubbles.Size = NumberSequence.new(0.35, 0.6)
	bubbles.Transparency = NumberSequence.new(0.2, 0.8)
	bubbles.Lifetime = NumberRange.new(4, 6)
	bubbles.Speed = NumberRange.new(5, 7)
	bubbles.SpreadAngle = Vector2.new(10, 10)
	bubbles.EmissionDirection = Enum.NormalId.Top
	bubbles.Rate = 8
	bubbles.Parent = mask
	-- aboard (VehicleService tags OnVehicle): no more bubbles, the ring and line go
	victim.model:GetAttributeChangedSignal("OnVehicle"):Connect(function()
		bubbles.Enabled = false
		DiverRescue.Cleanup(op)
	end)
end

function DiverRescue.Spawn(op: any)
	local site: CallTypes.DiveSite = op.dive
	local folder = Instance.new("Folder")
	folder.Name = `Dive_{op.id}`
	ring(folder, site.at)
	shotLine(folder, site.at)
	folder.Parent = Workspace:FindFirstChild("CallProps") or Workspace
	live[op] = folder
	dress(op)
end

function DiverRescue.Cleanup(op: any)
	local folder = live[op]
	if folder then
		live[op] = nil
		folder:Destroy()
	end
end

return DiverRescue
