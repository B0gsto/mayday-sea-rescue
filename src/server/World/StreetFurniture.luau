--!strict
-- StreetFurniture: code-built bench and litter bin standing in for M_Road_Bench / M_Road_Bin, whose
-- uploads render as flat navy blocks in the live client (round-2 art review). Same conventions as the
-- assets: pivot at the base centre, front (the sitting side) = local -Z.
--   StreetFurniture.build(asset) -> Model?   nil for any other asset (the caller clones the real one)

local StreetFurniture = {}

local IRON = Color3.fromRGB(34, 42, 38) -- cast-iron ends, painted dark green-black
local OAK = Color3.fromRGB(150, 108, 68)
local BIN_GREEN = Color3.fromRGB(38, 62, 48)
local GOLD = Color3.fromRGB(196, 160, 70)

local function part(
	m: Model,
	name: string,
	size: Vector3,
	cf: CFrame,
	colour: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material
	p.Shape = shape or Enum.PartType.Block
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = m
end

local function bench(m: Model)
	for _, x in { -2.7, 2.7 } do
		part(
			m,
			"LegFront",
			Vector3.new(0.25, 1.45, 0.25),
			CFrame.new(x, 0.72, -0.8),
			IRON,
			Enum.Material.Metal
		)
		part(
			m,
			"LegBack",
			Vector3.new(0.25, 2.9, 0.25),
			CFrame.new(x, 1.45, 0.7) * CFrame.Angles(0.12, 0, 0),
			IRON,
			Enum.Material.Metal
		)
		part(
			m,
			"Arm",
			Vector3.new(0.25, 0.2, 1.8),
			CFrame.new(x, 2.1, -0.15),
			IRON,
			Enum.Material.Metal
		)
	end
	for i, z in { -0.75, -0.25, 0.25 } do
		part(
			m,
			`Seat{i}`,
			Vector3.new(5.9, 0.16, 0.42),
			CFrame.new(0, 1.5, z),
			OAK,
			Enum.Material.Wood
		)
	end
	for i, y in { 2.15, 2.7 } do
		part(
			m,
			`Back{i}`,
			Vector3.new(5.9, 0.42, 0.12),
			CFrame.new(0, y, 0.72 + (y - 2.15) * 0.12) * CFrame.Angles(0.12, 0, 0),
			OAK,
			Enum.Material.Wood
		)
	end
end

local function bin(m: Model)
	local upright = CFrame.Angles(0, 0, math.pi / 2) -- cylinders run along X
	part(
		m,
		"Body",
		Vector3.new(2.5, 1.8, 1.8),
		CFrame.new(0, 1.25, 0) * upright,
		BIN_GREEN,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	part(
		m,
		"Band",
		Vector3.new(0.18, 1.86, 1.86),
		CFrame.new(0, 2.05, 0) * upright,
		GOLD,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	part(
		m,
		"Lid",
		Vector3.new(0.3, 2.0, 2.0),
		CFrame.new(0, 2.65, 0) * upright,
		BIN_GREEN,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	part(
		m,
		"Mouth",
		Vector3.new(0.05, 0.5, 1.0),
		CFrame.new(0, 1.9, -0.9),
		Color3.fromRGB(16, 18, 16),
		Enum.Material.SmoothPlastic
	)
end

local BUILDERS: { [string]: (Model) -> () } = { M_Road_Bench = bench, M_Road_Bin = bin }

function StreetFurniture.build(asset: string): Model?
	local fn = BUILDERS[asset]
	if not fn then
		return nil
	end
	local m = Instance.new("Model")
	m.Name = asset
	fn(m)
	m.WorldPivot = CFrame.identity
	return m
end

return StreetFurniture
